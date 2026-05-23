defmodule Grephql.ClientModuleGenerationPlugin do
  @moduledoc false
  use Grephql.Generation.Plugin

  alias Grephql.Generation.Field
  alias Grephql.Generation.Schema

  # Renames every `name` field to `display_name`. A rename is observable at
  # runtime — the decoded struct exposes the new key, sourced from the original
  # "name" — unlike forced nullability, whose effect lives only in the @type
  # (not introspectable on generated modules). Proves a user plugin reaches the
  # pipeline via use Grephql's :generation_plugins.
  @impl Grephql.Generation.Plugin
  def after_resolve(tree, _context), do: rename(tree)

  defp rename(%Schema{} = node) do
    %{
      node
      | fields:
          Enum.map(node.fields, fn
            %Field{name: :name} = field -> %{field | name: :display_name}
            field -> field
          end),
        children: Enum.map(node.children, &rename/1)
    }
  end
end

defmodule Grephql.ClientModuleTest do
  use ExUnit.Case, async: true

  describe "use Grephql with file source" do
    defmodule FileClient do
      use Grephql,
        otp_app: :grephql,
        source: "../support/schemas/minimal.json"
    end

    test "defines __grephql_config__/0" do
      assert {otp_app, use_config} = FileClient.__grephql_config__()
      assert otp_app == :grephql
      assert use_config == []
    end
  end

  describe "use Grephql with inline JSON source" do
    @minimal_json Jason.encode!(%{
                    "data" => %{
                      "__schema" => %{
                        "queryType" => %{"name" => "Query"},
                        "mutationType" => nil,
                        "subscriptionType" => nil,
                        "types" => [
                          %{
                            "kind" => "OBJECT",
                            "name" => "Query",
                            "description" => nil,
                            "fields" => [],
                            "inputFields" => nil,
                            "interfaces" => [],
                            "enumValues" => nil,
                            "possibleTypes" => nil
                          }
                        ],
                        "directives" => []
                      }
                    }
                  })

    test "loads inline JSON schema" do
      # Inline JSON is tested via __load_schema__ directly since
      # module attributes can't be unquoted in nested defmodule
      schema = Grephql.__load_schema__(@minimal_json, __ENV__.file)
      assert schema.query_type == "Query"
    end
  end

  describe "use Grephql with config options" do
    defmodule ConfigClient do
      use Grephql,
        otp_app: :grephql,
        source: "../support/schemas/minimal.json",
        endpoint: "https://api.example.com/graphql",
        req_options: [receive_timeout: 30_000]
    end

    test "passes config keys through __grephql_config__/0" do
      {_otp_app, use_config} = ConfigClient.__grephql_config__()
      assert use_config[:endpoint] == "https://api.example.com/graphql"
      assert use_config[:req_options] == [receive_timeout: 30_000]
    end
  end

  describe "source file validation" do
    test "raises CompileError when schema file does not exist" do
      assert_raise CompileError, ~r/schema file not found/, fn ->
        defmodule MissingSchemaClient do
          use Grephql,
            otp_app: :grephql,
            source: "nonexistent/schema.json"
        end
      end
    end
  end

  describe "schema caching" do
    test "persistent_term caches schema across calls" do
      schema1 = Grephql.__load_schema__("../support/schemas/minimal.json", __ENV__.file)
      schema2 = Grephql.__load_schema__("../support/schemas/minimal.json", __ENV__.file)

      assert schema1 == schema2
    end
  end

  describe "use Grephql with generation_plugins" do
    defmodule PluginClient do
      use Grephql,
        otp_app: :grephql,
        source: "../support/schemas/integration.json",
        endpoint: "https://api.example.com/graphql",
        generation_plugins: [Grephql.ClientModuleGenerationPlugin]

      defgql(:get_user, """
      query GetUser($id: ID!) {
        user(id: $id) { id name }
      }
      """)
    end

    test "a user generation plugin runs and changes the generated modules" do
      assert function_exported?(PluginClient, :get_user, 2)

      result =
        Grephql.ResponseDecoder.decode!(
          PluginClient.GetUser.Result,
          %{"user" => %{"id" => "1", "name" => "Alice"}}
        )

      assert result.user.id == "1"
      # The plugin renamed :name -> :display_name during generation; the field
      # is sourced from the original "name" key, so the value still decodes. If
      # :generation_plugins were not wired through, the struct would expose
      # :name instead and this would fail.
      assert result.user.display_name == "Alice"
      refute Map.has_key?(result.user, :name)
    end
  end
end

defmodule Grephql.Generation.SkipIncludeTest do
  use ExUnit.Case, async: true

  # Generated modules are defined at test runtime by TypeGenerator.generate/3.
  @compile {:no_warn_undefined,
            [
              Grephql.Test.SkipInclude.FieldInclude.Result,
              Grephql.Test.SkipInclude.FieldSkip.Result,
              Grephql.Test.SkipInclude.LiteralInclude.Result,
              Grephql.Test.SkipInclude.LiteralSkip.Result,
              Grephql.Test.SkipInclude.InlineFragment.Result,
              Grephql.Test.SkipInclude.FragmentSpread.Result,
              Grephql.Test.SkipInclude.FieldEmbed.Result,
              Grephql.Test.SkipInclude.FragmentEmbed.Result,
              Grephql.Test.SkipInclude.UnionInclude.Result,
              Grephql.Test.SkipInclude.UserPlugin.Result
            ]}

  alias Grephql.Generation.Field
  alias Grephql.Generation.Plugins.SkipInclude
  alias Grephql.Generation.Schema
  alias Grephql.Test.SchemaHelper
  alias Grephql.TypeGenerator

  defmodule CapturePlugin do
    @moduledoc false
    use Grephql.Generation.Plugin

    @impl Grephql.Generation.Plugin
    def after_resolve(tree, _context) do
      send(self(), {:resolved_tree, tree})
      tree
    end
  end

  defmodule ForceNullablePlugin do
    @moduledoc false
    use Grephql.Generation.Plugin

    alias Grephql.Generation.Field
    alias Grephql.Generation.Schema

    @impl Grephql.Generation.Plugin
    def after_resolve(tree, _context) do
      Schema.map_fields(tree, fn %Field{} = field ->
        if field.name == :name, do: Field.put_nullable(field, true), else: field
      end)
    end
  end

  describe "field-level @include / @skip" do
    test "@include(if: $var) makes a non-null ID field nullable" do
      tree =
        resolve_tree(
          ~s|query Q($show: Boolean!) { user(id: "1") { id @include(if: $show) name } }|,
          Grephql.Test.SkipInclude.FieldInclude,
          :q
        )

      assert nullable?(tree, :id)
      # name has no directive and is schema-nullable already; unaffected by plugin
      assert field(tree, :id).resolved.nullable == true
    end

    test "@skip(if: $var) makes a non-null ID field nullable" do
      tree =
        resolve_tree(
          ~s|query Q($hide: Boolean!) { user(id: "1") { id @skip(if: $hide) name } }|,
          Grephql.Test.SkipInclude.FieldSkip,
          :q
        )

      assert nullable?(tree, :id)
    end
  end

  describe "no-op literal directives" do
    test "@include(if: true) does NOT make a non-null field nullable" do
      tree =
        resolve_tree(
          ~s|query Q { user(id: "1") { id @include(if: true) name } }|,
          Grephql.Test.SkipInclude.LiteralInclude,
          :q
        )

      refute nullable?(tree, :id)
    end

    test "@skip(if: false) does NOT make a non-null field nullable" do
      tree =
        resolve_tree(
          ~s|query Q { user(id: "1") { id @skip(if: false) name } }|,
          Grephql.Test.SkipInclude.LiteralSkip,
          :q
        )

      refute nullable?(tree, :id)
    end
  end

  describe "directive propagation from fragments" do
    test "inline-fragment @include propagates to all inner fields" do
      tree =
        resolve_tree(
          ~s|query Q($show: Boolean!) { user(id: "1") { ... @include(if: $show) { id name } } }|,
          Grephql.Test.SkipInclude.InlineFragment,
          :q
        )

      assert nullable?(tree, :id)
      assert nullable?(tree, :name)
    end

    test "fragment-spread @include propagates to all expanded fields" do
      fragments = %{
        "UserFields" => %{
          source: "fragment UserFields on User { id name }",
          fragment: parse_fragment("fragment UserFields on User { id name }"),
          result_module: Grephql.Test.SkipInclude.FragmentSpread.Fragments.UserFields
        }
      }

      tree =
        resolve_tree(
          ~s|query Q($show: Boolean!) { user(id: "1") { ...UserFields @include(if: $show) } }|,
          Grephql.Test.SkipInclude.FragmentSpread,
          :q,
          fragments: fragments
        )

      assert nullable?(tree, :id)
      assert nullable?(tree, :name)
    end
  end

  describe "directive propagation on union/interface inline fragments" do
    test "inline-fragment @include over a union propagates to concrete-type fields" do
      schema = schema_with_union()

      root =
        resolve_root(
          ~s|query Q($show: Boolean!) { search { __typename ... on User @include(if: $show) { id email } ... on Post { id title } } }|,
          Grephql.Test.SkipInclude.UnionInclude,
          :q,
          schema: schema
        )

      search_node = node_for(root, "SearchResult") || union_child(root)
      user_variant = Enum.find(search_node.children, &(&1.parent_type == "User"))
      post_variant = Enum.find(search_node.children, &(&1.parent_type == "Post"))

      # User variant fields are conditional (inline fragment carries @include).
      assert field(user_variant, :id).resolved.nullable == true
      assert field(user_variant, :email).resolved.nullable == true

      # Post variant has no directive: its non-null id stays non-null.
      assert field(post_variant, :id).resolved.nullable == false
    end
  end

  describe "field-level directive does not propagate into sub-selection" do
    test "@include on an embed field marks the embed nullable but not its children" do
      schema = SchemaHelper.build_schema(types: types_with_profile())

      tree =
        resolve_tree(
          ~s|query Q($show: Boolean!) { user(id: "1") { name profile @include(if: $show) { bio } } }|,
          Grephql.Test.SkipInclude.FieldEmbed,
          :q,
          schema: schema
        )

      # The embed field itself is conditional -> nullable.
      assert field(tree, :profile).resolved.nullable == true

      # Its child `bio` keeps schema nullability (no propagation of the parent's directive).
      bio = field(node_for(tree.root, "Profile"), :bio)
      assert bio.query_field.directives == []
    end
  end

  describe "fragment directive over an object field" do
    test "inline-fragment @include marks an embed nullable but not its children" do
      schema = SchemaHelper.build_schema(types: types_with_profile())

      tree =
        resolve_tree(
          ~s|query Q($show: Boolean!) { user(id: "1") { name ... @include(if: $show) { profile { bio } } } }|,
          Grephql.Test.SkipInclude.FragmentEmbed,
          :q,
          schema: schema
        )

      # The embed is a direct member of the conditional fragment -> nullable.
      assert field(tree, :profile).resolved.nullable == true

      # bio lives inside profile; the fragment directive does not reach it.
      bio = field(node_for(tree.root, "Profile"), :bio)
      assert bio.query_field.directives == []
    end
  end

  describe "SkipInclude.after_resolve/2 conditionality rules" do
    setup do
      context = %Grephql.Generation.Context{schema: SchemaHelper.build_schema()}
      %{context: context}
    end

    test "@include(if: false) and @skip(if: true) still produce a nullable field", %{
      context: context
    } do
      for {directive_name, literal} <- [{"include", false}, {"skip", true}] do
        tree =
          object_with_field(
            scalar_field(:id, false, [boolean_directive(directive_name, literal)])
          )

        out = SkipInclude.after_resolve(tree, context)
        assert hd(out.fields).resolved.nullable == true
      end
    end

    test "embeds_many fields are left unchanged even when conditional", %{context: context} do
      embed = %Field{
        kind: :embeds_many,
        name: :posts,
        original_name: "posts",
        resolved: %{
          ecto_type: {:object, "Post"},
          nullable: false,
          enum_values: nil,
          inner_nullable: nil
        },
        embed_module: SomePostModule,
        query_field: %Grephql.Language.Field{
          name: "posts",
          directives: [variable_directive("include", "show")]
        },
        schema_field: %Grephql.Schema.Field{
          name: "posts",
          type: %Grephql.Schema.TypeRef{kind: :object, name: "Post"}
        }
      }

      tree = object_with_field(embed)
      out = SkipInclude.after_resolve(tree, context)
      assert hd(out.fields).resolved.nullable == false
    end
  end

  describe "user generation_plugins" do
    test "a user plugin can transform a field (force nullable)" do
      tree =
        resolve_tree(
          ~s|query Q { user(id: "1") { id name } }|,
          Grephql.Test.SkipInclude.UserPlugin,
          :q,
          generation_plugins: [ForceNullablePlugin]
        )

      # name forced nullable by the user plugin (it was schema-nullable anyway,
      # but the plugin proves it can mutate the resolved field)
      assert field(tree, :name).resolved.nullable == true
      # id stays non-null (no directive, user plugin only touches :name)
      refute nullable?(tree, :id)
    end
  end

  # Helpers

  # Returns the `User` node of the resolved tree (the queries below all select a
  # top-level `user` embed, so the fields under test live one level down).
  defp resolve_tree(query, client_module, function_name, opts \\ []) do
    schema = Keyword.get_lazy(opts, :schema, &SchemaHelper.build_schema/0)
    operation = parse!(query)

    plugins = [CapturePlugin | Keyword.get(opts, :generation_plugins, [])]

    TypeGenerator.generate(operation, schema,
      client_module: client_module,
      function_name: function_name,
      fragments: Keyword.get(opts, :fragments, %{}),
      generation_plugins: plugins
    )

    assert_received {:resolved_tree, root}
    %{root: root, user: node_for(root, "User")}
  end

  defp resolve_root(query, client_module, function_name, opts) do
    %{root: root} = resolve_tree(query, client_module, function_name, opts)
    root
  end

  defp union_child(%Schema{kind: :union} = node), do: node

  defp union_child(%Schema{children: children}) do
    Enum.find_value(children, &union_child/1)
  end

  defp union_child(_other), do: nil

  defp node_for(%Schema{parent_type: type} = node, type), do: node

  defp node_for(%Schema{children: children}, type) do
    Enum.find_value(children, fn child -> node_for(child, type) end)
  end

  defp node_for(_other, _type), do: nil

  defp field(%{user: %Schema{} = node}, name), do: field(node, name)

  defp field(%Schema{} = node, name) do
    Enum.find(node.fields, &(&1.name == name)) ||
      raise "field #{inspect(name)} not found in #{inspect(node.module)}"
  end

  defp nullable?(tree, name) do
    %Field{resolved: %{nullable: nullable}} = field(tree, name)
    nullable
  end

  defp object_with_field(%Field{} = field) do
    %Schema{kind: :object, module: HandBuilt, parent_type: "User", fields: [field], children: []}
  end

  defp scalar_field(name, nullable, directives) do
    %Field{
      kind: :field,
      name: name,
      original_name: Atom.to_string(name),
      resolved: %{ecto_type: :string, nullable: nullable, enum_values: nil, inner_nullable: nil},
      query_field: %Grephql.Language.Field{name: Atom.to_string(name), directives: directives},
      schema_field: %Grephql.Schema.Field{
        name: Atom.to_string(name),
        type: %Grephql.Schema.TypeRef{kind: :scalar, name: "ID"}
      }
    }
  end

  defp boolean_directive(name, value) do
    %Grephql.Language.Directive{
      name: name,
      arguments: [
        %Grephql.Language.Argument{
          name: "if",
          value: %Grephql.Language.BooleanValue{value: value}
        }
      ]
    }
  end

  defp variable_directive(name, var_name) do
    %Grephql.Language.Directive{
      name: name,
      arguments: [
        %Grephql.Language.Argument{
          name: "if",
          value: %Grephql.Language.Variable{name: var_name}
        }
      ]
    }
  end

  defp parse!(query) do
    {:ok, %{definitions: [operation | _rest]}} = Grephql.Parser.parse(query)
    operation
  end

  defp parse_fragment(source) do
    {:ok, %{definitions: [fragment | _rest]}} = Grephql.Parser.parse(source)
    fragment
  end

  defp schema_with_union do
    type_ref = fn kind, name -> %Grephql.Schema.TypeRef{kind: kind, name: name} end
    non_null = fn inner -> %Grephql.Schema.TypeRef{kind: :non_null, of_type: inner} end

    types =
      Map.merge(SchemaHelper.default_types(), %{
        "Query" => %Grephql.Schema.Type{
          kind: :object,
          name: "Query",
          fields: %{
            "search" => %Grephql.Schema.Field{
              name: "search",
              type:
                non_null.(%Grephql.Schema.TypeRef{
                  kind: :list,
                  of_type: type_ref.(:union, "SearchResult")
                })
            }
          }
        },
        "SearchResult" => %Grephql.Schema.Type{
          kind: :union,
          name: "SearchResult",
          possible_types: ["User", "Post"]
        },
        "User" => %Grephql.Schema.Type{
          kind: :object,
          name: "User",
          fields: %{
            "__typename" => %Grephql.Schema.Field{
              name: "__typename",
              type: non_null.(type_ref.(:scalar, "String"))
            },
            "id" => %Grephql.Schema.Field{name: "id", type: non_null.(type_ref.(:scalar, "ID"))},
            "email" => %Grephql.Schema.Field{name: "email", type: type_ref.(:scalar, "String")}
          }
        },
        "Post" => %Grephql.Schema.Type{
          kind: :object,
          name: "Post",
          fields: %{
            "__typename" => %Grephql.Schema.Field{
              name: "__typename",
              type: non_null.(type_ref.(:scalar, "String"))
            },
            "id" => %Grephql.Schema.Field{name: "id", type: non_null.(type_ref.(:scalar, "ID"))},
            "title" => %Grephql.Schema.Field{name: "title", type: type_ref.(:scalar, "String")}
          }
        }
      })

    SchemaHelper.build_schema(types: types)
  end

  defp types_with_profile do
    Map.merge(SchemaHelper.default_types(), %{
      "User" => %Grephql.Schema.Type{
        kind: :object,
        name: "User",
        fields: %{
          "name" => %Grephql.Schema.Field{
            name: "name",
            type: %Grephql.Schema.TypeRef{kind: :scalar, name: "String"}
          },
          "profile" => %Grephql.Schema.Field{
            name: "profile",
            type: %Grephql.Schema.TypeRef{
              kind: :non_null,
              of_type: %Grephql.Schema.TypeRef{kind: :object, name: "Profile"}
            }
          }
        }
      },
      "Profile" => %Grephql.Schema.Type{
        kind: :object,
        name: "Profile",
        fields: %{
          "bio" => %Grephql.Schema.Field{
            name: "bio",
            type: %Grephql.Schema.TypeRef{kind: :scalar, name: "String"}
          }
        }
      }
    })
  end
end

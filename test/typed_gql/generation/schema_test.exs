defmodule TypedGql.Generation.SchemaTest do
  use ExUnit.Case, async: true

  alias TypedGql.Generation.Field
  alias TypedGql.Generation.Schema

  defp scalar_field(name, nullable) do
    %Field{
      kind: :field,
      name: name,
      original_name: Atom.to_string(name),
      resolved: %{ecto_type: :string, nullable: nullable, enum_values: nil, inner_nullable: nil},
      query_field: %TypedGql.Language.Field{name: Atom.to_string(name)},
      schema_field: %TypedGql.Schema.Field{
        name: Atom.to_string(name),
        type: %TypedGql.Schema.TypeRef{kind: :scalar, name: "String"}
      }
    }
  end

  describe "map_fields/2" do
    test "applies the function to fields of the node and all descendants" do
      child =
        %Schema{
          kind: :object,
          module: Root.Child,
          parent_type: "Child",
          fields: [scalar_field(:inner, false)]
        }

      root =
        %Schema{
          kind: :object,
          module: Root,
          parent_type: "Root",
          fields: [scalar_field(:outer, false)],
          children: [child]
        }

      mapped = Schema.map_fields(root, fn field -> Field.put_nullable(field, true) end)

      assert hd(mapped.fields).resolved.nullable == true

      [child] = mapped.children
      assert hd(child.fields).resolved.nullable == true
    end

    test "recurses into union variants" do
      variant =
        %Schema{
          kind: :object,
          module: Root.Search.User,
          parent_type: "User",
          fields: [scalar_field(:id, false)]
        }

      union =
        %Schema{
          kind: :union,
          module: Root.Search,
          union_module: Root.Search.Union,
          typename_to_module: %{"User" => Root.Search.User},
          children: [variant]
        }

      mapped = Schema.map_fields(union, fn field -> Field.put_nullable(field, true) end)

      variant_field = mapped.children |> hd() |> Map.fetch!(:fields) |> hd()
      assert variant_field.resolved.nullable == true
    end
  end
end

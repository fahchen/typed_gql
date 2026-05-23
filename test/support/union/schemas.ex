defmodule TypedGql.Test.UnionTypes.User do
  @moduledoc false
  use TypedGql.EmbeddedSchema

  typed_embedded_schema do
    field :__typename, TypedGql.Types.Typename, values: ["User", "Post"], typed: [null: false]
    field :name, :string, typed: [null: true]
    field :email, :string, typed: [null: true]
  end
end

defmodule TypedGql.Test.UnionTypes.Post do
  @moduledoc false
  use TypedGql.EmbeddedSchema

  typed_embedded_schema do
    field :__typename, TypedGql.Types.Typename, values: ["User", "Post"], typed: [null: false]
    field :title, :string, typed: [null: true]
  end
end

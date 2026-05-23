defmodule TypedGql.Language.NamedType do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :name, String.t()
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.ListType do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :type, TypedGql.Language.type_reference_t()
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.NonNullType do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :type, TypedGql.Language.type_reference_t()
    field :loc, map(), default: %{line: nil}
  end
end

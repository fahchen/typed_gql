defmodule TypedGql.Language.IntValue do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :value, integer()
    field :loc, map()
  end
end

defmodule TypedGql.Language.FloatValue do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :value, float()
    field :loc, map()
  end
end

defmodule TypedGql.Language.StringValue do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :value, String.t()
    field :loc, map()
  end
end

defmodule TypedGql.Language.BooleanValue do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :value, boolean()
    field :loc, map()
  end
end

defmodule TypedGql.Language.NullValue do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :loc, map()
  end
end

defmodule TypedGql.Language.EnumValue do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :value, String.t()
    field :loc, map(), default: %{line: nil, column: nil}
  end
end

defmodule TypedGql.Language.ListValue do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :values, [TypedGql.Language.value_t()], default: []
    field :loc, map()
  end
end

defmodule TypedGql.Language.ObjectValue do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :fields, [TypedGql.Language.ObjectField.t()], default: []
    field :loc, map()
  end
end

defmodule TypedGql.Language.ObjectField do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :name, String.t()
    field :value, TypedGql.Language.value_t()
    field :loc, map(), default: %{line: nil}
  end
end

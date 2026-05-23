defmodule TypedGql.Language.ScalarTypeDefinition do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :name, String.t()
    field :description, String.t()
    field :directives, [TypedGql.Language.Directive.t()], default: []
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.ObjectTypeDefinition do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :name, String.t()
    field :description, String.t()
    field :directives, [TypedGql.Language.Directive.t()], default: []
    field :interfaces, [TypedGql.Language.NamedType.t()], default: []
    field :fields, [TypedGql.Language.FieldDefinition.t()], default: []
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.InterfaceTypeDefinition do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :name, String.t()
    field :description, String.t()
    field :fields, [TypedGql.Language.FieldDefinition.t()], default: []
    field :directives, [TypedGql.Language.Directive.t()], default: []
    field :interfaces, [TypedGql.Language.NamedType.t()], default: []
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.UnionTypeDefinition do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :name, String.t()
    field :description, String.t()
    field :directives, [TypedGql.Language.Directive.t()], default: []
    field :types, [TypedGql.Language.NamedType.t()], default: []
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.EnumTypeDefinition do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :name, String.t()
    field :description, String.t()
    field :values, [TypedGql.Language.EnumValueDefinition.t()], default: []
    field :directives, [TypedGql.Language.Directive.t()], default: []
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.InputObjectTypeDefinition do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :name, String.t()
    field :description, String.t()
    field :fields, [TypedGql.Language.InputValueDefinition.t()], default: []
    field :directives, [TypedGql.Language.Directive.t()], default: []
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.FieldDefinition do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :name, String.t()
    field :description, String.t()
    field :arguments, [TypedGql.Language.InputValueDefinition.t()], default: []
    field :directives, [TypedGql.Language.Directive.t()], default: []
    field :type, TypedGql.Language.type_reference_t()
    field :complexity, non_neg_integer()
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.InputValueDefinition do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :name, String.t()
    field :type, TypedGql.Language.type_reference_t()
    field :description, String.t()
    field :default_value, TypedGql.Language.value_t()
    field :directives, [TypedGql.Language.Directive.t()], default: []
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.EnumValueDefinition do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :value, String.t()
    field :description, String.t()
    field :directives, [TypedGql.Language.Directive.t()], default: []
    field :loc, map(), default: %{line: nil, column: nil}
  end
end

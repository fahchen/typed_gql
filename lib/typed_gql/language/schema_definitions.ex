defmodule TypedGql.Language.SchemaDefinition do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :description, String.t()
    field :directives, [TypedGql.Language.Directive.t()], default: []
    field :fields, [TypedGql.Language.FieldDefinition.t()], default: []
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.SchemaDeclaration do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :description, String.t()
    field :directives, [TypedGql.Language.Directive.t()], default: []
    field :fields, [TypedGql.Language.FieldDefinition.t()], default: []
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.DirectiveDefinition do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :name, String.t()
    field :description, String.t()
    field :arguments, [TypedGql.Language.InputValueDefinition.t()], default: []
    field :directives, [TypedGql.Language.Directive.t()], default: []
    field :locations, [atom()], default: []
    field :repeatable, boolean(), default: false
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.TypeExtensionDefinition do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :definition, TypedGql.Language.ObjectTypeDefinition.t()
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.OperationDefinition do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :operation, atom()
    field :name, String.t()
    field :description, String.t()
    field :variable_definitions, [TypedGql.Language.VariableDefinition.t()], default: []
    field :directives, [TypedGql.Language.Directive.t()], default: []
    field :selection_set, TypedGql.Language.SelectionSet.t()
    field :shorthand, boolean()
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.SelectionSet do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :selections, [TypedGql.Language.selection_t()], default: []
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.Field do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :alias, String.t()
    field :name, String.t()
    field :arguments, [TypedGql.Language.Argument.t()], default: []
    field :directives, [TypedGql.Language.Directive.t()], default: []
    field :selection_set, TypedGql.Language.SelectionSet.t()
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.Argument do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :name, String.t()
    field :value, TypedGql.Language.value_t()
    field :loc, map() | tuple(), default: {}
  end
end

defmodule TypedGql.Language.Variable do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :name, String.t()
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.VariableDefinition do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :variable, TypedGql.Language.Variable.t()
    field :type, TypedGql.Language.type_reference_t()
    field :directives, [TypedGql.Language.Directive.t()], default: []
    field :default_value, TypedGql.Language.value_t()
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.Directive do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :name, String.t()
    field :arguments, [TypedGql.Language.Argument.t()], default: []
    field :loc, map()
  end
end

defmodule TypedGql.Language.Fragment do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :name, String.t()
    field :description, String.t()
    field :type_condition, TypedGql.Language.NamedType.t()
    field :directives, [TypedGql.Language.Directive.t()], default: []
    field :selection_set, TypedGql.Language.SelectionSet.t()
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.FragmentSpread do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :name, String.t()
    field :directives, [TypedGql.Language.Directive.t()], default: []
    field :loc, map(), default: %{line: nil}
  end
end

defmodule TypedGql.Language.InlineFragment do
  @moduledoc false
  use TypedStructor

  typed_structor do
    field :type_condition, TypedGql.Language.NamedType.t()
    field :directives, [TypedGql.Language.Directive.t()], default: []
    field :selection_set, TypedGql.Language.SelectionSet.t()
    field :loc, map(), default: %{line: nil}
  end
end

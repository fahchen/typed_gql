defmodule Grephql.Generation.Context do
  @moduledoc """
  Read-only context passed to `Grephql.Generation.Plugin` callbacks.

  Carries the schema and compile-time options the engine has available
  at every pipeline juncture. Per-node information (parent type, target
  module) lives on `Grephql.Generation.Schema` nodes, not here.
  """
  use TypedStructor

  alias Grephql.Schema

  typed_structor do
    field :schema, Schema.t(), enforce: true
    field :scalar_types, %{String.t() => module()}, default: %{}
    field :fragments, %{String.t() => map()}, default: %{}
  end
end

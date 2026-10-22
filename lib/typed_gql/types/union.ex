defmodule TypedGql.Types.Union do
  @moduledoc """
  Parameterized Ecto Type for GraphQL union/interface fields.

  Dispatches to the correct embedded schema module based on the
  `__typename` field in the JSON map. The field declares its members through
  the `:typename_to_module` option, a map of GraphQL `__typename` strings to
  the embedded schema modules that load them:

      field :search, {:array, TypedGql.Types.Union},
        typename_to_module: %{"User" => Result.Search.User, "Post" => Result.Search.Post}

  It uses `embed_as: :dump` so that `Ecto.embedded_load/3` calls `load/3`,
  which reads `__typename` and delegates to the matched module via
  `Ecto.embedded_load/3`.

  An unresolvable `__typename` returns `:error`, as the callback contract
  requires; Ecto turns that into its own `ArgumentError` naming the offending
  map, the field and the schema, so nothing is lost by not carrying a message.

  `cast/2` accepts the wire shape — a decoded JSON map with a string
  `"__typename"` — and reads the values inside the variant with load
  semantics, so an already-cast value such as an enum atom is not accepted.
  """

  use Ecto.ParameterizedType

  @typedoc "The members a field dispatches to, in both directions."
  @type params() :: %{
          typename_to_module: %{String.t() => module()},
          module_to_typename: %{module() => String.t()}
        }

  @impl Ecto.ParameterizedType
  def init(opts) do
    typename_to_module = Keyword.fetch!(opts, :typename_to_module)

    %{
      typename_to_module: typename_to_module,
      module_to_typename: Map.new(typename_to_module, fn {name, module} -> {module, name} end)
    }
  end

  @impl Ecto.ParameterizedType
  def type(_params), do: :map

  @impl Ecto.ParameterizedType
  def cast(nil, _params), do: {:ok, nil}

  # A struct is also a map, so this clause has to answer for non-members
  # itself: falling through to `cast(%{} = map, params)` would report them
  # as a missing `__typename` instead of rejecting them.
  def cast(%{__struct__: module} = struct, params) do
    if is_map_key(params.module_to_typename, module), do: {:ok, struct}, else: :error
  end

  def cast(%{} = map, params), do: load(map, nil, params)
  def cast(_other, _params), do: :error

  @impl Ecto.ParameterizedType
  def load(nil, _loader, _params), do: {:ok, nil}

  def load(%{} = map, _loader, params) do
    with {:ok, module} <- resolve_module(map, params) do
      {:ok, Ecto.embedded_load(module, map, :json)}
    end
  end

  def load(_other, _loader, _params), do: :error

  @impl Ecto.ParameterizedType
  def dump(nil, _dumper, _params), do: {:ok, nil}

  # Delegating to the variant's own dumpers is what makes the result
  # JSON-encodable: enums become strings and nested embeds become maps.
  # The struct's module is the variant's identity, so dump writes the
  # __typename back into the map — the struct itself carries the field only
  # when the query selected it, and without the key the dumped map could
  # never be loaded again.
  def dump(%{__struct__: module} = struct, _dumper, params) do
    case params.module_to_typename do
      %{^module => typename} ->
        {:ok, struct |> Ecto.embedded_dump(:json) |> Map.put(:__typename, typename)}

      _not_a_member ->
        :error
    end
  end

  def dump(_other, _dumper, _params), do: :error

  @impl Ecto.ParameterizedType
  def embed_as(_format, _params), do: :dump

  # Ecto prints a parameterized type's params in its load errors; an interface
  # with hundreds of members would bury the message, so name the typenames only.
  @impl Ecto.ParameterizedType
  def format(params) do
    "#TypedGql.Types.Union<#{params.typename_to_module |> Map.keys() |> Enum.sort() |> Enum.join(" | ")}>"
  end

  defp resolve_module(%{"__typename" => typename}, params),
    do: Map.fetch(params.typename_to_module, typename)

  # `Ecto.embedded_dump/2` emits atom keys, so a dumped union has to resolve
  # too. The guard keeps a loaded variant struct, whose `:__typename` is an
  # atom, out of this clause.
  defp resolve_module(%{__typename: typename}, params) when is_binary(typename),
    do: Map.fetch(params.typename_to_module, typename)

  defp resolve_module(_map, _params), do: :error
end

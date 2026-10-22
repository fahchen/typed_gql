# Unions and Interfaces

A field whose type is a union or an interface can return more than one object
type. TypedGql generates one struct per type the document declares, plus a
dispatcher that picks the struct from the response's `__typename`. Unions and
interfaces follow the same rules; the few places they differ are called out
below.

The examples use the GitHub schema in a client named `MyApp.GitHub`; module
names are shown relative to it.

## Declaring a variant

A type is declared by an inline fragment or a named fragment spread whose
condition names it:

```elixir
defgql :search, ~GQL"""
  query Search($q: String!) {
    search(query: $q, type: REPOSITORY, first: 10) {
      nodes {
        ... on User {
          name
        }
        ... on Repository {
          nameWithOwner
        }
      }
    }
  }
"""
```

`nodes` is a `SearchResultItem` union, so this generates a struct per declared
member and a dispatcher `Union` between them:

```elixir
# Search.Result
@type t() :: %Search.Result{search: Ecto.Schema.embeds_one(Search.Result.Search.t()) | nil}

# Search.Result.Search
@type t() :: %Search.Result.Search{nodes: [Search.Result.Search.Nodes.Union.t() | nil] | nil}

# Search.Result.Search.Nodes.Union
@type t() :: Search.Result.Search.Nodes.Repository.t() | Search.Result.Search.Nodes.User.t()

# Search.Result.Search.Nodes.User
@type t() :: %Search.Result.Search.Nodes.User{name: String.t() | nil}

# Search.Result.Search.Nodes.Repository
@type t() :: %Search.Result.Search.Nodes.Repository{name_with_owner: String.t()}
```

A condition on an abstract type declares every member of the field's type that
it covers. `RepositoryOwner` is implemented by `Organization` and `User`, so
this declares those two and no other `SearchResultItem` member:

```elixir
defgql :owners, ~GQL"""
  query Owners($q: String!) {
    search(query: $q, type: USER, first: 10) {
      nodes {
        ... on RepositoryOwner {
          login
        }
      }
    }
  }
"""
```

```elixir
# Owners.Result.Search.Nodes.Union
@type t() :: Owners.Result.Search.Nodes.Organization.t() | Owners.Result.Search.Nodes.User.t()

# Owners.Result.Search.Nodes.Organization
@type t() :: %Owners.Result.Search.Nodes.Organization{login: String.t()}

# Owners.Result.Search.Nodes.User
@type t() :: %Owners.Result.Search.Nodes.User{login: String.t()}
```

`... on Node { id }` there would declare every member, since all eight
implement `Node`.

Fields selected outside any fragment are shared: they are merged into every
variant's struct.

### Conditions that only select shared fields

On an interface field, a condition on the interface itself, or on another
interface that covers every member, adds shared fields and declares nothing.
These two selections generate the same modules:

```elixir
defgql :hoisted, ~GQL"""
  query Hoisted($id: ID!) {
    node(id: $id) {
      ... on Node { id }
      ... on User { name }
    }
  }
"""

defgql :shared, ~GQL"""
  query Shared($id: ID!) {
    node(id: $id) {
      id
      ... on User { name }
    }
  }
"""
```

Both declare only `User`, with `id` merged into it:

```elixir
# Hoisted.Result
@type t() :: %Hoisted.Result{node: Hoisted.Result.Node.Union.t() | nil}

# Hoisted.Result.Node.Union
@type t() :: Hoisted.Result.Node.User.t()

# Hoisted.Result.Node.User
@type t() :: %Hoisted.Result.Node.User{id: String.t(), name: String.t() | nil}
```

A union has no fields of its own, so a condition there always declares the
members it covers.

## Members the document does not declare

A member the document never declares gets no struct, so a response that
returns one cannot be loaded. The whole response then decodes to an error:

```elixir
{:error, %TypedGql.DecodeError{message: "cannot decode response data: " <> _reason}}
```

To make a member representable, declare it. `... on Repository { __typename }`
is enough.

## Selections that declare nothing

A selection with no fragment that declares a member generates one plain
embedded schema instead of a dispatcher:

```elixir
defgql :node_types, ~GQL"""
  query NodeTypes($ids: [ID!]!) {
    nodes(ids: $ids) {
      __typename
    }
  }
"""
```

```elixir
# NodeTypes.Result
@type t() :: %NodeTypes.Result{nodes: [NodeTypes.Result.Nodes.t() | nil]}

# NodeTypes.Result.Nodes
@type t() :: %NodeTypes.Result.Nodes{__typename: TypedGql.Types.Typename.t()}
```

```elixir
{:ok, result} = MyApp.GitHub.node_types(%{ids: ["1", "2"]})

result.data.nodes
#=> [
#     %MyApp.GitHub.NodeTypes.Result.Nodes{__typename: :user},
#     %MyApp.GitHub.NodeTypes.Result.Nodes{__typename: :repository},
#     nil
#   ]
```

`__typename` accepts any possible type of the field, as a snake_cased atom.
Since no member is declared, no response fails to load for naming one.

## Typespecs

The dispatcher's `t/0` names the variants it can return, in sorted order, as
`Search.Result.Search.Nodes.Union` above shows. A field holding the dispatcher
is typed `Union.t()`, so a result's typespec says which structs can come back.

# Unions and Interfaces

A field whose type is a union or an interface can return more than one object
type. TypedGql generates one struct per type the document declares, plus a
dispatcher that picks the struct from the response's `__typename`. Unions and
interfaces follow the same rules; the few places they differ are called out
below.

## Declaring a variant

A type is declared by an inline fragment or a named fragment spread whose
condition names it:

```elixir
defgql :search, ~GQL"""
  query Search($q: String!) {
    search(query: $q) {
      ... on User {
        name
      }
      ... on Repository {
        fullName
      }
    }
  }
"""
```

This generates `Search.Result.Search.User` and `Search.Result.Search.Repository`,
and a dispatcher `Search.Result.Search.Union`.

A condition on an abstract type declares every member of the field's type that
it covers. `... on Node { id }` over a `User | Repository` union declares both,
while `... on Named` over the same union declares only the members that
implement `Named`.

Fields selected outside any fragment are shared: they are merged into every
variant's struct.

### Conditions that only select shared fields

On an interface field, a condition on the interface itself, or on another
interface that covers every member, adds shared fields and declares nothing.
These two selections generate the same modules:

```graphql
node(id: $id) { ... on Node { id } ... on User { name } }
node(id: $id) { id ... on User { name } }
```

Both declare only `User`. A union has no fields of its own, so a condition
there always declares the members it covers.

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

The dispatcher's `t/0` names the variants it can return, in sorted order:

```elixir
@type t() :: Repository.t() | User.t()
```

A field holding the dispatcher is typed `Union.t()`, so a result's typespec
says which structs can come back.

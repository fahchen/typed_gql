# Generated Modules and Types

Each `defgql` generates typed Ecto embedded schema modules at compile time.
This guide covers where they live, how they are named, and how to read them.
Unions and interfaces have [their own guide](unions-and-interfaces.md).

## Module layout

Given `defgql :get_user` inside `MyApp.GitHub`:

| Type | Pattern | Example |
|------|---------|---------|
| Fragment | `Client.Fragments.Name` | `MyApp.GitHub.Fragments.UserFields` |
| Result | `Client.FnName.Result.Field...` | `MyApp.GitHub.GetUser.Result.User` |
| Nested field | `...Result.Field.NestedField` | `MyApp.GitHub.GetUser.Result.User.Posts` |
| Union variant | `...Result.Field.TypeName` | `MyApp.GitHub.Search.Result.Search.User` |
| Input types | `Client.Inputs.TypeName` | `MyApp.GitHub.Inputs.CreateIssueInput` |
| Variables | `Client.FnName.Variables` | `MyApp.GitHub.GetUser.Variables` |

## Naming rules

- Function name is CamelCased: `:get_user` -> `GetUser`
- Struct field names are snake_cased: `userName` -> `:user_name`
- Field aliases override both field name and module path: `author: user { ... }` -> field `:author`, module `...Result.Author`
- Fragment modules live under `Client.Fragments.*`
- Input types are shared across operations under `Client.Inputs.*`
- Variables are per-operation under `Client.FnName.Variables`

## Example

```elixir
defmodule MyApp.GitHub do
  use TypedGql, otp_app: :my_app, source: "schema.json"

  deffragment ~GQL"""
    fragment PostFields on Post {
      title
      body
    }
  """

  defgql :get_user, ~GQL"""
    query GetUser($id: ID!) {
      author: user(id: $id) {
        name
        posts {
          ...PostFields
        }
      }
    }
  """
end

# Generated modules:
# MyApp.GitHub.Fragments.PostFields         — %{title: String.t(), body: String.t()}
# MyApp.GitHub.GetUser.Result               — %{author: Author.t()}
# MyApp.GitHub.GetUser.Result.Author        — %{name: String.t(), posts: [Posts.t()]}
# MyApp.GitHub.GetUser.Result.Author.Posts   — %{title: String.t(), body: String.t()}
# MyApp.GitHub.GetUser.Variables            — %{id: String.t()}
```

The `posts: [Posts.t()]` above assumes the schema declares it `[Post!]!`. A list
typespec mirrors the schema's nullability at every level — `[Post]` generates
`[Posts.t() | nil] | nil` — and a nullable list's struct default is `nil`, not `[]`.

## Enums

GraphQL enums are automatically converted to snake_cased atoms:

```elixir
# GraphQL: enum Role { ADMIN, READ_ONLY }
# Elixir:  :admin, :read_only
```

Loading is case-insensitive — `"ADMIN"`, `"admin"`, and `"Admin"` all resolve to `:admin`.

Custom scalars map to whatever Ecto type you configure; see the
[custom scalars guide](mapping-custom-scalars.md).

## Access behaviour

All generated schemas implement the `Access` behaviour, so you can use bracket syntax and `get_in/2` alongside dot notation:

```elixir
{:ok, result} = MyApp.GitHub.get_user(%{login: "octocat"})

# Dot notation
result.data.user.name

# Bracket syntax
result.data.user[:name]

# Dynamic / nested access
get_in(result.data, [:user, :name])
```

This is powered by `TypedStructor.Plugins.Access`, which is registered in every generated `typed_embedded_schema` block.

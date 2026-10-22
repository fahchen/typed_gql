# TypedGql
[![Build Status](https://github.com/fahchen/typed_gql/actions/workflows/ci.yml/badge.svg)](https://github.com/fahchen/typed_gql/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/typed_gql)](https://hex.pm/packages/typed_gql)
[![HexDocs](https://img.shields.io/badge/HexDocs-gray)](https://hexdocs.pm/typed_gql)

Compile-time GraphQL client for Elixir. Parses and validates queries during compilation, generates typed Ecto embedded schemas for responses and variables, and executes queries at runtime via [Req](https://github.com/wojtekmach/req).

## Features

- **Compile-time validation** — Syntax errors, schema mismatches, and deprecated usage caught at `mix compile`, with errors pointing to file:line:column in your Elixir source
- **Minimal code generation** — Only generates modules for types actually referenced in your queries, not the entire schema
- **Zero runtime parsing** — All GraphQL parsing happens at compile time
- **Typed responses** — JSON responses are cast into typed Ecto embedded schemas, accessible via dot notation, `[:field]`, and `get_in` ([Generated Modules and Types](guides/generated-types.md))
- **Typed variables** — Input validation via Ecto changesets with generated `params()` type ([Writing Operations](guides/writing-operations.md))
- **Union / Interface support** — Automatic type dispatch on `__typename` ([Unions and Interfaces](guides/unions-and-interfaces.md))
- **Custom scalars** — Map any scalar to an Ecto type; common ones are built in ([Mapping Custom Scalars](guides/mapping-custom-scalars.md))
- **Req integration** — Full access to Req's middleware/plugin system, test with `Req.Test` directly ([Testing](guides/testing.md))
- **Response metadata** — Capture arbitrary response metadata (e.g. GraphQL `extensions`) via `prepare_req/1` callback and `Result.assigns` ([Customizing Requests](guides/extending-requests-with-prepare-req.md))
- **Configurable JSON library** — Defaults to Elixir 1.18+ built-in `JSON`, falls back to `Jason`, or set your own via `:json_library`
- **Auto-generated docs** — `defgql` functions include `@doc` with variables, types, and generated module listing

## Installation

Add `typed_gql` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:typed_gql, "~> 0.13.0"}
  ]
end
```

## Quick Start

### 1. Download your schema

```bash
mix typed_gql.download_schema \
  --endpoint https://api.example.com/graphql \
  --output priv/schemas/schema.json \
  --header "Authorization: Bearer token123"
```

`mix typed_gql.download_schema` saves the schema via introspection:

| Option | Required | Description |
|--------|----------|-------------|
| `--endpoint` / `-e` | yes | GraphQL endpoint URL |
| `--output` / `-o` | yes | File path to save the schema JSON |
| `--header` / `-h` | no | HTTP header in `"Key: Value"` format (repeatable) |

### 2. Define a client module

```elixir
defmodule MyApp.GitHub do
  use TypedGql,
    otp_app: :my_app,
    source: "priv/schemas/github.json",
    endpoint: "https://api.github.com/graphql"

  defgql :get_user, ~GQL"""
    query GetUser($login: String!) {
      user(login: $login) {
        name
        bio
      }
    }
  """

  defgql :get_viewer, ~GQL"""
    query {
      viewer {
        login
        email
      }
    }
  """
end
```

### 3. Call the generated functions

```elixir
# With variables — validates input before sending
case MyApp.GitHub.get_user(%{login: "octocat"}) do
  {:ok, result} ->
    result.data.user.name  #=> "The Octocat"

  {:error, %Ecto.Changeset{} = changeset} ->
    # Variable validation failed
    changeset.errors

  {:error, %Req.Response{} = response} ->
    # HTTP error
    response.status

  {:error, %TypedGql.DecodeError{} = error} ->
    # The server answered 2xx with data the result schema cannot load
    error.message
end

# Without variables
{:ok, result} = MyApp.GitHub.get_viewer()
result.data.viewer.login
```

## Macros

A tour of the three macros follows; `TypedGql.Macros` documents each one in full.

### `defgql` / `defgqlp`

Defines a public (or private) GraphQL query function. At compile time: parses, validates, generates typed modules, and defines a callable function.

```elixir
# Public — generates def get_user/2
defgql :get_user, ~GQL"""
  query GetUser($id: ID!) {
    user(id: $id) { name }
  }
"""

# Private — generates defp get_user/2
defgqlp :get_user, ~GQL"""
  query GetUser($id: ID!) {
    user(id: $id) { name }
  }
"""
```

`defgql` functions automatically include `@doc` with operation info, variable table, and all generated module names.

### `deffragment`

Defines a reusable named fragment. The fragment name comes from the GraphQL definition itself, so `deffragment` only takes the fragment string. Fragments are validated at compile time and automatically appended to queries that reference them via `...FragmentName`.

```elixir
deffragment ~GQL"""
  fragment UserFields on User {
    name
    email
    createdAt
  }
"""

defgql :get_user, ~GQL"""
  query GetUser($id: ID!) {
    user(id: $id) {
      ...UserFields
    }
  }
"""
```

The fragment generates a typed module at `Client.Fragments.UserFields` — an embedded schema for an object condition, or, when the condition resolves to per-member selections, a module whose `t/0` is the union of the per-member schemas at `Client.Fragments.UserFields.TypeName`.

`defgql` only sees fragments defined before it in the module, and a fragment body may only spread fragments defined above it — spreading one defined later is a compile error. If the same name is defined several times before a query, the latest definition wins for that query. See `TypedGql.Macros.deffragment/1` for why the macro model requires this while GraphQL itself does not.

## Configuration

Configuration is resolved in order (later wins): compile-time defaults -> runtime config -> per-call opts.

### Compile-time (in `use`)

```elixir
use TypedGql,
  otp_app: :my_app,
  source: "priv/schemas/github.json",
  endpoint: "https://api.github.com/graphql",
  req_options: [receive_timeout: 30_000],
  scalars: %{"DateTime" => TypedGql.Types.DateTime}
```

### Runtime (application config)

```elixir
# config/runtime.exs
config :my_app, MyApp.GitHub,
  endpoint: "https://api.github.com/graphql",
  req_options: [auth: {:bearer, System.fetch_env!("GITHUB_TOKEN")}]
```

### Per-call

```elixir
MyApp.GitHub.get_user(%{login: "octocat"},
  endpoint: "https://other.api.com/graphql",
  req_options: [receive_timeout: 60_000]
)
```

### `use TypedGql` options

| Option | Required | Description |
|--------|----------|-------------|
| `:otp_app` | yes | OTP application for runtime config lookup |
| `:source` | yes | Path to introspection JSON (relative to caller file) or inline JSON string |
| `:endpoint` | no | Default GraphQL endpoint URL. The URL may also come from `req_options` (`:url`/`:base_url`) or `prepare_req/1`, both of which take precedence over it |
| `:req_options` | no | Default [Req options](https://hexdocs.pm/req/Req.html#new/1) (keyword list) |
| `:scalars` | no | Map of GraphQL scalar name to Ecto type (default: `%{}`) |
| `:generation_plugins` | no | Extra `TypedGql.Generation.Plugin` modules, run after the built-in ones |

### JSON library

Defaults to Elixir 1.18+ built-in `JSON`, falls back to `Jason`. To override:

```elixir
config :typed_gql, :json_library, Jason
```

Any module implementing `encode!/1` and `decode/1` works.

## Guides

- [Writing Operations](guides/writing-operations.md) — the `~GQL` sigil and formatter, field aliases, variables, mutations and input types
- [Generated Modules and Types](guides/generated-types.md) — module layout, naming rules, enums, `Access`
- [Unions and Interfaces](guides/unions-and-interfaces.md) — which variants are generated and how they are typed
- [Mapping Custom Scalars](guides/mapping-custom-scalars.md) — built-in scalars and writing your own `Ecto.Type`
- [Customizing Requests with `prepare_req`](guides/extending-requests-with-prepare-req.md) — Req steps, headers, response metadata
- [Testing](guides/testing.md) — stubbing with `Req.Test` and telling requests apart

## Requirements

- Elixir ~> 1.15
- Erlang/OTP 26+ (the oldest pair covered by CI)

## License

See [LICENSE](LICENSE) for details.

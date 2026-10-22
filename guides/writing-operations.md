# Writing Operations

How queries and mutations are written inside a client module: the `~GQL` sigil,
field aliases, variables, and input types. `TypedGql.Macros` documents
`defgql`, `defgqlp` and `deffragment` in full.

## The `~GQL` sigil and formatter

The `~GQL` sigil marks GraphQL strings for automatic formatting by `mix format`. Plain strings still work with `defgql` — `~GQL` is optional.

Add the formatter plugin to your `.formatter.exs`:

```elixir
[
  plugins: [TypedGql.Formatter],
  # ...
]
```

Or via dependency import:

```elixir
[
  import_deps: [:typed_gql],
  # ...
]
```

Before and after `mix format`:

```elixir
# Before
defgql :get_user, ~GQL"query GetUser($id: ID!) { user(id: $id) { name email posts { title } } }"

# After mix format
defgql :get_user, ~GQL"""
  query GetUser($id: ID!) {
    user(id: $id) {
      name
      email
      posts {
        title
      }
    }
  }
"""
```

## Field aliases

GraphQL aliases affect both the struct field name and the module path:

```elixir
defgql :get_account, ~GQL"""
  query {
    account: user(login: "alice") {
      displayName: name
    }
  }
"""

{:ok, result} = MyApp.GitHub.get_account()
result.data.account.display_name  # alias becomes the field name
```

## Variables

Each operation with variables gets a `Client.FnName.Variables` module. Calls
run the caller's map through it before any request is sent, and it can be used
standalone to validate or inspect a payload:

```elixir
# Same validation the client performs on every call
{:ok, vars} = MyApp.GitHub.GetUser.Variables.build(%{id: "U_1"})
{:error, changeset} = MyApp.GitHub.GetUser.Variables.build(%{})
Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
#=> %{id: ["can't be blank"]}

# Params use the snake_cased names; the GraphQL name is kept for serialization
MyApp.GitHub.GetUser.Variables.__schema__(:fields)  #=> [:id]
```

Variables are per-operation, so two operations declaring `$id: ID!` get
separate modules — unlike input types, which are shared.

## Mutations and input types

`defgql` works the same for mutations. GraphQL input object types become
shared modules under `Client.Inputs.*`:

```elixir
defgql :create_issue, ~GQL"""
  mutation CreateIssue($input: CreateIssueInput!) {
    createIssue(input: $input) {
      issue {
        number
        title
        state
      }
    }
  }
"""
```

```elixir
# Plain maps are validated against the generated input schema.
# Params use the snake_cased field names, not the GraphQL spelling.
{:ok, result} =
  MyApp.GitHub.create_issue(%{input: %{repository_id: "R_1", title: "Bug"}})

result.data.create_issue.issue.state  #=> :open

# Missing required fields fail before any request is sent
{:error, changeset} = MyApp.GitHub.create_issue(%{input: %{}})
Ecto.Changeset.traverse_errors(changeset.changes.input, fn {msg, _opts} -> msg end)
#=> %{repository_id: ["can't be blank"], title: ["can't be blank"]}
```

The generated input module can also be used directly — `build/1` returns
`{:ok, struct}` or `{:error, changeset}`, and nested input objects are
embedded:

```elixir
{:ok, input} =
  MyApp.GitHub.Inputs.CreateIssueInput.build(%{
    repository_id: "R_1",
    title: "Bug",
    body: "Steps to reproduce...",
    label_ids: ["L_1", "L_2"]
  })

{:ok, result} = MyApp.GitHub.create_issue(%{input: input})
```

Input modules are shared across the whole client, so two operations using
`CreateIssueInput` refer to the same module. See
`examples/github_client.exs` for a runnable version.

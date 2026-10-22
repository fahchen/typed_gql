# Testing

TypedGql executes requests through [Req](https://hexdocs.pm/req), so tests stub
the HTTP layer with `Req.Test` and make no network calls.

## Stubbing responses

Point the client at a `Req.Test` stub in test config:

```elixir
# config/test.exs
config :my_app, MyApp.GitHub,
  req_options: [plug: {Req.Test, MyApp.GitHub}]
```

```elixir
test "get_user returns user data" do
  Req.Test.stub(MyApp.GitHub, fn conn ->
    Req.Test.json(conn, %{
      "data" => %{"user" => %{"name" => "Alice", "bio" => "Elixirist"}}
    })
  end)

  assert {:ok, result} = MyApp.GitHub.get_user(%{login: "alice"})
  assert result.data.user.name == "Alice"
end
```

## Telling requests apart

When several `defgql` functions share one stub, attach
`TypedGql.OperationInfo` so the stub can branch on which function made the
request:

```elixir
defmodule MyApp.GitHub do
  use TypedGql, otp_app: :my_app, source: "priv/schemas/github.json"

  # opt in for tests only
  if Mix.env() == :test do
    def prepare_req(req), do: TypedGql.OperationInfo.attach(req)
  end

  # ...
end
```

```elixir
test "page loads user and posts" do
  Req.Test.expect(MyApp.GitHub, 2, fn conn ->
    case TypedGql.OperationInfo.get(conn).function do
      "get_user" -> Req.Test.json(conn, %{"data" => %{"user" => %{"name" => "Alice"}}})
      "list_posts" -> Req.Test.json(conn, %{"data" => %{"posts" => []}})
    end
  end)

  # ... code that calls both MyApp.GitHub.get_user/1 and list_posts/1
end
```

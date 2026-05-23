defmodule TypedGql.Test.TypespecFixture do
  @moduledoc false
  use TypedGql,
    otp_app: :typed_gql,
    source: "schemas/integration.json",
    endpoint: "https://api.example.com/graphql"

  defgql(:get_user, """
  query GetUser($id: ID!, $show: Boolean!) {
    user(id: $id) {
      id @include(if: $show)
      name
    }
  }
  """)
end

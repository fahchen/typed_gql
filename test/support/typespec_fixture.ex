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
      posts {
        title
      }
    }
  }
  """)

  defgql(:embed_types, """
  query EmbedTypes($id: ID!, $flag: Boolean!) {
    user(id: $id) {
      profile { bio }
      posts {
        author { posts { author { id } } }
        included: author @include(if: $flag) { id }
        skipped: author @skip(if: $flag) { id }
        ... on Post @include(if: $flag) { conditional: author { id } }
      }
    }
  }
  """)

  defgql(:list_drafts, """
  query ListDrafts {
    drafts {
      title
    }
  }
  """)

  defgql(:list_nodes, """
  query ListNodes($ids: [ID!]!) {
    nodes(ids: $ids) {
      __typename
      ... on User {
        name
      }
    }
  }
  """)

  defgql(:list_users_and_posts, """
  query ListUsersAndPosts($ids: [ID!]!) {
    nodes(ids: $ids) {
      __typename
      ... on User {
        name
      }
      ... on Post {
        title
      }
    }
  }
  """)

  defgql(:list_node_types, """
  query ListNodeTypes($ids: [ID!]!) {
    nodes(ids: $ids) {
      id
      __typename
    }
  }
  """)

  defgql(:search_users_and_posts, """
  query SearchUsersAndPosts($term: String!) {
    search(query: $term) {
      ... on User {
        name
      }
      ... on Post {
        title
      }
    }
  }
  """)

  deffragment("""
  fragment SearchBits on SearchResult {
    ... on User {
      name
    }
    ... on Post {
      title
    }
  }
  """)

  deffragment("""
  fragment NodeBits on Node {
    ... on User {
      name
    }
  }
  """)

  defgql(:search_types, """
  query SearchTypes($term: String!) {
    search(query: $term) {
      __typename
    }
  }
  """)
end

defmodule TypedGql.Test.InputTypespecFixture do
  @moduledoc false
  use TypedGql,
    otp_app: :typed_gql,
    source: "schemas/github.json",
    endpoint: "https://api.example.com/graphql",
    scalars: %{"GitObjectID" => :string}

  defgql(:create_commit, """
  mutation CreateCommit($input: CreateCommitOnBranchInput!) {
    createCommitOnBranch(input: $input) { clientMutationId }
  }
  """)
end

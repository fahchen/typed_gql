defmodule TypedGql.Generation.TypespecTest do
  use ExUnit.Case, async: true

  # Asserts the *generated* @type, not just the generation IR. This is only
  # possible because TypedGql.Test.TypespecFixture is a compiled .ex client
  # (test/support/typespec_fixture.ex): Code.Typespec.fetch_types/1 reads from
  # the .beam, which exists for compile-time-generated modules but not for the
  # in-memory modules the other generation tests build at runtime.
  test "@include makes a non-null field nullable in the generated @type" do
    rendered = generated_t(TypedGql.Test.TypespecFixture.GetUser.Result.User)

    # id is ID! but carries @include(if: $show) -> nullable in the generated type.
    assert rendered =~ "id: String.t() | nil"
    # name is non-null and undirected -> stays non-null.
    assert rendered =~ "name: String.t()"
    refute rendered =~ "name: String.t() | nil"
  end

  test "a [T!]! object list keeps the embeds_many type" do
    rendered = generated_t(TypedGql.Test.TypespecFixture.GetUser.Result.User)

    # Ecto.Schema.embeds_many(t) expands to [t], so [Post!]! keeps its embed.
    assert rendered =~
             "posts: Ecto.Schema.embeds_many(TypedGql.Test.TypespecFixture.GetUser.Result.User.Posts.t())"
  end

  test "a nullable object list is nullable in both the list and its elements" do
    rendered = generated_t(TypedGql.Test.TypespecFixture.ListDrafts.Result)

    # drafts is [Post] — the whole list and every element may be null.
    assert rendered =~
             "drafts: [TypedGql.Test.TypespecFixture.ListDrafts.Result.Drafts.t() | nil] | nil"
  end

  # nodes is [Node]! — the list itself cannot be null, its elements can. The
  # document declares `... on User` and nothing else, so an element can only
  # ever be a User and the field says so: no dispatcher module stands between.
  test "an interface field is typed as the variant it declares" do
    alias TypedGql.Test.TypespecFixture.ListNodes.Result

    assert rendered_t(Result) ==
             "t() :: %#{inspect(Result)}{ nodes: [#{inspect(Result.Nodes.User)}.t() | nil] }"

    refute Code.ensure_loaded?(Result.Nodes.Post)
  end

  test "an interface field declaring several members is typed as their union" do
    alias TypedGql.Test.TypespecFixture.ListUsersAndPosts.Result

    assert rendered_t(Result) ==
             "t() :: %#{inspect(Result)}{ nodes: [ (#{inspect(Result.Nodes.Post)}.t() | " <>
               "#{inspect(Result.Nodes.User)}.t()) | nil ] }"

    refute Code.ensure_loaded?(Result.Nodes.Union)

    data = %{
      "nodes" => [
        %{"__typename" => "User", "name" => "Alice"},
        %{"__typename" => "Post", "title" => "Hello"},
        nil
      ]
    }

    assert %Result{
             nodes: [%Result.Nodes.User{name: "Alice"}, %Result.Nodes.Post{title: "Hello"}, nil]
           } =
             TypedGql.ResponseDecoder.decode!(Result, data)
  end

  test "a union field declaring several members is typed as their union" do
    alias TypedGql.Test.TypespecFixture.SearchUsersAndPosts.Result

    assert rendered_t(Result) ==
             "t() :: %#{inspect(Result)}{ search: [ #{inspect(Result.Search.Post)}.t() | " <>
               "#{inspect(Result.Search.User)}.t() ] }"

    refute Code.ensure_loaded?(Result.Search.Union)

    data = %{
      "search" => [
        %{"__typename" => "Post", "title" => "Hello"},
        %{"__typename" => "User", "name" => "Alice"}
      ]
    }

    assert %Result{
             search: [%Result.Search.Post{title: "Hello"}, %Result.Search.User{name: "Alice"}]
           } =
             TypedGql.ResponseDecoder.decode!(Result, data)
  end

  # A fragment has no field to carry a dispatching type, so its own module only
  # names the union its per-member schemas make up.
  test "a fragment on a union names its variants' union" do
    alias TypedGql.Test.TypespecFixture.Fragments.SearchBits

    assert rendered_t(SearchBits) ==
             "t() :: #{inspect(SearchBits.Post)}.t() | #{inspect(SearchBits.User)}.t()"

    refute function_exported?(SearchBits, :__schema__, 1)
  end

  test "a fragment on an interface names the variant it declares" do
    alias TypedGql.Test.TypespecFixture.Fragments.NodeBits

    assert rendered_t(NodeBits) == "t() :: #{inspect(NodeBits.User)}.t()"
    refute function_exported?(NodeBits, :__schema__, 1)
  end

  # No fragment declares a member, so an interface field generates one plain
  # struct of the shared fields and no dispatcher.
  test "an interface selected without fragments is one plain struct" do
    alias TypedGql.Test.TypespecFixture.ListNodeTypes.Result

    assert rendered_t(Result) ==
             "t() :: %#{inspect(Result)}{ nodes: [#{inspect(Result.Nodes)}.t() | nil] }"

    assert rendered_t(Result.Nodes) ==
             "t() :: %#{inspect(Result.Nodes)}{ __typename: TypedGql.Types.Typename.t(), id: String.t() }"

    data = %{"nodes" => [%{"id" => "1", "__typename" => "User"}, nil]}

    assert TypedGql.ResponseDecoder.decode!(Result, data) ==
             %Result{nodes: [%Result.Nodes{id: "1", __typename: :user}, nil]}
  end

  # A union has no fields of its own, so `__typename` is all it can select
  # without a fragment.
  test "a union selected without fragments is one plain struct" do
    alias TypedGql.Test.TypespecFixture.SearchTypes.Result

    assert rendered_t(Result) ==
             "t() :: %#{inspect(Result)}{ search: Ecto.Schema.embeds_many(#{inspect(Result.Search)}.t()) }"

    assert rendered_t(Result.Search) ==
             "t() :: %#{inspect(Result.Search)}{ __typename: TypedGql.Types.Typename.t() }"

    assert TypedGql.ResponseDecoder.decode!(Result, %{"search" => [%{"__typename" => "Post"}]}) ==
             %Result{search: [%Result.Search{__typename: :post}]}
  end

  defp generated_t(module) do
    {:ok, types} = Code.Typespec.fetch_types(module)

    types
    |> Enum.map(fn {_kind, type} -> Macro.to_string(Code.Typespec.type_to_quoted(type)) end)
    |> Enum.find(&String.starts_with?(&1, "t() ::"))
  end

  # `Macro.to_string/1` breaks a long union across lines, so assertions read the
  # one-line rendering rather than its wrapping.
  defp rendered_t(module) do
    module |> generated_t() |> String.split() |> Enum.join(" ")
  end
end

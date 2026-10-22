defmodule TypedGql.Types.UnionTest do
  use ExUnit.Case, async: true

  alias TypedGql.Test.UnionTypes.Address
  alias TypedGql.Test.UnionTypes.BareUser
  alias TypedGql.Test.UnionTypes.Post
  alias TypedGql.Test.UnionTypes.User
  alias TypedGql.Types.Union

  @search Union.init(typename_to_module: %{"User" => User, "Post" => Post})
  @bare Union.init(typename_to_module: %{"User" => BareUser})

  describe "load/3" do
    test "loads User map by __typename" do
      map = %{"__typename" => "User", "name" => "Alice", "email" => "a@b.com"}

      assert {:ok, %User{__typename: :user}} =
               Union.load(map, nil, @search)
    end

    test "loads Post map by __typename" do
      map = %{"__typename" => "Post", "title" => "Hello"}

      assert {:ok, %Post{__typename: :post, title: "Hello"}} =
               Union.load(map, nil, @search)
    end

    test "returns nil for nil input" do
      assert {:ok, nil} = Union.load(nil, nil, @search)
    end

    test "returns error for missing __typename" do
      assert :error = Union.load(%{"name" => "X"}, nil, @search)
    end

    test "returns error for unknown __typename" do
      assert :error = Union.load(%{"__typename" => "Comment"}, nil, @search)
    end

    test "loads a map whose __typename key is an atom, as Ecto's dumper emits" do
      assert {:ok, %User{__typename: :user, name: "Alice"}} =
               Union.load(%{__typename: "User", name: "Alice"}, nil, @search)
    end
  end

  describe "cast/2" do
    test "casts map by __typename" do
      map = %{"__typename" => "User", "name" => "Bob"}

      assert {:ok, %User{__typename: :user, name: "Bob"}} =
               Union.cast(map, @search)
    end

    test "passes through existing struct" do
      struct = %User{name: "Alice"}
      assert {:ok, ^struct} = Union.cast(struct, @search)
    end

    test "rejects a struct that is not a union member" do
      assert :error = Union.cast(%Address{zip: "12345"}, @search)
    end

    test "casts nil" do
      assert {:ok, nil} = Union.cast(nil, @search)
    end
  end

  describe "dump/3" do
    test "dumps struct to map" do
      struct = %User{name: "Alice", email: "a@b.com"}
      assert {:ok, map} = Union.dump(struct, nil, @search)
      assert map.name == "Alice"
      assert map.email == "a@b.com"
    end

    test "dumps through the variant's own field dumpers" do
      {:ok, user} =
        Union.load(
          %{"__typename" => "User", "role" => "ADMIN", "address" => %{"zip" => "12345"}},
          nil,
          @search
        )

      assert {:ok, map} = Union.dump(user, nil, @search)
      assert map.__typename == "User"
      assert map.role == "ADMIN"
      assert map.address == %{zip: "12345"}
      assert {:ok, _json} = Jason.encode(map)
    end

    test "round-trips back to the loaded struct" do
      {:ok, user} =
        Union.load(%{"__typename" => "User", "name" => "Alice"}, nil, @search)

      assert {:ok, dumped} = Union.dump(user, nil, @search)
      assert {:ok, ^user} = Union.load(dumped, nil, @search)
    end

    test "rejects a struct that is not a union member" do
      assert :error = Union.dump(%Address{zip: "12345"}, nil, @search)
    end

    test "dumps nil" do
      assert {:ok, nil} = Union.dump(nil, nil, @search)
    end

    test "a variant without a __typename field still round-trips through dump" do
      {:ok, user} = Union.load(%{"__typename" => "User", "name" => "Alice"}, nil, @bare)

      assert {:ok, dumped} = Union.dump(user, nil, @bare)
      assert dumped.__typename == "User"
      assert {:ok, ^user} = Union.load(dumped, nil, @bare)
    end
  end

  describe "anything but a map or nil" do
    test "is stored as a map" do
      assert Union.type(@search) == :map
    end

    test "is refused by cast, load and dump" do
      assert :error = Union.cast("User", @search)
      assert :error = Union.load([], nil, @search)
      assert :error = Union.dump(%{"__typename" => "User"}, nil, @search)
    end
  end

  describe "init/1" do
    test "keeps the members both ways" do
      assert @search.typename_to_module == %{"User" => User, "Post" => Post}
      assert @search.module_to_typename == %{User => "User", Post => "Post"}
    end
  end

  describe "format/1" do
    test "names the typenames, not the whole params" do
      assert Union.format(@search) == "#TypedGql.Types.Union<Post | User>"
    end
  end

  describe "embed_as/2" do
    test "returns :dump" do
      assert :dump == Union.embed_as(:json, @search)
    end
  end
end

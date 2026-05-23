defmodule Grephql.Generation.TypespecTest do
  use ExUnit.Case, async: true

  # Asserts the *generated* @type, not just the generation IR. This is only
  # possible because Grephql.Test.TypespecFixture is a compiled .ex client
  # (test/support/typespec_fixture.ex): Code.Typespec.fetch_types/1 reads from
  # the .beam, which exists for compile-time-generated modules but not for the
  # in-memory modules the other generation tests build at runtime.
  test "@include makes a non-null field nullable in the generated @type" do
    rendered = generated_t(Grephql.Test.TypespecFixture.GetUser.Result.User)

    # id is ID! but carries @include(if: $show) -> nullable in the generated type.
    assert rendered =~ "id: String.t() | nil"
    # name is non-null and undirected -> stays non-null.
    assert rendered =~ "name: String.t()"
    refute rendered =~ "name: String.t() | nil"
  end

  defp generated_t(module) do
    {:ok, types} = Code.Typespec.fetch_types(module)

    types
    |> Enum.map(fn {_kind, type} -> Macro.to_string(Code.Typespec.type_to_quoted(type)) end)
    |> Enum.find(&String.starts_with?(&1, "t() ::"))
  end
end

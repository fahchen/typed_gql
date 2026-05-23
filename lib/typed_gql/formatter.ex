defmodule TypedGql.Formatter do
  @moduledoc """
  Formatter plugin for the `~GQL` sigil.

  Formats GraphQL code inside `~GQL` sigils when running `mix format`.

  ## Setup

  Add to your `.formatter.exs`:

      [
        plugins: [TypedGql.Formatter],
        # ...
      ]

  Or if using TypedGql as a dependency:

      [
        import_deps: [:typed_gql],
        # ...
      ]
  """

  @behaviour Mix.Tasks.Format

  @impl Mix.Tasks.Format
  def features(_opts) do
    [sigils: [:GQL]]
  end

  @impl Mix.Tasks.Format
  def format(contents, opts) do
    case TypedGql.Parser.parse(contents) do
      {:ok, document} ->
        if opts[:opening_delimiter] in ["\"\"\"", "'''"] do
          TypedGql.Printer.print(document) <> "\n"
        else
          # Inline sigils have no indentation context — keep original content
          contents
        end

      {:error, _reason} ->
        contents
    end
  rescue
    # Parser.parse/1 raises FunctionClauseError on edge cases like empty strings
    FunctionClauseError -> contents
  end
end

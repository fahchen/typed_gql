# Used by "mix format"
typed_gql_locals = [
  deffragment: 1,
  defgql: 2,
  defgqlp: 2
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:ecto, :typed_structor, :ecto_typed_schema],
  locals_without_parens: typed_gql_locals,
  plugins: [TypedGql.Formatter],
  export: [
    locals_without_parens: typed_gql_locals,
    plugins: [TypedGql.Formatter]
  ]
]

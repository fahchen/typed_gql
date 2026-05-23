defmodule TypedGql.Test.Response.ScalarUser do
  @moduledoc false
  use TypedGql.EmbeddedSchema

  typed_embedded_schema do
    field :name, :string, typed: [null: false]
    field :email, :string, typed: [null: true]
  end
end

defmodule TypedGql.Test.Response.NumericFields do
  @moduledoc false
  use TypedGql.EmbeddedSchema

  typed_embedded_schema do
    field :age, :integer, typed: [null: false]
    field :score, :float, typed: [null: false]
  end
end

defmodule TypedGql.Test.Response.BooleanField do
  @moduledoc false
  use TypedGql.EmbeddedSchema

  typed_embedded_schema do
    field :active, :boolean, typed: [null: false]
  end
end

defmodule TypedGql.Test.Response.Profile do
  @moduledoc false
  use TypedGql.EmbeddedSchema

  typed_embedded_schema do
    field :bio, :string, typed: [null: true]
  end
end

defmodule TypedGql.Test.Response.UserWithProfile do
  @moduledoc false
  use TypedGql.EmbeddedSchema

  typed_embedded_schema do
    field :name, :string, typed: [null: false]
    embeds_one :profile, TypedGql.Test.Response.Profile, typed: [null: true]
  end
end

defmodule TypedGql.Test.Response.Post do
  @moduledoc false
  use TypedGql.EmbeddedSchema

  typed_embedded_schema do
    field :title, :string, typed: [null: false]
  end
end

defmodule TypedGql.Test.Response.UserWithPosts do
  @moduledoc false
  use TypedGql.EmbeddedSchema

  typed_embedded_schema do
    field :name, :string, typed: [null: false]
    embeds_many :posts, TypedGql.Test.Response.Post, typed: []
  end
end

defmodule TypedGql.Test.Response.DeepAuthor do
  @moduledoc false
  use TypedGql.EmbeddedSchema

  typed_embedded_schema do
    field :name, :string, typed: [null: false]
  end
end

defmodule TypedGql.Test.Response.DeepPost do
  @moduledoc false
  use TypedGql.EmbeddedSchema

  typed_embedded_schema do
    field :title, :string, typed: [null: false]
    embeds_one :author, TypedGql.Test.Response.DeepAuthor, typed: []
  end
end

defmodule TypedGql.Test.Response.UserWithDeepPosts do
  @moduledoc false
  use TypedGql.EmbeddedSchema

  typed_embedded_schema do
    field :name, :string, typed: [null: false]
    embeds_many :posts, TypedGql.Test.Response.DeepPost, typed: []
  end
end

defmodule TypedGql.Test.Response.UserWithRole do
  @moduledoc false
  use TypedGql.EmbeddedSchema

  typed_embedded_schema do
    field :name, :string, typed: [null: false]
    field :role, TypedGql.Types.Enum, values: ["ADMIN", "USER", "GUEST"], typed: [null: true]
  end
end

defmodule TypedGql.Test.Response.WithDateTime do
  @moduledoc false
  use TypedGql.EmbeddedSchema

  typed_embedded_schema do
    field :name, :string, typed: [null: false]
    field :created_at, TypedGql.Types.DateTime, typed: [null: true]
  end
end

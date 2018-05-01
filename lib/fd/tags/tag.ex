defmodule Fd.Tags.Tag do
  use Ecto.Schema
  import Ecto.Changeset
  alias Fd.Tags.Tag


  schema "tags" do
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(%Tag{} = tag, attrs) do
    tag
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end

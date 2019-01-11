defmodule Fd.Tags.Tag do
  use Ecto.Schema
  import Ecto.Changeset
  alias Fd.Tags.Tag

  schema "tags" do
    field :name, :string
    field :description, :string, default: ""

    # When listing instances with this tag, also include instances tagged with other tags id.
    field :includes, {:array, :integer}, default: []

    # If a canonical tag is set, all user facing requests to the tag 
    belongs_to :canonical, Fd.Tags.Tag
    #has_many :aliases, Fd.Tags.Tag

    has_many :taggings, Fd.Tags.Tagging
    many_to_many :instances, Fd.Instances.Instance, join_through: "taggings"

    timestamps()
  end

  @doc false
  def changeset(%Tag{} = tag, attrs) do
    tag
    |> Fd.Repo.preload(:canonical)
    |> cast(attrs, [:name, :description, :includes])
    |> validate_required([:name])
    |> validate_format(:name, ~r/[a-zA-Z0-9]/)
    |> put_canonical(attrs["canonical_id"])
    |> unique_constraint(:name)
  end

  def put_canonical(changeset, tag) do
    tag = case tag do
      tag when is_integer(tag) ->
        Fd.Tags.get_tag!(tag)
      tag when is_binary(tag) ->
        [tag | _] = parse_tags(%{"tags" => tag})
        tag
      nil ->
        IO.puts "canonical nil"
        nil
    end
    if tag do
      IO.puts "Canonical => #{inspect tag}"
      changeset
      |> put_change(:canonical_id, tag.id)
      |> put_assoc(:canonical, tag)
      |> IO.inspect()
    else
      changeset
    end
  end

  def put_tags(changeset, params = %{}) do
    put_assoc(changeset, :tags, parse_tags(params))
  end

  def parse_tags(params) do
    case params["tags"] do
      string when is_binary(string) ->
        string
        |> String.split(",")
      list when is_list(list) -> list
      _ -> []
    end
    |> Enum.map(&String.trim/1)
    |> Enum.reject(& &1 == "")
    |> Enum.map(&Fd.Tags.get_or_create_tag/1)
    |> IO.inspect()
    |> Enum.uniq()
  end


end

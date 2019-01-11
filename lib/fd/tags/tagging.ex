defmodule Fd.Tags.Tagging do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  schema "taggings" do
    belongs_to :tag, Fd.Tags.Tag
    belongs_to :instance, Fd.Instances.Instance
    timestamps()
  end

end


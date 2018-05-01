defmodule Fd.Instances.InstanceCheck do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  schema "instance_checks" do
    field :up, :boolean
    field :signup, :boolean
    field :users, :integer
    field :statuses, :integer
    field :peers, :integer
    field :emojis, :integer
    field :server, :integer
    field :version, :string
    field :max_chars, :integer
    field :error_s, :string
    belongs_to :instance, Fd.Instances.Instance
    timestamps(inserted_at: false)
  end

  def changeset(%InstanceCheck{} = check, attrs) do
    check
    |> cast(attrs, [:up, :statuses, :users, :peers, :version, :emojis, :max_chars, :signup, :instance_id, :error_s,
      :server])
  end

end

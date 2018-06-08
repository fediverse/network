defmodule Fd.Instances.InstanceSettings do
  use Ecto.Schema
  import Ecto.Changeset
  alias Fd.Instances.{Instance, InstanceSettings}

  embedded_schema do
    field :keep_calm, :boolean
    field :hidden, :boolean
    field :dead_reason, :string
    field :alerts_to_contact, :boolean
    field :maintenance_mode, :boolean
  end

  def changeset(settings = %InstanceSettings{}, attrs) do
    settings
    |> cast(attrs, [:hidden, :alerts_to_contact, :keep_calm, :dead_reason, :maintenance_mode])
  end

end

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

    field :federation_restrictions_link, :string
  end

  def changeset(settings = %InstanceSettings{}, attrs) do
    settings
    |> cast(attrs, [:hidden, :alerts_to_contact, :keep_calm, :dead_reason, :maintenance_mode, :federation_restrictions_link])
    |> validate_change(:federation_restrictions_link, fn(_, link) ->
      case URI.parse(link) do
        %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host) -> []
        _ -> [federation_restrictions_link: "is not a valid URL"]
      end
    end)
  end

end

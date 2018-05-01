defmodule Fd.Repo.Migrations.CreateInstances do
  use Ecto.Migration

  def change do
    create table(:instances) do
      add :domain, :string
      add :version, :string
      add :server, :integer

      add :name, :string
      add :description, :text
      add :email, :string

      add :valid, :boolean
      add :up, :boolean

      add :last_checked_at, :utc_datetime
      add :last_up_at, :utc_datetime
      add :last_down_at, :utc_datetime

      # /api/v1/instance
      add :has_mastapi, :boolean
      add :mastapi_version, :string
      add :mastapi_instance, :map

      add :custom_emojis, :map

      # /api/statusnet/{config,version}
      add :has_statusnet, :boolean
      add :statusnet_version, :string
      add :statusnet_config, :map

      add :peertube_config, :map

      timestamps()
    end

    create unique_index(:instances, [:domain])
  end
end

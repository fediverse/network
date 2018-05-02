defmodule Fd.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do

    execute "create extension if not exists citext", "drop extension citext"

    create table(:accounts) do
      add :username, :citext
      add :visible, :boolean

      add :public_key, :text
      add :remote_url, :string
      add :uri, :string
      add :url, :string
      add :locked, :boolean

      add :name, :string
      add :bio, :text
      add :avatar_url, :string
      add :header_url, :string
      add :statuses_count, :integer
      add :followers_count, :integer
      add :followings_count, :integer
      add :last_status_at, :utc_datetime
      add :refreshed_at, :utc_datetime
      add :instance_id, :integer

      timestamps()
    end

    create unique_index(:accounts, [:username])
    create index(:accounts, [:instance_id])
  end
end

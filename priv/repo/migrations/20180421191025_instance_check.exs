defmodule Fd.Repo.Migrations.InstanceCheck do
  use Ecto.Migration

  def change do
    execute "create extension if not exists timescaledb", "drop extension timescaledb"
    create table(:instance_checks, primary_key: false) do
      add :instance_id, references(:instances, on_delete: :delete_all)
      add :up, :boolean
      add :users, :integer
      add :peers, :integer
      add :emojis, :integer
      add :statuses, :integer
      add :version, :string
      add :signup, :boolean
      add :max_chars, :integer
      timestamps(inserted_at: false)
    end

    execute "SELECT create_hypertable('instance_checks', 'updated_at', chunk_time_interval => interval '1 week')"

    add_index(:instance_checks, [:instance_id, "updated_at DESC"])
  end
end

defmodule Fd.Repo.Migrations.InstanceCheck do
  use Ecto.Migration

  def change do
    create table(:instance_checks) do
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
  end
end

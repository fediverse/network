defmodule Fd.Repo.Migrations.AddTagRelations do
  use Ecto.Migration

  def change do
    alter table(:tags) do
      add(:canonical_id, references(:tags))
      add(:includes, {:array, :integer})
    end
  end
end

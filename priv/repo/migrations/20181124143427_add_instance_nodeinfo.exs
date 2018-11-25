defmodule Fd.Repo.Migrations.AddInstanceNodeinfo do
  use Ecto.Migration

  def change do
    alter table(:instances) do
      add :nodeinfo, :map
    end

    create index(:instances, [:nodeinfo], using: :gin)
  end
end

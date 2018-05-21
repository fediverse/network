defmodule Fd.Repo.Migrations.AddInstanceSettings do
  use Ecto.Migration

  def change do
    alter table(:instances) do
      add :settings, :map
    end
  end
end

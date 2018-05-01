defmodule Fd.Repo.Migrations.AddMoreFieldInstance do
  use Ecto.Migration

  def change do
    alter table(:instances) do
      add :monitor, :boolean
      add :hidden, :boolean
      add :dead, :boolean
    end

    alter table(:instance_checks) do
      add :server, :integer
    end

  end
end

defmodule Fd.Repo.Migrations.CheckErrorField do
  use Ecto.Migration

  def change do
    alter table(:instance_checks) do
      add :error_s, :string
    end
  end
end

defmodule Fd.Repo.Migrations.AddInstanceIndices do
  use Ecto.Migration

  def change do
    create index(:instances, [:server])
    create index(:instances, [:server, :version])
  end
end

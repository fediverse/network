defmodule Fd.Repo.Migrations.TagNameCitext do
  use Ecto.Migration

  def change do
    execute "create extension if not exists citext", "drop extension citext"
    alter table(:tags) do
      modify(:name, :citext)
    end
  end
end

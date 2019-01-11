defmodule Fd.Repo.Migrations.AddTagDescription do
  use Ecto.Migration

  def change do
    alter table(:tags) do
      add(:description, :text)
    end
  end
end

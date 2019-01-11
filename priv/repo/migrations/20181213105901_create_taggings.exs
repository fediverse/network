defmodule Fd.Repo.Migrations.CreateTaggings do
  use Ecto.Migration

  def change do
    create table(:taggings) do
      add :instance_id, references(:instances)
      add :tag_id, references(:tags)
    end

    create unique_index(:taggings, [:tag_id, :instance_id])
    create index(:taggings, :tag_id)
    create index(:taggings, :instance_id)
  end
end

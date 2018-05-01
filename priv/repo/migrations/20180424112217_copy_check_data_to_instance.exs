defmodule Fd.Repo.Migrations.CopyCheckDataToInstance do
  use Ecto.Migration

  def change do
    alter table(:instances) do
      add(:signup, :boolean)
      add(:users, :integer)
      add(:statuses, :integer)
      add(:peers, :integer)
      add(:emojis, :integer)
      add(:max_chars, :integer)
    end
  end

end

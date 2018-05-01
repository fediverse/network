defmodule Fd.Repo.Migrations.AddInstanceHostInfo do
  use Ecto.Migration

  def change do
    alter table(:instances) do
      add :domain_suffix, :citext
      add :domain_base, :citext
      add :ases, {:array, :text}
      add :ips, {:array, :text}
    end
  end
end

defmodule Fd.Accounts.Account do
  use Ecto.Schema
  import Ecto.Changeset
  alias Fd.Accounts.Account
  alias Fd.Instances.Instance

  @username_regex ~r"^[a-z0-9_]+@[a-z0-9\.]$"

  schema "accounts" do
    field :username, :string
    field :visible, :boolean

    # Computed fields
    field :public_key, :string
    field :remote_url, :string
    field :locked, :boolean
    field :name, :string
    field :bio, :string
    field :avatar_url, :string
    field :header_url, :string

    field :followers_count, :integer
    field :followings_count, :integer
    field :last_status_at, :utc_datetime
    field :refreshed_at, :utc_datetime

    belongs_to :instance, Fd.Instances.Instance

    timestamps()
  end

  @doc false
  def changeset(%Account{} = account, :create, attrs) do
    account
    |> cast(attrs, [:username, :instance_id])
    |> validate_required([:username])
    |> validate_format(:username, @username_regex)
    |> unique_constraint(:username)
    |> cast_assoc(:instance, required: true, with: &Instance.changeset(&1))
  end
end

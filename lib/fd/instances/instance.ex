defmodule Fd.Instances.Instance do
  use Ecto.Schema
  import Ecto.Changeset
  alias Fd.Instances.Instance

  schema "instances" do
    field :domain, :string
    field :domain_suffix, :string
    field :domain_base, :string
    field :name, :string
    field :description, :string
    field :email, :string
    field :server, :integer
    field :version, :string
    field :ases, {:array, :string}
    field :ips, {:array, :string}
    field :valid, :boolean
    field :up, :boolean
    field :monitor, :boolean
    field :hidden, :boolean
    field :dead, :boolean
    field :signup, :boolean
    field :users, :integer
    field :statuses, :integer
    field :peers, :integer
    field :emojis, :integer
    field :max_chars, :integer
    field :last_checked_at, :utc_datetime
    field :last_up_at, :utc_datetime
    field :last_down_at, :utc_datetime
    field :has_mastapi, :boolean
    field :has_statusnet, :boolean
    field :mastapi_version, :string
    field :mastapi_instance, :map
    field :custom_emojis, :map
    field :statusnet_version, :string
    field :statusnet_config, :map
    field :peertube_config, :map
    field :nodeinfo, :map

    embeds_one :settings, Fd.Instances.InstanceSettings, on_replace: :delete

    has_many :checks, Fd.Instances.InstanceCheck

    has_many :taggings, Fd.Tags.Tagging
    many_to_many :tags, Fd.Tags.Tag, join_through: "taggings", on_replace: :delete

    timestamps()
  end

  def hidden?(%Instance{} = instance) do
    cond do
      instance.hidden == true -> true
      Map.get(instance.settings || %{}, :hidden) == true -> true
      true -> false
    end
  end

  @doc false
  def changeset(%Instance{} = instance, attrs) do
    instance
    |> cast(attrs, [:domain, :up, :server, :name, :description, :email, :version, :valid, :last_checked_at, :last_up_at, :last_down_at, :has_mastapi,
      :has_statusnet, :mastapi_version, :mastapi_instance, :custom_emojis, :statusnet_version, :statusnet_config,
      :peertube_config, :signup, :users, :statuses, :peers, :emojis, :max_chars, :domain_suffix, :domain_base, :ases,
      :ips, :monitor, :hidden, :dead, :nodeinfo])
    |> validate_required([:domain])
    |> unique_constraint(:domain)
  end

  @doc false
  def manage_changeset(%Instance{} = instance, attrs) do
    instance
    |> cast(attrs, [:monitor, :dead])
    |> Fd.Tags.Tag.put_tags(attrs)
    |> cast_embed(:settings)
  end


end

defimpl Phoenix.Param, for: Fd.Instances.Instance do
  def to_param(%Fd.Instances.Instance{domain: domain}) do
    Fd.Util.idna(domain)
  end
end


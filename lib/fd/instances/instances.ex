defmodule Fd.Instances do
  @moduledoc """
  The Instances context.
  """

  import Ecto.Query, warn: false
  alias Fd.Repo

  alias Fd.Instances.{Instance, InstanceCheck}

  @doc """
  Returns the list of instances.

  ## Examples

      iex> list_instances()
      [%Instance{}, ...]

  """
  def list_instances do
    Repo.all(Instance)
  end

  @doc """
  Gets a single instance.

  Raises `Ecto.NoResultsError` if the Instance does not exist.

  ## Examples

      iex> get_instance!(123)
      %Instance{}

      iex> get_instance!(456)
      ** (Ecto.NoResultsError)

  """
  def get_instance!(id), do: Repo.get!(Instance, id)
  def get_instance_by_domain!(domain) do
    domain = Fd.Util.from_idna(domain)
    from(i in Instance, where: i.domain == ^domain)
    |> Repo.one!
  end

  def get_instance_by_domain(domain) when is_binary(domain) do
    domain = Fd.Util.from_idna(domain)
    from(i in Instance, where: i.domain == ^domain)
    |> Repo.one
  end

  def get_instance_by_domain(_), do: nil

  @doc """
  Returns the latest up check for the given `Instance`.
  """
  @spec get_instance_last_up_check(Instance) :: InstanceCheck | nil
  def get_instance_last_up_check(%Instance{id: id}) do
    from(c in InstanceCheck,
      where: c.instance_id == ^id and c.up == true,
      order_by: [desc: c.updated_at],
      limit: 1
    )
    |> Repo.one
  end
  @spec get_instance_last_check(Instance) :: InstanceCheck | nil
  def get_instance_last_check(%Instance{id: id}) do
    from(c in InstanceCheck,
      where: c.instance_id == ^id,
      order_by: [desc: c.updated_at],
      limit: 1
    )
    |> Repo.one
  end

  def get_instance_users(id) do
    query = "select distinct on (month) id, users, statuses, date_trunc('month', updated_at) as month, updated_at from instance_checks where instance_id = #{id} limit 12"
    res = Ecto.Adapters.SQL.query!(Repo, query)
    get_month = fn(map) -> map
                          |> Map.get("month")
                          |> elem(0)
                          |> elem(1)
                          end

    data = Enum.map(res.rows, fn r -> Enum.zip(res.columns, r) |> Enum.into(%{}) end)

    Enum.map(data, fn d -> Map.put(d, "month", get_month.(d)) end)
  end

  def get_instance_statuses(id) do
    query = "select distinct on (week) statuses, extract(week from updated_at) as week from instance_checks where instance_checks.instance_id = #{id} limit 52"
    res = Ecto.Adapters.SQL.query!(Repo, query)
    get_month = fn(map) -> map
                          |> Map.get("week")
                          end

    data = Enum.map(res.rows, fn r -> Enum.zip(res.columns, r) |> Enum.into(%{}) end)

    Enum.map(data, fn d -> Map.put(d, "month", get_month.(d)) end)
  end


  def switch_flag(id, flag, bool) when is_boolean(bool) do
    instance = get_instance!(id)
    update_instance(instance, %{flag => bool})
  end

  def list_instances_by_domains(list) when is_list(list) do
    list = Enum.map(list, &Fd.Util.from_idna/1)
    from(i in Instance, where: i.domain in ^list)
    |> Repo.all
  end

  @doc """
  Creates a instance.

  ## Examples

      iex> create_instance(%{field: value})
      {:ok, %Instance{}}

      iex> create_instance(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_instance(attrs \\ %{}) do
    %Instance{}
    |> Instance.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a instance.

  ## Examples

      iex> update_instance(instance, %{field: new_value})
      {:ok, %Instance{}}

      iex> update_instance(instance, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_instance(%Instance{} = instance, attrs) do
    instance
    |> Instance.changeset(attrs)
    |> Repo.update()
  end

  def update_manage_instance(%Instance{} = instance, attrs) do
    instance
    |> Instance.manage_changeset(attrs)
    |> Repo.update()
  end


  @doc """
  Deletes a Instance.

  ## Examples

      iex> delete_instance(instance)
      {:ok, %Instance{}}

      iex> delete_instance(instance)
      {:error, %Ecto.Changeset{}}

  """
  def delete_instance(%Instance{} = instance) do
    Repo.delete(instance)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking instance changes.

  ## Examples

      iex> change_instance(instance)
      %Ecto.Changeset{source: %Instance{}}

  """
  def change_instance(%Instance{} = instance) do
    Instance.changeset(instance, %{})
  end
end

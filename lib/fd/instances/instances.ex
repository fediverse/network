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

  @statistics_intervals %{
    "5min" => {"5 minutes", 576}, # two days
    "hourly" => {"1 hour", 192}, #one week
    "3hour" => {"3 hour", 112}, #two weeks
    "daily" => {"1 day", 31},
    "weekly" => {"1 week", 53},
    "monthly" => {"1 month", 12},
  }
  @statistics_intervals_keys Map.keys(@statistics_intervals)

  def get_instance_statistics(id, interval, limit \\ nil) when is_integer(id) and interval in @statistics_intervals_keys do
    {interval, default_limit} = Map.get(@statistics_intervals, interval)
    limit = unless limit do
      default_limit
    else
      limit
    end
    query = """
    SELECT time_bucket('#{interval}', updated_at) as date,
      last(users, updated_at) as users,
      last(statuses, updated_at) as statuses,
      last(peers, updated_at) as peers,
      last(emojis, updated_at) as emojis,
      (last(users, updated_at) - first(users, updated_at)) as new_users,
      (last(statuses, updated_at) - first(statuses, updated_at)) as new_statuses,
      (last(peers, updated_at) - first(peers, updated_at)) as new_peers,
      (last(emojis, updated_at) - first(emojis, updated_at)) as new_emojis
    FROM instance_checks
    WHERE instance_id = #{id} AND up = 'true'
    GROUP BY date
    ORDER BY date DESC
    LIMIT #{limit}
    """

    res = Ecto.Adapters.SQL.query!(Repo, query)
    get_date = fn(map) ->
      {date, {h, m, s, ms}} = Map.get(map, "date")
      hour = {h, m, s}

      {date, hour}
      |> NaiveDateTime.from_erl!(ms)
      |> DateTime.from_naive!("Etc/UTC")
    end

    res.rows
    |> Enum.map(fn r -> Enum.zip(res.columns, r) |> Enum.into(%{}) end)
    |> Enum.map(fn d -> Map.put(d, "date", get_date.(d)) end)
  end

  def get_global_statistics(interval, limit \\ nil) when interval in @statistics_intervals_keys do
    {interval, default_limit} = Map.get(@statistics_intervals, interval)
    limit = unless limit do
      default_limit
    else
      limit
    end
    query = """
    SELECT time_bucket('#{interval}', updated_at) as date,
      last(users, updated_at) as users,
      last(statuses, updated_at) as statuses,
      last(peers, updated_at) as peers,
      last(emojis, updated_at) as emojis,
      (last(users, updated_at) - first(users, updated_at)) as new_users,
      (last(statuses, updated_at) - first(statuses, updated_at)) as new_statuses,
      (last(peers, updated_at) - first(peers, updated_at)) as new_peers,
      (last(emojis, updated_at) - first(emojis, updated_at)) as new_emojis
    FROM instance_checks
    WHERE up = 'true'
    GROUP BY date
    ORDER BY date DESC
    LIMIT #{limit}
    """

    res = Ecto.Adapters.SQL.query!(Repo, query)
    get_date = fn(map) ->
      {date, {h, m, s, ms}} = Map.get(map, "date")
      hour = {h, m, s}

      {date, hour}
      |> NaiveDateTime.from_erl!(ms)
      |> DateTime.from_naive!("Etc/UTC")
    end

    res.rows
    |> Enum.map(fn r -> Enum.zip(res.columns, r) |> Enum.into(%{}) end)
    |> Enum.map(fn d -> Map.put(d, "date", get_date.(d)) end)
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

defmodule Fd.Instances do
  @moduledoc """
  The Instances context.
  """

  import Ecto.Query, warn: false
  alias Fd.Repo

  alias Fd.Instances.{Instance, InstanceCheck, InstanceSettings}
  alias Fd.Cache

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

  def get_instance_last_checks(%Instance{id: id}, limit) do
    Cache.ctx_get_or_set("Instance:#{id}", "last_checks:#{limit}", fn() ->
      from(c in InstanceCheck, where: c.instance_id == ^id, limit: ^limit, order_by: [desc: c.updated_at])
      |> Repo.all()
    end)
  end


  def get_instance_last_checks_overview(%Instance{id: id}, limit) do
    Cache.ctx_get_or_set("Instance:#{id}", "last_checks:o:#{limit}", fn() ->
      from(c in InstanceCheck, select: %InstanceCheck{up: c.up, updated_at: c.updated_at, error_s: c.error_s},
      where: c.instance_id == ^id, limit: ^limit, order_by: [desc: c.updated_at])
      |> Repo.all()
    end)
  end


  @doc """
  Returns the latest up check for the given `Instance`.
  """
  @spec get_instance_last_up_check(Instance) :: InstanceCheck | nil
  def get_instance_last_up_check(%Instance{id: id}) do
    Cache.ctx_get_or_set("Instance:#{id}", "last_up_check", fn() ->
      from(c in InstanceCheck,
        where: c.instance_id == ^id and c.up == true,
        order_by: [desc: c.updated_at],
        limit: 1
      )
      |> Repo.one
    end)
  end
  @spec get_instance_last_check(Instance) :: InstanceCheck | nil
  def get_instance_last_check(%Instance{id: id}) do
    Cache.ctx_get_or_set("Instance:#{id}", "last_check", fn() ->
      from(c in InstanceCheck,
        where: c.instance_id == ^id,
        order_by: [desc: c.updated_at],
        limit: 1
      )
      |> Repo.one
    end)
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

  def get_cached_instances_statistics(id, interval, limit) when is_integer(id) and interval in @statistics_intervals_keys do
    Cache.lazy("Instance:#{id}:stats:i#{interval}l#{limit}", &get_instance_statistics/3, [id, interval, limit])
  end

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

    result = res.rows
    |> Enum.map(fn r -> Enum.zip(res.columns, r) |> Enum.into(%{}) end)
    |> Enum.map(fn d -> Map.put(d, "date", get_date.(d)) end)
    {result, 60}
  end

  def get_uptime_percentage(id) do
    get_uptime_percentage(id, :last_thirty_days)
  end

  @spec get_uptime_percentage(Integer.t, :overall | :last_seven_days | {:time_range, DateTime.t, DateTime.t}) :: Float.t | nil

  def get_uptime_percentage(id, :last_seven_days) do
    finish = Date.utc_today() |> Timex.shift(days: 1)
    start = Timex.shift(finish, days: -8)
    get_uptime_percentage(id, {:time_range, start, finish})
  end
  def get_uptime_percentage(id, :last_two_weeks) do
    finish = Date.utc_today() |> Timex.shift(days: 1)
    start = Timex.shift(finish, days: -15)
    get_uptime_percentage(id, {:time_range, start, finish})
  end
  def get_uptime_percentage(id, :last_thirty_days) do
    finish = Date.utc_today() |> Timex.shift(days: 1)
    start = Timex.shift(finish, days: -31)
    get_uptime_percentage(id, {:time_range, start, finish})
  end

  def get_uptime_percentage(id, mode) do
    Cache.ctx_get_or_set("Instance:#{id}", "uptime:m#{inspect(mode)}", fn() ->
      query = case mode do
        :overall ->
          """
          select (count(*) filter(where t.up = 'true') * 100.0) /
              count(*) from (select ic.up from instance_checks as ic
                       where ic.instance_id = #{id}
                       order by ic.updated_at desc) t;
          """
        {:time_range, start, finish} ->
          """
          select (count(*) filter(where t.up = 'true') * 100.0) /
              count(*) from (select ic.up from instance_checks as ic
                       where ic.instance_id = #{id}
                        and ic.updated_at between to_timestamp('#{start}', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                          and to_timestamp('#{finish}', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                       order by ic.updated_at) t;
          """
      end
      result = case Ecto.Adapters.SQL.query!(Repo, query) do
        %Postgrex.Result{rows: [[decimal]]} -> Decimal.to_float(decimal)
        _ -> nil
      end
    end)
  end

  def get_global_statistics(interval) when interval in @statistics_intervals_keys do
    {interval, _} = Map.get(@statistics_intervals, interval)
    query = """
    SELECT distinct time_bucket('#{interval}', date) as date,
            sum(users) as users, sum(statuses) as statuses, sum(peers) as peers, sum(new_users) as new_users,
            sum(new_statuses) as new_statuses, sum(new_peers) as new_peers, sum(new_emojis) as new_emojis,
            count(distinct instance_id) as instances
    FROM (
      SELECT distinct instance_id, time_bucket('#{interval}', updated_at) as date,
        last(users, updated_at) as users,
        last(statuses, updated_at) as statuses,
        last(peers, updated_at) as peers,
        last(emojis, updated_at) as emojis,
        (last(users, updated_at) - first(users, updated_at)) as new_users,
        (last(statuses, updated_at) - first(statuses, updated_at)) as new_statuses,
        (last(peers, updated_at) - first(peers, updated_at)) as new_peers,
        (last(emojis, updated_at) - first(emojis, updated_at)) as new_emojis
      FROM instance_checks
      WHERE up = 'true' AND server != 0
      GROUP BY date, instance_id
      ORDER BY date DESC
      ) as x
    GROUP BY date
    """

    res = Ecto.Adapters.SQL.query!(Repo, query)
    get_date = fn(map) ->
      {date, {h, m, s, ms}} = Map.get(map, "date")
      hour = {h, m, s}

      {date, hour}
      |> NaiveDateTime.from_erl!(ms)
      |> DateTime.from_naive!("Etc/UTC")
    end

    result = res.rows
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
    instance
    |> Map.put_new(:settings, %InstanceSettings{})
    |> Instance.changeset(%{})
  end
end

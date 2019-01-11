defmodule Fd.Stats do
  require Logger
  import Ecto.Query

  alias Fd.Repo
  alias Fd.Instances.Instance
  alias Fd.Instances.InstanceCheck, as: Check

  @moduledoc """

  Returns stats evolution over a period of time.

  Default scope:

  Where instance:
    * server is a valid & non ignored server
    * last_up_check is less than 90 days ago

  Params:

  * Required:
    * `from`
      * YYYY-MM-DD, YYYY-MM, YYYY-DD
  * Optional:
    * `server_ids` list of server ids (comma separated)
    * `instance_ids` list of instance ids (comma separated)
    * `to` (same format as `from`)


  """

  @reports %{
    "2018" => %{
      "from" => "2018-04-30", "to" => "2018-12-31"
    }
  }

  for {k, params} <- @reports do
    params = Macro.escape(params)
    def rebuild_file_evolution(unquote(k)) do
      rebuild_file_evolution(unquote(params))
    end
    def file_evolution(unquote(k)) do
      file_evolution(unquote(params))
    end
    def evolution(unquote(k)) do
      evolution(unquote(params))
    end
  end


  def rebuild_file_evolution(params) do
    evol = evolution(params)
    filename = "evolution_#{Map.get(params, "to")}_#{Map.get(params, "from")}.json"
    File.write!(filename, Jason.encode!(evol))
    evol
  end

  def file_evolution(params) do
    filename = "evolution_#{Map.get(params, "to")}_#{Map.get(params, "from")}.json"
    if File.exists?(filename) do
      File.read!(filename) |> Jason.decode!(keys: :atoms)
    else
      rebuild_file_evolution(params)
    end
  end

  def cached_evolution(params) do
    Fd.Cache.lazy("Stats:Evolution:#{inspect params}", &evolution/1, [params])
  end

  def evolution(params) do
    from = Map.fetch!(params, "from") |> parse_date()
    to = Map.get(params, "to") |> parse_date()

    query_scope = fn(query, params, key) ->
      definer = case parse_list(Map.get(params, key)) do
        list when is_list(list) and list != [] -> {key, list}
        _ -> nil
      end

      case definer do
        nil -> query
        {"server_ids", ids} -> where(query, [check], check.server in ^ids)
        {"instance_ids", ids} -> where(query, [check], check.instance_id in ^ids)
      end
    end

    {:ok, from_time} = NaiveDateTime.new(from, ~T[00:00:00.000])
    {:ok, to_time} = NaiveDateTime.new((to || %Date{from | day: Date.days_in_month(from)}), ~T[23:59:59.999])

    {:ok, not_up_before} = Date.add(to, -30) |> NaiveDateTime.new(~T[23:59:59.999])

    valid_server_ids = Fd.ServerName.valid_server_ids()

    all_instances = from(instance in Instance,
      where: instance.last_up_at >= ^not_up_before and instance.server > 0)

    before_period_instances = from(instance in Instance,
      where: instance.last_up_at >= ^from_time and instance.inserted_at <= ^from_time and instance.server > 0)

    # Total count of instances
    instances = from(instance in Instance,
      where: instance.inserted_at >= ^from_time
      and instance.inserted_at <= ^to_time
      #and instance.last_up_at >= ^not_up_before
      and instance.server > 0)# in ^valid_server_ids)

    # instances that died in the from-to period
    dead_instances = from(instance in Instance,
      where: instance.last_up_at >=^from_time and instance.last_up_at <= ^not_up_before and instance.server > 0)

    # Instances that was up before the from-to period

    instances_detailed_query = from(check in Check)
            |> period_constraint(from, to)
            |> query_scope.(params, "instance_ids")
            |> query_scope.(params, "server_ids")
    #|> where([check, _], check.server in ^valid_server_ids)
            |> join(:inner, [check], instance in assoc(check, :instance))
            |> distinct([check, instance], instance.id)
            |> group_by([check, instance], instance.id)
            |> select([check, instance], %{
              instance_id: instance.id,
              server: instance.server,
              users_first: fragment("first(?, ?)", check.users, check.updated_at),
              users_last: fragment("last(?, ?)", check.users, check.updated_at),
              users: fragment("last(?, ?) - first(?, ?)", check.users, check.updated_at, check.users, check.updated_at),
              statuses_first: fragment("first(?, ?)", check.statuses, check.updated_at),
              statuses_last: fragment("last(?, ?)", check.statuses, check.updated_at),
              statuses: fragment("last(?, ?) - first(?, ?)", check.statuses, check.updated_at, check.statuses, check.updated_at),
              peers_first: fragment("first(?, ?)", check.peers, check.updated_at),
              peers_last: fragment("last(?, ?)", check.peers, check.updated_at),
              peers: fragment("last(?, ?) - first(?, ?)", check.peers, check.updated_at, check.peers, check.updated_at),
            })

    instances_dead_detailed_query = instances_detailed_query
                                    |> where([check, instance], instance.last_up_at <= ^not_up_before)


    instances_up_detailed_query = instances_detailed_query |> where([check, instance], instance.last_up_at >= ^not_up_before)
    total_stats_query = from(pouet in subquery(instances_detailed_query))
                        |> select([pouet], %{
                          users_first: sum(pouet.users_first), users_last: sum(pouet.users_last), users: sum(pouet.users),
                          statuses: sum(pouet.statuses), statuses_first: sum(pouet.statuses_first), statuses_last: sum(pouet.statuses_last),
                          peers: sum(pouet.statuses), peers_first: sum(pouet.peers_first), peers_last: sum(pouet.peers_last),
                        })

    total_dead_stats_query = from(pouet in subquery(instances_dead_detailed_query))
                        |> select([pouet], %{
                          users_first: sum(pouet.users_first), users_last: sum(pouet.users_last), users: sum(pouet.users),
                          statuses: sum(pouet.statuses), statuses_first: sum(pouet.statuses_first), statuses_last: sum(pouet.statuses_last),
                          peers: sum(pouet.statuses), peers_first: sum(pouet.peers_first), peers_last: sum(pouet.peers_last),
                        })

    server_stats_query = from(pouet in subquery(instances_detailed_query))
                         |> group_by([pouet], pouet.server)
                         |> select([pouet], %{
                           server: pouet.server,
                          users_first: sum(pouet.users_first), users_last: sum(pouet.users_last), users: sum(pouet.users),
                          statuses: sum(pouet.statuses), statuses_first: sum(pouet.statuses_first), statuses_last: sum(pouet.statuses_last),
                           peers: sum(pouet.peers), peers_first: sum(pouet.peers_first), peers_last: sum(pouet.peers_last),
                         })
    #|> order_by([pouet], desc: [pouet.users, pouet.statuses])

    instances_new_count = from(instance in subquery(instances), select: count(instance.id))
    instances_dead_count = from(instance in subquery(dead_instances), select: count(instance.id))

    instances_count_server = fn(query) ->
      from(instance in subquery(query),
        select: {instance.server, count(instance.id)},
        group_by: instance.server)
        |> Repo.all()
        |> Enum.into(Map.new)
    end

    instances_new_count_server = instances_count_server.(instances)
    instances_dead_count_server = instances_count_server.(dead_instances)


    repo_opts = [timeout: 150_000]

     %{
       query: (
         params
         |> Map.put(:from, from_time)
         |> Map.put(:to, to_time)
      ),
      instances: Repo.all(instances_detailed_query, repo_opts),
      servers: (
        Repo.all(server_stats_query, repo_opts)
         |> Enum.map(fn(stat) ->
           stat
           |> Map.put(:instances, Map.get(instances_new_count_server, stat.server))
           |> Map.put(:dead_instances, Map.get(instances_dead_count_server, stat.server))
         end)
         |> Enum.sort_by(fn(s) -> (s.instances||0) end, &>=/2)
      ),#(((s.users || 0)*2) + ((s.statuses || 1) / 2)) end, &>=/2),
      network: (
        Repo.one(total_stats_query, repo_opts)
        |> Map.put(:all, %{
          instances: Repo.one(from(i in all_instances, select: count(i.id)))
        })
        |> Map.put(:previous, %{
          instances: Repo.one(from(i in before_period_instances, select: count(i.id)))
        })
        |> Map.put(:dead, Repo.one(total_dead_stats_query, repo_opts))
        |> put_in([:dead, :instances], Repo.one(instances_dead_count))
         |> Map.put(:instances, Repo.one(instances_new_count))
      ),
    }
  end


  defp parse_id_list(string) when is_binary(string) do
    string
    |> String.strip()
    |> String.split(",")
    |> Enum.reduce([], fn(id, acc) ->
      case Integer.parse(id) do
        {id, _} -> [id | acc]
        _ -> acc
      end
    end)
  end
  defp parse_list(_), do: []

  # We want a very laxist date parser
  # Three supported formats:
  # year-month-day, year-month, year
  defp parse_date(string) when is_binary(string) do
    list = string
           |> String.split("-")
           |> Enum.reduce([], fn(int, acc) ->
             case {acc, Integer.parse(int)} do
               {_, {int, _}} -> acc ++ [int]
               {[], _} -> acc
             end
           end)
           |> IO.inspect()
    case list do
      [year] ->
        IO.inspect {year}
        {:ok, date} = Date.new(year, 1, 1)
        date
      [year, month] ->
        IO.inspect {year,month}
        {:ok, date} = Date.new(year, month, 1)
        date
      [year, month, day] ->
        IO.inspect {year,month,day}
        {:ok, date} = Date.new(year, month, day)
        date
    end
  end

  defp parse_date(_), do: nil

  defp period_constraint(query, from = %Date{}, nil) do
    to = %Date{from | day: Date.days_in_month(from)}
    period_constraint(query, from, to)
  end

  defp period_constraint(query, from = %Date{}, to = %Date{}) when from > to, do: period_constraint(query, to, from)

  defp period_constraint(query, from = %Date{}, to = %Date{}) when from < to do
    {:ok, from} = NaiveDateTime.new(from, ~T[00:00:00.000])
    {:ok, to} = NaiveDateTime.new(to, ~T[23:59:59.999])
    where(query, [check], check.updated_at >= ^from and check.updated_at <= ^to)
  end

end

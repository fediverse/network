defmodule Fd.GlobalStats do

  use GenServer
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def get do
    case GenServer.call(__MODULE__, :get) do
      {:ok, stats} -> stats
      other ->
        Logger.error "GlobalStats call failed: #{inspect(other)}"
        %{}
    end
  end

  defstruct [:timer, :stats]

  def init(_) do
    Logger.debug "GlobalStats: init"
    GenServer.cast(__MODULE__, :build)
    timer = :erlang.send_after(60_000, self(), :refresh)
    {:ok, %__MODULE__{timer: timer, stats: nil}}
  end

  def handle_call(:get, _, state = %{stats: stats}) do
    {:reply, {:ok, stats}, state}
  end

  def handle_info(:refresh, state) do
    Logger.debug "GlobalStats: queueing refresh"
    server = self()
    spawn(fn() ->
      stats = build()
      send(server, {:put, stats})
    end)
    timer = :erlang.send_after(60_000, self(), :refresh)
    {:noreply, %__MODULE__{state | timer: timer}}
  end

  def handle_info({:put, stats}, state) do
    Logger.debug "GlobalStats: stats refreshed"
    {:noreply, %__MODULE__{state | stats: stats}}
  end

  def handle_cast(:build, state) do
    stats = build()
    {:noreply, %{state|stats: stats}}
  end

  def build do
    import Ecto.Query
    alias Fd.{Repo, Instances.Instance}
    # Instances per server: select server,count(id) from instances group by server;
    # Instances up: select count(id) from instances where up='true';
    # Statuses, users, emojis: select sum(users) as users, sum(statuses) as statuses, sum(emojis) as emojis from instances;
    [total] = from(i in Instance, select: [count(i.id)], where: not is_nil(i.last_up_at)) |> Repo.one
    [up] = from(i in Instance, select: [count(i.id)], where: i.up == true) |> Repo.one
    [new] = from(i in Instance, select: [count(i.id)], where: i.up == true and fragment("? > NOW() - INTERVAL '7 days'", i.inserted_at)) |> Repo.one
    [down] = from(i in Instance, select: [count(i.id)], where: i.up != true and fragment("? > NOW() - INTERVAL '30 days'", i.last_up_at)) |> Repo.one
    [dead] = from(i in Instance, select: [count(i.id)], where: is_nil(i.last_up_at) or fragment("? < NOW() - INTERVAL '30 days'", i.last_up_at)) |> Repo.one

    per_server_all = from(i in Instance, select: [i.server, sum(i.users), sum(i.statuses), sum(i.emojis), count(i.id)], group_by: i.server)
    |> Repo.all
    |> Enum.reduce(%{}, &per_server_reducer/2)
    per_server_up = from(i in Instance, select: [i.server,sum(i.users), sum(i.statuses), sum(i.emojis), count(i.id)], group_by: i.server, where: i.up == true)
    |> Repo.all
    |> Enum.reduce(%{}, &per_server_reducer/2)
    per_server_down = from(i in Instance, select: [i.server,sum(i.users), sum(i.statuses), sum(i.emojis), count(i.id)], group_by: i.server, where: i.up == false and fragment("? > NOW() - INTERVAL '30 days'", i.last_up_at))
    |> Repo.all
    |> Enum.reduce(%{}, &per_server_reducer/2)
    per_server_dead = from(i in Instance, select: [i.server,sum(i.users), sum(i.statuses), sum(i.emojis), count(i.id)], group_by: i.server, where: i.dead or fragment("? < NOW() - INTERVAL '30 days'", i.last_up_at))
    |> Repo.all
    |> Enum.reduce(%{}, &per_server_reducer/2)

    [_total, users, statuses, emojis] = from(i in Instance, select: [count(i.id), sum(i.users), sum(i.statuses), sum(i.emojis)])
                                      |> Repo.one
                                      |> Enum.map(fn x -> if x == nil, do: 0, else: x end)
    [_up, up_users, up_statuses, up_emojis] = from(i in Instance, where: i.up == true, select: [count(i.id), sum(i.users), sum(i.statuses), sum(i.emojis)])
                                      |> Repo.one
                                      |> Enum.map(fn x -> if x == nil, do: 0, else: x end)
    [_down, down_users, down_statuses, down_emojis] = from(i in Instance, where: i.up == false and fragment("? > NOW() - INTERVAL '30 days'", i.last_up_at), select: [count(i.id), sum(i.users), sum(i.statuses), sum(i.emojis)])
                                      |> Repo.one
                                      |> Enum.map(fn x -> if x == nil, do: 0, else: x end)
    [_dead, dead_users, dead_statuses, dead_emojis] = from(i in Instance, where: i.dead or fragment("? < NOW() - INTERVAL '30 days'", i.last_up_at), select: [count(i.id), sum(i.users), sum(i.statuses), sum(i.emojis)])
                                      |> Repo.one
                                      |> Enum.map(fn x -> if x == nil, do: 0, else: x end)

    per_server = Enum.reduce(per_server_all, %{}, fn({server_id, x=[total, users, statuses, emojis]}, acc) ->
      [up, up_users, up_statuses, up_emojis] = Map.get(per_server_up, server_id, [0, 0, 0, 0])
      [down, down_users, down_statuses, down_emojis] = Map.get(per_server_down, server_id, [0, 0, 0, 0])
      [dead, dead_users, dead_statuses, dead_emojis] = Map.get(per_server_dead, server_id, [0, 0, 0, 0])
      data = %{
        "instances" => %{"total" => total, "alive" => up + down, "up" => up, "down" => down, "dead" => dead},
        "users" => %{"total" => users, "alive" => up_users + down_users, "up" => up_users, "down" => down_users, "dead" => dead_users},
        "statuses" => %{"total" => statuses, "alive" => up_statuses + down_statuses, "up" => up_statuses, "down" => down_statuses, "dead" => dead_statuses},
        "emojis" => %{"total" => emojis, "alive" => up_emojis + down_emojis, "up" => up_emojis, "down" => down_emojis, "dead" => dead_emojis},
      }
      Map.put(acc, server_id, data)
    end)

    Logger.info "users: #{inspect users}"
    Logger.info "up_users: #{inspect up_users}"

    %{
      "instances" => %{"total" => total, "alive" => up + down, "up" => up, "down" => down, "dead" => dead, "new" => new},
      "users" => %{"total" => users, "alive" => up_users + down_users, "up" => up_users, "down" => down_users, "dead" => dead_users},
      "statuses" => %{"total" => statuses, "alive" => up_statuses + down_statuses, "up" => up_statuses, "down" => down_statuses, "dead" => dead_statuses},
      "emojis" => %{"total" => emojis, "alive" => up_emojis + down_emojis, "up" => up_emojis, "down" => down_emojis, "dead" => dead_emojis},
      "per_server" => per_server
    }
  end

  defp per_server_reducer([nil, _, _, _, _], acc), do: acc
  defp per_server_reducer([server_id, users, statuses, emojis, count], acc) do
    Map.put(acc, server_id, [count, users || 0, statuses || 0, emojis || 0])
  end

end

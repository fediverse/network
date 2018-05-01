defmodule Fd.HostStats do
  @moduledoc """
  Build statistics about hosting environments

  * Per TLD
  * Per Domain
  """

  use GenServer
  require Logger

  # Refresh only every half hour as it rarely changes
  @refresh_every_min 30

  def start_link() do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def get do
    case GenServer.call(__MODULE__, :get) do
      {:ok, stats} -> stats
      other ->
        Logger.error "HostStats call failed: #{inspect(other)}"
        %{}
    end
  end

  def refresh do
    pid = Process.whereis(__MODULE__)
    send(pid, :refresh)
  end

  defstruct [:timer, :stats]

  def init(_) do
    Logger.debug "HostStats: init"
    stats = build()
    timer = :erlang.send_after(60_000, self(), :refresh)
    {:ok, %__MODULE__{timer: timer, stats: stats}}
  end

  def handle_call(:get, _, state = %{stats: stats}) do
    {:reply, {:ok, stats}, state}
  end

  def handle_info(:refresh, state) do
    Logger.debug "HostStats: queueing refresh"
    server = self()
    spawn(fn() ->
      stats = build()
      send(server, {:put, stats})
    end)
    timer = :erlang.send_after(60_000 * @refresh_every_min, self(), :refresh)
    {:noreply, %__MODULE__{state | timer: timer}}
  end

  def handle_info({:put, stats}, state) do
    Logger.debug "HostStats: stats refreshed"
    {:noreply, %__MODULE__{state | stats: stats}}
  end

  def build do
    import Ecto.Query
    alias Fd.{Repo, Instances.Instance}

    totals = from(i in Instance, select: [i.domain_suffix, count(i.domain_suffix)], group_by: i.domain_suffix, order_by: fragment("count desc"))
    |> Repo.all
    |> Enum.reduce(%{}, fn([tld, count], acc) -> Map.put(acc, tld, count) end)
    up = from(i in Instance, select: [i.domain_suffix, count(i.domain_suffix)], group_by: i.domain_suffix, order_by: fragment("count desc"), where: i.up == true)
    |> Repo.all
    |> Enum.reduce(%{}, fn([tld, count], acc) -> Map.put(acc, tld, count) end)

    per_server_all = from(i in Instance, select: [i.server, i.domain_suffix, count(i.domain_suffix)], group_by: [i.server, i.domain_suffix])
    |> Repo.all
    |> Enum.reduce(%{}, &per_server_reducer/2)
    per_server_up = from(i in Instance, select: [i.server, i.domain_suffix, count(i.domain_suffix)], group_by: [i.server, i.domain_suffix], where: i.up == true)
                    |> Repo.all
    |> Enum.reduce(%{}, &per_server_reducer/2)

    totals_domain = from(i in Instance, select: [i.domain_base, count(i.domain_base)], group_by: i.domain_base, order_by: fragment("count desc"))
    |> Repo.all
    |> Enum.reduce(%{}, fn([tld, count], acc) -> Map.put(acc, tld, count) end)
    up_domain = from(i in Instance, select: [i.domain_base, count(i.domain_base)], group_by: i.domain_base, order_by: fragment("count desc"), where: i.up == true)
    |> Repo.all
    |> Enum.reduce(%{}, fn([tld, count], acc) -> Map.put(acc, tld, count) end)

    per_server_all_domain = from(i in Instance, select: [i.server, i.domain_base, count(i.domain_base)], group_by: [i.server, i.domain_base])
    |> Repo.all
    |> Enum.reduce(%{}, &per_server_reducer/2)
    per_server_up_domain = from(i in Instance, select: [i.server, i.domain_base, count(i.domain_base)], group_by: [i.server, i.domain_base], where: i.up == true)
                    |> Repo.all
    |> Enum.reduce(%{}, &per_server_reducer/2)

    tlds = Enum.reduce(totals, %{}, fn({tld, total}, acc) ->
      actual_tld = tld
      up = Map.get(up, tld, 0)
      per_server = Enum.reduce(Map.get(per_server_all, tld, %{}), %{}, fn({server, total}, acc) ->
        if server do
          up = get_in(per_server_up, [tld, server]) || 0
          Map.put(acc, server, %{"total" => total, "up" => up, "down" => total-up})
        else
          acc
        end
      end)
      Map.put(acc, tld, %{"total" => total, "up" => up, "down" => total-up, "per_server" => per_server})
    end)
    |> Enum.sort_by(fn({tld, stats}) -> Map.get(stats, "total", 0) end, &>=/2)
    |> Enum.reject(fn({tld, _}) -> tld == nil end)

    domains = Enum.reduce(totals_domain, %{}, fn({tld, total}, acc) ->
      actual_tld = tld
      up = Map.get(up_domain, tld, 0)
      per_server = Enum.reduce(Map.get(per_server_all_domain, tld, %{}), %{}, fn({server, total}, acc) ->
        if server do
          up = get_in(per_server_up_domain, [tld, server]) || 0
          Map.put(acc, server, %{"total" => total, "up" => up, "down" => total-up})
        else
          acc
        end
      end)
      Map.put(acc, tld, %{"total" => total, "up" => up, "down" => total-up, "per_server" => per_server})
    end)
    |> Enum.sort_by(fn({tld, stats}) -> Map.get(stats, "total", 0) end, &>=/2)
    |> Enum.reject(fn({tld, _}) -> tld == nil end)

    %{"tlds" => tlds, "domains" => domains}
  end

  defp per_server_reducer([nil, _, _, _, _], acc), do: acc
  defp per_server_reducer([server_id, tld, count], acc) do
    data = Map.get(acc, tld, %{})
    |> Map.put(server_id, count)
    Map.put(acc, tld, data)
  end

end

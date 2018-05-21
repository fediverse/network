defmodule FdWeb.PageController do
  use FdWeb, :controller
  
  alias Fd.Instances

  def index(conn, _params) do
    render conn, "index.html"
  end

  def about(conn, _params) do
    render conn, "about.html"
  end


  def info(conn, _params) do
    render conn, "info.html"
  end

  def monitoring(conn, _params) do
    conn
    |> assign(:title, "Instance Monitoring")
    |> render("monitoring.html")
  end

  def stats(conn, params) do
    stats = get_global_stats(params)
    render(conn, "stats.html", stats: stats)
  end


  defp get_global_stats(params) do
    interval      = Map.get(params, "interval", "3hour")
    Fd.Cache.lazy("global_stats:#{interval}", fn(interval) ->
      stats         = Instances.get_global_statistics(interval)
      get_serie = fn(stats, key) ->
        Enum.map(stats, fn(stat) -> Map.get(stat, key, 0)||0 end)
        |> Enum.reverse()
      end
      get_mg_serie = fn(stats, key) ->
        stats
        |> Enum.map(fn(stat) ->
          value = Map.get(stat, key, 0)||0
          date = Map.get(stat, "date")
          %{"date" => date, "value" => value}
        end)
        |> Enum.reverse
      end
      %{
        dates: get_serie.(stats, "date"),
        users: get_serie.(stats, "users"),
        statuses: get_serie.(stats, "statuses"),
        peers: get_serie.(stats, "peers"),
        emojis: get_serie.(stats, "emojis"),
        mg_users: get_mg_serie.(stats, "users"),
        mg_new_users: get_mg_serie.(stats, "new_users"),
        mg_statuses: get_mg_serie.(stats, "statuses"),
        mg_new_statuses: get_mg_serie.(stats, "new_statuses"),
        mg_peers: get_mg_serie.(stats, "peers"),
        mg_new_peers: get_mg_serie.(stats, "new_peers"),
        mg_emojis: get_mg_serie.(stats, "emojis"),
        mg_new_emojis: get_mg_serie.(stats, "new_emojis"),
        mg_instances: get_mg_serie.(stats, "instances"),
        interval: interval,
    } end, [interval])
  end

end

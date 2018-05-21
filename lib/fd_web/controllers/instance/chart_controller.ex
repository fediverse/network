defmodule FdWeb.InstanceChartController do
  use FdWeb, :controller
  alias Fd.Instances
  require Logger

  @graph_names ["users", "users_new", "statuses", "statuses_new"]
  @graph_keys %{"users" => :mg_users, "users_new" => :mg_new_users, "statuses" => :mg_statuses, "statuses_new" =>
    :mg_new_statuses}

  def show(conn, params = %{"instance_id" => id, "name" => name}) do
    [name, extension] = String.split(name, ".", parts: 2)
    params = Map.put(params, "extension", extension)
    proxy(conn, id, name, params)
  end

  defp proxy(conn, id, name, params) do #when name in @graph_names do
    instance      = Instances.get_instance_by_domain!(id)
    {:ok, stats, _ttl}         = FdWeb.InstanceController.get_instance_stats(instance, params)

    proxy_graph(conn, stats, name, params)
  end

  # Graph parameters:
  #   - width (w)
  #   - height (h)
  #
  # Chartd params:
  #   - w (width)
  #   - h (height)
  #   - t (title)
  #   - dX (X=0..5) dataset
  #   - ymin (min y axis)
  #   - ymax (max y axis)
  #   - step (makes a step graph)
  #   - hl=1 (hilight last point)
  #   - ol=1, or=1 (hide left or right y axis)
  #   - xmin, xmax (min/max x axis, unix timestamp)
  #   - sX, fX (X=0..5) stroke and background colour for dataset X
  #     appending "." to the sX makes it dotted style
  #     appending "-" to the sX makes it dashed style

  @styles %{
    "default" => %{
      "w" => 580,
      "h" => 180,
      "or" => 1,
    },
    "sparkline" => %{
      "s0" => "222222",
      "w" => 50,
      "h" => 16,
      "or" => 1,
      "ol" => 1,
    },
  }
  defp proxy_graph(conn, stats, name, params) do
    style = Map.get(@styles, Map.get(params, "style", "default"), %{})
    datasets = collect_datasets(stats, name)
    graph_params = %{}
    |> Map.merge(style)
    |> Map.merge(datasets)

    path = case Map.get(params, "extension", "svg") do
      ext when ext in ["png", "svg"] -> "/a.#{ext}"
      true -> "/a.svg"
    end

    uri = %URI{host: "chartd.co", scheme: "https", path: path, query: URI.encode_query(graph_params)}
    uri_s = URI.to_string(uri)

    headers = %{
      "User-Agent" => "fediverse.network chart proxy (root@fediverse.network)"
    }
    options = [hackney: [pool: :hackney_chartd]]

    case HTTPoison.get(uri_s, headers, options) do
      {:ok, resp = %HTTPoison.Response{status_code: 200, body: body, headers: headers}} ->
        headers = Enum.reduce(headers, %{}, fn({key, value}, acc) ->
          Map.put(acc, String.downcase(key), value)
        end)
        content_type = Map.get(headers, "content-type", "image/png")
        conn
        |> put_resp_header("content-type", content_type)
        |> put_resp_header("cache-control", "public, max-age=1800")
        |> send_resp(200, body)
      error ->
        Logger.error "Failed to proxy chartd: #{inspect error}"
        conn
        |> send_resp(503, "error")
    end
  end

  def collect_datasets(stats, name) do
    names = String.split(name, ",")
    |> Enum.with_index()
    data = for {name, idx} when idx < 5 <- names do
      points = Map.get(stats, Map.get(@graph_keys, name))
      if points do
        first = List.first(points)
        last = List.last(points)
        first_ts = if first do
          DateTime.to_unix(first["date"])
        end
        last_ts = if last do
          DateTime.to_unix(last["date"])
        end
        points = Enum.map(points, fn(%{"value" => value}) -> value || 0 end)
        {first_ts, last_ts, idx, points}
      end
    end
    |> Enum.reverse()
    [{first_ts, last_ts, _, _} | _] = data
    Enum.reduce(data, %{}, fn({_, _, idx, points}, acc) -> Map.put(acc, "d"<>to_string(idx), encode_data(points)) end)
  end

  @b62 "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  def encode_data(data) when is_list(data) do
    min = Enum.min(data)
    max = Enum.max(data)
    count = Enum.count(data)
    dim = dim(max, min)
    if dim == 0 do
      data
      |> Enum.map(fn(_) -> String.at(@b62, 0) end)
      |> Enum.join("")
    else
      enclen = String.length(@b62) - 1
      data
      |> Enum.map(fn(value) ->
        index = trunc((enclen * (value - min) / dim))
        if index >= 0 && index < String.length(@b62) do
          String.at(@b62, index)
        else
          String.at(@b62, 0)
        end
      end)
      |> Enum.join("")
    end
  end

  defp dim(x, y) when x < y, do: 0
  defp dim(x, y), do: x - y

end

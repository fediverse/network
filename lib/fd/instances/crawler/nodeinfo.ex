defmodule Fd.Instances.Crawler.Nodeinfo do
  alias Fd.Instances.Crawler
  require Logger

  import Crawler, only: [debug: 2, info: 2, error: 2, request: 2, request: 3], warn: false

  #def query_nodeinfo(crawler = %Crawler{halted?: false, s_config: %{"site" => %{"platform" => %{"PLATFORM_NAME" => server}}}}) when server in @nodeinfo_servers, do: do_query_nodeinfo(crawler)
  #def query_nodeinfo(crawler = %Crawler{halted?: false, s_config: %{"site" => %{"friendica" => _}}}), do: do_query_nodeinfo(crawler)
  def query(crawler = %Crawler{has_mastapi?: true, has_statusnet?: false}), do: crawler
  def query(crawler = %Crawler{has_peertubeapi?: true}), do: crawler
  def query(crawler = %Crawler{halted?: false}), do: query_well_known(crawler)
  def query(crawler), do: crawler

  @not_found [404]
  @down_http_codes Crawler.down_http_codes()

  defp query_well_known(crawler) do
    case request(crawler, "/.well-known/nodeinfo", [accept: "application/jrd+json, application/json"]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        debug(crawler, "got /.well-known/nodeinfo " <> inspect(body))
        %Crawler{crawler | has_nodeinfo?: true, nodeinfo_schema: body}
        |> query_nodeinfo()
      {:ok, %HTTPoison.Response{status_code: code}} when code in @not_found ->
        debug(crawler, ".well-known/nodeinfo is not found. #{inspect code}")
        %Crawler{crawler | has_nodeinfo?: false}
      {:ok, %HTTPoison.Response{status_code: code}} when code not in @down_http_codes  ->
        debug(crawler, "nodeinfo well-known responded with an invalid code, maybe down or not found: #{inspect code}")
        crawler
      {:error, %Jason.DecodeError{}} ->
        debug(crawler, "nodeinfo json decode error, skipping")
        crawler
      failed ->
        debug(crawler, "host is down " <> inspect(failed))
        %Crawler{crawler | halted?: true, fatal_error: failed}
    end
  end

  defp query_nodeinfo(crawler = %Crawler{has_nodeinfo?: true, nodeinfo_schema: %{"links" => schemas}}) do
    links = Enum.reduce(schemas, [], fn(schema, acc) ->
      href = Map.get(schema, "href")
      uri = URI.parse(href)
      version = detect_version(Map.get(schema, "rel"))
      if version && uri.host == crawler.instance.domain do
        [{version, uri.path} | acc]
      else
        acc
      end
    end)
    |> Enum.sort_by(fn({v, _}) -> v end, &>=/2)
    {version, path} = List.first(links)
    query_nodeinfo(crawler, version, path)
  end

  defp query_nodeinfo(crawler, version, path) do
    error(crawler, "Should crawl Nodeinfo ver #{inspect version} at path #{inspect path}")
    case request(crawler, path) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        debug(crawler, "got nodeinfo#{inspect version} #{inspect path} " <> inspect(body))
        %Crawler{crawler | has_nodeinfo?: true, nodeinfo: body}
      {:ok, %HTTPoison.Response{status_code: code}} when code in @not_found ->
        debug(crawler, "nodeinfo #{path} is not found. #{inspect code}")
        %Crawler{crawler | has_nodeinfo?: false}
      {:ok, %HTTPoison.Response{status_code: code}} when code not in @down_http_codes  ->
        debug(crawler, "nodeinfo #{path} responded with an invalid code, maybe down or not found: #{inspect code}")
        crawler
      {:error, %Jason.DecodeError{}} ->
        debug(crawler, "nodeinfo #{path} json decode error, skipping")
        crawler
      failed ->
        debug(crawler, "host is down " <> inspect(failed))
        %Crawler{crawler | halted?: true, fatal_error: failed}
    end
  end

  defp detect_version("http://nodeinfo.diaspora.software/ns/schema/"<>float) do
    case Float.parse(float) do
      {version, _} -> version
      _ -> nil
    end
  end

  defp detect_version(_), do: nil

end

defmodule FdWeb.InstanceController do
  use FdWeb, :controller

  alias Fd.Instances
  alias Fd.Repo
  alias Fd.Instances.{Instance, InstanceCheck}
  import Ecto.Query, warn: false

  plug :cache_headers

  def cache_headers(conn, _) do
    conn
  end

  def index(conn, %{"tag" => tag_name} = params) do
    {_, filters, stats} = basic_filter(conn, Map.put(params, "up", "all"))

    tag = from(t in Fd.Tags.Tag, where: t.name == ^tag_name)
        |> Repo.one!

    tag = if tag.canonical_id do
      Repo.preload(tag, :canonical).canonical
    else
      tag
    end

    if tag_name == tag.name do
      i = from(t in Fd.Tags.Tag, where: t.id == ^tag.id or (t.canonical_id == ^tag.id))
      |> join(:inner, [t], tg in Fd.Tags.Tagging, (tg.tag_id == t.id) or (tg.tag_id in t.includes))
      |> join(:inner, [t, tg], i in Fd.Instances.Instance, tg.instance_id == i.id)
      |> select([t, _, i], i)
      |> Repo.all

      ids = Enum.map(i, fn(i) -> i.id end)
      stats = from(i in Instance,
        where: i.id in ^ids,
        select: %{
          "instances" => count(i.id),
          "users" => sum(i.users),
          "statuses" => sum(i.statuses)
        })
        |> Repo.one

      title = "#{tag.name} instances"

      conn
      |> assign(:title, title)
      |> assign(:tag, tag)
      |> render("index.html", instances: i, title: title, stats: stats, filters: nil)
    else
      redirect(conn, to: instance_tag_path(conn, :index, tag.name))
    end
  end

  def index(conn = %{request_path: "/all"}, params) do
    {instances, filters, stats} = basic_filter(conn, Map.put(params, "up", "all"))
    conn
    |> assign(:title, "All Instances")
    |> render("index.html", stats: stats, instances: instances, title: "All Instances", filters: filters)
  end

  def index(conn = %{request_path: "/down"}, params) do
    {instances, filters, stats} = basic_filter(conn, Map.put(params, "up", "false"))
    conn
    |> assign(:title, "Down Instances")
    |> render("index.html", stats: stats, instances: instances, title: "Down Instances", filters: filters)
  end

  def index(conn = %{request_path: "/oldest"}, params) do
    {instances, filters, stats} = basic_filter(conn, Map.put(params, "age", "oldest"))
    conn
    |> assign(:title, "Oldest Instances")
    |> render("index.html", stats: stats, instances: instances, title: "Oldest Instances", filters: filters)
  end

  def index(conn = %{request_path: "/newest"}, params) do
    {instances, filters, stats} = basic_filter(conn, Map.put(params, "age", "newest"))
    conn
    |> assign(:title, "Newest Instances")
    |> render("index.html", stats: stats, instances: instances, title: "Newest Instances", filters: filters)
  end

  def index(conn = %{request_path: "/closed"}, params) do
    {instances, filters, stats} = basic_filter(conn, Map.merge(params, %{"up" => "all", "closed" => "true"}))
    conn
    |> assign(:title, "Closed Instances")
    |> render("index.html", stats: stats, instances: instances, title: "Closed Instances", filters: filters)
  end

  def tld(conn, _) do
    stats = Fd.HostStats.get()
    conn
    |> assign(:title, "Instances per TLD")
    |> render("tld.html", stats: stats)
  end

  def domain(conn, _) do
    stats = Fd.HostStats.get()
    conn
    |> assign(:title, "Instances per domain")
    |> render("domain.html", stats: stats)
  end


  for s <- Fd.ServerName.list_names() do
    path = Fd.ServerName.route_path(s)
    display_name = Fd.ServerName.display_name(s)
    def index(conn = %{request_path: unquote(path)}, params) do
      params = Map.put(params, "server", unquote(path))
      {instances, filters, stats} = basic_filter(conn, params)
      conn
      |> assign(:title, unquote(display_name))
      |> render("index.html", stats: stats, instances: instances, title: "#{unquote(display_name)} Instances", filters: filters)
    end
  end

  def index(conn, params) do
    {instances, filters, stats} = basic_filter(conn, params)
    title = case params do
      %{"domain" => domain} -> "Instances on #{domain} sub-domains"
      %{"tld" => tld} -> "Instances on TLD .#{tld}"
      _ -> "Instances"
    end
    conn
    |> assign(:title, title)
    |> render("index.html", stats: stats, instances: instances, title: title, filters: filters)
  end

  def new(conn, _params) do
    changeset = Instances.change_instance(%Instance{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"instance" => instance_params}) do
    case Instances.create_instance(instance_params) do
      {:ok, instance} ->
        conn
        |> put_flash(:info, "Instance added successfully.")
        |> redirect(to: instance_path(conn, :show, instance))
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def federation(conn, params = %{"instance_id" => id}) do
    instance = Instances.get_instance_by_domain!(id)
    conn
    |> assign(:title, "#{Fd.Util.idna(instance.domain)} Federation Restrictions")
    |> assign(:private, Instances.Instance.hidden?(instance))
    |> assign(:section, "federation")
    |> render(FdWeb.InstanceFederationView, "show.html", instance: instance)
  end

  def public_timeline(conn, params = %{"instance_id" => id}) do
    instance = Instances.get_instance_by_domain!(id)
    if instance.server == 2 or instance.server == 3 do

      timeline_url = Pleroma.Web.MediaProxy.url("https://#{instance.domain}/api/v1/timelines/public.json?limit=50&local=true")

      req = timeline_url
             |> HTTPoison.get!()

      data = Poison.decode!(req.body)

      conn
      |> json(data)
    else
      send_resp(conn, 404, "not supported")
    end
  end

  def timeline(conn, params = %{"instance_id" => id}) do
    instance = Instances.get_instance_by_domain!(id)
    if instance.server == 2 or instance.server == 3 do

      conn
      |> assign(:title, "#{Fd.Util.idna(instance.domain)} Timeline")
      |> assign(:section, "timeline")
      |> render("timeline.html", instance: instance)
    else
      send_resp(conn, 404, "not supported")
    end
  end

  def show(conn, params = %{"id" => id}) do
    instance      = Instances.get_instance_by_domain!(id)
    iid           = instance.id
    checks        = Fd.Instances.get_instance_last_checks_overview(instance, 220)
    last_up_check = Instances.get_instance_last_up_check(instance)
    host_stats    = Fd.HostStats.get()
    stats         = Fd.Cache.lazy("web:i:#{instance.id}:stats", &get_instance_stats/2, [instance, params])

    if Application.get_env(:fd, :instances)[:readrepair] do
      Fd.Instances.Server.crawl(instance.id)
    end

    conn
    |> assign(:title, "#{Fd.Util.idna(instance.domain)} - #{Fd.ServerName.from_int(instance.server)}")
    |> assign(:private, Instances.Instance.hidden?(instance))
    |> assign(:section, "summary")
    |> render("show.html", instance: instance, last_up_check: last_up_check, checks: checks, host_stats: host_stats, stats: stats)
  end

  def stats(conn, params = %{"instance_id" => id}) do
    instance      = Instances.get_instance_by_domain!(id)
    stats         = Fd.Cache.lazy("web:i:#{instance.id}:stats:#{conn.query_string}", &get_instance_stats/2, [instance, params])

    conn
    |> assign(:title, "#{Fd.Util.idna(instance.domain)} statistics")
    |> assign(:section, "stats")
    |> assign(:private, Instances.Instance.hidden?(instance))
    |> render("stats.html", instance: instance, stats: stats)
  end

  def checks(conn, params = %{"instance_id" => id}) do
    instance      = Instances.get_instance_by_domain!(id)
    checks        = Instances.get_instance_last_checks(instance, 500)

    conn
    |> assign(:title, "#{Fd.Util.idna(instance.domain)} checks")
    |> assign(:section, "checks")
    |> assign(:private, Instances.Instance.hidden?(instance))
    |> render("checks.html", instance: instance, checks: checks)
  end

  def nodeinfo(conn, params = %{"instance_id" => id}) do
    instance = Instances.get_instance_by_domain!(id)

    if instance.nodeinfo && !Enum.empty?(instance.nodeinfo) do
      conn
      |> assign(:title, "#{Fd.Util.idna(instance.domain)} nodeinfo")
      |> assign(:private, Instances.Instance.hidden?(instance))
      |> render("nodeinfo.html", instance: instance)
    else
      conn
      |> redirect(to: instance_path(conn, :show, instance))
    end
  end

  @allowed_filters ["up", "closed", "server", "age", "tld", "domain", "users", "statuses", "emojis", "peers", "max_chars"]
  defp basic_filter(conn,params) do
    Fd.Cache.lazy("list:#{conn.request_path}?#{conn.query_string}", &run_basic_filter/1, [params])
  end
  defp run_basic_filter(params) do
    filters = params
    |> Enum.map(fn({param, value}) ->
      value = case value do
        "/"<>something -> something
        other -> other
      end
      {param, value}
    end)
    |> Enum.filter(fn({key, _}) -> Enum.member?(@allowed_filters, key) end)
    |> Enum.into(Map.new)
    |> Map.put_new("up", "true")
    |> Map.put_new("server", "known")
    instances = Enum.reduce(filters, from(i in Instance), &basic_filter_reduce/2)
    |> select([q], %Instance{id: q.id, domain: q.domain, up: q.up, server: q.server, statuses: q.statuses, users: q.users,
      peers: q.peers, emojis: q.emojis, hidden: q.hidden, signup: q.signup, dead: q.dead, version: q.version,
      inserted_at: q.inserted_at, max_chars: q.max_chars, settings: q.settings})
    |> Fd.Repo.all

    {instances, filters, Fd.GlobalStats.get()}
  end

  def get_instance_stats(instance, params) do
    interval      = Map.get(params, "interval", "hourly")
    limit         = Map.get(params, "limit", nil)
    {stats, ttl}         = Instances.get_instance_statistics(instance.id, interval)
    get_serie = fn(stats, key) ->
      Enum.map(stats, fn(stat) -> Map.get(stat, key, 0)||0 end)
      |> Enum.reverse()
    end
    get_mg_serie = fn(stats, key, opts) ->
      stats
      |> Enum.map(fn(stat) ->
        value = Map.get(stat, key)
        value = if Keyword.get(opts, :non_neg, false) && value < 0 do
          0
        else value end
        date = Map.get(stat, "date")
        %{"date" => date, "value" => value}
      end)
      |> Enum.reverse
    end
    stats = %{
      #dates: get_serie.(stats, "date"),
      #users: get_serie.(stats, "users"),
      #statuses: get_serie.(stats, "statuses"),
      #peers: get_serie.(stats, "peers"),
      #emojis: get_serie.(stats, "emojis"),
      mg_users: get_mg_serie.(stats, "users", []),
      mg_new_users: get_mg_serie.(stats, "new_users", [non_neg: true]),
      mg_statuses: get_mg_serie.(stats, "statuses", []),
      mg_new_statuses: get_mg_serie.(stats, "new_statuses", [non_neg: true]),
      mg_peers: get_mg_serie.(stats, "peers", []),
      mg_new_peers: get_mg_serie.(stats, "new_peers", [non_neg: true]),
      mg_emojis: get_mg_serie.(stats, "emojis", []),
      mg_new_emojis: get_mg_serie.(stats, "new_emojis", [non_neg: true]),
      interval: interval,
    }
    {:ok, stats, ttl}
  end

  defp basic_filter_reduce({"up", "true"}, query) do
    where(query, [i], i.up == true)
  end
  defp basic_filter_reduce({"up", "false"}, query) do
    where(query, [i], i.up != true)
  end
  defp basic_filter_reduce({"up", "all"}, query) do
    query
  end

  defp basic_filter_reduce({"closed", "true"}, query) do
    where(query, [i], i.dead or fragment("? < NOW() - INTERVAL '30 days'", i.last_up_at))
    |> order_by([i], [desc: i.last_up_at])
  end

  defp basic_filter_reduce({"server", "all"}, query) do
    query
  end
  defp basic_filter_reduce({"server", "known"}, query) do
    where(query, [i], i.server != 0)
  end
  defp basic_filter_reduce({"server", server}, query) do
    int = Fd.ServerName.to_int(String.downcase(server))
    where(query, [i], i.server == ^int)
  end

  defp basic_filter_reduce({"age", "oldest"}, query) do
    order_by(query, [i], [asc: i.inserted_at])
  end
  defp basic_filter_reduce({"age", "newest"}, query) do
    order_by(query, [i], [desc: i.inserted_at])
  end

  defp basic_filter_reduce({"users", "asc"}, query) do
    query
    |> where([i], not is_nil(i.users))
    |> order_by([i], [asc: i.users])
  end
  defp basic_filter_reduce({"users", "desc"}, query) do
    query
    |> where([i], not is_nil(i.users))
    |> order_by([i], [desc: i.users])
  end

  defp basic_filter_reduce({"statuses", "asc"}, query) do
    query
    |> where([i], not is_nil(i.statuses))
    |> order_by([i], [asc: i.statuses])
  end
  defp basic_filter_reduce({"statuses", "desc"}, query) do
    query
    |> where([i], not is_nil(i.statuses))
    |> order_by([i], [desc: i.statuses])
  end

  defp basic_filter_reduce({"max_chars", "asc"}, query) do
    query
    |> where([i], not is_nil(i.max_chars))
    |> order_by([i], [asc: i.max_chars])
  end
  defp basic_filter_reduce({"max_chars", "desc"}, query) do
    query
    |> where([i], not is_nil(i.max_chars))
    |> order_by([i], [desc: i.max_chars])
  end

  defp basic_filter_reduce({"emojis", "asc"}, query) do
    query
    |> where([i], not is_nil(i.emojis))
    |> order_by([i], [asc: i.emojis])
  end
  defp basic_filter_reduce({"emojis", "desc"}, query) do
    query
    |> where([i], not is_nil(i.emojis))
    |> order_by([i], [desc: i.emojis])
  end

  defp basic_filter_reduce({"peers", "asc"}, query) do
    query
    |> where([i], not is_nil(i.peers))
    |> order_by([i], [asc: i.peers])
  end
  defp basic_filter_reduce({"peers", "desc"}, query) do
    query
    |> where([i], not is_nil(i.peers))
    |> order_by([i], [desc: i.peers])
  end

  defp basic_filter_reduce({"tld", tld}, query) do
    tld = Fd.Util.from_idna(tld)
    where(query, [i], i.domain_suffix == ^tld)
  end
  defp basic_filter_reduce({"domain", domain}, query) do
    domain = Fd.Util.from_idna(domain)
    where(query, [i], i.domain_base == ^domain or i.domain == ^domain)
  end

  defp basic_filter_reduce(_, query), do: query


end

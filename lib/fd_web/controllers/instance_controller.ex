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

  def index(conn = %{request_path: "/all"}, params) do
    {instances, filters, stats} = basic_filter(Map.put(params, "up", "all"))
    conn
    |> assign(:title, "All Instances")
    |> render("index.html", stats: stats, instances: instances, title: "All Instances", filters: filters)
  end

  def index(conn = %{request_path: "/down"}, params) do
    {instances, filters, stats} = basic_filter(Map.put(params, "up", "false"))
    conn
    |> assign(:title, "Down Instances")
    |> render("index.html", stats: stats, instances: instances, title: "Down Instances", filters: filters)
  end

  def index(conn = %{request_path: "/oldest"}, params) do
    {instances, filters, stats} = basic_filter(Map.put(params, "age", "oldest"))
    conn
    |> assign(:title, "Oldest Instances")
    |> render("index.html", stats: stats, instances: instances, title: "Oldest Instances", filters: filters)
  end

  def index(conn = %{request_path: "/newest"}, params) do
    {instances, filters, stats} = basic_filter(Map.put(params, "age", "newest"))
    conn
    |> assign(:title, "Newest Instances")
    |> render("index.html", stats: stats, instances: instances, title: "Newest Instances", filters: filters)
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
    def index(conn = %{request_path: unquote(path)}, params) do
      params = Map.put(params, "server", unquote(path))
      {instances, filters, stats} = basic_filter(params)
      conn
      |> assign(:title, unquote(s))
      |> render("index.html", stats: stats, instances: instances, title: "#{unquote(s)} Instances", filters: filters)
    end
  end

  def index(conn, params) do
    {instances, filters, stats} = basic_filter(params)
    render(conn, "index.html", stats: stats, instances: instances, title: "Instances", filters: filters)
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

  def show(conn, params = %{"id" => id}) do
    instance      = Instances.get_instance_by_domain!(id)
    iid           = instance.id
    checks        = Repo.all from(c in InstanceCheck, where: c.instance_id == ^iid, limit: 35, order_by: [desc: c.updated_at])
    last_up_check = Instances.get_instance_last_up_check(instance)
    host_stats    = Fd.HostStats.get()
    stats         = get_instance_stats(instance, params)

    if Application.get_env(:fd, :instances)[:readrepair] do
      Fd.Instances.Server.crawl(instance.id)
    end

    conn
    |> assign(:title, "#{Fd.Util.idna(instance.domain)} - #{Fd.ServerName.from_int(instance.server)}")
    |> assign(:private, instance.hidden)
    |> assign(:section, "summary")
    |> render("show.html", instance: instance, last_up_check: last_up_check, checks: checks, host_stats: host_stats, stats: stats)
  end

  def stats(conn, params = %{"instance_id" => id}) do
    instance = Instances.get_instance_by_domain!(id)
    stats    = get_instance_stats(instance, params)

    conn
    |> assign(:title, "#{Fd.Util.idna(instance.domain)} statistics")
    |> assign(:section, "stats")
    |> assign(:private, instance.hidden)
    |> render("stats.html", instance: instance, stats: stats)
  end

  def checks(conn, params = %{"instance_id" => id}) do
    instance      = Instances.get_instance_by_domain!(id)
    iid           = instance.id
    checks        = Repo.all from(c in InstanceCheck, where: c.instance_id == ^iid, limit: 500, order_by: [desc: c.updated_at])

    conn
    |> assign(:title, "#{Fd.Util.idna(instance.domain)} checks")
    |> assign(:section, "checks")
    |> assign(:private, instance.hidden)
    |> render("checks.html", instance: instance, checks: checks)
  end

  @allowed_filters ["up", "server", "age", "tld", "domain", "users", "statuses", "emojis", "peers", "max_chars"]
  defp basic_filter(params) do
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
      inserted_at: q.inserted_at, max_chars: q.max_chars})
    |> Fd.Repo.all

    {instances, filters, Fd.GlobalStats.get()}
  end

  defp get_instance_stats(instance, params) do
    default_interval = if instance.monitor, do: "hourly", else: "3hour"
    interval      = Map.get(params, "interval", default_interval)
    stats         = Instances.get_instance_statistics(instance.id, interval)
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
      interval: interval,
    }
  end

  defp basic_filter_reduce({"up", "true"}, query) do
    where(query, [i], i.up == true)
  end
  defp basic_filter_reduce({"up", "false"}, query) do
    where(query, [i], i.up != true)
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

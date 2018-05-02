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

  @allowed_filters ["up", "server", "age", "tld", "domain", "users", "statuses", "emojis", "peers"]
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
    |> Fd.Repo.all

    {instances, filters, Fd.GlobalStats.get()}
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

  def show(conn, %{"id" => id}) do
    instance      = Instances.get_instance_by_domain!(id)
    iid           = instance.id
    usm           = Instances.get_instance_users(iid)
    users         = Enum.map(usm, fn r -> r["users"] end)
    months        = Enum.map(usm, fn r -> r["updated_at"] |> elem(0) |> Date.from_erl! |> Date.to_iso8601 end)
    checks        = Repo.all from(c in InstanceCheck, where: c.instance_id == ^iid, limit: 35, order_by: [desc: c.updated_at])
    last_up_check = Instances.get_instance_last_up_check(instance)

    s_w           = Instances.get_instance_statuses(iid)
    weeks         = Enum.map(s_w, fn s -> trunc(s["week"]) end)
    statuses      = Enum.map(s_w, fn s -> trunc(s["statuses"]) end)


    if Application.get_env(:fd, :instances)[:readrepair] do
      Fd.Instances.Server.crawl(instance.id)
    end
    host_stats = Fd.HostStats.get()
    conn
    |> assign(:title, "#{Fd.Util.idna(instance.domain)} - #{Fd.ServerName.from_int(instance.server)}")
    |> assign(:private, instance.hidden)
    |> render("show.html", instance: instance, last_up_check: last_up_check, checks: checks, host_stats: host_stats,
                           users: users, months: months, weeks: weeks, statuses: statuses)
  end

  def checks(conn, params) do
    checks = from(c in InstanceCheck, limit: 250, order_by: [desc: c.updated_at])
    checks = Enum.reduce(params, checks, &check_filter_reduce/2)

    checks = checks
    |> Fd.Repo.all
    |> Fd.Repo.preload(:instance)
    conn
    |> assign(:title, "Checks")
    |> render("checks.html", checks: checks)
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

  defp check_filter_reduce({"error", error}, query) do
    where(query, [c], c.error_s == ^error)
  end
  defp check_filter_reduce(_, query), do: query

end

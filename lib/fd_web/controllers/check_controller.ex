defmodule FdWeb.CheckController do
  use FdWeb, :controller

  alias Fd.Repo
  alias Fd.Instances
  alias Fd.Instances.{InstanceCheck}
  import Ecto.Query, warn: false

  def index(conn, params) do
    checks = from(c in InstanceCheck, limit: 500, order_by: [desc: c.updated_at])
    checks = Enum.reduce(params, checks, &check_filter_reduce/2)

    checks = checks
    |> Repo.all
    |> Repo.preload(:instance)
    conn
    |> assign(:title, "Latest Checks")
    |> render("index.html", checks: checks)
  end

  def show(conn, params = %{"instance_id" => id, "from_time" => from_time_iso}) do
    instance = Instances.get_instance_by_domain!(id)
    iid = instance.id
    to_time_iso = Map.get(params, "to_time", from_time_iso)
    from_time = NaiveDateTime.from_iso8601!(from_time_iso)
    to_time = NaiveDateTime.from_iso8601!(to_time_iso)
    range? = !(from_time_iso == to_time_iso)
    checks = from(c in InstanceCheck,
      where: c.instance_id == ^iid and c.updated_at >= ^from_time and c.updated_at <= ^to_time,
      order_by: [asc: c.updated_at]
    )
    |> Repo.all
    title = if range?, do: "from #{from_time} to #{to_time}", else: "at #{from_time}"
    conn
    |> assign(:section, "checks")
    |> assign(:title, "Checks on #{instance.domain} #{title}")
    |> assign(:private, Instances.Instance.hidden?(instance))
    |> render("show.html", checks: checks, instance: instance, range?: range?, from_time: from_time, to_time: to_time)
  end

  defp check_filter_reduce({"error", error}, query) do
    where(query, [c], c.error_s == ^error)
  end
  defp check_filter_reduce(_, query), do: query

end

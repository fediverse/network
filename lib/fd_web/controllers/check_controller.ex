defmodule FdWeb.CheckController do
  use FdWeb, :controller

  alias Fd.Repo
  alias Fd.Instances.{InstanceCheck}
  import Ecto.Query, warn: false

  def index(conn, params) do
    checks = from(c in InstanceCheck, limit: 500, order_by: [desc: c.updated_at])
    checks = Enum.reduce(params, checks, &check_filter_reduce/2)

    checks = checks
    |> Fd.Repo.all
    |> Fd.Repo.preload(:instance)
    conn
    |> assign(:title, "Latest Checks")
    |> render("index.html", checks: checks)
  end
  defp check_filter_reduce({"error", error}, query) do
    where(query, [c], c.error_s == ^error)
  end
  defp check_filter_reduce(_, query), do: query

end

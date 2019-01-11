defmodule FdWeb.ReportController do
  use FdWeb, :controller

  alias Fd.Stats

  def show(conn, %{"report" => "2018"}) do
    stats = Stats.file_evolution(%{"from" => "2018-04-30", "to" => "2018-12-31"})

    conn
    |> assign(:title, "🎉 2018 Report")
    |> render("show.html", [
      stats: stats,
      name: "2018"
    ])
  end

end

defmodule FdWeb.PageController do
  use FdWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end

  def info(conn, _params) do
    render conn, "info.html"
  end

  def monitoring(conn, _params) do
    conn
    |> assign(:title, "Instance Monitoring")
    |> render("monitoring.html")
  end

end

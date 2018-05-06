defmodule FdWeb.ManageController do
  use FdWeb, :controller

  alias Fd.{Repo, Instances}
  alias Fd.Instances.{Instance, Server}

  plug :verify_token_plug

  def index(conn = %{assigns: %{instance: instance}}, _) do
    change = Instances.change_instance(instance)
    conn
    |> assign(:title, "Manage #{Fd.Util.idna(instance.domain)}")
    |> render("index.html", instance: instance, changeset: change)
  end

  def index(conn, _) do
    conn
    |> assign(:title, "Manage your instance")
    |> render("login.html")
  end

  def update(conn = %{assigns: %{instance: instance}}, %{"instance" => instance_params}) do
    case Instances.update_manage_instance(instance, instance_params) do
      {:ok, instance} ->
        Server.crawl(instance.id)
        redirect(conn, to: manage_path(conn, :index))
    end
  end

  def send_token(conn, %{"login" => %{"domain" => domain, "email" => email}}) do
    spawn(fn() ->
      import Ecto.Query
      instance = from(i in Instance, where: i.domain == ^domain and i.email == ^email)
      |> Repo.one
      |> Fd.LoginEmail.login()
      |> Fd.Mailer.deliver()
      |> IO.inspect()
    end)

    conn
    |> assign(:title, "Manage your instance")
    |> render("sent.html")
  end

  def send_token(conn, _) do
    redirect(conn, to: manage_path(conn, :index))
  end

  def logout(conn, %{}) do
    conn
    |> put_session(:token, nil)
    |> redirect(to: manage_path(conn, :index))
  end

  def login_by_token(conn, %{"token" => token}) do
    case verify_token(conn, token) do
      {:ok, conn} ->
        conn
        |> put_session(:token, token)
        |> redirect(to: manage_path(conn, :index))
      _ ->
        conn
        |> redirect(to: manage_path(conn, :index))
    end
  end

  def verify_token_plug(conn, _) do
    with \
      token when is_binary(token) <- get_session(conn, :token),
      {:ok, conn} <- verify_token(conn, token)
    do
      conn
    else
      _ -> conn
    end
  end

  defp verify_token(conn, token) do
    with \
      {:ok, "instance:"<>id} <- Phoenix.Token.verify(FdWeb.Endpoint, Application.get_env(:fd, :email_login_salt), token, max_age: (1440*60)*7),
      {id, _} <- Integer.parse(id),
      instance = %Instance{} <- Instances.get_instance!(id)
    do
      conn = conn
      |> assign(:instance, instance)
      {:ok, conn}
    else
      error ->
        IO.puts "Login failed: #{inspect error}"
        {:error, conn}
    end
  end

end


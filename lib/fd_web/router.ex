defmodule FdWeb.Router do
  use FdWeb, :router
  use Plug.ErrorHandler
  use Sentry.Plug

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FdWeb do
    pipe_through :browser # Use the default browser stack

    get "/info", PageController, :info
    get "/about", PageController, :about
    get "/about/:id", PageController, :about_subpage
    get "/monitoring", PageController, :monitoring
    get "/stats", PageController, :stats

    # Define /pleroma, /mastodon, …
    for s <- Fd.ServerName.list_names do
      get Fd.ServerName.route_path(s), InstanceController, :index, as: :instance_sserver
      get Fd.ServerName.route_path(s) <> "/versions", ServerController, as: :server_sversions
    end

    get "/all", InstanceController, :index, as: :instance_all
    get "/down", InstanceController, :index, as: :instance_down
    get "/newest", InstanceController, :index, as: :instance_newest
    get "/oldest", InstanceController, :index, as: :instance_oldest
    get "/closed", InstanceController, :index, as: :instance_closed
    get "/checks", CheckController, :index, as: :latest_checks
    get "/tld", InstanceController, :tld, as: :instance
    get "/tld/:tld", InstanceController, :index, as: :instance_tld
    get "/domain", InstanceController, :domain, as: :instance
    get "/domain/:domain", InstanceController, :index, as: :instance_domain
    get "/t/:tag", InstanceController, :index, as: :instance_tag

    get "/reports/:report", ReportController, :show

    @traps ~w(wp-login.php)
    for trap <- @traps do
      get "/#{trap}", PageController, :trap
    end

    @notfound ~w(statistics.json siteinfo.json poco)
    for notfound <- @notfound do
      get "/#{notfound}", PageController, :not_found
    end

    # Manage
    get "/manage", ManageController, :index, as: :manage
    get "/:instance_id/manage", ManageController, :show, as: :manage
    put "/:instance_id/manage", ManageController, :update, as: :manage
    get "/manage/logout", ManageController, :logout
    post "/manage/login", ManageController, :send_token, as: :manage
    get "/manage/login/:token", ManageController, :login_by_token, as: :manage

    resources "/", InstanceController, only: [:index, :show] do
      get "/nodeinfo", InstanceController, :nodeinfo
      get "/stats", InstanceController, :stats
      get "/stats/:interval", InstanceController, :stats
      get "/emojis", InstanceController, :emojis
      get "/peers", InstanceController, :peers
      get "/federation", InstanceController, :federation
      get "/timeline", InstanceController, :timeline
      get "/public_timeline", InstanceController, :public_timeline
      get "/checks", InstanceController, :checks
      get "/checks/:from_time", CheckController, :show, as: :check
      get "/checks/:from_time/:to_time", CheckController, :show, as: :check
      get "/chart/:name", InstanceChartController, :show, as: :chart
    end

    #resources "/tags", TagController

    # This route will mostly never be directly hit (eaten by instance /:id) but this is for route helpers
    # Real routes are generated per-server by Fd.ServerName.list_names a couple of lines before
    get "/:server", InstanceController, :index, as: :instance_server
    get "/:server/versions", ServerController, :versions, as: :server_versions
  end

  if Mix.env == :dev do
    scope "/dev" do
      pipe_through [:browser]

      forward "/mailbox", Plug.Swoosh.MailboxPreview, [base_path: "/dev/mailbox"]
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", FdWeb do
  #   pipe_through :api
  # end
end

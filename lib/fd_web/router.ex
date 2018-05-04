defmodule FdWeb.Router do
  use FdWeb, :router

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

    #resources "/accounts", AccountController
    get "/info", PageController, :info
    get "/monitoring", PageController, :monitoring

    # Define /pleroma, /mastodon, …
    for s <- Fd.ServerName.list_names do
      get Fd.ServerName.route_path(s), InstanceController, :index, as: :instance_sserver
    end

    get "/all", InstanceController, :index, as: :instance_all
    get "/down", InstanceController, :index, as: :instance_down
    get "/newest", InstanceController, :index, as: :instance_newest
    get "/oldest", InstanceController, :index, as: :instance_oldest
    get "/checks", InstanceController, :checks, as: :latest_checks
    get "/tld", InstanceController, :tld, as: :instance
    get "/tld/:tld", InstanceController, :index, as: :instance_tld
    get "/domain", InstanceController, :domain, as: :instance
    get "/domain/:domain", InstanceController, :index, as: :instance_domain

    # Manage
    get "/manage", ManageController, :index, as: :manage
    put "/manage", ManageController, :update, as: :manage
    get "/manage/logout", ManageController, :logout
    post "/manage/login", ManageController, :send_token, as: :manage
    get "/manage/login/:token", ManageController, :login_by_token, as: :manage

    resources "/", InstanceController, only: [:index, :show] do
      get "/stats", InstanceController, :stats
      get "/stats/:interval", InstanceController, :stats
      get "/emojis", InstanceController, :emojis
      get "/peers", InstanceController, :peers
      get "/checks", InstanceController, :checks
    end

    #resources "/tags", TagController

    # This route will mostly never be directly hit (eaten by instance /:id) but this is for route helpers
    # Real routes are generated per-server by Fd.ServerName.list_names a couple of lines before
    get "/:server", InstanceController, :index, as: :instance_server
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

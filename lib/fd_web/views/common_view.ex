defmodule FdWeb.CommonView do
  use Phoenix.View, root: "lib/fd_web/templates",
                    namespace: FdWeb

  # Import convenience functions from controllers
  import Phoenix.Controller, only: [get_flash: 2, view_module: 1]

  # Use all HTML functionality (forms, tags, etc)
  use Phoenix.HTML

  import FdWeb.Router.Helpers
  import FdWeb.ErrorHelpers
  import FdWeb.Gettext

  def idna(domain) do
    Fd.Util.idna(domain)
  end

  def format_date(date, mode \\ "default") do
    iso = to_iso8601(date)
    content_tag(:time, iso, datetime: iso, "data-controller": "time", "data-mode": mode)
  end

  def remote_follow(conn, username, title \\ nil, submit_opts \\ []) do
    form_for(conn, Pleroma.Web.Router.Helpers.util_path(Pleroma.Web.Endpoint, :remote_subscribe), [class: "form-inline", style: "display: inline;"], fn(f) ->
      [hidden_input(f, :nickname, value: username), hidden_input(f, :profile, value: username), submit(title || username, submit_opts)]
    end)
  end

  defp to_iso8601(naive = %NaiveDateTime{}) do
    NaiveDateTime.to_iso8601(naive) <> "Z"
  end

end

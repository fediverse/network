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
    content_tag(:time, iso, datetime: iso, title: iso, "data-controller": "time", "data-mode": mode)
  end

  def remote_follow(conn, username, title \\ nil, submit_opts \\ []) do
    form_for(conn, Pleroma.Web.Router.Helpers.util_path(Pleroma.Web.Endpoint, :remote_subscribe), [class: "form-inline", style: "display: inline;"], fn(f) ->
      [hidden_input(f, :nickname, value: username), hidden_input(f, :profile, value: username), submit(title || username, submit_opts)]
    end)
  end

  def number(number, options \\ [])

  def number(number, options) when is_integer(number) do
    case Fd.Cldr.Number.to_string(number) do
      {:ok, string} ->
        if Keyword.get(options, :plus) && number > 0 do
          "+#{string}"
        else
          string
        end
      _ -> number
    end
  end

  def number(_, _), do: ["0", content_tag(:sup, "?")]

  def positive(number) when number > 0 do
    "+#{number}"
  end

  def positive(0), do: "0"

  def positive(number) when number < 0 do
    "#{number}"
  end

  defp to_iso8601(string) when is_binary(string) do
    string
  end

  defp to_iso8601(naive = %NaiveDateTime{}) do
    NaiveDateTime.to_iso8601(naive) <> "Z"
  end

end

defmodule FdWeb.LayoutView do
  use FdWeb, :view

  def title(conn = %{assigns: %{title: title}}, site_title) do
    [title, raw(" &mdash; "), site_title]
  end

  def title(_, site_title), do: site_title

end

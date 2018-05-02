defmodule FdWeb.LayoutView do
  use FdWeb, :view

  def title(conn = %{assigns: %{title: title}}, site_title) do
    [title, raw(" &mdash; "), site_title]
  end

  def title(_, site_title), do: site_title

  def private_meta_tag(conn) do
    if Map.get(conn.assigns, :private, false) do
      tag(:meta, name: "robots", content: "noindex, nofollow")
    end
  end

end

defmodule FdWeb.InstanceFederationView do
  use FdWeb, :view
  alias Fd.Instances.Instance

  def render("show.html", %{conn: conn, instance: instance = %Instance{nodeinfo: %{"metadata" => %{"federation" => federation = %{"mrf_policies" => policies}}}}}) do
    render("pleroma_mrf.html", conn: conn, instance: instance, federation: federation, policies: policies)
  end

  def render("show.html", %{conn: conn, instance: instance}) do
    render("none.html", conn: conn, instance: instance)
  end

  def overview(conn, instance = %Instance{nodeinfo: %{"metadata" => %{"federation" => federation = %{"mrf_policies" => policies}}}}) do
    overview_content(link("disclosed (Pleroma MRFs)", to: instance_instance_path(conn, :federation, instance)))
  end

  def overview(conn, instance = %Instance{settings: %{federation_restrictions_link: link}}) when is_binary(link) do
    overview_content(link("disclosed (external list)", to: link))
  end

  def overview(conn, _) do
    #overview_content("unknown or not disclosed")
    ""
  end

  defp overview_content(content) do
    content_tag(:li, [
      content_tag(:span, "Federation restrictions", class: "label"),
      raw("&nbsp;"),
      content_tag(:span, content, class: "value")
    ])
  end

end


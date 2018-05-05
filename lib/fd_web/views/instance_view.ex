defmodule FdWeb.InstanceView do
  use FdWeb, :view

  alias Fd.Instances.Instance

  import FdWeb.CommonView, only: [idna: 1]

  def display_stat(stats, format, keys) do
    value = get_in(stats, keys)
    if value do
      format_stat(format, keys, value)
    end
  end
  def display_stats(stats, format, key, keys) do
    value = get_in(stats, key)
    if value do
      stats = for skey <- keys do
        if val = Map.get(value, skey) do
          format_stat(:inline, [key, skey], val)
        end
      end
      |> Enum.filter(fn(x) -> x end)
      |> Enum.intersperse(" - ")
      if format == :mini do
        ["(", stats, ")"]
      else
        stats
      end
    end
  end


  def format_stat(:mini, keys, value) do
    content_tag(:span, ["(", to_string(value), ")"], title: Enum.join(keys, " "), class: "stat-"<>Enum.join(keys, "-"))
  end
  def format_stat(:inline, keys, value) do
    content_tag(:span, to_string(value), title: Enum.join(keys, " "), class: "stat-"<>Enum.join(keys, "-"))
  end


  def name(instance = %Instance{}) do
    if instance.name && clean_name(instance.name, instance.domain) do
      domain = content_tag(:span, ["(", idna(instance.domain), ")"], class: "instance-domain")
      [instance.name, " ", domain]
    else
      idna(instance.domain)
    end
  end

  def li_item(_, nil), do: nil

  def li_item(title, var) do
    title = content_tag(:strong, title)
    content_tag(:li, [title, ": ", to_string(var)])
  end

  def up_bootstrap_table_class(%Instance{up: true}), do: "success"
  def up_bootstrap_table_class(%Instance{up: false}), do: "danger"
  def up_bootstrap_table_class(_), do: "warning"

  def active_class_bool(true), do: "active"
  def active_class_bool(_), do: ""

  def clean_name("Mastodon", _), do: nil
  def clean_name("Pleroma", _), do: nil
  def clean_name(name, domain) when name == domain, do: nil
  def clean_name(name, _), do: name

  def server_info("known"), do: nil
  def server_info(name) when is_binary(name) do
    server_info(Fd.ServerName.to_int(name))
  end
  def server_info(id) when is_integer(id) do
    case Fd.ServerName.data(id) do
      data when is_map(data) ->
        render("_server_info.html", data: data)
      _ -> nil
    end
  end
  def server_info(_), do: nil

end

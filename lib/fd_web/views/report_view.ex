defmodule FdWeb.ReportView do
  use FdWeb, :view

  def percentage(title, first, last) do
    diff = last - first
    percentage = ((diff / first) * 100)
                 |> Float.ceil()
                 |> trunc()

    percent_str = if percentage > 0 do
      "+#{percentage}%"
    else
      "#{percentage}%"
    end

    [
      content_tag(:span, [percent_str], style: "font-weight: bold; font-size: 110%;"),
      raw("&nbsp;"),
      title,
      raw("&nbsp;"),
      content_tag(:span, [number(diff, plus: true)], style: "font-size: 80%")
    ]
  end

end

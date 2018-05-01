defmodule Fd.ServerName do

  @default "Unknown"
  @servers %{
    1   => "GNUSocial",
    2   => "Mastodon",
    3   => "Pleroma",
    4   => "PeerTube",
    5   => "Hubzilla",
    6   => "PostActiv",
    7   => "Friendica",
    8   => "Kroeg",
  }

  for {id, name} <- @servers do
    named = String.downcase(name)
    path = named
    |> String.downcase()
    |> String.replace(" ", "")
    def from_int(unquote(id)), do: unquote(name)
    def to_int("/"<>unquote(path)), do: unquote(id)
    def to_int(unquote(name)), do: unquote(id)
    def to_int(unquote(named)), do: unquote(id)
    def exists?(unquote(name)), do: true
    def exists?(unquote(named)), do: true
  end

  def from_int(_), do: @default
  def to_int(_), do: 0
  def exists?(_), do: false

  def list_names do
    Enum.map(@servers, fn({_, name}) -> name end) ++ [@default]
  end

  def route_path(id) when is_integer(id) do
    id |> from_int() |> route_path()
  end

  def route_path(name) when is_binary(name) do
    name = name
    |> String.downcase()
    |> String.replace(" ", "")
    "/" <> name
  end

end

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
    8   => "Kroeg", # https://github.com/puckipedia/Kroeg
    9   => "GangGo", # not AP yet but soon https://github.com/ganggo/ganggo/pull/55
    10  => "SocialHome", # not AP yet but soon too
  }
  @server_data %{
    0 => %{
      notice: "Warning: Instances with an unknown server may for now not be real instances. the crawler is still under development and may stumble upon non-instances. This will be fixed soon."
    },
    1 => %{
      link: "https://gnu.io/social/",
      source: "https://git.gnu.io/gnu/gnu-social/",
    },
    2 => %{
      link: "https://joinmastodon.org",
      source: "https://github.com/tootsuite/mastodon",
      other_stats: [
        {"instances.social", "https://instances.social"},
        {"Mastodon Monitoring Project", "https://mnm.social/"},
        {"Sp3r4z's stats", "http://sp3r4z.fr/mastodon/"},
      ],
    },
    3 => %{
      link: "https://pleroma.social",
      description: "Pleroma is an ActivityPub/OStatus server built on Elixir. New and rising!",
      source: "https://git.pleroma.social/pleroma/pleroma",
      other_stats: [
        {"distsn.org list", "https://distsn.org/pleroma-instances.html"},
        {"instances.social", "https://instances.social"},
      ],
    },
    4 => %{
      description: "PeerTube is a video streaming platform",
      link: "https://joinpeertube.org",
      source: "https://github.com/Chocobozzz/PeerTube",
      other_stats: [
        {"instances.joinpeertube.org", "https://instances.joinpeertube.org"}
      ],
    },
    5 => %{
      link: "https://hubzilla.org",
      source: "https://github.com/redmatrix/hubzilla",
    },
    6 => %{
      link: "https://www.postactiv.com",
      source: "http://gitea.postactiv.com/postActiv/postActiv",
    },
    7 => %{
      link: "https://friendi.ca/",
      source: "https://github.com/friendica/friendica",
    },
    8 => %{
      description: "Experimental ActivityPub server in C#",
      source: "https://github.com/puckipedia/Kroeg",
    },
    9 => %{
      hidden: true,
      notice: "Not compatible ActivityPub yet",
      source: "https://github.com/ganggo/ganggo"
    },
    10 => %{
      hidden: true,
      notice: "Not compatible ActivityPub yet",
      source: "https://github.com/jaywink/socialhome",
    },
  }

  for {id, name} <- @servers do
    named = String.downcase(name)
    path = named
    |> String.downcase()
    |> String.replace(" ", "")
    data = Map.get(@server_data, id, nil)
    |> Macro.escape
    def from_int(unquote(id)), do: unquote(name)
    def to_int("/"<>unquote(path)), do: unquote(id)
    def to_int(unquote(name)), do: unquote(id)
    def to_int(unquote(named)), do: unquote(id)
    def exists?(unquote(name)), do: true
    def exists?(unquote(named)), do: true
    def data(unquote(id)), do: unquote(data)
  end

  def from_int(_), do: @default
  def to_int(_), do: 0
  def exists?(_), do: false

  def data(0), do: Map.get(@server_data, 0, nil)
  def data(_), do: nil

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

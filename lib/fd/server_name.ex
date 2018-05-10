defmodule Fd.ServerName do

  @default "Other"
  @servers %{
    1   => "GNUSocial",
    2   => "Mastodon",
    3   => "Pleroma",
    4   => "PeerTube",
    5   => "Hubzilla",
    6   => "PostActiv",
    7   => "Friendica",
    8   => "Kroeg", # https://github.com/puckipedia/Kroeg
    9   => "Misskey",
    10  => "GangGo", # not AP yet but soon https://github.com/ganggo/ganggo/pull/55
    11  => "SocialHome", # not AP yet but soon too
    12  => "Funkwhale",
  }
  @server_data %{
    0 => %{
      notice: "Warning: Instances with an unknown server may for now not be real instances. the crawler is still under development and may stumble upon non-instances. This will be fixed soon."
    },
    1 => %{
      link: "https://gnu.io/social/",
      source: "https://git.gnu.io/gnu/gnu-social/",
      notice: "Statistics are not available",
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
      notice: "Statistics are not available for private instances",
    },
    6 => %{
      link: "https://www.postactiv.com",
      source: "http://gitea.postactiv.com/postActiv/postActiv",
      notice: "Statistics are not available",
    },
    7 => %{
      link: "https://friendi.ca/",
      source: "https://github.com/friendica/friendica",
      notice: "Statistics are not available for private instances",
    },
    8 => %{
      description: "Experimental ActivityPub server in C#",
      source: "https://github.com/puckipedia/Kroeg",
    },
    9 => %{
      source: "https://github.com/syuilo/misskey",
    },
    10 => %{
      hidden: true,
      notice: "Not compatible ActivityPub yet",
      source: "https://github.com/ganggo/ganggo"
    },
    11 => %{
      hidden: true,
      notice: "Not compatible ActivityPub yet",
      source: "https://github.com/jaywink/socialhome",
    },
    12 => %{
      description: "A modern, convivial and free music server",
      link: "https://funkwhale.audio/",
      source: "https://code.eliotberriot.com/funkwhale",
    }
  }

  for {id, name} <- @servers do
    named = String.downcase(name)
    path = named
    |> String.downcase()
    |> String.replace(" ", "")
    data = Map.get(@server_data, id, nil)
    |> Macro.escape
    def to_path(unquote(id)), do: unquote(path)
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

  def to_path(0), do: String.downcase(@default)

  def list_names do
    Enum.map(@servers, fn({_, name}) -> name end) ++ [@default]
  end

  def list do
    stats = Fd.GlobalStats.get()
    @servers
    |> Map.put(0, @default)
    |> Enum.map(fn({id, name}) ->
      data(id)
      |> Map.put(:id, id)
      |> Map.put(:name, name)
      |> Map.put(:path, to_path(id))
      |> Map.put_new(:hidden, false)
    end)
    |> Enum.sort_by(fn(%{id: id}) -> get_in(stats, ["per_server", id, "instances", "total"])||0 end, &>=/2)
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

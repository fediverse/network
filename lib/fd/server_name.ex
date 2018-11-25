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
    13  => "Plume",
    14  => "castling.club",
    15  => "write.as",
    16  => "MicroblogPub",
    17  => "rustodon",
    18  => "pixelfed",
    19  => "reel2bits",
    20  => "read.as",
    21  => "writefreely",
    22  => "Osada",
    23  => "p3k",
    24  => "red",
    25  => "mobilizon",
    26  => "activityrelay",
    27  => "PubGate",
    28  => "booth",
    29  => "zap",
  }
  @server_data %{
    0 => %{
      slug: "other",
      notice: "Warning: Instances with an unknown server may for now not be real instances. the crawler is still under development and may stumble upon non-instances. This will be fixed soon."
    },
    1 => %{
      name: "GNU Social",
      slug: "gnusocial",
      link: "https://gnu.io/social/",
      source: "https://git.gnu.io/gnu/gnu-social/",
      notice: "Statistics are not available",
      protocols: ["ostatus"],
    },
    2 => %{
      slug: "mastodon",
      link: "https://joinmastodon.org",
      source: "https://github.com/tootsuite/mastodon",
      protocols: ["ostatus", "activitypub"],
      other_stats: [
        {"instances.social", "https://instances.social"},
        {"Mastodon Monitoring Project", "https://mnm.social/"},
        {"Sp3r4z's stats", "http://sp3r4z.fr/mastodon/"},
      ],
    },
    3 => %{
      slug: "pleroma",
      link: "https://pleroma.social",
      description: "Pleroma is an ActivityPub/OStatus server built on Elixir. New and rising!",
      source: "https://git.pleroma.social/pleroma/pleroma",
      protocols: ["ostatus", "activitypub"],
      other_stats: [
        {"distsn.org list", "https://distsn.org/pleroma-instances.html"},
        {"instances.social", "https://instances.social"},
      ],
    },
    4 => %{
      slug: "peertube",
      description: "PeerTube is a video streaming platform",
      link: "https://joinpeertube.org",
      source: "https://github.com/Chocobozzz/PeerTube",
      protocols: ["activitypub"],
      other_stats: [
        {"instances.joinpeertube.org", "https://instances.joinpeertube.org"}
      ],
    },
    5 => %{
      slug: "hubzilla",
      link: "https://hubzilla.org",
      source: "https://github.com/redmatrix/hubzilla",
      notice: "Statistics are not available for private instances",
      protocols: ["ostatus", "zot"],
    },
    6 => %{
      slug: "postactiv",
      link: "https://www.postactiv.com",
      source: "http://gitea.postactiv.com/postActiv/postActiv",
      notice: "Statistics are not available",
      protocols: ["ostatus"],
    },
    7 => %{
      slug: "friendica",
      link: "https://friendi.ca/",
      source: "https://github.com/friendica/friendica",
      notice: "Statistics are not available for private instances",
      protocols: ["ostatus"],
    },
    8 => %{
      slug: "kroeg",
      description: "Experimental ActivityPub server in Rust",
      link: "http://puckipedia.com/kroeg",
      source: "https://git.puckipedia.com/kroeg",
      protocols: ["activitypub"],
    },
    9 => %{
      slug: "misskey",
      source: "https://github.com/syuilo/misskey",
      protocols: ["activitypub"],
    },
    10 => %{
      slug: "ganggo",
      #hidden: true,
      notice: "Not compatible ActivityPub yet",
      source: "https://github.com/ganggo/ganggo"
    },
    11 => %{
      slug: "socialhome",
      #hidden: true,
      notice: "Not compatible ActivityPub yet",
      source: "https://github.com/jaywink/socialhome",
    },
    12 => %{
      slug: "funkwhale",
      description: "A modern, convivial and free music server",
      link: "https://funkwhale.audio/",
      source: "https://code.eliotberriot.com/funkwhale",
      protocols: ["activitypub"],
    },
    13 => %{
      slug: "plume",
      description: "A federated blog engine",
      source: "https://github.com/Plume-org/Plume",
      protocols: ["activitypub"],
    },

    # Castling is closed source and single instance so we hide it :)
    14 => %{
      slug: "castlingclub",
      hidden: false,
      description: "A federated chess server",
      link: "https://castling.club/",
      source: false,
      protocols: ["activitypub"],
    },
    15 => %{
      slug: "writeas",
      description: "",
      hidden: true,
      link: "https://write.as/",
      description: "Simple, connected, privacy-focused blogging platform",
      source: false,
      protocols: ["activitypub"],
    },
    16 => %{
      name: "microblog.pub",
      slug: "microblogpub",
      description: "A self-hosted, single-user, ActivityPub powered microblog",
      link: "https://microblog.pub/",
      source: "https://github.com/tsileo/microblog.pub",
      protocols: ["activitypub"],
    },
    17 => %{
      name: "Rustodon",
      slug: "rustodon",
      description: "A Mastodon-compatible, ActivityPub-speaking server in Rust",
      source: "https://github.com/rustodon/rustodon",
      protocols: ["activitypub"],
    },
    18 => %{
      name: "PixelFed",
      slug: "pixelfed",
      description: "Federated Image Sharing",
      source: "https://github.com/pixelfed",
      link: "https://pixelfed.org",
      protocols: ["activitypub"],
    },
    19 => %{
      name: "reel2bits",
      slug: "reel2bits",
      description: "Something something like soundcloud but not like soundcloud",
      source: "https://dev.sigpipe.me/dashie/reel2bits",
      protocols: ["activitypub"],
    },
    20 => %{
      name: "read.as",
      slug: "readas",
      description: "Long-form ActivityPub-enabled reader",
      source: "https://github.com/writeas/Read.as",
      link: "https://read.as",
      protocols: ["activitypub"],
    },
    21 => %{
      name: "WriteFreely",
      slug: "writefreely",
      description: "Painless, simple, federated blogging platform",
      source: "https://github.com/writeas/writefreely",
      link: "https://writefreely.org/",
      protocols: ["activitypub"],
    },
    22 => %{
      name: "Osada",
      slug: "osada",
      description: "Bridge between zot6 and non-nomadic protocols",
      source: "https://framagit.org/macgirvin/osada",
      link: "https://zotlabs.com/osada/",
      protocols: ["activitypub", "zot"],
    },
    23 => %{
      name: "p3k",
      slug: "p3k",
      source: "https://indieweb.org/p3k"
    },
    24 => %{
      name: "red",
      slug: "red",
      source: "https://framagit.org/macgirvin/red",
      protocols: ["activitypub", "zot"],
    },
    25 => %{
      name: "Mobilizon",
      slug: "mobilizon",
      source: "https://framagit.org/framasoft/mobilizon"
    },
    26 => %{
      name: "ActivityRelay",
      slug: "activityrelay",
      description: "A generic LitePub message relay",
      source: "https://git.pleroma.social/pleroma/relay",
    },
    27 => %{
      name: "PubGate",
      slug: "pubgate",
      source: "https://github.com/autogestion/pubgate"
    },
    28 => %{
      name: "booth",
      slug: "booth",
      source: false
    },
    29 => %{
      name: "zap",
      slug: "zap",
    }

  }

  @protocols %{
    "ostatus" => %{
      name: "OStatus",
      logo: "https://static.fediverse.network/icons/ostatus.png",
    },
    "activitypub" => %{
      name: "ActivityPub",
      logo: "https://static.fediverse.network/icons/activitypub.png",
    },
    "zot" => %{
      name: "ZOT",
      logo: "https://static.fediverse.network/icons/zot.png"
    }
  }

  for {id, name} <- @servers do
    {_, _, data} = Map.get(@server_data, id, nil)
    |> Macro.escape
    data = data |> Enum.into(%{})
    path = Map.get(data, :slug)
    display_name = Map.get(data, :name, name)
    def to_path(unquote(id)), do: unquote(path)
    def route_path(unquote(id)), do: "/" <> unquote(path)
    def route_path(unquote(name)), do: "/" <> unquote(path)
    def route_path(unquote(display_name)), do: "/" <> unquote(path)
    def display_name(unquote(id)), do: unquote(display_name)
    def display_name(unquote(name)), do: unquote(display_name)
    def from_int(unquote(id)), do: unquote(name)
    def to_int("/"<>unquote(path)), do: unquote(id)
    def to_int(unquote(name)), do: unquote(id)
    def to_int(unquote(String.downcase(name))), do: unquote(id)
    def to_int(unquote(display_name)), do: unquote(id)
    def to_int(unquote(path)), do: unquote(id)
    def exists?(unquote(name)), do: true
    def exists?(unquote(path)), do: true
    def data(unquote(id)), do: unquote(Macro.escape(data))
  end

  def from_int(_), do: @default
  def to_int(_), do: 0
  def exists?(_), do: false

  def data(0), do: Map.get(@server_data, 0, nil)
  def data(_), do: nil

  def to_path(0), do: String.downcase(@default)
  def route_path(0), do: "/" <> String.downcase(@default)
  def route_path("Other"), do: "/" <> String.downcase(@default)

  def display_name(_), do: "Other"

  def list_names do
    Enum.map(@servers, fn({_, name}) -> name end) ++ [@default]
  end

  for {id, data} <- @protocols do
    def get_protocol_data(unquote(id)), do: unquote(Macro.escape(data))
  end
  def get_protocol_data(_), do: nil

  def list do
    stats = Fd.GlobalStats.get()
    @servers
    |> Map.put(0, @default)
    |> Enum.map(fn({id, name}) ->
      data(id)
      |> Map.put(:id, id)
      |> Map.put_new(:name, name)
      |> Map.put(:path, to_path(id))
      |> Map.put_new(:hidden, false)
    end)
    |> Enum.sort_by(fn(%{id: id}) -> get_in(stats, ["per_server", id, "instances", "up"])||0 end, &>=/2)
  end


end

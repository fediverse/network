defmodule Fd.Instances.Crawler do
  @moduledoc """
  # Instance Crawler

  1. Test Masto API (/api/v1/instance)
      1. a. /api/v1/instance/peers (only once per 6h)
      1. b. /api/v1/instance/custom_emojis (only once per 24h)
  2. Test Statusnet API (/api/statusnet/config)
      2. a. /api/statusnet/config
      2. b. Test /main/statistics
  3. Update `Instance`

  Maybe:
    - Could test if we get a reply on /api/z/1.0/channel/stream (so we can now it's hubzilla?)

  """

  # TODO: Store complete crawl state into Instance db

  require Logger
  alias __MODULE__
  alias Fd.{Instances, Instances.Instance, Instances.InstanceCheck}

  @hackney_pool :hackney_crawler
  @hackney_pool_opts [{:timeout, 150_000}, {:max_connections, 200}, {:connect_timeout, 150_000}]
  @hackney_mon_pool :hackney_crawler_mon
  @hackney_mon_pool_opts [{:timeout, 150_000}, {:max_connections, 50}, {:connect_timeout, 150_000}]
  @hackney_opts [{:pool, @hackney_pool}]
  @hackney_mon_opts [{:pool, @hackney_pool}]

  @down_http_codes [301, 410, 502, 503, 504, 505, 520, 521, 522, 523, 524, 525, 526, 527, 530]
  @nodeinfo_servers ["hubzilla", "Friendica"]
  @nodeinfo_hide_if_not_found_servers ["Friendica"]

  defstruct [ :instance,
              :halted?,
              :fatal_error,
              :server,

              :has_mastapi?,
              :m_instance,
              :m_peers,
              :m_custom_emojis,

              :has_statusnet?,
              :s_version,
              :s_config,

              :has_peertubeapi?,
              :pt_config,
              :pt_stats,

              :has_nodeinfo?,
              :nodeinfo,

              :html,

              :changes,
              :check,
              :diffs,
            ]

  def setup() do
    :ok = :hackney_pool.start_pool(@hackney_pool, @hackney_pool_opts)
    :ok = :hackney_pool.start_pool(@hackney_mon_pool, @hackney_mon_pool_opts)
  end

  def run(instance = %Instance{domain: domain}) do
    state = %Crawler{instance: instance, halted?: false, has_mastapi?: false, has_statusnet?: false, has_peertubeapi?:
      false, has_nodeinfo?: false, changes: %{}, check: %{}}


    start = :erlang.monotonic_time
    info(state, "starting new crawl")

    state = state
    |> query_mastapi_instance()
    |> query_mastapi_peers()
    |> query_mastapi_emojis()
    |> query_statusnet_version()
    |> query_statusnet_config()
    |> query_peertube_config()
    |> query_peertube_stats()
    |> query_statusnet_config2()
    |> query_nodeinfo()
    #|> query_html_index()
    |> process_results()
    |> put_public_suffix()
    |> put_host_info()
    |> check_for_changes()

    # TODO: If every check is false (and not halted), decide it's NOT a fediverse instance.
    # FIXME: Check for AP/OStatus endpoint as last resort before deciding it's not a fediverse instance.

    pipeline_stop = :erlang.monotonic_time

    changes = Map.get(state, :changes, %{})
    |> Map.put("last_checked_at", DateTime.utc_now())

    debug(state, "changes: #{inspect changes}")

    check = state.check
    check_changeset = InstanceCheck.changeset(%InstanceCheck{instance_id: instance.id}, check)
    Fd.Repo.insert!(check_changeset)

    case Instances.update_instance(instance, changes) do
      {:ok, instance} ->
        info(state, "OK -- updated!")
      error ->
        error(state, "FAIL: #{inspect error}")
    end

    finished = :erlang.monotonic_time
    pipeline_duration = pipeline_stop - start
    total_duration = finished - start

    info(state, "finished in #{:erlang.convert_time_unit(total_duration, :native, :millisecond)}ms (pipeline took #{:erlang.convert_time_unit(pipeline_duration, :native, :millisecond)} ms)!")

    if Application.get_env(:fd, :monitoring_alerts, false) && state.instance.monitor do
      spawn(fn() ->
        became_down? = Map.get(state.diffs, :became_down, false)
        became_up? = Map.get(state.diffs, :became_up, false)
        if became_down? do
          Fd.DownEmail.down_email(state.instance, state.check)
          |> Fd.Mailer.deliver()
        end
        if became_up? do
          Fd.UpEmail.up_email(state.instance)
          |> Fd.Mailer.deliver()
        end
      end)
    end

    spawn(fn() ->
      domains = state.m_peers || []
      existings = Enum.map(Instances.list_instances_by_domains(domains), fn(i) -> String.downcase(i.domain) end)
      new_domains = domains
      |> Enum.map(fn(domain) ->
        domain = domain
        |> String.trim
        |> String.downcase
        uri = URI.parse("https://#{domain}")
        uri.host
      end)
      |> Enum.filter(fn(domain) -> domain end)
      |> Enum.reject(fn(domain) -> Enum.member?(existings, domain) end)

      for domain <- new_domains, do: Instances.create_instance(%{"domain" => domain})
    end)
  end

  defp put_public_suffix(crawler) do
    crawler = unless crawler.instance.domain_suffix do
      debug(crawler, "setting domain suffix")
      domain = String.downcase(crawler.instance.domain)
      suffix = PublicSuffix.public_suffix(domain, ignore_private: true)
      changes = crawler.changes
      |> Map.put("domain_suffix", suffix)
      %Crawler{crawler | changes: changes}
    else
      crawler
    end

    crawler = unless crawler.instance.domain_base do
      debug(crawler, "setting domain base")
      domain = String.downcase(crawler.instance.domain)
      base = PublicSuffix.registrable_domain(domain)
      changes = crawler.changes
      |> Map.put("domain_base", base)
      %Crawler{crawler | changes: changes}
    else
      crawler
    end

  end

  #
  # -- CHECK FOR CHANGES
  #
  # * Detect if changed from up to down or vice-versa
  # * Detect if server/version changed
  # * Detect if it was the first crawl
  def check_for_changes(crawler) do
    last_check = Instances.get_instance_last_check(crawler.instance)
    last_up_check = Instances.get_instance_last_up_check(crawler.instance)

    new? = (last_check == nil)
    is_up? = Map.get(crawler.changes, "up")
    was_up? = (last_check && last_check.up == true)
    became_up? = (is_up? == true && was_up? == false)
    became_down? = (is_up? == false && was_up? == true)
    signup_changed? = if last_up_check && !is_nil(last_up_check.signup) do
      last_up_check.signup != Map.get(crawler.changes, "signup", false)
    else
      false
    end

    version_changed? = if last_up_check && is_up? do
      Map.get(crawler.changes, "version") != last_up_check.version
    else false end
    server_changed? = if last_up_check && is_up? do
      Map.get(crawler.changes, "server", 0) != last_up_check.server
    else false end

    diffs = %{new: new?, became_up: became_up?, became_down: became_down?, version_changed: version_changed?,
      server_changed: server_changed?}

    {became_open?, became_closed?} = cond do
      signup_changed? && Map.get(crawler.changes, "signup", true) == false ->
        {false, true}
      signup_changed? && Map.get(crawler.changes, "signup", false) == true ->
        {true, false}
      true ->
        {false, false}
    end

    unless (crawler.instance.hidden || false) or Map.get(crawler.changes, "server", 0) == 0 do
      if became_up? do
        post("is back up :)", crawler.instance, "fediversemonitoring@pleroma.fr")
      end
      if became_down? do
        error = if error = Map.get(crawler.check, "error_s") do
          " (#{error})"
        else
          ""
        end
        post("is down#{error}", crawler.instance, "fediversemonitoring@pleroma.fr")
      end
      if became_closed? do
        post("closed registrations", crawler.instance)
        post("closed registrations", crawler.instance, "fediversemonitoring@pleroma.fr")
      end
      if became_open? do
        post("opened registrations", crawler.instance)
        post("opened registrations", crawler.instance, "fediversemonitoring@pleroma.fr")
      end
      if new? do
        server_id = Map.get(crawler.changes, "server", 0)
        unless server_id == 0 do
          server = server_id |> Fd.ServerName.from_int()
          post("welcome to the fediverse! a new #{server} instance! \o/", crawler.instance)
          post("welcome to the fediverse! a new #{server} instance! \o/", crawler.instance, "fediversemonitoring@pleroma.fr")
        end
      end
      cond do
        server_changed? ->
          last = last_up_check.server || 0
          unless last == 0 do
            old_server = last_up_check.server |> Fd.ServerName.from_int()
            new_server = Map.get(crawler.changes, "server", 0) |> Fd.ServerName.from_int()
            post("changed servers from #{old_server} to #{new_server}", crawler.instance)
            post("changed servers from #{old_server} to #{new_server}", crawler.instance, "fediversemonitoring@pleroma.fr")
          end
        version_changed? ->
          server = Map.get(crawler.changes, "server", 0) |> Fd.ServerName.from_int()
          old_version = last_up_check.version
          new_version = Map.get(crawler.changes, "version", "?")
          post("upgraded #{server} from #{old_version} to #{new_version}:", crawler.instance)
          post("upgraded #{server} from #{old_version} to #{new_version}:", crawler.instance, "fediversemonitoring@pleroma.fr")
        true -> :nothing_changed
      end
    end

    debug(crawler, "Diffs: " <> inspect(diffs))

    %Crawler{crawler | diffs: diffs}
  end

  #
  # -- Hosting information
  #
  # * Get IPs
  # * Get IPs AS networks
  # * Get countries
  # * Get hosting information (masto.host, …)
  def put_host_info(crawler) do
    crawler
  end

  def process_results(crawler = %Crawler{halted?: true}) do
    error_s = Fd.HumanError.format(crawler.fatal_error)
    check = %{"up" => false, "error_s" => error_s}

    changes = crawler.changes
    |> Map.put("last_down_at", DateTime.utc_now())
    |> Map.put("up", false)
    %Crawler{crawler | changes: changes, check: check}
  end

  def process_results(crawler = %Crawler{has_mastapi?: true}) do
    changes = %{"last_up_at" => DateTime.utc_now(), "has_mastapi" => true}

    stats = Map.get(crawler.m_instance, "stats", %{})
    {server, version} = Map.get(crawler.m_instance, "version", nil) |> process_mastapi_version()
    user_count = Map.get(stats, "user_count")
    peer_count = Map.get(stats, "domain_count")
    status_count = Map.get(stats, "status_count")
    name = Map.get(crawler.m_instance, "title", crawler.instance.domain)
    description = Map.get(crawler.m_instance, "description")
    email = Map.get(crawler.m_instance, "email")
    emojis = Enum.reduce(crawler.m_custom_emojis || [], %{}, fn
      (%{"url" => url, "shortcode" => code}, emojis) -> Map.put(emojis, code, url)
      (_, emojis) -> emojis
    end)
    emoji_count = Enum.count(emojis)
    max_chars = Map.get(crawler.m_instance, "max_toot_chars", 500)

    signup = nil # WTF it's not in instance API??
    signup = cond do
      crawler.has_statusnet? ->
        if get_in(crawler.s_config, ["site", "closed"]) do
          get_in(crawler.s_config, ["site", "closed"]) == "0"
        else
          nil
        end
      true -> nil
    end

    check = %{"up" => true, "users" => user_count, "peers" => peer_count, "statuses" => status_count, "emojis" =>
      emoji_count, "version" => version, "signup" => signup, "max_chars" => max_chars, "server" => Fd.ServerName.to_int(server)}

    changes = changes
    |> Map.put("custom_emojis", emojis)
    |> Map.put("mastapi_instance", crawler.m_instance)
    |> Map.put("statusnet_config", crawler.s_config)
    |> Map.put("server", Fd.ServerName.to_int(server))
    |> Map.put("name", name)
    |> Map.put("description", description)
    |> Map.put("email", email)
    |> Map.put("dead", false)
    |> Map.merge(check)

    %Crawler{crawler | changes: changes, check: check}
  end

  def process_results(crawler = %Crawler{has_peertubeapi?: true}) do
    changes = %{"last_up_at" => DateTime.utc_now()}

    version = Map.get(crawler.pt_config, "serverVersion")
    server = "PeerTube"
    signup = get_in(crawler.pt_config, ["signup", "allowed"])
    stats = crawler.pt_stats || %{}
    videos = Map.get(stats, "totalLocalVideos", 0)
    comments = Map.get(stats, "totalLocalVideoComments", 0)
    statuses = videos + comments
    users = Map.get(stats, "totalUsers")

    check = %{"up" => true, "version" => version, "signup" => signup, "users" => users, "statuses" => statuses, "server" => Fd.ServerName.to_int(server)}

    changes = changes
    |> Map.put("peertube_config", crawler.pt_config)
    |> Map.put("server", Fd.ServerName.to_int(server))
    |> Map.put("dead", false)
    |> Map.merge(check)

    %Crawler{crawler | changes: changes, check: check}
  end

  @falses ["0", "false", false]
  @trues ["1", "true", true]

  # Hubzilla reports there
  def process_results(crawler = %Crawler{has_statusnet?: true}) do
    changes = %{"last_up_at" => DateTime.utc_now()}
    invite_only = cond do
      get_in(crawler.s_config, ["site", "inviteonly"]) in @trues -> true
      true -> false
    end
    signup = cond do
      invite_only -> false
      get_in(crawler.s_config, ["site", "closed"]) in @falses -> true
      get_in(crawler.s_config, ["site", "closed"]) in @trues -> false
      true -> nil
    end
    max_chars = get_in(crawler.s_config, ["site", "textlimit"])
    name = get_in(crawler.s_config, ["site", "name"])
    email = get_in(crawler.s_config, ["site", "email"])

    server = cond do
      platform = get_in(crawler.s_config, ["site", "platform", "PLATFORM_NAME"]) -> platform
      friendica = get_in(crawler.s_config, ["site", "friendica", "FRIENDICA_PLATFORM"]) -> friendica
      crawler.s_version ->
        {s, _} = process_statusnet_version(crawler.s_version)
        s
      true -> "GNUSocial"
    end
    private = cond do
      server in @nodeinfo_hide_if_not_found_servers and !crawler.has_nodeinfo? -> true
      get_in(crawler.s_config, ["site", "private"]) in @trues -> true
      true -> false
    end

    version = cond do
      platform = get_in(crawler.s_config, ["site", "platform", "STD_VERSION"]) -> platform
      friendica = get_in(crawler.s_config, ["site", "friendica", "FRIENDICA_VERSION"]) -> friendica
      crawler.s_version ->
        {_, v} = process_statusnet_version(crawler.s_version)
        v
      true -> nil
    end

    check = %{"up" => true, "signup" => signup, "max_chars" => max_chars, "version" => version, "server" => Fd.ServerName.to_int(server)}

    # Nodeinfo data is returned by Hubzilla (and coming from Disapora). For now we only use/crawl it if we already know
    # it's a hubzilla server we are talking to (using statusnet api); see query_nodeinfo/1
    check = if crawler.has_nodeinfo? do
      users = get_in(crawler.nodeinfo, ["usage", "users", "total"])
      posts = get_in(crawler.nodeinfo, ["usage", "localPosts"])
      comments = get_in(crawler.nodeinfo, ["usage", "localComments"])
      statuses = posts + comments
      check
      |> Map.put("users", users)
      |> Map.put("statuses", statuses)
    else check end

    changes = changes
    |> Map.put("statusnet_config", crawler.s_config)
    |> Map.put("server", Fd.ServerName.to_int(server))
    |> Map.put("version", version)
    |> Map.put("email", email)
    |> Map.put("name", name)
    |> Map.put("dead", false)
    |> Map.put("hidden", private)
    |> Map.merge(check)

    %Crawler{crawler | changes: changes, check: check}
  end

  defp process_statusnet_version("Pleroma "<>version), do: {"Pleroma", version}
  defp process_statusnet_version("postactiv-"<>version), do: {"PostActiv", version}
  defp process_statusnet_version(version), do: {"GNUSocial", version}

  def process_results(crawler) do
    Logger.warn "Unprocessable results for #{crawler.instance.domain} (id #{crawler.instance.id}) -- #{inspect crawler}"
    check = %{"up" => true}
    changes = crawler.changes || %{}
    |> Map.put("last_up_at", DateTime.utc_now())
    |> Map.put("server", 0)
    |> Map.put("up", true)
    %Crawler{crawler | changes: changes, check: check}
  end

  defp process_mastapi_version(nil), do: {"Unknown", nil}
  defp process_mastapi_version(string) do
    cond do
      # "universal" compatible (pleroma-like) format: "masto_version; compatible ServerName real_version"
      # FIXME: it wont work if the server is not in Fd.ServerName
      String.contains?(string, "compatible;") ->
        [_, server_and_version] = String.split(string, "(compatible; ")
        [server, version] = String.split(server_and_version, " ", parts: 2)
        {server, clean_string(version)}
      # Old versions of Pleroma
      String.starts_with?(string, "Pleroma") ->
        [_, version] = String.split(string, " ", parts: 2)
        {"Pleroma", clean_string(version)}
      string == "Mastodon::Version" -> {"Mastodon", "1.3"}
      # Kroeg
      String.contains?(string, "but actually Kroeg") ->
        {"Kroeg", "pre-alpha"}
      true ->
        {"Mastodon", clean_string(string)}
    end
  end

  defp clean_string(string) do
    string
    |> String.trim_trailing(")")
    |> String.trim_trailing(".")
  end

  #
  # MastAPI: Instance
  #

  @mastapi_not_found [404]
  def query_mastapi_instance(crawler) do
    case request(crawler, "/api/v1/instance") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        debug(crawler, "got /api/v1/instance " <> inspect(body))
        %Crawler{crawler | has_mastapi?: true, m_instance: body}
      {:ok, %HTTPoison.Response{status_code: code}} when code in @mastapi_not_found ->
        debug(crawler, "mastapi is not found. #{inspect code}")
        %Crawler{crawler | has_mastapi?: false}
      {:ok, %HTTPoison.Response{status_code: code}} when code not in @down_http_codes ->
        debug(crawler, "mastapi responded with an invalid code, maybe down or not found: #{inspect code}")
        %Crawler{crawler | has_mastapi?: false}
      failed ->
        debug(crawler, "host is down " <> inspect(failed))
        %Crawler{crawler | halted?: true, fatal_error: failed}
    end
  end

  #
  # MastAPI: Peers
  #

  def query_mastapi_peers(crawler = %Crawler{has_mastapi?: true, halted?: false}) do
    case request(crawler, "/api/v1/instance/peers") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        debug(crawler, "got /api/v1/instance/peers " <> inspect(body))
        %Crawler{crawler | has_mastapi?: true, m_peers: body}
      {:ok, %HTTPoison.Response{status_code: code}} when code not in @down_http_codes ->
        debug(crawler, "mastapi responded with an invalid code, maybe down or not found: #{inspect code}")
        crawler
      {:error, %Jason.DecodeError{}} ->
        debug(crawler, "json decode error, skipping")
        crawler
      failed ->
        debug(crawler, "host is down " <> inspect(failed))
        %Crawler{crawler | halted?: true, fatal_error: failed}
    end
  end

  def query_mastapi_peers(crawler), do: crawler

  #
  # MastAPI: Emojis
  #

  def query_mastapi_emojis(crawler = %Crawler{has_mastapi?: true, halted?: false}) do
    case request(crawler, "/api/v1/custom_emojis") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        debug(crawler, "got /api/v1/custom_emojis " <> inspect(body))
        %Crawler{crawler | has_mastapi?: true, m_custom_emojis: body}
      {:ok, %HTTPoison.Response{status_code: code}} when code not in @down_http_codes ->
        debug(crawler, "mastapi responded with an invalid code, maybe down or not found: #{inspect code}")
        crawler
      {:error, %Jason.DecodeError{}} ->
        debug(crawler, "json decode error, skipping")
        crawler
      failed ->
        debug(crawler, "host is down " <> inspect(failed))
        %Crawler{crawler | halted?: true, fatal_error: failed}
    end
  end

  def query_mastapi_emojis(crawler), do: crawler

  #
  # PeerTubeAPI: Config
  #

  @mastapi_not_found [404]
  def query_peertube_config(crawler = %Crawler{halted?: false, has_mastapi?: mastapi, has_statusnet?: false}) when not mastapi do
    case request(crawler, "/api/v1/config") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body = %{"instance" => _, "serverVersion" => _}}} ->
        debug(crawler, "got peertube-like /api/v1/config " <> inspect(body))
        %Crawler{crawler | has_peertubeapi?: true, pt_config: body}
      {:ok, %HTTPoison.Response{status_code: code}} when code in @mastapi_not_found ->
        debug(crawler, "peertubeapi is not found. #{inspect code}")
        %Crawler{crawler | has_peertubeapi?: false}
      {:ok, %HTTPoison.Response{status_code: code}}  when code not in @down_http_codes ->
        debug(crawler, "peertubeapi responded with an invalid code, maybe down or not found: #{inspect code}")
        %Crawler{crawler | has_peertubeapi?: false}
      failed ->
        debug(crawler, "host is down " <> inspect(failed))
        %Crawler{crawler | halted?: true, fatal_error: failed}
    end
  end

  def query_peertube_config(crawler) do
    debug(crawler, "skipping peertube test")
    crawler
  end
  #
  # PeerTubeAPI: Config
  #

  def query_peertube_stats(crawler = %Crawler{halted?: false, has_peertubeapi?: true}) do
    case request(crawler, "/api/v1/server/stats") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        debug(crawler, "got peertube-like /api/v1/server/stats " <> inspect(body))
        %Crawler{crawler | has_peertubeapi?: true, pt_stats: body}
      {:ok, %HTTPoison.Response{status_code: code}} when code not in @down_http_codes ->
        debug(crawler, "peertubeapi (stats) responded with an invalid code, maybe down or not found: #{inspect code}")
       crawler
      {:error, %Jason.DecodeError{}} ->
        debug(crawler, "json decode error, skipping")
        crawler
      failed ->
        debug(crawler, "host is down " <> inspect(failed))
        %Crawler{crawler | halted?: true, fatal_error: failed}
    end
  end

  def query_peertube_stats(crawler), do: crawler


  #
  # StatusNet: Version
  #
  @mastapi_not_found [404]
  def query_statusnet_version(crawler = %Crawler{halted?: false, has_mastapi?: false}) do
    case request(crawler, "/api/statusnet/version.json") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        debug(crawler, "got /api/statusnet/version.json " <> inspect(body))
        %Crawler{crawler | has_statusnet?: true, s_version: body}
      {:ok, %HTTPoison.Response{status_code: code}} when code in @mastapi_not_found ->
        debug(crawler, "statusnet is not found. #{inspect code}")
        %Crawler{crawler | has_statusnet?: false}
      {:ok, %HTTPoison.Response{status_code: code}} when code not in @down_http_codes  ->
        debug(crawler, "statusnet responded with an invalid code, maybe down or not found: #{inspect code}")
        crawler
      {:error, %Jason.DecodeError{}} ->
        debug(crawler, "json decode error, skipping")
        crawler
      failed ->
        debug(crawler, "host is down " <> inspect(failed))
        %Crawler{crawler | halted?: true, fatal_error: failed}
    end
  end

  def query_statusnet_version(crawler), do: crawler

  @mastapi_not_found [404]
  def query_statusnet_config(crawler = %Crawler{halted?: false}) do
    case request(crawler, "/api/statusnet/config.json") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        debug(crawler, "got /api/statusnet/config.json " <> inspect(body))
        %Crawler{crawler | has_statusnet?: true, s_config: body}
      {:ok, %HTTPoison.Response{status_code: code}} when code in @mastapi_not_found ->
        debug(crawler, "statusnet is not found. #{inspect code}")
        %Crawler{crawler | has_statusnet?: false}
      {:ok, %HTTPoison.Response{status_code: code}} when code not in @down_http_codes  ->
        debug(crawler, "statusnet responded with an invalid code, maybe down or not found: #{inspect code}")
        crawler
      {:error, %Jason.DecodeError{}} ->
        debug(crawler, "json decode error, skipping")
        crawler
      failed ->
        debug(crawler, "host is down " <> inspect(failed))
        %Crawler{crawler | halted?: true, fatal_error: failed}
    end
  end
  def query_statusnet_config(crawler), do: crawler

  @mastapi_not_found [404]
  def query_statusnet_config2(crawler = %Crawler{halted?: false, has_statusnet?: false, has_mastapi?: false, has_peertubeapi?: false}) do
    case request(crawler, "/api/statusnet/config") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        debug(crawler, "got /api/statusnet/config " <> inspect(body))
        %Crawler{crawler | has_statusnet?: true, s_config: body}
      {:ok, %HTTPoison.Response{status_code: code}} when code in @mastapi_not_found ->
        debug(crawler, "statusnet is not found. #{inspect code}")
        %Crawler{crawler | has_statusnet?: false}
      {:ok, %HTTPoison.Response{status_code: code}} when code not in @down_http_codes  ->
        debug(crawler, "statusnet responded with an invalid code, maybe down or not found: #{inspect code}")
        crawler
      {:error, %Jason.DecodeError{}} ->
        debug(crawler, "json decode error, skipping")
        crawler
      failed ->
        debug(crawler, "host is down " <> inspect(failed))
        %Crawler{crawler | halted?: true, fatal_error: failed}
    end
  end
  def query_statusnet_config2(crawler), do: crawler

  #
  # -- /nodeinfo/2.0
  #
  # Used by Hubzilla and Disaporas-like
  #
  # Only hit if server has already been discovered and match a pre-defined list.
  #

  @mastapi_not_found [404]
  def query_nodeinfo(crawler = %Crawler{halted?: false, s_config: %{"site" => %{"platform" => %{"PLATFORM_NAME" => server}}}}) when server in @nodeinfo_servers, do: do_query_nodeinfo(crawler)
  def query_nodeinfo(crawler = %Crawler{halted?: false, s_config: %{"site" => %{"friendica" => _}}}), do: do_query_nodeinfo(crawler)
  def query_nodeinfo(crawler), do: crawler

  def do_query_nodeinfo(crawler, version \\ nil) do
    apiv = if version == nil, do: "2.0", else: version
    case request(crawler, "/nodeinfo/"<>apiv) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        debug(crawler, "got /nodeinfo/#{inspect version} " <> inspect(body))
        %Crawler{crawler | has_nodeinfo?: true, nodeinfo: body}
      {:ok, %HTTPoison.Response{status_code: code}} when code in @mastapi_not_found ->
        if version == nil do
          do_query_nodeinfo(crawler, "1.0")
        else
          debug(crawler, "nodeinfo is not found. #{inspect code}")
          %Crawler{crawler | has_nodeinfo?: false}
        end
      {:ok, %HTTPoison.Response{status_code: code}} when code not in @down_http_codes  ->
        debug(crawler, "nodeinfo responded with an invalid code, maybe down or not found: #{inspect code}")
        crawler
      {:error, %Jason.DecodeError{}} ->
        debug(crawler, "json decode error, skipping")
        crawler
      failed ->
        debug(crawler, "host is down " <> inspect(failed))
        %Crawler{crawler | halted?: true, fatal_error: failed}
    end
  end

  #
  # -- HTML Index
  # -> Detect GNU Social (last resort)
  # -> Detect old Mastodon versions
  # -> Detect Mastodon registration state
  def query_html_index(crawler = %Crawler{halted?: false}) do
    case request(crawler, "/", [json: false, follow_redirects: true]) do
      {:ok, resp = %HTTPoison.Response{status_code: 200, body: body}} ->
        IO.inspect resp
        %Crawler{crawler | html: body}
      error ->
        info(crawler, "failed to get index page #{inspect error}")
    end
  end

  def query_html_index(crawler), do: crawler

  defp request(crawler, path, options \\ []), do: request(crawler, path, options, 1)

  @env Mix.env
  defp request(crawler = %Crawler{instance: %Instance{domain: domain}}, path, options, retries) do
    follow_redirects = Keyword.get(options, :follow_redirects, false)
    json = Keyword.get(options, :json, true)
    {mon_ua, options} = if crawler.instance.monitor do
      mon_ua = " - monitoring enabled https://fediverse.network/monitoring"
      {mon_ua, @hackney_mon_opts}
    else
      {"", @hackney_opts}
    end
    options = [follow_redirect: follow_redirects] ++ options
    dev_ua = if @env == :dev, do: " [dev]", else: ""
    headers = %{
      "User-Agent" => "fediverse.network crawler#{dev_ua} (https://fediverse.network/info#{mon_ua} root@fediverse.network)",
    }
    headers = if json do
      Map.put(headers, "Accept", "application/json")
    else
      headers
    end
    case HTTPoison.get("https://#{domain}#{path}", headers, options) do
      {:ok, response = %HTTPoison.Response{status_code: 200, body: body}} ->
        info(crawler, "http ok")
        debug(crawler, "http body: " <>inspect(body))
        case json && Jason.decode(body) do
          {:ok, body} ->
            debug(crawler, "body parsed in json!")
            resp = %HTTPoison.Response{response | body: body}
            {:ok, resp}
          {:error, error} ->
            info(crawler, "invalid json: " <> inspect({error, body}))
            {:error, error}
          false -> {:ok, response}
        end
      {:ok, response} ->
        info(crawler, "http ok")
        {:ok, response}
      {:error, error = %HTTPoison.Error{reason: reason}} when reason in [:timeout, :connect_timeout, :closed] ->
        if retries >= 5 do
          error(crawler, "HTTP TIMEOUT: (#{inspect reason} - max retries reached)")
          {:error, error}
        else
          error(crawler, "HTTP TIMEOUT: (#{inspect reason} - retry #{inspect retries})" <> inspect(error))
          :timer.sleep(:crypto.rand_uniform(500, 5000))
          request(crawler, path, options, retries + 1)
        end
      {:error, error} ->
        error(crawler, "HTTP ERROR: #{inspect error}")
        {:error, error}
    end
  end

  defp debug(crawler, message) do
    domain = crawler.instance.domain
    Logger.debug "Crawler(#{inspect self()} ##{crawler.instance.id} #{domain}): #{message}"
  end
  defp info(crawler, message) do
    domain = crawler.instance.domain
    Logger.info "Crawler(#{inspect self()} ##{crawler.instance.id} #{domain}): #{message}"
  end
  defp error(crawler, message) do
    domain = crawler.instance.domain
    Logger.error "Crawler(#{inspect self()} ##{crawler.instance.id} #{domain}): #{message}"
  end

  defp post(text, instance) do
    post(text, instance, "fediverse@pleroma.fr")
  end
  defp post(text, instance, account) do
    text = if instance.hidden do
      ["private instance", text]
    else
      [Fd.Util.idna(instance.domain), text, "— https://fediverse.network/#{Fd.Util.idna(instance.domain)}"]
    end
    text = text
    |> Enum.join(" ")

    Fd.Social.async_post(account, text)
  end


end

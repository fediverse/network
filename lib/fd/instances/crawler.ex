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
    - Could test if we get a reply on /api/z/1.0/channel/stream (so we can know it's hubzilla?)

  """

  # TODO: Store complete crawl state into Instance db

  require Logger
  alias __MODULE__
  alias Fd.{Instances}
  alias Fd.Instances.{Instance, InstanceCheck, Instrumenter}

  @hackney_pool :hackney_crawler
  @hackney_pool_opts [{:timeout, 150_000}, {:max_connections, 500}, {:connect_timeout, 300_000}]
  @hackney_mon_pool :hackney_crawler_mon
  @hackney_mon_pool_opts [{:timeout, 150_000}, {:max_connections, 100}, {:connect_timeout, 300_000}]
  @hackney_opts [{:connect_timeout, 50_000}, {:recv_timeout, 50_000}, {:pool, @hackney_pool}]
  @hackney_mon_opt [{:pool, @hackney_pool}]

  @down_http_codes [301, 410, 502, 503, 504, 505, 520, 521, 522, 523, 524, 525, 526, 527, 530]
  @retry_http_codes [500, 502, 503, 504, 505, 520, 521, 522, 523, 524]
  @nodeinfo_servers ["hubzilla", "Friendica"]
  @nodeinfo_hide_if_not_found_servers ["Friendica"]

  def down_http_codes, do: @down_http_codes
  def nodeinfo_servers, do: @nodeinfo_servers
  def nodeinfo_hide_if_not_found_servers, do: @nodeinfo_hide_if_not_found_servers

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
              :nodeinfo_schema,
              :nodeinfo,

              :has_misskey?,
              :misskey_meta,
              :misskey_stats,

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
      false, has_nodeinfo?: false, has_misskey?: false, changes: %{}, check: %{}}


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
    |> Crawler.Nodeinfo.query()
    |> query_misskey_meta()
    |> query_misskey_stats()
    #|> query_html_index()
    |> process_results()
    |> put_public_suffix()
    |> put_host_info()

    # TODO: If every check is false (and not halted), decide it's NOT a fediverse instance.
    # FIXME: Check for AP/OStatus endpoint as last resort before deciding it's not a fediverse instance.

    pipeline_stop = :erlang.monotonic_time

    changes = Map.get(state, :changes, %{})
              |> Map.put("last_checked_at", DateTime.utc_now())
              |> Map.put("nodeinfo", state.nodeinfo)

    debug(state, "changes: #{inspect changes}")

    check = state.check
    check_changeset = InstanceCheck.changeset(%InstanceCheck{instance_id: instance.id}, check)
    Fd.Repo.insert!(check_changeset)

    state = case Instances.update_instance(instance, changes) do
      {:ok, instance} ->

        state = check_for_changes(state)

    if Application.get_env(:fd, :monitoring_alerts, false) && state.instance.monitor && state.instance.settings && state.instance.settings.alerts_to_contact do
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

        info(state, "OK -- updated!")
        state
      error ->
        error(state, "FAIL: #{inspect error}")
        state
    end

    finished = :erlang.monotonic_time
    pipeline_duration = pipeline_stop - start
    total_duration = finished - start

    info(state, "finished in #{:erlang.convert_time_unit(total_duration, :native, :millisecond)}ms (pipeline took #{:erlang.convert_time_unit(pipeline_duration, :native, :millisecond)} ms)!")

    spawn(fn() ->
      domains = state.m_peers || []
      existings = Enum.map(Instances.list_instances_by_domains(domains), fn(i) -> String.downcase(i.domain) end)
      new_domains = domains
      |> Enum.filter(fn(domain) -> domain end)
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
      server_changed: server_changed?, is_up?: is_up?, was_up?: was_up?}

    {became_open?, became_closed?} = cond do
      signup_changed? && Map.get(crawler.changes, "signup", true) == false ->
        {false, true}
      signup_changed? && Map.get(crawler.changes, "signup", false) == true ->
        {true, false}
      true ->
        {false, false}
    end

    IO.puts Map.get(crawler.changes, "server")
    unless (crawler.instance.hidden || false) or Map.get(crawler.changes, "server") == 0 do
      if became_up? do
        post("{instance} is back up :)", crawler.instance, [:mon])
      end
      if became_down? do
        IO.puts "BECAME DOWN"
        error = if error = Map.get(crawler.check, "error_s") do
          " (#{error})"
        else
          ""
        end
        if Map.get(crawler.instance.settings || %{}, :maintenance_mode) do
          post("{instance} is undergoing planned maintenance#{error}", crawler.instance, [:mon])
        else
          post("{instance} is down#{error}", crawler.instance, [:mon])
        end
      end
      if became_closed? do
        post("{instance} closed registrations", crawler.instance, [:watch, :mon])
      end
      if became_open? do
        post("{instance} opened registrations", crawler.instance, [:watch, :mon])
      end
      if new? do
        server_id = Map.get(crawler.changes, "server", 0)
        unless server_id == 0 do
          server = server_id |> Fd.ServerName.from_int()
          [
            "{instance}, welcome to the fediverse! a new {server} instance! \\o/",
            "\\o/ please welcome {instance} to the fediverse, a new {server} instance",
            "one more {server} instance in the fediverse! welcome, {instance}!"
          ]
          |> Enum.random()
          |> post(crawler.instance, [:new, :watch, :mon], %{server: server})
        end
      end
      cond do
        server_changed? ->
          last = last_up_check.server || 0
          unless last == 0 do
            old_server = last_up_check.server |> Fd.ServerName.from_int()
            new_server = Map.get(crawler.changes, "server", 0) |> Fd.ServerName.from_int()
            post("{instance} changed servers from #{old_server} to #{new_server}", crawler.instance, [:watch, :mon])
          end
        version_changed? ->
          server = Map.get(crawler.changes, "server", 0) |> Fd.ServerName.from_int()
          old_version = last_up_check.version
          new_version = Map.get(crawler.changes, "version", "?")
          post("{instance} upgraded #{server} from #{old_version} to #{new_version}:", crawler.instance, [:watch, :mon])
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
    server = "peertube"
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

  def process_results(crawler = %{has_misskey?: true}) do
    users = Map.get(crawler.misskey_stats || %{}, "originalUsersCount")
    statuses = Map.get(crawler.misskey_stats || %{}, "originalNotesCount")
    version = Map.get(crawler.misskey_meta || %{}, "version")
    server = Fd.ServerName.to_int("misskey")

    check = %{"up" => true, "users" => users, "statuses" => statuses, "version" => version, "server" => server}
    changes = %{"last_up_at" => DateTime.utc_now()}
    |> Map.merge(check)
    |> Map.put("dead", false)

    %Crawler{crawler | changes: changes, check: check}
  end

  def process_results(crawler = %{has_nodeinfo?: true}) do
    users = get_in(crawler.nodeinfo, ["usage", "users", "total"])
    posts = get_in(crawler.nodeinfo, ["usage", "localPosts"])
    comments = get_in(crawler.nodeinfo, ["usage", "localComments"])
    server = Fd.ServerName.to_int(get_in(crawler.nodeinfo, ["software", "name"])||0)
    version = get_in(crawler.nodeinfo, ["software", "version"])
    name = get_in(crawler.nodeinfo, ["metadata", "nodeName"])
    description = get_in(crawler.nodeinfo, ["metadata", "description"])
    email = get_in(crawler.nodeinfo, ["metadata", "email"])
    private = get_in(crawler.nodeinfo, ["metadata", "private"])
    signup = get_in(crawler.nodeinfo, ["openRegistrations"])
    statuses = cond do
      posts && comments -> posts + comments
      posts -> posts
      comments -> comments
      true -> nil
    end

    check = (crawler.check || %{})
    |> Map.put("up", true)
    |> Map.put_new("users", users)
    |> Map.put_new("statuses", statuses)
    |> Map.put_new("server", server)
    |> Map.put_new("version", version)
    |> Map.put_new("signup", signup)

    changes = (crawler.changes || %{})
    |> Map.put("nodeinfo", crawler.nodeinfo)
    |> Map.put("name", name)
    |> Map.put("description", description)
    |> Map.put("email", email)
    |> Map.put("last_up_at", DateTime.utc_now())
    |> Map.put("hidden", private)
    |> Map.put("dead", false)
    |> Map.merge(check)

    %Crawler{crawler | changes: changes, check: check}
  end

  def process_results(crawler) do
    Logger.warn "Unprocessable results for #{crawler.instance.domain} (id #{crawler.instance.id}) -- #{inspect crawler}"
    check = %{"up" => true}
    changes = crawler.changes || %{}
    |> Map.put("last_up_at", DateTime.utc_now())
    |> Map.put("server", 0)
    |> Map.put("up", true)
    %Crawler{crawler | changes: changes, check: check}
  end


  defp process_statusnet_version("postactiv-"<>version), do: {"PostActiv", version}
  defp process_statusnet_version("Pleroma "<>version), do: {"Pleroma", version}
  defp process_statusnet_version(version), do: {"GNUSocial", version}


  defp process_mastapi_version(string) when is_binary(string) do
    {server, version} = cond do
      # "universal" compatible (pleroma-like) format: "masto_version; compatible ServerName real_version"
      # FIXME: it wont work if the server is not in Fd.ServerName
      String.contains?(string, ":compatible:") ->
        [_, server_and_version] = String.split(string, ":compatible:", parts: 2)
        case String.split(server_and_version, [",", " ", ":"], parts: 2) do
          [server, version] -> {server, clean_string(version)}
          _ -> {nil, server_and_version}
        end
      String.contains?(string, "compatible;") ->
        [_, server_and_version] = String.split(string, "(compatible; ")
        case String.split(server_and_version, " ", parts: 2) do
          [version] -> {nil, clean_string(version)}
          [server, version] -> {server, clean_string(version)}
        end
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
    {downcase(server), version}
  end
  defp process_mastapi_version(_), do: {"Unknown", nil}

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
      {:error, %Jason.DecodeError{}} ->
        debug(crawler, "json decode error, skipping")
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
      {:error, %Jason.DecodeError{}} ->
        debug(crawler, "json decode error, skipping")
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

  # -- Misskey /api/meta
  def query_misskey_meta(crawler = %Crawler{halted?: false, has_mastapi?: false, has_statusnet?: false, has_peertubeapi?: false, has_nodeinfo?: false}) do
    case request(crawler, "/api/meta", [method: :post]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        debug(crawler, "got /api/meta " <> inspect(body))
        %Crawler{crawler | has_misskey?: true, misskey_meta: body}
      {:ok, %HTTPoison.Response{status_code: code}} when code in @mastapi_not_found ->
        debug(crawler, "misskey is not found. #{inspect code}")
        %Crawler{crawler | has_misskey?: false}
      {:ok, %HTTPoison.Response{status_code: code}} when code not in @down_http_codes  ->
        debug(crawler, "misskey responded with an invalid code, maybe down or not found: #{inspect code}")
        crawler
      {:error, %Jason.DecodeError{}} ->
        debug(crawler, "json decode error, skipping")
        %Crawler{crawler | has_misskey?: false}
      failed ->
        debug(crawler, "host is down (meta misskey) " <> inspect(failed))
        %Crawler{crawler | halted?: true, fatal_error: failed}
    end
  end
  def query_misskey_meta(crawler), do: crawler

  def query_misskey_stats(crawler = %Crawler{halted?: false, has_misskey?: true}) do
    case request(crawler, "/api/stats", [method: :post]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        debug(crawler, "got /api/stats " <> inspect(body))
        %Crawler{crawler | misskey_stats: body}
      {:ok, %HTTPoison.Response{status_code: code}} when code in @mastapi_not_found ->
        debug(crawler, "misskey stats is not found. #{inspect code}")
        crawler
      {:ok, %HTTPoison.Response{status_code: code}} when code not in @down_http_codes  ->
        debug(crawler, "misskey stats responded with an invalid code, maybe down or not found: #{inspect code}")
        crawler
      {:error, %Jason.DecodeError{}} ->
        debug(crawler, "json decode error, skipping")
        crawler
      failed ->
        debug(crawler, "host is down " <> inspect(failed))
        %Crawler{crawler | halted?: true, fatal_error: failed}
    end
  end
  def query_misskey_stats(crawler), do: crawler

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

  def request(crawler, path, options \\ []), do: request(crawler, path, options, 1)

  @env Mix.env
  defp request(crawler = %Crawler{instance: %Instance{domain: domain}}, path, options, retries) do
    follow_redirects = Keyword.get(options, :follow_redirects, false)
    json = Keyword.get(options, :json, true)
    method = Keyword.get(options, :method, :get)
    accept = Keyword.get(options, :accept)
    timeout = Keyword.get(options, :timeout, 15_000)
    recv_timeout = Keyword.get(options, :recv_timeout, 15_000)
    body = Keyword.get(options, :body, "")
    {mon_ua, options} = if crawler.instance.monitor do
      mon_ua = " - monitoring enabled https://fediverse.network/monitoring"
      {mon_ua, [hackney: @hackney_mon_opts]}
    else
      {"", [hackney: @hackney_opts]}
    end
    options = [timeout: timeout, recv_timeout: recv_timeout, follow_redirect: follow_redirects] ++ options
    dev_ua = if @env == :dev, do: " [dev]", else: ""
    headers = %{
      "User-Agent" => "fediverse.network crawler#{dev_ua} (https://fediverse.network/info#{mon_ua} root@fediverse.network)",
    }
    headers = if json do
      Map.put(headers, "Accept", "application/json")
    else headers end
    headers = if accept do
      Map.put(headers, "Accept", accept)
    else headers end
    start = :erlang.monotonic_time
    IO.puts "-- #{domain} #{path} #{inspect(headers)}"
    case HTTPoison.request(method, "https://#{domain}#{path}", body, headers, options) do
      {:ok, response = %HTTPoison.Response{status_code: 200, body: body}} ->
        Instrumenter.http_request(path, response, start)
        info(crawler, "http ok - #{inspect method} - #{inspect path}")
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
      {:ok, response = %HTTPoison.Response{status_code: code}} when code in @retry_http_codes ->
        Instrumenter.http_request(path, response, start)
        retry(crawler, path, options, {:ok, response}, retries)
      {:ok, response} ->
        Instrumenter.http_request(path, response, start)
        info(crawler, "http ok - #{inspect response.status_code}")
        {:ok, response}
      {:error, error = %HTTPoison.Error{reason: reason}} when reason in [:timeout, :connect_timeout, :closed, :nxdomain, :ehostunreach] ->
        Instrumenter.http_request(path, error, start)
        retry(crawler, path, options, {:error, error}, retries)
        #if retries > 4  do
        #  error(crawler, "HTTP TIMEOUT: (#{inspect reason} - max retries reached)")
        #  {:error, error}
        #else
        #  error(crawler, "HTTP TIMEOUT: (#{inspect reason} - retry #{inspect retries})" <> inspect(error))
        #  :timer.sleep(:crypto.rand_uniform(retries*1000, retries*2000))
        #  request(crawler, path, options, retries + 1)
        #end
      {:error, error} ->
        Instrumenter.http_request(path, error, start)
        error(crawler, "HTTP ERROR: #{inspect error}")
        {:error, error}
    end
  end

  defp retry(crawler, path, options, error, retries) do
    if retries > 5 do
      error(crawler, "HTTP ERROR (max retries reached): #{inspect error}")
      error
    else
      debug(crawler, "HTTP retry #{inspect retries}: #{inspect error}")
      :timer.sleep(:crypto.rand_uniform(retries*2000, retries*5000))
      Instrumenter.retry_http_request()
      request(crawler, path, options, retries + 1)
    end
  end

  def debug(crawler, message) do
    domain = crawler.instance.domain
    Logger.debug "Crawler(#{inspect self()} ##{crawler.instance.id} #{domain}): #{message}"
  end
  def info(crawler, message) do
    domain = crawler.instance.domain
    Logger.info "Crawler(#{inspect self()} ##{crawler.instance.id} #{domain}): #{message}"
  end
  def error(crawler, message) do
    domain = crawler.instance.domain
    Logger.error "Crawler(#{inspect self()} ##{crawler.instance.id} #{domain}): #{message}"
  end

  defp post(text, instance, accounts, replaces \\ %{}) do
    Logger.warn inspect(instance.settings)
    [post_acct | repeat_accts] = if Map.get(instance.settings || %{}, :fedibot) do
      [instance.domain] ++ accounts
    else
      accounts
    end

    {instance_domain, link} = if instance.hidden do
      {"[private]", nil}
    else
      {Fd.Util.idna(instance.domain), "https://fediverse.network/#{Fd.Util.idna(instance.domain)}"}
    end

    text = text
    |> String.replace("{instance}", instance_domain)
    |> (fn(text) ->
      Enum.reduce(replaces, text, fn({replace, with_text}, text) ->
        String.replace(text, "{#{replace}}", with_text)
      end)
    end).()
    |> (fn(text) ->
      [text, link]
    end).()
    |> Enum.filter(&(&1))
    |> Enum.join(" - ")

    case Fd.Pleroma.post(post_acct, text) do
      {:ok, activity} ->
        Fd.Pleroma.repeat(activity.id, repeat_accts)
        {:ok, activity}
      {:error, error} ->
        Logger.error "Failed to post status: #{inspect error}"
        {:error, error}
    end
  end

  def downcase(nil), do: nil
  def downcase(s), do: String.downcase(s)

end

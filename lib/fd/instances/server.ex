defmodule Fd.Instances.Server do
  use GenServer
  require Logger
  alias Fd.{Instances, Instances.Instance}

  def start_link(id) do
    GenServer.start_link(__MODULE__, [id], [name: {:global, "instance:#{to_string(id)}"}])
  end

  defstruct [:id, :instance, :timer]

  def crawl(id) do
    case :global.whereis_name("instance:#{to_string(id)}") do
      :undefined ->
        {:ok, pid} = Fd.Instances.ServerSupervisor.start_child(id)
        send(pid, :crawl)
      pid ->
        send(pid, :crawl)
    end
  end

  def init([id]) do
    Logger.debug "starting instance #{inspect id}"
    instance = Instances.get_instance!(id)
    blacklisted? = Enum.any?(Application.get_env(:fd, :blacklist, []), fn(denied) ->
      String.ends_with?(instance.domain, denied)
    end)
    if blacklisted? do
      :ignore
    else
      delay = if Instances.dead?(instance) do
        Logger.info "instance #{instance.domain} dead, waiting"
        {delay, _} = get_delay(instance)
        (:crypto.rand_uniform(round(delay / 3), round(delay / 2)) * 60) * 1000
      else
        {min_delay, max_delay} = if instance.monitor, do: {0, 2}, else: {0, 8}
        (:crypto.rand_uniform(min_delay, max_delay) * 60) * 1000
      end
      {:ok, timer} = :timer.send_after(delay, self(), :crawl)
      {:ok, %__MODULE__{id: id, instance: instance, timer: timer}}
    end
  end

  @dev Mix.env == :dev
  def handle_info(:crawl, state = %__MODULE__{id: id}) do
    if state.timer, do: :timer.cancel(state.timer)
    instance = Instances.get_instance!(id)
               |> Fd.Repo.preload(:tags)
    if Map.get(instance.settings || %{}, :fedibot), do: {:ok, _} = Fd.Pleroma.create_or_get_user(instance.domain, instance.domain, "https://fediverse.network/#{instance.domain}")
    if @dev do
      Fd.Instances.Crawler.run(instance)
    else
      try do
        Fd.Instances.Crawler.run(instance)
      rescue
        e ->
          Sentry.capture_exception(e, [stacktrace: System.stacktrace(), extra: %{instance: instance.domain}])
        Logger.error "Server #{inspect(id)} rescued: #{inspect e}"
      catch
        e ->
          Sentry.capture_exception(e, [extra: %{instance: instance.domain}])
          Logger.error "Server #{inspect(id)} catched: #{inspect e}"
      end
    end
    Fd.Cache.ctx_delete("Instance:#{instance.id}")
    {delay, hibernate} = get_delay(instance)
    timer = case :timer.send_after(delay, self(), :crawl) do
      {:ok, timer} -> timer
      _ -> nil
    end
    state = %__MODULE__{state | instance: instance, timer: timer}
    if hibernate do
      {:noreply, state, :hibernate}
    else
      {:noreply, state}
    end
  end

  def handle_info(unhandled, state) do
    Logger.error "Server #{inspect(state.id)} unhandled info: #{inspect unhandled}"
    {:noreply, state, :hibernate}
  end

  defp get_delay(instance) do
    instance
    |> Instances.delay()
    |> Fd.Util.get_delay()
    |> (fn(delay) ->
      Logger.debug "Crawl delay for instance #{to_string(instance.id)} set to #{to_string(delay)}"
      {delay, delay > 900_000}
    end).()
  end

end

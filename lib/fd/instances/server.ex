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
    max_delay = if instance.monitor, do: 2, else: 15
    delay = (:crypto.rand_uniform(0, max_delay) * 60) * 1000
    timer = :erlang.send_after(delay, self(), :crawl)
    {:ok, %__MODULE__{id: id, instance: instance}}
  end

  @dev Mix.env == :dev
  def handle_info(:crawl, state = %__MODULE__{id: id}) do
    if state.timer, do: :timer.cancel(state.timer)
    instance = Instances.get_instance!(id)
    if @dev do
      Fd.Instances.Crawler.run(instance)
    else
      try do
        Fd.Instances.Crawler.run(instance)
      rescue
        e ->
          Logger.error "Server #{inspect(id)} rescued: #{inspect e}"
      catch
        e ->
          Logger.error "Server #{inspect(id)} catched: #{inspect e}"
      end
    end
    timer = :erlang.send_after(get_delay(instance), self(), :crawl)
    {:noreply, %__MODULE__{state | instance: instance, timer: timer}}
  end

  defp get_delay(instance) do
    cond do
      instance.monitor -> :instance_monitor
      instance.dead -> :instance_dead
      true -> :instance_default
    end
    |> Fd.Util.get_delay()
    |> (fn(delay) ->
      Logger.debug "Crawl delay for instance #{to_string(instance.id)} set to #{to_string(delay)}"
      delay
    end).()
  end

end

defmodule Fd.Application do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    :ok = :error_logger.add_report_handler(Sentry.Logger)
    start_prometheus()
    Fd.Instances.Crawler.setup()
    :ok = :hackney_pool.start_pool(:hackney_chartd, [{:timeout, 2000}, {:max_connections, 50}, {:connect_timeout, 2000}])

    children = [
      supervisor(Fd.Repo, []),
      worker(Fd.Cache, []),
      worker(Fd.GlobalStats, []),
      worker(Fd.HostStats, []),
      supervisor(FdWeb.Endpoint, []),
      supervisor(Fd.Instances.ServerSupervisor, []),
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Fd.Supervisor]
    case Supervisor.start_link(children, opts) do
      ok = {:ok, sup} ->
        if Application.get_env(:fd, :instances)[:autostart], do: spawn(fn -> run_instances() end)
        ok
      err -> err
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    FdWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp run_instances() do
    alias Fd.{Repo, Instances, Instances.Instance, Instances.ServerSupervisor}
    import Ecto.Query

    :timer.sleep(500)
    mon_instance_ids = from(i in Instance, select: i.id, where: i.monitor == true, order_by: [asc: i.last_checked_at])
    |> Repo.all
    instance_ids = from(i in Instance, select: i.id, where: (i.server != 0) and (is_nil(i.monitor) or i.monitor == false), order_by: [asc: i.last_checked_at])
    |> Repo.all
    unknown_instance_ids = from(i in Instance, select: i.id, where: ((is_nil(i.server) or i.server == 0)) and (is_nil(i.monitor) or i.monitor == false), order_by: [asc: i.last_checked_at])
    |> Repo.all
    for instance_id <- mon_instance_ids ++ instance_ids ++ unknown_instance_ids do
      IO.puts "-- starting instance #{instance_id}"
      Fd.Instances.ServerSupervisor.start_child(instance_id)
      :timer.sleep(:crypto.rand_uniform(250, 1000))
    end
  end

  defp start_prometheus() do
    require Prometheus.Registry

    #Prometheus.Registry.register_collector(:prometheus_process_collector)
    Fd.Instances.Instrumenter.setup()
    Fd.Repo.Instrumenter.setup()
    FdWeb.PhoenixInstrumenter.setup()
    FdWeb.PipelineInstrumenterPlug.setup()
    FdWeb.MetricsExporterPlug.setup()
  end

end

defmodule Fd.Application do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    Fd.Instances.Crawler.setup()

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      supervisor(Fd.Repo, []),
      worker(Fd.GlobalStats, []),
      worker(Fd.HostStats, []),
      # Start the endpoint when the application starts
      supervisor(FdWeb.Endpoint, []),
      # Start your own worker by calling: Fd.Worker.start_link(arg1, arg2, arg3)
      # worker(Fd.Worker, [arg1, arg2, arg3]),
      supervisor(Fd.Instances.ServerSupervisor, []),
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Fd.Supervisor]
    if Application.get_env(:fd, :instances)[:autostart], do: spawn(fn -> run_instances() end)
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    FdWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def run_instances() do
    alias Fd.{Repo, Instances, Instances.Instance, Instances.ServerSupervisor}
    import Ecto.Query

    :timer.sleep(500)
    mon_instance_ids = from(i in Instance, select: i.id, where: i.monitor == true, order_by: [asc: i.last_checked_at])
    |> Repo.all
    instance_ids = from(i in Instance, select: i.id, where: is_nil(i.monitor) or i.monitor == false, order_by: [asc: i.last_checked_at])
    |> Repo.all
    for instance_id <- mon_instance_ids ++ instance_ids do
      IO.puts "-- starting instance #{instance_id}"
      Fd.Instances.ServerSupervisor.start_child(instance_id)
      :timer.sleep(:crypto.rand_uniform(50, 350))
    end
  end

end

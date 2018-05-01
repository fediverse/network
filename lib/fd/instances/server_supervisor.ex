defmodule Fd.Instances.ServerSupervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_child(id) do
    Supervisor.start_child(__MODULE__, [id])
  end

  def init(_opts) do
    children = [
      worker(Fd.Instances.Server, [], restart: :transient)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end

end

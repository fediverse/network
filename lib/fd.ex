defmodule Fd do
  @moduledoc """
  Fd keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @env Mix.env()
  def build_env(), do: @env

  @doc "Crawls the instance at `domain`."
  @spec crawl(String.t | integer) :: nil
  def crawl(domain) when is_binary(domain) do
    id = Fd.Instances.get_instance_by_domain!(domain_id)
    Fd.Instances.Server.crawl(id)
  end
  def crawl(id) when is_integer(id) do
    Fd.Instances.Server.crawl(id)
  end

end

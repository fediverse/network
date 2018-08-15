defmodule Fd do
  @moduledoc """
  Fd keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @env Mix.env()
  def build_env(), do: @env
end

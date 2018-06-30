defmodule Fd.LoginEmail do
  require Logger
  import Swoosh.Email
  import Fd.Util, only: [idna: 1]
  import FdWeb.Router.Helpers

  def login(instance = %Fd.Instances.Instance{}) do
    key = Phoenix.Token.sign(FdWeb.Endpoint, Application.get_env(:fd, :email_login_salt), "instance:#{instance.id}:#{DateTime.utc_now() |> DateTime.to_unix}")
    if Mix.env == :dev do
      Logger.info("Login key: #{manage_url(FdWeb.Endpoint, :login_by_token, key)}")
    end
    new()
    |> to({idna(instance.domain), instance.email})
    |> from({"fediverse.network", "accounts@email.fediverse.network"})
    |> reply_to("root+instance-login-#{instance.id}@fediverse.network")
    |> subject("Login to manage your instance \"#{idna(instance.domain)}\" on fediverse.network")
    |> html_body(html(instance, key))
    |> text_body(text(instance, key))
  end

  def login(_), do: :error

  def text(instance, key) do
    """
    Hello,

    Someone -- probably you -- asked to log-in on fediverse.network to manage your instance, #{idna(instance.domain)}.

    Please follow this link to continue:

    #{manage_url(FdWeb.Endpoint, :login_by_token, key)}

    This link will be valid for a week.
    """
  end

  def html(instance, key) do
    url = manage_url(FdWeb.Endpoint, :login_by_token, key)
    """
    Hello,
    <br/><br/>
    Someone -- probably you -- asked to log-in on fediverse.network to manage your instance, #{idna(instance.domain)}.
    <br /><br />
    Please follow this link to continue:
    <br/><br/>
    <a href="#{url}">#{url}</a>
    <br/><br/>
    This link will be valid for a week.
    """
  end

end


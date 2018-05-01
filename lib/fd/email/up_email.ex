defmodule Fd.UpEmail do
  import Swoosh.Email
  import Fd.Util, only: [idna: 1]

  def up_email(instance = %Fd.Instances.Instance{}) do
    new()
    |> to({idna(instance.domain), instance.email})
    |> from({"fediverse.network monitoring", "monitoring@email.fediverse.network"})
    |> reply_to("root+instance-mon-#{instance.id}@fediverse.network")
    |> put_bcc("root+instance-mon-#{instance.id}@fediverse.network")
    |> subject("#{idna(instance.domain)} is available again!")
    |> html_body(html(instance))
    |> text_body(text(instance))
  end

  def login(_), do: :error

  def text(instance) do
    """
    Hello,

    Great news! #{idna(instance.domain)} seems to be available again.

    We're still fixing some bugs -- if this alert was a false positive, sorry about that! Do not hesitate to report it to us.

    ---
    This e-mail was sent by https://fediverse.network/monitoring
    To unsubscribe, please go to https://fediverse.network/manage and disable the monitoring feature.
    """
  end

  def html(instance) do
    """
    Hello,
    <br/><br/>
    Great news! #{idna(instance.domain)} seems to be available again.
    <br/><br/>
    We're still fixing some bugs -- if this alert was a false positive, sorry about that! Do not hesitate to report it to us.
    <br/><br/>
    ---<br/>
    This e-mail was sent by <a href="https://fediverse.network/monitoring">fediverse.network monitoring</a>.<br/>
    To unsubscribe, please <a href="https://fediverse.network/manage">log-in to manage your instance</a> and disable the monitoring feature.<br/>
    """
  end

end


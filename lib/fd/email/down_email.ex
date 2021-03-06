defmodule Fd.DownEmail do
  require Logger
  import Swoosh.Email
  import Fd.Util, only: [idna: 1]

  def down_email(instance = %Fd.Instances.Instance{}, check) do
    if instance.settings.maintenance_mode? do
      Logger.info("Skipping down email for #{instance.domain} because maintenance is planned")
    else
      new()
      |> to({idna(instance.domain), instance.email})
      |> from({"fediverse.network monitoring", "monitoring@email.fediverse.network"})
      |> reply_to("root+instance-mon-#{instance.id}@fediverse.network")
      |> put_bcc("root+instance-mon-#{instance.id}@fediverse.network")
      |> subject("#{idna(instance.domain)} is down")
      |> html_body(html(instance, check))
      |> text_body(text(instance, check))
    end
  end

  def login(_), do: :error

  def text(instance, check) do
    """
    Hello,

    Your instance #{idna(instance.domain)} has been detected down.

    The reason seems to be: #{Map.get(check, "error_s", "unknown")}

    We're still fixing some bugs -- if this alert was a false positive, sorry about that! Do not hesitate to report it to @href@pleroma.fr.

    ---
    This e-mail was sent by https://fediverse.network/monitoring
    To unsubscribe, please go to https://fediverse.network/manage
    """
  end

  def html(instance, check) do
    """
    Hello,
    <br/><br/>
    Your instance #{idna(instance.domain)} has been detected down.
    <br/><br/>
    The reason seems to be: <strong>#{Map.get(check, "error_s", "unknown")}</strong>.
    <br/><br/>
    We're still fixing some bugs -- if this alert was a false positive, sorry about that! Do not hesitate to report it to @href@pleroma.fr.
    <br/><br/>
    ---<br/>
    This e-mail was sent by <a href="https://fediverse.network/monitoring">fediverse.network monitoring</a>.<br/>
    To unsubscribe, please <a href="https://fediverse.network/manage">log-in to manage your instance</a>.
    """
  end

end


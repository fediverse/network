defmodule Fd.HumanError do
  @moduledoc """
  Converts HTTPPoison.Error and other errors to human strings
  """
  require Logger

  def format({:ok, %HTTPoison.Response{status_code: code}}) do
    "HTTP #{to_string(code)}"
  end

  def format({:ok, unhandled}) do
    Logger.error "Unhandled HumanError: {:ok, #{inspect unhandled}}"
    "Error"
  end

  def format({:error, %Jason.DecodeError{}}) do
    "JSON decode failed"
  end

  def format({:error, %HTTPoison.Error{reason: reason}}) do
    format_httpoison(reason)
  end

  def format({:error, atom}) when is_atom(atom) do
    to_string(atom)
  end

  def format(error) do
    Logger.error "Unhandled HumanError: #{inspect error}"
    "Error"
  end

  defp format_httpoison({:tls_alert, 'handshake failure'}) do
    "TLS Handshake Failure"
  end

  defp format_httpoison({:tls_alert, 'bad certificate'}) do
    "Bad TLS Certificate"
  end

  defp format_httpoison({:tls_alert, 'certificate expired'}) do
    "TLS Certificate Expired"
  end

  defp format_httpoison({:tls_alert, other}) when is_list(other) do
    "TLS #{to_string(other)}"
  end

  defp format_httpoison({:tls_alert, _}) do
    "TLS Error"
  end

  defp format_httpoison(:connect_timeout) do
    "Connect Timeout"
  end

  defp format_httpoison(:timeout) do
    "Timeout"
  end

  defp format_httpoison(:nxdomain) do
    "DNS Error"
  end

  defp format_httpoison(:closed) do
    "Connection closed"
  end

  defp format_httpoison(:econnrefused) do
    "Connection refused"
  end

  defp format_httpoison(atom) when is_atom(atom) do
    "HTTP Error #{to_string(atom)}"
  end

  defp format_httpoison(_) do
    "HTTP Error"
  end

end



defmodule Fd.Social do
  require Logger

  def async_post(user_at_host, status) do
    spawn(fn() -> post(user_at_host, status) end)
  end

  def post(user_at_host, status) do
    uri = URI.parse("https://#{user_at_host}")
    atom = String.to_atom(user_at_host)
    pass = Application.get_env(:fd, :social, []) |> Keyword.get(atom, "nopass")
    user = uri.userinfo
    host = uri.host
    body = %{"status" => status} |> Poison.encode!
    auth = "#{user}:#{pass}"
    |> Base.url_encode64()
    headers = %{
      "Content-Type" => "application/json",
      "Accept" => "application/json",
      "User-Agent" => "fediverse.network Fd.Social",
      "Authorization" => "Basic #{auth}",
    }
    case HTTPoison.post("https://#{host}/api/statuses/update.json", body, headers, []) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        :ok
      error ->
        Logger.error "Failed to post status \"#{status}\" to #{user_at_host} : #{inspect error}"
        error
    end
  end

end

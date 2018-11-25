defmodule Fd.Pleroma do
  alias Pleroma.{User, Repo, Web.CommonAPI}
  require Logger

  @general_accounts %{
    :mon  => {"monitoring", "Fediverse Monitoring", "and up, and down, and up, and down, and up, and down, and..."},
    :watch => {"watch", "Fediverse Watch", "https://fediverse.network - new instances and instances changes"},
    :new => {"new", "New Instance!", "It grows! https://fediverse.network/newest"},
  }

  def sanitize_nick(nick) do
    String.replace(nick, ~r/[^a-zA-Z\d]/, "")
  end

  def ensure_general_accounts() do
    for {_, {nick, name, bio}} <- @general_accounts do
      {:ok, _} = create_or_get_user(nick, name, bio)
    end
  end

  def get_user(nick) when is_atom(nick) do
    IO.puts "get user with atom #{inspect nick}"
    with {nick, _, _} <- Map.get(@general_accounts, nick)
    do
      get_user(nick)
    else
      _ -> {:error, :not_defined_account}
    end
  end

  def get_user(user=%User{}) do
    IO.puts "Get user with user #{inspect user.id}"
    {:ok, user}
  end

  def get_user(nick) when is_binary(nick) do
    IO.puts "Get user with nick #{inspect nick}"
    if user = User.get_by_nickname(sanitize_nick(nick)) do
      {:ok, user}
    else
      {:error, :user_not_found}
    end
  end

  def create_or_get_user(nick, name, bio) do
    nick = sanitize_nick(nick)
    if user = User.get_by_nickname(nick) do
      {:ok, user}
    else
      password = Base.encode64(:crypto.strong_rand_bytes(42))
      params = %{
        nickname: nick,
        email: "social+#{nick}@fediverse.network",
        password: password,
        password_confirmation: password,
        name: name,
        bio: bio
      }
      changeset = User.register_changeset(%User{}, params)
      case Repo.insert(changeset) do
        {:ok, user} ->
          Logger.info "Created Pleroma user: #{inspect {user.id, user.nickname}}"
          {:ok, user}
        {:error, error} ->
          Logger.debug "Pleroma.User insert failed: #{inspect error}"
          {:error, error}
      end
    end
  end

  def post_general_accounts(status) do
    for {_, {nick, _, _}} <- @general_accounts do
      {:ok, _} = post(nick, status)
    end
  end

  def post(nick, status) do
    with \
         {:ok, user} <- get_user(nick),
         {:allow, _} <- Hammer.check_rate("pleroma:post:#{user.id}", 60_000, 3),
         {:ok, activity} <- CommonAPI.post(user, %{"status" => status})
    do
      Logger.info "#{__MODULE__} Posted to #{nick}: #{inspect status}"
      {:ok, activity}
    else
      {:error, error} -> {:error, error}
      {:deny, _} -> {:error, :rate_limited}
    end
  end

  def repeat(_, []), do: []

  def repeat(ap_id, users) when is_list(users) do
    IO.puts "repeat with users #{inspect users}"
    users = for user <- users, do: repeat(ap_id, get_user(user))
  end

  def repeat(ap_id, user) when is_binary(user) or is_atom(user) do
    IO.puts "repeat with binary #{inspect user}"
    repeat(ap_id, get_user(user))
  end

  def repeat(ap_id, {:ok, user}), do: repeat(ap_id, user)

  def repeat(ap_id, user = %User{}) do
    Logger.info "#{__MODULE__} Repeated #{ap_id} from #{user.nickname}"
    CommonAPI.repeat(ap_id, user)
  end

end

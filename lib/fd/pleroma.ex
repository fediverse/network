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

  def get_user(:disabled), do: :disabled

  def get_user(nick) when is_atom(nick) do
    with {nick, _, _} <- Map.get(@general_accounts, nick),
         true <- Application.get_env(:fd, :monitoring_alerts, true)
    do
      get_user(nick)
    else
      _ -> :disabled
      _ -> {:error, :not_defined_account}
    end
  end

  def get_user(user=%User{}) do
    {:ok, user}
  end

  def get_user(nick) when is_binary(nick) do
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

  def post(nick, status, repeats \\ []) do
    with \
         [post_nick | repeat_nicks] <- (case nick do
           nick when is_binary(nick) -> [nick]
           nick when is_list(nick) -> nick
         end),
         {:ok, user} <- get_user(post_nick),
         {:allow, _} <- Hammer.check_rate("pleroma:post:#{user.id}", 120_000, 30),
         {:ok, activity} <- CommonAPI.post(user, %{"status" => status})
    do
      Logger.info "#{__MODULE__} Posted to #{post_nick} (repeats: #{inspect(repeat_nicks)}): #{inspect status}"
      repeat(activity.id, repeat_nicks)
      {:ok, activity}
    else
      :disabled -> {:ok, %{id: :disabled}}
      {:error, error} -> {:error, error}
      {:deny, _} -> {:error, :rate_limited}
    end
  end

  def repeat(_, []), do: []
  def repeat(_, :disabled), do: :ok
  def repeat(:disabled, _), do: :ok

  def repeat(ap_id, users) when is_list(users) do
    users = for user <- users, do: repeat(ap_id, get_user(user))
  end

  def repeat(ap_id, user) when is_binary(user) or is_atom(user) do
    repeat(ap_id, get_user(user))
  end


  def repeat(ap_id, {:ok, user}), do: repeat(ap_id, user)

  def repeat(ap_id, user = %User{}) do
    Logger.info "#{__MODULE__} Repeated #{ap_id} from #{user.nickname}"
    CommonAPI.repeat(ap_id, user)
  end

end

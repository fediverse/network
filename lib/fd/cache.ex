defmodule Fd.Cache do
  use Nebulex.Cache, otp_app: :fd, adapter: Nebulex.Adapters.Local
  @moduledoc """
  # Fd.Cache

  This is a classic `Nebulex.Cache` cache; with some enhancements:

  ## Lazy Expiry

  Some cached values depends on time, and take some seconds to complete.

  While using a TTL is enough for most cases, lazy expiry does not remove the cached value when expired:

  * the last cached value is returned
  * … while the new one computes

  It does it by storing a private state into the cache key with its planned expiry timestamp and a cue if it's in
  refresh or not.

  lazy/2, lazy/3 is the "high level" api over lazy_set, lazy_get. You pass it a key and either

  * lazy/2: `key, {module, fun, arg}`
  * lazy/2: `key, &capture, args`
  * lazy/3: `key, {m, f}, args`

  The called function must reply {:ok, value, ttl} (ttl in seconds), otherwise all its return value will be used as the
  value; and the ttl will be of 120 seconds.

  ## Context Cache

  It basically allows you to have something similar as nested-caching from Rails.

  ctx_set/3, ctx_set/4, ctx_get/2, ctx_delete/1 allows to group cache keys under a _context_.

  This is just a simple wrapper against set/3 and get/1: a list of the cached keys under a context are kept into a list.

  When you call ctx_delete/1, it'll call delete/1 against all the keys referenced by the list and the list itself.

  ctx_set/3, ctx_set/4, ctx_delete/1 works using a **spawned process** (so it returns immediately) and uses
  transaction/1.

  """

  def key(list) when is_list(list) do
    list
    |> List.flatten()
    |> Enum.join("|")
  end

  #
  # -- LAZY
  #

  def lazy(key, mfa, args \\ nil) do
    if value = lazy_get(key) do
      value
    else
      lazy_set(key, mfa, args)
    end
  end

  def lazy_set(key, mf, args \\ nil) do
    result = case mf do
      {m, f, a} -> apply(m, f, a)
      {m, f} -> apply(m, f, args)
      fun -> apply(fun, args)
    end

    {:ok, value, ttl} = case result do
      {:ok, value, ttl} ->
        {:ok, value, ttl}
      value ->
        {:ok, value, 120}
    end

    expired = DateTime.utc_now()
    |> Timex.shift(seconds: ttl)
    |> DateTime.to_unix()
    data = %{value: value, ts: expired, mf: mf, args: args, fresh: true}
    set(key, data)
    value
  end

  def lazy_get(key) do
    case get(key) do
      data = %{value: value, ts: ts, fresh: fresh} ->
        # We check if it's expired only once (with fresh as a guard) to avoid spawning multiple times the new value
        expired? = if fresh, do: DateTime.to_unix(DateTime.utc_now()) > ts, else: true
        if expired? do
          set(key, %{data | fresh: false})
          spawn(fn -> lazy_set(key, data.mf, data.args) end)
        end
        value
      other ->
        nil
    end
  end

  #
  # -- CONTEXT
  #

  def ctx_get_or_set(ctx, key, fun, options \\ []) do
    if value = ctx_get(ctx, key) do
      value
    else
      ctx_set(ctx, key, fun.(), options)
    end
  end

  def ctx_set(ctx, key, value, options \\ []) do
    spawn fn ->
      key_with_ctx = key([ctx, key])
      transaction fn ->
        ctx_keys = get(ctx) || []
        unless Enum.member?(ctx_keys, key), do: set(ctx, [key|ctx_keys])
        set(key_with_ctx, value, options)
      end
    end
    value
  end

  def ctx_get(ctx, key) do
    get(key([ctx, key]))
  end

  def ctx_delete(ctx) do
    spawn fn ->
      transaction fn ->
        for key <- get(ctx)||[] do
          [ctx, key]
          |> key()
          |> delete()
        end
        delete(ctx)
      end
    end
    :ok
  end

end

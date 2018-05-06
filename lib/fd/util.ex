defmodule Fd.Util do
  def put_if(map, key, value) do
    if value do
      Map.put(map, key, value)
    else
      map
    end
  end

  def put_if(map, key, value, true) do
    Map.put(map, key, value)
  end

  def put_if(map, key, value, null) when null in ["", false, nil] do
    map
  end

  def put_if(map, key, value, something) do
    if something do
      Map.put(map, key, value)
    else
      map
    end
  end

  def idna(domain) do
    domain
    |> to_charlist()
    |> :idna.from_ascii()
    |> to_string()
  end

  def from_idna(domain = "xn--"<>_), do: domain
  def from_idna(domain) do
    domain
    |> to_charlist()
    |> :idna.to_ascii()
    |> to_string()
  end


  def get_delay(key) do
    minutes = case Keyword.get(Application.get_env(:fd, :delays), key) do
      {:rand, min, max} -> :crypto.rand_uniform(min, max)
      {:hour, hours} when is_integer(hours) -> 60 * hours
      minutes when is_integer(minutes) -> minutes
    end
    (minutes * 60) * 1000
  end

end

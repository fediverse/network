defmodule Fd.Domain do
  def total_count(stats, domain) do
    IO.puts "total count #{inspect domain}"
    case Enum.find(stats["domains"], fn({d, _}) -> d == domain end) do
      {_, %{"total" => total}} -> total
      _ -> 0
    end
    |> IO.inspect()
  end
end

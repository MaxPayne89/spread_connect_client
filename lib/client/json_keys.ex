defmodule SpreadConnectClient.Client.JsonKeys do
  def camelize(map) when is_map(map) do
    map
    |> Map.new(fn {k, v} -> {camelize_key(k), camelize(v)} end)
  end

  def camelize(list) when is_list(list) do
    Enum.map(list, &camelize/1)
  end

  def camelize(other), do: other

  defp camelize_key(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> camelize_key()
  end

  defp camelize_key(str) when is_binary(str) do
    str
    |> String.split("_")
    |> case do
      [first | rest] -> first <> Enum.map_join(rest, &String.capitalize/1)
    end
  end
end

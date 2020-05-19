defmodule DumpHelper do
  @moduledoc false

  def dump(%{__struct__: _} = struct) do
    map = Map.from_struct(struct)
    :maps.map(&dump/2, map) |> filter_nils()
  end
  def dump(map), do: :maps.map(&dump/2, map)
  def dump(_key, value), do: ensure_nested_map(value)

  defp ensure_nested_map(%{__struct__: Date} = data), do: data
  defp ensure_nested_map(%{__struct__: DateTime} = data), do: data
  defp ensure_nested_map(%{__struct__: NaiveDateTime} = data) , do: data
  defp ensure_nested_map(%{__struct__: Time} = data), do: data
  defp ensure_nested_map(%{__struct__: BSON.ObjectId} = data), do: data
  defp ensure_nested_map(%{__struct__: _} = struct) do
    map = Map.from_struct(struct)
    :maps.map(&dump/2, map) |> filter_nils()
  end
  defp ensure_nested_map(list) when is_list(list), do: Enum.map(list, &ensure_nested_map/1)

  defp ensure_nested_map(data), do: data

  defp filter_nils(map) when is_map(map) do
    Enum.reject(map, fn {_key, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end
  defp filter_nils(keyword) when is_list(keyword) do
    Enum.reject(keyword, fn {_key, value} -> is_nil(value) end)
  end

end
defmodule ExCellerate.Functions.General.IfNull do
  @moduledoc false
  @behaviour ExCellerate.Function

  def name, do: "ifnull"
  def arity, do: 2

  def call([val, default]) do
    if is_nil(val), do: default, else: val
  end
end

defmodule ExCellerate.Functions.General.Concat do
  @moduledoc false
  @behaviour ExCellerate.Function

  def name, do: "concat"
  def arity, do: :any

  def call(args) do
    args
    |> Enum.map(&to_string/1)
    |> Enum.join("")
  end
end

defmodule ExCellerate.Functions.General.Lookup do
  @moduledoc false
  @behaviour ExCellerate.Function

  def name, do: "lookup"
  def arity, do: :any

  def call([map, key]) when is_map(map) do
    Map.get(map, key)
  end

  def call([list, index]) when is_list(list) and is_integer(index) do
    Enum.at(list, index)
  end

  def call([map, key, default]) when is_map(map) do
    Map.get(map, key, default)
  end

  def call([list, index, default]) when is_list(list) and is_integer(index) do
    Enum.at(list, index, default)
  end

  def call([_, _, default]), do: default
  def call(_), do: nil
end

defmodule ExCellerate.Functions.General.If do
  @moduledoc false
  @behaviour ExCellerate.Function

  def name, do: "if"
  def arity, do: 3

  def call([condition, then_val, else_val]) do
    if condition, do: then_val, else: else_val
  end
end

defmodule ExCellerate.Functions.General.Normalize do
  @moduledoc false
  @behaviour ExCellerate.Function

  def name, do: "normalize"
  def arity, do: 1

  def call([val]) when is_binary(val) do
    val
    |> String.downcase()
    |> String.replace(" ", "_")
  end

  def call(val), do: val
end

defmodule ExCellerate.Functions.General.Substring do
  @moduledoc false
  @behaviour ExCellerate.Function

  def name, do: "substring"
  def arity, do: :any

  def call([str, start]) when is_binary(str) and is_integer(start) do
    String.slice(str, start..-1//1)
  end

  def call([str, start, length])
      when is_binary(str) and is_integer(start) and is_integer(length) do
    String.slice(str, start, length)
  end

  def call(_), do: nil
end

defmodule ExCellerate.Functions.General.Contains do
  @moduledoc false
  @behaviour ExCellerate.Function

  def name, do: "contains"
  def arity, do: 2

  def call([str, substr]) when is_binary(str) and is_binary(substr) do
    String.contains?(str, substr)
  end

  def call(_), do: false
end

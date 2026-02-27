defmodule ExCellerate.Functions.General.Substring do
  @moduledoc false
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "substring"
  @impl true
  def arity, do: :any

  @impl true
  def call([str, start]) when is_binary(str) and is_integer(start) do
    String.slice(str, start..-1//1)
  end

  def call([str, start, length])
      when is_binary(str) and is_integer(start) and is_integer(length) do
    String.slice(str, start, length)
  end

  def call(_), do: nil
end

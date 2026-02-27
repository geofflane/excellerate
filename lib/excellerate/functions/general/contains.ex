defmodule ExCellerate.Functions.General.Contains do
  @moduledoc false
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "contains"
  @impl true
  def arity, do: 2

  @impl true
  def call([str, substr]) when is_binary(str) and is_binary(substr) do
    String.contains?(str, substr)
  end

  def call(_), do: false
end

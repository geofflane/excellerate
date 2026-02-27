defmodule ExCellerate.Functions.General.Concat do
  @moduledoc false
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "concat"
  @impl true
  def arity, do: :any

  @impl true
  def call(args) do
    Enum.map_join(args, "", &to_string/1)
  end
end

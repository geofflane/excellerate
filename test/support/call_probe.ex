defmodule ExCellerate.Test.CallProbe do
  @moduledoc false
  # A module shaped like an ExCellerate function. Tests put it in the scope data
  # to prove that expressions cannot invoke a module they did not resolve by name.
  def name, do: "call_probe"
  def arity, do: :any

  def call(args) do
    send(self(), {:call_probe, args})
    :probe_called
  end
end

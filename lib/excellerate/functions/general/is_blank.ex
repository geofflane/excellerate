defmodule ExCellerate.Functions.General.IsBlank do
  @moduledoc false
  # Internal: Implements the 'isblank' function — returns true if value
  # is nil or a whitespace-only (including empty) string.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "isblank"
  @impl true
  def arity, do: 1

  @impl true
  def call([nil]), do: true

  def call([str]) when is_binary(str) do
    String.trim(str) == ""
  end

  def call([_]), do: false
end

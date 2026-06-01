defmodule ExCellerate.NativeCompiler.Slots do
  @moduledoc false

  @type t :: %__MODULE__{
          cap: pos_integer(),
          minted: non_neg_integer(),
          free: [atom()]
        }

  defstruct [:cap, minted: 0, free: []]

  @doc """
  Creates a new slot pool with the given capacity.
  """
  @spec new(pos_integer()) :: t()
  def new(cap) when is_integer(cap) and cap > 0 do
    %__MODULE__{cap: cap, minted: 0, free: []}
  end

  @doc """
  Allocates a slot name from the pool.

  Returns `{:ok, name, updated_slots}` on success, or `{:full, slots}` when the
  pool is exhausted (free list empty and cap reached).
  """
  @spec alloc(t()) :: {:ok, atom(), t()} | {:full, t()}
  def alloc(%__MODULE__{free: [name | rest]} = slots) do
    {:ok, name, %{slots | free: rest}}
  end

  def alloc(%__MODULE__{minted: minted, cap: cap} = slots) when minted < cap do
    name = Module.concat(ExCellerate.Compiled, "S#{minted}")
    {:ok, name, %{slots | minted: minted + 1}}
  end

  def alloc(%__MODULE__{} = slots) do
    {:full, slots}
  end

  @doc """
  Returns a name to the pool's free list so it can be reused by a future `alloc/1`.
  """
  @spec free(t(), atom()) :: t()
  def free(%__MODULE__{free: free} = slots, name) when is_atom(name) do
    %{slots | free: [name | free]}
  end
end

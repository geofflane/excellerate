defmodule ExCellerate.NativeCompiler.Slots do
  @moduledoc false

  @type t :: %__MODULE__{
          cap: pos_integer(),
          minted: non_neg_integer(),
          free: [atom()]
        }

  defstruct [:cap, minted: 0, free: []]

  # Creates a new slot pool with the given capacity.
  @doc false
  @spec new(pos_integer()) :: t()
  def new(cap) when is_integer(cap) and cap > 0 do
    %__MODULE__{cap: cap, minted: 0, free: []}
  end

  # Allocates a slot name from the pool. Returns {:ok, name, updated_slots}, or
  # {:full, slots} when exhausted (free list empty and cap reached).
  @doc false
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

  # Returns a name to the pool's free list so a future alloc/1 reuses it. The
  # sole caller (the NativeCompiler GenServer) must not free the same name twice.
  @doc false
  @spec free(t(), atom()) :: t()
  def free(%__MODULE__{free: free} = slots, name) when is_atom(name) do
    %{slots | free: [name | free]}
  end
end

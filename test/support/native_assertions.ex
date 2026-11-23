defmodule ExCellerate.Test.NativeAssertions do
  @moduledoc false
  import ExUnit.Assertions

  # Native funs are guard closures (see ExCellerate.NativeCompiler.run/5) that
  # close over the compiled module they call, rather than bare `&Mod.eval/1`
  # captures. Asserts `fun` is such a closure backed by a module named with
  # `prefix`.
  def assert_native(fun, prefix \\ "Elixir.ExCellerate.Compiled.S") do
    info = Function.info(fun)
    assert info[:module] == ExCellerate.NativeCompiler

    assert Enum.any?(info[:env], fn value ->
             is_atom(value) and String.starts_with?(Atom.to_string(value), prefix)
           end),
           "expected #{inspect(fun)} to close over a #{prefix}* module"
  end
end

defmodule ExCellerate.Compiler.Lazy do
  @moduledoc false
  # Internal: compiles the built-in conditional functions so that only the
  # arguments they select are evaluated, as `&&`, `||` and `?:` already do.
  # Without this, `if(x != 0, 10 / x, 0)` raises when x is 0, because an
  # ordinary function call evaluates every argument first.
  #
  # Each expansion must return exactly what the function's eager `call/1`
  # returns for the same (evaluated) arguments; only evaluation order changes.
  # test/lazy_conditionals_test.exs checks that parity.
  #
  # Expansion is keyed on the resolved module, not the name, so a registry that
  # defines its own `if` keeps ordinary call semantics. Argument shapes that are
  # errors for the eager function (an odd `ifs`, an empty `switch`) return
  # :eager so the caller compiles a normal call and the error stays the same.

  alias ExCellerate.Functions.General.{And, Coalesce, If, IfNull, Ifs, Or, Switch}

  @spec expand(module(), [Macro.t()]) :: {:ok, Macro.t()} | :eager
  def expand(If, [condition, then_ast]), do: {:ok, if_ast(condition, then_ast, nil)}

  def expand(If, [condition, then_ast, else_ast]),
    do: {:ok, if_ast(condition, then_ast, else_ast)}

  def expand(Ifs, args) when args != [] and rem(length(args), 2) == 0 do
    {:ok, ifs_ast(args)}
  end

  def expand(And, args), do: {:ok, and_ast(args)}
  def expand(Or, args), do: {:ok, or_ast(args)}
  def expand(Coalesce, args), do: {:ok, coalesce_ast(args)}
  def expand(IfNull, [value, default]), do: {:ok, coalesce_ast([value, default])}

  def expand(Switch, [subject | pairs]) do
    subject_var = Macro.unique_var(:switch_subject, __MODULE__)

    {:ok,
     quote do
       unquote(subject_var) = unquote(subject)
       unquote(switch_ast(subject_var, pairs))
     end}
  end

  def expand(_module, _args), do: :eager

  defp if_ast(condition, then_ast, else_ast) do
    quote do
      if unquote(condition), do: unquote(then_ast), else: unquote(else_ast)
    end
  end

  # ifs(c1, v1, c2, v2, ...) -> value of the first truthy condition, else nil.
  defp ifs_ast([]), do: nil

  defp ifs_ast([condition, value | rest]) do
    if_ast(condition, value, ifs_ast(rest))
  end

  # Enum.all?/any? with & &1 return strict booleans.
  defp and_ast([]), do: true
  defp and_ast([arg | rest]), do: if_ast(arg, and_ast(rest), false)

  defp or_ast([]), do: false
  defp or_ast([arg | rest]), do: if_ast(arg, true, or_ast(rest))

  # First non-nil argument, else nil. `false` is a value here, not a miss.
  defp coalesce_ast([]), do: nil

  defp coalesce_ast([arg | rest]) do
    value_var = Macro.unique_var(:coalesce_value, __MODULE__)

    quote do
      case unquote(arg) do
        nil -> unquote(coalesce_ast(rest))
        unquote(value_var) -> unquote(value_var)
      end
    end
  end

  # switch(subject, case1, result1, ..., [default]): the first case equal (==)
  # to the subject selects its result; a trailing odd argument is the default.
  defp switch_ast(_subject_var, []), do: nil
  defp switch_ast(_subject_var, [default]), do: default

  defp switch_ast(subject_var, [case_ast, result | rest]) do
    quote do
      if unquote(subject_var) == unquote(case_ast) do
        unquote(result)
      else
        unquote(switch_ast(subject_var, rest))
      end
    end
  end
end

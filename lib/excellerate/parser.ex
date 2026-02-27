defmodule ExCellerate.Parser do
  @moduledoc false
  # Internal: Defines the NimbleParsec grammar for ExCellerate expressions.
  # It handles operator precedence, literals, variables, and function calls.
  import NimbleParsec

  # ... (rest of the module remains the same)

  # Helper functions for literals
  def handle_int([val]), do: String.to_integer(val)

  def handle_float([left, ".", ""]), do: String.to_float("#{left}.0")
  def handle_float([left, ".", right]), do: String.to_float("#{left}.#{right}")
  def handle_float([".", right]), do: String.to_float("0.#{right}")

  whitespace = ignore(optional(ascii_string([?\s, ?\t, ?\n], min: 1)))

  boolean =
    choice([
      string("true") |> replace(true),
      string("false") |> replace(false)
    ])

  int_literal =
    ascii_string([?0..?9], min: 1) |> reduce({__MODULE__, :handle_int, []})

  float_literal =
    choice([
      ascii_string([?0..?9], min: 1) |> concat(string(".")) |> ascii_string([?0..?9], min: 0),
      string(".") |> ascii_string([?0..?9], min: 1)
    ])
    |> reduce({__MODULE__, :handle_float, []})

  identifier =
    ascii_string([?a..?z, ?A..?Z, ?_], 1)
    |> optional(ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 1))
    |> reduce({Enum, :join, []})

  def make_dot_access(key), do: {:dot, key}
  def make_bracket_access(index), do: {:bracket, index}
  def make_call_access([]), do: {:call, []}
  def make_call_access(args), do: {:call, args}

  variable =
    identifier
    |> repeat(
      choice([
        ignore(string(".")) |> concat(identifier) |> map({__MODULE__, :make_dot_access, []}),
        ignore(string("["))
        |> parsec(:expression)
        |> ignore(string("]"))
        |> map({__MODULE__, :make_bracket_access, []}),
        ignore(string("("))
        |> optional(
          parsec(:expression)
          |> repeat(ignore(string(",")) |> concat(whitespace) |> parsec(:expression))
        )
        |> ignore(string(")"))
        |> reduce({__MODULE__, :make_call_access, []})
      ])
    )
    |> reduce({__MODULE__, :build_access, []})

  def build_access([name | accessors]) do
    initial = {:get_var, name}

    Enum.reduce(accessors, initial, fn
      {:dot, key}, acc -> {:access, acc, key}
      {:bracket, index}, acc -> {:access, acc, index}
      {:call, args}, acc -> {:call, acc, args}
    end)
  end

  literal =
    choice([
      boolean,
      float_literal,
      int_literal,
      variable
    ])

  primary =
    choice([
      whitespace |> concat(literal) |> concat(whitespace),
      ignore(string("(")) |> parsec(:expression) |> ignore(string(")")) |> concat(whitespace)
    ])

  unary =
    choice([
      whitespace
      |> string("not")
      |> replace(:not)
      |> concat(whitespace)
      |> concat(parsec(:unary))
      |> reduce({__MODULE__, :make_unary, []}),
      whitespace
      |> string("~")
      |> replace(:bnot)
      |> concat(whitespace)
      |> concat(parsec(:unary))
      |> reduce({__MODULE__, :make_unary, []}),
      whitespace
      |> string("-")
      |> replace(:negate)
      |> concat(whitespace)
      |> concat(parsec(:unary))
      |> reduce({__MODULE__, :make_unary, []}),
      primary
    ])

  defparsec(:unary, unary)

  def make_unary([op, operand]), do: {op, [], [operand]}

  factorial =
    unary
    |> choice([
      string("!") |> lookahead_not(string("=")) |> replace(:factorial),
      empty()
    ])
    |> reduce({__MODULE__, :handle_factorial, []})

  def handle_factorial([val, :factorial]), do: {:factorial, [], [val]}
  def handle_factorial([val]), do: val

  exponent =
    factorial
    |> repeat(whitespace |> string("^") |> replace(:^) |> concat(whitespace) |> concat(factorial))
    |> reduce({__MODULE__, :reduce_ops, []})

  multiplicative =
    exponent
    |> repeat(
      choice([
        whitespace |> string("*") |> replace(:*) |> concat(whitespace),
        whitespace |> string("/") |> replace(:/) |> concat(whitespace)
      ])
      |> concat(exponent)
    )
    |> reduce({__MODULE__, :reduce_ops, []})

  additive =
    multiplicative
    |> repeat(
      choice([
        whitespace |> string("+") |> replace(:+) |> concat(whitespace),
        whitespace |> string("-") |> replace(:-) |> concat(whitespace)
      ])
      |> concat(multiplicative)
    )
    |> reduce({__MODULE__, :reduce_ops, []})

  bitshift =
    additive
    |> repeat(
      choice([
        whitespace |> string("<<") |> replace(:bsl) |> concat(whitespace),
        whitespace |> string(">>") |> replace(:bsr) |> concat(whitespace)
      ])
      |> concat(additive)
    )
    |> reduce({__MODULE__, :reduce_ops, []})

  comparison =
    bitshift
    |> repeat(
      choice([
        whitespace |> string("==") |> replace(:==) |> concat(whitespace),
        whitespace |> string("!=") |> replace(:!=) |> concat(whitespace),
        whitespace |> string(">=") |> replace(:>=) |> concat(whitespace),
        whitespace |> string("<=") |> replace(:<=) |> concat(whitespace),
        whitespace |> string(">") |> replace(:>) |> concat(whitespace),
        whitespace |> string("<") |> replace(:<) |> concat(whitespace)
      ])
      |> concat(bitshift)
    )
    |> reduce({__MODULE__, :reduce_ops, []})

  bitwise =
    comparison
    |> repeat(
      choice([
        whitespace |> string("&") |> replace(:band) |> concat(whitespace),
        whitespace |> string("|^") |> replace(:bxor) |> concat(whitespace),
        whitespace |> string("|") |> replace(:bor) |> concat(whitespace)
      ])
      |> concat(comparison)
    )
    |> reduce({__MODULE__, :reduce_ops, []})

  logical =
    bitwise
    |> repeat(
      choice([
        whitespace |> string("&&") |> replace(:and) |> concat(whitespace),
        whitespace |> string("||") |> replace(:or) |> concat(whitespace)
      ])
      |> concat(bitwise)
    )
    |> reduce({__MODULE__, :reduce_ops, []})

  ternary =
    logical
    |> optional(
      whitespace
      |> string("?")
      |> replace(:question)
      |> concat(whitespace)
      |> parsec(:expression)
      |> concat(whitespace |> string(":") |> replace(:colon) |> concat(whitespace))
      |> parsec(:expression)
    )
    |> reduce({__MODULE__, :handle_ternary, []})

  def handle_ternary([cond, :question, true_val, :colon, false_val]),
    do: {:ternary, [], [cond, true_val, false_val]}

  def handle_ternary([val]), do: val

  defparsec(:expression, ternary)

  def reduce_ops([acc]), do: acc

  def reduce_ops([left, op, right | rest]) do
    op =
      case op do
        :bsl -> :<<<
        :bsr -> :>>>
        :band -> :&&&
        :bor -> :|||
        :bxor -> :"^^^"
        :and -> :&&
        :or -> :||
        _ -> op
      end

    reduce_ops([{op, [], [left, right]} | rest])
  end

  def parse(input) do
    case expression(input) do
      {:ok, [ast], "", _, _, _} -> {:ok, ast}
      {:ok, _, rest, _, _, _} -> {:error, "Unexpected input: #{rest}"}
      {:error, reason, _, _, _, _} -> {:error, reason}
    end
  end
end

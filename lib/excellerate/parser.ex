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

  escaped_char =
    ignore(string("\\"))
    |> choice([
      string("\\") |> replace("\\"),
      string("n") |> replace("\n"),
      string("t") |> replace("\t"),
      string("r") |> replace("\r"),
      string("\"") |> replace("\""),
      string("'") |> replace("'")
    ])

  single_string =
    ignore(string("'"))
    |> repeat(
      choice([escaped_char, lookahead_not(choice([string("'"), string("\\")])) |> utf8_char([])])
    )
    |> ignore(string("'"))

  double_string =
    ignore(string("\""))
    |> repeat(
      choice([escaped_char, lookahead_not(choice([string("\""), string("\\")])) |> utf8_char([])])
    )
    |> ignore(string("\""))

  string_literal =
    choice([single_string, double_string])
    |> reduce({__MODULE__, :handle_string_collect, []})

  def handle_string_collect(chars) do
    Enum.map_join(chars, "", fn
      c when is_integer(c) -> <<c::utf8>>
      c -> c
    end)
  end

  boolean =
    choice([
      string("true") |> lookahead_not(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_])) |> replace(true),
      string("false") |> lookahead_not(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_])) |> replace(false)
    ])

  null_literal =
    string("null")
    |> lookahead_not(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_]))
    |> replace(nil)

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
      null_literal,
      float_literal,
      int_literal,
      string_literal,
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
        whitespace |> string("/") |> replace(:/) |> concat(whitespace),
        whitespace |> string("%") |> replace(:%) |> concat(whitespace)
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

  logical_and =
    bitwise
    |> repeat(
      whitespace
      |> string("&&")
      |> replace(:and)
      |> concat(whitespace)
      |> concat(bitwise)
    )
    |> reduce({__MODULE__, :reduce_ops, []})

  logical_or =
    logical_and
    |> repeat(
      whitespace
      |> string("||")
      |> replace(:or)
      |> concat(whitespace)
      |> concat(logical_and)
    )
    |> reduce({__MODULE__, :reduce_ops, []})

  ternary =
    logical_or
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
      {:ok, [ast], "", _, _, _} ->
        {:ok, ast}

      {:ok, _, rest, _, {line, column}, _} ->
        {:error,
         ExCellerate.Error.exception(
           message: "Unexpected input at '#{binary_part(rest, 0, min(10, byte_size(rest)))}'",
           type: :parser,
           line: line,
           column: column
         )}

      {:error, reason, _, _, {line, column}, _} ->
        {:error,
         ExCellerate.Error.exception(
           message: reason,
           type: :parser,
           line: line,
           column: column
         )}
    end
  end
end

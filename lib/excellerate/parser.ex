defmodule ExCellerate.Parser do
  @moduledoc false
  # Internal: Defines the NimbleParsec grammar for ExCellerate expressions.
  #
  # ## Operator Precedence (lowest to highest)
  #
  # 1.  Ternary:        `a ? b : c`
  # 2.  Logical OR:     `||`
  # 3.  Logical AND:    `&&`
  # 4.  Bitwise:        `&`, `|`, `|^`
  # 5.  Comparison:     `==`, `!=`, `>=`, `<=`, `>`, `<`
  # 6.  Bitshift:       `<<`, `>>`
  # 7.  Additive:       `+`, `-`
  # 8.  Multiplicative: `*`, `/`, `%`
  # 9.  Exponent:       `^`              (left-associative)
  # 10. Factorial:      `n!`             (postfix unary)
  # 11. Unary:          `-`, `not`, `~`  (prefix unary)
  # 12. Primary:        literals, variables, `(expr)`, function calls, access
  #
  # Each precedence level is compiled as a separate `defparsec` to keep
  # generated code size small and compilation fast. A plain variable combinator
  # is inlined into every `defparsec` that references it; `parsec(:name)` emits
  # a function call instead, acting as a compilation boundary.
  #
  # ## All operators are left-associative
  #
  # This includes `^` (exponent). Mathematically exponentiation is typically
  # right-associative (`2^3^2 = 2^9 = 512`), but this grammar follows the
  # simpler left-associative model (`2^3^2 = 8^2 = 64`), matching the
  # behaviour of most spreadsheet engines.

  import NimbleParsec

  # ── Whitespace ──────────────────────────────────────────────────
  # Optional horizontal/vertical whitespace, silently consumed.

  whitespace = ignore(optional(ascii_string([?\s, ?\t, ?\n], min: 1)))

  # ── Literals ────────────────────────────────────────────────────

  # String escape sequences: \\, \n, \t, \r, \", \'
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

  # Keywords use lookahead guards so `true_value` parses as an identifier,
  # not as `true` followed by `_value`.
  boolean =
    choice([
      string("true") |> lookahead_not(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_])) |> replace(true),
      string("false")
      |> lookahead_not(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_]))
      |> replace(false)
    ])

  null_literal =
    string("null")
    |> lookahead_not(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_]))
    |> replace(nil)

  int_literal =
    ascii_string([?0..?9], min: 1) |> reduce({__MODULE__, :handle_int, []})

  # Floats: `1.0`, `1.`, `.5`
  float_literal =
    choice([
      ascii_string([?0..?9], min: 1) |> concat(string(".")) |> ascii_string([?0..?9], min: 0),
      string(".") |> ascii_string([?0..?9], min: 1)
    ])
    |> reduce({__MODULE__, :handle_float, []})

  # Identifiers: `foo`, `_bar`, `camelCase`, `with_123`
  identifier =
    ascii_string([?a..?z, ?A..?Z, ?_], 1)
    |> optional(ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 1))
    |> reduce({Enum, :join, []})

  # Variables with optional chained access and function calls:
  #   `user.profile.name`  → nested dot access
  #   `list[0]`            → bracket access (index can be any expression)
  #   `abs(-10)`           → function call
  #   `obj.method(1).val`  → mixed chaining
  variable =
    identifier
    |> repeat(
      choice([
        # Computed spread: .(expr) — must be tried before plain dot access
        ignore(string(".("))
        |> parsec(:expression)
        |> ignore(string(")"))
        |> map({__MODULE__, :make_computed_access, []}),
        ignore(string(".")) |> concat(identifier) |> map({__MODULE__, :make_dot_access, []}),
        ignore(string("[*]")) |> replace({:spread}),
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

  # All literal types, tried in order. Keywords before identifiers so
  # `true` isn't parsed as a variable name.
  literal =
    choice([
      boolean,
      null_literal,
      float_literal,
      int_literal,
      string_literal,
      variable
    ])

  # ── Precedence level 12: Primary ───────────────────────────────
  # Literals, variables, and parenthesized sub-expressions.

  primary =
    choice([
      whitespace |> concat(literal) |> concat(whitespace),
      ignore(string("(")) |> parsec(:expression) |> ignore(string(")")) |> concat(whitespace)
    ])

  # ── Precedence level 11: Unary prefix ──────────────────────────
  # `-x`, `not x`, `~x` — right-recursive via parsec(:unary).

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

  # ── Precedence level 10: Factorial (postfix) ───────────────────
  # `n!` — the `!` must not be followed by `=` to avoid matching `!=`.

  factorial =
    parsec(:unary)
    |> choice([
      string("!") |> lookahead_not(string("=")) |> replace(:factorial),
      empty()
    ])
    |> reduce({__MODULE__, :handle_factorial, []})

  defparsec(:factorial, factorial)

  # ── Precedence level 9: Exponent ───────────────────────────────
  # `a ^ b` — left-associative (see module doc).

  exponent =
    parsec(:factorial)
    |> repeat(
      whitespace
      |> string("^")
      |> replace(:^)
      |> concat(whitespace)
      |> concat(parsec(:factorial))
    )
    |> reduce({__MODULE__, :reduce_ops, []})

  defparsec(:exponent, exponent)

  # ── Precedence level 8: Multiplicative ─────────────────────────
  # `*`, `/`, `%` (modulo is `rem/2` in Elixir).

  multiplicative =
    parsec(:exponent)
    |> repeat(
      choice([
        whitespace |> string("*") |> replace(:*) |> concat(whitespace),
        whitespace |> string("/") |> replace(:/) |> concat(whitespace),
        whitespace |> string("%") |> replace(:%) |> concat(whitespace)
      ])
      |> concat(parsec(:exponent))
    )
    |> reduce({__MODULE__, :reduce_ops, []})

  defparsec(:multiplicative, multiplicative)

  # ── Precedence level 7: Additive ───────────────────────────────
  # `+`, `-` (binary subtraction, not unary negate).

  additive =
    parsec(:multiplicative)
    |> repeat(
      choice([
        whitespace |> string("+") |> replace(:+) |> concat(whitespace),
        whitespace |> string("-") |> replace(:-) |> concat(whitespace)
      ])
      |> concat(parsec(:multiplicative))
    )
    |> reduce({__MODULE__, :reduce_ops, []})

  defparsec(:additive, additive)

  # ── Precedence level 6: Bitshift ───────────────────────────────
  # `<<`, `>>` — must be tried before `<` and `>` in comparison.

  bitshift =
    parsec(:additive)
    |> repeat(
      choice([
        whitespace |> string("<<") |> replace(:bsl) |> concat(whitespace),
        whitespace |> string(">>") |> replace(:bsr) |> concat(whitespace)
      ])
      |> concat(parsec(:additive))
    )
    |> reduce({__MODULE__, :reduce_ops, []})

  defparsec(:bitshift, bitshift)

  # ── Precedence level 5: Comparison ─────────────────────────────
  # `==`, `!=`, `>=`, `<=`, `>`, `<`
  # Multi-char operators (`>=`, `<=`) are tried before single-char
  # (`>`, `<`) to avoid partial matches.

  comparison =
    parsec(:bitshift)
    |> repeat(
      choice([
        whitespace |> string("==") |> replace(:==) |> concat(whitespace),
        whitespace |> string("!=") |> replace(:!=) |> concat(whitespace),
        whitespace |> string(">=") |> replace(:>=) |> concat(whitespace),
        whitespace |> string("<=") |> replace(:<=) |> concat(whitespace),
        whitespace |> string(">") |> replace(:>) |> concat(whitespace),
        whitespace |> string("<") |> replace(:<) |> concat(whitespace)
      ])
      |> concat(parsec(:bitshift))
    )
    |> reduce({__MODULE__, :reduce_ops, []})

  defparsec(:comparison, comparison)

  # ── Precedence level 4: Bitwise ────────────────────────────────
  # `&` (AND), `|` (OR), `|^` (XOR)
  # `|^` is tried before `|` to avoid partial match.

  bitwise =
    parsec(:comparison)
    |> repeat(
      choice([
        whitespace |> string("&") |> replace(:band) |> concat(whitespace),
        whitespace |> string("|^") |> replace(:bxor) |> concat(whitespace),
        whitespace |> string("|") |> replace(:bor) |> concat(whitespace)
      ])
      |> concat(parsec(:comparison))
    )
    |> reduce({__MODULE__, :reduce_ops, []})

  defparsec(:bitwise, bitwise)

  # ── Precedence level 3: Logical AND ────────────────────────────
  # `&&` binds tighter than `||` so `true || false && false` is
  # parsed as `true || (false && false)`.

  logical_and =
    parsec(:bitwise)
    |> repeat(
      whitespace
      |> string("&&")
      |> replace(:and)
      |> concat(whitespace)
      |> concat(parsec(:bitwise))
    )
    |> reduce({__MODULE__, :reduce_ops, []})

  defparsec(:logical_and, logical_and)

  # ── Precedence level 2: Logical OR ─────────────────────────────
  # `||` — lowest-precedence binary operator before ternary.

  logical_or =
    parsec(:logical_and)
    |> repeat(
      whitespace
      |> string("||")
      |> replace(:or)
      |> concat(whitespace)
      |> concat(parsec(:logical_and))
    )
    |> reduce({__MODULE__, :reduce_ops, []})

  defparsec(:logical_or, logical_or)

  # ── Precedence level 1: Ternary ────────────────────────────────
  # `cond ? true_val : false_val`
  # The branches are full expressions, so ternaries can nest:
  #   `a ? b ? c : d : e` is `a ? (b ? c : d) : e`

  ternary =
    parsec(:logical_or)
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

  # Top-level entry point. Every expression starts here.
  defparsec(:expression, ternary)

  # ── Reducer / helper functions ─────────────────────────────────

  def handle_int([val]), do: String.to_integer(val)

  def handle_float([left, ".", ""]), do: String.to_float("#{left}.0")
  def handle_float([left, ".", right]), do: String.to_float("#{left}.#{right}")
  def handle_float([".", right]), do: String.to_float("0.#{right}")

  def handle_string_collect(chars) do
    Enum.map_join(chars, "", fn
      c when is_integer(c) -> <<c::utf8>>
      c -> c
    end)
  end

  def make_dot_access(key), do: {:dot, key}
  def make_bracket_access(index), do: {:bracket, index}
  def make_computed_access(expr), do: {:computed, expr}
  def make_call_access([]), do: {:call, []}
  def make_call_access(args), do: {:call, args}

  def build_access([name | accessors]) do
    initial = {:get_var, name}
    build_access_chain(initial, accessors)
  end

  # Builds the IR for an access chain, handling [*] spread markers.
  # Before a spread, accessors produce normal :access/:call nodes.
  # At a spread, we switch to collecting the remaining chain into a :spread node.
  defp build_access_chain(acc, []), do: acc

  defp build_access_chain(acc, [{:spread} | rest]) do
    build_spread_chain(acc, rest)
  end

  defp build_access_chain(acc, [head | rest]) do
    next =
      case head do
        {:dot, key} -> {:access, acc, key}
        {:bracket, index} -> {:access, acc, index}
        {:call, args} -> {:call, acc, args}
      end

    build_access_chain(next, rest)
  end

  # After encountering [*], subsequent accessors are collected as a path
  # to be mapped over. A nested [*] produces a :flat_spread node so
  # results are flattened across levels.
  # A computed accessor .(expr) produces a :computed_spread node.
  defp build_spread_chain(target, accessors, flat? \\ false) do
    {spread, remaining} = build_spread_node(target, accessors, flat?)
    continue_after_spread(spread, remaining)
  end

  # Computed spread: .(expr) — evaluates an expression per element
  defp build_spread_node(target, [{:computed, expr} | rest], flat?) do
    node =
      if flat?, do: {:flat_computed_spread, target, expr}, else: {:computed_spread, target, expr}

    {node, rest}
  end

  # Path spread: .field.subfield — maps a dotted path over each element
  defp build_spread_node(target, accessors, flat?) do
    {path, remaining} = collect_spread_path(accessors, [])
    node = if flat?, do: {:flat_spread, target, path}, else: {:spread, target, path}
    {node, remaining}
  end

  # After building a spread node, decide how to continue the chain
  defp continue_after_spread(spread, []), do: spread

  defp continue_after_spread(spread, [{:spread} | rest]),
    do: build_spread_chain(spread, rest, true)

  defp continue_after_spread(spread, remaining), do: build_access_chain(spread, remaining)

  defp collect_spread_path([], acc), do: {Enum.reverse(acc), []}
  defp collect_spread_path([{:spread} | rest], acc), do: {Enum.reverse(acc), [{:spread} | rest]}
  defp collect_spread_path([{:call, _} | _] = rest, acc), do: {Enum.reverse(acc), rest}
  defp collect_spread_path([{:computed, _} | _] = rest, acc), do: {Enum.reverse(acc), rest}

  defp collect_spread_path([{:dot, key} | rest], acc),
    do: collect_spread_path(rest, [{:key, key} | acc])

  defp collect_spread_path([{:bracket, index} | rest], acc),
    do: collect_spread_path(rest, [{:index, index} | acc])

  def make_unary([op, operand]), do: {op, [], [operand]}

  def handle_factorial([val, :factorial]), do: {:factorial, [], [val]}
  def handle_factorial([val]), do: val

  def handle_ternary([cond_val, :question, true_val, :colon, false_val]),
    do: {:ternary, [], [cond_val, true_val, false_val]}

  def handle_ternary([val]), do: val

  # Left-folds a flat list of [left, op, right, op, right, ...] into
  # nested `{op, [], [left, right]}` tuples. Also maps internal operator
  # atoms to their Elixir equivalents (e.g. :bsl → :<<<).
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

  # ── Public API ─────────────────────────────────────────────────

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

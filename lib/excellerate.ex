defmodule ExCellerate do
  @moduledoc """
  ExCellerate is a high-performance expression evaluation engine for Elixir.

  It parses text expressions into an intermediate representation (IR) and then
  compiles them into native Elixir AST for near-native performance.

  ## Features

  - Arithmetic operators: `+`, `-`, `*`, `/`, `^`, `%`
  - Comparison operators: `==`, `!=`, `<`, `<=`, `>`, `>=`
  - Logical operators: `&&`, `||`, `!` (not)
  - Bitwise operators: `&&&`, `|||`, `^^^`, `<<<`, `>>>`, `~~~` (bnot)
  - Ternary operator: `condition ? true_val : false_val`
  - Factorial: `n!`
  - Nested data access: `user.profile.name` or `list.0`
  - Custom functions via a Registry system.

  ## Examples

      iex> ExCellerate.eval("1 + 2 * 3")
      7

      iex> ExCellerate.eval("a + b", %{"a" => 10, "b" => 20})
      30

      iex> ExCellerate.eval("user.name", %{"user" => %{"name" => "Alice"}})
      "Alice"
  """

  alias ExCellerate.Parser
  alias ExCellerate.Compiler

  @type scope :: %{optional(String.t()) => any()}
  @type registry :: module() | nil
  @type eval_result :: any() | {:error, any()}

  @doc """
  Evaluates a text expression against an optional scope and registry.

  ## Parameters

  - `expression`: A string containing the ExCellerate expression.
  - `scope`: A map of variables available to the expression. Defaults to `%Requested{}`.
  - `registry`: An optional module that implements the ExCellerate.Registry behaviour.

  ## Returns

  - The result of the evaluation.
  - `{:error, reason}` if parsing or evaluation fails.
  """
  @spec eval(String.t(), scope(), registry()) :: eval_result()
  def eval(expression, scope \\ %{}, registry \\ nil) do
    case Parser.parse(expression) do
      {:ok, ast} ->
        try do
          elixir_ast = Compiler.compile(ast, registry)
          {result, _} = Code.eval_quoted(elixir_ast, [scope: scope], __ENV__)
          result
        rescue
          e ->
            if is_map(e) and Map.get(e, :message) == "not_found" do
              {:error, :not_found}
            else
              {:error, e}
            end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end

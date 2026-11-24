defmodule ExCellerate.ParserPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import ExCellerate.Test.Bounded

  alias ExCellerate.Parser

  # Arbitrary token soup is mostly invalid, which is the point: the parser must
  # reject anything promptly and never raise, however the tokens are nested.
  # Tokens include `not` and look-alike identifiers, since keyword/identifier
  # overlap is where backtracking blow-ups have come from.
  @tokens [
    "not",
    "notable",
    "not_x",
    "true",
    "null",
    "a",
    "abs",
    "1",
    "2.5",
    "'s'",
    "(",
    ")",
    "[",
    "]",
    "[*]",
    ".",
    ".(",
    ",",
    "?",
    ":",
    "+",
    "-",
    "*",
    "/",
    "^",
    "!",
    "~",
    "&&",
    "||",
    "==",
    "<",
    "<<",
    "&",
    "|"
  ]

  defp token_soup do
    @tokens
    |> StreamData.member_of()
    |> StreamData.list_of(max_length: 60)
    |> StreamData.bind(fn tokens ->
      StreamData.map(StreamData.member_of(["", " "]), &Enum.join(tokens, &1))
    end)
  end

  defp nested_unclosed do
    gen all(
          prefix <- StreamData.member_of(["not(", "not (", "-(", "(", "abs(", "-not(", "not -("]),
          depth <- StreamData.integer(20..40)
        ) do
      String.duplicate(prefix, depth) <> "1"
    end
  end

  property "parse/1 returns ok/error promptly for arbitrary token sequences" do
    check all(input <- token_soup()) do
      assert {tag, _} = within(500, fn -> Parser.parse(input) end)
      assert tag in [:ok, :error]
    end
  end

  property "parse/1 rejects deeply nested unclosed input promptly" do
    check all(input <- nested_unclosed(), max_runs: 50) do
      assert {:error, %ExCellerate.Error{type: :parser}} =
               within(500, fn -> Parser.parse(input) end)
    end
  end
end

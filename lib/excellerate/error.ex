defmodule ExCellerate.Error do
  @moduledoc """
  Represents an error in the ExCellerate system.
  """
  defexception [:message, :type, :line, :column, :details]

  @type t :: %__MODULE__{
          message: String.t(),
          type: :parser | :compiler | :runtime,
          line: integer() | nil,
          column: integer() | nil,
          details: any()
        }

  @impl true
  def exception(opts) do
    %__MODULE__{
      message: Keyword.get(opts, :message, "Unknown error"),
      type: Keyword.get(opts, :type, :runtime),
      line: Keyword.get(opts, :line),
      column: Keyword.get(opts, :column),
      details: Keyword.get(opts, :details)
    }
  end

  @impl true
  def message(%__MODULE__{} = e) do
    prefix =
      case e.type do
        :parser -> "Parse error"
        :compiler -> "Compilation error"
        :runtime -> "Runtime error"
      end

    location =
      if e.line && e.column do
        " at line #{e.line}, column #{e.column}"
      else
        ""
      end

    "#{prefix}#{location}: #{e.message}"
  end
end

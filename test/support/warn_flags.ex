defmodule ExCellerate.Test.WarnFlags do
  @moduledoc false
  # Some warnings are logged once per VM, guarded by a :persistent_term flag.
  # A test that asserts such a warning must clear the flag first, or it passes
  # or fails depending on whether an earlier test already triggered it.

  @flags [:excellerate_cache_warned, :excellerate_native_exit_warned]

  def reset(flag) when flag in @flags do
    :persistent_term.erase(flag)
    :ok
  end
end

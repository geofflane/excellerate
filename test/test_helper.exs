# Starts the global ExCellerate.Cache singleton consumed by the public
# ExCellerate.compile/2. INVARIANT: any test that starts the global
# ExCellerate.NativeCompiler, or stops/restarts this global Cache, MUST be
# `async: false` — these are globally-named singletons, so running such tests
# concurrently with async tests causes races over the shared registered names.
ExCellerate.Cache.start_link()
ExUnit.start()

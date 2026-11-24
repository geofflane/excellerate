defmodule ExCellerate.Cache do
  @moduledoc """
  ETS-backed LRU cache for compiled expression functions.

  Each entry stores `{full_key, value, last_accessed, mod_name}` where
  `mod_name` is the native BEAM module backing the entry (an atom) or `nil`
  for interpreted entries. When a registry exceeds its `cache_limit`, the
  least recently used entries are evicted.

  Recency is tracked per insert rather than per hit: a hit marks an entry as
  used since the most recent insert, and writes only if it was not already
  marked. Hot entries therefore cost a read, not a write, on every hit.
  Eviction happens only on insert, so this ordering is all it needs; entries
  read between the same two inserts count as equally recent.

  The cache must be started as part of your application's supervision tree
  for caching to work. If it is not started, expressions will be parsed and
  compiled on every call.

  ## Setup

  Add `ExCellerate.Cache` to your supervision tree:

      children = [
        ExCellerate.Cache,
        # ...
      ]

      Supervisor.start_link(children, strategy: :one_for_one)
  """
  use GenServer

  @table_name :excellerate_cache
  # Per-registry entry counts ({:count, registry}) and the recency epoch
  # (:epoch), kept apart from the entries so their match patterns never see them.
  @counts_table :excellerate_cache_counts
  @default_limit 1000
  @warn_flag :excellerate_cache_warned

  # Position of the last_accessed timestamp in the ETS tuple.
  # Tuple layout: {full_key, value, last_accessed, mod_name}
  @ts_pos 3

  @doc false
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc false
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  @doc false
  def get(registry, key) do
    if enabled?(registry) and table_exists?() do
      full_key = {registry, key}

      case :ets.lookup(@table_name, full_key) do
        [{_, value, ts, _mod}] ->
          touch(full_key, ts)
          {:ok, value}

        [] ->
          :error
      end
    else
      :error
    end
  end

  @doc false
  def put(registry, key, value, mod_name \\ nil) do
    if enabled?(registry) do
      if table_exists?() do
        insert({registry, key}, value, mod_name)
      else
        maybe_warn_not_started()
      end
    end
  end

  @doc false
  # Drops every entry, releasing the native module behind each one (as LRU
  # eviction does) so its pool slot can be reused. Entries are taken one at a
  # time so an entry inserted concurrently is either released here or survives.
  def clear do
    if table_exists?() do
      @table_name
      |> :ets.select([{{:"$1", :_, :_, :_}, [], [:"$1"]}])
      |> Enum.each(&take_and_release/1)
    end

    :ok
  end

  @doc false
  # Removes the entry for `expr` only if it is still bound to `stale_mod`, the
  # module a stale native fun was compiled into. Stale-fun recovery calls this
  # before recompiling, so it can't get the same stale fun back from the cache.
  # The module isn't released: its slot was already released, or it belongs to
  # a NativeCompiler that has since restarted.
  def delete_stale(registry, expr, stale_mod) do
    if table_exists?() do
      deleted =
        :ets.select_delete(@table_name, [{{{registry, expr}, :_, :_, stale_mod}, [], [true]}])

      if deleted > 0, do: decrement_count(registry, deleted)
    end

    :ok
  end

  @doc false
  # Drops every entry backed by a native module, without releasing them.
  # NativeCompiler runs this when it (re)starts: the modules belong to the
  # previous server, whose pool state is gone.
  def drop_native_entries do
    if table_exists?() do
      @table_name
      |> :ets.select([{{:"$1", :_, :_, :"$2"}, [{:"=/=", :"$2", nil}], [:"$1"]}])
      |> Enum.each(&take/1)
    end

    :ok
  end

  # Removes `key` if it is still present and releases its native module (a safe
  # no-op cast when NativeCompiler isn't running). Returns whether this call
  # removed it, so concurrent evictions of the same entry count it once.
  defp take_and_release(key) do
    case take(key) do
      {registry, expr, mod} ->
        if mod != nil, do: ExCellerate.NativeCompiler.release(registry, expr)
        true

      nil ->
        false
    end
  end

  # Removes `key` if it is still present, keeping the registry's count in step.
  defp take(key) do
    case :ets.take(@table_name, key) do
      [{{registry, expr}, _value, _ts, mod}] ->
        decrement_count(registry, 1)
        {registry, expr, mod}

      [] ->
        nil
    end
  end

  defp decrement_count(registry, n) do
    :ets.update_counter(@counts_table, {:count, registry}, -n, {{:count, registry}, 0})
  end

  # -- GenServer callbacks --

  @impl true
  def init(_opts) do
    :ets.new(@table_name, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    :ets.new(@counts_table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    :ets.insert(@counts_table, {:epoch, 0})
    {:ok, nil}
  end

  # -- Private helpers --

  # Recency stamps. Each insert advances the epoch by 2 and stamps the new entry
  # epoch - 1; a hit stamps an entry with the current epoch. So an entry read
  # after an insert ranks above it, and one read before an insert ranks below
  # it, which is the order LRU eviction needs.
  defp current_epoch, do: :ets.lookup_element(@counts_table, :epoch, 2)

  defp next_insert_stamp, do: :ets.update_counter(@counts_table, :epoch, 2) - 1

  defp touch(full_key, ts) do
    epoch = current_epoch()
    if ts < epoch, do: :ets.update_element(@table_name, full_key, {@ts_pos, epoch})
    :ok
  end

  # Inserts a new entry, or replaces the value of an existing one. Only a new
  # entry is counted. If the existing entry is evicted between the failed
  # insert_new and update_element, retry as a new insert.
  defp insert({registry, _expr} = full_key, value, mod_name) do
    stamp = next_insert_stamp()

    cond do
      :ets.insert_new(@table_name, {full_key, value, stamp, mod_name}) ->
        count = :ets.update_counter(@counts_table, {:count, registry}, 1, {{:count, registry}, 0})
        maybe_evict(registry, count, get_limit(registry))

      :ets.update_element(@table_name, full_key, [{2, value}, {@ts_pos, stamp}, {4, mod_name}]) ->
        :ok

      true ->
        insert(full_key, value, mod_name)
    end
  end

  defp table_exists? do
    :ets.whereis(@table_name) != :undefined
  end

  defp maybe_warn_not_started do
    unless :persistent_term.get(@warn_flag, false) do
      :persistent_term.put(@warn_flag, true)

      require Logger

      Logger.warning(
        "ExCellerate caching is enabled but ExCellerate.Cache is not started. " <>
          "Expressions will be re-compiled on every call. " <>
          "Add ExCellerate.Cache to your supervision tree to enable caching."
      )
    end
  end

  defp maybe_evict(_registry, count, limit) when count <= limit, do: :ok

  defp maybe_evict(registry, count, limit) do
    overage = count - limit
    evict_lru(registry, overage)
  end

  # Finds the `count` entries with the smallest last_accessed timestamps
  # for the given registry and deletes them.
  defp evict_lru(registry, count) do
    # Collect [expression, last_accessed] for this registry's entries.
    @table_name
    |> :ets.match({{registry, :"$1"}, :_, :"$2", :_})
    |> Enum.sort_by(fn [_expr, ts] -> ts end)
    |> Enum.take(count)
    |> Enum.each(fn [expr, _ts] -> take_and_release({registry, expr}) end)
  end

  defp enabled?(nil) do
    Application.get_env(:excellerate, :cache_enabled, true)
  end

  defp enabled?(registry) do
    if Code.ensure_loaded?(registry) and
         function_exported?(registry, :__excellerate_config__, 1) do
      registry.__excellerate_config__(:cache_enabled)
    else
      Application.get_env(:excellerate, :cache_enabled, true)
    end
  end

  defp get_limit(nil) do
    Application.get_env(:excellerate, :cache_limit, @default_limit)
  end

  defp get_limit(registry) do
    if Code.ensure_loaded?(registry) and
         function_exported?(registry, :__excellerate_config__, 1) do
      registry.__excellerate_config__(:cache_limit)
    else
      Application.get_env(:excellerate, :cache_limit, @default_limit)
    end
  end
end

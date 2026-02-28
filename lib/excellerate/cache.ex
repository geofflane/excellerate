defmodule ExCellerate.Cache do
  @moduledoc """
  ETS-backed LRU cache for compiled expression functions.

  Each entry stores `{full_key, value, last_accessed}` where `last_accessed`
  is a monotonically increasing integer from `:erlang.unique_integer([:monotonic])`.
  The timestamp is updated on every `get` hit via `:ets.update_element/3`,
  so eviction always removes the least recently used entry.

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
  @default_limit 1000
  @warn_flag :excellerate_cache_warned

  # Position of the last_accessed timestamp in the ETS tuple.
  # Tuple layout: {full_key, value, last_accessed}
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
        [{_, value, _ts}] ->
          # Touch: update last_accessed timestamp to mark as recently used.
          :ets.update_element(@table_name, full_key, {@ts_pos, now()})
          {:ok, value}

        [] ->
          :error
      end
    else
      :error
    end
  end

  @doc false
  def put(registry, key, value) do
    if enabled?(registry) do
      if table_exists?() do
        full_key = {registry, key}
        :ets.insert(@table_name, {full_key, value, now()})

        limit = get_limit(registry)
        count = count_for_registry(registry)
        maybe_evict(registry, count, limit)
      else
        maybe_warn_not_started()
      end
    end
  end

  @doc false
  def clear do
    if table_exists?() do
      :ets.delete_all_objects(@table_name)
    end
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

    {:ok, nil}
  end

  # -- Private helpers --

  defp now, do: :erlang.unique_integer([:monotonic])

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

  defp count_for_registry(registry) do
    :ets.select_count(@table_name, [{{{registry, :_}, :_, :_}, [], [true]}])
  end

  defp maybe_evict(_registry, count, limit) when count <= limit, do: :ok

  defp maybe_evict(registry, count, limit) do
    overage = count - limit
    evict_lru(registry, overage)
  end

  # Finds the `count` entries with the smallest last_accessed timestamps
  # for the given registry and deletes them.
  defp evict_lru(registry, count) do
    # Collect {expression, timestamp} for all entries belonging to this registry.
    entries = :ets.match(@table_name, {{registry, :"$1"}, :_, :"$2"})

    entries
    |> Enum.sort_by(fn [_expr, ts] -> ts end)
    |> Enum.take(count)
    |> Enum.each(fn [expr, _ts] -> :ets.delete(@table_name, {registry, expr}) end)
  end

  defp enabled?(nil) do
    Application.get_env(:excellerate, :cache_enabled, true)
  end

  defp enabled?(registry) do
    if function_exported?(registry, :__excellerate_config__, 1) do
      registry.__excellerate_config__(:cache_enabled)
    else
      Application.get_env(:excellerate, :cache_enabled, true)
    end
  end

  defp get_limit(nil) do
    Application.get_env(:excellerate, :cache_limit, @default_limit)
  end

  defp get_limit(registry) do
    if function_exported?(registry, :__excellerate_config__, 1) do
      registry.__excellerate_config__(:cache_limit)
    else
      Application.get_env(:excellerate, :cache_limit, @default_limit)
    end
  end
end

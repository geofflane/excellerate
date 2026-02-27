defmodule ExCellerate.Cache do
  @moduledoc """
  ETS-backed cache for compiled expression ASTs.

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
      case :ets.lookup(@table_name, {registry, key}) do
        [{_, value}] -> {:ok, value}
        [] -> :error
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
        :ets.insert(@table_name, {full_key, value})

        limit = get_limit(registry)
        count = count_for_registry(registry)
        maybe_evict_for_registry(registry, count, limit)
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

  defp maybe_evict_for_registry(_registry, count, limit) when count <= limit, do: :ok

  defp maybe_evict_for_registry(registry, _count, limit) do
    evict_for_registry(registry)
    new_count = count_for_registry(registry)
    maybe_evict_for_registry(registry, new_count, limit)
  end

  defp count_for_registry(registry) do
    :ets.select_count(@table_name, [{{{registry, :_}, :_}, [], [true]}])
  end

  defp evict_for_registry(registry) do
    case :ets.match(@table_name, {{registry, :"$1"}, :_}, 1) do
      {[[key]], _} -> :ets.delete(@table_name, {registry, key})
      _ -> :ok
    end
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

defmodule ExCellerate.Cache do
  @moduledoc false
  use GenServer

  @table_name :excellerate_cache
  @default_limit 1000

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get(registry, key) do
    if enabled?(registry) do
      case :ets.lookup(@table_name, {registry, key}) do
        [{_, value}] -> {:ok, value}
        [] -> :error
      end
    else
      :error
    end
  end

  def put(registry, key, value) do
    if enabled?(registry) do
      GenServer.call(__MODULE__, {:put, registry, key, value})
    end
  end

  def clear do
    :ets.delete_all_objects(@table_name)
  end

  @impl true
  def init(_) do
    :ets.new(@table_name, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    {:ok, nil}
  end

  @impl true
  def handle_call({:put, registry, key, value}, _from, state) do
    full_key = {registry, key}
    :ets.insert(@table_name, {full_key, value})

    limit = get_limit(registry)
    count = count_for_registry(registry)

    maybe_evict_for_registry(registry, count, limit)

    {:reply, :ok, state}
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

# Copyright (c) 2021      Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.UserCache do
  use GenServer
  require Logger

  @moduledoc """
  This module stores active sessions.
  """

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    :timer.send_interval(cleanup_time() |> :timer.minutes(), self(), :cleanup)
    {:ok, %{}}
  end

  @doc """
  Register cert (more precisely its hash) with session cache.
  """
  @spec register(binary()) :: {:ok, binary(), map()}
  def register(cert), do: GenServer.call(__MODULE__, {:register, cert})

  @doc """
  Remove cert from cache.
  """
  @spec unregister(binary()) :: :ok
  def unregister(cert), do: GenServer.call(__MODULE__, {:unregister, cert})

  @doc """
  Put metadata into session cache.
  """
  @spec put_metadata(binary(), atom(), any()) :: {:ok, map()}
  def put_metadata(cert, k, v), do: GenServer.call(__MODULE__, {:put_metadata, cert, k, v})

  @impl true
  def handle_call({:register, cert}, _from, map) do
    hash = Gemini.cert_hash(cert)

    if Map.has_key?(map, hash) do
      meta = elem(Map.get(map, hash), 1)
      {:reply, {:ok, hash, meta}, Map.put(map, hash, {DateTime.utc_now(), meta})}
    else
      Logger.info("user cache registered #{hash |> Gemini.readable_hash()}")
      {:reply, {:ok, hash, %{}}, Map.put(map, hash, {DateTime.utc_now(), %{}})}
    end
  end

  @spec handle_call({:put_metadata, binary(), atom(), any()}, any(), map()) ::
          {:reply, {:ok, map()}, map()}
  def handle_call({:put_metadata, hash, k, v}, _from, map) do
    meta = elem(Map.get(map, hash, {nil, %{}}), 1)
    nmeta = Map.put(meta, k, v)
    {:reply, {:ok, nmeta}, Map.put(map, hash, {DateTime.utc_now(), nmeta})}
  end

  @spec handle_call({:unregister, binary()}, any(), map()) :: {:reply, :ok, map()}
  def handle_call({:unregister, cert}, _from, map) do
    hash = Gemini.cert_hash(cert)
    Logger.info("user cache unregistered #{hash |> Gemini.readable_hash()}")
    {:reply, :ok, Map.delete(map, hash)}
  end

  @impl true
  def handle_info(:cleanup, map) do
    x = map_size(map)

    nmap =
      map
      |> Map.to_list()
      |> Enum.filter(fn {_, {x, _}} ->
        DateTime.diff(DateTime.utc_now(), x, :second) < cleanup_time() * 60
      end)
      |> Map.new()

    Logger.info("user cache cleaned #{x - map_size(nmap)} entries")
    {:noreply, nmap}
  end

  defp cleanup_time do
    Application.fetch_env!(:gemini, :user_cache_cleanup_time)
  end
end

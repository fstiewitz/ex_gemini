# Copyright (c) 2021-2022 Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.Site.File do
  use Gemini.Site, check_path: true
  require Logger

  @moduledoc """
    This module returns file contents as a gemini response.
  """

  @doc """
  Start site.

  * `name` name of the server.
  * `path` Path prefix.

  `args` is a list with three arguments:

  * a file path
  * meta type of the file contents
  * a cache value

  A cache value of `:disabled` disables the cache and the file will be loaded from disk on every access.
  A value of `:infinity` permanently caches the value in memory.
  A positive number of minutes clears the value from the cache if nobody accessed it in a fixed amount of minutes.
  """
  @impl Gemini.Site
  def start_link([name, path, args]) do
    GenServer.start_link(__MODULE__, [path, args], name: name)
  end

  @type cache_spec() :: :disabled | :infinity | pos_integer()

  @impl true
  def init([path, [file, meta, cache]]) when is_number(cache) do
    :timer.send_interval(:timer.minutes(cache), self(), :clean)
    {:ok, {nil, path, file, meta, cache}}
  end

  def init([path, [file, meta, cache]]) do
    {:ok, {nil, path, file, meta, cache}}
  end

  @impl true
  def path({_, path, _, _, _}), do: path

  @impl true
  def forward_request(_req, {nil, path, file, meta, :disabled}) do
    case File.read(file) do
      {:ok, data} ->
        response = make_response(:success, meta, data, [])
        {:reply, {:ok, response}, {nil, path, file, meta, :disabled}}

      {:error, x} ->
        Logger.error("could not read file #{file}: #{inspect(x)}")

        {:reply, {:ok, make_response(:temporary_failure, "Internal Error", nil, [])},
         {nil, path, file, meta, :disabled}}
    end
  end

  def forward_request(_req, {nil, path, file, meta, cache}) do
    case File.read(file) do
      {:ok, data} ->
        response = make_response(:success, meta, data, [])
        {:reply, {:ok, response}, {{data, DateTime.utc_now()}, path, file, meta, cache}}

      {:error, x} ->
        Logger.error("could not read file #{file}: #{inspect(x)}")

        {:reply, {:ok, make_response(:temporary_failure, "Internal Error", nil, [])},
         {nil, path, file, meta, cache}}
    end
  end

  def forward_request(_req, {{data, _ts}, path, file, meta, cache}) do
    response = make_response(:success, meta, data, [])
    {:reply, {:ok, response}, {{data, DateTime.utc_now()}, path, file, meta, cache}}
  end

  @impl true
  def handle_info(:clean, {{data, ts}, path, file, meta, cache}) do
    if DateTime.diff(DateTime.utc_now(), ts) / 60 > cache do
      {:noreply, {nil, file, meta, cache}}
    else
      {:noreply, {{data, ts}, path, file, meta, cache}}
    end
  end
end

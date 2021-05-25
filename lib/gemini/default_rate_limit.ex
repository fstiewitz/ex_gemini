# Copyright (c) 2021      Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.DefaultRateLimit do
  use GenServer
  require Logger
  @behaviour Gemini.RateLimit

  @moduledoc """
  This module keeps track of IP addresses for rate-limiting.

  To configure rate-limiting, use the following config keys:

  - periodic cleanup after `:rate_limit_max_age` minutes.
  - allow `:rate_limit_max_calls` within `:rate_limit_bracket_duration` minutes or get rate-limited.
  - `:rate_limit_penalty` *seconds* of rate-limiting.
  """

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    :timer.send_interval(max_age() |> :timer.minutes(), self(), :cleanup)
    {:ok, %{}}
  end

  @impl true
  def is_rate_limited(addr), do: GenServer.call(__MODULE__, {:is_rate_limited, addr})

  @impl true
  def handle_call({:is_rate_limited, addr}, _from, map) do
    now = DateTime.utc_now()
    {status, bracket_start, num} = Map.get(map, addr, {:good, now, 0})

    penalty = penalty()

    cond do
      status == :limited and DateTime.diff(now, bracket_start, :second) > penalty ->
        Logger.info("rate limit: release for #{:inet.ntoa(addr)}")
        {:reply, :not_limited, Map.put(map, addr, {:good, now, 1})}

      status == :limited ->
        {:reply, {:limited, penalty}, Map.put(map, addr, {:limited, now, 0})}

      num + 1 > max_calls() ->
        Logger.info("rate limit: limit for #{:inet.ntoa(addr)}")
        {:reply, {:limited, penalty}, Map.put(map, addr, {:limited, now, 0})}

      DateTime.diff(now, bracket_start, :second) > bracket_duration() * 60 ->
        {:reply, :not_limited, Map.put(map, addr, {:good, now, 1})}

      true ->
        {:reply, :not_limited, Map.put(map, addr, {:good, bracket_start, num + 1})}
    end
  end

  @impl true
  def handle_info(:cleanup, map) do
    x = map_size(map)

    nmap =
      map
      |> Map.to_list()
      |> Enum.filter(fn {_, {_s, x, _}} ->
        DateTime.diff(DateTime.utc_now(), x, :second) < max_age() * 60
      end)
      |> Map.new()

    Logger.info("rate limit cache cleaned #{x - map_size(nmap)} entries")
    {:noreply, nmap}
  end

  defp max_age do
    Application.fetch_env!(:gemini, :rate_limit_max_age)
  end

  defp bracket_duration do
    Application.fetch_env!(:gemini, :rate_limit_bracket_duration)
  end

  defp max_calls do
    Application.fetch_env!(:gemini, :rate_limit_max_calls)
  end

  defp penalty do
    Application.fetch_env!(:gemini, :rate_limit_penalty)
  end
end

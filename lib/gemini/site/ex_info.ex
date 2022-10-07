# Copyright (c) 2021-2022 Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.Site.ExInfo do
  use Gemini.Site, check_path: true

  @moduledoc """
  This module prints information about the running elixir/erlang system as a `text/gemini` response.
  You probably only want this during development/testing.
  """

  @prefix """
  # Status Page
  This status page prints information about the running elixir/erlang system.
  Much like `phpinfo()` and other verbose info tools you probably don't want to run this in a production setting.\n
  """

  @impl Gemini.Site
  def start_link([name, path, args]) do
    GenServer.start_link(__MODULE__, [path, args], name: name)
  end

  @impl true
  def init([path, _args]) do
    cnt = collect_information()
    {:ok, {@prefix <> cnt, path}}
  end

  @impl true
  def path({_, path}), do: path

  @impl true
  def forward_request(_req, {data, path}) do
    response = make_response(:success, "text/gemini", data, [])
    {:reply, {:ok, response}, {data, path}}
  end

  defp collect_information() do
    [
      :build_type,
      :c_compiler_used,
      :check_io,
      :compat_rel,
      :debug_compiled,
      :driver_version,
      :dynamic_trace,
      :dynamic_trace_probes,
      :kernel_poll,
      :machine,
      :modified_timing_level,
      :nif_version,
      :otp_release,
      :port_parallelism,
      :system_architecture,
      :system_logger,
      :system_version,
      :trace_control_word,
      :version,
      :wordsize,
      {:wordsize, :external}
    ]
    |> Enum.map(fn x -> {x, :erlang.system_info(x)} end)
    |> Enum.map(fn {x, y} -> "* #{inspect(x)}: #{inspect(y)}\n" end)
    |> Enum.reduce(&Kernel.<>(&1, &2))
  end
end

# Copyright (c) 2021      Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.Site.Directory do
  use Gemini.Site, check_path: false
  require Logger

  @moduledoc """
    This module serves everything in a directory.
  """

  @doc """
  Start site.

  * `name` name of the server.
  * `path` Path prefix.
  * `args` Arguments.

  `args` is a list with two arguments:

  * a directory path
  * meta type associations by file suffix (map extension to meta type)

  Files that cannot be matched in `meta` are served as `application/octet-stream`.
  """
  @impl Gemini.Site
  def start_link([name, path, args]) do
    GenServer.start_link(__MODULE__, [path, args], name: name)
  end

  @type cache_spec() :: :disabled | :infinity | pos_integer()

  @impl true
  def init([path, [dir, meta]]) do
    {:ok, {path, dir |> Path.expand(), meta}}
  end

  @impl true
  def path({path, _, _}), do: path

  @impl true
  def forward_request(%Gemini.Request{url: %URI{path: nil}}, state) do
    {:reply, {:error, :notfound}, state}
  end

  def forward_request(%Gemini.Request{url: %URI{path: p}}, {path, dir, meta} = state) do
    {:reply, read_dir(dir, meta, p, path), state}
  end

  @spec read_dir(binary(), %{binary() => binary() | {atom(), any()}}, binary(), binary()) ::
          {:ok, Gemini.Response.t()} | {:error, :notfound}
  def read_dir(base, meta, "/" <> p, path), do: read_dir(base, meta, p, path)

  def read_dir(base, meta, p, path) do
    p = Path.relative_to("/" <> p, path)
    exp = Path.expand(p, base)

    if String.starts_with?(exp, base) do
      case File.read(exp) do
        {:ok, r} -> {:ok, make_response(:success, find_meta(meta, p), r, [])}
        {:error, _x} -> {:error, :notfound}
      end
    else
      {:error, :notfound}
    end
  end

  defp find_meta(meta, p) do
    {_k, v} =
      meta
      |> Map.to_list()
      |> Enum.find({'', "application/octet-stream"}, fn {k, _v} -> String.ends_with?(p, k) end)

    v
  end
end

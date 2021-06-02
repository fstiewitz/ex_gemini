# Copyright (c) 2021      Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.Site.Directory do
  use Gemini.Site, check_path: false
  require Logger

  @moduledoc """
    This module serves everything in a directory.
  """

  @type meta_spec :: binary() | {atom(), any()}
  @type meta :: %{binary() => meta_spec()} | meta_spec() | (binary() -> meta_spec() | {binary(), meta_spec()})

  @doc """
  Start site.

  * `name` name of the server.
  * `path` Path prefix.
  * `args` Arguments.

  `args` is a list with two arguments:

  * a directory path
  * meta type associations

  `meta` can be:
  * A meta string (all files will be served with this meta type)
  * A map of `suffix => meta` (filename will be checked against these suffixes, `application/octet-stream` as fallback)
  * A function `fn filename -> ... end` which, given a file path, returns either a meta type or a tuple of `{alt_path, meta}` where `alt_path`
  is the file which will be read.
  """
  @impl Gemini.Site
  def start_link([name, path, args]) do
    GenServer.start_link(__MODULE__, [path, args], name: name)
  end

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

  @spec read_dir(binary(), meta(), binary(), binary()) ::
          {:ok, Gemini.Response.t()} | {:error, :notfound}
  def read_dir(base, meta, "/" <> p, path), do: read_dir(base, meta, p, path)

  def read_dir(base, meta, p, path) do
    p = Path.relative_to("/" <> p, path)
    exp = Path.expand(p, base)

    if String.starts_with?(exp, base) do
      {e, m} = find_meta(meta, exp)
      case File.read(e) do
        {:ok, r} -> {:ok, make_response(:success, m, r, [])}
        {:error, _x} -> {:error, :notfound}
      end
    else
      {:error, :notfound}
    end
  end

  defp find_meta(meta, p) when is_map(meta) do
    {_k, v} =
      meta
      |> Map.to_list()
      |> Enum.find({'', "application/octet-stream"}, fn {k, _v} -> String.ends_with?(p, k) end)

    {p, v}
  end

  defp find_meta(meta, p) when is_function(meta) do
    case meta.(p) do
      x when is_binary(x) -> {p, x}
      {a, r} when is_binary(a) -> {a, r}
      {a, r} -> {p, {a, r}}
    end
  end

  defp find_meta(meta, p), do: {p, meta}
end

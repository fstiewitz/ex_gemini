# Copyright (c) 2021-2022 Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.Site.Authenticated do
  use Gemini.Site

  @moduledoc """
  This module blocks requests without a user certificate.

  Unauthenticated requests receive a 60 status code (`CLIENT CERTIFICATE REQUIRED`).
  Authenticated requests are passed through.
  """

  @doc """
  Start site.

  * `name` name of the server.
  * `path` Path prefix.

  `args` is a keyword list with the following options:

  * `sites` a site-map (see `Gemini`) relative to `path`.
  * `signup` allow new user certificates access.
  * `login` a function, which receives `{hash, meta, cert}` of the user certificate and returns a boolean indicating authentication.
  * `login` a tuple of `{server, arg}`, will be called with `GenServer.call(server, {arg, {hash, meta, cert}})`.
  """
  @impl Gemini.Site
  def start_link([name, path, args]) do
    GenServer.start_link(__MODULE__, {path, args}, name: name)
  end

  @impl true
  def init({path, args}) do
    sites =
      args[:sites]
      |> Map.to_list()
      |> Enum.map(fn {sub_path, {name, args}} ->
        n = Gemini.get_name(name)
        s = Gemini.remove_trailing_slash(sub_path)
        {:ok, _pid} = Gemini.get_class(name).start_link([n, path <> s, args])
        {sub_path, n}
      end)

    {:ok, {path, sites, args}}
  end

  @impl true
  def path({path, _sites, _args}), do: path

  @impl true
  def forward_request(%Gemini.Request{peer: nil}, state) do
    {:reply,
     {:ok,
      make_response(:client_certificate_required, "Please provide a client certificate", nil, [])},
     state}
  end

  def forward_request(
        %Gemini.Request{peer: peer} = request,
        {path, sites, args} = state
      ) do
    response =
      case try_login(args[:signup], args[:login], peer) do
        true -> forward_logged_in(request, state)
        false -> make_response(:not_found, "NOT FOUND", nil, authenticated: true)
      end

    {:reply, {:ok, response}, {path, sites, args}}
  end

  defp try_login(true, _lf, _peer), do: true
  defp try_login(false, lf, _peer) when is_nil(lf), do: false
  defp try_login(false, lf, peer) when is_function(lf, 1), do: lf.(peer)

  defp try_login(false, {server, arg}, peer) do
    {:ok, r} = GenServer.call(server, {arg, peer})
    r
  end

  defp forward_logged_in(
         %Gemini.Request{url: %URI{path: p}} = request,
         {path, sites, _args}
       ) do
    response =
      case Gemini.get_best_site(sites, elem(String.split_at(p, String.length(path)), 1)) do
        {:error, :notfound} ->
          make_response(:not_found, "NOT FOUND", nil, authenticated: true)

        {:ok, n} ->
          {:ok, resp} = GenServer.call(n, {:forward_request, request})
          Map.put(resp, :authenticated, true)
      end

    response
  end
end

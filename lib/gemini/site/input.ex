# Copyright (c) 2021      Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.Site.Input do
  use Gemini.Site

  @moduledoc """
  This module asks the user for input.
  """

  @doc """
  Start site.

  * `name` name of the server.
  * `path` Path prefix.

  `args` is a keyword list with the following arguments:

  * `sites` a site-map (see `Gemini`) relative to `path`
  * `as_meta` is input stored in request only or saved in user certificate metadata
  * `prompt` input prompt
  * `cert_prompt` user certificate prompt (only used if `as_meta` is `true`)
  * `key` key to store input in metadata

  If `as_meta` is true, the input is stored in the metadata map under key `key`. The metadata map is tied
  to your user certificate for the *duration of the session*. Because sessions don't exist in this protocol,
  a "session" is kept alive with every request and the metadata is cleared 5 minutes after the last request.
  """
  @impl Gemini.Site
  def start_link([name, path, args]) do
    GenServer.start_link(__MODULE__, [path, args], name: name)
  end

  @impl true
  def init([path, attrs]) do
    sites =
      attrs[:sites]
      |> Map.to_list()
      |> Enum.map(fn {sub_path, {name, args}} ->
        n = Gemini.get_name(name)
        s = Gemini.remove_trailing_slash(sub_path)
        {:ok, _pid} = Gemini.get_class(name).start_link([n, path <> s, args])
        {sub_path, n}
      end)

    {:ok,
     %{
       key: attrs[:key] || :input,
       sites: sites,
       path: path,
       as_meta: attrs[:as_meta] || false,
       prompt: attrs[:prompt] || "Enter Input",
       cert_prompt: attrs[:cert_prompt] || "This page requires a valid user certificate"
     }}
  end

  @impl true
  def path(%{path: path}), do: path

  @impl true
  def forward_request(
        %Gemini.Request{url: %URI{query: nil}},
        %{as_meta: false, prompt: prompt} = state
      ) do
    {:reply, {:ok, make_response(:input, prompt, nil, [])}, state}
  end

  def forward_request(
        %Gemini.Request{url: %URI{query: query, path: p}} = req,
        %{as_meta: false, sites: sites, path: path} = state
      ) do
    response = apply_to_best_site(sites, p, path, req, query)
    {:reply, {:ok, response}, state}
  end

  def forward_request(
        %Gemini.Request{url: %URI{query: nil}, peer: nil},
        %{as_meta: true, cert_prompt: prompt} = state
      ) do
    {:reply, {:ok, make_response(:client_certificate_required, prompt, nil, [])}, state}
  end

  def forward_request(
        %Gemini.Request{url: %URI{query: nil}, peer: _cert},
        %{as_meta: true, prompt: prompt} = state
      ) do
    {:reply, {:ok, make_response(:input, prompt, nil, authenticated: true)}, state}
  end

  def forward_request(
        %Gemini.Request{url: %URI{query: query, path: p}, peer: {hash, _meta, cert}} = req,
        %{as_meta: true, key: key, sites: sites, path: path} = state
      ) do
    {:ok, meta} = Gemini.UserCache.put_metadata(hash, key, query)

    response =
      apply_to_best_site(
        sites,
        p,
        path,
        req |> Map.put(:input, query) |> Map.put(:peer, {hash, meta, cert}),
        query
      )

    {:reply, {:ok, response |> Map.put(:authenticated, true)}, state}
  end

  defp apply_to_best_site(sites, p, path, req, query) do
    case Gemini.get_best_site(sites, elem(String.split_at(p, String.length(path)), 1)) do
      {:error, :notfound} ->
        make_response(:not_found, "NOT FOUND", nil, authenticated: true)

      {:ok, n} ->
        {:ok, resp} = GenServer.call(n, {:forward_request, req |> Map.put(:input, query)})
        Map.put(resp, :authenticated, true)
    end
  end
end

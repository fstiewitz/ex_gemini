# Copyright (c) 2021      Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.DefaultRouter do
  require Logger
  @behaviour Gemini.Router

  @moduledoc """
  This module receives requests from `Gemini.ClientConnection` and forwards it
  to the appropriate server instance.

  This is the default router. Change config key `:router` to handle all requests by a different module.
  """

  @impl true
  def forward_request(%Gemini.Request{url: %URI{host: host, path: path}} = request) do
    with {:ok, sites_hosts} <- Application.fetch_env(:gemini, :sites),
         sites when is_map(sites) <- Map.get(sites_hosts, host, {:error, :wrong_host}),
         {:ok, pid} <- get_site(path, sites),
         {:ok, response} <- GenServer.call(pid, {:forward_request, request}) do
      {:ok, response}
    else
      {:error, :notfound} ->
        response = %Gemini.Response{status: {5, 1}, meta: "Not Found", body: nil}
        {:ok, response}

      {:error, x} ->
        {:error, x}

      :error ->
        Logger.error("could not load site map from Application environment")
        {:error, :internal_error}
    end
  end

  defp get_site(path, sites) do
    case Gemini.get_best_site(sites, path) do
      {:ok, {{_, n}, _}} -> {:ok, n}
      {:ok, {n, _}} -> {:ok, n}
      {:error, x} -> {:error, x}
    end
  end
end

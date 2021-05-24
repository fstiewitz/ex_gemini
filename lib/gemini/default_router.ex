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
  def forward_request(%Gemini.Request{url: url} = request) do
    with {:ok, sites} <- Application.fetch_env(:gemini, :sites),
         {:ok, pid} <- get_site(url, sites),
         {:ok, response} <- GenServer.call(pid, {:forward_request, request}) do
      log_response(response, url)
      {:ok, response}
    else
      {:error, :notfound} ->
        Logger.info("51 #{url |> URI.to_string()}")
        {:ok, %Gemini.Response{status: {5, 1}, meta: "Not Found", body: nil}}

      {:error, x} ->
        {:error, x}

      :error ->
        Logger.error("could not load site map from Application environment")
        {:error, :internal_error}
    end
  end

  defp get_site(%URI{path: path}, sites) do
    case Gemini.get_best_site(sites, path) do
      {:ok, {{_, n}, _}} -> {:ok, n}
      {:ok, {n, _}} -> {:ok, n}
      {:error, x} -> {:error, x}
    end
  end

  defp log_response(%Gemini.Response{status: {s0, s1}, authenticated: auth}, url) do
    case auth do
      false -> Logger.info("#{s0}#{s1} #{url |> URI.to_string()}")
      :required -> Logger.info("#{s0}#{s1} #{url |> URI.to_string()}")
      true -> Logger.info("#{s0}#{s1} #{url |> URI.to_string()} (authenticated)")
    end
  end
end

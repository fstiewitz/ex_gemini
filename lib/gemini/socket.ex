# Copyright (c) 2021-2022 Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.Socket do
  require Logger

  @moduledoc """
  Module for configuring `:ranch` in a `Supervisor`.
  """

  @spec child_spec(atom()) :: any()
  def child_spec(name) do
    ranch_config = Application.fetch_env!(:gemini, :ranch_config)
    rate_limit = Application.fetch_env!(:gemini, :rate_limit)
    router = Application.fetch_env!(:gemini, :router)

    case rate_limit do
      false ->
        Logger.info("starting Gemini with router #{inspect(router)} and no rate limiter")

      _ ->
        Logger.info(
          "starting Gemini with router #{inspect(router)} and rate limiter #{inspect(rate_limit)}"
        )
    end

    :ranch.child_spec(
      name,
      :ranch_ssl,
      put_in(ranch_config, [:verify], :verify_peer)
      |> put_in([:verify_fun], {&verify_fun(&1, &2, &3), nil}),
      Gemini.ClientConnection,
      rate_limit: rate_limit,
      router: router
    )
  end

  defp verify_fun(_cert, {:bad_cert, :selfsigned_peer}, nil), do: {:valid, nil}
  defp verify_fun(_cert, {:bad_cert, reason}, nil), do: {:fail, reason}
  defp verify_fun(_cert, {:extension, _}, nil), do: {:unknown, nil}
  defp verify_fun(_cert, :valid, nil), do: {:valid, nil}
  defp verify_fun(_cert, :valid_peer, nil), do: {:valid, nil}
end

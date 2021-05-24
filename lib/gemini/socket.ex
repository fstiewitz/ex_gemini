# Copyright (c) 2021      Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.Socket do
  @moduledoc """
  Module for configuring `:ranch` in a `Supervisor`.
  """

  @spec child_spec(atom()) :: any()
  def child_spec(name) do
    ranch_config = Application.fetch_env!(:gemini, :ranch_config)

    :ranch.child_spec(
      name,
      :ranch_ssl,
      put_in(ranch_config, [:verify], :verify_peer)
      |> put_in([:verify_fun], {&verify_fun(&1, &2, &3), nil}),
      Gemini.ClientConnection,
      []
    )
  end

  defp verify_fun(_cert, {:bad_cert, :selfsigned_peer}, nil), do: {:valid, nil}
  defp verify_fun(_cert, {:bad_cert, reason}, nil), do: {:fail, reason}
  defp verify_fun(_cert, {:extension, _}, nil), do: {:unknown, nil}
  defp verify_fun(_cert, :valid, nil), do: {:valid, nil}
  defp verify_fun(_cert, :valid_peer, nil), do: {:valid, nil}
end

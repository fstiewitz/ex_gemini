# Copyright (c) 2021      Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.ClientConnection do
  @behaviour :ranch_protocol

  @moduledoc """
  Represents a single connection. Spawned by `:ranch`.
  """

  @impl true
  def start_link(ref, transport, options) do
    pid = spawn_link(__MODULE__, :init, [ref, transport, options])
    {:ok, pid}
  end

  @spec init(any(), any(), keyword() | []) :: :ok
  def init(ref, transport, _options) do
    {:ok, socket} = :ranch.handshake(ref)
    loop(socket, transport, "")
  end

  @spec loop(any(), any(), binary()) :: :ok
  def loop(socket, transport, buffer) do
    case transport.recv(socket, 0, 5000) do
      {:ok, data} ->
        if String.contains?(data, "\r\n") do
          url = String.split(buffer <> data, "\r\n", parts: 2) |> hd
          request = %Gemini.Request{url: URI.parse(url), peer: get_cert(socket)}
          router = Application.fetch_env!(:gemini, :router)

          reply =
            case router.forward_request(request) do
              {:ok, reply} -> reply
              {:error, _x} -> Gemini.Site.make_response(:cgi_error, "INTERNAL ERROR", nil, [])
            end

          transport.send(socket, Gemini.Binary.binary(reply))
          :ok = transport.close(socket)
        else
          loop(socket, transport, buffer <> data)
        end

      _ ->
        :ok = transport.close(socket)
    end
  end

  defp get_cert(socket) do
    case :ssl.peercert(socket) do
      {:error, :no_peercert} ->
        nil

      {:ok, cert} ->
        {:ok, hash, meta} = Gemini.UserCache.register(cert)
        {hash, meta, cert}
    end
  end
end

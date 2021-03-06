# Copyright (c) 2021      Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.ClientConnection do
  require Logger
  @behaviour :ranch_protocol

  @moduledoc """
  Represents a single connection. Spawned by `:ranch`.
  """

  @impl true
  def start_link(ref, transport, options) do
    pid = spawn_link(__MODULE__, :init, [ref, transport, options])
    {:ok, pid}
  end

  @spec init(any(), any(), keyword()) :: :ok
  def init(ref, transport, options) do
    {:ok, socket} = :ranch.handshake(ref)
    rate_limit_status = check_rate_limit(transport, socket, options[:rate_limit])

    case rate_limit_status do
      {:error, _x} -> transport.close(socket)
      {addr, status} -> loop(socket, transport, "", {addr, status}, options[:router])
    end
  end

  @type limited :: {:inet.ip_address(), {:limited, pos_integer()}}
  @type unlimited :: {:inet.ip_address() | nil, :unlimited}
  @type rate_limit_status() :: limited() | unlimited()

  @spec loop(any(), any(), binary(), rate_limit_status(), atom()) :: :ok
  def loop(socket, transport, buffer, {addr, status}, router) do
    case transport.recv(socket, 0, 5000) do
      {:ok, data} ->
        cond do
          String.contains?(data, "\r\n") ->
            process_with_rate_limit(socket, transport, buffer <> data, {addr, status}, router)

          String.length(buffer) > 3000 ->
            log_invalid(addr)

            :ok = transport.close(socket)

          true ->
            loop(socket, transport, buffer <> data, {addr, status}, router)
        end

      _ ->
        :ok = transport.close(socket)
    end
  end

  defp process_with_rate_limit(socket, transport, buffer, {addr, status}, router) do
    case status do
      :not_limited ->
        process_request(socket, transport, buffer, router, addr)

      {:limited, x} ->
        Logger.info("44 #{:inet.ntoa(addr)}")

        transport.send(
          socket,
          Gemini.Binary.binary(Gemini.Site.make_response(:slow_down, x, nil, []))
        )
    end
  end

  defp log_invalid(nil), do: nil
  defp log_invalid(addr), do: Logger.info("99 #{:inet.ntoa(addr)}")

  defp check_rate_limit(_transport, _socket, false), do: {nil, :not_limited}

  defp check_rate_limit(transport, socket, rate_limit) do
    case transport.peername(socket) do
      {:ok, {addr, _port}} ->
        {addr, rate_limit.is_rate_limited(addr)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_request(socket, transport, buffer, router, addr) do
    url = String.split(buffer, "\r\n", parts: 2) |> hd

    uri =
      case URI.parse(url) do
        %URI{path: nil} = u -> Map.put(u, :path, "/")
        u -> u
      end

    request = %Gemini.Request{url: uri, peer: get_cert(socket), client: addr}

    reply =
      case router.forward_request(request) do
        {:ok, %Gemini.Response{} = reply} ->
          reply

        {:error, :wrong_host} ->
          Gemini.Site.make_response(:proxy_request_refused, "REFUSED", nil, [])

        {:error, _x} ->
          Gemini.Site.make_response(:cgi_error, "INTERNAL ERROR", nil, [])
      end

    Gemini.log_response(reply, request)
    transport.send(socket, Gemini.Binary.binary(reply))
    :ok = transport.close(socket)
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

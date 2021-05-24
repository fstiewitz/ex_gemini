# Copyright (c) 2021      Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.Site.Spy do
  use Gemini.Site, check_path: true

  @moduledoc """
  This module returns all information that the server stores about your request and associated user certificate.
  """

  @prefix """
  # Request Information
  This page returns all of your information which the server currently stores about you.

  """

  @request_prefix """
  ## Request Information
  This information was send with your request.

  """

  @impl true
  def start_link([name, path, args]) do
    GenServer.start_link(__MODULE__, [path, args], name: name)
  end

  @impl true
  def init([path, _args]) do
    {:ok, path}
  end

  @impl true
  def path(path), do: path

  @impl true
  def forward_request(req, path) do
    response =
      {@prefix <> @request_prefix, req}
      |> print_request_prefix()
      |> print_meta()
      |> make_response()

    {:reply, {:ok, response}, path}
  end

  @spec make_response({binary(), Gemini.Request.t()}) :: Gemini.Response.t()
  def make_response({data, _r}) do
    make_response(:success, "text/gemini", data, [])
  end

  defp print_request_prefix({cnt, %Gemini.Request{url: uri, peer: {_hash, _meta, cert}} = req}) do
    pr_cert =
      cert
      |> :public_key.pkix_decode_cert(:plain)
      |> inspect(
        pretty: true,
        limit: :infinity,
        printable_limit: :infinity,
        charlists: :infer,
        binaries: :infer
      )
      |> String.split("\n")
      |> Enum.map(fn x -> "#{x}\n" end)
      |> Enum.reduce(&Kernel.<>(&2, &1))

    cnt =
      cnt <>
        """
        ### URL
        The URL provided with your request is:
        ```
        #{uri |> URI.to_string()}
        ```

        ### Client Certificate
        The client certificate you communicated is as follows:

        ```
        #{pr_cert}
        ```
        """

    {cnt, req}
  end

  defp print_request_prefix({cnt, %Gemini.Request{url: uri, peer: nil} = req}) do
    cnt =
      cnt <>
        """
        ### URL
        The URL provided with your request is: #{uri |> URI.to_string()}

        ### Client Certificate
        No client certificate has been provided

        """

    {cnt, req}
  end

  defp print_meta({cnt, %Gemini.Request{url: _uri, peer: {hash, meta, _cert}} = req}) do
    pr_meta =
      meta
      |> Map.to_list()
      |> Enum.map(fn {k, v} -> "#{k} => #{inspect(v)}\n" end)
      |> Enum.reduce("", &Kernel.<>(&2, &1))

    pr_meta =
      case pr_meta do
        "" -> "No metadata provided"
        x -> x
      end

    cnt =
      cnt <>
        """
        ### Internal ID
        This internal ID identifies you and your actions on this server and is tied to your certificate:
        ```
        #{Gemini.readable_hash(hash)}
        ```

        ### Metadata
        Sites on this server can store metadata associated with your user certificate. This data is not permanent and gets removed around 10 minutes after your last connection.

        ```
        #{pr_meta}
        ```

        """

    {cnt, req}
  end
end

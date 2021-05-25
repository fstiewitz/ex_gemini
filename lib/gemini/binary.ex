# Copyright (c) 2021      Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defprotocol Gemini.Binary do
  @moduledoc """
  This protocol serializes data structures to the gemini protocol.
  """

  @doc """
  Serialize input to binary, ready to be sent over Gemini.
  """
  @spec binary(any()) :: binary()
  def binary(data)
end

defimpl Gemini.Binary, for: Gemini.Request do
  def binary(%Gemini.Request{url: url}) do
    "#{url |> URI.to_string()}\r\n"
  end
end

defimpl Gemini.Binary, for: Gemini.Response do
  def binary(%Gemini.Response{status: {s0, s1}, meta: meta, body: nil}) do
    "#{s0}#{s1} #{binary_meta(meta)}\r\n"
  end

  def binary(%Gemini.Response{status: {s0, s1}, meta: meta, body: body}) do
    "#{s0}#{s1} #{binary_meta(meta)}\r\n#{encode_meta(meta, body)}"
  end

  defp encode_meta({meta, args}, text) do
    meta.encode(text, args)
  end

  defp encode_meta(_meta, text) do
    text
  end

  defp binary_meta({meta, args}) do
    Gemini.Binary.binary(meta.type(args))
  end

  defp binary_meta(meta) do
    Gemini.Binary.binary(meta)
  end
end

defimpl Gemini.Binary, for: BitString do
  def binary(data) do
    data
  end
end

defimpl Gemini.Binary, for: Integer do
  def binary(data) do
    "#{inspect(data)}"
  end
end

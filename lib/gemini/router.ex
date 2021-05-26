# Copyright (c) 2021      Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.Router do
  @moduledoc """
  Behaviour for router modules.
  """

  @type forward_return :: {:ok, Gemini.Response.t()} | {:error, any()}

  @doc """
  Process `Gemini.Request`. Return `Gemini.Response`.
  """
  @callback forward_request(request :: Gemini.Request.t()) :: forward_return()
end

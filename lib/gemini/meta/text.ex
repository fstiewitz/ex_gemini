# Copyright (c) 2021-2022 Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.Meta.Text do
  @moduledoc """
  This module encodes `text/plain` texts.
  You can provide `text/plain` directly as a meta type in `Gemini.Response`, so this
  module is not really necessary.
  """
  @behaviour Gemini.Meta

  @impl true
  def type(_args) do
    "text/plain"
  end

  @impl true
  def encode(body, _args) do
    body
  end
end

# Copyright (c) 2021-2022 Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.Meta do
  @moduledoc """
  Behaviour module for complex meta types. Modules of this type can be used in place of string MIME types in `Gemini.Response`.
  """

  @doc """
  Return mime type of this meta type.
  """
  @callback type(args :: any()) :: binary()

  @doc """
  Encode first argument according to the meta type.
  """
  @callback encode(data :: any(), args :: any()) :: binary()
end

# Copyright (c) 2021      Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.Response do
  defstruct status: {0, 0}, meta: "", body: nil, authenticated: false

  @type t :: %__MODULE__{
          status: {pos_integer(), non_neg_integer()},
          meta: String.t() | {mod :: atom(), name :: any()},
          body: any(),
          authenticated: false | true | :required
        }

  @moduledoc """
  A response as defined in the Gemini Protocol Specification. `status` is a two-digit tuple,
  `meta` is either a string (which will be copied into the response) or a tuple of `Gemini.Meta` module and arguments of that module.
  `body` is nil (no body), a binary (`meta` is a string), or any data that will be passed to the `Gemini.Meta` module.
  `authenticated` is set to false (no auth required), true (authenticated) or `:required` (user auth required).
  """
end

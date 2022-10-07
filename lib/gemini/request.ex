# Copyright (c) 2021-2022 Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.Request do
  @enforce_keys [:url, :peer, :client]
  defstruct url: %URI{}, peer: nil, input: nil, client: nil

  @type t :: %__MODULE__{
          url: URI.t(),
          peer: nil | {hash :: binary(), metadata :: map(), cert :: binary()},
          input: nil | binary(),
          client: :inet.ip_address() | nil
        }

  @moduledoc """
  A request as defined in the Gemini Protocol Specification. Stores the url of the request,
  an optional user certificate as `{id, meta, cert}` and optional user input.
  """
end

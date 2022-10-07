# Copyright (c) 2021-2022 Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.RateLimit do
  @moduledoc """
  This behaviour keeps track of IP addresses for rate-limiting.
  """

  @doc """
  Check if IP-address is rate-limited.

  Returns :not_limited or {:limited, minutes}.
  """
  @callback is_rate_limited(addr :: :inet.ip_address()) ::
              {:limited, pos_integer()} | :not_limited
end

# Copyright (c) 2021      Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    sites =
      Application.fetch_env!(:gemini, :sites)
      |> Map.to_list()
      |> Enum.map(fn {path, {name, args}} ->
        Supervisor.child_spec(
          {Gemini.get_class(name),
           [Gemini.get_name(name), path |> Gemini.remove_trailing_slash(), args]},
          id: Gemini.get_name(name)
        )
      end)

    rate_limit =
      case Application.fetch_env!(:gemini, :rate_limit) do
        false -> []
        Gemini.DefaultRateLimit -> [Gemini.DefaultRateLimit]
      end

    children =
      [
        Gemini.UserCache,
        Gemini.Socket.child_spec(Gemini.Ranch)
      ] ++ sites ++ rate_limit

    opts = [strategy: :one_for_one, name: Gemini.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

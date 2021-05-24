# Copyright (c) 2021      Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini.Site do
  @moduledoc """
  Base module for sites.
  Use it with `use Gemini.Site`.
  If the `use` call is made with the option `:check_path` then `c:forward_request/2` will only be called if the URL path matches exactly.
  It is a good idea to enable that for "leaf" sites, i.e. sites that do not forward to other sites.

  `start_link` receives a list with three arguments:
  - the name to register the GenServer
  - the path
  - arguments from the site-map

  The server state must contain the path and `path(state)` must return that path.
  """
  defmacro __using__(opts) do
    base =
      quote do
        use GenServer
        @behaviour Gemini.Site

        def make_response(status, meta, body, attrs),
          do: Gemini.Site.make_response(status, meta, body, attrs)
      end

    if opts[:check_path] do
      quote do
        unquote(base)

        @impl true
        def handle_call(
              {:forward_request, %Gemini.Request{url: %URI{path: p}} = req},
              _from,
              state
            ) do
          s = Gemini.remove_trailing_slash(p)
          if String.equivalent?(s, path(state)) do
            forward_request(req, state)
          else
            {:reply, {:ok, make_response(:not_found, "Not Found", nil, [])}, state}
          end
        end
      end
    else
      quote do
        unquote(base)

        @impl true
        def handle_call({:forward_request, req}, _from, state), do: forward_request(req, state)

      end
    end
  end

  @doc """
  Start site's GenServer.

  - the name to register the GenServer
  - the path
  - arguments from the site-map
  """
  @callback start_link(list()) :: GenServer.on_start()

  @doc """
  Handle/Forward request. Think of it as `GenServer.handle_call/3` without the middle `from` argument.
  """
  @callback forward_request(request :: Gemini.Request.t(), state :: any()) :: {:reply, any(), any()}

  @doc """
  Return path supplied in `c:start_link/1` using the state.
  """
  @callback path(state :: any()) :: binary()
  @type status_decl :: {pos_integer(), non_neg_integer()} | :input | :sensitive_input | :success | :redirect_temporary | :redirect_permanent
  | :temporary_failure | :server_unavailable | :cgi_error | :proxy_error | :slow_down | :permanent_failure | :not_found | :gone | :proxy_request_refused
  | :bad_request | :client_certificate_required | :certificate_not_authorised | :certificate_not_valid

  @spec make_response(
          status :: Gemini.Site.status_decl(),
          meta :: binary() | {atom(), any()},
          body :: any(),
          attrs :: keyword() | []
        ) :: Gemini.Response.t()
  def make_response(:client_certificate_required, meta, body, attrs),
    do: make_response({6, 0}, meta, body, put_in(attrs, [:authenticated], :required))

  def make_response(status, meta, body, attrs) do
    %Gemini.Response{
      status: Gemini.Site.status(status),
      meta: meta,
      body: body,
      authenticated: attrs[:authenticated] || false
    }
  end

  @doc """
  Return two digit status tuple.
  """
  @spec status(status_decl()) :: {pos_integer(), non_neg_integer()}
  def status({s0, s1}), do: {s0, s1}
  def status(:input), do: {1, 0}
  def status(:sensitive_input), do: {1, 1}
  def status(:success), do: {2, 0}
  def status(:redirect_temporary), do: {3, 0}
  def status(:redirect_permanent), do: {3, 1}
  def status(:temporary_failure), do: {4, 0}
  def status(:server_unavailable), do: {4, 1}
  def status(:cgi_error), do: {4, 2}
  def status(:proxy_error), do: {4, 3}
  def status(:slow_down), do: {4, 4}
  def status(:permanent_failure), do: {5, 0}
  def status(:not_found), do: {5, 1}
  def status(:gone), do: {5, 2}
  def status(:proxy_request_refused), do: {5, 3}
  def status(:bad_request), do: {5, 9}
  def status(:client_certificate_required), do: {6, 0}
  def status(:certificate_not_authorised), do: {6, 1}
  def status(:certificate_not_valid), do: {6, 2}
end

# Copyright (c) 2021-2022 Fabian Stiewitz <fabian@stiewitz.pw>
# Licensed under the EUPL-1.2
defmodule Gemini do
  require Logger

  @moduledoc """
  Gemini is a lightweight application protocol. This server implements a lightweight server implementation
  using Elixir.

  ## Architecture
  `Gemini` uses `:ranch` as a TLS socket pool.

  The data flow is as follows:
  1. `:ranch` creates a `Gemini.ClientConnection` for a connection.
  2. `Gemini.ClientConnection` reads the request.
  3. If request includes a client certificate, `Gemini.ClientConnection` registers a session with `Gemini.UserCache`.
  4. `Gemini.ClientConnection` builds a `Gemini.Request` and forwards it to `Gemini.Router`.
  5. The top-level `Gemini.Router` uses the site map `:sites` (in config) to find a module to forward the request to (a "Site-Module").
  6. That site module takes the `Gemini.Request` and returns a `Gemini.Response`.
  7. `Gemini.ClientConnection` sends the `Gemini.Response` and closes the connection.

  ## Configuration
  ### Site-Map
  A site map is a data structure with the following shape:

      %{
        "hostname" => %{
          "path-or-path-prefix" => {name, [args]}
        }
      }

  The value with the most specific `path-or-path-prefix` wins. `name` is either:
  - a site module `name` which will be registered under the same name.
  - a tuple of `{mod, name}`: A site module `mod` registered under the name `name`.

  The module is started with `args` under the supervision of `Gemini.Supervisor`.

  The top-level site-map is the config key `:sites`.

  If you do not need a site-map or you want to run your own routing, set config key `:router` to a module which implements `Gemini.Router`.

  ### Certificates
  `:ranch` is configured using the config key `:ranch_config`. Use it to configure at least `:port`, `:certfile` and `:keyfile`.
  `:verify` and `:verify_fun` is overwritten by the program.

  The certificate provided by the user is stored in the `:peer` property of `Gemini.Request` as `{id, meta, cert}`. `cert` is the DER-encoded
  certificate, `id` is a hash-value of that certificate (can be assumed to be unique and should probably be used internally if you implement some kind of permanent DB)
  and `meta` is a metadata map (see Metadata below).

  ### Rate-Limiting
  Rate-limiting is turned on by default with max. 20 calls/minute and a 60 second penalty.
  To configure the default rate-limit module, see `Gemini.DefaultRateLimit`.
  To turn it off, set config key `:rate_limit` to false.
  To provide your own Rate-Limit module, set `:rate_limit` to the name of the module which implements `Gemini.RateLimit`.

  ### Site-Modules

  #### `Gemini.Site.File`
  Serves a single file.

      %{"/" => {
          {Gemini.Site.File, MyIndex},
          ["public/index", "text/gemini", :infinity]}}

  #### `Gemini.Site.Directory`
  Serves a directory.

      %{"/" => {
          {Gemini.Site.Directory, MyIndex},
          ["public", %{".txt" => "text/plain", ".gemini" => "text/gemini"}]
      }}

  #### `Gemini.Site.Authenticated`
  Require user certificate.

      %{"/auth" => {
          {Gemini.Site.Authenticated, MyAuth},
          [sites: %{"/" => {
                      {Gemini.Site.File, MyAuthedFile},
                      ["public/authed", "text/gemini", :infinity]}}]}}

  #### `Gemini.Site.Input`
  Require user input.

      %{"/input" => {
          {Gemini.Site.Input, MyInput},
          [as_meta: false, sites: %{"/" => {
              {Gemini.Site.Spy, MySpy}, []}}]}}

  #### `Gemini.Site.Spy`
  Return all data the server has stored about a given request/user/certificate.

      %{"/" => {
          {Gemini.Site.Spy, MySpy}, []}}

  #### `Gemini.Site.ExInfo`
  Return information about the running elixir/erlang system.

      %{"/" => {
          {Gemini.Site.ExInfo, MyInfo}, []}}

  This set of modules only provides the most basic functionality. Anything complex regarding user interaction and data storage has to be implemented
  using custom site modules.

  ### Custom Modules

      defmodule MyModule do
        use Gemini.Site, check_path: true

        def start_link([name, path, args]) do
          GenServer.start_link(__MODULE__, [path, args], name: name)
        end

        def init([path, args]) do
          {:ok, {path, args}}
        end

        def path({path, _args}), do: path

        def forward_request(request, state) do
          response = make_response(:success, "text/plain", "Hello, World!", [])
          {:reply, {:ok, response}, state}
        end
      end

  The `request` in `c:Gemini.Site.forward_request/2` is a `Gemini.Request`.
  If you need a user certificate, use your module in a `Gemini.Site.Authenticated` site-map or
  reimplement that behaviour from scratch.
  If you need user input, use your module in a `Gemini.Site.Input` site-map or
  reimplement that behaviour from scratch.

  ### Metadata
  Sites can associate temporary metadata with a user certificate using `Gemini.UserCache`. If a request includes
  a user certificate, the metadata map is available in `Gemini.Request` under `:peer`. See `Gemini.Request` for details.

  """

  @doc false
  @spec get_class(atom() | {atom(), atom()}) :: atom()
  def get_class({n, _}), do: n
  def get_class(n), do: n

  @doc false
  @spec get_name(atom() | {atom(), atom()}) :: atom()
  def get_name({_, n}), do: n
  def get_name(n), do: n

  @doc """
  Return hash value of certificate that is used internally to identify users.
  """
  @spec cert_hash(binary()) :: binary()
  def cert_hash(cert) do
    :crypto.hash(:sha512, cert)
  end

  @doc """
  Return readable hash value.
  """
  @spec readable_hash(binary()) :: binary()
  def readable_hash(data) do
    data
    |> :binary.bin_to_list()
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.reduce("", &Kernel.<>(&1, &2))
  end

  @doc """
  Get best site (or `{:error, :notfound}`) for a path and sitemap.
  """
  @spec get_best_site(map(), binary()) :: {:ok, any()} | {:error, :notfound}
  def get_best_site(sites, "") do
    site =
      sites
      |> Enum.reduce({"//", nil}, fn {a, x}, {b, y} ->
        if String.length(a) < String.length(b) do
          {a, x}
        else
          {b, y}
        end
      end)

    case site do
      {"", nil} -> {:error, :notfound}
      {_, n} -> {:ok, n}
    end
  end

  def get_best_site(sites, path) do
    site =
      sites
      |> Enum.filter(fn {x, _} -> String.starts_with?(path, x) end)
      |> Enum.reduce({"", nil}, fn {a, x}, {b, y} ->
        if String.length(a) > String.length(b) do
          {a, x}
        else
          {b, y}
        end
      end)

    case site do
      {"", nil} -> {:error, :notfound}
      {_, n} -> {:ok, n}
    end
  end

  @doc """
  Remove trailing slash from path
  """
  @spec remove_trailing_slash(binary()) :: binary()
  def remove_trailing_slash(path) do
    cond do
      path == "/" -> ""
      String.ends_with?(path, "/") -> String.at(path, String.length(path) - 1)
      true -> path
    end
  end

  @doc """
  Log request & response to Logger.
  """
  @spec log_response(Gemini.Response.t(), Gemini.Request.t()) :: :ok
  def log_response(%Gemini.Response{status: {s0, s1}, authenticated: auth}, %Gemini.Request{
        url: url,
        client: nil
      }) do
    case auth do
      false -> Logger.info("#{s0}#{s1} #{url |> URI.to_string()}")
      :required -> Logger.info("#{s0}#{s1} #{url |> URI.to_string()}")
      true -> Logger.info("#{s0}#{s1} #{url |> URI.to_string()} (authenticated)")
    end

    :ok
  end

  def log_response(%Gemini.Response{status: {s0, s1}, authenticated: auth}, %Gemini.Request{
        url: url,
        client: client
      }) do
    case auth do
      false ->
        Logger.info("#{s0}#{s1} #{:inet.ntoa(client)} #{url |> URI.to_string()}")

      :required ->
        Logger.info("#{s0}#{s1} #{:inet.ntoa(client)} #{url |> URI.to_string()}")

      true ->
        Logger.info("#{s0}#{s1} #{:inet.ntoa(client)} #{url |> URI.to_string()} (authenticated)")
    end

    :ok
  end
end

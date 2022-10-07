import Config

config :gemini, :ranch_config,
  port: 1965,
  certfile: "certs/cert.pem",
  keyfile: "certs/key.pem"

# clean session cache every 3 minutes
config :gemini, :user_cache_cleanup_time, 3

config :gemini, :rate_limit, Gemini.DefaultRateLimit

# clean rate limit IP cache every 10 minutes
config :gemini, :rate_limit_max_age, 10

# time out rate-limited IPs for 60 seconds
config :gemini, :rate_limit_penalty, 60

# max number of calls during a bracket
config :gemini, :rate_limit_max_calls, 20

# duration of one rate-limiting bracket
config :gemini, :rate_limit_bracket_duration, 1

config :gemini, :router, Gemini.DefaultRouter

meta = fn p ->
  case p |> Path.basename() do
    "hello.txt" -> "text/plain"
    _ -> "application/octet-stream"
  end
end

meta2 = fn p ->
  case p |> Path.basename() do
    "hello" -> {"#{p}.txt", "text/plain"}
    "hello.txt" -> "text/plain"
    _ -> "application/octet-stream"
  end
end

# Example of simple login function, checking certificate hash against whitelist.
# Hash listed here is from my own test cert.
good_users =
  [
    "64F1810F25F317829F5D4050E0147DE4F22D785426867CCD1B5A01C549C2FD47E8639AE07A25DF4512E65C2B492B6468AE06BBDDD80DF0C65B96FC2D9C5D32E2"
  ]
  |> Enum.map(fn hash ->
    hash
    |> :erlang.bitstring_to_list()
    |> Enum.chunk_every(2)
    |> Enum.map(&to_string(&1))
    |> Enum.map(&String.to_integer(&1, 16))
    |> :binary.list_to_bin()
  end)

login = fn {hash, _meta, _cert} ->
  hash
  |> :binary.bin_to_list()
  |> Enum.map(&Integer.to_string(&1, 16))
  |> Enum.map(&String.pad_leading(&1, 2, "0"))
  |> Enum.join()
  |> IO.inspect()

  good_users
  |> Enum.map(fn ch ->
    ch
    |> :binary.bin_to_list()
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.pad_leading(&1, 2, "0"))
    |> Enum.join()
    |> IO.inspect()
  end)

  Enum.find(good_users, fn x -> x == hash end) != nil
end

config :gemini, :sites, %{
  "localhost" => %{
    # show index page
    "/" => {{Gemini.Site.File, Web.Index}, ["public/index", "text/gemini", :infinity]},
    "/version" => {{Gemini.Site.ExInfo, Web.ExInfo}, []},
    "/dir" => {{Gemini.Site.Directory, Web.Dir}, ["public/directory", %{".txt" => "text/plain"}]},
    "/dir2" => {{Gemini.Site.Directory, Web.Dir2}, ["public/directory", "text/plain"]},
    "/dir3" => {{Gemini.Site.Directory, Web.Dir3}, ["public/directory", meta]},
    "/dir4" => {{Gemini.Site.Directory, Web.Dir4}, ["public/directory", meta2]},
    "/auth" =>
      {{Gemini.Site.Authenticated, Web.Authenticated},
       [
         signup: true,
         sites: %{
           "/" => {{Gemini.Site.File, Web.AuthFile}, ["public/authed", "text/gemini", :infinity]},
           "/test" => {{Gemini.Site.Spy, Web.SpyAuthed}, []}
         }
       ]},
    "/auth2" =>
      {{Gemini.Site.Authenticated, Web.Authenticated2},
       [
         signup: false,
         login: login,
         sites: %{
           "/" => {{Gemini.Site.File, Web.AuthFile2}, ["public/authed", "text/gemini", :infinity]},
           "/test" => {{Gemini.Site.Spy, Web.SpyAuthed2}, []}
         }
       ]},
    "/spy" => {Gemini.Site.Spy, []},
    # user input can be stored in two ways:
    # 1. Simple user input is stored in the `:input` field of the request
    "/input_simple" =>
      {{Gemini.Site.Input, Web.Input},
       [
         as_meta: false,
         prompt: "Enter something",
         sites: %{"/" => {{Gemini.Site.Spy, Web.Spy1}, []}}
       ]},
    # 2. User input is stored in the metadata associated with the user certificate
    "/input_meta" =>
      {{Gemini.Site.Input, Web.Input2},
       [
         as_meta: true,
         prompt: "Enter something",
         key: :my_input,
         sites: %{"/" => {{Gemini.Site.Spy, Web.Spy2}, []}}
       ]},
    "/not_found" =>
      {{Gemini.Site.File, Web.NotFound}, ["public/not_found", "text/gemini", :disabled]}
  }
}

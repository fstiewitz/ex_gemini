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

config :gemini, :sites, %{
  "localhost" => %{
    # show index page
    "/" => {{Gemini.Site.File, Web.Index}, ["public/index", "text/gemini", :infinity]},
    "/version" => {{Gemini.Site.ExInfo, Web.ExInfo}, []},
    "/dir" => {{Gemini.Site.Directory, Web.Dir}, ["public/directory", %{".txt" => "text/plain"}]},
    "/auth" =>
      {{Gemini.Site.Authenticated, Web.Authenticated},
       [
         signup: true,
         sites: %{
           "/" => {{Gemini.Site.File, Web.AuthFile}, ["public/authed", "text/gemini", :infinity]},
           "/test" => {{Gemini.Site.Spy, Web.SpyAuthed}, []}
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

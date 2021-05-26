import Config

config :gemini, :ranch_config,
  port: 1965,
  certfile: "/etc/ex_gemini/cert.pem",
  keyfile: "/etc/ex_gemini/key.pem"

config :gemini, :user_cache_cleanup_time, 3

config :gemini, :rate_limit, Gemini.DefaultRateLimit

config :gemini, :rate_limit_max_age, 10

config :gemini, :rate_limit_penalty, 60

config :gemini, :rate_limit_max_calls, 20

config :gemini, :rate_limit_bracket_duration, 1

config :gemini, :router, Gemini.DefaultRouter

# Every service is a data structure of shape {Prefix, {Type, [Name, [Arguments]]}}
config :gemini, :sites, %{}

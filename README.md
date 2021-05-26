# Gemini

Gemini server implementation in Elixir.

## TODO

- [x] Serve files
- [x] Routing
- [x] Auth
- [x] Input
- [x] Virtual Hosts (`v0.2`)
- [x] Rate-Limiting (`v0.2`)
- [ ] Release Configuration (necessary?)

## Installation (development)

To develop the server:

1. Clone this repository
2. `mix deps.get`
3. `mix compile`
3. `iex -S mix`

See `config/config.dev.exs` for development settings.
Obviously don't use this in prod.

## Installation (standalone)

To run the server as a standalone application:

1. Clone this repository (optional: checkout the version you want)
2. `MIX_ENV=prod mix deps.get`
3. `MIX_ENV=prod mix compile`
4. `MIX_ENV=prod mix release gemini`
5. Copy `_build/prod/rel/gemini` to a good location (like `/opt/ex_gemini`)
6. Create your server certificates
7. Create `/etc/ex_gemini/config.exs` (see `config/config.dev.exs` for reference)
8. Start the server (`/opt/ex_gemini/bin/gemini start`)

## Installation (docker)

See [DEPLOYMENT.md](DEPLOYMENT.md)

## Installation (as package)

The package can be installed
by adding `gemini` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gemini, git: "https://github.com/fstiewitz/ex_gemini.git", tag: "0.1"}
  ]
end
```

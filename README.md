# Gemini

Gemini server implementation in Elixir.

## TODO

- [x] Serve files
- [x] Routing
- [x] Auth
- [x] Input
- [ ] Virtual Hosts (currently ignores hostname)
- [ ] Rate-Limiting
- [ ] Release Configuration (necessary?)

## Installation (standalone)

To use the app as a standalone server:

1. Clone this repository
2. Create server certificate in `certs/`
3. Configure sites in `config/runtime.exs`.
4. `iex -S mix` or `mix release`.

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

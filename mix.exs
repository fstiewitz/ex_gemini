defmodule Gemini.MixProject do
  use Mix.Project

  def project do
    [
      app: :gemini,
      name: "Gemini",
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :ranch],
      mod: {Gemini.Application, []},
      env: [
        ranch_config: [
          port: 1965,
          certfile: "certs/cert.pem",
          keyfile: "certs/key.pem"
        ],
        user_cache_cleanup_time: 3,
        router: Gemini.DefaultRouter,
        sites: %{}
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ranch, "~> 2.0"},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:dialyxir, "~> 1.1", only: :dev, runtime: false},
      {:credo, "~> 1.5", only: :dev, runtime: false}
    ]
  end
end

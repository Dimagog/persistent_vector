defmodule PersistentVector.Mixfile do
  use Mix.Project

  @version "0.1.1"
  @github "https://github.com/dimagog/persistent_vector"

  def project do
    [
      app: :persistent_vector,
      name: "Persistent Vector",
      version: @version,
      description: "PersistentVector is an array-like collection of values indexed by contiguous `0`-based integer index.",
      elixir: "~> 1.4",
      start_permanent: Mix.env == :prod,
      deps: deps(),

      dialyzer: [
        # flags: ~w[underspecs overspecs race_conditions error_handling unmatched_returns no_match]a
        flags: ~w[error_handling unmatched_returns no_match]a
      ],

      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.html": :test],

      docs: [
        main: "PersistentVector",
        extras: [
          "LICENSE.md": [title: "LICENSE"],
          "README.md": [title: "Read Me"],
          "benchmarks.md": [title: "Benchmarks"],
        ],
        homepage_url: @github,
        source_url: @github,
        source_ref: "v#{@version}"
      ],

      package: [
        name: "persistent_vector",
        licenses: ["MIT"],
        maintainers: ["Dmitry Kakurin"],
        links: %{"GitHub" => @github}
      ]
    ]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [
      {:benchee, "~> 0.9", only: :dev},
      {:benchee_html, "~> 0.3", only: :dev},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      # Run `mix eqc.install --mini` for the first time to use eqc_ex
      {:eqc_ex, "~> 1.4", only: :test},
      {:excoveralls, "~> 0.7", only: :test},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      {:version_tasks, "~> 0.10", only: :dev, runtime: false}
    ]
  end
end

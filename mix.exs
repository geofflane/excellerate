defmodule ExCellerate.MixProject do
  use Mix.Project

  def project do
    [
      app: :excellerate,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_parsec, "~> 1.4"},
      {:benchee, "~> 1.3", only: :dev}
    ]
  end
end

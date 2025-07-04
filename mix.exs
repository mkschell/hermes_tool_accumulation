defmodule HermesToolAccumulation.MixProject do
  use Mix.Project

  def project do
    [
      app: :hermes_tool_accumulation,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {HermesToolAccumulation.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:hermes_mcp, "~> 0.11"},
      {:postgrex, ">= 0.0.0"}
    ]
  end
end

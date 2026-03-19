defmodule GitrepoAgent.MixProject do
  use Mix.Project

  def project do
    [
      app: :gitrepo_agent,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {GitrepoAgent.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:req, "~> 0.5"},
      {:dotenv_parser, "~> 2.0"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      test: ["test --trace"]
    ]
  end
end

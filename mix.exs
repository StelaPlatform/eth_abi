defmodule EthContractUtil.MixProject do
  use Mix.Project

  def project do
    [
      app: :eth_abi,
      version: "0.1.0",
      elixir: "~> 1.14",
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
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:chain_util, git: "https://github.com/StelaPlatform/chain_util.git"},
      {:utility_belt, "~> 0.16.0"},
      {:keccakf1600, "~> 2.1", hex: :keccakf1600_diode_fork},
      {:poison, "~> 5.0.0"}
    ]
  end
end

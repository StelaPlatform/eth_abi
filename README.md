# EthAbi

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `eth_abi` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:eth_abi, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/eth_abi>.

## Usage

Auto gen Elixir native method based on Ethereum smart contract ABI, and also contract constructor.

```elixir
  path = "artifacts/contracts/StelaComment.sol/StelaComment.json"
  contract_module = "StelaPlatform.Comment.Contract"
  deployer_module = "StelaPlatform.Comment.Contract.Deploy"

  EthAbi.ContractGen.gen_contract(path, contract_module,
    output_folder: "priv/gen/contract",
    create_beam: true
  )

  EthAbi.DeployerGen.gen_deployer(path, contract_module, deployer_module,
    output_folder: "priv/gen/contract",
    create_beam: true
  )
```

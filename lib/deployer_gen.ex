defmodule EthAbi.DeployerGen do
  use EthAbi.Util
  require UtilityBelt.CodeGen.DynamicModule
  alias UtilityBelt.CodeGen.DynamicModule

  def gen_deployer(contract_json_path, contract_name, module_name, opts \\ []) do
    output_folder = Keyword.get(opts, :output_folder, "lib/mix/tasks")
    create_beam = Keyword.get(opts, :create_beam, false)

    contract_module = String.to_atom("Elixir.#{contract_name}")

    preamble =
      quote do
        alias unquote(contract_module), as: Contract
      end

    contract_json = read_contract_json(contract_json_path)

    link_references = get_link_references(contract_json)

    constructor = get_constructor(contract_json)

    quoted_do_run = quote_do_run(constructor, link_references)

    contents = quote_deployer(quoted_do_run)

    doc = get_doc(constructor)

    DynamicModule.gen(
      module_name,
      preamble,
      contents,
      doc: doc,
      path: Path.join(File.cwd!(), output_folder),
      create: create_beam
    )
  end

  def quote_deployer(quoted_do_run) do
    quote do
      def run([gas_limit | rest_args]) do
        Application.ensure_all_started(:ocap_rpc)
        %{deployer: %{sk: sk}} = ChainUtil.wallets()

        do_run(rest_args, sk, gas_limit)
      end

      unquote(quoted_do_run)

      defp wait_tx(hash) do
        wait_tx(hash, OcapRpc.Eth.Transaction.get_by_hash(hash))
      end

      defp wait_tx(hash, nil) do
        Process.sleep(1000)
        tx = OcapRpc.Eth.Transaction.get_by_hash(hash)
        wait_tx(hash, tx)
      end

      defp wait_tx(hash, %{block_hash: nil}) do
        Process.sleep(1000)
        tx = OcapRpc.Eth.Transaction.get_by_hash(hash)
        wait_tx(hash, tx)
      end

      defp wait_tx(_, %{receipt_status: 0}), do: raise("Failed to deploy contract.")
      defp wait_tx(_hash, tx), do: tx
    end
  end

  # {
  #   "inputs": [
  #     {
  #       "internalType": "uint8",
  #       "name": "digits",
  #       "type": "uint8"
  #     }
  #   ],
  #   "stateMutability": "nonpayable",
  #   "type": "constructor"
  # }
  defp quote_do_run(constructor, link_references) do
    quoted_deployment_args = quote_deployment_args(constructor, link_references)
    quoted_casts = quote_args_cast(constructor)
    quoted_inspectors = quote_args_inspect(constructor)
    quoted_default_beneficiary = quote_default_beneficiary(constructor)

    quote_do_run(
      quoted_deployment_args,
      quoted_casts,
      quoted_inspectors,
      quoted_default_beneficiary
    )
  end

  defp quote_do_run(
         quoted_deployment_args,
         quoted_casts,
         quoted_inspectors,
         quoted_default_beneficiary
       ) do
    quote do
      def do_run([unquote_splicing(quoted_deployment_args)], sk, gas_limit) do
        unquote(quoted_default_beneficiary)

        unquote_splicing(quoted_casts)

        opts = [gas_limit: String.to_integer(gas_limit)]

        hash =
          Contract.deploy(
            sk,
            unquote_splicing(quoted_deployment_args),
            opts
          )

        IO.inspect(hash, label: "Contract Deployment Transaction")

        _tx = wait_tx(hash)
        receipt = OcapRpc.Eth.Transaction.get_receipt(hash)
        contract_address = receipt.contract_address |> IO.inspect(label: "contract address")

        unquote_splicing(quoted_inspectors)

        contract_address
      end
    end
  end

  defp quote_deployment_args(constructor, link_references) do
    constructor_args =
      case constructor do
        nil ->
          []

        %{"inputs" => inputs} ->
          inputs |> Enum.map(&Map.get(&1, "name")) |> Enum.map(&to_snake_atom/1)
      end

    link_reference_args = Enum.map(link_references, &elem(&1, 0))

    (constructor_args ++ link_reference_args) |> Enum.map(&Macro.var(&1, nil))
  end

  defp quote_args_inspect(nil), do: []

  defp quote_args_inspect(%{"inputs" => inputs}) do
    args = inputs |> Enum.map(&Map.get(&1, "name"))
    types = inputs |> Enum.map(&Map.get(&1, "type"))

    args
    |> Enum.zip(types)
    |> Enum.map(&do_quote_args_inspect/1)
  end

  defp do_quote_args_inspect({arg, _type}) do
    quote do
      Contract
      |> apply(unquote(to_snake_atom("get_" <> arg)), [contract_address])
      # |> String.replace("0x", "")
      # |> Base.decode16!(case: :lower)
      # |> ABI.TypeDecoder.decode(%ABI.FunctionSelector{
      #   function: nil,
      #   types: [unquote(get_function_selector_type(type))]
      # })
      |> IO.inspect(label: unquote(arg))
    end
  end

  # defp get_function_selector_type("uint8"), do: {:uint, 8}
  # defp get_function_selector_type("uint256"), do: {:uint, 256}
  # defp get_function_selector_type("bool"), do: :bool
  # defp get_function_selector_type("bytes"), do: :bytes
  # defp get_function_selector_type("string"), do: :string
  # defp get_function_selector_type("address"), do: :address

  defp quote_args_cast(nil), do: []

  defp quote_args_cast(%{"inputs" => inputs}) do
    args = inputs |> Enum.map(&Map.get(&1, "name"))
    types = inputs |> Enum.map(&Map.get(&1, "type"))

    args
    |> Enum.zip(types)
    |> Enum.map(fn
      {arg, "int" <> _} -> {arg, :to_integer}
      {arg, "uint" <> _} -> {arg, :to_integer}
      {arg, "bool" <> _} -> {arg, :to_atom}
      _ -> nil
    end)
    |> Enum.filter(fn tuple -> tuple != nil end)
    |> Enum.map(&do_quote_args_cast/1)
  end

  defp do_quote_args_cast({arg, caster}) do
    arg_name = arg |> to_snake_atom() |> Macro.var(nil)

    quote do
      unquote(arg_name) = apply(String, unquote(caster), [unquote(arg_name)])
    end
  end

  defp quote_default_beneficiary(nil), do: nil

  defp quote_default_beneficiary(%{"inputs" => inputs}) do
    inputs
    |> Enum.map(&Map.get(&1, "name"))
    |> Enum.any?(fn arg -> arg == "beneficiary" end)
    |> case do
      true ->
        quote do
          %{alice: %{addr: alice}} = ChainUtil.wallets()

          beneficiary =
            case Keyword.get(binding(), :beneficiary, "") do
              "0x" <> addr -> "0x" <> addr
              _ -> alice
            end
        end

      false ->
        nil
    end
  end

  defp get_doc(%{"inputs" => inputs}) do
    args = inputs |> Enum.map(&Map.get(&1, "name"))
    types = inputs |> Enum.map(&Map.get(&1, "type"))
    arg_type_list = Enum.zip(args, types)
    "This is auto generated deployer, supported args: #{inspect(arg_type_list)}"
  end

  defp get_doc(_), do: "This is auto generated deployer."
end

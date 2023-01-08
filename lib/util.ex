defmodule EthAbi.Util do
  defmacro __using__(_opts) do
    quote do
      @doc """
      Convert a string to an atom in snake case.

      ## Examples

        iex> ContractGen.to_snake_atom("getApproved")
        :get_approved

        iex> ContractGen.to_snake_atom("approved")
        :approved
      """
      def to_snake_atom(str) do
        str |> Macro.underscore() |> String.to_atom()
      end

      def read_contract_json(contract_json_path) do
        contract_json_path
        |> File.read!()
        |> Poison.decode!()
      end

      def get_constructor(%{"abi" => abi_list}) do
        abi_list
        |> Enum.filter(fn abi -> abi["type"] == "constructor" end)
        |> List.first()
      end

      def get_functions(%{"abi" => abi_list}) do
        abi_list
        |> Enum.filter(fn abi -> abi["type"] == "function" end)
        |> Enum.sort(fn abi1, abi2 -> abi1["stateMutability"] >= abi2["stateMutability"] end)
      end

      def get_events(%{"abi" => abi_list}) do
        abi_list
        |> Enum.filter(fn abi -> abi["type"] == "event" end)
      end

      @doc """
      Returns a tuple list:
      [
        {:fixidity_lib, "__$57db9bc971bf4694ab481f89183e7659b0$__"}
      ]
      """
      def get_link_references(%{"linkReferences" => []}) do
        []
      end

      def get_link_references(%{"linkReferences" => link_references}) do
        link_references
        |> Map.keys()
        |> Enum.flat_map(&link_ref_from_file(&1, link_references))
      end

      defp link_ref_from_file(file_name, link_references) do
        link_references
        |> Map.get(file_name)
        |> Map.keys()
        |> Enum.map(fn lib_name ->
          <<head::binary-size(17), _::binary>> = :keccakf1600.sha3_256("#{file_name}:#{lib_name}")

          {to_snake_atom(lib_name), "__$#{Base.encode16(head, case: :lower)}$__"}
        end)
      end
    end
  end
end

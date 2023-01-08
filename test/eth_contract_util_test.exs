defmodule EthContractUtilTest do
  use ExUnit.Case
  doctest EthContractUtil

  test "greets the world" do
    assert EthContractUtil.hello() == :world
  end
end

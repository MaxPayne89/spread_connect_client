defmodule SpreadConnectClientTest do
  use ExUnit.Case
  doctest SpreadConnectClient

  test "greets the world" do
    assert SpreadConnectClient.hello() == :world
  end
end

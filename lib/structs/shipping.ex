defmodule SpreadConnectClient.Structs.Shipping do
  @moduledoc """
  Represents shipping information for an order
  """

  alias SpreadConnectClient.Structs.{Address, Price}

  defstruct [:address, :customer_price, :preferred_type]

  @type t :: %__MODULE__{
          address: Address.t(),
          customer_price: Price.t(),
          preferred_type: String.t()
        }
end

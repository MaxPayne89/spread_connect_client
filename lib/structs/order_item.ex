defmodule SpreadConnectClient.Structs.OrderItem do
  @moduledoc """
  Represents an order item with its basic properties
  """

  alias SpreadConnectClient.Structs.Price

  defstruct [:sku, :quantity, :external_order_item_reference, :customer_price]

  @type t :: %__MODULE__{
          sku: String.t(),
          quantity: integer(),
          external_order_item_reference: integer(),
          customer_price: Price.t()
        }
end

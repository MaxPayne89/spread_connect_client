defmodule SpreadConnectClient.Structs.Price do
  @moduledoc """
  Represents a price with amount and currency
  """

  defstruct [:amount, :currency]

  @type t :: %__MODULE__{
    amount: float(),
    currency: String.t()
  }
end

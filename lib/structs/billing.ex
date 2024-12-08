defmodule SpreadConnectClient.Structs.Billing do
  @moduledoc """
  Represents billing information for an order
  """

  defstruct [:name, :phone, :company, :country, :state, :city, :address, :postal_code]

  @type t :: %__MODULE__{
    name: String.t(),
    phone: String.t(),
    company: String.t(),
    country: String.t(),
    state: String.t(),
    city: String.t(),
    address: String.t(),
    postal_code: String.t()
  }
end

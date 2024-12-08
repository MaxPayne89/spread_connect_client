defmodule SpreadConnectClient.Structs.Address do
  @moduledoc """
  Represents an address with its basic properties
  """

  defstruct [:first_name, :last_name, :company, :street, :city, :state, :zip_code, :country]

  @type t :: %__MODULE__{
    first_name: String.t(),
    last_name: String.t(),
    company: String.t(),
    street: String.t(),
    city: String.t(),
    state: String.t(),
    zip_code: String.t(),
    country: String.t()
  }
end

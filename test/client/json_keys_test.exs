defmodule SpreadConnectClient.Client.JsonKeysTest do
  use ExUnit.Case, async: true

  alias SpreadConnectClient.Client.JsonKeys

  describe "camelize/1 with maps" do
    test "converts simple snake_case keys to camelCase" do
      input = %{
        order_number: "12345",
        customer_email: "test@example.com",
        total_amount: 99.99
      }

      expected = %{
        "orderNumber" => "12345",
        "customerEmail" => "test@example.com",
        "totalAmount" => 99.99
      }

      assert JsonKeys.camelize(input) == expected
    end

    test "converts atom keys to string camelCase keys" do
      input = %{
        external_order_reference: "ABC123",
        billing_address: %{zip_code: "12345"}
      }

      expected = %{
        "externalOrderReference" => "ABC123",
        "billingAddress" => %{"zipCode" => "12345"}
      }

      assert JsonKeys.camelize(input) == expected
    end

    test "handles nested maps recursively" do
      input = %{
        order_data: %{
          customer_info: %{
            first_name: "John",
            last_name: "Doe",
            phone_number: "+1234567890"
          },
          billing_address: %{
            street_address: "123 Main St",
            postal_code: "12345"
          }
        }
      }

      expected = %{
        "orderData" => %{
          "customerInfo" => %{
            "firstName" => "John",
            "lastName" => "Doe",
            "phoneNumber" => "+1234567890"
          },
          "billingAddress" => %{
            "streetAddress" => "123 Main St",
            "postalCode" => "12345"
          }
        }
      }

      assert JsonKeys.camelize(input) == expected
    end

    test "preserves non-snake_case keys" do
      input = %{
        id: 123,
        name: "test",
        email: "test@example.com",
        data: %{
          count: 5,
          active: true
        }
      }

      expected = %{
        "id" => 123,
        "name" => "test",
        "email" => "test@example.com",
        "data" => %{
          "count" => 5,
          "active" => true
        }
      }

      assert JsonKeys.camelize(input) == expected
    end

    test "handles empty maps" do
      assert JsonKeys.camelize(%{}) == %{}
    end

    test "handles deeply nested structures" do
      input = %{
        level_one: %{
          level_two: %{
            level_three: %{
              deep_key: "deep_value",
              another_deep_key: %{
                final_key: "final_value"
              }
            }
          }
        }
      }

      expected = %{
        "levelOne" => %{
          "levelTwo" => %{
            "levelThree" => %{
              "deepKey" => "deep_value",
              "anotherDeepKey" => %{
                "finalKey" => "final_value"
              }
            }
          }
        }
      }

      assert JsonKeys.camelize(input) == expected
    end
  end

  describe "camelize/1 with lists" do
    test "converts list of maps" do
      input = [
        %{order_item: %{sku: "SKU1", item_price: 19.99}},
        %{order_item: %{sku: "SKU2", item_price: 29.99}}
      ]

      expected = [
        %{"orderItem" => %{"sku" => "SKU1", "itemPrice" => 19.99}},
        %{"orderItem" => %{"sku" => "SKU2", "itemPrice" => 29.99}}
      ]

      assert JsonKeys.camelize(input) == expected
    end

    test "handles mixed list content" do
      input = [
        %{user_name: "john"},
        "string_value",
        123,
        %{email_address: "test@example.com"}
      ]

      expected = [
        %{"userName" => "john"},
        "string_value",
        123,
        %{"emailAddress" => "test@example.com"}
      ]

      assert JsonKeys.camelize(input) == expected
    end

    test "handles empty lists" do
      assert JsonKeys.camelize([]) == []
    end

    test "handles nested lists" do
      input = [
        %{
          order_items: [
            %{sku: "SKU1", unit_price: 10.00},
            %{sku: "SKU2", unit_price: 15.00}
          ]
        }
      ]

      expected = [
        %{
          "orderItems" => [
            %{"sku" => "SKU1", "unitPrice" => 10.00},
            %{"sku" => "SKU2", "unitPrice" => 15.00}
          ]
        }
      ]

      assert JsonKeys.camelize(input) == expected
    end
  end

  describe "camelize/1 with primitive values" do
    test "returns strings unchanged" do
      assert JsonKeys.camelize("hello_world") == "hello_world"
      assert JsonKeys.camelize("") == ""
    end

    test "returns numbers unchanged" do
      assert JsonKeys.camelize(42) == 42
      assert JsonKeys.camelize(3.14) == 3.14
      assert JsonKeys.camelize(0) == 0
    end

    test "returns booleans unchanged" do
      assert JsonKeys.camelize(true) == true
      assert JsonKeys.camelize(false) == false
    end

    test "returns nil unchanged" do
      assert JsonKeys.camelize(nil) == nil
    end

    test "returns atoms unchanged (non-key atoms)" do
      assert JsonKeys.camelize(:some_atom) == :some_atom
    end
  end

  describe "camelize_key/1 edge cases" do
    test "handles single word keys" do
      input = %{name: "test", id: 123}
      expected = %{"name" => "test", "id" => 123}
      assert JsonKeys.camelize(input) == expected
    end

    test "handles keys with multiple underscores" do
      input = %{
        very_long_key_name: "value1",
        another_very_long_key: "value2"
      }

      expected = %{
        "veryLongKeyName" => "value1",
        "anotherVeryLongKey" => "value2"
      }

      assert JsonKeys.camelize(input) == expected
    end

    test "handles keys with leading/trailing underscores" do
      input = %{
        _private_key: "private",
        public_key_: "public"
      }

      expected = %{
        "PrivateKey" => "private",
        "publicKey" => "public"
      }

      assert JsonKeys.camelize(input) == expected
    end

    test "handles keys with numbers" do
      input = %{
        order_item_1: "first",
        order_item_2: "second",
        api_v2_endpoint: "endpoint"
      }

      expected = %{
        "orderItem1" => "first",
        "orderItem2" => "second",
        "apiV2Endpoint" => "endpoint"
      }

      assert JsonKeys.camelize(input) == expected
    end

    test "handles empty string keys" do
      input = %{"" => "empty_key"}
      expected = %{"" => "empty_key"}
      assert JsonKeys.camelize(input) == expected
    end
  end

  describe "real-world order data transformation" do
    test "transforms complete order structure" do
      order_data = %{
        external_order_reference: "ORD-12345",
        order_items: [
          %{
            sku: "SHIRT-001",
            quantity: 2,
            external_order_item_reference: "ITEM-001",
            customer_price: %{
              amount: 29.99,
              currency: "EUR"
            }
          }
        ],
        phone: "+49123456789",
        shipping: %{
          preferred_type: "STANDARD",
          address: %{
            first_name: "John",
            last_name: "Doe",
            company: "Test Corp",
            country: "DE",
            state: "BE",
            city: "Berlin",
            street: "Main Street 123",
            zip_code: "12345"
          },
          customer_price: %{
            amount: 5.99,
            currency: "EUR"
          }
        },
        billing_address: %{
          first_name: "John",
          last_name: "Doe",
          company: "Test Corp",
          country: "DE",
          state: "BE",
          city: "Berlin",
          street: "Main Street 123",
          zip_code: "12345"
        },
        currency: "EUR",
        email: "john.doe@example.com"
      }

      result = JsonKeys.camelize(order_data)

      assert result["externalOrderReference"] == "ORD-12345"
      assert [item] = result["orderItems"]
      assert item["externalOrderItemReference"] == "ITEM-001"
      assert item["customerPrice"]["amount"] == 29.99
      assert result["shipping"]["preferredType"] == "STANDARD"
      assert result["shipping"]["address"]["firstName"] == "John"
      assert result["shipping"]["address"]["lastName"] == "Doe"
      assert result["shipping"]["address"]["zipCode"] == "12345"
      assert result["billingAddress"]["firstName"] == "John"
      assert result["billingAddress"]["zipCode"] == "12345"
    end
  end
end
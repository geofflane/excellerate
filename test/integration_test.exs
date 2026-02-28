defmodule ExCellerate.IntegrationTest do
  use ExUnit.Case, async: true

  describe "complex expressions combining multiple features" do
    test "arithmetic with multiple scope variables" do
      scope = %{"price" => 25.0, "quantity" => 4, "tax_rate" => 0.08}
      assert ExCellerate.eval!("price * quantity * (1 + tax_rate)", scope) == 108.0
    end

    test "nested access with arithmetic and functions" do
      scope = %{
        "order" => %{
          "items" => [
            %{"price" => 10.5, "qty" => 2},
            %{"price" => 7.25, "qty" => 3}
          ],
          "discount" => 5
        }
      }

      # Compute total for first item minus discount
      assert ExCellerate.eval!(
               "order.items[0].price * order.items[0].qty - order.discount",
               scope
             ) == 16.0
    end

    test "ternary with comparison on computed values" do
      scope = %{"score" => 85, "threshold" => 70, "bonus" => 10}

      assert ExCellerate.eval!(
               "score + bonus >= 90 ? 'A' : 'B'",
               scope
             ) == "A"
    end

    test "chained function calls with scope variables" do
      scope = %{"x" => -15, "y" => 7, "z" => 3}
      # abs(-15) + max(7, 3) + min(7, 3) = 15 + 7 + 3 = 25
      assert ExCellerate.eval!("abs(x) + max(y, z) + min(y, z)", scope) == 25
    end

    test "string functions with scope and concatenation" do
      scope = %{"first" => "Jane", "last" => "Doe", "greeting" => "Hello"}

      assert ExCellerate.eval!(
               "concat(greeting, ' ', first, ' ', last)",
               scope
             ) == "Hello Jane Doe"
    end

    test "nested ternary with function calls and comparisons" do
      scope = %{"val" => -42}

      # If abs(val) > 100 then "big", else if abs(val) > 10 then "medium", else "small"
      assert ExCellerate.eval!(
               "abs(val) > 100 ? 'big' : (abs(val) > 10 ? 'medium' : 'small')",
               scope
             ) == "medium"
    end

    test "boolean logic across multiple scope values" do
      scope = %{"age" => 25, "has_license" => true, "is_insured" => false}

      assert ExCellerate.eval!(
               "age >= 18 && has_license && is_insured",
               scope
             ) == false

      assert ExCellerate.eval!(
               "age >= 18 && (has_license || is_insured)",
               scope
             ) == true
    end

    test "ifnull with nested access fallback chain" do
      scope = %{"user" => %{"nickname" => nil, "name" => "Alice"}}

      assert ExCellerate.eval!(
               "ifnull(user.nickname, user.name)",
               scope
             ) == "Alice"
    end

    test "modulo and arithmetic with ternary for even/odd" do
      scope = %{"n" => 17}

      assert ExCellerate.eval!("n % 2 == 0 ? 'even' : 'odd'", scope) == "odd"
      assert ExCellerate.eval!("(n + 1) % 2 == 0 ? 'even' : 'odd'", scope) == "even"
    end

    test "compiled function reused across different complex scopes" do
      {:ok, fun} =
        ExCellerate.compile(
          "abs(a - b) > threshold ? concat(label, ': ALERT') : concat(label, ': OK')"
        )

      assert fun.(%{"a" => 100, "b" => 50, "threshold" => 30, "label" => "Sensor1"}) ==
               "Sensor1: ALERT"

      assert fun.(%{"a" => 10, "b" => 12, "threshold" => 5, "label" => "Sensor2"}) ==
               "Sensor2: OK"
    end

    test "mixed dot and bracket access with computation" do
      scope = %{
        "data" => %{
          "matrix" => [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
        },
        "row" => 1,
        "col" => 2
      }

      assert ExCellerate.eval!("data.matrix[row][col]", scope) == 6
    end

    test "power and factorial with scope" do
      scope = %{"base" => 2, "exp" => 10}
      assert ExCellerate.eval!("base ^ exp", scope) == 1024.0
    end

    test "substring and contains on scope strings" do
      scope = %{"email" => "alice@example.com"}

      assert ExCellerate.eval!("contains(email, '@')", scope) == true
      assert ExCellerate.eval!("substring(email, 0, 5)", scope) == "alice"
    end

    test "normalize with concatenation from scope" do
      scope = %{"category" => "Office Supplies", "id" => 42}

      assert ExCellerate.eval!(
               "concat(normalize(category), '_', id)",
               scope
             ) == "office_supplies_42"
    end
  end
end

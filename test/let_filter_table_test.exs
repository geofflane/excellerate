defmodule ExCellerate.LetFilterTableTest do
  use ExUnit.Case, async: true

  describe "let" do
    test "binds a name and uses it in the body" do
      scope = %{
        "orders" => [
          %{"product" => "Widget", "price" => 10, "qty" => 2},
          %{"product" => "Gadget", "price" => 5, "qty" => 1}
        ]
      }

      assert ExCellerate.eval!(
               "let(total, sum(orders[*].(qty * price)), total + 5)",
               scope
             ) == 30
    end

    test "lexical scoping shadows outer variables" do
      scope = %{"x" => 10, "y" => 3}

      assert ExCellerate.eval!("let(x, 2, x + y)", scope) == 5
      assert ExCellerate.eval!("x + y", scope) == 13
    end

    test "nested let uses inner binding only inside its body" do
      assert ExCellerate.eval!("let(x, 2, let(x, 5, x) + x)") == 7
    end

    test "let works with struct scope without mutating it" do
      uri = URI.parse("https://example.com")

      assert ExCellerate.eval!("let(host, 'override', host)", uri) == "override"
      assert ExCellerate.eval!("scheme", uri) == "https"
    end

    test "rejects too few arguments" do
      assert {:error, %ExCellerate.Error{type: :compiler, message: msg}} =
               ExCellerate.eval("let(x, 1)")

      assert msg =~ "let"
      assert msg =~ "3 arguments"
    end

    test "rejects too many arguments" do
      assert {:error, %ExCellerate.Error{type: :compiler, message: msg}} =
               ExCellerate.eval("let(x, 1, 2, 3)")

      assert msg =~ "let"
      assert msg =~ "3 arguments"
    end

    test "works inside compile/2 across multiple calls" do
      {:ok, fun} = ExCellerate.compile("let(x, price * 2, x + 1)")

      assert fun.(%{"price" => 10}) == 21
      assert fun.(%{"price" => 5}) == 11
    end

    test "binds a list value" do
      scope = %{
        "orders" => [
          %{"qty" => 2},
          %{"qty" => 1},
          %{"qty" => 5}
        ]
      }

      assert ExCellerate.eval!("let(items, orders, sum(items[*].qty))", scope) == 8
    end

    test "binds null and uses ifnull" do
      assert ExCellerate.eval!("let(x, null, ifnull(x, 42))") == 42
    end

    test "body uses bound variable multiple times" do
      assert ExCellerate.eval!("let(x, 3, x * x + x)") == 12
    end

    test "nested let with different variable names" do
      assert ExCellerate.eval!("let(x, 1, let(y, 2, x + y))") == 3
    end

    test "three-deep nested let" do
      assert ExCellerate.eval!("let(a, 1, let(b, 2, let(c, 3, a + b + c)))") == 6
    end

    test "bound variable used as function argument" do
      assert ExCellerate.eval!("let(n, 5, abs(n - 10))") == 5
    end

    test "rejects non-identifier first argument" do
      assert {:error, %ExCellerate.Error{type: :compiler, message: msg}} =
               ExCellerate.eval("let(1, 2, 3)")

      assert msg =~ "let"
      assert msg =~ "variable name"
    end

    test "let binding visible inside computed spread" do
      scope = %{
        "orders" => [
          %{"product" => "A", "qty" => 10},
          %{"product" => "B", "qty" => 2},
          %{"product" => "C", "qty" => 7}
        ]
      }

      result =
        ExCellerate.eval!(
          "let(threshold, 5, filter(orders, orders[*].(qty > threshold)))",
          scope
        )

      assert result == [
               %{"product" => "A", "qty" => 10},
               %{"product" => "C", "qty" => 7}
             ]
    end

    test "outer scope variable visible inside computed spread" do
      scope = %{
        "tax_rate" => 0.1,
        "orders" => [
          %{"price" => 100},
          %{"price" => 200}
        ]
      }

      assert ExCellerate.eval!("orders[*].(price * tax_rate)", scope) == [10.0, 20.0]
    end

    test "let binding visible in computed spread with struct scope" do
      # Structs as scope root — let bindings and struct fields must both
      # be accessible inside computed spread expressions.
      uri = URI.parse("https://example.com")
      scope = Map.put(uri, "items", [%{"name" => "A"}, %{"name" => "B"}])

      assert ExCellerate.eval!("let(h, host, items[*].(concat(name, h)))", scope) ==
               ["Aexample.com", "Bexample.com"]
    end
  end

  describe "filter" do
    test "filters a list using a computed spread predicate" do
      scope = %{
        "orders" => [
          %{"id" => 1, "qty" => 2},
          %{"id" => 2, "qty" => 1},
          %{"id" => 3, "qty" => 5}
        ]
      }

      assert ExCellerate.eval!("filter(orders, orders[*].(qty > 1))", scope) == [
               %{"id" => 1, "qty" => 2},
               %{"id" => 3, "qty" => 5}
             ]
    end

    test "returns error when predicate is not a list" do
      scope = %{"orders" => [1, 2, 3]}

      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("filter(orders, true)", scope)

      assert msg =~ "filter"
      assert msg =~ "list"
    end

    test "returns error when predicate values are not booleans" do
      scope = %{
        "orders" => [
          %{"qty" => 2},
          %{"qty" => 1}
        ]
      }

      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("filter(orders, orders[*].qty)", scope)

      assert msg =~ "filter"
      assert msg =~ "boolean"
    end

    test "returns error when predicate list length differs" do
      scope = %{"orders" => [1, 2], "mask" => [true]}

      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("filter(orders, mask)", scope)

      assert msg =~ "filter"
      assert msg =~ "length"
    end

    test "returns empty list when filtering empty list" do
      scope = %{"items" => [], "mask" => []}
      assert ExCellerate.eval!("filter(items, mask)", scope) == []
    end

    test "filter result spread directly without let" do
      scope = %{
        "orders" => [
          %{"id" => 1, "qty" => 2},
          %{"id" => 2, "qty" => 1},
          %{"id" => 3, "qty" => 5}
        ]
      }

      assert ExCellerate.eval!(
               "sum(filter(orders, orders[*].(qty > 1))[*].qty)",
               scope
             ) == 7
    end
  end

  describe "table" do
    test "builds a list of maps from spread columns" do
      scope = %{
        "orders" => [
          %{"product" => "Widget", "price" => 10, "qty" => 2},
          %{"product" => "Gadget", "price" => 5, "qty" => 1}
        ]
      }

      assert ExCellerate.eval!(
               "table('product', orders[*].product, 'total', orders[*].(qty * price))",
               scope
             ) == [
               %{"product" => "Widget", "total" => 20},
               %{"product" => "Gadget", "total" => 5}
             ]
    end

    test "rejects non-string keys" do
      scope = %{
        "orders" => [%{"price" => 10, "qty" => 2}],
        "k" => 123
      }

      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("table(k, orders[*].price)", scope)

      assert msg =~ "table"
      assert msg =~ "string"
    end

    test "rejects non-list values" do
      scope = %{"x" => 42}

      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("table('col', x)", scope)

      assert msg =~ "table"
      assert msg =~ "list"
    end

    test "rejects odd number of arguments" do
      scope = %{
        "orders" => [%{"price" => 10, "qty" => 2}]
      }

      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("table('total', orders[*].price, 'extra')", scope)

      assert msg =~ "table"
      assert msg =~ "even"
    end

    test "rejects zero arguments" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("table()")

      assert msg =~ "table"
      assert msg =~ "even"
    end

    test "rejects lists of different lengths" do
      scope = %{
        "a" => [1, 2, 3],
        "b" => [10, 20]
      }

      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("table('x', a, 'y', b)", scope)

      assert msg =~ "table"
      assert msg =~ "length"
    end

    test "builds table with empty lists" do
      scope = %{"a" => [], "b" => []}

      assert ExCellerate.eval!("table('x', a, 'y', b)", scope) == []
    end
  end

  describe "let + filter + table integration" do
    setup do
      scope = %{
        "orders" => [
          %{"product" => "Widget", "price" => 10, "qty" => 5},
          %{"product" => "Gadget", "price" => 3, "qty" => 1},
          %{"product" => "Gizmo", "price" => 8, "qty" => 3}
        ]
      }

      %{scope: scope}
    end

    test "table with spread columns", %{scope: scope} do
      result =
        ExCellerate.eval!(
          "table('name', orders[*].product, 'total', orders[*].(qty * price))",
          scope
        )

      assert result == [
               %{"name" => "Widget", "total" => 50},
               %{"name" => "Gadget", "total" => 3},
               %{"name" => "Gizmo", "total" => 24}
             ]
    end

    test "let binds filtered list then aggregates", %{scope: scope} do
      result =
        ExCellerate.eval!(
          "let(big, filter(orders, orders[*].(qty > 1)), sum(big[*].price))",
          scope
        )

      assert result == 18
    end

    test "full pipeline: filter, table, and aggregate", %{scope: scope} do
      # Filter to large orders, build a summary table, then sum the totals
      result =
        ExCellerate.eval!(
          "let(big, filter(orders, orders[*].(qty > 1)), table('product', big[*].product, 'total', big[*].(qty * price)))",
          scope
        )

      assert result == [
               %{"product" => "Widget", "total" => 50},
               %{"product" => "Gizmo", "total" => 24}
             ]
    end

    test "nested let with filter and sum", %{scope: scope} do
      result =
        ExCellerate.eval!(
          "let(big, filter(orders, orders[*].(qty > 1)), let(total, sum(big[*].(qty * price)), total * 2))",
          scope
        )

      # big = [Widget(50), Gizmo(24)] -> sum = 74 -> 74 * 2 = 148
      assert result == 148
    end

    test "len of table result", %{scope: scope} do
      result =
        ExCellerate.eval!(
          "len(table('product', orders[*].product, 'total', orders[*].(qty * price)))",
          scope
        )

      assert result == 3
    end

    test "sum of table column via spread", %{scope: scope} do
      # Build a table, then spread into the total column and sum it
      result =
        ExCellerate.eval!(
          "let(summary, table('product', orders[*].product, 'total', orders[*].(qty * price)), sum(summary[*].total))",
          scope
        )

      # 50 + 3 + 24 = 77
      assert result == 77
    end

    test "filter then table then aggregate in one expression", %{scope: scope} do
      result =
        ExCellerate.eval!(
          "let(big, filter(orders, orders[*].(qty > 1)), let(summary, table('product', big[*].product, 'total', big[*].(qty * price)), sum(summary[*].total)))",
          scope
        )

      # big = [Widget(qty=5), Gizmo(qty=3)]
      # summary = [%{product: Widget, total: 50}, %{product: Gizmo, total: 24}]
      # sum = 74
      assert result == 74
    end
  end
end

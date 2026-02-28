defmodule ExCellerate.SpreadTest do
  use ExUnit.Case, async: true

  describe "spread notation" do
    setup do
      scope = %{
        "orders" => [
          %{"product" => "Widget", "price" => 10, "qty" => 2},
          %{"product" => "Gadget", "price" => 25, "qty" => 1},
          %{"product" => "Thing", "price" => 5, "qty" => 10}
        ]
      }

      {:ok, scope: scope}
    end

    test "extracts a column from a list of maps", %{scope: scope} do
      assert ExCellerate.eval!("orders[*].price", scope) == [10, 25, 5]
      assert ExCellerate.eval!("orders[*].product", scope) == ["Widget", "Gadget", "Thing"]
    end

    test "sum over a column", %{scope: scope} do
      assert ExCellerate.eval!("sum(orders[*].price)", scope) == 40
    end

    test "avg over a column", %{scope: scope} do
      assert_in_delta ExCellerate.eval!("avg(orders[*].qty)", scope), 4.333, 0.01
    end

    test "max over a column", %{scope: scope} do
      assert ExCellerate.eval!("max(orders[*].price)", scope) == 25
    end

    test "min over a column", %{scope: scope} do
      assert ExCellerate.eval!("min(orders[*].price)", scope) == 5
    end

    test "len counts items in spread result", %{scope: scope} do
      assert ExCellerate.eval!("len(orders[*].product)", scope) == 3
    end

    test "textjoin over a column", %{scope: scope} do
      assert ExCellerate.eval!("textjoin(', ', orders[*].product)", scope) ==
               "Widget, Gadget, Thing"
    end

    test "deep nested access after spread" do
      scope = %{
        "users" => [
          %{"profile" => %{"name" => "Alice"}},
          %{"profile" => %{"name" => "Bob"}}
        ]
      }

      assert ExCellerate.eval!("users[*].profile.name", scope) == ["Alice", "Bob"]
    end

    test "nested spread flattens results" do
      scope = %{
        "departments" => [
          %{"employees" => [%{"name" => "Alice"}, %{"name" => "Bob"}]},
          %{"employees" => [%{"name" => "Carol"}]}
        ]
      }

      assert ExCellerate.eval!("departments[*].employees[*].name", scope) ==
               ["Alice", "Bob", "Carol"]
    end

    test "spread with compiled function", %{scope: scope} do
      {:ok, fun} = ExCellerate.compile("sum(orders[*].price)")
      assert fun.(scope) == 40

      other_scope = %{
        "orders" => [
          %{"price" => 100},
          %{"price" => 200}
        ]
      }

      assert fun.(other_scope) == 300
    end

    test "spread on simple list of values" do
      scope = %{"numbers" => [1, 2, 3, 4, 5]}
      assert ExCellerate.eval!("sum(numbers)", scope) == 15
    end

    test "spread with atom-keyed maps" do
      scope = %{"items" => [%{name: "a", value: 1}, %{name: "b", value: 2}]}
      assert ExCellerate.eval!("items[*].value", scope) == [1, 2]
      assert ExCellerate.eval!("sum(items[*].value)", scope) == 3
    end

    test "spread with mixed nesting depths" do
      scope = %{
        "data" => %{
          "rows" => [
            %{"scores" => [10, 20, 30]},
            %{"scores" => [40, 50]}
          ]
        }
      }

      # First get the scores arrays
      assert ExCellerate.eval!("data.rows[*].scores", scope) == [[10, 20, 30], [40, 50]]
    end

    test "nested spread flattens across multiple levels" do
      scope = %{
        "data" => %{
          "rows" => [
            %{"scores" => [10, 20, 30]},
            %{"scores" => [40, 50]}
          ]
        }
      }

      # Nested spread should flatten the inner lists
      assert ExCellerate.eval!("sum(data.rows[*].scores[*])", scope) == 150
    end

    test "spread through list of lists" do
      scope = %{"matrix" => [[1, 2], [3, 4], [5, 6]]}
      assert ExCellerate.eval!("sum(matrix[*][*])", scope) == 21
    end

    test "spread with struct values" do
      scope = %{
        "endpoints" => [
          URI.parse("https://api.example.com"),
          URI.parse("https://cdn.example.com")
        ]
      }

      assert ExCellerate.eval!("endpoints[*].host", scope) ==
               ["api.example.com", "cdn.example.com"]
    end

    test "spread result used in contains" do
      scope = %{
        "tags" => [
          %{"label" => "urgent"},
          %{"label" => "review"},
          %{"label" => "bug"}
        ]
      }

      assert ExCellerate.eval!("contains(textjoin(',', tags[*].label), 'urgent')", scope) == true
    end

    test "spread with single-element list" do
      scope = %{"items" => [%{"val" => 42}]}
      assert ExCellerate.eval!("items[*].val", scope) == [42]
      assert ExCellerate.eval!("sum(items[*].val)", scope) == 42
    end

    test "spread with empty list" do
      scope = %{"items" => []}
      assert ExCellerate.eval!("items[*].val", scope) == []
    end

    test "specific index after spread" do
      scope = %{
        "data" => %{
          "rows" => [
            %{"scores" => [10, 20, 30]},
            %{"scores" => [40, 50, 60]}
          ]
        }
      }

      # Get the second score from each row
      assert ExCellerate.eval!("data.rows[*].scores[1]", scope) == [20, 50]
      assert ExCellerate.eval!("sum(data.rows[*].scores[0])", scope) == 50
    end

    test "dot access after spread then bracket index" do
      scope = %{
        "teams" => [
          %{"members" => [%{"name" => "Alice"}, %{"name" => "Bob"}]},
          %{"members" => [%{"name" => "Carol"}, %{"name" => "Dave"}]}
        ]
      }

      # Get the first member's name from each team
      assert ExCellerate.eval!("teams[*].members[0].name", scope) == ["Alice", "Carol"]
    end
  end

  describe "computed spread" do
    setup do
      scope = %{
        "orders" => [
          %{"product" => "Widget", "price" => 10, "qty" => 2},
          %{"product" => "Gadget", "price" => 25, "qty" => 1},
          %{"product" => "Thing", "price" => 5, "qty" => 10}
        ]
      }

      {:ok, scope: scope}
    end

    test "per-row arithmetic", %{scope: scope} do
      assert ExCellerate.eval!("orders[*].(qty * price)", scope) == [20, 25, 50]
    end

    test "aggregate over computed spread", %{scope: scope} do
      assert ExCellerate.eval!("sum(orders[*].(qty * price))", scope) == 95
    end

    test "avg over computed spread", %{scope: scope} do
      assert_in_delta ExCellerate.eval!("avg(orders[*].(qty * price))", scope), 31.666, 0.01
    end

    test "max over computed spread", %{scope: scope} do
      assert ExCellerate.eval!("max(orders[*].(qty * price))", scope) == 50
    end

    test "computed spread with function calls", %{scope: scope} do
      assert ExCellerate.eval!("orders[*].(upper(product))", scope) ==
               ["WIDGET", "GADGET", "THING"]
    end

    test "computed spread with string concatenation", %{scope: scope} do
      assert ExCellerate.eval!("orders[*].(concat(product, ': ', qty))", scope) ==
               ["Widget: 2", "Gadget: 1", "Thing: 10"]
    end

    test "computed spread with ternary", %{scope: scope} do
      assert ExCellerate.eval!("orders[*].(qty > 5 ? 'bulk' : 'single')", scope) ==
               ["single", "single", "bulk"]
    end

    test "computed spread with complex expression", %{scope: scope} do
      # qty * price with 10% tax
      result = ExCellerate.eval!("orders[*].(qty * price * 1.1)", scope)
      assert_in_delta Enum.at(result, 0), 22.0, 0.01
      assert_in_delta Enum.at(result, 1), 27.5, 0.01
      assert_in_delta Enum.at(result, 2), 55.0, 0.01
    end

    test "computed spread with nested access" do
      scope = %{
        "users" => [
          %{"profile" => %{"scores" => [10, 20]}, "name" => "Alice"},
          %{"profile" => %{"scores" => [30, 40]}, "name" => "Bob"}
        ]
      }

      assert ExCellerate.eval!("users[*].(concat(name, ': ', profile.scores[0]))", scope) ==
               ["Alice: 10", "Bob: 30"]
    end

    test "compiled computed spread", %{scope: scope} do
      {:ok, fun} = ExCellerate.compile("sum(orders[*].(qty * price))")
      assert fun.(scope) == 95

      other = %{
        "orders" => [
          %{"price" => 100, "qty" => 3},
          %{"price" => 200, "qty" => 2}
        ]
      }

      assert fun.(other) == 700
    end
  end
end

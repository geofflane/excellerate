defmodule ExCellerate.DataAccessTest do
  use ExUnit.Case, async: true

  describe "variables and data structures" do
    test "accesses variables in scope" do
      assert ExCellerate.eval!("a", %{"a" => 10}) == 10
      assert ExCellerate.eval!("var_name", %{"var_name" => 42}) == 42
      assert ExCellerate.eval!("atom_key", %{atom_key: 7}) == 7
    end

    test "accesses nested map values via dot notation" do
      assert ExCellerate.eval!("map.key", %{"map" => %{"key" => 2}}) == 2
      assert ExCellerate.eval!("a.b.c", %{"a" => %{"b" => %{"c" => 3}}}) == 3
    end

    test "accesses list values via bracket notation" do
      assert ExCellerate.eval!("list[1]", %{"list" => [1, 2, 3]}) == 2
      assert ExCellerate.eval!("map.list[0].v", %{"map" => %{"list" => [%{"v" => 2}]}}) == 2
    end

    test "returns error for missing variables" do
      case ExCellerate.eval("unknown", %{}) do
        {:error, %ExCellerate.Error{message: msg}} ->
          assert msg =~ "Function or variable not found: unknown"

        other ->
          flunk("Expected ExCellerate.Error, got #{inspect(other)}")
      end
    end
  end

  describe "struct access" do
    test "struct fields accessible via dot notation in scope" do
      uri = URI.parse("https://example.com/path")
      scope = %{"uri" => uri}

      assert ExCellerate.eval!("uri.host", scope) == "example.com"
      assert ExCellerate.eval!("uri.scheme", scope) == "https"
      assert ExCellerate.eval!("uri.path", scope) == "/path"
    end

    test "struct as top-level scope with atom keys" do
      uri = URI.parse("https://example.com/path")
      assert ExCellerate.eval!("host", uri) == "example.com"
      assert ExCellerate.eval!("scheme", uri) == "https"
    end

    test "nested struct access" do
      scope = %{
        "config" => %{
          "endpoint" => URI.parse("https://api.example.com/v1")
        }
      }

      assert ExCellerate.eval!("config.endpoint.host", scope) == "api.example.com"
    end

    test "struct field in arithmetic expression" do
      scope = %{"uri" => URI.parse("https://example.com:8080")}
      assert ExCellerate.eval!("uri.port + 1", scope) == 8081
    end

    test "struct field in function call" do
      scope = %{"uri" => URI.parse("https://example.com/path")}
      assert ExCellerate.eval!("contains(uri.host, 'example')", scope) == true
    end

    test "struct field with ternary" do
      scope = %{"uri" => URI.parse("https://example.com")}

      assert ExCellerate.eval!(
               "uri.scheme == 'https' ? 'secure' : 'insecure'",
               scope
             ) == "secure"
    end
  end

  describe "scope edge cases" do
    test "string key takes precedence over atom key" do
      scope = %{"x" => 1, x: 2}
      assert ExCellerate.eval!("x", scope) == 1
    end

    test "non-function scope variable called as function returns error" do
      scope = %{"notfunc" => 42}
      assert {:error, _} = ExCellerate.eval("notfunc(1)", scope)
    end

    test "scope variable shadows builtin when not called as function" do
      scope = %{"abs" => 42}
      assert ExCellerate.eval!("abs", scope) == 42
    end

    test "negate a variable" do
      assert ExCellerate.eval!("-a", %{"a" => 5}) == -5
    end
  end

  # ── Bug regression tests ──────────────────────────────────────────

  describe "sentinel collision bug" do
    test "map value of :not_found is returned correctly" do
      scope = %{"m" => %{"k" => :not_found}}
      assert ExCellerate.eval!("m.k", scope) == :not_found
    end

    test "list value of :not_found is returned correctly" do
      scope = %{"l" => [:not_found, :ok]}
      assert ExCellerate.eval!("l[0]", scope) == :not_found
    end
  end

  describe "type edge cases" do
    test "nil in arithmetic returns error" do
      assert {:error, _} = ExCellerate.eval("a + 1", %{"a" => nil})
    end

    test "boolean in arithmetic returns error" do
      assert {:error, _} = ExCellerate.eval("true + 1")
    end

    test "ternary treats 0 as truthy (Elixir semantics)" do
      assert ExCellerate.eval!("0 ? 'yes' : 'no'") == "yes"
    end

    test "ternary treats empty string as truthy" do
      assert ExCellerate.eval!("'' ? 'yes' : 'no'") == "yes"
    end

    test "ternary treats null as falsy" do
      assert ExCellerate.eval!("null ? 'yes' : 'no'") == "no"
    end
  end
end

# ExCellerate

ExCellerate is a high-performance, extensible expression evaluation engine for Elixir. It parses text-based expressions into an intermediate representation (IR) and compiles them directly into native Elixir AST for near-native execution speed.

## Features

- **Blazing Fast**: Compiles expressions to native Elixir code and caches the results using ETS for near-instant repeated evaluations.
- **Robust Error System**: Detailed error reporting for Parsing, Compilation, and Runtime issues via `ExCellerate.Error`.
- **Validation Support**: Built-in `validate/1` to check syntax and function existence without execution.
- **Flexible Data Access**: Seamlessly access nested maps (`user.profile.name`) and lists (`data[0]`).

## Built-in Functions

### Math

- Arithmetic: `+`, `-`, `*`, `/`, `^`, `%`
- Bitwise: `&&&`, `|||`, `^^^`, `<<<`, `>>>`, `~~~`
- `abs(n)`: Absolute value of `n`.
- `round(n)`: Rounds `n` to the nearest integer.
- `floor(n)`: Largest integer less than or equal to `n`.
- `ceil(n)`: Smallest integer greater than or equal to `n`.
- `max(a, b)`: Returns the larger of `a` and `b`.
- `min(a, b)`: Returns the smaller of `a` and `b`.

### Boolean

- Logical: `&&`, `||`, `!`, `not`
- Comparison: `==`, `!=`, `<`, `>`, `<=`, `>=`
- Advanced: Factorials (`n!`) and Ternary operators (`cond ? true : false`).

### Utility & String

- `if(cond, true_val, false_val)`: Functional if-statement.
- `ifnull(val, default)`: Returns `default` if `val` is `nil`, otherwise returns `val`.
- `concat(a, b, ...)`: Concatenates any number of arguments into a single string.
- `lookup(collection, key, default \\ nil)`:
  - For maps: Looks up `key` in the map.
  - For lists: Returns the element at the integer `key` (index).
  - Returns `default` if the value is not found or is `nil`.
- `normalize(string)`: Downcases the string and replaces all spaces with underscores (e.g., `"Foo Bar"` -> `"foo_bar"`).
- `substring(string, start, length \\ nil)`: Returns a subset of the string.
- `contains(string, search_term)`: Returns `true` if `search_term` exists within `string`.

## Error Handling

ExCellerate follows the standard Elixir convention of `eval/3` and `eval!/3` variants:

- `ExCellerate.eval/3` returns `{:ok, result}` on success or `{:error, reason}` on failure.
- `ExCellerate.eval!/3` returns the bare result on success or raises on failure.

```elixir
# Safe variant — returns ok/error tuples
case ExCellerate.eval("1 + * 2") do
  {:ok, result} ->
    IO.puts("Result: #{result}")

  {:error, %ExCellerate.Error{type: :parser} = e} ->
    IO.puts("Syntax error: #{Exception.message(e)}")

  {:error, %ExCellerate.Error{type: :runtime} = e} ->
    IO.puts("Runtime error: #{Exception.message(e)}")
end

# Bang variant — raises on error
result = ExCellerate.eval!("1 + 2 * 3")
```

## Examples

### Basic Expressions

```elixir
ExCellerate.eval!("1 + 2 * 3")
# => 7

ExCellerate.eval!("5!")
# => 120

ExCellerate.eval!("10 % 3")
# => 1
```

### Variables and Nested Access

Expressions can reference variables from a scope map. Nested maps and lists are accessed with dot notation and bracket indexing:

```elixir
scope = %{
  "order" => %{
    "items" => [
      %{"name" => "Widget", "price" => 10.50, "qty" => 2},
      %{"name" => "Gadget", "price" => 7.25, "qty" => 3}
    ],
    "discount" => 5
  }
}

ExCellerate.eval!("order.items[0].price * order.items[0].qty", scope)
# => 21.0

ExCellerate.eval!("order.items[1].name", scope)
# => "Gadget"
```

### Combining Functions, Arithmetic, and Logic

```elixir
scope = %{"price" => 25.0, "quantity" => 4, "tax_rate" => 0.08}
ExCellerate.eval!("price * quantity * (1 + tax_rate)", scope)
# => 108.0

scope = %{"score" => 85, "threshold" => 70, "bonus" => 10}
ExCellerate.eval!("score + bonus >= 90 ? 'A' : 'B'", scope)
# => "A"

scope = %{"x" => -15, "y" => 7, "z" => 3}
ExCellerate.eval!("abs(x) + max(y, z) + min(y, z)", scope)
# => 25
```

### String Functions

```elixir
scope = %{"first" => "Jane", "last" => "Doe"}
ExCellerate.eval!("concat(first, ' ', last)", scope)
# => "Jane Doe"

scope = %{"email" => "alice@example.com"}
ExCellerate.eval!("contains(email, '@')", scope)
# => true

ExCellerate.eval!("substring(email, 0, 5)", scope)
# => "alice"

scope = %{"category" => "Office Supplies", "id" => 42}
ExCellerate.eval!("concat(normalize(category), '_', id)", scope)
# => "office_supplies_42"
```

### Working with Structs

Structs in scope are accessed the same way as maps. Field names are resolved to atom keys automatically:

```elixir
uri = URI.parse("https://api.example.com:8080/v1")
scope = %{"endpoint" => uri}

ExCellerate.eval!("endpoint.host", scope)
# => "api.example.com"

ExCellerate.eval!("endpoint.port + 1", scope)
# => 8081

ExCellerate.eval!("endpoint.scheme == 'https' ? 'secure' : 'insecure'", scope)
# => "secure"

ExCellerate.eval!("contains(endpoint.host, 'example')", scope)
# => true
```

Nested structs work too:

```elixir
scope = %{
  "config" => %{
    "endpoint" => URI.parse("https://api.example.com/v1")
  }
}

ExCellerate.eval!("config.endpoint.host", scope)
# => "api.example.com"
```

### Scope with Atom Keys

Scope maps can use either string or atom keys. String keys take precedence when both exist:

```elixir
ExCellerate.eval!("name", %{name: "Alice"})
# => "Alice"

ExCellerate.eval!("host", URI.parse("https://example.com"))
# => "example.com"
```

## Validation

You can validate an expression's syntax and function calls without executing it:

```elixir
:ok = ExCellerate.validate("abs(-10)")
{:error, %ExCellerate.Error{}} = ExCellerate.validate("invalid(1, 2)")
```

## Pre-compilation

For maximum performance, you can compile an expression once and reuse it with different scopes. The compiled function skips parsing and AST generation on subsequent calls:

```elixir
{:ok, fun} = ExCellerate.compile("price * quantity * (1 - discount)")

fun.(%{"price" => 100, "quantity" => 3, "discount" => 0.1})
# => 270.0

fun.(%{"price" => 50, "quantity" => 10, "discount" => 0.2})
# => 400.0

# Bang variant
fun = ExCellerate.compile!("a + b")
fun.(%{"a" => 1, "b" => 2})
# => 3
```

## Performance & Caching

ExCellerate caches compiled functions in an ETS table for fast repeated evaluations. To enable caching, add `ExCellerate.Cache` to your application's supervision tree:

```elixir
# In your Application module (e.g., lib/my_app/application.ex)
def start(_type, _args) do
  children = [
    ExCellerate.Cache,
    # ... your other children
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

If the cache is not started, ExCellerate still works — expressions will simply be parsed and compiled on every call.

### Configuring Caching in a Registry

```elixir
defmodule MyRegistry do
  use ExCellerate.Registry,
    plugins: [...],
    cache_enabled: true,    # Default: true
    cache_limit: 5000       # Default: 1000
end
```

If `cache_enabled` is set to `false`, every call to `eval/2` will re-parse and re-compile the expression.

### Global Defaults

While per-registry configuration is preferred, you can still provide global defaults for expressions evaluated via `ExCellerate.eval/3` without a custom registry using Application environment variables:

```elixir
config :excellerate,
  cache_enabled: true,
  cache_limit: 1000
```

## Custom Registries and Overrides

ExCellerate is designed for performance and extensibility. The way to add or override behavior is by creating a dedicated Registry module. This compiles the function dispatch logic once, providing better performance.

### 1. Define your Custom Functions

```elixir
defmodule MyApp.Functions.Greet do
  @behaviour ExCellerate.Function

  def name, do: "greet"
  def arity, do: 1
  def call([name]), do: "Hello, #{name}!"
end

defmodule MyApp.Functions.CustomAbs do
  @behaviour ExCellerate.Function
  def name, do: "abs" # This will override the built-in abs()
  def arity, do: 1
  def call([_]), do: 42
end
```

### 2. Create your Registry

```elixir
defmodule MyApp.Registry do
  use ExCellerate.Registry, plugins: [
    MyApp.Functions.Greet,
    MyApp.Functions.CustomAbs
  ]
end
```

### 3. Use your Registry

```elixir
# Use the eval!/2 function generated in your registry
MyApp.Registry.eval!("greet('World')")
# => "Hello, World!"

# Overridden functions work as expected
MyApp.Registry.eval!("abs(-100)")
# => 42

# Default functions (not overridden) are still available
MyApp.Registry.eval!("max(10, 20)")
# => 20
```

## Pros and Cons

### Pros

- **Performance**: By compiling to Elixir AST and caching results in ETS, ExCellerate avoids redundant parsing and provides execution speeds matching native Elixir.
- **Safety**: Expressions are compiled into a restricted subset of Elixir, preventing arbitrary code execution.
- **Error Handling**: Detailed structs identify exactly where and why an expression failed (e.g., line/column for parse errors).
- **Extensibility**: The registry system makes it easy to add domain-specific logic without modifying the core library.
- **Readability**: Uses a familiar, Excel-like or C-style syntax for expressions.

### Cons

- **First-run Overhead**: The very first time an expression is encountered, it must be parsed and compiled. Subsequent calls use the cache.
- **Static Resolution**: Custom functions are resolved at compile-time (in registries) or lookup-time, which might be slightly slower than hardcoded Elixir calls.

## Security

ExCellerate uses `Code.eval_quoted/3` internally to compile expressions into reusable anonymous functions. This happens once per unique expression (the result is cached). While `eval_quoted` may raise concerns, the expression input is not evaluated directly — it passes through two controlled stages:

1. **Parsing**: The NimbleParsec parser only accepts a fixed grammar. Arbitrary Elixir code (e.g., `System.cmd/2`, `File.rm/1`) cannot be expressed in the parser's syntax and will be rejected as parse errors.

2. **Compilation**: The compiler only generates AST for a restricted set of operations: arithmetic, comparisons, logical/bitwise operators, data access (`Map.fetch`, `Access.get`, `Enum.at`), and function calls dispatched through the registry system. No arbitrary module calls, process operations, or I/O are emitted.

The parser is the security boundary. Users cannot inject arbitrary Elixir through an expression string because the parser will not produce IR for it, and the compiler will not generate AST for it.

**When is this safe?**

- Developers writing expressions in config files or application code — no risk, they already have full code access.
- End-users submitting expressions through a UI — the parser constrains what can be expressed. They cannot escape the expression grammar.

**What would constitute a vulnerability?**

A bug in the parser or compiler that causes a crafted expression string to produce unexpected AST. This is a narrow surface area, but if you discover such a case, please report it.

We think that this is a valid analysis of the threat, but we welcome feedback on this security model. If you have concerns or find an issue, please open an issue on the [GitHub repository](https://github.com/matchsense/excellerate).

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and published on [HexDocs](https://hexdocs.pm). Once published, the docs can be found at [https://hexdocs.pm/excellerate](https://hexdocs.pm/excellerate).

## License

ExCellerate is released under the MIT License.

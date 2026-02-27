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

ExCellerate uses a structured error system. Errors return `{:error, %ExCellerate.Error{}}`.

```elixir
case ExCellerate.eval("1 + * 2") do
  {:error, %ExCellerate.Error{type: :parser, line: 1, column: 5} = e} ->
    IO.puts("Syntax error: #{Exception.message(e)}")
  
  {:error, %ExCellerate.Error{type: :runtime} = e} ->
    IO.puts("Runtime error: #{Exception.message(e)}")
end
```

## Validation

You can validate an expression's syntax and function calls without executing it:

```elixir
:ok = ExCellerate.validate("abs(-10)")
{:error, %ExCellerate.Error{}} = ExCellerate.validate("invalid(1, 2)")
```

## Performance & Caching

ExCellerate caches compiled AST in an ETS table for fast repeated evaluations. To enable caching, add `ExCellerate.Cache` to your application's supervision tree:

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

ExCellerate is designed for performance and extensibility. While you can pass functions in the scope, the recommended way to add or override behavior is by creating a dedicated Registry module. This compiles the function dispatch logic once, providing better performance.

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
# Use the eval/2 function generated in your registry
MyApp.Registry.eval("greet('World')")
# => "Hello, World!"

# Overridden functions work as expected
MyApp.Registry.eval("abs(-100)")
# => 42

# Default functions (not overridden) are still available
MyApp.Registry.eval("max(10, 20)")
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

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and published on [HexDocs](https://hexdocs.pm). Once published, the docs can be found at [https://hexdocs.pm/excellerate](https://hexdocs.pm/excellerate).

## License

ExCellerate is released under the MIT License.

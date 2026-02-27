# ExCellerate

ExCellerate is a high-performance, extensible expression evaluation engine for Elixir. It parses text-based expressions into an intermediate representation (IR) and compiles them directly into native Elixir AST for near-native execution speed.

## Features

- **Blazing Fast**: Compiles expressions to native Elixir code, leveraging the BEAM's efficiency.
- **Rich Operator Support**: 
  - Arithmetic: `+`, `-`, `*`, `/`, `^`, `%`
  - Bitwise: `&&&`, `|||`, `^^^`, `<<<`, `>>>`, `~~~`
  - Logical: `&&`, `||`, `!`, `not`
  - Comparison: `==`, `!=`, `<`, `>`, `<=`, `>=`
  - Advanced: Factorials (`n!`) and Ternary operators (`cond ? true : false`).
- **Built-in Functions**: 
  - Math: `abs/1`, `round/1`, `floor/1`, `ceil/1`, `max/2`, `min/2`
  - Utility: `if/3`, `ifnull/2`, `concat/n`, `lookup/2-3`, `normalize/1`
- **Flexible Data Access**: Seamlessly access nested maps (`user.profile.name`) and lists (`data[0]`).
- **Extensible Function Registry**: Easily add custom functions or override default ones globally or per-evaluation.

## Installation
...
MyApp.Registry.eval("max(10, 20)")
# => 20
```

## Built-in Function Reference

### Math Functions
- `abs(n)`: Returns the absolute value of `n`.
- `round(n)`: Rounds `n` to the nearest integer.
- `floor(n)`: Returns the largest integer less than or equal to `n`.
- `ceil(n)`: Returns the smallest integer greater than or equal to `n`.
- `max(a, b)`: Returns the larger of two values.
- `min(a, b)`: Returns the smaller of two values.

### Utility Functions
- `if(condition, then_val, else_val)`: Returns `then_val` if `condition` is truthy, otherwise `else_val`.
- `ifnull(val, default)`: Returns `default` if `val` is `nil`, otherwise returns `val`.
- `concat(arg1, arg2, ...)`: Concatenates all arguments into a single string.
- `lookup(collection, key, default \\ nil)`: 
  - For maps: Looks up `key` in the map.
  - For lists: Returns the element at the integer `key` (index).
  - Returns `default` if the value is not found or is `nil`.
- `normalize(string)`: Downcases the string and replaces all spaces with underscores (e.g., `"Foo Bar"` -> `"foo_bar"`).

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
- **Performance**: By compiling to Elixir AST, ExCellerate avoids the overhead of interpreted loops found in many expression engines.
- **Safety**: Expressions are compiled into a restricted subset of Elixir, preventing arbitrary code execution.
- **Extensibility**: The registry system makes it easy to add domain-specific logic without modifying the core library.
- **Readability**: Uses a familiar, Excel-like or C-style syntax for expressions.

### Cons
- **Compilation Overhead**: There is a small initial cost to compile the expression to AST. For high-frequency evaluations of the same expression, consider caching the compiled result (coming in future versions).
- **Static Resolution**: Custom functions are currently resolved at compile-time (in registries) or lookup-time, which might be slightly slower than hardcoded Elixir calls.

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and published on [HexDocs](https://hexdocs.pm). Once published, the docs can be found at [https://hexdocs.pm/excellerate](https://hexdocs.pm/excellerate).

## License

ExCellerate is released under the MIT License.

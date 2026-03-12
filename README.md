# ExCellerate

[![Hex.pm](https://img.shields.io/hexpm/v/excellerate.svg)](https://hex.pm/packages/excellerate)
[![Hex Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/excellerate)
[![CI](https://github.com/geofflane/excellerate/actions/workflows/elixir.yml/badge.svg)](https://github.com/geofflane/excellerate/actions/workflows/elixir.yml)

ExCellerate is a high-performance, extensible expression evaluation engine for Elixir. It parses text-based expressions into an intermediate representation (IR) and compiles them directly into native Elixir AST for near-native execution speed. It's loosely inspired by spreadsheet style expressions, but since we don't have columns and rows exactly we don't access `A1` and instead rely on path notation into lists and maps.

## Installation

Add it to your mix.exs:

```elixir
def deps do
  [
    {:excellerate, "~> 0.3.0"}
  ]
end
```

### Performance & Caching

ExCellerate caches compiled functions in an ETS-backed LRU (Least Recently Used) cache for fast repeated evaluations. When the cache reaches its size limit, the least recently accessed entries are evicted first, ensuring frequently-used expressions stay cached. To enable caching, add `ExCellerate.Cache` to your application's supervision tree:

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

You can also create your own registry to configure caching and register your own functions (see below).

```elixir
defmodule MyRegistry do
  use ExCellerate.Registry,
    plugins: [...],
    cache_enabled: true,    # Default: true
    cache_limit: 5000       # Default: 1000
end
```

If `cache_enabled` is set to `false`, every call to `eval/2` will re-parse and re-compile the expression.

When the number of cached expressions for a registry exceeds `cache_limit`, the least recently used entries are evicted. Each cache hit updates the entry's last-accessed timestamp, so frequently-used expressions are retained even if they were first compiled long ago.

### Global Defaults

While per-registry configuration is preferred, you can still provide global defaults for expressions evaluated via `ExCellerate.eval/3` without a custom registry using Application environment variables:

```elixir
config :excellerate,
  cache_enabled: true,
  cache_limit: 1000
```

### Custom Registries and Overrides

ExCellerate is designed for performance and extensibility. The way to add or override behavior is by creating a dedicated Registry module. This compiles the function dispatch logic once, providing better performance.

#### 1. Define your Custom Functions

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

#### 2. Create your Registry

```elixir
defmodule MyApp.Registry do
  use ExCellerate.Registry, plugins: [
    MyApp.Functions.Greet,
    MyApp.Functions.CustomAbs
  ]
end
```

#### 3. Use your Registry

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

## Features

- **Blazing Fast**: Compiles expressions to native Elixir code and caches the results using ETS for near-instant repeated evaluations.
- **Robust Error System**: Detailed error reporting for Parsing, Compilation, and Runtime issues via `ExCellerate.Error`.
- **Validation Support**: Built-in `validate/1` to check syntax and function existence without execution.
- **Flexible Data Access**: Seamlessly access nested maps (`user.profile.name`), lists (`data[0]`, `data[-1]`), structs, and column spreads (`orders[*].price`).

## Built-in Functions

### Operators

- **Arithmetic**: `+`, `-`, `*`, `/`, `^` (power), `%` (modulo), `n!` (factorial)
- **Comparison**: `==`, `!=`, `<`, `>`, `<=`, `>=`
- **Logical**: `&&`, `||`, `not`
- **Bitwise**: `&`, `|`, `|^` (xor), `<<`, `>>`, `~` (bnot)
- **Ternary**: `condition ? true_val : false_val`

### Math Functions

- `abs(n)`: Absolute value.
- `round(n)` / `round(n, digits)`: Rounds to the nearest integer, or to `digits` decimal places. Negative digits round left of the decimal.
- `floor(n)`: Largest integer less than or equal to `n`.
- `ceil(n)`: Smallest integer greater than or equal to `n`.
- `trunc(n)`: Truncates toward zero (unlike `floor` for negatives).
- `max(a, b, ...)` / `max(list)`: Maximum of arguments or a list.
- `min(a, b, ...)` / `min(list)`: Minimum of arguments or a list.
- `sign(n)`: Returns -1, 0, or 1.
- `sqrt(n)`: Square root.
- `exp(n)`: e raised to the power `n`.
- `ln(n)`: Natural logarithm (base e).
- `log(n, base)`: Logarithm with specified base.
- `log10(n)`: Base-10 logarithm.
- `sum(a, b, ...)` / `sum(list)`: Sums arguments or a list.
- `avg(a, b, ...)` / `avg(list)`: Arithmetic mean of arguments or a list.

### String Functions

- `len(s)` / `len(list)`: String length or list length.
- `left(s)` / `left(s, n)`: First character (default), or first `n` characters.
- `right(s)` / `right(s, n)`: Last character (default), or last `n` characters.
- `substring(s, start, length \\ nil)`: Substring by position and optional length.
- `upper(s)`: Converts to uppercase.
- `lower(s)`: Converts to lowercase.
- `trim(s)`: Removes leading and trailing whitespace.
- `concat(a, b, ...)`: Concatenates any number of arguments into a string.
- `textjoin(delimiter, a, b, ...)`: Joins values with a delimiter.
- `replace(s, old, new)`: Replaces all occurrences of `old` with `new`.
- `find(search, text)` / `find(search, text, start)`: Returns the 0-based position of `search` in `text` (optionally starting from `start`), or -1 if not found.
- `contains(s, term)`: Returns `true` if `term` exists within `s`.
- `underscore(s)`: Converts to underscore case — downcases, replaces spaces and slashes with underscores, strips other non-alphanumeric characters (e.g., `"Foo Bar"` -> `"foo_bar"`).
- `slug(s)`: Converts to a slug — downcases, replaces spaces and slashes with hyphens, strips other non-alphanumeric characters (e.g., `"Foo Bar"` -> `"foo-bar"`).

### Utility Functions

- `if(cond, true_val)` / `if(cond, true_val, false_val)`: Functional if-statement. The 2-arg form returns `nil` when falsy.
- `ifs(cond1, val1, cond2, val2, ...)`: Returns the value for the first truthy condition. Use `true` as the final condition for a default. Returns `nil` if no conditions match.
- `ifnull(val, default)`: Returns `default` if `val` is `nil`.
- `isnull(val)`: Returns `true` if `val` is `nil`, `false` otherwise.
- `isblank(val)`: Returns `true` if `val` is `nil` or a whitespace-only (including empty) string, `false` otherwise.
- `coalesce(a, b, ...)`: Returns the first non-nil value.
- `switch(expr, case1, val1, ..., default)`: Multi-way value matching.
- `and(a, b, ...)`: Returns `true` if all arguments are truthy.
- `or(a, b, ...)`: Returns `true` if any argument is truthy.
- `lookup(collection, key, default \\ nil)`:
  - For maps: Looks up `key` in the map.
  - For lists: Returns the element at the integer `key` (index). Negative indices count from the end.
  - Returns `default` if the value is not found.
- `match(lookup_value, list)` / `match(lookup_value, list, match_type)`: Searches for a value in a list and returns its 0-based position. `match_type` controls matching: `0` (default) for exact match, `1` for the largest value &lt;= `lookup_value` (list must be ascending), `-1` for the smallest value &gt;= `lookup_value` (list must be descending). Returns `null` when no match is found.
- `index(list, row)` / `index(list, row, col)`: Returns a value from a list or 2D array by position (0-based). Negative indices count from the end. For 2D arrays (list of lists), pass both `row` and `col`. Returns `null` for out-of-bounds or `null` positions.
- `sort(a, b, ...)` / `sort(list)`: Sorts values in ascending order.
- `unique(a, b, ...)` / `unique(list)`: Returns unique values, preserving the order of first occurrence.
- `filter(list, predicates)`: Returns items where the corresponding predicate is `true`.
- `table(key1, list1, key2, list2, ...)`: Builds a list of maps from alternating key/list pairs.
- `take(list, rows)` / `take(list, rows, cols)`: Extracts rows, columns, or both from a list or 2D array. Positive counts take from the beginning, negative from the end. Pass `null` to skip a dimension (e.g., `take(data, null, 2)` for columns only).
- `slice(list, start)` / `slice(list, start, length)`: Extracts a contiguous section of a list. Zero-based start index; negative indices count from the end. Without length, returns everything from start to end.

### Date & Time Functions

Date and time functions operate on native Elixir `Date`, `NaiveDateTime`, and `DateTime` structs. Pass dates into expressions via the scope — there is no date literal syntax.

#### Construction

- `date(year, month, day)`: Creates a `Date`.
- `datetime(year, month, day)` / `datetime(year, month, day, hour, minute, second)`: Creates a `NaiveDateTime`. Hour, minute, and second default to `0` when omitted.
- `today()`: Returns the current date as a `Date`.
- `now()`: Returns the current date and time as a `NaiveDateTime`.

#### Extraction

- `year(date)`: Extracts the year.
- `month(date)`: Extracts the month (1-12).
- `day(date)`: Extracts the day of the month (1-31).
- `hour(date)`: Extracts the hour (0-23). Returns `0` for a plain `Date`.
- `minute(date)`: Extracts the minute (0-59). Returns `0` for a plain `Date`.
- `second(date)`: Extracts the second (0-59). Returns `0` for a plain `Date`.
- `weekday(date)`: Returns the ISO day of the week (1 = Monday, 7 = Sunday).

#### Arithmetic

- `datedif(date1, date2, unit)`: Returns the signed difference (`date2 − date1`) as an integer in the given unit. The result is negative when `date1 > date2`; use `abs()` to get an unsigned value.
- `dateadd(date, amount, unit)`: Shifts a date by the given integer amount and unit. Returns the same type as the input (adding sub-day units to a `Date` promotes it to a `NaiveDateTime`). End-of-month clamping is applied for `"months"` and `"years"` (e.g., Jan 31 + 1 month = Feb 28 or 29).

Both `datedif` and `dateadd` accept singular or plural unit names: `"day"` or `"days"`, `"month"` or `"months"`, etc. Valid units: `year(s)`, `month(s)`, `day(s)`, `hour(s)`, `minute(s)`, `second(s)`, `millisecond(s)`.

### Special Forms

- `let(name, value, expr)`: Lexically binds `name` to `value` within `expr` only.

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

## Multi-line Expressions

Expressions can be formatted across multiple lines for readability. Newlines are treated as whitespace by the parser, so you can break long expressions into a readable structure:

```elixir
expr = """
ifs(
  score > 90, 'A',
  score > 80, 'B',
  score > 70, 'C',
  true, 'F'
)
"""

ExCellerate.eval!(expr, %{"score" => 85})
# => "B"
```

This works with all APIs — `eval/3`, `compile/2`, and `validate/2`:

```elixir
expr = """
let(
  big,
  filter(orders, orders[*].(qty > 1)),
  table(
    'product', big[*].product,
    'total', big[*].(qty * price)
  )
)
"""

:ok = ExCellerate.validate(expr)
{:ok, fun} = ExCellerate.compile(expr)
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

Negative indices count from the end of the list, the same way they work in Elixir:

```elixir
scope = %{"items" => [10, 20, 30, 40, 50]}

ExCellerate.eval!("items[-1]", scope)
# => 50

ExCellerate.eval!("items[-2]", scope)
# => 40
```

### Nil Propagation

Path access uses **nil propagation**: if any key along a dotted path is missing
or the target is `nil`, the expression returns `nil` instead of raising an
error. This mirrors how spreadsheets treat empty cells and removes the need for
defensive checks at every level of a nested path.

```elixir
scope = %{"user" => %{"name" => "Alice"}}

# Missing leaf key
ExCellerate.eval!("user.email", scope)
# => nil

# Missing intermediate key — .name is never attempted
ExCellerate.eval!("user.profile.name", scope)
# => nil

# Explicit nil value
ExCellerate.eval!("user.name", %{"user" => nil})
# => nil

# List index out of bounds
ExCellerate.eval!("list[99]", %{"list" => [1, 2, 3]})
# => nil
```

This makes `ifnull`, `coalesce`, and ternaries useful for providing defaults:

```elixir
ExCellerate.eval!("ifnull(user.email, 'no email')", %{"user" => %{}})
# => "no email"

ExCellerate.eval!("coalesce(user.nick, user.name, 'anonymous')", %{"user" => %{}})
# => "anonymous"

ExCellerate.eval!("user.name ? user.name : 'unknown'", %{"user" => %{}})
# => "unknown"
```

**Note:** Root variable lookup still raises. Referencing a variable that doesn't
exist in the scope at all (e.g. `totally_unknown`) is treated as a likely typo
and returns an error:

```elixir
ExCellerate.eval("totally_unknown", %{})
# => {:error, %ExCellerate.Error{message: "variable not found: totally_unknown"}}
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
ExCellerate.eval!("concat(underscore(category), '_', id)", scope)
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

### Column Spread (`[*]`)

The `[*]` operator extracts a field from every element in a list, enabling column-oriented operations on tabular data:

```elixir
scope = %{
  "orders" => [
    %{"product" => "Widget", "price" => 10, "qty" => 2},
    %{"product" => "Gadget", "price" => 25, "qty" => 1},
    %{"product" => "Thing",  "price" => 5,  "qty" => 10}
  ]
}

ExCellerate.eval!("orders[*].product", scope)
# => ["Widget", "Gadget", "Thing"]

ExCellerate.eval!("sum(orders[*].price)", scope)
# => 40

ExCellerate.eval!("avg(orders[*].qty)", scope)
# => 4.333...

ExCellerate.eval!("max(orders[*].price)", scope)
# => 25

ExCellerate.eval!("textjoin(', ', orders[*].product)", scope)
# => "Widget, Gadget, Thing"
```

Access chains after `[*]` apply to each element, so deep nesting works naturally:

```elixir
scope = %{
  "users" => [
    %{"profile" => %{"name" => "Alice"}},
    %{"profile" => %{"name" => "Bob"}}
  ]
}

ExCellerate.eval!("users[*].profile.name", scope)
# => ["Alice", "Bob"]
```

You can also index into sub-lists after a spread:

```elixir
scope = %{
  "rows" => [
    %{"scores" => [10, 20, 30]},
    %{"scores" => [40, 50, 60]}
  ]
}

# Get the second score from each row
ExCellerate.eval!("rows[*].scores[1]", scope)
# => [20, 50]
```

Nested `[*]` operators flatten across levels:

```elixir
scope = %{
  "departments" => [
    %{"employees" => [%{"name" => "Alice"}, %{"name" => "Bob"}]},
    %{"employees" => [%{"name" => "Carol"}]}
  ]
}

ExCellerate.eval!("departments[*].employees[*].name", scope)
# => ["Alice", "Bob", "Carol"]
```

### Computed Spread (`.(expr)`)

To evaluate an expression *per element* of a spread, use the `.(expr)` syntax.
Inside the parentheses, bare variable names resolve against each element rather
than the outer scope:

```elixir
scope = %{
  "orders" => [
    %{"product" => "Widget", "price" => 10, "qty" => 2},
    %{"product" => "Gadget", "price" => 25, "qty" => 1}
  ]
}

# Per-row product of qty * price
ExCellerate.eval!("orders[*].(qty * price)", scope)
# => [20, 25]

# Sum of per-row products
ExCellerate.eval!("sum(orders[*].(qty * price))", scope)
# => 45
```

You can use any expression inside `.(...)`, including function calls and nested
access:

```elixir
ExCellerate.eval!("orders[*].(upper(product))", scope)
# => ["WIDGET", "GADGET"]
```

Computed spreads also compose with nested `[*]`:

```elixir
scope = %{
  "departments" => [
    %{"employees" => [
      %{"name" => "Alice", "salary" => 5000},
      %{"name" => "Bob", "salary" => 6000}
    ]},
    %{"employees" => [
      %{"name" => "Carol", "salary" => 5500}
    ]}
  ]
}

# Annualised salaries for all employees, flattened
ExCellerate.eval!("departments[*].employees[*].(salary * 12)", scope)
# => [60000, 72000, 66000]
```

## Validation

You can validate an expression's syntax and function calls without executing it:

```elixir
:ok = ExCellerate.validate("abs(-10)")
{:error, %ExCellerate.Error{}} = ExCellerate.validate("invalid(1, 2)")
```

Validation checks syntax, function existence, and arity. However, ExCellerate does not perform type checking — scope values are not known until runtime, so type mismatches (e.g., passing a number to a string function like `upper(price)`) will only be caught at evaluation time with a descriptive runtime error.

## Let, Filter, and Table

`let/3` introduces a lexical binding that is visible only inside the body
expression; it does not mutate the outer scope:

```elixir
scope = %{"x" => 10, "y" => 3}

ExCellerate.eval!("let(x, 2, x + y)", scope)
# => 5

ExCellerate.eval!("x + y", scope)
# => 13
```

`filter/2` selects items from a list using a boolean list produced by a
computed spread. The predicate list must be the same length as the input list:

```elixir
scope = %{
  "orders" => [
    %{"id" => 1, "qty" => 2},
    %{"id" => 2, "qty" => 1},
    %{"id" => 3, "qty" => 5}
  ]
}

ExCellerate.eval!("filter(orders, orders[*].(qty > 1))", scope)
# => [%{"id" => 1, "qty" => 2}, %{"id" => 3, "qty" => 5}]
```

`table` builds a list of maps from alternating key/list pairs. Use spread or
computed spread to produce the list columns:

```elixir
scope = %{
  "orders" => [
    %{"product" => "Widget", "price" => 10, "qty" => 2},
    %{"product" => "Gadget", "price" => 5, "qty" => 1}
  ]
}

ExCellerate.eval!("table('product', orders[*].product, 'total', orders[*].(qty * price))", scope)
# => [%{"product" => "Widget", "total" => 20}, %{"product" => "Gadget", "total" => 5}]
```

### Take and Slice

`take` extracts rows, columns, or both from a list or 2D array. Positive counts
take from the beginning, negative from the end. Pass `null` to skip a dimension:

```elixir
scope = %{
  "grid" => [
    [1, 2, 3, 4],
    [5, 6, 7, 8],
    [9, 10, 11, 12]
  ]
}

ExCellerate.eval!("take(grid, 2)", scope)
# => [[1, 2, 3, 4], [5, 6, 7, 8]]

ExCellerate.eval!("take(grid, -2)", scope)
# => [[5, 6, 7, 8], [9, 10, 11, 12]]

ExCellerate.eval!("take(grid, null, 2)", scope)
# => [[1, 2], [5, 6], [9, 10]]

ExCellerate.eval!("take(grid, 2, 2)", scope)
# => [[1, 2], [5, 6]]
```

It also works on flat lists:

```elixir
ExCellerate.eval!("take(items, 3)", %{"items" => [10, 20, 30, 40, 50]})
# => [10, 20, 30]
```

`slice` extracts a contiguous section of a list by start index and optional
length. The start index is zero-based; negative indices count from the end:

```elixir
scope = %{"items" => [10, 20, 30, 40, 50]}

ExCellerate.eval!("slice(items, 1)", scope)
# => [20, 30, 40, 50]

ExCellerate.eval!("slice(items, 1, 3)", scope)
# => [20, 30, 40]

ExCellerate.eval!("slice(items, -2)", scope)
# => [40, 50]
```

### Putting It Together

These features compose naturally. Filter to large orders, then build a summary:

```elixir
scope = %{
  "orders" => [
    %{"product" => "Widget", "price" => 10, "qty" => 5},
    %{"product" => "Gadget", "price" => 3, "qty" => 1},
    %{"product" => "Gizmo", "price" => 8, "qty" => 3}
  ]
}

expr = "let(big, filter(orders, orders[*].(qty > 1)), table('product', big[*].product, 'total', big[*].(qty * price)))"
ExCellerate.eval!(expr, scope)
# => [%{"product" => "Widget", "total" => 50}, %{"product" => "Gizmo", "total" => 24}]
```

### INDEX/MATCH Lookups

The `match` and `index` functions compose naturally to replicate Excel's classic INDEX/MATCH pattern — look up a value in one column based on finding a match in another:

```elixir
scope = %{
  "products" => [
    %{"name" => "Bananas", "price" => 1.25},
    %{"name" => "Oranges", "price" => 2.50},
    %{"name" => "Apples", "price" => 1.75}
  ]
}

# Find the price of Oranges
ExCellerate.eval!("index(products[*].price, match('Oranges', products[*].name))", scope)
# => 2.50
```

Use `match_type` `1` or `-1` for approximate matching against sorted data:

```elixir
scope = %{"brackets" => [0, 10000, 50000, 100000], "rates" => [0.10, 0.15, 0.25, 0.35]}

# Find the tax rate for an income of 75000 (largest bracket <= 75000)
ExCellerate.eval!("index(rates, match(75000, brackets, 1))", scope)
# => 0.25
```

When `match` returns `null` (no match found), `index` propagates the `null`:

```elixir
scope = %{"names" => ["Alice", "Bob"], "scores" => [90, 85]}

ExCellerate.eval!("index(scores, match('Unknown', names))", scope)
# => nil
```

### Date & Time

Date and time functions work with native Elixir `Date`, `NaiveDateTime`, and `DateTime` structs from the scope. You can also construct dates within expressions:

```elixir
# Construct dates in expressions
ExCellerate.eval!("date(2024, 6, 15)")
# => ~D[2024-06-15]

ExCellerate.eval!("datetime(2024, 6, 15, 13, 30, 0)")
# => ~N[2024-06-15 13:30:00]
```

Extract components from dates passed in scope:

```elixir
scope = %{"birthday" => ~D[1990-07-04]}

ExCellerate.eval!("year(birthday)", scope)
# => 1990

ExCellerate.eval!("month(birthday)", scope)
# => 7
```

Calculate differences between dates:

```elixir
scope = %{
  "start" => ~D[2024-01-01],
  "end" => ~D[2024-03-15]
}

ExCellerate.eval!("datedif(start, end, 'days')", scope)
# => 74

ExCellerate.eval!("datedif(start, end, 'months')", scope)
# => 2

ExCellerate.eval!("datedif(start, end, 'hours')", scope)
# => 1776
```

Shift dates forward or backward:

```elixir
scope = %{"due" => ~D[2024-01-31]}

ExCellerate.eval!("dateadd(due, 30, 'days')", scope)
# => ~D[2024-03-01]

# End-of-month clamping: Jan 31 + 1 month = Feb 29 (2024 is a leap year)
ExCellerate.eval!("dateadd(due, 1, 'months')", scope)
# => ~D[2024-02-29]
```

Compose date functions with other expressions:

```elixir
scope = %{
  "events" => [
    %{"name" => "Launch", "date" => ~D[2024-03-01]},
    %{"name" => "Review", "date" => ~D[2024-06-15]},
    %{"name" => "Release", "date" => ~D[2024-09-30]}
  ],
  "cutoff" => ~D[2024-05-01]
}

# Use date functions with spreads and filtering
ExCellerate.eval!("events[*].date", scope)
# => [~D[2024-03-01], ~D[2024-06-15], ~D[2024-09-30]]

ExCellerate.eval!("year(events[0].date)", scope)
# => 2024
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

## Pros and Cons

### Pros

- **Performance**: By compiling to Elixir AST and caching results in ETS, ExCellerate avoids redundant parsing and provides execution speeds matching native Elixir.
- **Safety**: Expressions are compiled into a restricted subset of Elixir, preventing arbitrary code execution.
- **Error Handling**: Detailed structs identify exactly where and why an expression failed (e.g., line/column for parse errors).
- **Extensibility**: The registry system makes it easy to add domain-specific logic without modifying the core library.
- **Readability**: Uses a familiar, Excel-like or C-style syntax for expressions.

### Cons

- **First-run Overhead**: The very first time an expression is encountered, it must be parsed and compiled. Subsequent calls use the cache.
- **Static Resolution**: All function names must be registered at compile time. Functions cannot be passed dynamically in the scope — use a custom `ExCellerate.Registry` instead.
- **No Type Checking**: Expressions are not statically typed. Validation confirms syntax, function existence, and arity, but type mismatches (e.g., `upper(42)`) are only caught at runtime.

## Security

ExCellerate uses `Code.eval_quoted/3` internally to compile expressions into reusable anonymous functions. This happens once per unique expression (the result is cached). While `eval_quoted` may raise concerns, the expression input is not evaluated directly — it passes through two controlled stages:

1. **Parsing**: The NimbleParsec parser only accepts a fixed grammar. Arbitrary Elixir code (e.g., `System.cmd/2`, `File.rm/1`) cannot be expressed in the parser's syntax and will be rejected as parse errors.

2. **Compilation**: The compiler only generates AST for a restricted set of operations: arithmetic, comparisons, logical/bitwise operators, data access (`Map.fetch`, `Access.get`, `Enum.at`), and function calls dispatched through the registry system. All function names must resolve at compile time to a registered module — scope values cannot be invoked as functions. No arbitrary module calls, process operations, or I/O are emitted.

The parser is the security boundary. Users cannot inject arbitrary Elixir through an expression string because the parser will not produce IR for it, and the compiler will not generate AST for it.

**When is this safe?**

- Developers writing expressions in config files or application code — no risk, they already have full code access.
- End-users submitting expressions through a UI — the parser constrains what can be expressed. They cannot escape the expression grammar.

**What would constitute a vulnerability?**

A bug in the parser or compiler that causes a crafted expression string to produce unexpected AST. This is a narrow surface area, but if you discover such a case, please report it.

We think that this is a valid analysis of the threat, but we welcome feedback on this security model. If you have concerns or find an issue, please open an issue on the [GitHub repository](https://github.com/matchsense/excellerate).

## Documentation

Full documentation is available on [HexDocs](https://hexdocs.pm/excellerate).

## License

ExCellerate is released under the MIT License.

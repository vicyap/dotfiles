---
paths:
  - "**/*.ex"
  - "**/*.exs"
---

## Elixir guidelines

Source: github.com/phoenixframework/phoenix/tree/main/usage-rules

### Version, typing, and quality gates

- Target Elixir v1.20+ for new projects even while it's pre-release (as of May 2026) — it carries major improvements to Elixir's built-in type checking
- Maximize that type-checking signal: prefer precise pattern matching, explicit return shapes, typespecs for public contracts, and exhaustive matches over broad catch-alls
- Do **not** use Dialyzer for new work — treat it as a legacy path now that Elixir builds type checking into the language itself
- Always use Credo with sane defaults for style, consistency, and maintainability; consider adding [`ex_slop`](https://github.com/elixir-vibe/ex_slop) (Credo checks for AI-generated-code issues) and [`ex_dna`](https://github.com/elixir-vibe/ex_dna) (AST-aware duplication detection)

- Elixir lists don't support index-based access via `list[i]` (it raises at runtime) — use `Enum.at/2`, pattern matching, or `List` instead

- Elixir variables are immutable but rebindable, so for block expressions (`if`, `case`, `cond`, etc.) you *must* bind the result to a variable to use it — you cannot rebind inside the expression, i.e.:

      # INVALID: rebinding inside the `if`; the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: rebind the result of the `if` itself
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file — it risks cyclic dependencies and compilation errors
- **Never** use map access syntax (`my_struct[:field]`) on structs — they don't implement the Access behaviour by default. Access fields directly (`my_struct.field`) or through a higher-level API the struct provides, e.g. `Ecto.Changeset.get_field/2` for changesets
- Elixir's stdlib covers date/time (`Time`, `Date`, `DateTime`, `Calendar`); never install an extra dependency for it unless asked, except `date_time_parser` for parsing
- Don't use `String.to_atom/1` on user input (memory leak risk — atoms are never garbage collected)
- Predicate function names should not start with `is_` and should end in `?`; reserve `is_thing` naming for guards
- Elixir's OTP primitives like `DynamicSupervisor` and `Registry` require names in the child spec (`{DynamicSupervisor, name: MyApp.MyDynamicSup}`) so callers can address them by name (`DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`)
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure; pass `timeout: :infinity` unless you have a reason not to

## Anti-patterns

- **`with` else blocks**: normalize error returns in private helper functions so `with` needs no `else` at all, rather than flattening every error into one complex `else` block that re-maps them back to their source

- **Use `and`/`or`/`not` when operands are booleans**, not `&&`/`||`/`!`. The strict operators require their first argument to be a strict boolean, catching bugs where a non-boolean like `:error` or `:undefined` would silently pass as truthy under `&&`:

      # Avoid — :error is truthy under &&, so this silently "passes"
      if is_binary(name) && is_integer(age), do: ...
      # Prefer — raises if either isn't a strict boolean
      if is_binary(name) and is_integer(age), do: ...

- **Match specific patterns in `case`, not a catch-all `_`**. A catch-all silently swallows new return values as they're added instead of surfacing them:

      # Avoid — a new {:error, _} shape falls through unnoticed
      case File.read(path) do
        {:ok, data} -> data
        _ -> nil
      end

      # Prefer
      case File.read(path) do
        {:ok, data} -> data
        {:error, _reason} -> nil
      end

- **Use `map.key` for required keys, `map[:key]` for optional keys** — even on plain maps. Bracket access on a required key hides a missing-key bug as silent `nil` propagation instead of raising
- **Prefer tuple-returning functions over `try`/`rescue`** (`File.read/1` + `case`, not `File.read!/1` + `try/rescue`). Reserve bang functions for scripts, tests, and fire-and-forget calls where crashing is correct
- **Extract data before sending to processes** — a closure captures its entire binding, so `spawn(fn -> log(conn.remote_ip) end)` silently retains all of `conn` in memory. Bind the needed value first: `ip = conn.remote_ip; spawn(fn -> log(ip) end)`
- **Centralize process interfaces** — all `GenServer.call/cast` and `Agent` interactions for a process belong in that process's own module, not scattered across callers
- **Functions over macros** — don't reach for `defmacro` when `def` suffices
- **Keep structs under 32 fields** — the BEAM silently switches from a flat map (shared key tuple) to a hash map at 32 fields, a hidden performance/memory-layout cliff. Nest optional or rarely-accessed fields instead
- **Replace overlapping booleans with atoms** — when several boolean fields have dependent states (`admin: true` makes `editor: true` meaningless), use one atom field like `role: :admin`

## Mix guidelines

- `mix deps.clean --all` is almost never needed — avoid it unless you have good reason

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests — it guarantees cleanup between tests and prevents cross-test leakage
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests — they make tests flaky. Wait for a process to finish with `Process.monitor/1` + `assert_receive {:DOWN, ^ref, :process, ^pid, :normal}`; to synchronize before the next call, use `_ = :sys.get_state(pid)` to ensure prior messages are handled

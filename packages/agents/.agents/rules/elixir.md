---
paths:
  - "**/*.ex"
  - "**/*.exs"
---

## Elixir guidelines

Source: github.com/phoenixframework/phoenix/tree/main/usage-rules

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Anti-patterns

- **`with` else blocks**: Don't flatten errors into a single complex `else` block. Instead, normalize error returns in private helper functions so `with` needs no `else` at all:

      # Avoid: complex else mapping errors back to their source
      with {:ok, encoded} <- File.read(path),
           {:ok, decoded} <- Base.decode64(encoded) do
        {:ok, String.trim(decoded)}
      else
        {:error, _} -> {:error, :badfile}
        :error -> {:error, :badencoding}
      end

      # Prefer: normalize errors at the source, drop the else
      with {:ok, encoded} <- file_read(path),
           {:ok, decoded} <- base_decode64(encoded) do
        {:ok, String.trim(decoded)}
      end

- **Use `and`/`or`/`not` when operands are booleans**, not `&&`/`||`/`!`. The strict operators assert their first argument is boolean, catching bugs where `:error` or `:undefined` would be truthy under `&&`:

      # Avoid
      if is_binary(name) && is_integer(age), do: ...
      # Prefer
      if is_binary(name) and is_integer(age), do: ...

- **Match specific patterns in `case`, not catch-all `_`**. When the possible return values are known, match each explicitly. Catch-all `_` hides bugs when new return values are added:

      # Avoid
      case File.read(path) do
        {:ok, data} -> data
        _ -> nil
      end

      # Prefer
      case File.read(path) do
        {:ok, data} -> data
        {:error, _reason} -> nil
      end

- **Use `map.key` for required keys, `map[:key]` for optional keys** -- even on plain maps, not just structs. Bracket access on a required key hides missing-key bugs as `nil` propagation

- **Prefer tuple-returning functions over `try`/`rescue`**. Use `File.read/1` + `case`, not `File.read!/1` + `try/rescue`. Reserve bang functions for scripts, tests, and fire-and-forget calls where crashing is the right response

- **Extract data before sending to processes**. Closures capture entire bindings, so `spawn(fn -> log(conn.remote_ip) end)` copies all of `conn`. Bind the needed value first:

      ip = conn.remote_ip
      spawn(fn -> log(ip) end)

- **Centralize process interfaces** -- all `GenServer.call/cast` and `Agent` interactions for a process belong in that process's module. Don't scatter `GenServer.call(pid, ...)` across multiple modules

- **Functions over macros** -- don't use `defmacro` when `def` suffices

- **Keep structs under 32 fields** -- the BEAM switches from flat map (shared key tuple) to hash map at 32 fields. Nest optional or rarely-accessed fields if needed

- **Replace overlapping booleans with atoms** -- when multiple boolean fields have dependent states (e.g., `admin: true` makes `editor: true` meaningless), use a single atom field like `role: :admin`

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests
  - Instead of sleeping to wait for a process to finish, **always** use `Process.monitor/1` and assert on the DOWN message:

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

   - Instead of sleeping to synchronize before the next call, **always** use `_ = :sys.get_state/1` to ensure the process has handled prior messages

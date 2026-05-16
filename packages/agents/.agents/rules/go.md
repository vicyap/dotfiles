---
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
---

## Modern Go guidelines

Source: JetBrains go-modern-guidelines

Before writing Go code, check `go.mod` for the project's Go version. Use **all** modern features up to that version. **Never** use outdated patterns when a modern alternative exists.

### Go 1.13+

- `errors.Is(err, target)` not `err == target` (works with wrapped errors)

### Go 1.18+

- `any` not `interface{}`
- `strings.Cut(s, sep)` / `bytes.Cut(b, sep)` not Index+slice

### Go 1.19+

- `atomic.Bool`/`atomic.Int64`/`atomic.Pointer[T]` not `atomic.StoreInt32` and friends

### Go 1.20+

- `strings.CutPrefix`/`CutSuffix` not HasPrefix+TrimPrefix
- `errors.Join(err1, err2)` to combine multiple errors
- `context.WithCancelCause` then `context.Cause(ctx)` for cancellation reasons

### Go 1.21+

**Built-ins:**
- `min(a, b)` / `max(a, b)` not if/else comparisons
- `clear(m)` to delete all map entries, `clear(s)` to zero slice elements

**slices package** -- use instead of manual loops:
- `slices.Contains`, `slices.Index`, `slices.IndexFunc`
- `slices.SortFunc(items, func(a, b T) int { return cmp.Compare(a.X, b.X) })`
- `slices.Sort` for ordered types
- `slices.Max` / `slices.Min`, `slices.Reverse`, `slices.Compact`, `slices.Clone`

**maps package:**
- `maps.Clone(m)`, `maps.Copy(dst, src)`, `maps.DeleteFunc`

**sync package:**
- `sync.OnceFunc(func() { ... })` not `sync.Once` + wrapper
- `sync.OnceValue(func() T { ... })` for lazy singletons

### Go 1.22+

- `for i := range n` not `for i := 0; i < n; i++`
- Loop variables are now safe to capture in goroutines (each iteration gets its own copy)
- `cmp.Or(flag, env, config, "default")` returns first non-zero value:

      // Instead of:
      name := os.Getenv("NAME")
      if name == "" {
          name = "default"
      }
      // Use:
      name := cmp.Or(os.Getenv("NAME"), "default")

- Enhanced `http.ServeMux`: `mux.HandleFunc("GET /api/{id}", handler)` with `r.PathValue("id")`

### Go 1.23+

- `maps.Keys(m)` / `maps.Values(m)` return iterators
- `slices.Collect(iter)` to build slice from iterator
- `slices.Sorted(iter)` to collect and sort in one step
- `time.Tick` is safe now -- GC recovers unreferenced tickers since 1.23, no need for `NewTicker`

### Go 1.24+

- **`t.Context()`** not `context.WithCancel(context.Background())` in tests. ALWAYS use `t.Context()` when a test needs a context.

- **`omitzero`** not `omitempty` for JSON struct tags on `time.Duration`, `time.Time`, structs, slices, maps. `omitempty` is broken for these types.

      // WRONG: omitempty doesn't work for Duration
      Timeout time.Duration `json:"timeout,omitempty"`
      // CORRECT:
      Timeout time.Duration `json:"timeout,omitzero"`

- **`b.Loop()`** not `for i := 0; i < b.N; i++` in benchmarks.

- **`strings.SplitSeq`** / `strings.FieldsSeq` / `bytes.SplitSeq` / `bytes.FieldsSeq` when iterating over split results in a for-range loop:

      // OLD:
      for _, part := range strings.Split(s, ",") { process(part) }
      // NEW:
      for part := range strings.SplitSeq(s, ",") { process(part) }

### Go 1.25+

- **`wg.Go(fn)`** not `wg.Add(1)` + `go func() { defer wg.Done(); ... }()`:

      // OLD:
      var wg sync.WaitGroup
      for _, item := range items {
          wg.Add(1)
          go func() {
              defer wg.Done()
              process(item)
          }()
      }
      // NEW:
      var wg sync.WaitGroup
      for _, item := range items {
          wg.Go(func() { process(item) })
      }

### Go 1.26+

- **`new(val)`** returns pointer to any value. Type is inferred: `new(0)` -> `*int`, `new("s")` -> `*string`, `new(T{})` -> `*T`. DO NOT use `x := val; &x` pattern.

      cfg := Config{
          Timeout: new(30),   // *int
          Debug:   new(true), // *bool
      }

- **`errors.AsType[T](err)`** not `errors.As(err, &target)`:

      // OLD:
      var pathErr *os.PathError
      if errors.As(err, &pathErr) { handle(pathErr) }
      // NEW:
      if pathErr, ok := errors.AsType[*os.PathError](err); ok { handle(pathErr) }

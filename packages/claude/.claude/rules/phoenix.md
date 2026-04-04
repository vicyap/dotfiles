---
paths:
  - "**/*_web*"
  - "**/*router*"
  - "**/*controller*"
  - "**/*plug*"
  - "**/*.ex"
---

## Phoenix guidelines

Source: github.com/phoenixframework/phoenix/tree/main/usage-rules

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the UserLive route would point to the `AppWeb.Admin.UserLive` module

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it

- Use `Endpoint.url/0` for base URL construction instead of manually reading `Endpoint.config(:url)` and reassembling scheme/host/port. Build distinct paths from the same base rather than deriving one URL from another via `String.replace`.

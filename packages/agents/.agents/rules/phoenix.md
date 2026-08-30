---
paths:
  - "**/*_web*"
  - "**/*router*"
  - "**/*controller*"
  - "**/*plug*"
---

## Phoenix guidelines

Source: github.com/phoenixframework/phoenix/tree/main/usage-rules

- Phoenix router `scope` blocks include an optional alias that's prefixed onto every route within the scope — be mindful of it when adding routes in a scope, or you'll get duplicate module prefixes

- You **never** need your own `alias` for route definitions — the `scope` already provides one, e.g.:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the `UserLive` route points to `AppWeb.Admin.UserLive`

- `Phoenix.View` is no longer needed or included with Phoenix — don't use it

- Use `Endpoint.url/0` for base URL construction instead of manually reading `Endpoint.config(:url)` and reassembling scheme/host/port; build distinct paths from the same base rather than deriving one URL from another via `String.replace`

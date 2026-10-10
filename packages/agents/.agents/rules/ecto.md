---
paths:
  - "**/*schema*.ex"
  - "**/*changeset*.ex"
  - "**/*migration*.exs"
  - "**/*repo*.ex"
---

## Ecto Guidelines

Source: github.com/phoenixframework/phoenix/tree/main/usage-rules

- **Always** preload Ecto associations in queries when they'll be accessed in templates (e.g. a view referencing `message.user.email`)
- `Ecto.Changeset.validate_number/2` **does not support the `:allow_nil` option** — passing it is silently ignored rather than erroring, since validations already only run when a change for the field exists and isn't nil
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields — bracket access (`changeset[:field]`) raises, since changesets don't implement Access
- Fields set programmatically (e.g. `user_id`) must **never** appear in `cast` calls, for security purposes — set them explicitly when building the struct instead
- **Always** invoke `mix ecto.gen.migration migration_name_using_underscores` to generate migration files, so the correct timestamp and conventions are applied

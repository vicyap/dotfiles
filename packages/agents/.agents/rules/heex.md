---
paths:
  - "**/*.heex"
  - "**/*.html.heex"
  - "**/*_html.ex"
  - "**/*_component*.ex"
---

## Phoenix HTML guidelines

Source: github.com/phoenixframework/phoenix/tree/main/usage-rules

- Phoenix templates **always** use `~H` or `.html.heex` files (HEEx), **never** `~E`

- Build forms with the imported `Phoenix.Component.form/1` and `inputs_for/1` — **never** the outdated `Phoenix.HTML.form_for`/`inputs_for`. Assign a form via `to_form/2` (`assign(socket, form: to_form(...))`) and drive every field reference from it in the template: `<.form for={@form} id="...">`, `<.input field={@form[:field]} />`. **Never** write `<.form let={f} ...>` or read a changeset directly in the template (`@changeset[:field]`) — the form assign is the only sanctioned path

- **Always** add unique DOM IDs to key elements (forms, buttons, etc.) — they're what tests target later, e.g. `<.form for={@form} id="product-form">`

- For app-wide template imports/aliases, add them to `my_app_web.ex`'s `html_helpers` block so they reach every LiveView, LiveComponent, and `use MyAppWeb, :html` module

- Wrap a tag in `phx-no-curly-interpolation` before showing literal `{`/`}` inside it (e.g. a `<pre>`/`<code>` snippet) — without it, HEEx still tries to interpolate the braces:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

  `<%= ... %>` still works for genuine dynamic expressions inside such a tag

- For conditional or multiple class values, **always** use HEEx's `class={[...]}` list syntax — **never** build the class string via interpolation (wrap an `if` in parens: `if(@cond, do: "a", else: "b")`)

- **Never** use `<% Enum.each %>` or another non-`for` comprehension to generate template content — **always** `<%= for item <- @collection do %>`

- HEEx comments are `<%!-- comment --%>`, not a plain HTML `<!-- -->` — **always** use the HEEx form for template comments

- Interpolation: `{...}` and `<%= %>` both work for a value in a tag body, but attributes only accept `{...}` and block constructs (`if`/`cond`/`case`/`for`) only work via `<%= ... %>` in the body — prefer `{...}` for plain body values

---
paths:
  - "**/*live*.ex"
  - "**/*_live.ex"
  - "**/*_live/*.ex"
  - "**/*_test.exs"
---

## Phoenix LiveView guidelines

Source: github.com/phoenixframework/phoenix/tree/main/usage-rules

- **Never** use the deprecated `live_redirect`/`live_patch` — use `<.link navigate={href}>`/`<.link patch={href}>` in templates, and `push_navigate`/`push_patch` in LiveViews
- **Avoid LiveComponents** unless you have a strong, specific need for them
- Name LiveViews with a `Live` suffix (`AppWeb.WeatherLive`)

### LiveView streams

- **Always** use streams instead of assigning regular lists for collections, to avoid memory ballooning and runtime termination: `stream(socket, :messages, [new_msg])` to append, `..., reset: true` to reset/filter, `..., at: -1` to prepend, `stream_delete(socket, :messages, msg)` to delete

- A `stream/3` collection needs matching template markup — the parent element needs `phx-update="stream"` and its own DOM id, and each child consumes `@streams.stream_name`'s `{id, item}` pairs as its own DOM id:

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>{msg.text}</div>
      </div>

- LiveView streams aren't Enumerable (`Enum.filter/2`/`Enum.reject/2` raise) — to filter, prune, or refresh a stream, refetch the data and re-stream the whole collection with `reset: true`

- Streams don't support counting or empty states natively. Track a count in a separate assign; for an empty state, add a Tailwind `hidden only:block` sibling to the stream's `:for` block — it only works when that's the only HTML alongside the stream comprehension

- Updating an assign that's read *inside* a streamed item's template does **not** re-render that item on its own — you must also re-insert the item (`stream_insert/3`) so the change takes effect:

      def handle_event("edit_message", %{"message_id" => message_id}, socket) do
        message = Chat.get_message!(message_id)

        {:noreply,
         socket
         |> stream_insert(:messages, message)
         |> assign(:editing_message_id, String.to_integer(message_id))}
      end

- **Never** use the deprecated `phx-update="append"`/`"prepend"` for collections

### LiveView JavaScript interop

- A `phx-hook="MyHook"` element whose hook manages its own DOM **must** also set `phx-update="ignore"`

#### Inline colocated js hooks

- **Never** write a raw `<script>` tag in HEEx (LiveView doesn't patch around it) — use a colocated hook instead, named with a leading `.`; it's bundled into `app.js` automatically, no separate registration step:

      <input phx-hook=".PhoneNumber" id="user-phone-number" />
      <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
        export default { mounted() { /* ... */ } }
      </script>

#### External phx-hook

- An external `phx-hook="MyHook"` (defined in `assets/js/`) must be passed to the `LiveSocket` constructor's `hooks` option, e.g. `new LiveSocket("/live", Socket, { hooks: { MyHook } })`

#### Pushing events between client and server

- `push_event/3` returns an updated socket — rebind or return it, or the event is silently dropped: `socket = push_event(socket, "my_event", %{...})`. A hook receives it via `this.handleEvent("my_event", fn)`, and can call `this.pushEvent(event, payload, reply_fn)` to get a `{:reply, map, socket}` reply back from `handle_event/3`

### LiveView tests

- Use `Phoenix.LiveViewTest` (with the bundled `LazyHTML`) for assertions; drive form tests through `render_submit/2` and `render_change/2`
- Reference the DOM IDs you added in the LiveView template when calling `element/2`/`has_element/2`
- **Never** assert against raw HTML — use `element/2`, `has_element/2`, and similar (`assert has_element?(view, "#my-form")`), favoring the presence of key elements over exact text content, which changes more often
- `<.form>`/`<.input>` can render different markup than you expect — assert against the actual rendered HTML structure, not your mental model of it

### Form handling

#### Creating a form from params

- `to_form(params)` in a `handle_event` callback assumes the map already has string keys (the raw params shape); pass `as: :user` to nest it as `%{"user" => user_params}` on submit

#### Creating a form from changesets

- `to_form/1` on a changeset auto-computes `:as` from the changeset's schema module (e.g. `MyApp.Users.User` → submitted params nest as `%{"user" => user_params}`)
- **Never** access `@changeset[:field]` in the template or write `<.form let={f} ...>` — always drive the form from a `to_form/2` assign (`@form`)

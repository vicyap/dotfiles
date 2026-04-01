---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/next.config.*"
  - "**/app/**"
  - "**/pages/**"
---

## React & Next.js guidelines

Source: Vercel Engineering react-best-practices

### Eliminating waterfalls (CRITICAL)

- **Defer `await` into branches where actually needed.** Don't `await` at the top of a function if only one branch uses the result:

      // WRONG: blocks both branches
      async function handle(id: string, skip: boolean) {
        const data = await fetchData(id)
        if (skip) return { skipped: true }
        return process(data)
      }
      // CORRECT: only fetches when needed
      async function handle(id: string, skip: boolean) {
        if (skip) return { skipped: true }
        const data = await fetchData(id)
        return process(data)
      }

- **Check cheap sync conditions before awaiting flags.** If you have `flag && cheapCondition`, check the cheap condition first to skip the async call entirely.

- **`Promise.all()` for independent operations.** Never `await` sequential independent fetches:

      // WRONG: 3 round trips
      const user = await fetchUser()
      const posts = await fetchPosts()
      const comments = await fetchComments()
      // CORRECT: 1 round trip
      const [user, posts, comments] = await Promise.all([fetchUser(), fetchPosts(), fetchComments()])

- **In API routes, start promises early, await late:**

      export async function GET(request: Request) {
        const sessionPromise = auth()
        const configPromise = fetchConfig()
        const session = await sessionPromise
        const [config, data] = await Promise.all([configPromise, fetchData(session.user.id)])
        return Response.json({ data, config })
      }

- **Use Suspense to parallelize RSC data fetching.** Move async fetches into child components so sibling components fetch in parallel instead of sequentially:

      // WRONG: Sidebar waits for Page's fetch
      export default async function Page() {
        const header = await fetchHeader()
        return <div><div>{header}</div><Sidebar /></div>
      }
      // CORRECT: both fetch simultaneously
      export default function Page() {
        return <div><Header /><Sidebar /></div>
      }

- **Chain nested fetches per item** so a slow item doesn't block others:

      // WRONG: slow getChat blocks ALL getUser calls
      const chats = await Promise.all(chatIds.map(id => getChat(id)))
      const authors = await Promise.all(chats.map(chat => getUser(chat.author)))
      // CORRECT: each item chains independently
      const authors = await Promise.all(chatIds.map(id => getChat(id).then(chat => getUser(chat.author))))

### Bundle size (CRITICAL)

- **Avoid barrel file imports.** Libraries like `lucide-react` (1,583 modules, ~2.8s) and `@mui/material` (2,225 modules, ~4.2s) are extremely expensive to import from barrel files. In Next.js 13.5+, use `optimizePackageImports` in next.config.js. Outside Next.js, import directly from subpaths.

- **`next/dynamic` for heavy components** not needed on initial render (e.g. Monaco, charts, maps):

      const MonacoEditor = dynamic(() => import('./monaco-editor').then(m => m.MonacoEditor), { ssr: false })

- **Defer analytics/logging** -- load after hydration with `dynamic(..., { ssr: false })`.

- **Preload on hover/focus** for perceived speed: `onMouseEnter={() => void import('./heavy-module')}`.

### Server-side (HIGH)

- **Server Actions are public endpoints.** ALWAYS authenticate and authorize inside each `"use server"` function. Never rely solely on middleware or layout guards.

- **No shared module state for request data.** Module-level mutable variables cause cross-request data leaks in concurrent RSC/SSR:

      // WRONG: request A's user leaks to request B
      let currentUser: User | null = null
      export default async function Page() {
        currentUser = await auth()
        return <Dashboard />
      }
      // CORRECT: pass data through the render tree
      export default async function Page() {
        const user = await auth()
        return <Dashboard user={user} />
      }

- **Hoist static I/O to module level.** Fonts, logos, config files -- read once at module init, not on every request:

      // Module-level: runs ONCE
      const fontData = fetch(new URL('./fonts/Inter.ttf', import.meta.url)).then(res => res.arrayBuffer())
      export async function GET(request: Request) {
        const font = await fontData
        // ...
      }

- **Minimize RSC serialization.** Only pass fields the client component actually uses, not entire objects:

      // WRONG: serializes 50 fields
      <Profile user={user} />
      // CORRECT: serializes 1 field
      <Profile name={user.name} />

- **`React.cache()` for per-request deduplication** of DB queries, auth checks, heavy computations. Beware: it uses `Object.is` for cache keys, so inline objects always miss.

- **`after()` from `next/server`** for non-blocking post-response work (logging, analytics, cache invalidation).

### Re-render gotchas (MEDIUM-HIGH)

- **Never define components inside components.** Creates a new component type every render, causing full remount (lost state, rerun effects, recreated DOM). Symptoms: inputs lose focus on keystroke, animations restart, scroll resets.

- **Derive state during render, not in effects:**

      // WRONG: extra render + state drift
      const [fullName, setFullName] = useState('')
      useEffect(() => { setFullName(firstName + ' ' + lastName) }, [firstName, lastName])
      // CORRECT: derive inline
      const fullName = firstName + ' ' + lastName

- **Don't subscribe to state only used in callbacks.** If you only read `searchParams` inside an `onClick`, use `new URLSearchParams(window.location.search)` on demand instead of `useSearchParams()` which re-renders on every change.

- **Hoist default non-primitive props from memoized components.** `memo(({ onClick = () => {} })` breaks memoization -- extract to `const NOOP = () => {}` at module level.

- **Use functional `setState`** for stable callbacks: `setValue(prev => prev + 1)` lets you omit the value from `useCallback` deps.

- **Lazy state initialization:** `useState(() => expensiveCompute())` not `useState(expensiveCompute())`.

### Hydration

- **Prevent flicker without hydration mismatch.** For client-only data (theme, auth), use an inline `<script dangerouslySetInnerHTML>` that runs synchronously before React hydrates, not `useEffect` which flashes the default value.

- **`<Activity mode="hidden">`** (React 19) preserves state/DOM for expensive components that toggle visibility. Avoids remount cost.

- **Use ternary `{x ? <A/> : <B/>}` not `{x && <A/>}`** -- the latter renders `0` or `""` for falsy non-boolean values.

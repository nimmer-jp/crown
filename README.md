<div align="center">
  <h1>👑 Crown Framework</h1>
  <p><strong>The Full-stack Nim Meta-Framework. Next.js DX meets the speed of Nim.</strong></p>

  <p>
    <a href="https://nim-lang.org"><img src="https://img.shields.io/badge/Nim-2.2+-FFE953?logo=nim&logoColor=white" alt="Nim Version"></a>
    <a href="https://github.com/itsumura-h/nim-basolato"><img src="https://img.shields.io/badge/Powered%20by-Basolato-blue" alt="Basolato"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License"></a>
  </p>
</div>

---

Crown is a next-generation meta-framework for the [Nim](https://nim-lang.org/) programming language. It combines the blazing-fast performance of Nim with a modern, file-system-based routing architecture inspired by Next.js (App Router), empowering you to build hypermedia-driven applications with zero client-side JavaScript configuration.

## ✨ Features and Philosophy

- **Next.js-like Developer Experience (DX)**: Ditch manual route definitions. Crown uses a File-System Routing architecture where your `src/app/` directory perfectly mirrors your app's URLs.
- **Zero JS (State Management Free)**: Crown treats HTML as the engine of application state. By leveraging HTMX automatically under the hood, you get SPA-like partial page updates and rich UX without writing a single line of client-side JavaScript.
- **Solid Bedrock**: We didn't reinvent the wheel. Crown is built upon **[Basolato](https://github.com/itsumura-h/nim-basolato)**, leveraging its battle-tested HTTP server, security, and session management capabilities—completely abstracted away for your convenience.
- **Component Co-location**: No templating black magic. Write your views and your backend logic cleanly together in the same `.nim` file using native procs and the `html""" """` macro.
- **Tailwind CSS Ready**: Crown automatically injects Tailwind CSS by default, enabling you to style your application instantly without complex build pipelines.
- **Zero-Config PWA**: Automatically generates a Service Worker, manifest, and offline fallback (including Background Sync for API requests) with a single flip of a flag in `crown.json`.

## 🚀 Quick Start

Initialize a new Crown project in seconds:

```bash
# 1. Install the crown CLI (using Nimble)
nimble install -y https://github.com/valit/crown

# 2. Create a new directory and initialize the project
mkdir my_awesome_app
cd my_awesome_app
crown init

# 3. Start the development server
crown dev
```

_(Your app will be available at `http://localhost:5000/` with hot-reloading enabled!)_

## 📂 File-System Routing

Say goodbye to `routes.nim` boilerplate. With Crown, your directory structure defines your routes.

```text
my_awesome_app/
├── crown.json           # Configuration
├── src/
│   └── app/
│       ├── layout/
│       │   ├── layout.nim # Default layout (wraps pages by default)
│       │   └── admin.nim  # Custom "admin" layout
│       ├── page.nim       # Automatically maps to GET `/`
│       ├── editor/
│       │   └── page.nim   # Automatically maps to GET `/editor`
│       └── api/
│           └── save.nim   # Automatically maps to POST/GET `/api/save`
└── public/                # Static assets
```

> **Warning**: Never manually create `src/main.nim` or `src/routes.nim`. Crown generates highly-optimized routing logic automatically in the hidden `.crown/` directory for you.

## 💻 1-File Components (Showcase)

Crown allows you to elegantly handle multiple HTTP methods inside of a single page module. Return partial HTML snippets to handle `hx-post` requests magically.

```nim
# src/app/editor/page.nim
import crown/core
import tiara/components # Assuming you use Tiara UI components

# 1. Handle POST requests (Partial Updates)
proc post*(req: Request): string =
  let content = req.postParams.getOrDefault("content", "")
  # ... Perform DB Save Operations ...

  # Return a partial HTML snippet
  return html"""
    <div id="save-status" class="tiara-toast-success">
      Successfully saved!
    </div>
  """

# 2. Handle GET requests (Full Page Renders)
proc page*(req: Request): string =
  let initialContent = "Start typing here..."

  # By default, the output is injected into `src/app/layout/layout.nim`
  return html"""
    <div class="tiara-container">
      ...
    </div>
  """

# 3. Handle GET requests with Custom Layout
proc page*(req: Request, layout: Layout = "admin"): string =
  # Explicitly using "admin" maps to `src/app/layout/admin.nim`
  return html"""
    <div>Admin Dashboard</div>
  """
```

## 🧩 Components are just Strings

In Crown, HTML is primarily written with `html"""` and returned as a `string`.
Reusable UI pieces are ordinary Nim procedures that also return `string`.

```nim
proc badge(text: string): string =
  component"""<span class="badge">{text}</span>"""

proc page*(req: Request): string =
  html"""
    <div>
      {badge("new")}
    </div>
  """
```

*(Note: `component` is provided as an optional alias for `html` to improve code readability.)*

If you are migrating from pure Basolato and prefer using Templi `Component` objects, Crown does natively support returning `Component` and `Future[Component]` from routes as a backwards-compatibility feature. Components from Basolato are re-exported in `crown/core`.

### Scoped CSS Components

You can define components with co-located scoped CSS using the `component name(args):` macro form.
Inside `css:`, `.self` is replaced with a compile-time generated unique class.
Inside `html:`, `class="self"` (or `"foo self bar"`) is replaced with the same class.

```nim
import crown/core

component myButton(label: string):
  css: """
    .self {
      padding: var(--space-4);
      background: var(--primary);
    }
    .self:hover { opacity: 0.8; }
  """

  html:
    button(class="self"):
      text label
```

`component"""..."""` (string alias) is still available for backwards compatibility.

You can also write raw HTML directly in `html:`:

```nim
component myButtonRaw(label: string):
  css: """
    .self { padding: 8px 12px; }
  """
  html: """
    <button class="btn self">{label}</button>
  """
```

Raw HTML mode also supports PHP-like directives:

```nim
component listPanel(items: seq[string], showHeader: bool):
  css: ".self { padding: 12px; }"
  html: """
    <section class="self">
      {? if showHeader ?}
        <h2>Items</h2>
      {? end ?}
      <ul>
      {? for item in items ?}
        <li>{?= item ?}</li>
      {? endfor ?}
      </ul>
    </section>
  """
```

Supported directives:
- `{? if ... ?}`, `{? elif ... ?}`, `{? else ?}`, `{? end ?}` (`endif` also allowed)
- `{? for ... ?}`, `{? while ... ?}`, `{? case ... ?}`, `{? of ... ?}`, `{? endfor ?}`
- `{?= expr ?}` (inline expression output)

Inside `html:`, control flow (`if` / `for` / `case`) and nested function/component calls are supported.
Void elements like `input` and `br` are emitted without closing tags.

## 🔄 State Management & Component Updates

Crown explicitly avoids React-like two-way data binding or client-side component state synchronization. Instead, it fully embraces a **Server-Driven Re-rendering** model. 

The core philosophy is simple:
1. **Single Source of Truth (SSOT)**: Keep state in the parent page, UseCases, DB, or Session.
2. **Pure Functions**: Components are pure `props -> string` functions.
3. **Re-render on Change**: When a child needs an update, recalculate and return the new markup.

Here are the 4 practical patterns for handling state in Crown:

### 1. Persistent State (Parent Page Re-render)
When updating DB, Session, or Form values, update the state on the server and re-render the target components (or the entire parent page). This is the standard, simplest approach.

### 2. Partial Update Endpoints
If you want to update *only* a specific component from the parent page, do not mutate it directly. Instead, create a dedicated endpoint (e.g., `src/app/sidebar/page.nim` returning `sidebar(vm)`) and fetch its markup partially via HTMX (`hx-get`).

### 3. Sibling Synchronization
When updating one component affects another (e.g., an editor save updates a sidebar document count), rebuild the shared state on the server and return *both* pieces of HTML. You can swap them simultaneously using HTMX's Out-of-Band (OOB) swaps or simply re-render the parent target containing both.

### 4. Purely Local UI State
For transient states like modal visibility, active tabs, or drag-and-drop indicators, use lightweight client-side JavaScript (Vanilla JS, Alpine.js, etc.). Do not try to sync these micro-states with the server.

## 📂 Layout System

Crown provides a centralized layout system in `src/app/layout/`.

- **Default Layout**: Any `page` function without a custom layout parameter is automatically wrapped by `src/app/layout/layout.nim`.
- **Custom Layouts**: You can specify a layout by adding a second parameter to your `page` function: `proc page*(req: Request, layout: Layout = "admin")`. This will look for `src/app/layout/admin.nim`.
- **Disable Layout**: If you want to return a raw snippet without any layout (e.g., for HTMX parts), use `res.disableLayout()` or handle it via `post` routes which don't apply layouts by default.

## 🔗 Basolato and Nim versions

Crown supports **Basolato 0.15.0 through 0.16.x** and **Nim 2.2.x** (Nim ≥ 2.0 is required by `crown.nimble`).

| Basolato | Controller shape | Notes |
|----------|------------------|--------|
| 0.16.x | `proc(c: Context): Future[Response]` with `let p = c.params()` | Generated `.crown/routes.nim` uses `crownRouteRegister("get", ...)` and `Routes.merge` when available. |
| 0.15.x | `proc(c: Context, p: Params): Future[Response]` | Same macro; `when compiles` picks the two-argument branch. `Routes.merge` is omitted; routes are a `seq[Routes]`. |

**HTTP backend:** Basolato 0.16 with the stdlib server can hit GC-safety / `createResponse` issues on Nim 2.2; `crown build` and `crown dev` default to **`-d:httpbeast`**. For Basolato installs that need SSL and local app imports, Crown also adds **`-d:ssl`**, **`--path:.`**, and **`--nimcache:./nimcache`** unless you explicitly override them in `crown.json`.

**Name clashes:** In generated routes, Crown uses `import crown/core as crown` and qualifies `crown.Request` / `crown.Response` so they do not collide with Basolato’s `request` / `response` modules. The `crownRouteRegister` template uses exported aliases `BasolatoContext`, `BasolatoParams`, and `BasolatoHttpResponse` internally so expansion stays unambiguous with `import basolato/controller`.

**Issue repro (Basolato 0.15 + Nim 2.2):** Pin `basolato@0.15.0` in your app or `nimble`, use Nim 2.2.x from `PATH` (not a broken Nimble-cached copy), set `SECRET_KEY` before Basolato loads (see `tests/crown_test_env.nim`), add `-d:httpbeast` as in `tests/config.nims`, then `nimble test` from the Crown repo or `nim c -r -d:httpbeast tests/tcrown_route_register.nim`.

## 🛠 Command Line Interface

Crown comes with a powerful CLI to manage your project lifecycle.

- `crown init` — Scaffolds a new barebones project structure natively.
- `crown dev` — Boots the development server. It watches your `src/` directory and auto-recompiles routes dynamically.
- `crown build` — Compiles your application into a highly optimized, production-ready static binary inside the `.crown` directory (`.crown/main`).

## ⚙️ Compiler and Watcher Config

You can extend the Nim compiler flags used by both `crown build` and `crown dev` in `crown.json`.

```json
{
  "port": 5000,
  "tailwind": true,
  "pwa": false,
  "nimFlags": ["-d:ssl"],
  "buildFlags": ["-d:release", "-d:production_db"],
  "devFlags": ["--hints:off", "-d:dev_db"],
  "watchDirs": ["config"],
  "watchFiles": ["app.env"]
}
```

`nim.flags`, `nim.buildFlags`, `nim.devFlags`, `watch.dirs`, and `watch.files` are also accepted as nested forms. The dev server now inherits the full parent environment and overrides only `PORT` and `ENV`, so secrets like `TURSO_DATABASE_URL` and `TURSO_AUTH_TOKEN` continue to be available in the child process.

By default, Crown now compiles with `-d:httpbeast` (Basolato's `httpbeast` backend), `-d:ssl`, `--path:.`, and `--nimcache:./nimcache`.
If you want to switch backend or disable SSL explicitly, set define/undef flags in `nimFlags`, `buildFlags`, or `devFlags` (for example `"-u:httpbeast", "-d:httpx"` or `"-u:ssl"`). A custom `--nimcache:...` flag disables Crown's default nimcache path.

## 🤝 Contributing

We welcome contributions to make Crown the ultimate full-stack framework for Nim! Feel free to open issues or submit pull requests.

## 📄 License

This project is licensed under the MIT License.

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

## 📂 Layout System

Crown provides a centralized layout system in `src/app/layout/`.

- **Default Layout**: Any `page` function without a custom layout parameter is automatically wrapped by `src/app/layout/layout.nim`.
- **Custom Layouts**: You can specify a layout by adding a second parameter to your `page` function: `proc page*(req: Request, layout: Layout = "admin")`. This will look for `src/app/layout/admin.nim`.
- **Disable Layout**: If you want to return a raw snippet without any layout (e.g., for HTMX parts), use `res.disableLayout()` or handle it via `post` routes which don't apply layouts by default.

```

## 🛠 Command Line Interface

Crown comes with a powerful CLI to manage your project lifecycle.

- `crown init` — Scaffolds a new barebones project structure natively.
- `crown dev` — Boots the development server. It watches your `src/` directory and auto-recompiles routes dynamically.
- `crown build` — Compiles your application into a highly optimized, production-ready static binary inside the `.crown` directory (`.crown/main`).

## 🤝 Contributing

We welcome contributions to make Crown the ultimate full-stack framework for Nim! Feel free to open issues or submit pull requests.

## 📄 License

This project is licensed under the MIT License.
```

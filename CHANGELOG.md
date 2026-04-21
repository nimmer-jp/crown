# Changelog

## 0.4.5

- **crownRouteRegister**: Keeps Basolato 0.15 (two-argument `Context, Params` controller) and 0.16 (`Context` + `c.params()`) behind `when compiles`; uses `{.dirty.}`, explicit `Route.get` / `post` / … branches, and HTTP method strings (`"get"`, `"post"`, …). Exported aliases `BasolatoContext`, `BasolatoParams`, and `BasolatoHttpResponse` avoid ambiguous `Context` / `Response` at template expansion sites (Nim 2.2 + `import basolato/controller`).
- **generateRoutesCode**: `import crown/core as crown` and `crown.Request` / `crown.Response` in generated handlers; after per-route `let crownRouteN = ...`, emit `let routes* = Routes.merge(@[crownRoute0, ...])` when `Routes.merge` exists (Basolato 0.16+); else `let routes* = @[...]` for 0.15.
- **generateMainCode**: `serve(@[routes.routes], …)` when routes are merged to a single `Routes`; else `serve(routes.routes, …)` for legacy `seq[Routes]`.
- **Tests**: `tests/config.nims` adds `--path:../src` so `nimble test` / `nim c tests/…` resolve `crown/*` from the workspace `src/`. `tests/crown_test_env.nim` sets `SECRET_KEY` before Basolato initializes (Nim processes imports before other top-level statements). **nimble** `task test` runs `nim c -r` with the toolchain on `PATH` to avoid a known failure with some Nimble-cached compiler copies (`raiseIndexError2`).
- **Breaking (route helpers)**: `Request.get` was removed to avoid clashing with Basolato `Route.get` / unrelated `get` overloads when using `crownRouteRegister`. Use `Request.getStr` / `Params` accessors or `r.params` instead.

## 0.4.4

- **generateRoutesCode**: Emit each route as `let crownRouteN = crownRouteRegister(...): ...` then `let routes* = @[crownRoute0, ...]`. Colon-syntax template calls cannot be `@[ ... ]` elements in Nim 2.x (parse error).

## 0.4.3

- **Basolato 0.16**: Generated `main.nim` uses `serve(routes, settings)` with `Settings.new(host:, port:)` when `Settings` exists; otherwise `serve(routes)` for Basolato 0.15. `PORT` / `HOST` are read at runtime when using `Settings` (defaults: port 5000, host `0.0.0.0`).
- **Routes**: `crownRouteRegister` emits a single-argument `Controller` with `let p = c.params()` on Basolato 0.16, or the legacy `(Context, Params)` handler on 0.15 (`when compiles` at compile time).
- **httpbeast / httpx**: `clientIp` uses `request.hostname` for the peer after proxy headers; `asyncnet` is only imported for the asynchttpserver backend.
- **Basolato 0.16 re-exports**: Drop `export controller.getOrDefault` (use Crown / `Params.getStr`); export `templates.tmpli` only when declared (removed upstream in newer Basolato).

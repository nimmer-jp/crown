# Changelog

## 0.4.3

- **Basolato 0.16**: Generated `main.nim` calls `serve(routes, settings)` with `Settings.new` when available; falls back to `serve(routes)` on Basolato 0.15. Port from `PORT` (default 5000), host from `HOST` (default `0.0.0.0`) when using `Settings`.
- **Param.ext**: `crownParamsWithCatch` copies path params with `Param.new($v, v.fileName, ext(v))` (public getter) for Basolato 0.16’s `Param` type.
- **httpbeast / httpx**: `clientIp` uses the peer address from `request.hostname` (Basolato’s mapped client IP) instead of `getPeerAddr` / `AsyncSocket` on `req.client`. `asyncnet` is only imported on the asynchttpserver backend.
- **Routes**: `crownRouteRegister` emits a Basolato 0.16 single-argument controller (`let p = c.params()`) or a 0.15 `(Context, Params)` handler, selected at compile time.

## Basolato 0.16 + std server pulls async code that can fail GC-safety checks on Nim 2.2;
## match Crown’s default backend (see README / crown.json nimFlags).
switch("define", "httpbeast")
## Resolve `import crown/...` to the workspace `src/` (nimble test uses `--path:.` from repo root).
switch("path", "../src")

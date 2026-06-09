# Package

version       = "0.6.0"
author        = "pianopia"
description   = "Next generation meta-framework for Nim, powered by Basolato and HTMX"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
skipDirs      = @["website", "example"]
bin           = @["crown"]

# Dependencies

requires "nim >= 2.2.0"
requires "https://github.com/itsumura-h/nim-basolato#v0.15.0"
requires "cligen"
requires "tiara >= 0.1.0"

# Basolato は `requires` と `crown dev` / `ensureBasolatoPinnedForCrown` で取得する。
# Nimble の `before install` から `nimble install ...#v0.15.0` を実行しないこと:
# Nimble がフラグメント付き URL を `git ls-remote` に渡して失敗したあと `hg` にフォールバックし、
# 「'hg' not in PATH」などの誤ったエラーになる（Mercurial が要るわけではない）。
# 手動で依存を先に置きたい場合は `bash scripts/bootstrap_nimble_deps.sh`。

# Default `nimble test` may invoke a broken Nim copy from Nimble's package cache on some setups
# (internal error: system module needs: raiseIndexError2). This task runs tests with `nim` from PATH.
task test, "Run unit tests":
  exec "nim c -r -d:httpbeast tests/tcrown_route_register.nim"
  exec "nim c -r -d:httpbeast tests/tgenerator.nim"
  exec "nim c -r -d:httpbeast --out:tests/tproject.out tests/tproject.nim"
  exec "nim c -r -d:httpbeast tests/tscoped_component.nim"

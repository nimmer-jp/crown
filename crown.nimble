# Package

version       = "0.5.1"
author        = "pianopia"
description   = "Next generation meta-framework for Nim, powered by Basolato and HTMX"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
skipDirs      = @["website", "example"]
bin           = @["crown"]

# Dependencies

requires "nim >= 2.0.0"
requires "https://github.com/itsumura-h/nim-basolato#0.15.0"
requires "cligen"
requires "tiara >= 0.1.0"

# Default `nimble test` may invoke a broken Nim copy from Nimble’s package cache on some setups
# (internal error: system module needs: raiseIndexError2). This task runs tests with `nim` from PATH.
task test, "Run unit tests":
  exec "nim c -r -d:httpbeast tests/tcrown_route_register.nim"
  exec "nim c -r -d:httpbeast tests/tgenerator.nim"
  exec "nim c -r -d:httpbeast --out:tests/tproject.out tests/tproject.nim"
  exec "nim c -r -d:httpbeast tests/tscoped_component.nim"

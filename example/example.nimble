version       = "0.1.0"
author        = "Example User"
description   = "A new awesome Crown app"
license       = "MIT"
srcDir        = "src"

requires "nim >= 2.2.0"
requires "https://github.com/itsumura-h/nim-basolato#v0.15.0"
requires "https://github.com/nimmer-jp/tiara >= 0.1.0"

# Ensures Nimble downloads Basolato v0.15.0 (Crown toolchain) alongside any other installs.
before install:
  exec nimbleExe & " install -y https://github.com/itsumura-h/nim-basolato#v0.15.0"

# ../../src パスへの依存は nim.cfg で解決

# Package

version       = "0.4.4"
author        = "pianopia"
description   = "Next generation meta-framework for Nim, powered by Basolato and HTMX"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
skipDirs      = @["website", "example"]
bin           = @["crown"]

# Dependencies

requires "nim >= 2.0.0"
requires "https://github.com/itsumura-h/nim-basolato"
requires "cligen"
requires "https://github.com/nimmer-jp/tiara"

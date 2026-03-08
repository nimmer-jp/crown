# Package

version       = "0.1.0"
author        = "pianopia"
description   = "Next generation meta-framework for Nim, powered by Basolato and HTMX"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["crown"]

# Dependencies

requires "nim >= 2.0.0"
requires "basolato"
requires "cligen"
requires "https://github.com/nimmer-jp/tiara"

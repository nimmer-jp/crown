version       = "0.1.0"
author        = "Example User"
description   = "A new awesome Crown app"
license       = "MIT"
srcDir        = "src"

requires "nim >= 2.2.0"
requires "https://github.com/itsumura-h/nim-basolato#v0.15.0"
requires "https://github.com/nimmer-jp/tiara >= 0.1.0"

# Crown / Nimble: フラグメント付き git URL を before install の nimble install で回さないこと
# （Nimble の URL 判定バグ → 'hg' not in PATH のように見える）。
# 必要ならプロジェクトで `bash scripts/bootstrap_nimble_deps.sh`（このリポからコピー可）。

# ../../src パスへの依存は nim.cfg で解決

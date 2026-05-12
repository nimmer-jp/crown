#!/usr/bin/env bash
## Install Basolato v0.15.0 without passing a Nimble `#tag` fragment on the CLI.
## Nimble may call `git ls-remote 'https://...git#v0.15.0'`, fail, then probe `hg` and
## report `'hg' not in PATH` (Mercurial is not required—the URL fragment confused VCS probing).
##
## Optional: neutralizes stale `before install` hooks that run `nimble install ...#v0.15.0`
## in Nimble pkgcache copies of crown.nimble.
## Usage (from Crown repo clone): bash scripts/bootstrap_nimble_deps.sh
set -euo pipefail

NIMBLE_DIR="${NIMBLE_DIR:-"$HOME/.nimble"}"
BASOLATO_REPO="https://github.com/itsumura-h/nim-basolato.git"
BASOLATO_TAG="v0.15.0"
CACHE_ROOT="${NIMBLE_DIR}/crown-bootstrap-cache"
CLONE_DIR="${CACHE_ROOT}/nim-basolato"

have_pkgs2_basolato() {
  local d
  shopt -s nullglob
  for d in "${NIMBLE_DIR}/pkgs2/basolato-0.15.0-"*; do
    if [[ -d "$d" && -f "$d/basolato.nimble" ]]; then
      shopt -u nullglob
      return 0
    fi
  done
  shopt -u nullglob
  return 1
}

install_basolato_from_clone() {
  if have_pkgs2_basolato; then
    echo "✓ Basolato 0.15.0 already present under pkgs2"
    return 0
  fi
  mkdir -p "$CACHE_ROOT"
  if [[ ! -d "${CLONE_DIR}/.git" ]]; then
    git clone --branch "$BASOLATO_TAG" --depth 1 "$BASOLATO_REPO" "$CLONE_DIR"
  else
    git -C "$CLONE_DIR" fetch --depth 1 origin "refs/tags/${BASOLATO_TAG}:refs/tags/${BASOLATO_TAG}" 2>/dev/null \
      || git -C "$CLONE_DIR" fetch --tags origin
    git -C "$CLONE_DIR" checkout -q "${BASOLATO_TAG}"
  fi
  nimble install -y "$CLONE_DIR"
}

neutralize_pkgcache_crown_hooks() {
  command -v python3 >/dev/null 2>&1 || return 0
  local pc="${NIMBLE_DIR}/pkgcache"
  [[ -d "$pc" ]] || return 0
  NIMBLE_DIR="$NIMBLE_DIR" python3 - <<'PY'
import os, re
from pathlib import Path
root = Path(os.environ["NIMBLE_DIR"]) / "pkgcache"
if not root.is_dir():
    raise SystemExit(0)
pat = re.compile(
    r"\nbefore\s+install\s*:\s*\n(?:[ \t]+[^\n]+\n)+",
    re.MULTILINE,
)
rep = "\n# before install: removed by crown scripts/bootstrap_nimble_deps.sh (Nimble #fragment / VCS probe issue)\n"
for p in root.rglob("crown.nimble"):
    try:
        t = p.read_text(encoding="utf-8", errors="replace")
    except OSError:
        continue
    if "nim-basolato#v0.15.0" not in t:
        continue
    t2, n = pat.subn(rep, t, count=1)
    if n and t2 != t:
        p.write_text(t2, encoding="utf-8")
        print("patched", p)
PY
}

install_basolato_from_clone
neutralize_pkgcache_crown_hooks
echo "✓ bootstrap_nimble_deps.sh finished"

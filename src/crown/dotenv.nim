import std/[os, strutils]

proc crownFindProjectRoot*(): string =
  ## Walk upward from ``getCurrentDir()`` until ``crown.json`` is found.
  var d = getCurrentDir()
  for _ in 0 ..< 64:
    if fileExists(d / "crown.json"):
      return d
    let p = parentDir(d)
    if p == d:
      break
    d = p
  return ""

proc applyDotEnvFile*(filePath: string) =
  ## Very small ``.env`` parser: ``KEY=value``, ``#`` comments, optional ``export `` prefix,
  ## simple single/double quote stripping. Each line calls ``putEnv`` (overwrites).
  if not fileExists(filePath):
    return
  let text = readFile(filePath)
  for rawLine in text.splitLines():
    var line = rawLine.strip()
    if line.len == 0 or line[0] == '#':
      continue
    if line.startsWith("export "):
      line = line[7 .. ^1].strip()
    let eq = line.find('=')
    if eq < 1:
      continue
    let key = line[0 ..< eq].strip()
    if key.len == 0:
      continue
    var val = line[eq + 1 .. ^1].strip()
    if val.len >= 2:
      if (val[0] == '"' and val[^1] == '"') or (val[0] == '\'' and val[^1] == '\''):
        val = val[1 .. ^2]
    putEnv(key, val)

proc primeCrownEnvironment*() =
  ## Load ``<project>/.env`` then ``<project>/.env.local`` when ``crown.json`` can be found.
  ## Intended to run before Basolato imports its own env layer.
  let root = crownFindProjectRoot()
  if root.len == 0:
    return
  applyDotEnvFile(root / ".env")
  applyDotEnvFile(root / ".env.local")

proc primeCrownEnvironmentBeforeBasolato*() {.inline.} =
  ## Hook name used by generated ``crown_env_preserver`` (stable even if internals change).
  primeCrownEnvironment()

proc loadCrownDotEnv*() {.inline.} =
  ## App-callable alias for the same priming used by generated ``crown_env_preserver``.
  primeCrownEnvironment()

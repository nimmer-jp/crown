import std/[algorithm, json, os, osproc, strtabs, strutils]

type
  BuildMode* = enum
    bmBuild, bmDev

  CrownConfig* = object
    port*: string
    nimFlags*: seq[string]
    buildFlags*: seq[string]
    devFlags*: seq[string]
    watchDirs*: seq[string]
    watchFiles*: seq[string]
    ## Extra ``--path:`` entries for ``nim c`` (monorepos, local nimble checkouts, etc.).
    compilerPaths*: seq[string]

const
  crownProjectSourcePath = currentSourcePath()
  basolatoVersion = "0.15.0"
  basolatoGitRef = "v0.15.0" ## Upstream tag (`v` prefix); Nimble URL fragment

proc getCrownPackagePath*(): string =
  ## Path Nim should use to import the same Crown package as this CLI binary.
  crownProjectSourcePath.parentDir().parentDir()

proc getNimbleDir*(): string =
  let configured = getEnv("NIMBLE_DIR").strip()
  if configured.len > 0:
    return configured
  getHomeDir() / ".nimble"

proc getBasolatoPackagePath*(nimbleDir = getNimbleDir()): string =
  ## Pin Basolato imports to Crown's supported version even when newer versions
  ## are also installed in Nimble's global package cache.
  let pkgs2Dir = nimbleDir / "pkgs2"
  if not dirExists(pkgs2Dir):
    return ""

  let prefix = "basolato-" & basolatoVersion & "-"
  var candidates: seq[string] = @[]
  for kind, path in walkDir(pkgs2Dir):
    if kind == pcDir and path.extractFilename().startsWith(prefix) and
        fileExists(path / "basolato.nimble"):
      candidates.add(path)

  if candidates.len == 0:
    return ""

  candidates.sort()
  candidates[0]

proc nonPinnedBasolatoInstallRoots*(nimbleDir = getNimbleDir()): seq[string] =
  ## Nimble dirs for Basolato builds whose version differs from Crown's pinned
  ## ``basolatoVersion``. Used with Nim ``--excludePath`` so imports resolve to
  ## 0.15 even when 0.16+ is installed beside it.
  result = @[]
  let pinnedPrefix = "basolato-" & basolatoVersion & "-"
  for sub in @["pkgs2", "pkgs"]:
    let root = nimbleDir / sub
    if not dirExists(root):
      continue
    for kind, path in walkDir(root):
      if kind != pcDir:
        continue
      let name = path.extractFilename()
      if not name.startsWith("basolato-"):
        continue
      if name.startsWith(pinnedPrefix):
        continue
      if not fileExists(path / "basolato.nimble"):
        continue
      result.add(path)
  result.sort()

proc basolatoNimbleGitUrl*(): string =
  ## URL Nimble installs from to obtain ``basolatoVersion``.
  result = "https://github.com/itsumura-h/nim-basolato#" & basolatoGitRef

proc ensureBasolatoPinnedForCrown*(nimbleDir = getNimbleDir()): bool =
  ## Ensures Nimble pkgs contain Basolato ``basolatoVersion``.
  ##
  ## If only a newer Basolato (for example 0.16+) is installed, runs
  ## ``nimble install -y`` for ``basolatoGitRef`` once so Crown compiles
  ## against the pinned tree (both versions may coexist).
  ##
  ## Set ``CROWN_NO_AUTO_BASELATO=1`` (or ``true``, ``yes``, ``on``) to skip auto-install.
  if getBasolatoPackagePath(nimbleDir).len > 0:
    return true
  let skip = strip(getEnv("CROWN_NO_AUTO_BASELATO", ""))
  if skip in ["1", "true", "yes", "on"]:
    echo "❌ Crown requires Basolato " & basolatoVersion &
        ", but it is not installed under: " & nimbleDir
    echo "   Run: nimble install " & basolatoNimbleGitUrl()
    echo "   (Unset CROWN_NO_AUTO_BASELATO to allow Crown to install Basolato automatically.)"
    return false
  let nimbleBin = strip(findExe("nimble"))
  if nimbleBin.len == 0:
    echo "❌ `nimble` not found on PATH; cannot install Basolato " & basolatoVersion &
        " automatically."
    echo "   Run: nimble install " & basolatoNimbleGitUrl()
    return false
  echo "📦 Installing Basolato ", basolatoVersion,
      " under Nimble (Crown pinned build; newer Basolato can remain installed)."
  let installArgs = @[ "install", basolatoNimbleGitUrl(), "-y",
      "--nimbleDir:" & nimbleDir ]
  let p =
    startProcess(nimbleBin, args = installArgs, options = {poUsePath, poParentStreams})
  let code = waitForExit(p)
  close(p)
  if code != 0:
    echo "❌ `nimble install` failed with exit code ", code, "."
    echo "   Retry manually: nimble install " & basolatoNimbleGitUrl()
    return false
  if getBasolatoPackagePath(nimbleDir).len == 0:
    echo "❌ Basolato ", basolatoVersion, " missing after install. Expected under: ",
        nimbleDir / "pkgs2"
    return false
  result = true

proc addUnique(dest: var seq[string], values: openArray[string]) =
  for value in values:
    let normalized = value.strip()
    if normalized.len > 0 and normalized notin dest:
      dest.add(normalized)

proc hasServerBackendFlag(flags: openArray[string]): bool =
  for value in flags:
    let normalized = value.strip()
    if normalized in [
      "-d:httpbeast",
      "--define:httpbeast",
      "-u:httpbeast",
      "--undef:httpbeast",
      "-d:httpx",
      "--define:httpx",
      "-u:httpx",
      "--undef:httpx"
    ]:
      return true

proc hasDefineOrUndefFlag(flags: openArray[string], symbol: string): bool =
  for value in flags:
    let normalized = value.strip()
    if normalized in [
      "-d:" & symbol,
      "--define:" & symbol,
      "-u:" & symbol,
      "--undef:" & symbol
    ]:
      return true

proc hasCurrentDirPathFlag(flags: openArray[string]): bool =
  for value in flags:
    let normalized = value.strip().replace("\"", "")
    if normalized in ["--path:.", "--path=.", "--path:./", "--path=./"]:
      return true

proc hasNimCacheFlag(flags: openArray[string]): bool =
  for value in flags:
    let normalized = value.strip()
    if normalized.startsWith("--nimcache"):
      return true

proc readStringSeq(node: JsonNode, key: string): seq[string] =
  if node.kind != JObject or not node.hasKey(key):
    return @[]
  let values = node[key]
  if values.kind != JArray:
    return @[]
  for value in values:
    if value.kind == JString:
      result.add(value.getStr())

proc readPort(node: JsonNode): string =
  if node.kind != JObject or not node.hasKey("port"):
    return ""
  let port = node["port"]
  case port.kind
  of JInt:
    result = $port.getInt()
  of JString:
    result = port.getStr()
  else:
    discard

proc loadCrownConfig*(): CrownConfig =
  result = CrownConfig(
    port: "8080",
    nimFlags: @[],
    buildFlags: @[],
    devFlags: @[],
    watchDirs: @[],
    watchFiles: @[],
    compilerPaths: @[]
  )

  if not fileExists("crown.json"):
    return

  try:
    let root = parseFile("crown.json")
    let port = readPort(root)
    if port.len > 0:
      result.port = port

    addUnique(result.nimFlags, readStringSeq(root, "nimFlags"))
    addUnique(result.buildFlags, readStringSeq(root, "buildFlags"))
    addUnique(result.devFlags, readStringSeq(root, "devFlags"))
    addUnique(result.watchDirs, readStringSeq(root, "watchDirs"))
    addUnique(result.watchFiles, readStringSeq(root, "watchFiles"))
    addUnique(result.compilerPaths, readStringSeq(root, "compilerPaths"))

    if root.kind == JObject and root.hasKey("nim") and root["nim"].kind == JObject:
      let nimNode = root["nim"]
      addUnique(result.nimFlags, readStringSeq(nimNode, "flags"))
      addUnique(result.buildFlags, readStringSeq(nimNode, "buildFlags"))
      addUnique(result.devFlags, readStringSeq(nimNode, "devFlags"))
      addUnique(result.compilerPaths, readStringSeq(nimNode, "compilerPaths"))

    if root.kind == JObject and root.hasKey("watch") and root["watch"].kind == JObject:
      let watchNode = root["watch"]
      addUnique(result.watchDirs, readStringSeq(watchNode, "dirs"))
      addUnique(result.watchFiles, readStringSeq(watchNode, "files"))
  except CatchableError:
    discard

proc getCompileArgs*(config: CrownConfig, mode: BuildMode, mainPath: string,
    nimbleDir = getNimbleDir()): seq[string] =
  result = @["c"]
  addUnique(result, @["--path:" & getCrownPackagePath()])
  let basolatoPath = getBasolatoPackagePath(nimbleDir)
  if basolatoPath.len > 0:
    addUnique(result, @["--path:" & basolatoPath])
  for extra in config.compilerPaths:
    let p = extra.strip()
    if p.len == 0:
      continue
    addUnique(result, @["--path:" & absolutePath(p)])
  let excludeBas = nonPinnedBasolatoInstallRoots(nimbleDir)
  let modeFlags = case mode
    of bmBuild:
      config.buildFlags
    of bmDev:
      config.devFlags
  if not hasServerBackendFlag(config.nimFlags) and not hasServerBackendFlag(modeFlags):
    addUnique(result, @["-d:httpbeast"])
  if not hasDefineOrUndefFlag(config.nimFlags, "ssl") and
      not hasDefineOrUndefFlag(modeFlags, "ssl"):
    addUnique(result, @["-d:ssl"])
  if not hasCurrentDirPathFlag(config.nimFlags) and
      not hasCurrentDirPathFlag(modeFlags):
    addUnique(result, @["--path:."])
  if not hasNimCacheFlag(config.nimFlags) and not hasNimCacheFlag(modeFlags):
    addUnique(result, @["--nimcache:./nimcache"])
  addUnique(result, config.nimFlags)
  case mode
  of bmBuild:
    addUnique(result, @["-d:release"])
    addUnique(result, config.buildFlags)
  of bmDev:
    addUnique(result, @["--hints:off"])
    addUnique(result, config.devFlags)
  for alien in excludeBas:
    if alien.len > 0:
      addUnique(result, @["--excludePath:" & absolutePath(alien)])
  result.add(mainPath)

proc buildProcessEnv*(overrides: openArray[(string, string)]): StringTableRef =
  result = newStringTable(modeCaseSensitive)
  for key, value in envPairs():
    result[key] = value
  for entry in overrides:
    result[entry[0]] = entry[1]

proc runNimCompile*(config: CrownConfig, mode: BuildMode, mainPath: string,
    overrides: openArray[(string, string)]): int =
  if getBasolatoPackagePath().len == 0:
    if not ensureBasolatoPinnedForCrown():
      return 1

  let process = startProcess("nim",
    args = getCompileArgs(config, mode, mainPath),
    env = buildProcessEnv(overrides),
    options = {poUsePath, poParentStreams}
  )
  result = waitForExit(process)
  close(process)

proc getWatchDirs*(config: CrownConfig, appDir: string): seq[string] =
  let parent = appDir.parentDir()
  if parent.len > 0 and parent != ".":
    addUnique(result, @[parent])
  else:
    addUnique(result, @[appDir])
  addUnique(result, @["public"])
  addUnique(result, config.watchDirs)

proc getWatchFiles*(config: CrownConfig): seq[string] =
  addUnique(result, @["crown.json", "crown.nimble", "nim.cfg", ".env"])
  addUnique(result, config.watchFiles)

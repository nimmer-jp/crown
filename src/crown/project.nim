import std/[json, os, osproc, strtabs, strutils]

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
    devIncremental*: bool
    tailwindCliEnabled*: bool
    tailwindCliInput*: string
    tailwindCliOutput*: string
    frontendEnabled*: bool
    frontendEntry*: string
    frontendRouteEntry*: string
    frontendBuilder*: string
    frontendOverlay*: bool

proc addUnique(dest: var seq[string], values: openArray[string]) =
  for value in values:
    let normalized = value.strip()
    if normalized.len > 0 and normalized notin dest:
      dest.add(normalized)

proc hasIncrementalCliFlag*(flags: openArray[string]): bool =
  for value in flags:
    let normalized = value.strip()
    if normalized.startsWith("--incremental:"):
      return true
  false

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

proc readStringSeq(node: JsonNode, key: string): seq[string] =
  if node.kind != JObject or not node.hasKey(key):
    return @[]
  let values = node[key]
  if values.kind != JArray:
    return @[]
  for value in values:
    if value.kind == JString:
      result.add(value.getStr())

proc readString(node: JsonNode, key: string): string =
  if node.kind != JObject or not node.hasKey(key):
    return ""
  if node[key].kind == JString:
    return node[key].getStr()
  ""

proc readBool(node: JsonNode, key: string): tuple[ok: bool, value: bool] =
  if node.kind != JObject or not node.hasKey(key):
    return (false, false)
  let value = node[key]
  if value.kind == JBool:
    return (true, value.getBool())
  (false, false)

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
    port: "5000",
    nimFlags: @[],
    buildFlags: @[],
    devFlags: @[],
    watchDirs: @[],
    watchFiles: @[],
    devIncremental: true,
    tailwindCliEnabled: false,
    tailwindCliInput: "src/input.css",
    tailwindCliOutput: "public/app.css",
    frontendEnabled: true,
    frontendEntry: "src/app.js",
    frontendRouteEntry: "client.js",
    frontendBuilder: "auto",
    frontendOverlay: true
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

    let topFrontendEntry = readString(root, "frontendEntry").strip()
    if topFrontendEntry.len > 0:
      result.frontendEntry = topFrontendEntry

    let topFrontendRouteEntry = readString(root, "frontendRouteEntry").strip()
    if topFrontendRouteEntry.len > 0:
      result.frontendRouteEntry = topFrontendRouteEntry

    let topFrontendBuilder = readString(root, "frontendBuilder").strip()
    if topFrontendBuilder.len > 0:
      result.frontendBuilder = topFrontendBuilder.toLowerAscii()

    let topFrontendEnabled = readBool(root, "frontendEnabled")
    if topFrontendEnabled.ok:
      result.frontendEnabled = topFrontendEnabled.value

    let topFrontendOverlay = readBool(root, "frontendOverlay")
    if topFrontendOverlay.ok:
      result.frontendOverlay = topFrontendOverlay.value

    let topDevIncremental = readBool(root, "devIncremental")
    if topDevIncremental.ok:
      result.devIncremental = topDevIncremental.value

    if root.kind == JObject and root.hasKey("tailwind") and root["tailwind"].kind == JObject:
      let tw = root["tailwind"]
      if tw.hasKey("cli") and tw["cli"].kind == JObject:
        let cli = tw["cli"]
        let cliEn = readBool(cli, "enabled")
        if cliEn.ok:
          result.tailwindCliEnabled = cliEn.value
        let cliIn = readString(cli, "input").strip()
        if cliIn.len > 0:
          result.tailwindCliInput = cliIn
        let cliOut = readString(cli, "output").strip()
        if cliOut.len > 0:
          result.tailwindCliOutput = cliOut

    if root.kind == JObject and root.hasKey("nim") and root["nim"].kind == JObject:
      let nimNode = root["nim"]
      addUnique(result.nimFlags, readStringSeq(nimNode, "flags"))
      addUnique(result.buildFlags, readStringSeq(nimNode, "buildFlags"))
      addUnique(result.devFlags, readStringSeq(nimNode, "devFlags"))
      let nimDevInc = readBool(nimNode, "devIncremental")
      if nimDevInc.ok:
        result.devIncremental = nimDevInc.value

    if root.kind == JObject and root.hasKey("watch") and root["watch"].kind == JObject:
      let watchNode = root["watch"]
      addUnique(result.watchDirs, readStringSeq(watchNode, "dirs"))
      addUnique(result.watchFiles, readStringSeq(watchNode, "files"))

    if root.kind == JObject and root.hasKey("frontend") and root["frontend"].kind == JObject:
      let frontendNode = root["frontend"]

      let frontendEnabled = readBool(frontendNode, "enabled")
      if frontendEnabled.ok:
        result.frontendEnabled = frontendEnabled.value

      let frontendEntry = readString(frontendNode, "entry").strip()
      if frontendEntry.len > 0:
        result.frontendEntry = frontendEntry

      let frontendRouteEntry = readString(frontendNode, "routeEntry").strip()
      if frontendRouteEntry.len > 0:
        result.frontendRouteEntry = frontendRouteEntry

      let frontendBuilder = readString(frontendNode, "builder").strip()
      if frontendBuilder.len > 0:
        result.frontendBuilder = frontendBuilder.toLowerAscii()

      let frontendOverlay = readBool(frontendNode, "overlay")
      if frontendOverlay.ok:
        result.frontendOverlay = frontendOverlay.value
  except:
    discard

proc getCompileArgs*(config: CrownConfig, mode: BuildMode, mainPath: string): seq[string] =
  result = @["c"]
  let modeFlags = case mode
    of bmBuild:
      config.buildFlags
    of bmDev:
      config.devFlags
  if not hasServerBackendFlag(config.nimFlags) and not hasServerBackendFlag(modeFlags):
    addUnique(result, @["-d:httpbeast"])
  addUnique(result, config.nimFlags)
  case mode
  of bmBuild:
    addUnique(result, @["-d:release"])
    addUnique(result, config.buildFlags)
  of bmDev:
    addUnique(result, @["--hints:off"])
    addUnique(result, config.devFlags)
    if config.devIncremental and not hasIncrementalCliFlag(config.nimFlags) and
        not hasIncrementalCliFlag(config.devFlags):
      addUnique(result, @["--incremental:on"])
  result.add(mainPath)

proc buildProcessEnv*(overrides: openArray[(string, string)]): StringTableRef =
  result = newStringTable(modeCaseSensitive)
  for key, value in envPairs():
    result[key] = value
  for entry in overrides:
    result[entry[0]] = entry[1]

proc runNimCompile*(config: CrownConfig, mode: BuildMode, mainPath: string,
    overrides: openArray[(string, string)]): int =
  let process = startProcess("nim",
    args = getCompileArgs(config, mode, mainPath),
    env = buildProcessEnv(overrides),
    options = {poUsePath, poParentStreams}
  )
  result = waitForExit(process)
  close(process)

proc getCheckArgs*(config: CrownConfig, mainPath: string): seq[string] =
  ## Flags for `nim check` (dev-oriented; no `--incremental`, no `-d:release`).
  result = @["check", "--hints:off"]
  if not hasServerBackendFlag(config.nimFlags) and not hasServerBackendFlag(
      config.devFlags):
    addUnique(result, @["-d:httpbeast"])
  addUnique(result, config.nimFlags)
  addUnique(result, config.devFlags)
  result.add(mainPath)

proc runNimCheck*(config: CrownConfig, mainPath: string,
    overrides: openArray[(string, string)]): int =
  let process = startProcess("nim",
    args = getCheckArgs(config, mainPath),
    env = buildProcessEnv(overrides),
    options = {poUsePath, poStdErrToStdOut, poParentStreams}
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
  if config.frontendEntry.len > 0:
    addUnique(result, @[config.frontendEntry])
  if config.tailwindCliEnabled and config.tailwindCliInput.len > 0:
    addUnique(result, @[config.tailwindCliInput])
  addUnique(result, config.watchFiles)

import std/[json, os, osproc, streams, strutils, tables]
import generator
import project

type
  FrontendBuildResult* = object
    success*: bool
    hasEntries*: bool
    builder*: string
    message*: string

proc normalizeBuilder(builder: string): string =
  let normalized = builder.strip().toLowerAscii()
  if normalized in ["bun", "copy"]:
    return normalized
  "auto"

proc resolveBuilder(config: CrownConfig): string =
  let requested = normalizeBuilder(config.frontendBuilder)
  if requested == "bun":
    return "bun"
  if requested == "copy":
    return "copy"
  if findExe("bun").len > 0:
    return "bun"
  "copy"

proc runProcessCapture(cmd: string, args: seq[string]): tuple[exitCode: int, output: string] =
  let process =
    try:
      startProcess(cmd,
        args = args,
        options = {poUsePath, poStdErrToStdOut}
      )
    except CatchableError as err:
      return (127, err.msg)

  var output = ""
  if outputStream(process) != nil:
    output = outputStream(process).readAll()

  let exitCode = waitForExit(process)
  close(process)
  (exitCode, output)

proc writeFileIfChanged(path, content: string) =
  if fileExists(path) and readFile(path) == content:
    return
  writeFile(path, content)

proc buildWithBun(sourcePath, outPath: string, mode: BuildMode): tuple[ok: bool, output: string] =
  var args = @[
    "build",
    sourcePath,
    "--target=browser",
    "--format=esm",
    "--outfile",
    outPath
  ]

  if mode == bmDev:
    args.add("--sourcemap=inline")
  else:
    args.add("--minify")

  let (exitCode, output) = runProcessCapture("bun", args)
  (exitCode == 0, output)

proc buildWithCopy(sourcePath, outPath: string): tuple[ok: bool, output: string] =
  try:
    copyFile(sourcePath, outPath)
    (true, "")
  except CatchableError as err:
    (false, err.msg)

proc buildEntry(builder, sourcePath, outPath: string, mode: BuildMode): tuple[ok: bool, output: string] =
  createDir(outPath.parentDir())
  case builder
  of "bun":
    buildWithBun(sourcePath, outPath, mode)
  else:
    buildWithCopy(sourcePath, outPath)

proc writeFrontendManifest(outDir, globalScript: string,
    routeScripts: OrderedTable[string, string], overlay: bool) =
  var routesJson = newJObject()
  for routePath, scriptUrl in routeScripts:
    routesJson[routePath] = %scriptUrl

  let manifest = %*{
    "globalScript": globalScript,
    "routeScripts": routesJson,
    "overlay": overlay
  }
  writeFileIfChanged(outDir / "frontend-manifest.json", $manifest)

proc writeFrontendError(outDir, message: string) =
  let payload = %*{"error": message}
  writeFileIfChanged(outDir / "frontend-error.json", $payload)

proc runTailwindIfConfigured*(config: CrownConfig, mode: BuildMode): tuple[
    ok: bool, message: string] =
  ## Runs standalone `tailwindcss` when `crown.json` enables `tailwind.cli`.
  result = (ok: true, message: "")
  if not config.tailwindCliEnabled:
    return
  let inputPath = config.tailwindCliInput.strip()
  let outputPath = config.tailwindCliOutput.strip()
  if inputPath.len == 0 or outputPath.len == 0:
    return (ok: false, message: "tailwind.cli: set `input` and `output` in crown.json")
  if not fileExists(inputPath):
    return (ok: false, message: "tailwind cli: input not found: " & inputPath)
  if findExe("tailwindcss").len == 0:
    return (ok: false, message:
        "tailwindcss CLI not found on PATH (https://tailwindcss.com/docs/installation)")
  var args = @["-i", inputPath, "-o", outputPath]
  if mode == bmBuild:
    args.add("--minify")
  try:
    createDir(outputPath.parentDir())
  except CatchableError as err:
    return (ok: false, message: err.msg)
  let (exitCode, output) = runProcessCapture("tailwindcss", args)
  if exitCode != 0:
    return (ok: false, message: "tailwindcss failed:\n" & output)
  result = (ok: true, message: "")

proc buildFrontendAssets*(config: CrownConfig, appDir, outDir: string,
    mode: BuildMode): FrontendBuildResult =
  result.success = true
  result.hasEntries = false
  createDir(outDir)

  if not config.frontendEnabled:
    writeFrontendManifest(outDir, "", initOrderedTable[string, string](),
        config.frontendOverlay)
    writeFrontendError(outDir, "")
    result.builder = "disabled"
    return

  if not dirExists("public"):
    createDir("public")

  let builder = resolveBuilder(config)
  result.builder = builder

  var errors: seq[string]
  var globalScript = ""
  var routeScripts = initOrderedTable[string, string]()

  let globalEntry = config.frontendEntry.strip()
  if globalEntry.len > 0 and fileExists(globalEntry):
    result.hasEntries = true
    let outputPath = "public" / "app.js"
    let (ok, output) = buildEntry(builder, globalEntry, outputPath, mode)
    if ok:
      globalScript = "/app.js"
    else:
      errors.add("Global frontend entry failed: " & globalEntry & "\n" & output)

  let routeEntryFile = config.frontendRouteEntry.strip()
  if routeEntryFile.len > 0:
    for entry in collectRouteClientEntries(appDir, routeEntryFile):
      result.hasEntries = true
      let outputPath = "public" / ".crown" / "client" / entry.assetPath
      let (ok, output) = buildEntry(builder, entry.sourcePath, outputPath, mode)
      if ok:
        routeScripts[entry.urlPath] = routeClientScriptUrl(entry.urlPath)
      else:
        errors.add("Route frontend entry failed (" & entry.urlPath & "): " &
            entry.sourcePath & "\n" & output)

  writeFrontendManifest(outDir, globalScript, routeScripts, config.frontendOverlay)

  if errors.len > 0:
    result.success = false
    result.message = errors.join("\n\n")
    writeFrontendError(outDir, result.message)
    return

  writeFrontendError(outDir, "")

proc normalizeForCompare(path: string): string =
  if path.len == 0:
    return ""
  expandFilename(path).replace('\\', '/')

proc isFrontendWatchPath*(path: string, config: CrownConfig, appDir: string): bool =
  let currentPath = normalizeForCompare(path)
  if currentPath.len == 0:
    return false

  let globalEntry = normalizeForCompare(config.frontendEntry)
  if globalEntry.len > 0 and currentPath == globalEntry:
    return true

  let routeEntry = config.frontendRouteEntry.strip()
  if routeEntry.len == 0:
    return false

  let appRoot = normalizeForCompare(appDir)
  let routeSuffix = "/" & routeEntry.replace('\\', '/')

  if appRoot.len == 0:
    return false

  currentPath.startsWith(appRoot & "/") and currentPath.endsWith(routeSuffix)

proc isTailwindWatchPath*(path: string, config: CrownConfig): bool =
  if not config.tailwindCliEnabled:
    return false
  let cur = normalizeForCompare(path)
  let inp = normalizeForCompare(config.tailwindCliInput)
  cur.len > 0 and inp.len > 0 and cur == inp

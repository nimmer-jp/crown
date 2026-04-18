import std/[net, os, osproc, parseutils, strutils, tables, terminal, times]
import frontend
import generator
import project

proc parseListenPort(portStr: string): int =
  result = 5000
  let s = portStr.strip()
  if s.len == 0:
    return
  var value = 0
  let consumed = parseutils.parseInt(s, value, 0)
  if consumed == s.len and value >= 1 and value <= 65535:
    result = value

proc tcpBindPortAvailable(port: int): bool =
  var socket = newSocket()
  defer: socket.close()
  try:
    socket.setSockOpt(OptReuseAddr, true)
    socket.bindAddr(Port(port), "0.0.0.0")
    return true
  except CatchableError:
    return false

proc pickDevelopmentListenPort(requested: int): int =
  ## Uses ``requested`` when free; otherwise scans upward for a bindable TCP port.
  result = requested
  for _ in 0 ..< 256:
    if tcpBindPortAvailable(result):
      return
    inc result

proc echoDevListenInfo(requested, actual: int) =
  styledEcho fgCyan, "  requested port: ", $requested
  styledEcho fgCyan, "  actual port:    ", $actual
  styledEcho fgGreen, "  http://localhost:", $actual

proc normalizeWatchPath(path: string): string =
  path.replace('\\', '/')

proc shouldIgnorePath(path, outDir: string): bool =
  let normalizedPath = normalizeWatchPath(path)
  let normalizedOutDir = normalizeWatchPath(outDir)
  result = normalizedPath == normalizedOutDir or
      normalizedPath.startsWith(normalizedOutDir & "/") or
      normalizedPath == "public/app.js" or
      normalizedPath.endsWith("/public/app.js") or
      normalizedPath.startsWith("public/.crown/") or
      normalizedPath.contains("/public/.crown/") or
      normalizedPath.contains("/.git/") or
      normalizedPath.contains("/node_modules/") or
      normalizedPath.contains("/.DS_Store")

proc snapshotWatchedFiles(appDir, outDir: string): Table[string, Time] =
  result = initTable[string, Time]()
  let config = loadCrownConfig()

  for dir in getWatchDirs(config, appDir):
    if not dirExists(dir):
      continue
    for path in walkDirRec(dir):
      if shouldIgnorePath(path, outDir):
        continue
      try:
        result[normalizeWatchPath(path)] = getLastModificationTime(path)
      except:
        discard

  for path in getWatchFiles(config):
    if not fileExists(path) or shouldIgnorePath(path, outDir):
      continue
    try:
      result[normalizeWatchPath(path)] = getLastModificationTime(path)
    except:
      discard

proc collectWatchChanges(previous, current: Table[string, Time]): seq[string] =
  for path, mtime in current:
    if not previous.hasKey(path) or previous[path] != mtime:
      result.add(path)
  for path in previous.keys:
    if not current.hasKey(path):
      result.add(path)

proc buildAndRunServer*(appDir, outDir, mainPath: string): Process =
  styledEcho fgYellow, "\n👑 Rebuilding Crown App..."
  createDir(outDir)

  let config = loadCrownConfig()
  let twRes = runTailwindIfConfigured(config, bmDev)
  if not twRes.ok:
    styledEcho fgRed, "❌ Tailwind build failed. Continuing if previous CSS exists..."
    echo twRes.message

  # Generate PWA Files
  generatePWAFiles()

  # Regenerate routes
  let routesCode = generateRoutesCode(appDir, isDev = true)
  writeFile(outDir / "routes.nim", routesCode)

  let mainCode = generateMainCode("routes.nim")
  writeFile(mainPath, mainCode)

  let frontendResult = buildFrontendAssets(config, appDir, outDir, bmDev)
  if not frontendResult.success:
    styledEcho fgRed, "❌ Frontend build failed. Keeping dev server alive and waiting for fixes..."
    echo frontendResult.message

  let requestedPort = parseListenPort(config.port)
  let actualPort = pickDevelopmentListenPort(requestedPort)
  let port = $actualPort
  if actualPort != requestedPort:
    styledEcho fgYellow, "⚠ Port ", $requestedPort,
        " is in use; starting on ", port, " instead."
  # Ensure PORT is passed correctly to compiler & runtime
  let compRes = runNimCompile(config, bmDev, mainPath, [("PORT", port)])
  if compRes != 0:
    styledEcho fgRed, "❌ Compilation failed. Waiting for changes..."
    if config.devIncremental:
      styledEcho fgYellow,
          "Hint: Nim incremental dev builds sometimes fail with internal errors (e.g. `=copy` for `string`). Set `\"devIncremental\": false` in crown.json to disable `--incremental:on` for `crown dev`."
    return nil

  let binPath = mainPath[0 .. ^5] # remove .nim

  var runPath = binPath
  if not fileExists(binPath):
    # Depending on OS, binary might lack extension or have .exe
    let binPathAlt = if hostOS == "windows": binPath & ".exe" else: binPath
    if not fileExists(binPathAlt):
      styledEcho fgRed, "❌ Could not find compiled binary."
      return nil
    runPath = binPathAlt

  styledEcho fgGreen, "✅ Compiled successfully. Starting dev server..."
  echoDevListenInfo(requestedPort, actualPort)
  return startProcess(runPath,
    env = buildProcessEnv([("PORT", port), ("ENV", "development")]),
    options = {poParentStreams}
  )

proc startWatcher*(appDir = "src/app", outDir = ".crown") =
  let mainPath = outDir / "main.nim"
  var lastSnapshot = snapshotWatchedFiles(appDir, outDir)
  var serverProc = buildAndRunServer(appDir, outDir, mainPath)

  styledEcho fgCyan, "👑 Crown Watcher standing by. Monitoring project files for changes..."

  while true:
    sleep(500) # Poll every 500ms
    let currentSnapshot = snapshotWatchedFiles(appDir, outDir)
    let changedPaths = collectWatchChanges(lastSnapshot, currentSnapshot)
    if changedPaths.len > 0:
      styledEcho fgMagenta, "\n✨ Change detected. Rebuilding..."
      lastSnapshot = currentSnapshot

      let config = loadCrownConfig()
      var tailwindOnly = config.tailwindCliEnabled and changedPaths.len > 0
      if tailwindOnly:
        for path in changedPaths:
          if not isTailwindWatchPath(path, config):
            tailwindOnly = false
            break

      if tailwindOnly:
        let twRes = runTailwindIfConfigured(config, bmDev)
        if twRes.ok:
          styledEcho fgGreen, "✅ Tailwind CSS rebuilt."
        else:
          styledEcho fgRed, "❌ Tailwind build failed."
          echo twRes.message
        continue

      var frontendOnly = config.frontendEnabled
      if frontendOnly:
        for path in changedPaths:
          if not isFrontendWatchPath(path, config, appDir):
            frontendOnly = false
            break

      if frontendOnly:
        let frontendResult = buildFrontendAssets(config, appDir, outDir, bmDev)
        if frontendResult.success:
          styledEcho fgGreen, "✅ Frontend rebuilt."
        else:
          styledEcho fgRed, "❌ Frontend build failed. Server is still running."
          echo frontendResult.message
        continue

      if serverProc != nil:
        # Kill previous process
        terminate(serverProc)
        discard waitForExit(serverProc, 2000)
        close(serverProc)
        serverProc = nil

      serverProc = buildAndRunServer(appDir, outDir, mainPath)

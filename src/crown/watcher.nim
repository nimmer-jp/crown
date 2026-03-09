import std/[os, times, osproc, tables, terminal, strutils]
import generator
import project

proc normalizeWatchPath(path: string): string =
  path.replace('\\', '/')

proc shouldIgnorePath(path, outDir: string): bool =
  let normalizedPath = normalizeWatchPath(path)
  let normalizedOutDir = normalizeWatchPath(outDir)
  result = normalizedPath == normalizedOutDir or
      normalizedPath.startsWith(normalizedOutDir & "/") or
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

proc hasWatchChanges(previous, current: Table[string, Time]): bool =
  if previous.len != current.len:
    return true
  for path, mtime in previous:
    if not current.hasKey(path) or current[path] != mtime:
      return true
  return false

proc buildAndRunServer*(appDir, outDir, mainPath: string): Process =
  styledEcho fgYellow, "\n👑 Rebuilding Crown App..."
  createDir(outDir)

  # Generate PWA Files
  generatePWAFiles()

  # Regenerate routes
  let routesCode = generateRoutesCode(appDir)
  writeFile(outDir / "routes.nim", routesCode)

  let mainCode = generateMainCode("routes.nim")
  writeFile(mainPath, mainCode)

  let config = loadCrownConfig()
  let port = config.port
  # Ensure PORT is passed correctly to compiler & runtime
  let compRes = runNimCompile(config, bmDev, mainPath, [("PORT", port)])
  if compRes != 0:
    styledEcho fgRed, "❌ Compilation failed. Waiting for changes..."
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

  styledEcho fgGreen, "✅ Compiled successfully. Starting server on port ",
      port, "..."
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
    if hasWatchChanges(lastSnapshot, currentSnapshot):
      styledEcho fgMagenta, "\n✨ Change detected. Rebuilding..."
      lastSnapshot = currentSnapshot

      if serverProc != nil:
        # Kill previous process
        terminate(serverProc)
        discard waitForExit(serverProc, 2000)
        close(serverProc)
        serverProc = nil

      serverProc = buildAndRunServer(appDir, outDir, mainPath)

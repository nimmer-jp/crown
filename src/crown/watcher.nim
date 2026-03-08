import std/[os, times, osproc, terminal, strutils, strtabs, json]
import generator

proc getPort(): string =
  result = "5000"
  if fileExists("crown.json"):
    try:
      let j = parseFile("crown.json")
      if j.hasKey("port"):
        result = $j["port"].getInt()
    except:
      discard

proc buildAndRunServer*(appDir, outDir, mainPath: string): Process =
  styledEcho fgYellow, "\n👑 Rebuilding Crown App..."
  createDir(outDir)

  # Regenerate routes
  let routesCode = generateRoutesCode(appDir)
  writeFile(outDir / "routes.nim", routesCode)

  let mainCode = generateMainCode("routes.nim")
  writeFile(mainPath, mainCode)

  let port = getPort()
  # Ensure PORT is passed correctly to compiler & runtime
  putEnv("PORT", port)

  let compRes = execCmd("nim c --hints:off " & mainPath)
  if compRes != 0:
    styledEcho fgRed, "❌ Compilation failed. Waiting for changes..."
    return nil

  let binPath = mainPath[0 .. ^5] # remove .nim

  if not fileExists(binPath):
    # Depending on OS, binary might lack extension or have .exe
    let binPathAlt = if hostOS == "windows": binPath & ".exe" else: binPath
    if not fileExists(binPathAlt):
      styledEcho fgRed, "❌ Could not find compiled binary."
      return nil

  styledEcho fgGreen, "✅ Compiled successfully. Starting server on port ",
      port, "..."
  # startProcess runs it asynchronously
  return startProcess(binPath, env = newStringTable(["PORT", port, "ENV",
      "development"], modeCaseSensitive))

proc getLatestModTime(dir: string): Time =
  result = Time()
  for path in walkDirRec(dir):
    if path.endsWith(".nim") or path.endsWith(".html") or path.endsWith(".css"):
      let mtime = getLastModificationTime(path)
      if mtime > result:
        result = mtime

proc startWatcher*(appDir = "src/app", outDir = ".crown") =
  let mainPath = outDir / "main.nim"
  var lastMod = getLatestModTime(appDir)
  var serverProc = buildAndRunServer(appDir, outDir, mainPath)

  styledEcho fgCyan, "👑 Crown Watcher standing by. Monitoring '", appDir, "' for changes..."

  while true:
    sleep(500) # Poll every 500ms
    let currentMod = getLatestModTime(appDir)
    if currentMod > lastMod:
      styledEcho fgMagenta, "\n✨ Change detected in ", appDir
      lastMod = currentMod

      if serverProc != nil:
        # Kill previous process
        terminate(serverProc)
        discard waitForExit(serverProc, 2000)
        close(serverProc)
        serverProc = nil

      serverProc = buildAndRunServer(appDir, outDir, mainPath)

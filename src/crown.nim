import cligen
import std/[os, strutils, terminal]
import crown/generator
import crown/project
import crown/watcher

const
  initPagePlain = "import crown/core\n\nproc page*(context: Context, params: Params): Future[Response] {.async.} =\n  return htmlResponse(html\"\"\"\n    <div class=\"p-10 text-center\">\n      <h1 class=\"text-4xl font-bold text-gray-800\">Welcome to Crown 👑</h1>\n      <p class=\"mt-4 text-gray-600\">Your App Router-like framework for Nim.</p>\n      <p class=\"mt-2 text-sm text-gray-400\">Edit <code>src/app/page.nim</code> to get started.</p>\n    </div>\n  \"\"\")\n"

  initPageTiara =
    "import crown/core\n" &
    "import tiara\n" &
    "\n" &
    "proc page*(req: Request): string =\n" &
    "  return html\"\"\"\n" &
    "    <div class=\"p-10 text-center space-y-4 max-w-2xl mx-auto\">\n" &
    "      <h1 class=\"text-4xl font-bold text-gray-800\">Welcome to Crown 👑</h1>\n" &
    "      <p class=\"text-gray-600\">\n" &
    "        Crown の App Router と <span class=\"font-semibold text-indigo-600\">Tiara</span> の <code class=\"text-sm bg-slate-100 px-1 rounded\">html</code> DSL で組み立てたデフォルトページです。\n" &
    "      </p>\n" &
    "      <p class=\"text-sm text-gray-400\">編集: <code>src/app/page.nim</code> · 起動: <code>crown dev</code></p>\n" &
    "    </div>\n" &
    "  \"\"\"\n"
  crownJsonDefault = "{\n  \"port\": 5000,\n  \"tailwind\": true,\n  \"pwa\": false\n}\n"

proc ensureDir(path: string) =
  if dirExists(path):
    return
  let p = parentDir(path)
  if p.len > 0 and not dirExists(p):
    ensureDir(p)
  createDir(path)

proc scaffoldCrownProject(root: string, useTiaraPage: bool) =
  ## Create directories, optional starter page, crown.json, and crown.nimble under ``root``.
  let appDir = root / "src" / "app"
  ensureDir(appDir)
  ensureDir(root / "public")

  let pagePath = appDir / "page.nim"
  if not fileExists(pagePath):
    writeFile(pagePath, if useTiaraPage: initPageTiara else: initPagePlain)

  let cfgPath = root / "crown.json"
  if not fileExists(cfgPath):
    writeFile(cfgPath, crownJsonDefault)

  let nimblePath = root / "crown.nimble"
  if not fileExists(nimblePath):
    let nimbleContent = """
version       = "0.1.0"
author        = "Crown User"
description   = "A new Crown application"
license       = "MIT"
srcDir        = "src"

requires "nim >= 2.2.10"
requires "https://github.com/itsumura-h/nim-basolato#v0.15.0"
requires "https://github.com/nimmer-jp/tiara >= 0.1.0"
"""
    writeFile(nimblePath, nimbleContent)

proc init*() =
  ## Initialize a new Crown project in the current directory
  styledEcho fgCyan, "👑 Initializing new Crown project..."
  scaffoldCrownProject(getCurrentDir(), useTiaraPage = false)
  styledEcho fgGreen, "✅ Project initialized! Run `crown dev` to start the development server."

proc createApp*(paths: seq[string] = @[]) =
  ## Create a new Crown + Tiara app (starter page uses Tiara). Pass an optional project directory as the first argument (any extra arguments are ignored).
  var name = ""
  if paths.len > 0:
    name = paths[0].strip()
  if paths.len > 1:
    styledEcho fgYellow, "⚠️ Extra arguments were ignored: ", paths[1 .. ^1].join(" ")
  var root = getCurrentDir()
  if name.len > 0:
    root = root / name
    if fileExists(root):
      styledEcho fgRed, "❌ Path exists and is not a directory: ", root
      quit(1)
    ensureDir(root)

  styledEcho fgCyan, "👑 Creating Crown + Tiara application..."
  scaffoldCrownProject(root, useTiaraPage = true)
  styledEcho fgGreen, "✅ App scaffold ready at: ", root
  styledEcho fgYellow,
    "Next: cd into the project if needed, run `nimble install`, then `crown dev`."

proc build*(appDir = "src/app", outDir = ".crown") =
  ## Build the Crown application for production
  echo "👑 Building Crown application..."
  if not dirExists(appDir):
    echo "[Error] App directory not found: ", appDir
    quit(1)

  createDir(outDir)
  writeCrownEnvPreserver(outDir)
  generatePWAFiles()
  let routesCode = generateRoutesCode(appDir)
  let routesPath = outDir / "routes.nim"
  writeFile(routesPath, routesCode)

  let mainCode = generateMainCode("routes.nim")
  let mainPath = outDir / "main.nim"
  writeFile(mainPath, mainCode)

  let config = loadCrownConfig()
  let port = config.port
  # Basolato resolves PORT during compilation, so pass it via the compiler environment.
  let ret = runNimCompile(config, bmBuild, mainPath, [("PORT", port)])
  if ret == 0:
    styledEcho fgGreen, "✅ Build succeeded! You can run the app with ./.crown/main"
  else:
    styledEcho fgRed, "❌ Build failed. Please check the Nim compiler output above."
    quit(ret)

proc dev*(appDir = "src/app", outDir = ".crown") =
  ## Start the Crown development server
  styledEcho fgYellow, "👑 Starting Crown dev server..."
  if not dirExists(appDir):
    echo "[Error] App directory not found: ", appDir
    quit(1)

  # A real implementation would use something like `fsmonitor` or `nimble dev` loop to restart on changes.
  # We will use our custom watcher.
  startWatcher(appDir, outDir)

proc start*(outDir = ".crown") =
  ## Start the built Crown application for production
  styledEcho fgYellow, "👑 Starting Crown production server..."
  let binPath = outDir / "main"
  
  var runPath = binPath
  if not fileExists(binPath):
    let binPathAlt = if hostOS == "windows": binPath & ".exe" else: binPath
    if not fileExists(binPathAlt):
      styledEcho fgRed, "❌ Could not find compiled binary. Please run `crown build` first."
      quit(1)
    runPath = binPathAlt
    
  let config = loadCrownConfig()
  let port = config.port
  putEnv("PORT", $port)
  putEnv("ENV", "production")

  let err = execShellCmd(runPath)
  quit(err)

when isMainModule:
  dispatchMulti([build], [dev], [start], [init], [createApp, positional = "paths"])

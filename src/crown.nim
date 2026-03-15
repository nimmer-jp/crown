import cligen
import std/[os, strutils, terminal]
import crown/generator
import crown/project
import crown/watcher

proc init*() =
  ## Initialize a new Crown project in the current directory
  styledEcho fgCyan, "👑 Initializing new Crown project..."

  createDir("src/app")
  createDir("public")

  let initPageContent = "import crown/core\n\nproc page*(context: Context, params: Params): Future[Response] {.async.} =\n  return htmlResponse(html\"\"\"\n    <div class=\"p-10 text-center\">\n      <h1 class=\"text-4xl font-bold text-gray-800\">Welcome to Crown 👑</h1>\n      <p class=\"mt-4 text-gray-600\">Your App Router-like framework for Nim.</p>\n      <p class=\"mt-2 text-sm text-gray-400\">Edit <code>src/app/page.nim</code> to get started.</p>\n    </div>\n  \"\"\")\n"
  if not fileExists("src/app/page.nim"):
    writeFile("src/app/page.nim", initPageContent)

  if not fileExists("crown.json"):
    writeFile("crown.json", "{\n  \"port\": 5000,\n  \"tailwind\": true,\n  \"pwa\": false\n}\n")

  if not fileExists("crown.nimble"):
    let nimbleContent =
      """
      version       = "0.1.0"
      author        = "Crown User"
      description   = "A new Crown application"
      license       = "MIT"
      srcDir        = "src"

      requires "nim >= 2.2.0"
      requires "https://github.com/itsumura-h/nim-basolato >= 0.15.0"
      requires "https://github.com/nimmer-jp/tiara >= 0.1.0"
      """
    writeFile("crown.nimble", nimbleContent)

  styledEcho fgGreen, "✅ Project initialized! Run `crown dev` to start the development server."

proc build*(appDir = "src/app", outDir = ".crown") =
  ## Build the Crown application for production
  echo "👑 Building Crown application..."
  if not dirExists(appDir):
    echo "[Error] App directory not found: ", appDir
    quit(1)

  createDir(outDir)
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
  dispatchMulti([build], [dev], [start], [init])

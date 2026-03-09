import cligen
import std/[os, strutils, osproc, terminal, json]
import crown/generator
import crown/watcher

proc getPort(): string =
  result = "5000"
  if fileExists("crown.json"):
    try:
      let j = parseFile("crown.json")
      if j.hasKey("port"):
        result = $j["port"].getInt()
    except:
      discard

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

  let port = getPort()
  # basolato requires .env, make sure it matches crown.json
  writeFile(".env", "PORT=" & port & "\nENV=production\n")

  let cmd = "env PORT=" & port & " nim c -d:release " & mainPath
  let ret = execCmd(cmd)
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

when isMainModule:
  dispatchMulti([build], [dev], [init])

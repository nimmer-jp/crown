import std/[os, strutils, strformat, sets]

type
  RouteEntry = object
    filePath: string
    urlPath: string
    methods: seq[string]
    importName: string

proc detectMethods*(content: string): seq[string] =
  var methods: seq[string]
  for line in content.splitLines():
    let l = line.strip()
    if l.startsWith("proc "):
      let parts = l.split({' ', '(', '*', ':', '\t'})
      if parts.len > 1:
        let name = parts[1]
        if name == "get": methods.add("get")
        elif name == "post": methods.add("post")
        elif name == "put": methods.add("put")
        elif name == "delete": methods.add("delete")
        elif name == "patch": methods.add("patch")
        elif name == "page": methods.add("page")
  return methods

proc resolveUrlPath*(appDir, filePath: string): string =
  let relPath = filePath.relativePath(appDir)
  var urlPath = "/" & relPath.replace(".nim", "").replace("\\", "/") # Windows support
  if urlPath.endsWith("/page"):
    urlPath = urlPath[0 .. ^6]

  # Handle p_id -> {id:str} for dynamic routing
  var finalParts: seq[string]
  for part in urlPath.split('/'):
    if part.startsWith("p_"):
      finalParts.add("{" & part[2..^1] & ":str}")
    else:
      finalParts.add(part)
  urlPath = finalParts.join("/")

  if urlPath == "":
    urlPath = "/"
  if urlPath != "/" and urlPath.endsWith("/"):
    urlPath = urlPath[0 .. ^2]
  return urlPath

proc getLayoutChain(appDir, pagePath: string): seq[string] =
  var chain: seq[string]
  var currentDir = pagePath.parentDir()
  while currentDir.len >= appDir.len and currentDir.startsWith(appDir):
    let layoutPath = currentDir / "layout.nim"
    if fileExists(layoutPath):
      chain.add(layoutPath)
    if currentDir == appDir:
      break
    currentDir = currentDir.parentDir()

  # Reverse so outermost layout comes first
  var chainResult: seq[string]
  for i in countdown(chain.high, 0):
    chainResult.add(chain[i])
  return chainResult

proc generateRoutesCode*(appDir: string): string =
  var entries: seq[RouteEntry]
  var notFoundEntry: RouteEntry
  var hasNotFound = false

  for path in walkDirRec(appDir):
    if path.endsWith(".nim") and not path.endsWith("layout.nim"):
      let content = readFile(path)
      let methods = detectMethods(content)
      if methods.len > 0:
        let relPath = path.relativePath("src/")
        let importName = relPath.replace("/", "_").replace(".nim", "").replace(
            "-", "_")

        let entry = RouteEntry(
          filePath: relPath.replace(".nim", ""),
          urlPath: resolveUrlPath(appDir, path),
          methods: methods,
          importName: importName
        )

        if path.endsWith("not_found.nim"):
          notFoundEntry = entry
          hasNotFound = true
        else:
          entries.add(entry)

  var code = "import basolato except html\nimport crown/core\nimport std/asyncdispatch\n"
  var uniqueImports = initHashSet[string]()

  # Import all pages into .crown/ (relative depth +1, thus ../src/)
  for e in entries:
    let importStmt = &"import ../src/{e.filePath} as {e.importName}\n"
    if not uniqueImports.contains(importStmt):
      code &= importStmt
      uniqueImports.incl(importStmt)

  # Find all unique layouts to import
  var layoutImports = initHashSet[string]()
  for path in walkDirRec(appDir):
    if path.endsWith("layout.nim"):
      let relPath = path.relativePath("src/")
      let layoutName = relPath.replace("/", "_").replace(".nim", "").replace(
          "-", "_")
      let stmt = &"import ../src/{relPath.replace(\".nim\", \"\")} as {layoutName}\n"
      if not layoutImports.contains(stmt):
        code &= stmt
        layoutImports.incl(stmt)

  if hasNotFound:
    let stmt = &"import ../src/{notFoundEntry.filePath} as {notFoundEntry.importName}\n"
    if not layoutImports.contains(stmt):
      code &= stmt

  code &= "\nlet routes* = @[\n"
  for e in entries:
    let fullPagePath = "src" / e.filePath & ".nim"
    let layouts = getLayoutChain("src" / "app", fullPagePath)

    for m in e.methods:
      let httpMethod = if m == "page": "get" else: m

      # Generate a wrapper proc inline that intelligently tries to call the page handlers
      code &= &"  Route.{httpMethod}(\"{e.urlPath}\", proc(c: Context, p: Params): Future[Response] {{.async.}} =\n"
      code &= &"    var res: Response\n"
      code &= &"    let req = Request(context: c, params: p)\n"
      code &= &"    when compiles({e.importName}.{m}(req)):\n"
      code &= &"      when type({e.importName}.{m}(req)) is string:\n"
      code &= &"        res = htmlResponse({e.importName}.{m}(req))\n"
      code &= &"      elif type({e.importName}.{m}(req)) is Response:\n"
      code &= &"        res = {e.importName}.{m}(req)\n"
      code &= &"      else:\n"
      code &= &"        res = await {e.importName}.{m}(req)\n"
      code &= &"    else:\n"
      code &= &"      # Fallback to pure Basolato signature for backwards compatibility\n"
      code &= &"      when type({e.importName}.{m}(c, p)) is Response:\n"
      code &= &"        res = {e.importName}.{m}(c, p)\n"
      code &= &"      else:\n"
      code &= &"        res = await {e.importName}.{m}(c, p)\n"
      code &= &"    \n"
      code &= &"    var contentType = \"\"\n"
      code &= &"    if res.headers.hasKey(\"Content-Type\"): contentType = $res.headers[\"Content-Type\"]\n"
      code &= &"    elif res.headers.hasKey(\"content-type\"): contentType = $res.headers[\"content-type\"]\n"
      code &= &"    if contentType.contains(\"text/html\"):\n"
      code &= &"      var htmlContent = res.body()\n"

      # Apply layouts from innermost to outermost
      for i in countdown(layouts.high, 0):
        let lPath = layouts[i]
        let lName = lPath.relativePath("src/").replace("/", "_").replace(".nim",
            "").replace("-", "_")
        code &= &"      when type({lName}.layout(htmlContent)) is string:\n"
        code &= &"        htmlContent = {lName}.layout(htmlContent)\n"
        code &= &"      else:\n"
        code &= &"        htmlContent = {lName}.layout(htmlContent).body()\n"

      code &= &"      htmlContent = injectCrownSystem(htmlContent)\n"
      code &= &"      res = htmlResponse(htmlContent, res.status)\n"
      code &= &"    return res\n"
      code &= &"  ),\n"

  if hasNotFound:
    let fullPagePath = "src" / notFoundEntry.filePath & ".nim"
    let layouts = getLayoutChain("src" / "app", fullPagePath)
    # Add a catch-all route at the end for 404
    code &= &"  Route.get(\"/{{path:str}}\", proc(c: Context, p: Params): Future[Response] {{.async.}} =\n"
    code &= &"    var res: Response\n"
    code &= &"    let req = Request(context: c, params: p)\n"
    code &= &"    when compiles({notFoundEntry.importName}.page(req)):\n"
    code &= &"      when type({notFoundEntry.importName}.page(req)) is string:\n"
    code &= &"        res = htmlResponse({notFoundEntry.importName}.page(req))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(req)) is Response:\n"
    code &= &"        res = {notFoundEntry.importName}.page(req)\n"
    code &= &"      else:\n"
    code &= &"        res = await {notFoundEntry.importName}.page(req)\n"
    code &= &"    else:\n"
    code &= &"      when type({notFoundEntry.importName}.page(c, p)) is Response:\n"
    code &= &"        res = {notFoundEntry.importName}.page(c, p)\n"
    code &= &"      else:\n"
    code &= &"        res = await {notFoundEntry.importName}.page(c, p)\n"
    code &= &"    res.status = Http404\n" # Force 404 status
    code &= &"    var contentType = \"\"\n"
    code &= &"    if res.headers.hasKey(\"Content-Type\"): contentType = $res.headers[\"Content-Type\"]\n"
    code &= &"    elif res.headers.hasKey(\"content-type\"): contentType = $res.headers[\"content-type\"]\n"
    code &= &"    if contentType.contains(\"text/html\"):\n"
    code &= &"      var htmlContent = res.body()\n"
    for i in countdown(layouts.high, 0):
      let lPath = layouts[i]
      let lName = lPath.relativePath("src/").replace("/", "_").replace(".nim",
          "").replace("-", "_")
      code &= &"      when type({lName}.layout(htmlContent)) is string:\n"
      code &= &"        htmlContent = {lName}.layout(htmlContent)\n"
      code &= &"      else:\n"
      code &= &"        htmlContent = {lName}.layout(htmlContent).body()\n"
    code &= &"      htmlContent = injectCrownSystem(htmlContent)\n"
    code &= &"      res = htmlResponse(htmlContent, res.status)\n"
    code &= &"    return res\n"
    code &= &"  ),\n"

  code &= "]\n"



  return code

proc generateMainCode*(routesPath: string): string =
  let moduleName = routesPath.replace(".nim", "")
  return "import basolato except html\n" &
         "import " & moduleName & "\n\n" &
         "serve(" & moduleName & ".routes)\n"

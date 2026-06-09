import std/[os, strutils, strformat, sets, json]

type
  RouteParam* = object
    name*: string
    typ*: string
    catchAll*: bool

  LayoutEntry = object
    filePath: string
    importName: string
    isCentral: bool
    centralName: string

  RouteEntry = object
    filePath: string
    urlPath: string
    methods: seq[tuple[name: string, layout: string]]
    importName: string
    params: seq[RouteParam]
    routeGroups: seq[string]
    defaultLayoutAliases: seq[string]
    hasLoader: bool
    hasLoading: bool
    hasError: bool

proc normalizeModulePath*(path: string): string =
  ## Convert filesystem separators to Nim module separators.
  path.replace("\\", "/").replace(".nim", "")

proc makeImportAlias*(modulePath: string): string =
  ## Convert any path-ish value into a safe Nim import alias.
  for ch in modulePath:
    if ch.isAlphaNumeric or ch == '_':
      result.add(ch)
    else:
      result.add('_')
  while "__" in result:
    result = result.replace("__", "_")
  result = result.strip(chars = {'_'})
  if result.len == 0:
    result = "module"
  if result[0].isDigit:
    result = "m_" & result

proc writeFileIfChanged(path, content: string) =
  if fileExists(path) and readFile(path) == content:
    return
  writeFile(path, content)

proc normalizedPath(path: string): string =
  result = path
  normalizePath(result)

proc sourceRoot(appDir: string): string =
  let parent = appDir.parentDir()
  if parent.len == 0:
    return "."
  parent

proc detectMethods*(content: string): seq[tuple[name: string, layout: string]] =
  var methods: seq[tuple[name: string, layout: string]]
  for line in content.splitLines():
    let l = line.strip()
    if l.startsWith("proc "):
      let parts = l.split({' ', '(', '*', ':', '\t'})
      if parts.len > 1:
        let name = parts[1]
        if name in ["get", "post", "put", "delete", "patch", "page"]:
          var layoutName = ""
          let layoutIdx = l.find("layout")
          if layoutIdx != -1:
            let eqIdx = l.find("=", layoutIdx)
            if eqIdx != -1:
              let quote1Idx = l.find("\"", eqIdx)
              if quote1Idx != -1:
                let quote2Idx = l.find("\"", quote1Idx + 1)
                if quote2Idx != -1:
                  layoutName = l[quote1Idx + 1 .. quote2Idx - 1]
          methods.add((name, layoutName))
  return methods

proc hasExportedProc*(content, name: string): bool =
  for line in content.splitLines():
    let l = line.strip()
    if l.startsWith("proc " & name & "*(") or
        l.startsWith("proc " & name & " *("):
      return true

proc isRouteGroupSegment(part: string): bool =
  part.len >= 2 and part[0] == '(' and part[^1] == ')'

proc parseDynamicSegment(part: string): tuple[pathPart: string, param: RouteParam] =
  ## Supports Crown legacy ``p_id`` and Next-style ``[id]`` / ``[id:int]``.
  ## Basolato currently matches one segment per dynamic token; catch-all is
  ## recorded in the manifest for future adapters but emitted as a segment token.
  var param = RouteParam(name: "", typ: "str", catchAll: false)
  if part.startsWith("p_") and part.len > 2:
    param.name = part[2 .. ^1]
    return ("{" & param.name & ":str}", param)

  if part.len >= 3 and part[0] == '[' and part[^1] == ']':
    var inside = part[1 .. ^2]
    if inside.startsWith("..."):
      param.catchAll = true
      inside = inside[3 .. ^1]
    let pieces = inside.split(":", 1)
    param.name = pieces[0].strip()
    if pieces.len > 1 and pieces[1].strip().len > 0:
      param.typ = pieces[1].strip()
    if param.name.len > 0:
      return ("{" & param.name & ":" & param.typ & "}", param)

  return (part, param)

proc resolveRoutePath*(appDir, filePath: string): tuple[urlPath: string,
    params: seq[RouteParam], routeGroups: seq[string]] =
  let relPath = filePath.relativePath(appDir)
  var routePath = relPath.replace(".nim", "").replace("\\", "/")
  if routePath.endsWith("/page"):
    routePath = routePath[0 .. ^6]
  elif routePath == "page":
    routePath = ""

  var finalParts: seq[string]
  var params: seq[RouteParam]
  var routeGroups: seq[string]
  for part in routePath.split('/'):
    if part.len == 0:
      continue
    if isRouteGroupSegment(part):
      routeGroups.add(part)
      continue
    let parsed = parseDynamicSegment(part)
    finalParts.add(parsed.pathPart)
    if parsed.param.name.len > 0:
      params.add(parsed.param)

  var urlPath = "/" & finalParts.join("/")
  if urlPath == "/":
    discard
  elif urlPath.endsWith("/"):
    urlPath = urlPath[0 .. ^2]

  return (urlPath, params, routeGroups)

proc resolveUrlPath*(appDir, filePath: string): string =
  resolveRoutePath(appDir, filePath).urlPath

proc routeFileReserved(path: string): bool =
  let name = path.extractFilename()
  name in ["layout.nim", "loading.nim", "error.nim"]

proc layoutAliasForPath(appDir, path: string): LayoutEntry =
  let relPath = normalizeModulePath(path.relativePath(sourceRoot(appDir)))
  let centralLayoutDir = normalizedPath(appDir / "layout")
  let parent = normalizedPath(path.parentDir())
  let isCentral = parent == centralLayoutDir
  let stem = path.extractFilename().replace(".nim", "")
  let alias =
    if isCentral:
      "crown_layout_" & makeImportAlias(stem)
    else:
      "crown_route_layout_" & makeImportAlias(relPath)
  LayoutEntry(
    filePath: relPath,
    importName: alias,
    isCentral: isCentral,
    centralName: if isCentral: stem else: ""
  )

proc discoverLayouts(appDir: string): seq[LayoutEntry] =
  for path in walkDirRec(appDir):
    if path.extractFilename() == "layout.nim" or
        (normalizedPath(path.parentDir()) == normalizedPath(appDir / "layout") and
        path.endsWith(".nim")):
      result.add(layoutAliasForPath(appDir, path))

proc findLayoutAlias(layouts: openArray[LayoutEntry], relFilePath: string): string =
  for layout in layouts:
    if layout.filePath == relFilePath:
      return layout.importName

proc findCentralLayoutAlias(layouts: openArray[LayoutEntry], name: string): string =
  for layout in layouts:
    if layout.isCentral and layout.centralName == name:
      return layout.importName

proc findLayoutFile(layouts: openArray[LayoutEntry], alias: string): string =
  for layout in layouts:
    if layout.importName == alias:
      return "src/" & layout.filePath & ".nim"
  return alias

proc inheritedLayoutAliases(appDir, filePath: string,
    layouts: openArray[LayoutEntry]): seq[string] =
  ## Apply nearest route-local layout first, then outer layouts, then the
  ## legacy central default layout (`src/app/layout/layout.nim`) last.
  var current = filePath.parentDir()
  let root = normalizedPath(appDir)
  while normalizedPath(current).startsWith(root) and normalizedPath(current) != root:
    let layoutPath = current / "layout.nim"
    if fileExists(layoutPath):
      let rel = normalizeModulePath(layoutPath.relativePath(sourceRoot(appDir)))
      let alias = findLayoutAlias(layouts, rel)
      if alias.len > 0:
        result.add(alias)
    let next = current.parentDir()
    if next == current:
      break
    current = next

  let central = findCentralLayoutAlias(layouts, "layout")
  if central.len > 0:
    result.add(central)

proc generateCrownEnvPreserverModuleSource*(): string =
  ## Materialized as ``.crown/crown_env_preserver.nim``. Load project-root ``.env`` files,
  ## then snapshot ``PORT`` for Basolato incremental dev quirks. Import this module
  ## strictly before ``import basolato``.
  result = "## Generated by Crown; do not edit.\n" &
      "import crown/dotenv\n" &
      "import std/[os, strutils]\n\n" &
      "primeCrownEnvironmentBeforeBasolato()\n\n" &
      "let crownPortBeforeBasolatoEnv*: string = strip(getEnv(\"PORT\", \"\"))\n"

proc writeCrownEnvPreserver*(outDir: string) {.inline.} =
  writeFile(outDir / "crown_env_preserver.nim",
      generateCrownEnvPreserverModuleSource())

proc collectRouteEntries(appDir: string,
    layouts: openArray[LayoutEntry]): tuple[entries: seq[RouteEntry],
    notFoundEntry: RouteEntry, hasNotFound: bool] =
  for path in walkDirRec(appDir):
    if not path.endsWith(".nim") or routeFileReserved(path):
      continue
    let content = readFile(path)
    let methods = detectMethods(content)
    if methods.len == 0:
      continue

    let relPath = normalizeModulePath(path.relativePath(sourceRoot(appDir)))
    let routePath = resolveRoutePath(appDir, path)
    let entry = RouteEntry(
      filePath: relPath,
      urlPath: routePath.urlPath,
      methods: methods,
      importName: makeImportAlias(relPath),
      params: routePath.params,
      routeGroups: routePath.routeGroups,
      defaultLayoutAliases: inheritedLayoutAliases(appDir, path, layouts),
      hasLoader: hasExportedProc(content, "loader"),
      hasLoading: fileExists(path.parentDir() / "loading.nim"),
      hasError: fileExists(path.parentDir() / "error.nim")
    )

    if path.endsWith("not_found.nim"):
      result.notFoundEntry = entry
      result.hasNotFound = true
    else:
      result.entries.add(entry)

proc routeManifestJson*(appDir: string): JsonNode =
  let layouts = discoverLayouts(appDir)
  let collected = collectRouteEntries(appDir, layouts)
  result = %*{
    "version": "0.6",
    "appDir": appDir,
    "routes": []
  }
  for e in collected.entries:
    var methods = newJArray()
    for m in e.methods:
      methods.add(%(if m.name == "page": "GET" else: m.name.toUpperAscii()))
    var params = newJArray()
    for p in e.params:
      params.add(%*{
        "name": p.name,
        "type": p.typ,
        "catchAll": p.catchAll
      })
    var groups = newJArray()
    for g in e.routeGroups:
      groups.add(%g)
    var layoutsJson = newJArray()
    for alias in e.defaultLayoutAliases:
      layoutsJson.add(%findLayoutFile(layouts, alias))
    result["routes"].add(%*{
      "path": e.urlPath,
      "file": "src/" & e.filePath & ".nim",
      "methods": methods,
      "params": params,
      "routeGroups": groups,
      "layouts": layoutsJson,
      "dynamic": e.params.len > 0,
      "hasLoader": e.hasLoader,
      "hasLoading": e.hasLoading,
      "hasError": e.hasError
    })

proc generateRouteManifest*(appDir: string): string =
  routeManifestJson(appDir).pretty()

proc writeRouteManifest*(outDir, appDir: string) =
  writeFileIfChanged(outDir / "manifest.json", generateRouteManifest(appDir))

proc nimStringLiteral(s: string): string =
  $(%s)

proc generateRoutesCode*(appDir: string, isDev: bool = false): string =
  let layouts = discoverLayouts(appDir)
  let collected = collectRouteEntries(appDir, layouts)
  let entries = collected.entries
  let notFoundEntry = collected.notFoundEntry
  let hasNotFound = collected.hasNotFound

  var code = "import std/json\nimport crown/core as crown\nimport basolato except html\nimport std/asyncdispatch\n"
  if isDev:
    code = "import std/os\n" & code
  var uniqueImports = initHashSet[string]()

  for layout in layouts:
    let stmt = &"import \"../src/{layout.filePath}.nim\" as {layout.importName}\n"
    if not uniqueImports.contains(stmt):
      code &= stmt
      uniqueImports.incl(stmt)

  # Import all pages into .crown/ (relative depth +1, thus ../src/)
  for e in entries:
    let importStmt = &"import \"../src/{e.filePath}.nim\" as {e.importName}\n"
    if not uniqueImports.contains(importStmt):
      code &= importStmt
      uniqueImports.incl(importStmt)

  if hasNotFound:
    code &= &"import \"../src/{notFoundEntry.filePath}.nim\" as {notFoundEntry.importName}\n"

  code &= "\n"
  code &= "template crownSetRouteResponse(res: var crown.Response, value: untyped): untyped =\n"
  code &= "  when type(value) is string:\n"
  code &= "    res = htmlResponse(value)\n"
  code &= "  elif type(value) is Html:\n"
  code &= "    res = htmlResponse(crown.crownTiaraHtmlToString(value))\n"
  code &= "  elif type(value) is Future[string]:\n"
  code &= "    res = htmlResponse(await value)\n"
  code &= "  elif type(value) is Future[Html]:\n"
  code &= "    res = htmlResponse(crown.crownTiaraHtmlToString(await value))\n"
  code &= "  elif type(value) is crown.Response:\n"
  code &= "    res = value\n"
  code &= "  elif type(value) is Future[crown.Response]:\n"
  code &= "    res = await value\n"
  code &= "  else:\n"
  code &= "    res = await value\n"
  code &= "\n"

  ## Each route is a separate `let`: colon-syntax `crownRouteRegister` cannot sit inside
  ## `@[ ... ]`. Basolato 0.16+: `let routes* = Routes.merge(@[crownRoute0, ...])`; 0.15: `seq[Routes]`.
  var routeNames: seq[string] = @[]
  var crownIdx = 0

  for e in entries:
    for methodTuple in e.methods:
      let m = methodTuple.name
      let explicitLayout = methodTuple.layout
      let httpMethod = if m == "page": "get" else: m
      let explicitArg = if explicitLayout != "": "\"" & explicitLayout &
          "\"" else: "\"\""

      let rn = "crownRoute" & $crownIdx
      inc crownIdx
      routeNames.add(rn)

      # Generate a wrapper proc inline that intelligently tries to call Crown,
      # loader-backed Crown, or pure Basolato handlers.
      code &= &"let {rn} = crownRouteRegister(\"{httpMethod}\", \"{e.urlPath}\"):\n"
      code &= &"    var res: crown.Response\n"
      code &= &"    let req = crown.Request(context: c, params: p)\n"
      if m == "page":
        code &= &"    when compiles({e.importName}.loader(req)):\n"
        code &= &"      when compiles(await {e.importName}.loader(req)):\n"
        code &= &"        let crownLoaderData = await {e.importName}.loader(req)\n"
        code &= &"      else:\n"
        code &= &"        let crownLoaderData = {e.importName}.loader(req)\n"
        code &= &"      when compiles({e.importName}.{m}(req, crownLoaderData, {explicitArg})):\n"
        code &= &"        crownSetRouteResponse(res, {e.importName}.{m}(req, crownLoaderData, {explicitArg}))\n"
        code &= &"      elif compiles({e.importName}.{m}(req, crownLoaderData)):\n"
        code &= &"        crownSetRouteResponse(res, {e.importName}.{m}(req, crownLoaderData))\n"
        code &= &"      elif compiles({e.importName}.{m}(req, {explicitArg})):\n"
        code &= &"        crownSetRouteResponse(res, {e.importName}.{m}(req, {explicitArg}))\n"
        code &= &"      else:\n"
        code &= &"        crownSetRouteResponse(res, {e.importName}.{m}(req))\n"
        code &= &"    elif compiles({e.importName}.{m}(req, {explicitArg})):\n"
      else:
        code &= &"    when compiles({e.importName}.{m}(req, {explicitArg})):\n"
      code &= &"      crownSetRouteResponse(res, {e.importName}.{m}(req, {explicitArg}))\n"
      code &= &"    elif compiles({e.importName}.{m}(req)):\n"
      code &= &"      crownSetRouteResponse(res, {e.importName}.{m}(req))\n"
      code &= &"    else:\n"
      code &= &"      # Fallback to pure Basolato signature for backwards compatibility\n"
      code &= &"      crownSetRouteResponse(res, {e.importName}.{m}(c, p))\n"
      code &= &"    \n"
      code &= &"    var contentType = \"\"\n"
      code &= &"    if res.headers.hasKey(\"Content-Type\"): contentType = $res.headers[\"Content-Type\"]\n"
      code &= &"    elif res.headers.hasKey(\"content-type\"): contentType = $res.headers[\"content-type\"]\n"
      let isPage = if m == "page": "true" else: "false"
      code &= &"    let isLayoutEnabled = {isPage} and not res.headers.hasKey(\"Crown-Disable-Layout\")\n"
      code &= &"    let isCrownInjectEnabled = {isPage} and not res.headers.hasKey(\"Crown-Disable-Inject\")\n"
      code &= &"    if contentType.contains(\"text/html\") and (isLayoutEnabled or isCrownInjectEnabled):\n"
      code &= &"      var htmlContent = res.body()\n"
      code &= &"      if isLayoutEnabled:\n"
      if explicitLayout != "":
        var layoutNameSpace = findCentralLayoutAlias(layouts, explicitLayout)
        if layoutNameSpace.len == 0:
          layoutNameSpace = "crown_layout_" & makeImportAlias(explicitLayout)
        code &= &"        when compiles({layoutNameSpace}.layout(htmlContent)):\n"
        code &= &"          htmlContent = {layoutNameSpace}.layout(htmlContent)\n"
      else:
        for layoutAlias in e.defaultLayoutAliases:
          code &= &"        when compiles({layoutAlias}.layout(htmlContent)):\n"
          code &= &"          htmlContent = {layoutAlias}.layout(htmlContent)\n"
      code &= &"      if isCrownInjectEnabled:\n"
      code &= &"        htmlContent = injectCrownSystem(htmlContent)\n"
      code &= &"      res = htmlResponse(htmlContent, res.status)\n"
      code &= &"    return res\n"
      code &= "\n"

  if hasNotFound:
    let rnNf = "crownRoute" & $crownIdx
    inc crownIdx
    routeNames.add(rnNf)
    code &= &"let {rnNf} = crownRouteRegister(\"get\", \"/{{path:str}}\"):\n"
    code &= &"    var res: crown.Response\n"
    code &= &"    let req = crown.Request(context: c, params: p)\n"
    code &= &"    when compiles({notFoundEntry.importName}.page(req, \"\")):\n"
    code &= &"      when type({notFoundEntry.importName}.page(req, \"\")) is string:\n"
    code &= &"        res = htmlResponse({notFoundEntry.importName}.page(req, \"\"))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(req, \"\")) is Html:\n"
    code &= &"        res = htmlResponse(crown.crownTiaraHtmlToString({notFoundEntry.importName}.page(req, \"\")))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(req, \"\")) is Future[Html]:\n"
    code &= &"        res = htmlResponse(crown.crownTiaraHtmlToString(await {notFoundEntry.importName}.page(req, \"\")))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(req, \"\")) is crown.Response:\n"
    code &= &"        res = {notFoundEntry.importName}.page(req, \"\")\n"
    code &= &"      else:\n"
    code &= &"        res = await {notFoundEntry.importName}.page(req, \"\")\n"
    code &= &"    elif compiles({notFoundEntry.importName}.page(req)):\n"
    code &= &"      when type({notFoundEntry.importName}.page(req)) is string:\n"
    code &= &"        res = htmlResponse({notFoundEntry.importName}.page(req))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(req)) is Html:\n"
    code &= &"        res = htmlResponse(crown.crownTiaraHtmlToString({notFoundEntry.importName}.page(req)))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(req)) is Future[Html]:\n"
    code &= &"        res = htmlResponse(crown.crownTiaraHtmlToString(await {notFoundEntry.importName}.page(req)))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(req)) is crown.Response:\n"
    code &= &"        res = {notFoundEntry.importName}.page(req)\n"
    code &= &"      else:\n"
    code &= &"        res = await {notFoundEntry.importName}.page(req)\n"
    code &= &"    else:\n"
    code &= &"      when type({notFoundEntry.importName}.page(c, p)) is string:\n"
    code &= &"        res = htmlResponse({notFoundEntry.importName}.page(c, p))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(c, p)) is Html:\n"
    code &= &"        res = htmlResponse(crown.crownTiaraHtmlToString({notFoundEntry.importName}.page(c, p)))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(c, p)) is Future[Html]:\n"
    code &= &"        res = htmlResponse(crown.crownTiaraHtmlToString(await {notFoundEntry.importName}.page(c, p)))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(c, p)) is crown.Response:\n"
    code &= &"        res = {notFoundEntry.importName}.page(c, p)\n"
    code &= &"      else:\n"
    code &= &"        res = await {notFoundEntry.importName}.page(c, p)\n"
    code &= &"    res.status = Http404\n" # Force 404 status
    code &= &"    var contentType = \"\"\n"
    code &= &"    if res.headers.hasKey(\"Content-Type\"): contentType = $res.headers[\"Content-Type\"]\n"
    code &= &"    elif res.headers.hasKey(\"content-type\"): contentType = $res.headers[\"content-type\"]\n"
    code &= &"    let isLayoutEnabled = not res.headers.hasKey(\"Crown-Disable-Layout\")\n"
    code &= &"    let isCrownInjectEnabled = not res.headers.hasKey(\"Crown-Disable-Inject\")\n"
    code &= &"    if contentType.contains(\"text/html\") and (isLayoutEnabled or isCrownInjectEnabled):\n"
    code &= &"      var htmlContent = res.body()\n"
    code &= &"      if isLayoutEnabled:\n"
    for layoutAlias in notFoundEntry.defaultLayoutAliases:
      code &= &"        when compiles({layoutAlias}.layout(htmlContent)):\n"
      code &= &"          htmlContent = {layoutAlias}.layout(htmlContent)\n"
    code &= &"      if isCrownInjectEnabled:\n"
    code &= &"        htmlContent = injectCrownSystem(htmlContent)\n"
    code &= &"      res = htmlResponse(htmlContent, res.status)\n"
    code &= &"    return res\n"
    code &= "\n"

  if isDev:
    let rnDev = "crownRoute" & $crownIdx
    inc crownIdx
    routeNames.add(rnDev)
    code &= "let " & rnDev & " = crownRouteRegister(\"get\", \"/routes\"):\n"
    code &= "    var html = \"\"\"<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>Crown Routes</title><script src=\"https://cdn.tailwindcss.com\"></script></head><body class=\"bg-gray-50 text-gray-800 p-8\"><div class=\"max-w-4xl mx-auto\"><h1 class=\"text-3xl font-bold mb-6\">👑 Crown Registered Routes</h1><div class=\"bg-white shadow rounded-lg overflow-hidden\"><table class=\"min-w-full\"><thead class=\"bg-gray-100\"><tr><th class=\"px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider\">Path</th><th class=\"px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider\">File</th><th class=\"px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider\">Methods</th></tr></thead><tbody class=\"divide-y divide-gray-200\">\"\"\"\n"
    for e in entries:
      var mNames = ""
      for m in e.methods:
        if mNames.len > 0: mNames &= ", "
        mNames &= m.name.toUpperAscii()
      code &= "    html &= \"\"\"<tr class=\"hover:bg-gray-50\"><td class=\"px-6 py-4 whitespace-nowrap font-mono text-sm text-blue-600\"><a href=\"" & e.urlPath & "\">" & e.urlPath & "</a></td><td class=\"px-6 py-4 whitespace-nowrap text-sm text-gray-500\">src/" & e.filePath & ".nim</td><td class=\"px-6 py-4 whitespace-nowrap text-sm text-gray-500 font-mono\">" & mNames & "</td></tr>\"\"\"\n"
    code &= "    html &= \"\"\"</tbody></table></div></div></body></html>\"\"\"\n"
    code &= "    return htmlResponse(html)\n"
    code &= "\n"

    let rnManifest = "crownRoute" & $crownIdx
    inc crownIdx
    routeNames.add(rnManifest)
    let manifestLiteral = nimStringLiteral(generateRouteManifest(appDir))
    code &= "let " & rnManifest & " = crownRouteRegister(\"get\", \"/__crown/manifest\"):\n"
    code &= "    return jsonResponse(parseJson(" & manifestLiteral & "))\n"
    code &= "\n"

    let rnBrowserError = "crownRoute" & $crownIdx
    inc crownIdx
    routeNames.add(rnBrowserError)
    code &= "let " & rnBrowserError & " = crownRouteRegister(\"post\", \"/__crown/client-error\"):\n"
    code &= "    let req = crown.Request(context: c, params: p)\n"
    code &= "    let body = req.jsonBody()\n"
    code &= "    let payload = %*{\n"
    code &= "      \"kind\": (if body.hasKey(\"kind\"): body[\"kind\"].getStr else: \"unknown\"),\n"
    code &= "      \"message\": (if body.hasKey(\"message\"): body[\"message\"].getStr else: \"\"),\n"
    code &= "      \"source\": (if body.hasKey(\"source\"): body[\"source\"].getStr else: \"\"),\n"
    code &= "      \"line\": (if body.hasKey(\"line\"): body[\"line\"].getStr else: \"\"),\n"
    code &= "      \"column\": (if body.hasKey(\"column\"): body[\"column\"].getStr else: \"\"),\n"
    code &= "      \"stack\": (if body.hasKey(\"stack\"): body[\"stack\"].getStr else: \"\")\n"
    code &= "    }\n"
    code &= "    echo \"[crown:browser] \" & $payload\n"
    code &= "    try:\n"
    code &= "      createDir(\".crown\")\n"
    code &= "      let f = open(\".crown/browser.log\", fmAppend)\n"
    code &= "      defer: f.close()\n"
    code &= "      f.writeLine($payload)\n"
    code &= "    except CatchableError:\n"
    code &= "      discard\n"
    code &= "    return jsonResponse(%*{\"ok\": true})\n"
    code &= "\n"

  if routeNames.len == 0:
    code &= "when compiles(Routes.merge(@[])):\n"
    code &= "  let routes* = Routes.merge(@[])\n"
    code &= "else:\n"
    code &= "  let routes*: seq[Routes] = @[]\n"
  else:
    code &= "when compiles(Routes.merge(@[])):\n"
    code &= "  let routes* = Routes.merge(@[" & join(routeNames, ", ") & "])\n"
    code &= "else:\n"
    code &= "  let routes* = @[" & join(routeNames, ", ") & "]\n"

  return code

proc generateMainCode*(routesPath: string, defaultListenPort: int = 8080): string =
  let moduleName = routesPath.replace(".nim", "")
  let dp = $defaultListenPort
  return "import crown_env_preserver\n" &
         "import std/[os, strutils]\n" &
         "import basolato except html\n" &
         "import " & moduleName & "\n\n" &
         "proc crownParsePortEnv(defaultPort: int): int =\n" &
         "  ## Prefer runtime PORT (Cloud Run, Fly, Docker) over the compile-time snapshot.\n" &
         "  let runtime = getEnv(\"PORT\", \"\").strip()\n" &
         "  if runtime.len > 0:\n" &
         "    try:\n" &
         "      return parseInt(runtime)\n" &
         "    except ValueError:\n" &
         "      discard\n" &
         "  let pref = crown_env_preserver.crownPortBeforeBasolatoEnv.strip()\n" &
         "  if pref.len > 0:\n" &
         "    try:\n" &
         "      return parseInt(pref)\n" &
         "    except ValueError:\n" &
         "      discard\n" &
         "  return defaultPort\n\n" &
         "when compiles(Settings.new(port = 5000)):\n" &
         "  let port = crownParsePortEnv(" & dp & ")\n" &
         "  let hostRaw = getEnv(\"HOST\", \"0.0.0.0\").strip()\n" &
         "  let host = if hostRaw.len > 0: hostRaw else: \"0.0.0.0\"\n" &
         "  let settings = Settings.new(host = host, port = port)\n" &
         "  when compiles(Routes.merge(@[])):\n" &
         "    serve(@[" & moduleName & ".routes], settings)\n" &
         "  else:\n" &
         "    serve(" & moduleName & ".routes, settings)\n" &
         "else:\n" &
         "  when compiles(Routes.merge(@[])):\n" &
         "    serve(@[" & moduleName & ".routes])\n" &
         "  else:\n" &
         "    serve(" & moduleName & ".routes)\n"

proc getCrownConfig(): JsonNode =
  result = %*{"tailwind": true, "pwa": false}
  if fileExists("crown.json"):
    try:
      let j = parseFile("crown.json")
      if j.hasKey("tailwind"): result["tailwind"] = j["tailwind"]
      if j.hasKey("pwa"): result["pwa"] = j["pwa"]
    except CatchableError:
      discard

proc generatePWAFiles*(publicDir: string = "public") =
  let config = getCrownConfig()
  if config["pwa"].getBool(false):
    if not dirExists(publicDir):
      createDir(publicDir)
    let manifestPath = publicDir / "manifest.json"
    if not fileExists(manifestPath):
      let manifestContent = """{
  "name": "Crown App",
  "short_name": "Crown",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#000000",
  "icons": []
}"""
      writeFileIfChanged(manifestPath, manifestContent)
    
    let swPath = publicDir / "sw.js"
    let swContent = """const CACHE_NAME = 'crown-pwa-cache-v1';
const SYNC_STORE_NAME = 'crown-sync-queue';

async function getDB() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('CrownPWA', 1);
    request.onupgradeneeded = (event) => {
      const db = event.target.result;
      if (!db.objectStoreNames.contains(SYNC_STORE_NAME)) {
        db.createObjectStore(SYNC_STORE_NAME, { keyPath: 'id', autoIncrement: true });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function queueRequest(request) {
  const db = await getDB();
  const tx = db.transaction(SYNC_STORE_NAME, 'readwrite');
  const store = tx.objectStore(SYNC_STORE_NAME);
  
  const serialized = {
    url: request.url,
    method: request.method,
    headers: [...request.headers.entries()],
    body: await request.clone().text(),
    timestamp: Date.now()
  };
  
  store.add(serialized);
}

async function flushQueue() {
  const db = await getDB();
  const tx = db.transaction(SYNC_STORE_NAME, 'readonly');
  const store = tx.objectStore(SYNC_STORE_NAME);
  const request = store.getAll();
  
  request.onsuccess = async () => {
    const items = request.result;
    if (!items || items.length === 0) return;
    
    for (const item of items) {
      try {
        await fetch(item.url, {
          method: item.method,
          headers: item.headers,
          body: item.body
        });
        const delTx = db.transaction(SYNC_STORE_NAME, 'readwrite');
        delTx.objectStore(SYNC_STORE_NAME).delete(item.id);
      } catch (e) {
        console.error('Failed to sync:', e);
      }
    }
  };
}

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(['/'])));
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method === 'GET') {
    event.respondWith(
      fetch(req).then((response) => {
        const resClone = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(req, resClone));
        return response;
      }).catch(() => caches.match(req))
    );
  } else {
    event.respondWith(
      fetch(req).catch(async () => {
        await queueRequest(req);
        const isHtmx = req.headers.has('HX-Request');
        if (isHtmx) {
          return new Response(
            `<div style="opacity:0.8" class="p-4 mb-4 text-sm text-yellow-800 rounded-lg bg-yellow-50">[オフライン] リクエストをローカルに保存しました。通信復帰後に自動同期されます。</div>`, 
            { headers: { 'Content-Type': 'text/html' } }
          );
        } else {
          return new Response(
            JSON.stringify({ offline: true, queued: true }), 
            { headers: { 'Content-Type': 'application/json' } }
          );
        }
      })
    );
  }
});

self.addEventListener('sync', (event) => {
  if (event.tag === 'crown-sync') event.waitUntil(flushQueue());
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'FLUSH_QUEUE') flushQueue();
});

	flushQueue();
	"""
    writeFileIfChanged(swPath, swContent)

import std/[json, options, os, sets, strformat, strutils]

type
  RouteEntry = object
    filePath: string
    urlPath: string
    methods: seq[tuple[name: string, layout: string]]
    importName: string

  ClientRouteEntry* = object
    urlPath*: string
    sourcePath*: string
    assetPath*: string

  CrownEmitPattern* = object
    path*: string
    catchDepth*: int
    catchName*: string

proc readCatchAllMaxDepth*(): int =
  ## Max path segments for Crown catch-all (`p___name`) without changing Basolato.
  result = 16
  if not fileExists("crown.json"):
    return
  try:
    let j = parseFile("crown.json")
    if j.kind == JObject and j.hasKey("catchAllMaxDepth"):
      let n = j["catchAllMaxDepth"]
      if n.kind == JInt:
        result = max(1, min(64, n.getInt()))
  except:
    discard

proc parseCrownCatchAll*(urlPath: string): Option[tuple[prefix: string, name: string]] =
  ## ``/wiki/{@slug}`` → prefix ``/wiki``, name ``slug``. Crown-internal marker `{@…}` is not passed to Basolato.
  const tok = "{@"
  let openIdx = urlPath.find(tok)
  if openIdx < 0:
    return none(tuple[prefix, name: string])
  let closeIdx = urlPath.find('}', openIdx)
  if closeIdx < 0:
    return none(tuple[prefix, name: string])
  let name = urlPath[openIdx + tok.len ..< closeIdx]
  if name.len == 0 or not name[0].isAlphaAscii:
    return none(tuple[prefix, name: string])
  for ch in name:
    if not (ch in {'a'..'z', 'A'..'Z', '0'..'9', '_'}):
      return none(tuple[prefix, name: string])
  var prefix = urlPath[0 ..< openIdx]
  if prefix.endsWith("/"):
    prefix = prefix[0 .. ^2]
  if prefix == "/":
    prefix = ""
  some((prefix, name))

proc buildGreedyBasolatoPath*(prefix: string, depth: int): string =
  ## e.g. prefix ``wiki``, depth 2 → ``/wiki/{g0:str}/{g1:str}``
  var base = prefix
  if base.endsWith("/"):
    base = base[0 .. ^2]
  if base.len > 0 and not base.startsWith("/"):
    base = "/" & base
  for i in 0 ..< depth:
    base = base & "/{g" & $i & ":str}"
  if base.len == 0:
    base = "/"
  elif not base.startsWith("/"):
    base = "/" & base
  base

proc expandRoutePatterns*(urlPath: string): seq[CrownEmitPattern] =
  let co = parseCrownCatchAll(urlPath)
  if co.isNone:
    return @[CrownEmitPattern(path: urlPath, catchDepth: -1, catchName: "")]
  let (pre, nm) = co.get
  let maxD = readCatchAllMaxDepth()
  result = @[]
  for d in 1 .. maxD:
    result.add(CrownEmitPattern(
      path: buildGreedyBasolatoPath(pre, d),
      catchDepth: d,
      catchName: nm
    ))

proc normalizeCatchAllMarkersForClient*(urlPath: string): string =
  ## Maps `{@slug}` → `{_slug:catch}` for stable client bundle filenames.
  result = urlPath
  while true:
    let a = result.find("{@")
    if a < 0:
      break
    let b = result.find('}', a)
    if b < 0:
      break
    let nm = result[a + 2 ..< b]
    result = result[0 ..< a] & "{_" & nm & ":catch}" & result[b + 1 .. ^1]

proc normalizeModulePath*(path: string): string =
  ## Convert filesystem separators to Nim module separators.
  path.replace("\\", "/").replace(".nim", "")

proc makeImportAlias*(modulePath: string): string =
  modulePath.replace("\\", "_").replace("/", "_").replace("-", "_")

proc writeFileIfChanged(path, content: string) =
  if fileExists(path) and readFile(path) == content:
    return
  writeFile(path, content)

proc detectMethods*(content: string): seq[tuple[name: string, layout: string]] =
  var methods: seq[tuple[name: string, layout: string]]
  for line in content.splitLines():
    let l = line.strip()
    if l.startsWith("proc "):
      let parts = l.split({' ', '(', '*', ':', '\t'})
      if parts.len > 1:
        let name = parts[1]
        if name in ["get", "post", "put", "delete", "patch", "page", "sitemap",
            "robots"]:
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

proc isCrownRouteGroupSegment*(segment: string): bool =
  ## Folders named `__segment` are omitted from the URL (Next.js route-group style).
  segment.len >= 3 and segment.startsWith("__")

proc mapPathSegmentToRoute*(segment: string): string =
  ## ``p___slug`` → greedy catch-all marker ``{@slug}`` (expanded to many Basolato routes).
  ## `p_id` -> `{id:str}`, `p_id_int` / `p_user_id_int` -> `{user_id:int}` (Basolato).
  if segment.len >= 5 and segment.startsWith("p___"):
    let name = segment[4 .. ^1]
    if name.len == 0 or not name[0].isAlphaAscii:
      return segment
    return "{@" & name & "}"
  if not segment.startsWith("p_") or segment.len <= 2:
    return segment
  let body = segment[2 .. ^1]
  if body.endsWith("_int") and body.len > 4:
    let name = body[0 .. ^5]
    if name.len == 0:
      return segment
    return "{" & name & ":int}"
  if body.len == 0:
    return segment
  return "{" & body & ":str}"

proc resolveUrlPath*(appDir, filePath: string): string =
  let relPath = filePath.relativePath(appDir)
  var urlPath = "/" & relPath.replace(".nim", "").replace("\\", "/") # Windows support
  if urlPath.endsWith("/page"):
    urlPath = urlPath[0 .. ^6]

  var finalParts: seq[string]
  for part in urlPath.split('/'):
    if part.len == 0:
      continue
    if isCrownRouteGroupSegment(part):
      continue
    finalParts.add(mapPathSegmentToRoute(part))
  urlPath = finalParts.join("/")
  if urlPath.len > 0:
    urlPath = "/" & urlPath

  if urlPath == "":
    urlPath = "/"
  if urlPath != "/" and urlPath.endsWith("/"):
    urlPath = urlPath[0 .. ^2]

  let fn = filePath.extractFilename()
  if fn == "sitemap.nim":
    urlPath = urlPath & ".xml"
  elif fn == "robots.nim":
    urlPath = urlPath & ".txt"
  return urlPath

proc normalizeClientAssetSegment(segment: string): string =
  var normalized = newStringOfCap(segment.len + 4)
  for ch in segment:
    if (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or
        (ch >= '0' and ch <= '9') or ch in {'-', '_'}:
      normalized.add(ch)
    else:
      normalized.add('_')
  result = normalized.strip(chars = {'_'})
  if result.len == 0:
    result = "index"

proc routeClientAssetPath*(urlPath: string): string =
  ## Returns a deterministic, route-scoped client asset path (relative) like:
  ## "/" -> "index.js", "/blog/{id:str}" -> "blog/_id.js"
  let pathForClient = normalizeCatchAllMarkersForClient(urlPath)
  if pathForClient == "/" or pathForClient.len == 0:
    return "index.js"

  var segments: seq[string]
  for rawSegment in pathForClient.split('/'):
    if rawSegment.len == 0:
      continue
    if rawSegment.startsWith("{") and rawSegment.endsWith("}"):
      var inner = rawSegment[1 .. ^2]
      let colonIdx = inner.find(':')
      if colonIdx >= 0:
        inner = inner[0 ..< colonIdx]
      segments.add("_" & normalizeClientAssetSegment(inner))
    else:
      segments.add(normalizeClientAssetSegment(rawSegment))

  if segments.len == 0:
    return "index.js"
  segments.join("/") & ".js"

proc routeClientScriptUrl*(urlPath: string): string =
  "/.crown/client/" & routeClientAssetPath(urlPath).replace("\\", "/")

proc collectRouteClientEntries*(appDir, routeEntryFile: string): seq[ClientRouteEntry] =
  if routeEntryFile.len == 0 or not dirExists(appDir):
    return @[]

  var seen = initHashSet[string]()
  for path in walkDirRec(appDir):
    if path.endsWith(".nim") and path.extractFilename() == "page.nim":
      let entryPath = path.parentDir() / routeEntryFile
      if not fileExists(entryPath):
        continue
      let urlPath = resolveUrlPath(appDir, path)
      if seen.contains(urlPath):
        continue
      seen.incl(urlPath)
      result.add(ClientRouteEntry(
        urlPath: urlPath,
        sourcePath: entryPath,
        assetPath: routeClientAssetPath(urlPath)
      ))

proc generateRoutesCode*(appDir: string, isDev: bool = false): string =
  var entries: seq[RouteEntry]
  var notFoundEntry: RouteEntry
  var hasNotFound = false

  for path in walkDirRec(appDir):
    if path.endsWith(".nim") and not path.endsWith("layout.nim"):
      let content = readFile(path)
      let methods = detectMethods(content)
      if methods.len > 0:
        let relPath = normalizeModulePath(path.relativePath("src"))
        let importName = makeImportAlias(relPath)

        let entry = RouteEntry(
          filePath: relPath,
          urlPath: resolveUrlPath(appDir, path),
          methods: methods,
          importName: importName
        )

        if path.endsWith("not_found.nim"):
          notFoundEntry = entry
          hasNotFound = true
        else:
          entries.add(entry)

  var code = "import std/os\nimport std/json\nimport basolato except html\nimport crown/core\nimport std/asyncdispatch\n"
  var uniqueImports = initHashSet[string]()

  # Import all layouts safely
  var layoutImports = initHashSet[string]()
  let layoutDir = appDir / "layout"
  if dirExists(layoutDir):
    for path in walkDirRec(layoutDir):
      if path.endsWith(".nim"):
        let relPath = normalizeModulePath(path.relativePath("src"))
        let layoutImportName = "crown_layout_" & path.extractFilename().replace(
            ".nim", "")
        let stmt = &"import ../src/{relPath} as {layoutImportName}\n"
        if not layoutImports.contains(stmt):
          code &= stmt
          layoutImports.incl(stmt)

  # Import all pages into .crown/ (relative depth +1, thus ../src/)
  for e in entries:
    let importStmt = &"import ../src/{e.filePath} as {e.importName}\n"
    if not uniqueImports.contains(importStmt):
      code &= importStmt
      uniqueImports.incl(importStmt)

  if hasNotFound:
    code &= &"import ../src/{notFoundEntry.filePath} as {notFoundEntry.importName}\n"

  code &= "\nlet routes* = @[\n"
  for e in entries:
    for pat in expandRoutePatterns(e.urlPath):
      let concretePath = pat.path
      let useCatch = pat.catchDepth >= 0
      let reqLine = if useCatch:
          &"    let req = Request(context: c, params: crownParamsWithCatch(p, \"{pat.catchName}\", crownJoinGreedy(p, {pat.catchDepth})))\n"
        else:
          "    let req = Request(context: c, params: p)\n"
      for methodTuple in e.methods:
        let m = methodTuple.name
        let explicitLayout = methodTuple.layout
        let httpMethod = if m in ["page", "sitemap", "robots"]: "get" else: m
        let explicitArg = if explicitLayout != "": "\"" & explicitLayout &
            "\"" else: "\"\""
        let strResFn = if m == "sitemap": "xmlResponse" elif m ==
            "robots": "plainTextResponse" else: "htmlResponse"

        # Generate a wrapper proc inline that intelligently tries to call the page handlers
        code &= &"  Route.{httpMethod}(\"{concretePath}\", proc(c: Context, p: Params): Future[Response] {{.async.}} =\n"
        code &= &"    var res: Response\n"
        code &= reqLine
        code &= &"    when compiles({e.importName}.{m}(req, {explicitArg})):\n"
        code &= &"      when type({e.importName}.{m}(req, {explicitArg})) is string:\n"
        code &= &"        res = {strResFn}({e.importName}.{m}(req, {explicitArg}))\n"
        code &= &"      elif type({e.importName}.{m}(req, {explicitArg})) is Html:\n"
        code &= &"        res = htmlResponse(${e.importName}.{m}(req, {explicitArg}))\n"
        code &= &"      elif type({e.importName}.{m}(req, {explicitArg})) is Future[Html]:\n"
        code &= &"        res = htmlResponse($(await {e.importName}.{m}(req, {explicitArg})))\n"
        code &= &"      elif type({e.importName}.{m}(req, {explicitArg})) is Response:\n"
        code &= &"        res = {e.importName}.{m}(req, {explicitArg})\n"
        code &= &"      else:\n"
        code &= &"        res = await {e.importName}.{m}(req, {explicitArg})\n"
        code &= &"    elif compiles({e.importName}.{m}(req)):\n"
        code &= &"      when type({e.importName}.{m}(req)) is string:\n"
        code &= &"        res = {strResFn}({e.importName}.{m}(req))\n"
        code &= &"      elif type({e.importName}.{m}(req)) is Html:\n"
        code &= &"        res = htmlResponse(${e.importName}.{m}(req))\n"
        code &= &"      elif type({e.importName}.{m}(req)) is Future[Html]:\n"
        code &= &"        res = htmlResponse($(await {e.importName}.{m}(req)))\n"
        code &= &"      elif type({e.importName}.{m}(req)) is Response:\n"
        code &= &"        res = {e.importName}.{m}(req)\n"
        code &= &"      else:\n"
        code &= &"        res = await {e.importName}.{m}(req)\n"
        code &= &"    else:\n"
        code &= &"      # Fallback to pure Basolato signature for backwards compatibility\n"
        code &= &"      when type({e.importName}.{m}(c, p)) is string:\n"
        code &= &"        res = {strResFn}({e.importName}.{m}(c, p))\n"
        code &= &"      elif type({e.importName}.{m}(c, p)) is Html:\n"
        code &= &"        res = htmlResponse(${e.importName}.{m}(c, p))\n"
        code &= &"      elif type({e.importName}.{m}(c, p)) is Future[Html]:\n"
        code &= &"        res = htmlResponse($(await {e.importName}.{m}(c, p)))\n"
        code &= &"      elif type({e.importName}.{m}(c, p)) is Response:\n"
        code &= &"        res = {e.importName}.{m}(c, p)\n"
        code &= &"      else:\n"
        code &= &"        res = await {e.importName}.{m}(c, p)\n"
        code &= &"    \n"
        code &= &"    var contentType = \"\"\n"
        code &= &"    if res.headers.hasKey(\"Content-Type\"): contentType = $res.headers[\"Content-Type\"]\n"
        code &= &"    elif res.headers.hasKey(\"content-type\"): contentType = $res.headers[\"content-type\"]\n"
        let isPage = if m in ["page"]: "true" else: "false"
        code &= &"    let isLayoutEnabled = {isPage} and not res.headers.hasKey(\"Crown-Disable-Layout\")\n"
        code &= &"    if contentType.contains(\"text/html\") and isLayoutEnabled:\n"
        code &= &"      var htmlContent = res.body()\n"
        if explicitLayout != "":
          let layoutNameSpace = "crown_layout_" & explicitLayout
          code &= &"      when compiles({layoutNameSpace}.layout(htmlContent)):\n"
          code &= &"        htmlContent = {layoutNameSpace}.layout(htmlContent)\n"
        else:
          code &= &"      when compiles(crown_layout_layout.layout(htmlContent)):\n"
          code &= &"        htmlContent = crown_layout_layout.layout(htmlContent)\n"
        code &= &"      htmlContent = injectCrownSystem(htmlContent, \"{e.urlPath}\")\n"
        code &= &"      res = htmlResponse(htmlContent, res.status)\n"
        code &= &"    return res\n"
        code &= &"  ),\n"

  if hasNotFound:
    code &= &"  Route.get(\"/{{path:str}}\", proc(c: Context, p: Params): Future[Response] {{.async.}} =\n"
    code &= &"    var res: Response\n"
    code &= &"    let req = Request(context: c, params: p)\n"
    code &= &"    when compiles({notFoundEntry.importName}.page(req, \"\")):\n"
    code &= &"      when type({notFoundEntry.importName}.page(req, \"\")) is string:\n"
    code &= &"        res = htmlResponse({notFoundEntry.importName}.page(req, \"\"))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(req, \"\")) is Html:\n"
    code &= &"        res = htmlResponse(${notFoundEntry.importName}.page(req, \"\"))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(req, \"\")) is Future[Html]:\n"
    code &= &"        res = htmlResponse($(await {notFoundEntry.importName}.page(req, \"\")))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(req, \"\")) is Response:\n"
    code &= &"        res = {notFoundEntry.importName}.page(req, \"\")\n"
    code &= &"      else:\n"
    code &= &"        res = await {notFoundEntry.importName}.page(req, \"\")\n"
    code &= &"    elif compiles({notFoundEntry.importName}.page(req)):\n"
    code &= &"      when type({notFoundEntry.importName}.page(req)) is string:\n"
    code &= &"        res = htmlResponse({notFoundEntry.importName}.page(req))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(req)) is Html:\n"
    code &= &"        res = htmlResponse(${notFoundEntry.importName}.page(req))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(req)) is Future[Html]:\n"
    code &= &"        res = htmlResponse($(await {notFoundEntry.importName}.page(req)))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(req)) is Response:\n"
    code &= &"        res = {notFoundEntry.importName}.page(req)\n"
    code &= &"      else:\n"
    code &= &"        res = await {notFoundEntry.importName}.page(req)\n"
    code &= &"    else:\n"
    code &= &"      when type({notFoundEntry.importName}.page(c, p)) is string:\n"
    code &= &"        res = htmlResponse({notFoundEntry.importName}.page(c, p))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(c, p)) is Html:\n"
    code &= &"        res = htmlResponse(${notFoundEntry.importName}.page(c, p))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(c, p)) is Future[Html]:\n"
    code &= &"        res = htmlResponse($(await {notFoundEntry.importName}.page(c, p)))\n"
    code &= &"      elif type({notFoundEntry.importName}.page(c, p)) is Response:\n"
    code &= &"        res = {notFoundEntry.importName}.page(c, p)\n"
    code &= &"      else:\n"
    code &= &"        res = await {notFoundEntry.importName}.page(c, p)\n"
    code &= &"    res.status = Http404\n" # Force 404 status
    code &= &"    var contentType = \"\"\n"
    code &= &"    if res.headers.hasKey(\"Content-Type\"): contentType = $res.headers[\"Content-Type\"]\n"
    code &= &"    elif res.headers.hasKey(\"content-type\"): contentType = $res.headers[\"content-type\"]\n"
    code &= &"    let isLayoutEnabled = not res.headers.hasKey(\"Crown-Disable-Layout\")\n"
    code &= &"    if contentType.contains(\"text/html\") and isLayoutEnabled:\n"
    code &= &"      var htmlContent = res.body()\n"
    code &= &"      when compiles(crown_layout_layout.layout(htmlContent)):\n"
    code &= &"        htmlContent = crown_layout_layout.layout(htmlContent)\n"
    code &= &"      htmlContent = injectCrownSystem(htmlContent, \"/{{path:str}}\")\n"
    code &= &"      res = htmlResponse(htmlContent, res.status)\n"
    code &= &"    return res\n"
    code &= &"  ),\n"

  if isDev:
    code &= "  Route.get(\"/__crown/dev/frontend-error\", proc(c: Context, p: Params): Future[Response] {.async.} =\n"
    code &= "    let errPath = \".crown/frontend-error.json\"\n"
    code &= "    if fileExists(errPath):\n"
    code &= "      try:\n"
    code &= "        return jsonResponse(parseJson(readFile(errPath)))\n"
    code &= "      except:\n"
    code &= "        discard\n"
    code &= "    return jsonResponse(%*{\"error\": \"\"})\n"
    code &= "  ),\n"

    code &= "  Route.get(\"/routes\", proc(c: Context, p: Params): Future[Response] {.async.} =\n"
    code &= "    var html = \"\"\"<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>Crown Routes</title><script src=\"https://cdn.tailwindcss.com\"></script></head><body class=\"bg-gray-50 text-gray-800 p-8\"><div class=\"max-w-4xl mx-auto\"><h1 class=\"text-3xl font-bold mb-6\">👑 Crown Registered Routes</h1><div class=\"bg-white shadow rounded-lg overflow-hidden\"><table class=\"min-w-full\"><thead class=\"bg-gray-100\"><tr><th class=\"px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider\">Path</th><th class=\"px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider\">File</th><th class=\"px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider\">Methods</th></tr></thead><tbody class=\"divide-y divide-gray-200\">\"\"\"\n"
    for e in entries:
      var mNames = ""
      for m in e.methods:
        if mNames.len > 0: mNames &= ", "
        mNames &= m.name.toUpperAscii()
      code &= "    html &= \"\"\"<tr class=\"hover:bg-gray-50\"><td class=\"px-6 py-4 whitespace-nowrap font-mono text-sm text-blue-600\"><a href=\"" & e.urlPath & "\">" & e.urlPath & "</a></td><td class=\"px-6 py-4 whitespace-nowrap text-sm text-gray-500\">src/" & e.filePath & ".nim</td><td class=\"px-6 py-4 whitespace-nowrap text-sm text-gray-500 font-mono\">" & mNames & "</td></tr>\"\"\"\n"
    code &= "    html &= \"\"\"</tbody></table></div></div></body></html>\"\"\"\n"
    code &= "    return htmlResponse(html)\n"
    code &= "  ),\n"

  code &= "]\n"



  return code

proc generateMainCode*(routesPath: string): string =
  let moduleName = routesPath.replace(".nim", "")
  return "import basolato except html\n" &
         "import " & moduleName & "\n\n" &
         "serve(" & moduleName & ".routes)\n"

proc getCrownConfig(): JsonNode =
  result = %*{"tailwind": true, "pwa": false}
  if fileExists("crown.json"):
    try:
      let j = parseFile("crown.json")
      if j.hasKey("tailwind"): result["tailwind"] = j["tailwind"]
      if j.hasKey("pwa"): result["pwa"] = j["pwa"]
    except:
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

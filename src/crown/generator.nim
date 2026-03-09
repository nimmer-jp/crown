import std/[os, strutils, strformat, sets, json]

type
  RouteEntry = object
    filePath: string
    urlPath: string
    methods: seq[tuple[name: string, layout: string]]
    importName: string

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

  var code = "import std/os\nimport basolato except html\nimport crown/core\nimport std/asyncdispatch\n"
  var uniqueImports = initHashSet[string]()

  # Import all layouts safely
  var layoutImports = initHashSet[string]()
  let layoutDir = appDir / "layout"
  if dirExists(layoutDir):
    for path in walkDirRec(layoutDir):
      if path.endsWith(".nim"):
        let relPath = path.relativePath("src/")
        let layoutImportName = "crown_layout_" & path.extractFilename().replace(
            ".nim", "")
        let stmt = &"import ../src/{relPath.replace(\".nim\", \"\")} as {layoutImportName}\n"
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
    for methodTuple in e.methods:
      let m = methodTuple.name
      let explicitLayout = methodTuple.layout
      let httpMethod = if m == "page": "get" else: m
      let explicitArg = if explicitLayout != "": "\"" & explicitLayout &
          "\"" else: "\"\""

      # Generate a wrapper proc inline that intelligently tries to call the page handlers
      code &= &"  Route.{httpMethod}(\"{e.urlPath}\", proc(c: Context, p: Params): Future[Response] {{.async.}} =\n"
      code &= &"    var res: Response\n"
      code &= &"    let req = Request(context: c, params: p)\n"
      code &= &"    when compiles({e.importName}.{m}(req, {explicitArg})):\n"
      code &= &"      when type({e.importName}.{m}(req, {explicitArg})) is string:\n"
      code &= &"        res = htmlResponse({e.importName}.{m}(req, {explicitArg}))\n"
      code &= &"      elif type({e.importName}.{m}(req, {explicitArg})) is Response:\n"
      code &= &"        res = {e.importName}.{m}(req, {explicitArg})\n"
      code &= &"      else:\n"
      code &= &"        res = await {e.importName}.{m}(req, {explicitArg})\n"
      code &= &"    elif compiles({e.importName}.{m}(req)):\n"
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
      let isPage = if m == "page": "true" else: "false"
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
      code &= &"      htmlContent = injectCrownSystem(htmlContent)\n"
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
    code &= &"      elif type({notFoundEntry.importName}.page(req, \"\")) is Response:\n"
    code &= &"        res = {notFoundEntry.importName}.page(req, \"\")\n"
    code &= &"      else:\n"
    code &= &"        res = await {notFoundEntry.importName}.page(req, \"\")\n"
    code &= &"    elif compiles({notFoundEntry.importName}.page(req)):\n"
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
    code &= &"    let isLayoutEnabled = not res.headers.hasKey(\"Crown-Disable-Layout\")\n"
    code &= &"    if contentType.contains(\"text/html\") and isLayoutEnabled:\n"
    code &= &"      var htmlContent = res.body()\n"
    code &= &"      when compiles(crown_layout_layout.layout(htmlContent)):\n"
    code &= &"        htmlContent = crown_layout_layout.layout(htmlContent)\n"
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
      writeFile(manifestPath, manifestContent)
    
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
    writeFile(swPath, swContent)


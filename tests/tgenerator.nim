import std/options
import std/sequtils
import std/strutils
import std/unittest
import crown/generator

suite "Generator tests":
  test "detectMethods recognizes sitemap and robots procs":
    let sample = """
    proc sitemap*(req: Request): string = ""
    proc robots*(req: Request): string = ""
    """
    let methods = detectMethods(sample).mapIt(it.name)
    check "sitemap" in methods
    check "robots" in methods

  test "detectMethods extracts http methods from nim file code":
    let sampleContent = """
    import crown/core

    proc page*(context: Context, params: Params): Future[Response] {.async.} =
      return htmlResponse fmt"hello"

    proc post*(context: Context, params: Params): Future[Response] {.async.} =
      return htmlResponse fmt"saved"
    """
    let methods = detectMethods(sampleContent)
    let methodNames = methods.mapIt(it.name)
    check "page" in methodNames
    check "post" in methodNames
    check "get" notin methodNames

  test "resolveUrlPath properly resolves nested directory structures":
    # Mocks app structure
    let root = "/example/src/app"

    check resolveUrlPath(root, "/example/src/app/page.nim") == "/"
    check resolveUrlPath(root, "/example/src/app/editor/page.nim") == "/editor"
    check resolveUrlPath(root, "/example/src/app/api/save.nim") == "/api/save"

  test "normalizes windows module paths for imports and aliases":
    check normalizeModulePath(r"app\page.nim") == "app/page"
    check normalizeModulePath(r"app\admin\index.nim") == "app/admin/index"
    check makeImportAlias(r"app\page") == "app_page"
    check makeImportAlias("app/page") == "app_page"
    check makeImportAlias("app/admin-user/page") == "app_admin_user_page"

  test "derives stable route client asset paths":
    check routeClientAssetPath("/") == "index.js"
    check routeClientAssetPath("/editor") == "editor.js"
    check routeClientAssetPath("/blog/{id:str}") == "blog/_id.js"
    check routeClientAssetPath("/blog/{id:int}") == "blog/_id.js"
    check routeClientAssetPath("/foo-bar/baz") == "foo-bar/baz.js"

  test "resolveUrlPath strips __ route-group folders and maps p_*_int":
    let root = "/proj/src/app"
    check resolveUrlPath(root, "/proj/src/app/__marketing/about/page.nim") == "/about"
    check resolveUrlPath(root, "/proj/src/app/items/p_id_int/page.nim") == "/items/{id:int}"
    check resolveUrlPath(root, "/proj/src/app/p_slug.nim") == "/{slug:str}"

  test "route group and dynamic helpers":
    check isCrownRouteGroupSegment("__shop")
    check not isCrownRouteGroupSegment("_x")
    check mapPathSegmentToRoute("p_id_int") == "{id:int}"
    check mapPathSegmentToRoute("p_user_id_int") == "{user_id:int}"
    check mapPathSegmentToRoute("p_id") == "{id:str}"

  test "well-known sitemap and robots paths":
    let root = "/proj/src/app"
    check resolveUrlPath(root, "/proj/src/app/sitemap.nim") == "/sitemap.xml"
    check resolveUrlPath(root, "/proj/src/app/robots.nim") == "/robots.txt"
    check resolveUrlPath(root, "/proj/src/app/__seo/sitemap.nim") == "/sitemap.xml"

  test "catch-all p___ segment and expansion helpers":
    check mapPathSegmentToRoute("p___slug") == "{@slug}"
    check parseCrownCatchAll("/wiki/{@page}").get() == ("/wiki", "page")
    check parseCrownCatchAll("/{slug}").isNone
    check buildGreedyBasolatoPath("wiki", 2) == "/wiki/{g0:str}/{g1:str}"
    check buildGreedyBasolatoPath("", 1) == "/{g0:str}"
    let ex = expandRoutePatterns("/docs/{@rest}")
    check ex.len == readCatchAllMaxDepth()
    check ex[0].path == "/docs/{g0:str}"
    check ex[0].catchDepth == 1
    check ex[0].catchName == "rest"
    check normalizeCatchAllMarkersForClient("/x/{@a}/y") == "/x/{_a:catch}/y"
    let root = "/proj/src/app"
    check resolveUrlPath(root, "/proj/src/app/wiki/p___page/page.nim") == "/wiki/{@page}"

  test "generateRoutesCode splits layout vs inject flags and omits std/os when not dev":
    let appDir = "example/src/app"
    let prod = generateRoutesCode(appDir, isDev = false)
    check "let isCrownInjectEnabled" in prod
    check "Crown-Disable-Inject" in prod
    check "if isLayoutEnabled:" in prod
    check "if isCrownInjectEnabled:" in prod
    check "import std/os\n" notin prod
    check "crownRouteRegister(Route.get," in prod

    let dev = generateRoutesCode(appDir, isDev = true)
    check dev.startsWith("import std/os\nimport std/json\n")

  test "generateMainCode uses Settings when available and falls back to serve(routes)":
    let main016 = generateMainCode("routes.nim")
    check "import std/[os, strutils]" in main016
    check "when compiles(Settings.new(port: 5000)):" in main016
    check "serve(routes.routes, settings)" in main016
    check "serve(routes.routes)\n" in main016

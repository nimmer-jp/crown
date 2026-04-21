import std/unittest
import std/sequtils
import std/strutils
import crown/generator

suite "Generator tests":
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

  test "generateRoutesCode uses crownRouteRegister for Basolato 0.16 / 0.15 dual Controller":
    let prod = generateRoutesCode("example/src/app", isDev = false)
    check prod.contains("crownRouteRegister")
    check prod.contains("let crownRoute0 = crownRouteRegister")
    check prod.contains("let routes* = @[")
    check prod.contains("crownRoute0, crownRoute1")

  test "generateMainCode uses Settings when available else serve(routes) only (0.15 compat)":
    let mainCode = generateMainCode("routes.nim")
    check "import std/[os, strutils]" in mainCode
    check "when compiles(Settings.new(port: 5000)):" in mainCode
    check "serve(routes.routes, settings)" in mainCode
    check "else:\n  serve(routes.routes)\n" in mainCode

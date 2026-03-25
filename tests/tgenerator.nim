import std/unittest
import std/sequtils
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

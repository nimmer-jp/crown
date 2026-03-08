import std/unittest
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
    check "page" in methods
    check "post" in methods
    check "get" notin methods

  test "resolveUrlPath properly resolves nested directory structures":
    # Mocks app structure
    let root = "/example/src/app"

    check resolveUrlPath(root, "/example/src/app/page.nim") == "/"
    check resolveUrlPath(root, "/example/src/app/editor/page.nim") == "/editor"
    check resolveUrlPath(root, "/example/src/app/api/save.nim") == "/api/save"

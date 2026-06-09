import std/unittest
import std/json
import std/os
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
    check makeImportAlias("app/(admin)/users/[id:int]/page") ==
        "app_admin_users_id_int_page"

  test "resolveUrlPath supports route groups and bracket dynamic segments":
    let root = "/example/src/app"
    check resolveUrlPath(root, "/example/src/app/(marketing)/blog/[id:int]/page.nim") ==
        "/blog/{id:int}"
    check resolveUrlPath(root, "/example/src/app/docs/[...slug]/page.nim") ==
        "/docs/{slug:str}"

  test "generateRoutesCode uses crownRouteRegister for Basolato 0.16 / 0.15 dual Controller":
    let prod = generateRoutesCode("example/src/app", isDev = false)
    check prod.contains("import crown/core as crown")
    check prod.contains("crownRouteRegister")
    check prod.contains("let crownRoute0 = crownRouteRegister(\"get\"")
    check prod.contains("Routes.merge(@[")
    check prod.contains("crownRoute0, crownRoute1")

  test "generateRoutesCode exposes dev manifest and loader-backed pages":
    let tempDir = getTempDir() / ("crown-routes-06-" & $getCurrentProcessId())
    if dirExists(tempDir):
      removeDir(tempDir)
    createDir(tempDir / "src" / "app" / "(admin)" / "users" / "[id:int]")
    createDir(tempDir / "src" / "app" / "layout")
    defer: removeDir(tempDir)
    writeFile(tempDir / "src" / "app" / "layout" / "layout.nim",
        "proc layout*(content: string): string = content\n")
    writeFile(tempDir / "src" / "app" / "(admin)" / "users" / "layout.nim",
        "proc layout*(content: string): string = \"<section>\" & content & \"</section>\"\n")
    writeFile(tempDir / "src" / "app" / "(admin)" / "users" / "[id:int]" / "page.nim",
        """
import crown/core

type UserVm* = object
  id*: int

proc loader*(req: Request): UserVm =
  UserVm(id: req.param("id", int))

proc page*(req: Request, data: UserVm): string =
  $data.id
""")

    let code = generateRoutesCode(tempDir / "src" / "app", isDev = true)
    check code.contains("\"/users/{id:int}\"")
    check code.contains("import \"../src/app/(admin)/users/[id:int]/page.nim\"")
    check code.contains(".loader(req)")
    check code.contains("/__crown/manifest")
    check code.contains("/__crown/client-error")

  test "generateRouteManifest records 0.6 route metadata":
    let tempDir = getTempDir() / ("crown-manifest-06-" & $getCurrentProcessId())
    if dirExists(tempDir):
      removeDir(tempDir)
    createDir(tempDir / "src" / "app" / "(admin)" / "users" / "[id:int]")
    createDir(tempDir / "src" / "app" / "layout")
    defer: removeDir(tempDir)
    writeFile(tempDir / "src" / "app" / "layout" / "layout.nim",
        "proc layout*(content: string): string = content\n")
    writeFile(tempDir / "src" / "app" / "(admin)" / "users" / "[id:int]" / "loading.nim",
        "proc loading*(): string = \"loading\"\n")
    writeFile(tempDir / "src" / "app" / "(admin)" / "users" / "[id:int]" / "page.nim",
        """
import crown/core
proc loader*(req: Request): int = req.param("id", int)
proc page*(req: Request, data: int): string = $data
""")
    let manifest = parseJson(generateRouteManifest(tempDir / "src" / "app"))
    check manifest["version"].getStr() == "0.6"
    check manifest["routes"].len == 1
    let route = manifest["routes"][0]
    check route["path"].getStr() == "/users/{id:int}"
    check route["dynamic"].getBool()
    check route["hasLoader"].getBool()
    check route["hasLoading"].getBool()
    check route["params"][0]["name"].getStr() == "id"
    check route["params"][0]["type"].getStr() == "int"

  test "generateRoutesCode splits layout vs inject flags and omits std/os when not dev":
    let appDir = "example/src/app"
    let prod = generateRoutesCode(appDir, isDev = false)
    check "let isCrownInjectEnabled" in prod
    check "Crown-Disable-Inject" in prod
    check "if isLayoutEnabled:" in prod
    check "if isCrownInjectEnabled:" in prod
    check "import std/os\n" notin prod

    let dev = generateRoutesCode(appDir, isDev = true)
    check dev.startsWith("import std/os\nimport std/json\n")

  test "generateMainCode prefers runtime PORT and embeds crown.json default":
    let mainCode = generateMainCode("routes.nim", 9000)
    check "import crown_env_preserver" in mainCode
    check "let runtime = getEnv(\"PORT\"" in mainCode
    check "crownParsePortEnv(9000)" in mainCode

  test "generateMainCode uses Settings when available else serve(routes) only (0.15 compat)":
    let mainCode = generateMainCode("routes.nim")
    check "import crown_env_preserver" in mainCode
    check mainCode.contains("crown_env_preserver.crownPortBeforeBasolatoEnv")
    check "import std/[os, strutils]" in mainCode
    check "when compiles(Settings.new(port = 5000)):" in mainCode
    check "crownParsePortEnv(8080)" in mainCode
    check mainCode.contains("serve(@[routes.routes], settings)")
    check mainCode.contains("serve(routes.routes, settings)")
    check mainCode.contains("when compiles(Routes.merge(@[])):")

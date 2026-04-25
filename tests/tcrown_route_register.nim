## Regression: ``crownRouteRegister`` must splice route bodies so ``c`` / ``p`` resolve
## after ``{.async.}`` on Basolato 0.15 (Nim 2.2). Template + ``body: untyped`` breaks.
import ./crown_test_env
discard crownTestsEnvReady
import std/unittest

import std/asyncdispatch
import crown/core as crown
import basolato/controller except html
import ./fixtures/crown_route_page as fixture_page

proc page(req: crown.Request): crown.Response =
  discard req
  htmlResponse("ok")

proc layout(content: string): string =
  "<main>" & content & "</main>"

let generatedShapeRoute = crownRouteRegister("get", "/__crown_generated_shape_test"):
  var res: crown.Response
  let req = crown.Request(context: c, params: p)
  res = page(req)
  var contentType = ""
  if res.headers.hasKey("Content-Type"):
    contentType = $res.headers["Content-Type"]
  elif res.headers.hasKey("content-type"):
    contentType = $res.headers["content-type"]
  let isLayoutEnabled = true and not res.headers.hasKey("Crown-Disable-Layout")
  if contentType.contains("text/html") and isLayoutEnabled:
    var htmlContent = res.body()
    htmlContent = layout(htmlContent)
    htmlContent = injectCrownSystem(htmlContent)
    res = htmlResponse(htmlContent, res.status)
  return res

let importedGeneratedShapeRoute = crownRouteRegister("get", "/__crown_imported_generated_shape_test"):
  var res: crown.Response
  let req = crown.Request(context: c, params: p)
  when compiles(fixture_page.page(req, "")):
    when type(fixture_page.page(req, "")) is string:
      res = htmlResponse(fixture_page.page(req, ""))
    elif type(fixture_page.page(req, "")) is Html:
      res = htmlResponse($fixture_page.page(req, ""))
    elif type(fixture_page.page(req, "")) is Future[Html]:
      res = htmlResponse($(await fixture_page.page(req, "")))
    elif type(fixture_page.page(req, "")) is crown.Response:
      res = fixture_page.page(req, "")
    else:
      res = await fixture_page.page(req, "")
  elif compiles(fixture_page.page(req)):
    when type(fixture_page.page(req)) is string:
      res = htmlResponse(fixture_page.page(req))
    elif type(fixture_page.page(req)) is Html:
      res = htmlResponse($fixture_page.page(req))
    elif type(fixture_page.page(req)) is Future[Html]:
      res = htmlResponse($(await fixture_page.page(req)))
    elif type(fixture_page.page(req)) is crown.Response:
      res = fixture_page.page(req)
    else:
      res = await fixture_page.page(req)
  else:
    when type(fixture_page.page(c, p)) is string:
      res = htmlResponse(fixture_page.page(c, p))
    elif type(fixture_page.page(c, p)) is Html:
      res = htmlResponse($fixture_page.page(c, p))
    elif type(fixture_page.page(c, p)) is Future[Html]:
      res = htmlResponse($(await fixture_page.page(c, p)))
    elif type(fixture_page.page(c, p)) is crown.Response:
      res = fixture_page.page(c, p)
    else:
      res = await fixture_page.page(c, p)
  var contentType = ""
  if res.headers.hasKey("Content-Type"):
    contentType = $res.headers["Content-Type"]
  elif res.headers.hasKey("content-type"):
    contentType = $res.headers["content-type"]
  let isLayoutEnabled = true and not res.headers.hasKey("Crown-Disable-Layout")
  if contentType.contains("text/html") and isLayoutEnabled:
    var htmlContent = res.body()
    when compiles(fixture_page.layout(htmlContent)):
      htmlContent = fixture_page.layout(htmlContent)
    htmlContent = injectCrownSystem(htmlContent)
    res = htmlResponse(htmlContent, res.status)
  return res

suite "crownRouteRegister macro":
  test "route body binds c and p (0.15 two-arg controller)":
    let r = crownRouteRegister("get", "/__crown_macro_test"):
      var res: crown.Response
      let req = crown.Request(context: c, params: p)
      res = htmlResponse("ok")
      discard req
      return res
    check r != nil

  test "top-level route body accepts generated page and layout calls":
    check generatedShapeRoute != nil

  test "top-level route body accepts imported generated page and layout calls":
    check importedGeneratedShapeRoute != nil

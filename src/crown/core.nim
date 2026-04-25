import std/macros
import std/hashes
import std/strformat
import std/[httpcore, asyncdispatch, json, os, strutils]
when not (defined(httpbeast) or defined(httpx)):
  import std/asyncnet

import basolato/controller as baco except html
import basolato/core/response as basolatoResponse
import basolato/core/templates

export strformat, httpcore, asyncdispatch, json, os, strutils

type
  Context* = baco.Context
  Params* = baco.Params
  Response* = baco.Response
  ## Aliases for ``crownRouteRegister`` expansion: the template is instantiated in the caller’s scope,
  ## where ``Context`` / ``Response`` may be ambiguous (e.g. ``core.*`` vs Basolato’s ``context`` / ``response``).
  BasolatoContext* = baco.Context
  BasolatoParams* = baco.Params
  BasolatoHttpResponse* = baco.Response
  Request* = ref object
    context*: Context
    params*: Params

proc getStr*(r: Request, key: string): string = r.params.getStr(key)
proc getOrDefault*(r: Params, key: string, default: string): string = r.getStr(
    key, default)

template crownRouteRegister*(httpMethod: static string, path: static string, body: untyped): untyped {.dirty.} =
  ## Basolato 0.16: ``Controller`` is ``proc(c: Context): Future[Response]`` with ``Context.params``.
  ## Basolato 0.15: ``proc(c: Context, p: Params): Future[Response]``.
  ##
  ## First argument: ``"get"``, ``"post"``, ``"put"``, ``"patch"``, or ``"delete"``. Branches call
  ## ``Route.get`` / ``Route.post`` / … explicitly (avoids unrelated ``get`` overloads).
  ##
  ## ``{.dirty.}`` + ``import crown/core`` before Basolato (see generator) keeps ``c`` / ``p`` bound
  ## after ``{.async.}`` on Nim 2.2 + Basolato 0.15.
  ##
  ## ``when compiles`` uses ``BasolatoContext`` (exported from this module) so expansion sites never
  ## pick Basolato’s ``context.Context`` by mistake.
  when httpMethod == "get":
    when compiles((var c: BasolatoContext; discard c.params())):
      Route.get(path, proc(c: BasolatoContext): Future[BasolatoHttpResponse] {.async, closure.} =
        let p = c.params()
        body
      )
    else:
      Route.get(path, proc(c: BasolatoContext, p: BasolatoParams): Future[BasolatoHttpResponse] {.async, closure.} =
        body
      )
  elif httpMethod == "post":
    when compiles((var c: BasolatoContext; discard c.params())):
      Route.post(path, proc(c: BasolatoContext): Future[BasolatoHttpResponse] {.async, closure.} =
        let p = c.params()
        body
      )
    else:
      Route.post(path, proc(c: BasolatoContext, p: BasolatoParams): Future[BasolatoHttpResponse] {.async, closure.} =
        body
      )
  elif httpMethod == "put":
    when compiles((var c: BasolatoContext; discard c.params())):
      Route.put(path, proc(c: BasolatoContext): Future[BasolatoHttpResponse] {.async, closure.} =
        let p = c.params()
        body
      )
    else:
      Route.put(path, proc(c: BasolatoContext, p: BasolatoParams): Future[BasolatoHttpResponse] {.async, closure.} =
        body
      )
  elif httpMethod == "patch":
    when compiles((var c: BasolatoContext; discard c.params())):
      Route.patch(path, proc(c: BasolatoContext): Future[BasolatoHttpResponse] {.async, closure.} =
        let p = c.params()
        body
      )
    else:
      Route.patch(path, proc(c: BasolatoContext, p: BasolatoParams): Future[BasolatoHttpResponse] {.async, closure.} =
        body
      )
  elif httpMethod == "delete":
    when compiles((var c: BasolatoContext; discard c.params())):
      Route.delete(path, proc(c: BasolatoContext): Future[BasolatoHttpResponse] {.async, closure.} =
        let p = c.params()
        body
      )
    else:
      Route.delete(path, proc(c: BasolatoContext, p: BasolatoParams): Future[BasolatoHttpResponse] {.async, closure.} =
        body
      )
  else:
    {.error: "crownRouteRegister: unsupported httpMethod (use get, post, put, patch, delete)".}

# Expose `postParams` and `queryParams` behavior since they're just params in Basolato
proc postParams*(r: Request): Params = r.params
proc queryParams*(r: Request): Params = r.params

proc clientIp*(r: Request): string =
  ## Client address: ``X-Forwarded-For`` (first hop), ``X-Real-IP``, then peer.
  ## On httpbeast/httpx, ``request.hostname`` holds Basolato’s client address (not ``AsyncSocket``).
  let req = r.context.request
  if not req.headers.isNil:
    let xff = req.headers.getOrDefault("X-Forwarded-For").strip()
    if xff.len > 0:
      let first = xff.split(',', 1)[0].strip()
      if first.len > 0:
        return first
    let xri = req.headers.getOrDefault("X-Real-IP").strip()
    if xri.len > 0:
      return xri
  when defined(httpbeast) or defined(httpx):
    let h = req.hostname.strip()
    if h.len > 0:
      return h
  else:
    try:
      if not req.client.isNil:
        let (host, _) = getPeerAddr(req.client)
        if host.len > 0:
          return host
    except OSError:
      discard
  return ""

# Procedures manually exported
export baco.newHttpHeaders
export baco.getStr
export basolatoResponse.body
import tiara
export tiara.Html
when declared(templates.tmpli):
  export templates.tmpli

type Layout* = string

const clientJsPath = currentSourcePath().parentDir() / "client.js"
const clientNimPath = currentSourcePath().parentDir() / "client.nim"
const buildCmd = "nim js -d:release --hints:off -o:" & clientJsPath & " " & clientNimPath
const _ {.used.} = staticExec(buildCmd)
const clientJsCode = staticRead("client.js")

const crownClientJs = """
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
<style>
  :root { --font-sans: 'Inter', system-ui, -apple-system, sans-serif; }
  body { font-family: var(--font-sans); }
  .crown-loading { opacity: 0.5; pointer-events: none; transition: opacity 0.2s; }
</style>
<script>
""" & clientJsCode & "\n</script>\n"

proc getCrownConfig(): JsonNode =
  result = %*{"tailwind": true, "pwa": false}
  if fileExists("crown.json"):
    try:
      let j = parseFile("crown.json")
      if j.hasKey("tailwind"):
        result["tailwind"] = j["tailwind"]
      if j.hasKey("pwa"):
        result["pwa"] = j["pwa"]
    except:
      discard

proc injectCrownSystem*(content: string): string =
  ## Injects Crown system scripts and Tailwind CSS into the HTML content.
  var injectStr = crownClientJs
  let config = getCrownConfig()
  if config["tailwind"].getBool(true):
    injectStr &= "<script src=\"https://cdn.tailwindcss.com\"></script>\n"

  if config["pwa"].getBool(false):
    injectStr &= "<link rel=\"manifest\" href=\"/manifest.json\">\n"
    injectStr &= "<script>\n"
    injectStr &= "  if ('serviceWorker' in navigator) {\n"
    injectStr &= "    window.addEventListener('load', () => {\n"
    injectStr &= "      navigator.serviceWorker.register('/sw.js').then(reg => {\n"
    injectStr &= "        const syncIfOnline = () => {\n"
    injectStr &= "          if ('sync' in reg) { reg.sync.register('crown-sync').catch(() => {}); }\n"
    injectStr &= "          else if (navigator.serviceWorker.controller) { navigator.serviceWorker.controller.postMessage({type: 'FLUSH_QUEUE'}); }\n"
    injectStr &= "        };\n"
    injectStr &= "        window.addEventListener('online', syncIfOnline);\n"
    injectStr &= "      });\n"
    injectStr &= "    });\n"
    injectStr &= "  }\n"
    injectStr &= "</script>\n"
  else:
    injectStr &= "<script>\n"
    injectStr &= "  if ('serviceWorker' in navigator) {\n"
    injectStr &= "    navigator.serviceWorker.getRegistrations().then(function(registrations) {\n"
    injectStr &= "      for(let registration of registrations) { registration.unregister(); }\n"
    injectStr &= "    });\n"
    injectStr &= "  }\n"
    injectStr &= "</script>\n"

  let lowerContent = content.toLowerAscii()
  let headIdx = lowerContent.find("</head>")

  if headIdx != -1:
    result = content[0 ..< headIdx] & injectStr & content[headIdx .. ^1]
  elif lowerContent.find("<body>") != -1:
    let bodyIdx = lowerContent.find("<body>")
    result = content[0 .. bodyIdx+5] & injectStr & content[bodyIdx+6 .. ^1]
  else:
    # If it's a snippet, we still want the system available if it's the final output
    result = injectStr & content

proc htmlResponse*(content: string, status = Http200): Response =
  var headers = newHttpHeaders()
  headers["Content-Type"] = "text/html; charset=utf-8"
  return Response.new(status, content, headers)

proc jsonResponse*(data: JsonNode, status = Http200): Response =
  var headers = newHttpHeaders()
  headers["Content-Type"] = "application/json; charset=utf-8"
  return Response.new(status, $data, headers)

proc disableLayout*(res: var Response): var Response =
  ## Explicitly disables the layout injection for this response.
  res.headers["Crown-Disable-Layout"] = "true"
  return res

proc disableLayout*(res: Response): Response =
  ## Explicitly disables the layout injection for this response.
  var clonedHeaders = res.headers
  clonedHeaders["Crown-Disable-Layout"] = "true"
  return Response.new(res.status, res.body(), clonedHeaders)

proc crownToString*[T](value: T): string {.inline.} =
  $value

proc crownToString*(value: string): string {.inline.} =
  value

proc crownIsCssIdentChar(ch: char): bool {.inline.} =
  (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or
      (ch >= '0' and ch <= '9') or ch in {'_', '-'}

proc crownScopeCss*(cssBody, scopedClass: string): string =
  ## Replaces `.self` selector with component-scoped class names.
  result = newStringOfCap(cssBody.len + 32)
  var i = 0
  while i < cssBody.len:
    if cssBody[i] == '.' and i + 4 < cssBody.len and cssBody[i + 1 .. i + 4] == "self":
      let nextIdx = i + 5
      if nextIdx >= cssBody.len or not crownIsCssIdentChar(cssBody[nextIdx]):
        result.add('.')
        result.add(scopedClass)
        i = nextIdx
        continue
    result.add(cssBody[i])
    inc i

proc crownScopeClassTokens*(classes, scopedClass: string): string =
  let tokens = classes.splitWhitespace()
  if tokens.len == 0:
    return classes

  var replaced = newSeq[string](tokens.len)
  for i, token in tokens.pairs:
    replaced[i] = if token == "self": scopedClass else: token
  result = replaced.join(" ")

proc crownScopeClass*[T](value: T, scopedClass: string): string =
  crownScopeClassTokens(crownToString(value), scopedClass)

proc crownScopeHtmlClasses*(htmlBody, scopedClass: string): string =
  ## Replaces only `self` token inside HTML class attributes.
  result = newStringOfCap(htmlBody.len + 32)
  var i = 0
  while i < htmlBody.len:
    if i + 4 < htmlBody.len and htmlBody[i .. i + 4].toLowerAscii() == "class":
      var j = i + 5
      while j < htmlBody.len and htmlBody[j].isSpaceAscii():
        inc j
      if j < htmlBody.len and htmlBody[j] == '=':
        inc j
        while j < htmlBody.len and htmlBody[j].isSpaceAscii():
          inc j
        if j < htmlBody.len and htmlBody[j] in {'"', '\''}:
          let quote = htmlBody[j]
          inc j
          let valueStart = j
          while j < htmlBody.len and htmlBody[j] != quote:
            inc j
          if j < htmlBody.len:
            let classValue = htmlBody[valueStart ..< j]
            result.add("class=")
            result.add(quote)
            result.add(crownScopeClassTokens(classValue, scopedClass))
            result.add(quote)
            i = j + 1
            continue
    result.add(htmlBody[i])
    inc i

const crownHtmlTags = [
  "a", "abbr", "address", "article", "aside", "audio", "b", "bdi", "bdo", "blockquote",
  "body", "button", "canvas", "caption", "cite", "code", "data", "datalist", "dd", "del",
  "details", "dfn", "dialog", "div", "dl", "dt", "em", "fieldset", "figcaption", "figure",
  "footer", "form", "h1", "h2", "h3", "h4", "h5", "h6", "head", "header", "hgroup", "html",
  "i", "iframe", "ins", "kbd", "label", "legend", "li", "main", "map", "mark", "menu", "meter",
  "nav", "noscript", "object", "ol", "optgroup", "option", "output", "p", "picture", "pre",
  "progress", "q", "rp", "rt", "ruby", "s", "samp", "script", "search", "section", "select",
  "slot", "small", "span", "strong", "style", "sub", "summary", "sup", "table", "tbody", "td",
  "template", "textarea", "tfoot", "th", "thead", "time", "title", "tr", "u", "ul", "var",
  "video", "svg", "g", "path", "circle", "rect", "line", "polyline", "polygon", "text", "defs",
  "use", "symbol", "lineargradient", "radialgradient", "stop", "clippath", "mask", "foreignobject",
  "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source",
  "track", "wbr"
]

const crownVoidHtmlTags = [
  "area", "base", "br", "col", "embed", "hr", "img", "input",
  "link", "meta", "param", "source", "track", "wbr"
]

proc crownConcatExpr(parts: seq[NimNode]): NimNode {.compiletime.} =
  if parts.len == 0:
    return newLit("")

  result = parts[0]
  for i in 1 ..< parts.len:
    result = newCall(ident("&"), result, parts[i])

proc crownContainsTag(tags: openArray[string], target: string): bool {.compiletime.} =
  for tag in tags:
    if tag == target:
      return true
  false

proc crownIsHtmlTag(name: string): bool {.compiletime.} =
  let normalized = name.toLowerAscii()
  crownContainsTag(crownHtmlTags, normalized) or normalized.contains('-')

proc crownIsVoidHtmlTag(name: string): bool {.compiletime.} =
  crownContainsTag(crownVoidHtmlTags, name.toLowerAscii())

proc crownNodeName(node: NimNode): string {.compiletime.} =
  case node.kind
  of nnkIdent, nnkSym:
    node.strVal
  of nnkPostfix:
    if node.len < 2:
      error("Invalid postfix identifier in component DSL", node)
    crownNodeName(node[1])
  of nnkAccQuoted:
    if node.len == 0:
      error("Invalid quoted identifier for component DSL", node)
    crownNodeName(node[0])
  else:
    error("Expected identifier in component DSL, got: " & $node.kind, node)

proc crownRenderHtmlNode(node: NimNode, scopedClass: string): NimNode {.compiletime.}

proc crownIsRawHtmlTemplateSection(section: NimNode): bool {.compiletime.} =
  var target = section
  if section.kind == nnkStmtList:
    if section.len != 1:
      return false
    target = section[0]
  target.kind in {nnkStrLit, nnkTripleStrLit}

proc crownNormalizePhpDirective(code: string): string {.compiletime.} =
  var directive = code.strip()
  if directive.len == 0:
    return directive
  let lower = directive.toLowerAscii()
  if lower == "else":
    return "else:"

  if (lower.startsWith("if ") or lower.startsWith("elif ") or
      lower.startsWith("for ") or lower.startsWith("while ") or
      lower.startsWith("when ") or lower.startsWith("of ")) and not directive.endsWith(":"):
    directive.add(':')
  directive

proc crownFindNextDirectiveOpen(templateBody: string, startPos: int): tuple[idx: int, closeToken: string] {.compiletime.} =
  result.idx = -1
  result.closeToken = ""

  let angleIdx = templateBody.find("<?", startPos)
  let braceIdx = templateBody.find("{?", startPos)

  if angleIdx >= 0 and (result.idx < 0 or angleIdx < result.idx):
    result.idx = angleIdx
    result.closeToken = "?>"

  if braceIdx >= 0 and (result.idx < 0 or braceIdx < result.idx):
    result.idx = braceIdx
    result.closeToken = "?}"

proc crownRenderPhpLikeTemplate(templateBody, scopedClass: string): NimNode {.compiletime.} =
  let outVar = "crownTplOut"
  var generated = "block:\n"
  generated.add("  var " & outVar & " = \"\"\n")
  var indent = 1

  proc emitLine(line: string) {.compiletime.} =
    generated.add(repeat("  ", indent))
    generated.add(line)
    generated.add('\n')

  proc emitLiteral(chunk: string) {.compiletime.} =
    if chunk.len == 0:
      return
    emitLine(outVar & ".add(fmt(" & newLit(chunk).repr & "))")

  var pos = 0
  while pos < templateBody.len:
    let nextOpen = crownFindNextDirectiveOpen(templateBody, pos)
    let openIdx = nextOpen.idx
    if openIdx < 0:
      emitLiteral(templateBody[pos .. ^1])
      break

    emitLiteral(templateBody[pos ..< openIdx])
    let closeIdx = templateBody.find(nextOpen.closeToken, openIdx + 2)
    if closeIdx < 0:
      error("Unclosed directive in raw html template")

    let rawDirective = templateBody[openIdx + 2 ..< closeIdx].strip()
    if rawDirective.len > 0:
      if rawDirective.startsWith("="):
        let expr = rawDirective[1 .. ^1].strip()
        if expr.len == 0:
          error("`<?= ... ?>` requires an expression")
        emitLine(outVar & ".add(crownToString(" & expr & "))")
      else:
        let lower = rawDirective.toLowerAscii()
        if lower in ["end", "endif", "endfor", "endwhile", "endwhen", "endcase"]:
          if indent <= 1:
            error("Unexpected template end directive: " & rawDirective)
          dec indent
        else:
          var directive = crownNormalizePhpDirective(rawDirective)
          let normalizedLower = directive.toLowerAscii()
          if normalizedLower.startsWith("elif ") or
              normalizedLower == "else:" or
              normalizedLower.startsWith("of "):
            if indent <= 1:
              error("Unexpected branch directive: " & directive)
            dec indent

          emitLine(directive)
          if directive.endsWith(":"):
            inc indent

    pos = closeIdx + nextOpen.closeToken.len

  if indent != 1:
    error("Unclosed control directive in raw html template. Use `<? end ?>` / `<? endif ?>` / `<? endfor ?>`.")

  emitLine("crownScopeHtmlClasses(" & outVar & ", " & newLit(scopedClass).repr & ")")
  parseExpr(generated)

proc crownRenderRawHtmlSection(section: NimNode, scopedClass: string): NimNode {.compiletime.} =
  var htmlExpr = section
  if section.kind == nnkStmtList:
    htmlExpr = section[0]
  if htmlExpr.kind in {nnkStrLit, nnkTripleStrLit} and
      (htmlExpr.strVal.contains("<?") or htmlExpr.strVal.contains("{?")):
    return crownRenderPhpLikeTemplate(htmlExpr.strVal, scopedClass)
  newCall(
    bindSym("crownScopeHtmlClasses"),
    newCall(bindSym("fmt"), htmlExpr),
    newLit(scopedClass)
  )

proc crownRenderOutputBlock(flowStmt: NimNode, scopedClass: string): NimNode {.compiletime.} =
  let outSym = genSym(nskVar, "crownOut")
  var body = newStmtList()
  body.add(newVarStmt(outSym, newLit("")))

  var renderedFlow = copyNimTree(flowStmt)
  case renderedFlow.kind
  of nnkIfStmt, nnkWhenStmt:
    for i in 0 ..< renderedFlow.len:
      let branch = renderedFlow[i]
      case branch.kind
      of nnkElifBranch:
        renderedFlow[i][1] = newStmtList(newCall(
          bindSym("add"),
          outSym,
          crownRenderHtmlNode(branch[1], scopedClass)
        ))
      of nnkElse:
        renderedFlow[i][0] = newStmtList(newCall(
          bindSym("add"),
          outSym,
          crownRenderHtmlNode(branch[0], scopedClass)
        ))
      else:
        error("Unsupported branch kind in control flow", branch)
  of nnkForStmt, nnkWhileStmt:
    renderedFlow[^1] = newStmtList(newCall(
      bindSym("add"),
      outSym,
      crownRenderHtmlNode(renderedFlow[^1], scopedClass)
    ))
  of nnkCaseStmt:
    for i in 1 ..< renderedFlow.len:
      let branch = renderedFlow[i]
      case branch.kind
      of nnkOfBranch:
        renderedFlow[i][^1] = newStmtList(newCall(
          bindSym("add"),
          outSym,
          crownRenderHtmlNode(branch[^1], scopedClass)
        ))
      of nnkElse:
        renderedFlow[i][0] = newStmtList(newCall(
          bindSym("add"),
          outSym,
          crownRenderHtmlNode(branch[0], scopedClass)
        ))
      else:
        error("Unsupported case branch kind", branch)
  else:
    error("Unsupported flow statement: " & $renderedFlow.kind, renderedFlow)

  body.add(renderedFlow)
  body.add(outSym)
  nnkBlockStmt.newTree(newEmptyNode(), body)

proc crownRenderChildren(node: NimNode, scopedClass: string): NimNode {.compiletime.} =
  if node.kind != nnkStmtList:
    return crownRenderHtmlNode(node, scopedClass)

  var rendered: seq[NimNode] = @[]
  for child in node:
    rendered.add(crownRenderHtmlNode(child, scopedClass))
  crownConcatExpr(rendered)

proc crownRenderHtmlNode(node: NimNode, scopedClass: string): NimNode {.compiletime.} =
  case node.kind
  of nnkStmtList:
    return crownRenderChildren(node, scopedClass)
  of nnkIfStmt, nnkWhenStmt, nnkForStmt, nnkWhileStmt, nnkCaseStmt:
    return crownRenderOutputBlock(node, scopedClass)
  of nnkLetSection, nnkVarSection, nnkConstSection, nnkAsgn, nnkFastAsgn,
      nnkDiscardStmt:
    return nnkBlockStmt.newTree(newEmptyNode(), newStmtList(copyNimTree(node), newLit("")))
  of nnkCall, nnkCommand:
    let head = crownNodeName(node[0])
    if head == "text":
      if node.len != 2:
        error("`text` expects exactly one argument", node)
      return newCall(
        bindSym("escapeHtml"),
        newCall(bindSym("crownToString"), node[1])
      )
    if head == "raw":
      if node.len != 2:
        error("`raw` expects exactly one argument", node)
      return newCall(bindSym("crownToString"), node[1])

    if not crownIsHtmlTag(head):
      # Unknown calls are treated as nested component/function rendering.
      return newCall(bindSym("crownToString"), node)

    let isVoidTag = crownIsVoidHtmlTag(head)
    var parts: seq[NimNode] = @[newLit("<" & head)]
    var children: NimNode = newEmptyNode()
    for i in 1 ..< node.len:
      let part = node[i]
      if part.kind == nnkExprEqExpr:
        let attrName = crownNodeName(part[0])
        var attrValueExpr: NimNode
        if attrName == "class":
          attrValueExpr = newCall(bindSym("crownScopeClass"), part[1], newLit(scopedClass))
        else:
          attrValueExpr = newCall(bindSym("crownToString"), part[1])

        parts.add(newLit(" " & attrName & "=\""))
        parts.add(newCall(bindSym("escapeHtml"), attrValueExpr))
        parts.add(newLit("\""))
      elif part.kind == nnkStmtList:
        children = part
      else:
        # Bare expressions inside a tag become escaped text content.
        if children.kind == nnkEmpty:
          children = newStmtList()
        children.add(newCall(ident("text"), part))

    if isVoidTag:
      if children.kind != nnkEmpty and children.len > 0:
        error("Void HTML tags cannot have children: " & head, node)
      parts.add(newLit(" />"))
      return crownConcatExpr(parts)

    parts.add(newLit(">"))
    if children.kind != nnkEmpty:
      parts.add(crownRenderChildren(children, scopedClass))
    parts.add(newLit("</" & head & ">"))
    return crownConcatExpr(parts)
  else:
    # Non-call nodes are treated as escaped text.
    return newCall(
      bindSym("escapeHtml"),
      newCall(bindSym("crownToString"), node)
    )

proc crownParseComponentSignature(signature: NimNode): tuple[name: NimNode, params: NimNode] {.compiletime.} =
  result.params = newNimNode(nnkFormalParams)
  result.params.add(ident("string"))

  case signature.kind
  of nnkIdent, nnkSym:
    result.name = signature
  of nnkObjConstr:
    if signature.len == 0:
      error("Component name is missing", signature)
    result.name = signature[0]
    for i in 1 ..< signature.len:
      let part = signature[i]
      if part.kind != nnkExprColonExpr:
        error("Component parameters must be `name: Type`", part)
      result.params.add(newIdentDefs(part[0], part[1], newEmptyNode()))
  else:
    error("Invalid component declaration. Use `component myButton(label: string):`", signature)

proc crownGetSection(body: NimNode, section: string): NimNode {.compiletime.} =
  result = newEmptyNode()
  if body.kind != nnkStmtList:
    error("Component body must be a statement list", body)

  for stmt in body:
    if stmt.kind in {nnkCall, nnkCommand} and stmt.len >= 2:
      let head = crownNodeName(stmt[0])
      if head == section:
        return stmt[1]

macro component*(signature: untyped, body: untyped): untyped =
  ## Declares a component with scoped css/html sections.
  ## Example:
  ## component myButton(label: string):
  ##   css: """.self { ... }"""
  ##   html:
  ##     button(class="self"):
  ##       text label
  let parsed = crownParseComponentSignature(signature)
  let info = signature.lineInfoObj()
  let scopedSeed = info.filename & ":" & $info.line & ":" & crownNodeName(parsed.name)
  let scopedClass = "crown-scope-" & toHex(cast[uint32](hash(scopedSeed)), 8).toLowerAscii()

  let htmlSection = crownGetSection(body, "html")
  if htmlSection.kind == nnkEmpty:
    error("`component` requires an `html:` section", body)
  let renderedHtml = if crownIsRawHtmlTemplateSection(htmlSection):
      crownRenderRawHtmlSection(htmlSection, scopedClass)
    else:
      crownRenderChildren(htmlSection, scopedClass)

  var outputExpr = renderedHtml
  let cssSection = crownGetSection(body, "css")
  if cssSection.kind != nnkEmpty:
    var cssExpr = cssSection
    if cssSection.kind == nnkStmtList:
      if cssSection.len != 1:
        error("`css:` section must have exactly one expression", cssSection)
      cssExpr = cssSection[0]
    outputExpr = crownConcatExpr(@[
      newLit("<style>"),
      newCall(bindSym("crownScopeCss"),
        newCall(bindSym("crownToString"), cssExpr),
        newLit(scopedClass)),
      newLit("</style>"),
      renderedHtml
    ])

  var procParams: seq[NimNode] = @[]
  for part in parsed.params:
    procParams.add(part)

  result = newProc(
    name = parsed.name,
    params = procParams,
    body = newStmtList(newAssignment(ident("result"), outputExpr))
  )

template html*(s: untyped): string =
  ## Combines string interpolation.
  ## Named `html` to trigger HTML syntax highlighting in editors.
  fmt(s)

template component*(s: untyped): string =
  ## An optional sugar alias for `html`.
  ## Use this if you want naming clarity for reusable UI pieces.
  fmt(s)

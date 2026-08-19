## Typed href helpers generated from ``.crown/manifest.json`` (TanStack Router-style).
import std/[macros, os, json, strutils, uri, options]

proc hrefIdent*(urlPath: string): string =
  ## ``/users/{id:int}`` → ``hrefUsers``; ``/`` → ``hrefIndex``.
  var parts: seq[string]
  for part in urlPath.split('/'):
    if part.len == 0:
      continue
    if part.startsWith("{") and part.endsWith("}"):
      continue
    var token = newStringOfCap(part.len)
    for ch in part:
      if ch.isAlphaNumeric:
        token.add(ch)
    if token.len == 0:
      continue
    token[0] = token[0].toUpperAscii
    parts.add(token)
  if parts.len == 0:
    return "hrefIndex"
  result = "href"
  for part in parts:
    result.add(part)

proc crownNimTypeForRouteParam*(typ: string): string =
  case typ
  of "int": "int"
  of "float": "float"
  of "bool": "bool"
  else: "string"

proc encodeQueryPairs*(pairs: openArray[(string, string)]): string =
  var encoded: seq[string]
  for (key, val) in pairs:
    encoded.add(encodeUrl(key) & "=" & encodeUrl(val))
  encoded.join("&")

proc queryPairsFromObject*[T](query: T): seq[(string, string)] =
  for fieldName, val in fieldPairs(query):
    when val is Option[string]:
      if val.isSome:
        result.add((fieldName, val.get))
    elif val is Option[int]:
      if val.isSome:
        result.add((fieldName, $val.get))
    elif val is Option[float]:
      if val.isSome:
        result.add((fieldName, $val.get))
    elif val is Option[bool]:
      if val.isSome:
        result.add((fieldName, $val.get))
    elif val is enum:
      result.add((fieldName, $val))
    elif val is string:
      result.add((fieldName, val))
    else:
      result.add((fieldName, $val))

proc withQuery*[T](path: string, query: T): string =
  ## Append object fields as a query string. ``Option`` fields omit ``none``.
  let pairs = queryPairsFromObject(query)
  if pairs.len == 0:
    return path
  let sep = if '?' in path: "&" else: "?"
  path & sep & encodeQueryPairs(pairs)

proc href*(path: string): string {.inline.} =
  path

proc href*[T](path: string, query: T): string {.inline.} =
  withQuery(path, query)

proc crownParamTypeIdent(typ: string): NimNode {.compileTime.} =
  ident(crownNimTypeForRouteParam(typ))

proc crownUniqueHrefName(base: string, used: var seq[string]): string {.compileTime.} =
  result = base
  var n = 2
  while result in used:
    result = base & $n
    inc n
  used.add(result)

macro crownEmitTypedHrefs*(): untyped =
  ## Emit ``hrefX*(...)`` procs from the project route manifest when present.
  result = newStmtList()
  let cwd = gorge("pwd").strip()
  let manifestFile = cwd / ".crown" / "manifest.json"
  if not fileExists(manifestFile):
    return
  var parsed: JsonNode
  try:
    parsed = parseJson(readFile(manifestFile))
  except CatchableError:
    return
  if parsed.kind != JObject or not parsed.hasKey("routes"):
    return

  var used: seq[string] = @[]
  for route in parsed["routes"]:
    if route.kind != JObject:
      continue
    let path = route{"path"}.getStr()
    if path.len == 0:
      continue
    var params: seq[tuple[name, typ: string]] = @[]
    if route.hasKey("params") and route["params"].kind == JArray:
      for p in route["params"]:
        params.add((p{"name"}.getStr(), p{"type"}.getStr("str")))

    let procName = ident(crownUniqueHrefName(hrefIdent(path), used))
    var formal = newNimNode(nnkFormalParams)
    formal.add(ident("string"))
    for p in params:
      let nimTyp = if p.name.len == 0: "string" else: p.typ
      formal.add(newIdentDefs(ident(p.name), crownParamTypeIdent(nimTyp), newEmptyNode()))

    var bodyParts: seq[NimNode] = @[]
    var literal = ""
    proc flushLiteral() {.compileTime.} =
      if literal.len > 0:
        bodyParts.add(newLit(literal))
        literal = ""

    if path == "/":
      bodyParts.add(newLit("/"))
    else:
      for part in path.split('/'):
        if part.len == 0:
          continue
        literal.add("/")
        if part.startsWith("{") and part.endsWith("}"):
          let inside = part[1 .. ^2]
          let name = inside.split(":")[0]
          flushLiteral()
          bodyParts.add(newCall(ident("$"), ident(name)))
        else:
          literal.add(part)
      flushLiteral()
      if bodyParts.len == 0:
        bodyParts.add(newLit("/"))

    var concat = bodyParts[0]
    for i in 1 ..< bodyParts.len:
      concat = infix(concat, "&", bodyParts[i])

    var built = newNimNode(nnkProcDef)
    built.add(postfix(procName, "*"))
    built.add(newEmptyNode())
    built.add(newEmptyNode())
    built.add(formal)
    built.add(newEmptyNode())
    built.add(newEmptyNode())
    built.add(newStmtList(newAssignment(ident("result"), concat)))
    result.add(built)

crownEmitTypedHrefs()

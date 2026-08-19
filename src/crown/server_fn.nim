## Transparent server functions (TanStack Start ``createServerFn`` analogue).
##
## Native build: real proc + JSON invoker ``crownServerFn_<name>``.
## Client JS can call ``window.crownServerFn(name, payload)``.
import std/[macros, json, jsonutils, strutils]

export jsonutils

proc crownFnProcName(n: NimNode): string {.compileTime.} =
  case n.kind
  of nnkIdent, nnkSym:
    result = n.strVal
  of nnkPostfix:
    result = crownFnProcName(n[1])
  of nnkAccQuoted:
    result = crownFnProcName(n[0])
  else:
    error("serverFn: expected proc name", n)

proc crownJsonToCall(node, typ: NimNode): NimNode {.compileTime.} =
  ## ``jsonTo(node, T)`` (std/jsonutils).
  newCall(ident("jsonTo"), node, copyNimTree(typ))

proc crownFnExpand(procDef: NimNode): NimNode {.compileTime.} =
  if procDef.kind != nnkProcDef:
    error("serverFn expects a proc definition", procDef)

  let origName = crownFnProcName(procDef[0])
  let invokerName = ident("crownServerFn_" & origName)
  let params = procDef[3]

  var argLets = newStmtList()
  var callArgs: seq[NimNode] = @[]
  let payloadSym = ident("payload")
  for i in 1 ..< params.len:
    let identDef = params[i]
    let typ = identDef[identDef.len - 2]
    for j in 0 ..< identDef.len - 2:
      let pname = identDef[j]
      if pname.kind == nnkEmpty:
        continue
      let key = crownFnProcName(pname)
      let argIdent = ident(key)
      argLets.add(newLetStmt(
        argIdent,
        crownJsonToCall(
          newCall(ident("{}"), payloadSym, newLit(key)),
          typ
        )
      ))
      callArgs.add(argIdent)

  var call = newCall(ident(origName))
  for a in callArgs:
    call.add(a)

  var invokeBody = newStmtList()
  invokeBody.add(argLets)
  let awaitCall = newCall(ident("await"), copyNimTree(call))
  invokeBody.add(nnkWhenStmt.newTree(
    nnkElifBranch.newTree(
      newCall(ident("compiles"), awaitCall),
      nnkReturnStmt.newTree(newCall(ident("toJson"), awaitCall))
    ),
    nnkElse.newTree(
      nnkReturnStmt.newTree(newCall(ident("toJson"), call))
    )
  ))

  var formal = newNimNode(nnkFormalParams)
  formal.add(nnkBracketExpr.newTree(ident("Future"), ident("JsonNode")))
  formal.add(newIdentDefs(payloadSym, ident("JsonNode"), newEmptyNode()))

  var invoker = newNimNode(nnkProcDef)
  invoker.add(postfix(invokerName, "*"))
  invoker.add(newEmptyNode())
  invoker.add(newEmptyNode())
  invoker.add(formal)
  invoker.add(nnkPragma.newTree(ident("async")))
  invoker.add(newEmptyNode())
  invoker.add(invokeBody)

  result = newStmtList(copyNimTree(procDef), invoker)

macro serverFn*(n: untyped): untyped =
  ## Wrap a server-only proc and generate ``crownServerFn_<name>`` for the router.
  ##
  ## ```nim
  ## serverFn:
  ##   proc updateUser*(id: string, name: string): User =
  ##     User(id: id, name: name)
  ## ```
  if n.kind == nnkStmtList:
    result = newStmtList()
    for child in n:
      if child.kind == nnkProcDef:
        result.add(crownFnExpand(child))
      elif child.kind in {nnkCommentStmt, nnkDiscardStmt}:
        discard
      else:
        error("serverFn block must contain proc definitions", child)
  elif n.kind == nnkProcDef:
    result = crownFnExpand(n)
  else:
    error("serverFn expects `serverFn:` plus a proc, or `serverFn proc ...`", n)

proc detectServerFns*(content: string): seq[string] =
  ## Scan source text for ``serverFn`` procs (used by the route generator).
  let lines = content.splitLines()
  var i = 0
  while i < lines.len:
    let l = lines[i].strip()
    if l == "serverFn:" or l.startsWith("serverFn:"):
      var j = i + 1
      while j < lines.len and lines[j].strip().len == 0:
        inc j
      if j < lines.len:
        var procLine = lines[j].strip()
        if procLine.startsWith("proc "):
          var name = procLine["proc ".len .. ^1].strip()
          var identName = ""
          for ch in name:
            if ch in {'*', '(', ' ', ':'}:
              break
            identName.add(ch)
          if identName.len > 0:
            result.add(identName)
    elif l.startsWith("serverFn proc "):
      var name = l["serverFn proc ".len .. ^1].strip()
      var identName = ""
      for ch in name:
        if ch in {'*', '(', ' ', ':'}:
          break
        identName.add(ch)
      if identName.len > 0:
        result.add(identName)
    inc i

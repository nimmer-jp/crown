## Compile-time query schemas and zero-cost param binding (TanStack-style).
import std/[macros, options, strutils, tables, json]

export options

proc parseBoolLoose*(raw: string, default: bool): bool =
  let v = raw.strip().toLowerAscii()
  if v.len == 0:
    return default
  if v in ["1", "true", "yes", "on"]:
    return true
  if v in ["0", "false", "no", "off"]:
    return false
  default

proc parseIntLoose*(raw: string, default: int): int =
  if raw.strip().len == 0:
    return default
  try:
    parseInt(raw.strip())
  except ValueError:
    default

proc parseFloatLoose*(raw: string, default: float): float =
  if raw.strip().len == 0:
    return default
  try:
    parseFloat(raw.strip())
  except ValueError:
    default

proc bindValues*[T](values: Table[string, string], _: typedesc[T]): T =
  ## Bind a string map into ``T``. Missing / blank keys keep Nim defaults
  ## (including object field defaults). ``Option`` fields become ``none`` when blank.
  result = T()
  for fieldName, field in fieldPairs(result):
    let raw = values.getOrDefault(fieldName, "")
    when field is string:
      if raw.len > 0:
        field = raw
    elif field is int:
      field = parseIntLoose(raw, field)
    elif field is float:
      field = parseFloatLoose(raw, field)
    elif field is bool:
      field = parseBoolLoose(raw, field)
    elif field is JsonNode:
      if raw.len > 0:
        try:
          field = parseJson(raw)
        except CatchableError:
          discard
    elif field is Option[string]:
      if raw.len > 0:
        field = some(raw)
      else:
        field = none(string)
    elif field is Option[int]:
      if raw.strip().len > 0:
        try:
          field = some(parseInt(raw.strip()))
        except ValueError:
          field = none(int)
      else:
        field = none(int)
    elif field is Option[float]:
      if raw.strip().len > 0:
        try:
          field = some(parseFloat(raw.strip()))
        except ValueError:
          field = none(float)
      else:
        field = none(float)
    elif field is Option[bool]:
      if raw.strip().len > 0:
        field = some(parseBoolLoose(raw, false))
      else:
        field = none(bool)
    elif field is enum:
      if raw.len > 0:
        field = parseEnum[typeof(field)](raw, field)
    else:
      discard

proc crownQueryNodeName(node: NimNode): string {.compileTime.} =
  case node.kind
  of nnkIdent, nnkSym:
    result = node.strVal
  of nnkPostfix:
    result = crownQueryNodeName(node[1])
  of nnkAccQuoted:
    result = crownQueryNodeName(node[0])
  else:
    error("query: expected identifier, got " & $node.kind, node)

proc crownIsChoiceCall(node: NimNode): bool {.compileTime.} =
  node.kind in {nnkCall, nnkCommand} and node.len >= 2 and
      crownQueryNodeName(node[0]) == "choice"

proc crownChoiceMembers(node: NimNode): seq[NimNode] {.compileTime.} =
  for i in 1 ..< node.len:
    result.add(node[i])

proc crownSplitQueryField(stmt: NimNode): tuple[name, typ, default: NimNode] {.compileTime.} =
  result.name = newEmptyNode()
  result.typ = newEmptyNode()
  result.default = newEmptyNode()

  # `page: int = 1` in an untyped macro body is parsed as:
  # Call(Ident "page", StmtList(Asgn(Ident "int", IntLit 1)))
  if stmt.kind in {nnkCall, nnkCommand} and stmt.len == 2 and
      stmt[0].kind in {nnkIdent, nnkSym} and stmt[1].kind == nnkStmtList and
      stmt[1].len == 1:
    result.name = stmt[0]
    let inner = stmt[1][0]
    if inner.kind == nnkAsgn:
      result.typ = inner[0]
      result.default = inner[1]
    else:
      result.typ = inner
    return

  var target = stmt
  if stmt.kind == nnkInfix and stmt[0].kind in {nnkIdent, nnkSym} and
      stmt[0].strVal == ":":
    result.name = stmt[1]
    target = stmt[2]
    if target.kind == nnkAsgn:
      result.typ = target[0]
      result.default = target[1]
    else:
      result.typ = target
    return
  case stmt.kind
  of nnkAsgn:
    let lhs = stmt[0]
    result.default = stmt[1]
    if lhs.kind == nnkInfix and lhs[0].kind in {nnkIdent, nnkSym} and
        lhs[0].strVal == ":":
      result.name = lhs[1]
      result.typ = lhs[2]
    elif lhs.kind == nnkExprColonExpr:
      result.name = lhs[0]
      result.typ = lhs[1]
    else:
      error("query fields must look like `name: Type = default`", stmt)
  of nnkExprColonExpr:
    result.name = stmt[0]
    result.typ = stmt[1]
    if result.typ.kind == nnkAsgn:
      result.default = result.typ[1]
      result.typ = result.typ[0]
  else:
    error("Unsupported query field syntax: " & $stmt.kind, stmt)

macro query*(name: untyped, body: untyped): untyped =
  ## Declare a typed search/query object. Inline enums use ``choice(a, b)``.
  ##
  ## ```nim
  ## query ProductsQuery:
  ##   page: int = 1
  ##   sort: choice(asc, desc) = desc
  ##   filter: Option[string]
  ## ```
  let typeName = ident(crownQueryNodeName(name))
  var recList = newNimNode(nnkRecList)
  var prelude = newStmtList()
  if body.kind != nnkStmtList:
    error("query body must be a statement list", body)

  for stmt in body:
    if stmt.kind in {nnkCommentStmt, nnkDiscardStmt}:
      continue
    var field = crownSplitQueryField(stmt)
    let fieldName = ident(crownQueryNodeName(field.name))
    var fieldType = field.typ
    if crownIsChoiceCall(field.typ):
      let enumName = ident(typeName.strVal & "_" & fieldName.strVal)
      var enumTy = newNimNode(nnkEnumTy)
      enumTy.add(newEmptyNode())
      for member in crownChoiceMembers(field.typ):
        enumTy.add(member)
      prelude.add(newNimNode(nnkTypeSection).add(
        newNimNode(nnkTypeDef).add(
          postfix(enumName, "*"),
          newEmptyNode(),
          enumTy
        )
      ))
      fieldType = enumName
      if field.default.kind != nnkEmpty and field.default.kind in {nnkIdent, nnkSym}:
        field.default = newDotExpr(enumName, field.default)

    recList.add(newIdentDefs(postfix(fieldName, "*"), fieldType, field.default))

  let typeDef = newNimNode(nnkTypeDef).add(
    postfix(typeName, "*"),
    newEmptyNode(),
    newNimNode(nnkObjectTy).add(newEmptyNode(), newEmptyNode(), recList)
  )
  prelude.add(newNimNode(nnkTypeSection).add(typeDef))
  result = prelude

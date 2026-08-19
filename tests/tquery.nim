import std/[unittest, tables, options]
import crown/query

type SortDir = enum
  asc, desc

type SearchInput = object
  q*: string
  page*: int = 1
  sort*: SortDir = desc
  filter*: Option[string]

query ProductsQuery:
  page: int = 1
  sort: choice(asc, desc) = desc
  filter: Option[string]

suite "Typed query binding":
  test "bindValues keeps defaults and parses enums / Option":
    let empty = bindValues(initTable[string, string](), SearchInput)
    check empty.page == 1
    check empty.sort == desc
    check empty.filter.isNone

    var values = initTable[string, string]()
    values["q"] = "nim"
    values["page"] = "3"
    values["sort"] = "asc"
    values["filter"] = "web"
    let filled = bindValues(values, SearchInput)
    check filled.q == "nim"
    check filled.page == 3
    check filled.sort == asc
    check filled.filter.get == "web"

  test "query macro emits object + inline enum":
    let q = ProductsQuery()
    check q.page == 1
    check q.sort == ProductsQuery_sort.desc
    check q.filter.isNone

    var values = initTable[string, string]()
    values["page"] = "2"
    values["sort"] = "asc"
    let parsed = bindValues(values, ProductsQuery)
    check parsed.page == 2
    check parsed.sort == ProductsQuery_sort.asc

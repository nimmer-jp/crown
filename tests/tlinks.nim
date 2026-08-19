import std/unittest
import std/options
import crown/links

type ProductsQuery = object
  page*: int
  sort*: string
  filter*: Option[string]

suite "Typed links":
  test "hrefIdent maps filesystem paths to helper names":
    check hrefIdent("/") == "hrefIndex"
    check hrefIdent("/products") == "hrefProducts"
    check hrefIdent("/users/{id:int}") == "hrefUsers"
    check hrefIdent("/api/save") == "hrefApiSave"
    check hrefIdent("/docs/routing") == "hrefDocsRouting"

  test "withQuery serializes objects and omits none Option":
    check withQuery("/products", ProductsQuery(page: 2, sort: "desc",
        filter: none(string))) == "/products?page=2&sort=desc"
    check withQuery("/products", ProductsQuery(page: 1, sort: "asc",
        filter: some("web"))) == "/products?page=1&sort=asc&filter=web"
    check href("/products") == "/products"

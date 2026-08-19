import crown/core

query ProductsQuery:
  page: int = 1
  sort: choice(asc, desc) = desc
  filter: Option[string]

type AddProduct = object
  name*: string

type Product = object
  id*: int
  name*: string

var catalog = @[
  Product(id: 1, name: "Crown mug"),
  Product(id: 2, name: "Nim sticker"),
  Product(id: 3, name: "Typed router")
]

proc loader*(req: Request): seq[Product] =
  let q = req.search(ProductsQuery)
  if q.filter.isNone:
    return catalog
  let needle = q.filter.get.toLowerAscii()
  for item in catalog:
    if needle in item.name.toLowerAscii():
      result.add(item)

proc action*(req: Request) =
  let form = req.form(AddProduct)
  if form.name.len > 0:
    catalog.add(Product(id: catalog.len + 1, name: form.name))

proc page*(req: Request, data: seq[Product]): string =
  let q = req.search(ProductsQuery)
  var itemsHtml = ""
  for item in data:
    itemsHtml &= "<li>" & item.name & "</li>"
  let nextUrl = href("/products", ProductsQuery(page: q.page + 1, sort: q.sort,
      filter: q.filter))
  html"""
    <div class="p-8 max-w-lg mx-auto space-y-4">
      <h1 class="text-2xl font-bold">Products</h1>
      <p class="text-sm text-slate-600">
        Typed <code>query</code> + Remix-style <code>action</code> (POST revalidates loader).
      </p>
      <ul class="list-disc pl-6">{itemsHtml}</ul>
      <form crown-post="/products" class="flex gap-2">
        <input name="name" placeholder="Add product" class="border rounded px-2 py-1 flex-1" />
        <button class="px-3 py-1 bg-indigo-600 text-white rounded" type="submit">Save</button>
      </form>
      <a class="text-indigo-600 text-sm" href="{nextUrl}">Next page ({q.page + 1})</a>
    </div>
  """

## Blog catalog.
##
## 新しいリリース記事を足す手順:
## 1. ``articles/<name>.nim`` に ``proc body*(): string`` を書く
## 2. このファイルで import し、``allPosts`` の先頭に ``BlogPost`` を追加する
import std/options
import ./articles/crown_0_7

export options

type BlogPost* = object
  slug*: string
  title*: string
  date*: string
  summary*: string
  tags*: seq[string]
  body*: proc (): string {.nimcall.}

proc postUrl*(p: BlogPost): string {.inline.} =
  "/blog/" & p.slug

let allPosts*: seq[BlogPost] = @[
  BlogPost(
    slug: "crown-0-7",
    title: "Crown 0.7: Typed Query, Action, and serverFn",
    date: "2026-08-19",
    summary: "TanStack の型安全性と Remix の loader/action を、Nim マクロのゼロコスト抽象に落とし込んだリリースです。",
    tags: @["Release", "0.7", "Routing"],
    body: crown_0_7.body
  )
]

proc findPost*(slug: string): Option[BlogPost] =
  for post in allPosts:
    if post.slug == slug:
      return some(post)
  none(BlogPost)

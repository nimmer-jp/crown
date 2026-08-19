import crown/core
import ../posts

type BlogView = object
  found*: bool
  slug*: string
  title*: string
  date*: string
  tags*: seq[string]
  body*: string

proc loader*(req: Request): BlogView =
  let slug = req.param("slug", string)
  let post = findPost(slug)
  if post.isNone:
    return BlogView(found: false, slug: slug)
  let p = post.get
  BlogView(
    found: true,
    slug: p.slug,
    title: p.title,
    date: p.date,
    tags: p.tags,
    body: p.body()
  )

proc page*(req: Request, data: BlogView): string =
  if not data.found:
    return html"""
      <div class="max-w-3xl mx-auto text-center py-16">
        <p class="text-xs font-bold tracking-widest uppercase text-indigo-600 mb-3">Blog</p>
        <h1 class="text-3xl font-extrabold text-slate-900 mb-3">Post not found</h1>
        <p class="text-slate-600 mb-8">スラッグ <code class="bg-slate-100 px-2 py-0.5 rounded text-sm">{data.slug}</code> の記事はありません。</p>
        <a href="/blog" class="text-indigo-600 font-bold hover:underline">← All posts</a>
      </div>
    """

  var tagHtml = ""
  for tag in data.tags:
    tagHtml &= "<span class=\"px-2 py-0.5 rounded-full bg-indigo-50 text-indigo-600 text-xs font-semibold\">" &
        tag & "</span>"

  html"""
    <article class="max-w-3xl mx-auto">
      <a href="/blog" class="text-sm font-semibold text-slate-400 hover:text-indigo-600 transition-colors">← Blog</a>
      <header class="mt-6 mb-10 pb-8 border-b border-slate-200">
        <div class="flex flex-wrap items-center gap-2 mb-4">
          <time class="text-xs font-mono text-slate-400">{data.date}</time>
          {tagHtml}
        </div>
        <h1 class="text-4xl font-extrabold tracking-tight text-slate-900 leading-tight">{data.title}</h1>
      </header>
      <div class="blog-body">
        {data.body}
      </div>
      <footer class="mt-16 pt-8 border-t border-slate-200 flex justify-between items-center">
        <a href="/blog" class="text-slate-500 font-semibold hover:text-slate-800">All posts</a>
        <a href="/docs" class="text-indigo-600 font-bold hover:underline">Documentation →</a>
      </footer>
    </article>
  """

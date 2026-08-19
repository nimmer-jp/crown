import crown/core
import ./posts

proc page*(req: Request): string =
  var cards = ""
  for post in allPosts:
    var tagHtml = ""
    for tag in post.tags:
      tagHtml &= "<span class=\"px-2 py-0.5 rounded-full bg-indigo-50 text-indigo-600 text-xs font-semibold\">" &
          tag & "</span>"
    cards &= html"""
      <a href="{postUrl(post)}" class="block group p-8 bg-white border border-slate-200 rounded-3xl shadow-sm hover:shadow-xl hover:border-indigo-100 transition-all">
        <div class="flex flex-wrap items-center gap-2 mb-3">
          <time class="text-xs font-mono text-slate-400">{post.date}</time>
          {tagHtml}
        </div>
        <h2 class="text-2xl font-bold text-slate-900 group-hover:text-indigo-600 transition-colors mb-2">{post.title}</h2>
        <p class="text-slate-600 leading-relaxed">{post.summary}</p>
        <div class="mt-4 text-indigo-600 font-bold text-sm inline-flex items-center gap-1 group-hover:gap-2 transition-all">
          Read post <span>→</span>
        </div>
      </a>
    """

  html"""
    <div class="max-w-3xl mx-auto">
      <div class="mb-12 border-b border-slate-200 pb-8">
        <p class="text-xs font-bold tracking-widest uppercase text-indigo-600 mb-3">Blog</p>
        <h1 class="text-4xl font-extrabold tracking-tight text-slate-900 mb-3">Release notes &amp; writing</h1>
        <p class="text-lg text-slate-600">Crown のリリース、設計の背景、これから進む方向をここに残していきます。</p>
      </div>
      <div class="space-y-6">
        {cards}
      </div>
    </div>
  """

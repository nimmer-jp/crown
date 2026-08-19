import crown/core

proc page*(req: Request, layout="docs"): string =
  return html"""
    <div>
      <div class="mb-10 border-b border-slate-200 pb-8">
        <h1 class="text-4xl font-extrabold tracking-tight text-slate-900 mb-4 flex items-center gap-3">
          <span class="bg-emerald-100 text-emerald-700 w-12 h-12 rounded-xl flex items-center justify-center text-2xl">🔁</span>
          Loader &amp; Action
        </h1>
        <p class="text-xl text-slate-600">Remix と同じ HTTP サイクル。GET は loader、POST は action、成功後は自動 revalidate。</p>
      </div>

      <p class="mb-4 text-lg">Crown は独自のクライアント状態管理を増やしません。<code>loader</code>（GET）と <code>action</code>（POST）を Web 標準の HTTP に 1:1 で対応させます。</p>

      <h3 class="text-xl font-bold text-slate-900 mt-8 mb-4">loader（GET）</h3>
      <p class="mb-4">画面の初期表示に必要なデータをサーバーでまとめます。<code>page(req, data)</code> の第 2 引数に流れます。</p>
      <div class="bg-slate-900 rounded-xl p-6 text-slate-300 font-mono text-sm overflow-x-auto shadow-inner mb-6 whitespace-pre leading-relaxed">        proc loader*(req: Request): seq[Product] =
          let q = req.search(ProductsQuery)
          getProducts(q.page, q.sort)

        proc page*(req: Request, data: seq[Product]): string =
          render(data)</div>

      <h3 class="text-xl font-bold text-slate-900 mt-8 mb-4">action（POST）と自動 Revalidate</h3>
      <p class="mb-4"><code>proc action*</code> は同じパスの POST になります。戻り値が空 / <code>revalidate()</code> / <code>void</code> のとき、Crown は同じルートの <code>loader</code> と <code>page</code> を再実行して最新 HTML を返します。リダイレクトや明示的な HTML 断片を返せば、revalidate は走りません。</p>
      <div class="bg-slate-900 rounded-xl p-6 text-slate-300 font-mono text-sm overflow-x-auto shadow-inner mb-6 whitespace-pre leading-relaxed">        proc action*(req: Request) =
          db.insert(req.form(AddProduct))
          # 成功後に loader → page が自動実行される</div>

      <p class="mb-4"><code>crown-post</code> に <code>crown-target</code> が無いフォームは、返ってきたフル HTML ドキュメントでページ全体を差し替えます。</p>

      <div class="mt-12 pt-8 border-t border-slate-200">
        <div class="flex justify-between items-center">
          <a href="/docs/routing" class="flex items-center gap-4 group p-4 border border-transparent rounded-2xl hover:bg-slate-50 transition-all">
            <div class="text-slate-300 group-hover:text-slate-500 group-hover:-translate-x-1 transition-all text-2xl">←</div>
            <div class="text-left">
              <div class="text-sm text-slate-400 mb-1">Previous</div>
              <div class="font-bold text-slate-600 group-hover:text-slate-800">File-System Routing</div>
            </div>
          </a>
          <a href="/docs/server_fn" class="flex items-center gap-4 group p-4 border border-slate-200 rounded-2xl hover:border-indigo-300 hover:shadow-md transition-all">
            <div class="text-right">
              <div class="text-sm text-slate-400 mb-1">Next Topic</div>
              <div class="font-bold text-indigo-600 group-hover:text-indigo-700">Server Functions</div>
            </div>
            <div class="text-slate-300 group-hover:text-indigo-500 group-hover:translate-x-1 transition-all text-2xl">→</div>
          </a>
        </div>
      </div>
    </div>
  """

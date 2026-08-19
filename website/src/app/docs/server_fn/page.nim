import crown/core

proc page*(req: Request, layout="docs"): string =
  return html"""
    <div>
      <div class="mb-10 border-b border-slate-200 pb-8">
        <h1 class="text-4xl font-extrabold tracking-tight text-slate-900 mb-4 flex items-center gap-3">
          <span class="bg-amber-100 text-amber-700 w-12 h-12 rounded-xl flex items-center justify-center text-2xl">⚙️</span>
          Server Functions
        </h1>
        <p class="text-xl text-slate-600">TanStack Start の createServerFn 相当。クライアントからは JSON RPC、サーバーでは通常の Nim 関数。</p>
      </div>

      <p class="mb-4 text-lg"><code>serverFn</code> マクロは、サーバービルド時に実体の proc と JSON インボーカを生成し、POST <code>/__crown/fn/&lt;name&gt;</code> として公開します。ブラウザからは <code>window.crownServerFn(name, payload)</code> で呼べます。</p>

      <div class="bg-slate-900 rounded-xl p-6 text-slate-300 font-mono text-sm overflow-x-auto shadow-inner mb-6 whitespace-pre leading-relaxed">serverFn:
  proc updateUser*(id: string, name: string): User =
    db.users.update(id, name)

# Client
# window.crownServerFn("updateUser", {{id: "1", name: "Ada"}})</div>

      <p class="mb-4">引数と戻り値は <code>std/jsonutils</code> で JSON 化されます。ファイルシステムルーティングはそのままなので、<code>src/app/</code> 配下のどのモジュールにも置けます。</p>

      <div class="mt-12 pt-8 border-t border-slate-200">
        <div class="flex justify-between items-center">
          <a href="/docs/data" class="flex items-center gap-4 group p-4 border border-transparent rounded-2xl hover:bg-slate-50 transition-all">
            <div class="text-slate-300 group-hover:text-slate-500 group-hover:-translate-x-1 transition-all text-2xl">←</div>
            <div class="text-left">
              <div class="text-sm text-slate-400 mb-1">Previous</div>
              <div class="font-bold text-slate-600 group-hover:text-slate-800">Loader &amp; Action</div>
            </div>
          </a>
          <a href="/docs/layout_inheritance" class="flex items-center gap-4 group p-4 border border-slate-200 rounded-2xl hover:border-indigo-300 hover:shadow-md transition-all">
            <div class="text-right">
              <div class="text-sm text-slate-400 mb-1">Next Topic</div>
              <div class="font-bold text-indigo-600 group-hover:text-indigo-700">Layout Inheritance</div>
            </div>
            <div class="text-slate-300 group-hover:text-indigo-500 group-hover:translate-x-1 transition-all text-2xl">→</div>
          </a>
        </div>
      </div>
    </div>
  """

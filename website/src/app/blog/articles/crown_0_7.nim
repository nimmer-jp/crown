import crown/core

const querySample = "query ProductsQuery:\n" &
    "  page: int = 1\n" &
    "  sort: choice(asc, desc) = desc\n" &
    "  filter: Option[string]\n\n" &
    "proc page*(req: Request): string =\n" &
    "  let q = req.search(ProductsQuery)\n" &
    "  # q.page は int。抽出と変換はマクロが生成"

const dataSample = "proc loader*(req: Request): seq[Product] =\n" &
    "  getProducts(req.search(ProductsQuery))\n\n" &
    "proc action*(req: Request) =\n" &
    "  db.insert(req.form(AddProduct))\n" &
    "  # 成功後に loader → page が自動実行される\n\n" &
    "proc page*(req: Request, data: seq[Product]): string =\n" &
    "  render(data)"

const serverFnSample = "serverFn:\n" &
    "  proc updateUser*(id: string, name: string): User =\n" &
    "    db.users.update(id, name)\n\n" &
    "# window.crownServerFn(\"updateUser\", {id: \"1\", name: \"Ada\"})"

proc body*(): string =
  html"""
    <p class="text-lg text-slate-600 leading-relaxed mb-8">
      Crown 0.7 は、Next.js ライクなファイルシステムルーティングを保ったまま、
      <strong>TanStack Router の型付き Search Params</strong>、
      <strong>Remix の loader / action</strong>、
      <strong>TanStack Start の serverFn</strong>
      を Nim の AST マクロへ移植したリリースです。
    </p>

    <p class="text-slate-600 leading-relaxed mb-10">
      TypeScript 側では Conditional Types や Zod で戦っている領域を、
      Nim ではコンパイル時にコード生成してゼロコストにできます。
      ランタイムの <code class="text-sm bg-slate-100 px-1.5 py-0.5 rounded">node_modules</code> も、
      重いクライアントバンドルもありません。出力はこれまで通り単一のネイティブバイナリです。
    </p>

    <h2 class="text-2xl font-bold text-slate-900 mt-12 mb-4">Typed Search Params</h2>
    <p class="text-slate-600 leading-relaxed mb-4">
      URL クエリは多くのフレームワークで型が弱いところです。
      Crown では <code class="text-sm bg-slate-100 px-1.5 py-0.5 rounded">query</code> マクロが
      オブジェクト・デフォルト値・インライン enum・<code class="text-sm bg-slate-100 px-1.5 py-0.5 rounded">Option[T]</code>
      をコンパイル時に組み立てます。
    </p>
    <div class="bg-slate-900 rounded-xl p-6 text-slate-300 font-mono text-sm overflow-x-auto shadow-inner mb-6 whitespace-pre leading-relaxed">{querySample}</div>

    <h2 class="text-2xl font-bold text-slate-900 mt-12 mb-4">Loader と Action</h2>
    <p class="text-slate-600 leading-relaxed mb-4">
      独自のクライアント状態管理は増やしません。
      <code class="text-sm bg-slate-100 px-1.5 py-0.5 rounded">loader</code> は GET（画面に必要なデータをサーバーで一括取得）、
      <code class="text-sm bg-slate-100 px-1.5 py-0.5 rounded">action</code> は同じパスの POST（更新）です。
    </p>
    <p class="text-slate-600 leading-relaxed mb-6">
      <code class="text-sm bg-slate-100 px-1.5 py-0.5 rounded">action</code> が <code class="text-sm bg-slate-100 px-1.5 py-0.5 rounded">void</code> /
      <code class="text-sm bg-slate-100 px-1.5 py-0.5 rounded">revalidate()</code> / 空レスポンスを返すと、
      Crown は同じルートの loader と page を再実行して最新 HTML を返します。
      リダイレクトや部分 HTML を返せば、revalidate は走りません。
      <code class="text-sm bg-slate-100 px-1.5 py-0.5 rounded">crown-post</code> にターゲットが無いフォームは、
      フルドキュメントを差し替えます。
    </p>
    <div class="bg-slate-900 rounded-xl p-6 text-slate-300 font-mono text-sm overflow-x-auto shadow-inner mb-6 whitespace-pre leading-relaxed">{dataSample}</div>

    <h2 class="text-2xl font-bold text-slate-900 mt-12 mb-4">Typed Links</h2>
    <p class="text-slate-600 leading-relaxed mb-6">
      <code class="text-sm bg-slate-100 px-1.5 py-0.5 rounded">href="/users/" &amp; id</code> のような文字列結合はリンク切れの元です。
      ルートマニフェストから <code class="text-sm bg-slate-100 px-1.5 py-0.5 rounded">hrefUsers(id: int)</code> を生成し、
      クエリ付き URL は <code class="text-sm bg-slate-100 px-1.5 py-0.5 rounded">href("/products", q)</code> で組み立てます。
      タイポと型の不一致はコンパイルエラーになります。
    </p>

    <h2 class="text-2xl font-bold text-slate-900 mt-12 mb-4">serverFn</h2>
    <p class="text-slate-600 leading-relaxed mb-4">
      TanStack Start の <code class="text-sm bg-slate-100 px-1.5 py-0.5 rounded">createServerFn</code> 相当です。
      マクロはサーバー上の実体 proc と JSON インボーカを同時に生成し、
      <code class="text-sm bg-slate-100 px-1.5 py-0.5 rounded">POST /__crown/fn/&lt;name&gt;</code> として公開します。
    </p>
    <div class="bg-slate-900 rounded-xl p-6 text-slate-300 font-mono text-sm overflow-x-auto shadow-inner mb-6 whitespace-pre leading-relaxed">{serverFnSample}</div>

    <h2 class="text-2xl font-bold text-slate-900 mt-12 mb-4">これから</h2>
    <p class="text-slate-600 leading-relaxed mb-4">
      今回の焦点は「型」と「HTTP サイクル」です。
      Vinxi / Nitro 思想の Edge・WASM・SSG マルチターゲットは、
      Nim の公式バックエンド（C / JS / WASM）に沿って今後伸ばします。
      いまの本番経路は、これまで通り <code class="text-sm bg-slate-100 px-1.5 py-0.5 rounded">crown build</code> の単一ネイティブバイナリです。
    </p>
    <p class="text-slate-600 leading-relaxed">
      詳細は
      <a href="/docs/routing" class="text-indigo-600 font-semibold hover:underline">Typed Search / Links</a>、
      <a href="/docs/data" class="text-indigo-600 font-semibold hover:underline">Loader &amp; Action</a>、
      <a href="/docs/server_fn" class="text-indigo-600 font-semibold hover:underline">Server Functions</a>
      を参照してください。サンプルアプリの <code class="text-sm bg-slate-100 px-1.5 py-0.5 rounded">/products</code> でも同じパターンを試せます。
    </p>
  """

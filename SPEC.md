# 👑 Crown Framework 決定版仕様書

## 1. コンセプトと設計思想 (Philosophy)

Crownは、Nimの圧倒的な処理速度と、最新のWeb標準アーキテクチャ（Hypermedia Driven）を融合させた、次世代のメタフレームワークです。

* **Next.js (App Router) ライクな最高のDX:** ファイルシステムベースのルーティングを採用。URL設計の煩わしさから開発者を解放します。
* **Zero JS (状態管理からの解放):** クライアントとサーバーの状態同期（State）という概念を破棄。HTMXをコアエンジンとし、ブラウザのJSを一切書かずにリッチな部分更新（SPAライクなUX）を実現します。
* **堅牢な土台:** 独自のHTTPサーバーを再発明せず、セキュリティやセッション管理に実績のある**Basolato**を裏側のエンジンとして完全に隠蔽・活用します。
* **UIとロジックの共存 (Co-location):** 独自タグによるパースの黒魔術を捨て、Nim標準の `proc` とマクロ (`html""" """`) を用いて、1ファイル内にクリーンに処理とビューを同居させます。

## 2. アーキテクチャ構成

Crownのエコシステムは、以下の3つのレイヤーで構成されます。

1.  **Crown CLI (メタフレームワーク層):** ディレクトリ構造を走査し、Basolato用のルーティング (`routes.nim`) をビルド時に自動生成するトランスパイラ。
2.  **Crown Core (サーバー＆通信層):** BasolatoによるHTTPリクエスト処理と、HTMXによる非同期のHTMLフラグメント通信のオーケストレーション。
3.  **Tiara (UIコンポーネント層):** Tailwindに依存しない、純粋なNim製の美しく高速なUIコンポーネント群。Crownのビュー内で関数として呼び出されます。

## 3. ディレクトリ構造 (File-System Routing)

`src/app/` ディレクトリ配下の構造が、そのままWebアプリケーションのURL（ルーティング）になります。

```text
crown_project/
├── crown.json           # Crownの設定ファイル
├── src/
│   └── app/
│       ├── page.nim     # URL: /
│       ├── editor/
│       │   └── page.nim # URL: /editor
│       └── api/
│           └── save.nim # URL: /api/save (APIルートとしても機能)
└── public/              # 静的ファイル (自動的にHTMXがインクルードされる)
```

## 4. ファイル構成と記法 (1ファイル完結型)

開発者は `page.nim` などのファイル内に、HTTPメソッドに対応した `proc` をエクスポートするだけで、Crownが自動的にルーティングをマッピングします。

```nim
# src/app/editor/page.nim
import crown/core
import tiara/components

# ==========================================
# 1. Action層 (HTMX経由の非同期リクエスト処理)
# ==========================================

# POSTリクエスト: データの保存や更新
proc post*(req: Request): string =
  let content = req.postParams.getOrDefault("content", "")
  # DB保存処理など...
  
  # 画面全体ではなく、更新された部分のHTML「断片」だけを返す
  return html"""
    <div id="save-status" class="tiara-toast-success">
      保存しました！
    </div>
  """

# ==========================================
# 2. View層 (初期アクセス時のページ全体描画)
# ==========================================

# GETリクエスト: ページ全体のレンダリング
proc page*(req: Request): string =
  let initialContent = "ここにテキストを入力..."

  return html"""
    <div class="tiara-container">
      <h1>Crown Editor</h1>
      
      <form hx-post="/editor" hx-target="#save-status" hx-swap="innerHTML">
        ${Textarea(name="content", value=initialContent)}
        ${Button(text="保存", type="submit", color="primary")}
      </form>

      <div id="save-status"></div>
    </div>
  """
```

### シンタックスハイライトへのアプローチ
Crownの強みを最大限に引き出すため、Nimファイル内の `html""" """` ブロックを認識し、内部をHTML（およびTempli）としてカラーリングする**専用のVSCode拡張機能**の提供をエコシステムの前提とします。これにより、完全な1ファイルで完璧なエディタ体験が完成します。

## 5. Crown CLI のコマンド仕様

* `crown dev`: 開発サーバーを起動。ファイルの変更を検知し、裏側でBasolatoのルーティングを再生成・ホットリロードします。
* `crown build`: 本番環境用に最適化されたコンパイルを実行し、デプロイ可能なバイナリを生成します。

## 6. Crownがもたらす開発体験 (DX) の結論

1.  **React/Next.jsの複雑な `useState` や `useEffect` からの解放。**
2.  **WebSocketの状態同期バグや、巨大なJSバンドルサイズの排除。**
3.  **Nim本来の型安全性と爆速な実行速度の維持。**
4.  **「ファイルを置けば動く」という究極に直感的なルーティング。**

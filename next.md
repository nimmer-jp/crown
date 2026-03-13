 要点はこれです。

  - page* / post* の標準形は string を返す
  - 再利用部品も proc ...(): string = html"""...""" にする
  - Crown は最後にそれを Response へ包むだけにする
  - Basolato の Component 対応を入れるとしても、あくまで互換機能に留める

  イメージはこれです。

  import crown/core

  proc headerComponent*(): string =
    html"""
      <header>
        <h1>Editro</h1>
      </header>
    """

  proc page*(req: Request): string =
    html"""
      {headerComponent()}
      <main>Hello</main>
    """

  component() を足すなら、別の重い型は作らず、string の薄い sugar に留めるのがいいです。つまり component() は「あってもいいが必須ではない」、優先順位は return html""" を正式スタイルに据えることのほうが上です。

  必要なら次に、この内容をそのまま Crown の Issue/PR 本文用の日本語版と英語版にします。


› コンポーネント同士のデータ同期や親pageからのコンポーネント側の更新はどう扱えば良いですか？


• Crown を return html""" ベースで行くなら、考え方は React ではなく「サーバー主導の再描画」です。つまり、コンポーネント同士で状態を直接同期させるのではなく、親 page か usecase 側に状態を集めて、必要な部分を再レ
  ンダリングします。

  基本方針はこれです。

  - 単一の真実の置き場は page / usecase / DB / session に置く
  - コンポーネントは props -> string の純関数にする
  - 親から子の更新は「子を再計算して返す」で扱う
  - 兄弟コンポーネント同期も「共通状態から両方を再描画する」で扱う

  形はこうです。

  type EditorVm = object
    userName: string
    documents: seq[string]
    currentDoc: string

  proc header(vm: EditorVm): string =
    html"""<header>{vm.userName}</header>"""

  proc sidebar(vm: EditorVm): string =
    html"""<aside>{vm.documents.len} docs</aside>"""

  proc editor(vm: EditorVm): string =
    html"""<main>{vm.currentDoc}</main>"""

  proc page*(req: Request): string =
    let vm = buildEditorVm(req)
    html"""
      {header(vm)}
      {sidebar(vm)}
      {editor(vm)}
    """

  更新の扱いは 3 パターンに分けるのが実務的です。

  1. 永続状態

  - DB, session, URL, form value を更新
  - その状態から対象コンポーネントを再描画
  - 必要なら親ごと返す

  2. 兄弟同期

  - 片方が更新されたら、共通 state を作り直して両方返す
  - HTMX を使うなら target を親にしてまとめて差し替える
  - もしくは複数 fragment を返す

  3. 純ローカル UI 状態

  - モーダル開閉、タブ、ドラッグ中、入力途中など
  - これは小さい JS で持ってよい
  - サーバー state にしないほうが自然

  親 page から特定コンポーネントだけ更新したい場合も、「そのコンポーネントを直接 mutate する」のではなく、そのコンポーネント用 endpoint を切って再レンダリングするのが自然です。

  proc get*(req: Request): string =
    let vm = buildSidebarVm(req)
    sidebar(vm)

  つまり結論はこれです。

  - Crown ではコンポーネント間同期は「共有状態 + 再レンダリング」で扱う
  - 親から子の更新も「props を変えて再描画」で扱う
  - ローカルな瞬間状態だけ JS に逃がす
  - React のような双方向 state 同期を Crown のコンポーネント責務に入れない

  もし必要なら次に、Crown 向けに

  - 親 page 再描画
  - 部分更新 endpoint
  - sibling 同期
  - ローカル JS state
    の4パターンを具体例付きで整理します。

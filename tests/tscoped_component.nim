import std/unittest
import std/strutils
import crown/core

component myButton(label: string):
  css: """
    .self {
      padding: var(--space-4);
      background: var(--primary);
    }
    .self:hover { opacity: 0.8; }
  """
  html:
    button(class="self"):
      text label

component buttonWithExtraClass(label: string):
  css: """
    .self {
      color: white;
    }
    .selfish {
      color: red;
    }
  """
  html:
    button(class="btn self rounded"):
      text label

proc childBadge(name: string): string =
  "<em>" & name & "</em>"

component advancedPanel(items: seq[string], showHeader: bool, mode: string):
  css: """
    .self {
      border: 1px solid #ddd;
    }
  """
  html:
    section(class="self"):
      if showHeader:
        myButton("Header")
      ul:
        for item in items:
          li:
            myButton(item)
      childBadge(name = mode)
      case mode
      of "edit":
        input(type="text", value="draft")
      else:
        br()

component rawHtmlButton(label: string):
  css: """
    .self { color: white; background: black; }
  """
  html: """
    <button class="btn self rounded">{label}</button>
    <input class='self field' value="{label}" />
  """

component phpLikeRawTemplate(showHeader: bool, items: seq[string]):
  css: """
    .self { border: 1px solid #ddd; }
  """
  html: """
    <section class="self">
      {? if showHeader ?}
        <h3>Visible</h3>
      {? else ?}
        <h3>Hidden</h3>
      {? end ?}
      <ul>
      {? for item in items ?}
        <li>{?= item ?}</li>
      {? endfor ?}
      </ul>
    </section>
  """

suite "Scoped component macro":
  test "scopes css and html class names":
    let rendered = myButton("Save")
    check rendered.contains("<style>")
    check rendered.contains("</style>")
    check rendered.contains(".crown-scope-")
    check rendered.contains(".crown-scope-")
    check rendered.contains(":hover { opacity: 0.8; }")
    check rendered.contains("<button class=\"crown-scope-")
    check rendered.contains(">Save</button>")
    check not rendered.contains(".self")

  test "legacy component alias still works":
    let snippet = component"""<span class="badge">new</span>"""
    check snippet == "<span class=\"badge\">new</span>"

  test "replaces only self class token":
    let rendered = buttonWithExtraClass("Send")
    check rendered.contains(".selfish")
    check rendered.contains(".crown-scope-")
    check rendered.contains("<button class=\"btn crown-scope-")
    check rendered.contains(" rounded\">Send</button>")

  test "supports if/for/case and nested component calls":
    let rendered = advancedPanel(@["A", "B"], true, "edit")
    check rendered.contains(">Header</button>")
    check rendered.contains(">A</button>")
    check rendered.contains(">B</button>")
    check rendered.contains("<em>edit</em>")
    check rendered.contains("<input type=\"text\" value=\"draft\" />")
    check not rendered.contains("</input>")
    check not rendered.contains("<myButton")

  test "supports raw html template in html block":
    let rendered = rawHtmlButton("Send")
    check rendered.contains("<button class=\"btn crown-scope-")
    check rendered.contains(" rounded\">Send</button>")
    check rendered.contains("<input class='crown-scope-")
    check rendered.contains(" field' value=\"Send\" />")

  test "supports php-like directives in raw html":
    let rendered = phpLikeRawTemplate(true, @["A", "B"])
    check rendered.contains("<section class=\"crown-scope-")
    check rendered.contains("<h3>Visible</h3>")
    check not rendered.contains("<h3>Hidden</h3>")
    check rendered.contains("<li>A</li>")
    check rendered.contains("<li>B</li>")

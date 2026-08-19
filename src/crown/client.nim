import std/dom
import std/asyncjs
import std/jsffi

proc closest*(n: Node, selectors: cstring): Element {.importjs: "#.closest(#)".}
proc hasAttribute*(n: Node, name: cstring): bool {.importjs: "#.hasAttribute(#)".}
proc fetch*(url: cstring, options: JsObject): Future[
    JsObject] {.importjs: "fetch(#, #)".}
proc text*(res: JsObject): Future[cstring] {.importjs: "#.text()".}
proc newFormData*(form: Element): JsObject {.importjs: "new FormData(#)".}

var console* {.importc, nodecl.}: JsObject

proc applyFullDocument(html: cstring) =
  ## Remix-style document swap when ``crown-post`` has no ``crown-target``.
  {.emit: """
  (function (html) {
    var text = String(html);
    var lower = text.toLowerCase();
    if (lower.indexOf("<html") !== -1) {
      document.open();
      document.write(text);
      document.close();
    }
  })(`html`);
  """.}

proc installCrownServerFn() =
  {.emit: """
  window.crownServerFn = function (name, payload) {
    payload = payload || {};
    return fetch("/__crown/fn/" + name, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(payload)
    }).then(function (r) { return r.json(); });
  };
  """.}

proc handleRequest(el: Element, methodStr: cstring, url: cstring): Future[
    void] {.async.} =
  let targetSel = el.getAttribute("crown-target")
  var swap = el.getAttribute("crown-swap")
  if swap == nil or swap == "": swap = "innerHTML"

  el.classList.add("crown-loading")

  var options = newJsObject()
  options.method = methodStr

  if methodStr == "POST" and el.nodeName == "FORM":
    options.body = newFormData(el)

  try:
    let res = await fetch(url, options)
    let txt = await res.text()
    if targetSel != nil and targetSel != "":
      let targetNodes = document.querySelectorAll(targetSel)
      if targetNodes.len > 0:
        let target = targetNodes[0]
        if swap == "innerHTML":
          target.innerHTML = txt
        elif swap == "outerHTML":
          target.outerHTML = txt
    else:
      applyFullDocument(txt)
  except JsError as err:
    console.error("Crown API Error:", err)
  finally:
    el.classList.remove("crown-loading")

document.addEventListener("DOMContentLoaded", proc (e: Event) =
  installCrownServerFn()
  document.addEventListener("click", proc (e: Event) =
    let target = cast[Element](e.target)
    let el = target.closest("[crown-get], [crown-post]")
    if el != nil:
      if el.nodeName == "FORM": return

      let inputEl = cast[InputElement](el)
      if el.nodeName == "BUTTON" and inputEl.`type` == "submit" and
          inputEl.form != nil: return

      e.preventDefault()
      let methodStr: cstring = if el.hasAttribute(
          "crown-get"): "GET" else: "POST"
      let url = if el.hasAttribute("crown-get"): el.getAttribute(
          "crown-get") else: el.getAttribute("crown-post")
      discard handleRequest(el, methodStr, url)
  )

  document.addEventListener("submit", proc (e: Event) =
    let target = cast[Element](e.target)
    let form = target.closest("[crown-get], [crown-post]")
    if form != nil:
      e.preventDefault()
      let methodStr: cstring = if form.hasAttribute(
          "crown-post"): "POST" else: "GET"
      let url = if form.hasAttribute("crown-get"): form.getAttribute(
          "crown-get") else: form.getAttribute("crown-post")
      discard handleRequest(form, methodStr, url)
  )
)

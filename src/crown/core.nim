import std/macros
import std/strformat
import std/[httpcore, asyncdispatch, json, os, strutils]

import basolato/controller except html
import basolato/core/response as basolatoResponse
import basolato/core/templates

export strformat, httpcore, asyncdispatch, json, os, strutils

type
  Context* = controller.Context
  Params* = controller.Params
  Response* = controller.Response
  Request* = ref object
    context*: Context
    params*: Params

proc get*(r: Request, key: string): string = r.params.getStr(key)
proc getStr*(r: Request, key: string): string = r.params.getStr(key)
proc getOrDefault*(r: Params, key: string, default: string): string = r.getStr(
    key, default)
# Expose `postParams` and `queryParams` behavior since they're just params in Basolato
proc postParams*(r: Request): Params = r.params
proc queryParams*(r: Request): Params = r.params

# Procedures manually exported
export controller.newHttpHeaders
export controller.getStr
export controller.getOrDefault
export basolatoResponse.body
export templates.Component
export templates.tmpli

type Layout* = string

const clientJsPath = currentSourcePath().parentDir() / "client.js"
const clientNimPath = currentSourcePath().parentDir() / "client.nim"
const buildCmd = "nim js -d:release --hints:off -o:" & clientJsPath & " " & clientNimPath
const _ {.used.} = staticExec(buildCmd)
const clientJsCode = staticRead("client.js")

const crownClientJs = """
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
<style>
  :root { --font-sans: 'Inter', system-ui, -apple-system, sans-serif; }
  body { font-family: var(--font-sans); }
  .crown-loading { opacity: 0.5; pointer-events: none; transition: opacity 0.2s; }
</style>
<script>
""" & clientJsCode & "\n</script>\n"

proc getCrownConfig(): JsonNode =
  result = %*{"tailwind": true, "pwa": false}
  if fileExists("crown.json"):
    try:
      let j = parseFile("crown.json")
      if j.hasKey("tailwind"):
        result["tailwind"] = j["tailwind"]
      if j.hasKey("pwa"):
        result["pwa"] = j["pwa"]
    except:
      discard

proc injectCrownSystem*(content: string): string =
  ## Injects Crown system scripts and Tailwind CSS into the HTML content.
  var injectStr = crownClientJs
  let config = getCrownConfig()
  if config["tailwind"].getBool(true):
    injectStr &= "<script src=\"https://cdn.tailwindcss.com\"></script>\n"

  if config["pwa"].getBool(false):
    injectStr &= "<link rel=\"manifest\" href=\"/manifest.json\">\n"
    injectStr &= "<script>\n"
    injectStr &= "  if ('serviceWorker' in navigator) {\n"
    injectStr &= "    window.addEventListener('load', () => {\n"
    injectStr &= "      navigator.serviceWorker.register('/sw.js').then(reg => {\n"
    injectStr &= "        const syncIfOnline = () => {\n"
    injectStr &= "          if ('sync' in reg) { reg.sync.register('crown-sync').catch(() => {}); }\n"
    injectStr &= "          else if (navigator.serviceWorker.controller) { navigator.serviceWorker.controller.postMessage({type: 'FLUSH_QUEUE'}); }\n"
    injectStr &= "        };\n"
    injectStr &= "        window.addEventListener('online', syncIfOnline);\n"
    injectStr &= "      });\n"
    injectStr &= "    });\n"
    injectStr &= "  }\n"
    injectStr &= "</script>\n"
  else:
    injectStr &= "<script>\n"
    injectStr &= "  if ('serviceWorker' in navigator) {\n"
    injectStr &= "    navigator.serviceWorker.getRegistrations().then(function(registrations) {\n"
    injectStr &= "      for(let registration of registrations) { registration.unregister(); }\n"
    injectStr &= "    });\n"
    injectStr &= "  }\n"
    injectStr &= "</script>\n"

  let lowerContent = content.toLowerAscii()
  let headIdx = lowerContent.find("</head>")

  if headIdx != -1:
    result = content[0 ..< headIdx] & injectStr & content[headIdx .. ^1]
  elif lowerContent.find("<body>") != -1:
    let bodyIdx = lowerContent.find("<body>")
    result = content[0 .. bodyIdx+5] & injectStr & content[bodyIdx+6 .. ^1]
  else:
    # If it's a snippet, we still want the system available if it's the final output
    result = injectStr & content

proc htmlResponse*(content: string, status = Http200): Response =
  var headers = newHttpHeaders()
  headers["Content-Type"] = "text/html; charset=utf-8"
  return Response.new(status, content, headers)

proc jsonResponse*(data: JsonNode, status = Http200): Response =
  var headers = newHttpHeaders()
  headers["Content-Type"] = "application/json; charset=utf-8"
  return Response.new(status, $data, headers)

proc disableLayout*(res: var Response): var Response =
  ## Explicitly disables the layout injection for this response.
  res.headers["Crown-Disable-Layout"] = "true"
  return res

proc disableLayout*(res: Response): Response =
  ## Explicitly disables the layout injection for this response.
  var clonedHeaders = res.headers
  clonedHeaders["Crown-Disable-Layout"] = "true"
  return Response.new(res.status, res.body(), clonedHeaders)

template html*(s: untyped): string =
  ## Combines string interpolation.
  ## Named `html` to trigger HTML syntax highlighting in editors.
  fmt(s)

template component*(s: untyped): string =
  ## An optional sugar alias for `html`.
  ## Use this if you want naming clarity for reusable UI pieces.
  fmt(s)

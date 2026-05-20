import std/[tables, times, httpcore]
import crown/core

type
  RateLimitStore* = ref object
    buckets: Table[string, tuple[windowId: int64, count: int]]

proc newRateLimitStore*(): RateLimitStore =
  RateLimitStore(buckets: initTable[string, tuple[windowId: int64, count: int]]())

proc checkFixedWindow*(store: RateLimitStore; key: string;
    maxHits: Positive; windowSec: Positive): tuple[allowed: bool, retryAfterSec: Natural] =
  ## Fixed-window counter per ``key`` using wall-clock seconds.
  let now = getTime().toUnix()
  let wid = now div windowSec.int64
  if not store.buckets.hasKey(key) or store.buckets[key].windowId != wid:
    store.buckets[key] = (wid, 0)
  var entry = store.buckets[key]
  if entry.count >= maxHits.int:
    let elapsed = int(now mod windowSec.int64)
    var retry = int(windowSec) - elapsed
    if retry < 1:
      retry = 1
    return (false, Natural(retry))
  inc entry.count
  store.buckets[key] = entry
  return (true, 0.Natural)

proc rateLimitResponse*(retryAfterSec: Natural): Response =
  ## ``429`` JSON with ``Retry-After`` header (seconds).
  var headers = newHttpHeaders()
  headers["Content-Type"] = "application/json; charset=utf-8"
  if retryAfterSec > 0:
    headers["Retry-After"] = $retryAfterSec
  let body = "{\"error\":\"too_many_requests\",\"retry_after\":" & $retryAfterSec & "}"
  return Response.new(Http429, body, headers)

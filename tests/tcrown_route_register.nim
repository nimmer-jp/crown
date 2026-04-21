## Regression: ``crownRouteRegister`` must splice route bodies so ``c`` / ``p`` resolve
## after ``{.async.}`` on Basolato 0.15 (Nim 2.2). Template + ``body: untyped`` breaks.
import ./crown_test_env
discard crownTestsEnvReady
import std/unittest

import std/asyncdispatch
import crown/core as crown
import basolato/controller except html

suite "crownRouteRegister macro":
  test "route body binds c and p (0.15 two-arg controller)":
    let r = crownRouteRegister("get", "/__crown_macro_test"):
      var res: crown.Response
      let req = crown.Request(context: c, params: p)
      res = htmlResponse("ok")
      discard req
      return res
    check r != nil

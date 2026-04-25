import std/unittest
import crown/project

suite "Project compiler config":
  test "getCompileArgs includes Crown default compiler flags":
    let config = CrownConfig(
      port: "5000",
      nimFlags: @[],
      buildFlags: @[],
      devFlags: @[],
      watchDirs: @[],
      watchFiles: @[]
    )

    let args = getCompileArgs(config, bmDev, ".crown/main.nim")

    check "-d:httpbeast" in args
    check "-d:ssl" in args
    check "--path:." in args
    check "--nimcache:./nimcache" in args

  test "user flags can override Crown default compiler flags":
    let config = CrownConfig(
      port: "5000",
      nimFlags: @["-u:httpbeast", "-d:httpx", "-u:ssl", "--nimcache:custom"],
      buildFlags: @[],
      devFlags: @[],
      watchDirs: @[],
      watchFiles: @[]
    )

    let args = getCompileArgs(config, bmDev, ".crown/main.nim")

    check "-d:httpbeast" notin args
    check "-d:ssl" notin args
    check "-u:ssl" in args
    check "--nimcache:./nimcache" notin args
    check "--nimcache:custom" in args

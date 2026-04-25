import std/[strutils, unittest]
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

  test "getCompileArgs prefers the running Crown package path":
    let config = CrownConfig(
      port: "5000",
      nimFlags: @[],
      buildFlags: @[],
      devFlags: @[],
      watchDirs: @[],
      watchFiles: @[]
    )

    let args = getCompileArgs(config, bmBuild, ".crown/main.nim")

    check args[1] == "--path:" & getCrownPackagePath()
    check args.find("--path:.") > args.find("--path:" & getCrownPackagePath())

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

  test "source code catches only catchable exceptions":
    let sourceFiles = [
      "src/crown/core.nim",
      "src/crown/generator.nim",
      "src/crown/project.nim",
      "src/crown/watcher.nim"
    ]
    var offendingBareExcepts: seq[string] = @[]

    for file in sourceFiles:
      var lineNo = 0
      for line in readFile(file).splitLines():
        inc lineNo
        if line.strip() == "except:":
          offendingBareExcepts.add(file & ":" & $lineNo)

    checkpoint offendingBareExcepts.join(", ")
    check offendingBareExcepts.len == 0

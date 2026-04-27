import std/[os, strutils, unittest]
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

  test "getCompileArgs pins Basolato 0.15.0 package path when installed":
    let tempDir = getTempDir() / ("crown-basolato-" & $getCurrentProcessId())
    if dirExists(tempDir):
      removeDir(tempDir)
    createDir(tempDir)
    defer: removeDir(tempDir)
    let basolatoPath = tempDir / "pkgs2" / "basolato-0.15.0-test"
    createDir(basolatoPath)
    writeFile(basolatoPath / "basolato.nimble", "version = \"0.15.0\"\n")
    let newerBasolatoPath = tempDir / "pkgs2" / "basolato-0.16.1-test"
    createDir(newerBasolatoPath)
    writeFile(newerBasolatoPath / "basolato.nimble", "version = \"0.16.1\"\n")
    let config = CrownConfig(
      port: "5000",
      nimFlags: @[],
      buildFlags: @[],
      devFlags: @[],
      watchDirs: @[],
      watchFiles: @[]
    )

    let args = getCompileArgs(config, bmDev, ".crown/main.nim", tempDir)

    check "--path:" & basolatoPath in args
    check "--path:" & newerBasolatoPath notin args
    check args.find("--path:" & basolatoPath) < args.find("--path:.")

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

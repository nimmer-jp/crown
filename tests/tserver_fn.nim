import std/[unittest, asyncdispatch, json]
import crown/server_fn

type User = object
  id*: string
  name*: string

serverFn:
  proc updateUser*(id: string, name: string): User =
    User(id: id, name: name)

suite "serverFn":
  test "detectServerFns reads the block form":
    let src = """
serverFn:
  proc updateUser*(id: string, name: string): User =
    User(id: id, name: name)
"""
    check detectServerFns(src) == @["updateUser"]

  test "invoker round-trips JSON arguments":
    let node = waitFor crownServerFn_updateUser(%*{"id": "1", "name": "Ada"})
    check node["id"].getStr() == "1"
    check node["name"].getStr() == "Ada"

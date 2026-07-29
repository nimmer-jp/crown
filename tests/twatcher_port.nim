import std/[net, unittest]
import crown/watcher

suite "Watcher port free detection":
  test "tcpPortFree rejects loopback-only occupation when probing 0.0.0.0":
    ## Reproduce the Nativ-style case: something listens on 127.0.0.1:port only.
    ## Crown binds 0.0.0.0, but browsers hit localhost and collide.
    var occupied: Socket = nil
    var freePort = Port(0)
    for cand in 39100 .. 39200:
      var probe = newSocket()
      try:
        # No SO_REUSEADDR — mirrors a real exclusive loopback listener.
        probe.bindAddr(Port(cand), "127.0.0.1")
        probe.listen()
        occupied = probe
        freePort = Port(cand)
        break
      except CatchableError:
        probe.close()
    require occupied != nil
    defer: occupied.close()

    check localhostOccupied(freePort)
    check not tcpPortFree("0.0.0.0", freePort)

  test "tcpPortFree is true for an unused high port on 0.0.0.0":
    var chosen = Port(0)
    for cand in 39300 .. 39400:
      if tcpPortFree("0.0.0.0", Port(cand)):
        chosen = Port(cand)
        break
    require chosen.int > 0
    check tcpPortFree("0.0.0.0", chosen)
    check not localhostOccupied(chosen)

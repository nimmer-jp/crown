import std/options
import crown/core

template withSomeOrRedirect*[T](opt: Option[T], location: string, name: untyped,
    body: untyped): untyped {.dirty.} =
  ## If ``opt`` is ``none``, return ``redirect(location)``. Otherwise bind ``name = opt.get`` and run ``body``.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##   withSomeOrRedirect(fetchSession(req), "/login", sess):
  ##     return htmlResponse("hello " & sess.userName)
  if opt.isNone:
    return redirect(location)
  let name {.inject.} = opt.get()
  body

import crown/core

type UserVm* = object
  id*: int

proc loader*(req: Request): UserVm =
  UserVm(id: req.param("id", int))

proc page*(req: Request, data: UserVm): string =
  html"""
    <div class="p-8 max-w-md mx-auto">
      <h1 class="text-2xl font-bold mb-2">User {data.id}</h1>
      <p class="text-gray-600 text-sm">
        Crown 0.6 demo: route group <code>(demo)</code>, dynamic segment
        <code>[id:int]</code>, and <code>loader</code> → <code>page</code>.
      </p>
    </div>
  """

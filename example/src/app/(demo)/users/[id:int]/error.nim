import crown/core

proc error*(req: Request, message: string): string =
  discard req
  html"""
    <div class="p-8 max-w-md mx-auto">
      <h1 class="text-2xl font-bold text-red-700 mb-2">Something went wrong</h1>
      <p class="text-gray-600 text-sm">{message}</p>
    </div>
  """

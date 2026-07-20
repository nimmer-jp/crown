import crown/core

proc loading*(req: Request): string =
  discard req
  html"""
    <div class="p-8 max-w-md mx-auto animate-pulse">
      <div class="h-6 bg-gray-200 rounded w-1/3 mb-3"></div>
      <div class="h-4 bg-gray-100 rounded w-full"></div>
    </div>
  """

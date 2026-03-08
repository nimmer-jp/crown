import crown/core

proc page*(req: Request): string =
  return html"""
    <div class="text-center py-20">
      <h1 class="text-9xl font-black text-indigo-100">404</h1>
      <p class="text-2xl font-bold text-gray-800 -mt-12">Page Not Found</p>
      <p class="mt-4 text-gray-600">Sorry, the page you are looking for doesn't exist.</p>
      <div class="mt-10">
        <a href="/" class="inline-block bg-indigo-600 text-white px-8 py-3 rounded-full font-bold hover:bg-indigo-700 transition-colors shadow-lg shadow-indigo-200">
          Back to Safety
        </a>
      </div>
    </div>
  """

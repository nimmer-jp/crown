import crown/core

proc page*(req: Request): string =
  let id = req.getStr("id")
  return html"""
    <div class="p-6 bg-white rounded-xl shadow-sm border border-gray-200">
      <h2 class="text-2xl font-bold text-gray-800">Blog Post</h2>
      <p class="mt-2 text-gray-600">Viewing post with ID: <span class="font-mono text-indigo-600 bg-indigo-50 px-2 py-1 rounded">{id}</span></p>
      
      <div class="mt-6 pt-6 border-t border-gray-100">
        <a href="/" class="text-indigo-600 hover:underline">← Back to Home</a>
      </div>
    </div>
  """

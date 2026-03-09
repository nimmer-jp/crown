import crown/core

proc page*(req: Request, layout="docs"): string =
  return html"""
    <div>
      <div class="mb-10 border-b border-slate-200 pb-8">
        <h1 class="text-4xl font-extrabold tracking-tight text-slate-900 mb-4 flex items-center gap-3">
          <span class="bg-violet-100 text-violet-700 w-12 h-12 rounded-xl flex items-center justify-center text-2xl">🛣️</span>
          File-System Routing
        </h1>
        <p class="text-xl text-slate-600">Learn how routes map to files in the src/app directory.</p>
      </div>

      <p class="mb-4 text-lg">Routes are automatically generated based on the file structure inside the <code>src/app</code> directory. This makes it intuitive to structure your application without having to write complex configuration files.</p>
      
      <h3 class="text-xl font-bold text-slate-900 mt-8 mb-4">Basic Routes</h3>
      <ul class="space-y-3 mb-6 bg-slate-50 p-6 rounded-xl border border-slate-100 list-none pl-0">
        <li class="flex items-center gap-3"><code class="bg-white px-2 py-1 rounded border text-indigo-600 text-sm">src/app/page.nim</code> <span>→</span> <span class="font-mono text-sm text-slate-500 bg-slate-200/50 px-2 py-0.5 rounded">/</span></li>
        <li class="flex items-center gap-3"><code class="bg-white px-2 py-1 rounded border text-indigo-600 text-sm">src/app/docs/page.nim</code> <span>→</span> <span class="font-mono text-sm text-slate-500 bg-slate-200/50 px-2 py-0.5 rounded">/docs</span></li>
      </ul>

      <h3 class="text-xl font-bold text-slate-900 mt-8 mb-4">Dynamic Routes</h3>
      <p class="mb-4">You can define dynamic route parameters by prefixing the filename with <code>p_</code> (parameter):</p>
      <ul class="space-y-3 mb-6 bg-slate-50 p-6 rounded-xl border border-slate-100 list-none pl-0">
        <li class="flex items-center gap-3"><code class="bg-white px-2 py-1 rounded border text-indigo-600 text-sm">src/app/blog/p_id.nim</code> <span>→</span> <span class="font-mono text-sm text-slate-500 bg-slate-200/50 px-2 py-0.5 rounded">/blog/:id</span></li>
      </ul>
      <p class="mb-4">Inside <code>p_id.nim</code>, you can easily access the dynamic parameter through the Request object via <code>req.pathParams["id"]</code>.</p>

      <div class="mt-12 pt-8 border-t border-slate-200">
        <div class="flex justify-between items-center">
          <a href="/docs" class="flex items-center gap-4 group p-4 border border-transparent rounded-2xl hover:bg-slate-50 transition-all">
            <div class="text-slate-300 group-hover:text-slate-500 group-hover:-translate-x-1 transition-all text-2xl">←</div>
            <div class="text-left">
              <div class="text-sm text-slate-400 mb-1">Previous</div>
              <div class="font-bold text-slate-600 group-hover:text-slate-800">Getting Started</div>
            </div>
          </a>

          <a href="/docs/layout_inheritance" class="flex items-center gap-4 group p-4 border border-slate-200 rounded-2xl hover:border-indigo-300 hover:shadow-md transition-all">
            <div class="text-right">
              <div class="text-sm text-slate-400 mb-1">Next Topic</div>
              <div class="font-bold text-indigo-600 group-hover:text-indigo-700">Layout Inheritance</div>
            </div>
            <div class="text-slate-300 group-hover:text-indigo-500 group-hover:translate-x-1 transition-all text-2xl">→</div>
          </a>
        </div>
      </div>
    </div>
  """
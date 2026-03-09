import crown/core

proc page*(req: Request, layout="docs"): string =
  return html"""
    <div>
      <div class="mb-10 border-b border-slate-200 pb-8">
        <h1 class="text-4xl font-extrabold tracking-tight text-slate-900 mb-4 flex items-center gap-3">
          <span class="bg-indigo-100 text-indigo-700 w-12 h-12 rounded-xl flex items-center justify-center text-2xl">🚀</span>
          Getting Started
        </h1>
        <p class="text-xl text-slate-600">Installation and setup guide for Crown Framework.</p>
      </div>

      <p class="mb-4 text-lg">Crown is designed to give you the speed of Nim with the developer experience of modern meta-frameworks like Next.js or Nuxt.</p>
      
      <h3 class="text-xl font-bold text-slate-900 mt-8 mb-4">Installation</h3>
      <p class="mb-4">To install Crown globally, use Nimble:</p>
      <div class="bg-slate-900 rounded-xl p-6 text-slate-300 font-mono text-sm overflow-x-auto shadow-inner mb-6">
        <div class="flex gap-4 mb-2"><span class="text-slate-500">$</span><span>nimble install crown</span></div>
      </div>

      <h3 class="text-xl font-bold text-slate-900 mt-8 mb-4">Create a New Project</h3>
      <p class="mb-4">Initialize a new project and start the development server:</p>
      <div class="bg-slate-900 rounded-xl p-6 text-slate-300 font-mono text-sm overflow-x-auto shadow-inner mb-6">
        <div class="flex gap-4 mb-2"><span class="text-slate-500">$</span><span>crown init my-project</span></div>
        <div class="flex gap-4 mb-2"><span class="text-slate-500">$</span><span>cd my-project</span></div>
        <div class="flex gap-4"><span class="text-slate-500">$</span><span class="text-indigo-400">crown dev</span></div>
      </div>

      <div class="mt-12 pt-8 border-t border-slate-200">
        <div class="flex justify-end">
          <a href="/docs/routing" class="flex items-center gap-4 group p-4 border border-slate-200 rounded-2xl hover:border-indigo-300 hover:shadow-md transition-all">
            <div class="text-right">
              <div class="text-sm text-slate-400 mb-1">Next Topic</div>
              <div class="font-bold text-indigo-600 group-hover:text-indigo-700">File-System Routing</div>
            </div>
            <div class="text-slate-300 group-hover:text-indigo-500 group-hover:translate-x-1 transition-all text-2xl">→</div>
          </a>
        </div>
      </div>
    </div>
  """
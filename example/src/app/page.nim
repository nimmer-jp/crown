import crown/core
import tiara

proc page*(req: Request): string =
  return html"""
    <div class="space-y-24">
      <!-- Hero Section -->
      <section class="text-center space-y-8 py-12">
        <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-indigo-50 border border-indigo-100 text-indigo-600 text-xs font-bold tracking-wider uppercase animate-fade-in">
          <span class="relative flex h-2 w-2">
            <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-indigo-400 opacity-75"></span>
            <span class="relative inline-flex rounded-full h-2 w-2 bg-indigo-500"></span>
          </span>
          v0.1.0 Alpha Released
        </div>
        <h1 class="text-6xl sm:text-7xl font-extrabold tracking-tight text-slate-900">
          The Full-stack <span class="bg-clip-text text-transparent bg-gradient-to-r from-indigo-600 to-violet-600">Nim</span> Framework
        </h1>
        <p class="text-xl text-slate-600 max-w-2xl mx-auto leading-relaxed">
          Build high-performance, type-safe web applications with the speed of Nim and the simplicity of Next.js. Hypermedia-driven indices, nested layouts, and dynamic routing out of the box.
        </p>
        <div class="flex flex-wrap justify-center gap-4">
          <button class="px-8 py-4 bg-indigo-600 text-white rounded-2xl font-bold text-lg shadow-xl shadow-indigo-200 hover:bg-indigo-700 hover:-translate-y-1 transition-all active:scale-95">
            Documentation →
          </button>
          <button class="px-8 py-4 bg-white text-slate-900 border border-slate-200 rounded-2xl font-bold text-lg hover:bg-slate-50 transition-all active:scale-95">
            View on GitHub
          </button>
        </div>
      </section>

      <!-- Demos Grid -->
      <section class="grid md:grid-cols-2 gap-8">
        <!-- JSON API Demo Card -->
        <div class="group p-8 bg-white border border-slate-200 rounded-3xl shadow-sm hover:shadow-xl hover:border-indigo-100 transition-all">
          <div class="w-12 h-12 bg-indigo-50 rounded-2xl flex items-center justify-center mb-6 text-2xl group-hover:scale-110 transition-transform">⚡️</div>
          <h3 class="text-2xl font-bold mb-3 text-slate-900">Native Client Sync</h3>
          <p class="text-slate-600 mb-6 leading-relaxed">
            Fetch server-side data and update the DOM instantly without writing a single line of JavaScript.
          </p>
          
          <div class="p-5 bg-slate-50 rounded-2xl border border-slate-100">
            <button 
              crown-get="/api/save" 
              crown-target="#api-result" 
              class="w-full py-3 bg-white border border-slate-200 text-indigo-600 font-bold rounded-xl hover:bg-indigo-50 hover:border-indigo-200 transition-all shadow-sm active:scale-95"
            >
              Fetch API Info
            </button>
            <div id="api-result" class="mt-4 p-4 bg-slate-900 rounded-xl text-indigo-300 font-mono text-xs overflow-x-auto min-h-[80px] flex items-center justify-center italic opacity-60">
              // Click the button above to see magic
            </div>
          </div>
        </div>

        <!-- Layout Card -->
        <div class="group p-8 bg-white border border-slate-200 rounded-3xl shadow-sm hover:shadow-xl hover:border-violet-100 transition-all">
          <div class="w-12 h-12 bg-violet-50 rounded-2xl flex items-center justify-center mb-6 text-2xl group-hover:scale-110 transition-transform">📂</div>
          <h3 class="text-2xl font-bold mb-3 text-slate-900">Nested Layouts</h3>
          <p class="text-slate-600 mb-6 leading-relaxed">
            Organize your UI with deeply nested layouts that persist state and provide shared structure.
          </p>
          <a href="/editor" class="inline-flex items-center text-indigo-600 font-bold hover:gap-2 transition-all">
            Try the Editor Demo <span class="ml-1">→</span>
          </a>
        </div>
      </section>
    </div>
  """

import crown/core

proc page*(req: Request, layout="docs"): string =
  return html"""
    <div>
      <div class="mb-10 border-b border-slate-200 pb-8">
        <h1 class="text-4xl font-extrabold tracking-tight text-slate-900 mb-4 flex items-center gap-3">
          <span class="bg-fuchsia-100 text-fuchsia-700 w-12 h-12 rounded-xl flex items-center justify-center text-2xl">🧩</span>
          Layout Inheritance
        </h1>
        <p class="text-xl text-slate-600">Compose complex UIs naturally with deeply nested layouts.</p>
      </div>

      <p class="mb-4 text-lg">Crown's layout inheritance system allows you to define a <code>layout.nim</code> file in any directory. The framework automatically wraps the pages in that directory (and its subdirectories) with the corresponding layout.</p>
      
      <p class="mt-6 p-4 bg-fuchsia-50 text-fuchsia-800 rounded-xl border border-fuchsia-100 mb-8 font-medium">
        💡 In fact, this documentation page itself is built using nested layouts! The sidebar to your left is rendered by <code>src/app/docs/layout.nim</code>.
      </p>

      <h3 class="text-xl font-bold text-slate-900 mt-8 mb-4">How it works</h3>
      <p class="mb-4">When a user visits <code>/docs/routing</code>, Crown evaluates the directory tree from the root down to the target page, wrapping the HTML output at each level:</p>
      
      <div class="bg-slate-900 p-6 rounded-xl mb-6 shadow-inner text-sm font-mono text-slate-300">
        <div class="mb-2 text-indigo-400">// 1. Root Layout (src/app/layout.nim)</div>
        <div class="pl-4 border-l-2 border-indigo-500/30">
          <div>&lt;html&gt;&lt;body&gt;</div>
          <div class="mb-2 text-violet-400 mt-2">// 2. Docs Layout (src/app/docs/layout.nim)</div>
          <div class="pl-4 border-l-2 border-violet-500/30">
            <div>&lt;div class="sidebar"&gt;...&lt;/div&gt;</div>
            <div>&lt;main&gt;</div>
            <div class="mb-2 text-fuchsia-400 mt-2">// 3. Target Page (src/app/docs/routing/page.nim)</div>
            <div class="pl-4 border-l-2 border-fuchsia-500/30 text-white font-bold">
              &lt;h1&gt;File-System Routing&lt;/h1&gt;
            </div>
            <div class="mt-2">&lt;/main&gt;</div>
          </div>
          <div class="mt-2">&lt;/body&gt;&lt;/html&gt;</div>
        </div>
      </div>

      <h3 class="text-xl font-bold text-slate-900 mt-8 mb-4">Creating a Layout</h3>
      <p class="mb-4">A layout is simply a Nim file that exports a <code>layout*</code> procedure. It takes a <code>content</code> string as a parameter and returns a string.</p>
      
      <div class="bg-slate-900 rounded-xl p-6 text-slate-300 font-mono text-sm overflow-x-auto shadow-inner mb-6">
        <span class="text-pink-400">import</span> crown/core<br><br>
        <span class="text-pink-400">proc</span> <span class="text-blue-300">layout*</span>(content: <span class="text-green-300">string</span>): <span class="text-green-300">string</span> =<br>
        &nbsp;&nbsp;<span class="text-pink-400">return</span> html<span class="text-yellow-300">&quot;&quot;&quot;</span><br>
        <span class="text-yellow-300">&nbsp;&nbsp;&nbsp;&nbsp;&lt;div class="docs-layout"&gt;</span><br>
        <span class="text-yellow-300">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;{{content}}</span><br>
        <span class="text-yellow-300">&nbsp;&nbsp;&nbsp;&nbsp;&lt;/div&gt;</span><br>
        <span class="text-yellow-300">&nbsp;&nbsp;&quot;&quot;&quot;</span>
      </div>

      <p class="mt-6 p-4 bg-indigo-50 text-indigo-800 rounded-xl border border-indigo-100">
        <strong>State Preservation:</strong> Because Crown uses intelligent client-side routing, navigating between pages that share the same layout will NOT re-render that layout. This means scroll position, video playback, and local UI state in the sidebar remain perfectly preserved!
      </p>

      <div class="mt-12 pt-8 border-t border-slate-200">
        <div class="flex justify-between items-center">
          <a href="/docs/routing" class="flex items-center gap-4 group p-4 border border-transparent rounded-2xl hover:bg-slate-50 transition-all">
            <div class="text-slate-300 group-hover:text-slate-500 group-hover:-translate-x-1 transition-all text-2xl">←</div>
            <div class="text-left">
              <div class="text-sm text-slate-400 mb-1">Previous</div>
              <div class="font-bold text-slate-600 group-hover:text-slate-800">File-System Routing</div>
            </div>
          </a>

          <a href="/docs/interactivity" class="flex items-center gap-4 group p-4 border border-slate-200 rounded-2xl hover:border-indigo-300 hover:shadow-md transition-all">
            <div class="text-right">
              <div class="text-sm text-slate-400 mb-1">Next Topic</div>
              <div class="font-bold text-indigo-600 group-hover:text-indigo-700">Native Client Sync</div>
            </div>
            <div class="text-slate-300 group-hover:text-indigo-500 group-hover:translate-x-1 transition-all text-2xl">→</div>
          </a>
        </div>
      </div>
    </div>
  """
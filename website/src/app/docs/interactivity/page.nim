import crown/core

proc page*(req: Request, layout="docs"): string =
  return html"""
    <div>
      <div class="mb-10 border-b border-slate-200 pb-8">
        <h1 class="text-4xl font-extrabold tracking-tight text-slate-900 mb-4 flex items-center gap-3">
          <span class="bg-sky-100 text-sky-700 w-12 h-12 rounded-xl flex items-center justify-center text-2xl">⚡</span>
          Native Client Sync
        </h1>
        <p class="text-xl text-slate-600">Hypermedia-driven interactivity out of the box.</p>
      </div>

      <p class="mb-4 text-lg">Crown includes built-in capabilities inspired by HTMX. You can update the DOM dynamically, handle form submissions, and create highly interactive experiences without writing a single line of JavaScript.</p>
      
      <h3 class="text-xl font-bold text-slate-900 mt-8 mb-4">Fetching and Updating</h3>
      <p class="mb-4">Use <code>crown-get</code> to fetch HTML from an endpoint, and <code>crown-target</code> to specify which element's inner HTML should be replaced with the server response.</p>
      
      <div class="bg-slate-900 rounded-xl p-6 text-slate-300 font-mono text-sm overflow-x-auto shadow-inner mb-6">
        <code class="text-pink-400">&lt;button</code> <code class="text-sky-300">crown-get=</code><code class="text-green-300">"/api/save"</code> <code class="text-sky-300">crown-target=</code><code class="text-green-300">"#result"</code><code class="text-pink-400">&gt;</code><br>
        &nbsp;&nbsp;Fetch Data<br>
        <code class="text-pink-400">&lt;/button&gt;</code><br>
        <br>
        <code class="text-pink-400">&lt;div</code> <code class="text-sky-300">id=</code><code class="text-green-300">"result"</code><code class="text-pink-400">&gt;</code><br>
        &nbsp;&nbsp;<span class="text-slate-500">&lt;!-- The response from /api/save will be injected here --&gt;</span><br>
        <code class="text-pink-400">&lt;/div&gt;</code>
      </div>

      <h3 class="text-xl font-bold text-slate-900 mt-8 mb-4">Form Submissions</h3>
      <p class="mb-4">You can also use <code>crown-post</code> on forms to intercept standard form submissions, send the data securely via AJAX, and update parts of the page transparently instead of triggering a full page reload.</p>
      
      <div class="bg-slate-900 rounded-xl p-6 text-slate-300 font-mono text-sm overflow-x-auto shadow-inner mb-6">
        <code class="text-pink-400">&lt;form</code> <code class="text-sky-300">crown-post=</code><code class="text-green-300">"/api/save"</code> <code class="text-sky-300">crown-target=</code><code class="text-green-300">"#form-msg"</code><code class="text-pink-400">&gt;</code><br>
        &nbsp;&nbsp;<code class="text-pink-400">&lt;input</code> <code class="text-sky-300">name=</code><code class="text-green-300">"content"</code> <code class="text-sky-300">type=</code><code class="text-green-300">"text"</code> <code class="text-pink-400">/&gt;</code><br>
        &nbsp;&nbsp;<code class="text-pink-400">&lt;button</code> <code class="text-sky-300">type=</code><code class="text-green-300">"submit"</code><code class="text-pink-400">&gt;</code>Submit<code class="text-pink-400">&lt;/button&gt;</code><br>
        <code class="text-pink-400">&lt;/form&gt;</code><br>
        <br>
        <code class="text-pink-400">&lt;div</code> <code class="text-sky-300">id=</code><code class="text-green-300">"form-msg"</code><code class="text-pink-400">&gt;&lt;/div&gt;</code>
      </div>

      <div class="mt-12 pt-8 border-t border-slate-200">
        <div class="flex justify-between items-center">
          <a href="/docs/layout_inheritance" class="flex items-center gap-4 group p-4 border border-transparent rounded-2xl hover:bg-slate-50 transition-all">
            <div class="text-slate-300 group-hover:text-slate-500 group-hover:-translate-x-1 transition-all text-2xl">←</div>
            <div class="text-left">
              <div class="text-sm text-slate-400 mb-1">Previous</div>
              <div class="font-bold text-slate-600 group-hover:text-slate-800">Layout Inheritance</div>
            </div>
          </a>
        </div>
      </div>
    </div>
  """
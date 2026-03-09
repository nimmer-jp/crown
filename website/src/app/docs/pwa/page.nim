import crown/core

proc page*(req: Request, layout: Layout = "docs"): string =
  return html"""
    <div>
      <h1 class="text-4xl font-extrabold text-slate-900 tracking-tight mb-4">
        Zero-Config PWA
      </h1>
      <p class="text-lg text-slate-600 mb-8 leading-relaxed">
        Crown makes it incredibly simple to turn your application into a Progressive Web App (PWA).
        With just a single flag, your app can work offline and sync data in the background.
      </p>

      <div class="bg-indigo-50 border border-indigo-100 rounded-xl p-6 mb-10 shadow-sm">
        <h3 class="flex items-center text-indigo-900 font-semibold mb-3">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path></svg>
          The Problem with PWAs
        </h3>
        <p class="text-indigo-800 text-sm leading-relaxed mb-0">
          Traditionally, building a PWA requires manual setup of Service Workers, configuring caching strategies,
          and writing complex synchronization logic to handle offline requests. Crown automates all of this.
        </p>
      </div>

      <h2 class="text-2xl font-bold text-slate-900 mt-12 mb-6 border-b border-slate-200 pb-2">
        Enabling PWA Support
      </h2>

      <p class="text-slate-600 mb-4">
        To enable PWA support, simply set <code>"pwa": true</code> in your <code>crown.json</code> configuration file:
      </p>

      <div class="bg-slate-900 rounded-xl p-4 mb-8 overflow-x-auto shadow-inner">
        <pre><code class="language-json text-sm text-slate-200">{{
  "port": 5000,
  "tailwind": true,
  "pwa": true
}}</code></pre>
      </div>

      <p class="text-slate-600 mb-8">
        Once enabled, run <code>crown dev</code> or <code>crown build</code>. Crown will automatically generate a
        <code>manifest.json</code> and a <code>sw.js</code> (Service Worker) in your <code>public/</code> directory.
      </p>

      <h2 class="text-2xl font-bold text-slate-900 mt-12 mb-6 border-b border-slate-200 pb-2">
        Offline Request Queuing & Background Sync
      </h2>

      <p class="text-slate-600 mb-4">
        Crown's Service Worker goes beyond simple caching. It intelligently intercepts API requests when the user is offline:
      </p>

      <ul class="list-disc pl-6 mb-8 text-slate-600 space-y-2">
        <li><strong>GET Requests:</strong> Cached automatically using a Network-First strategy. If offline, the last cached version is served.</li>
        <li><strong>POST/PUT/DELETE Requests:</strong> If offline, these requests are safely stored in the browser's <strong>IndexedDB</strong> queue.</li>
        <li><strong>HTMX Integration:</strong> If an HTMX request is queued while offline, Crown returns a special HTML snippet alerting the user that the action was saved locally.</li>
        <li><strong>Background Sync:</strong> The moment the device regains connectivity, the Service Worker automatically flushes the queue, replaying the stored requests to the server in order.</li>
      </ul>

      <h2 class="text-2xl font-bold text-slate-900 mt-12 mb-6 border-b border-slate-200 pb-2">
        Disabling PWA
      </h2>

      <p class="text-slate-600 mb-4">
        If you decide to turn off PWA support, simply change the setting to <code>"pwa": false</code> in <code>crown.json</code>.
        Crown will automatically inject a script into your pages that securely <strong>unregisters</strong> any existing Service Workers
        from users' browsers, preventing stale caches or "zombie" apps.
      </p>

    </div>
  """
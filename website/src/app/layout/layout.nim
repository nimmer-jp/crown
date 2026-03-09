import crown/core

proc layout*(content: string): string =
  let jsScript = """
      <script>
        document.addEventListener('DOMContentLoaded', () => {
          const searchModal = document.getElementById('search-modal');
          const searchInput = document.getElementById('search-input');
          const searchResults = document.getElementById('search-results');
          const closeBtn = document.getElementById('close-search');

          // Mock Documentation Data
          const docs = [
            { title: 'Getting Started', url: '/docs', desc: 'Installation and setup guide for Crown Framework.' },
            { title: 'File-System Routing', url: '/docs/routing', desc: 'Learn how routes map to files in the src/app directory.' },
            { title: 'Layout Inheritance', url: '/docs/layout_inheritance', desc: 'Compose complex UIs naturally with deeply nested layouts.' },
            { title: 'Native Client Sync', url: '/docs/interactivity', desc: 'Add interactive features with HTMX-like custom attributes.' },
            { title: 'API Routes', url: '/api/save', desc: 'Create JSON endpoints alongside your pages.' },
            { title: 'Editor Demo', url: '/editor', desc: 'Try the nested layout and state preservation demo.' }
          ];

          const openSearch = () => {
            searchModal.classList.remove('hidden');
            searchModal.classList.add('flex');
            setTimeout(() => searchInput.focus(), 10);
            renderResults('');
          };

          const closeSearch = () => {
            searchModal.classList.add('hidden');
            searchModal.classList.remove('flex');
            searchInput.value = '';
          };

          const renderResults = (query) => {
            const q = query.toLowerCase();
            const filtered = docs.filter(d => d.title.toLowerCase().includes(q) || d.desc.toLowerCase().includes(q));
            
            if (filtered.length === 0) {
              searchResults.innerHTML = '<div class="p-8 text-center text-slate-500">No results found for "' + query + '"</div>';
              return;
            }

            searchResults.innerHTML = filtered.map(d => `
              <a href="${d.url}" onclick="document.getElementById('search-modal').classList.add('hidden')" class="block p-4 hover:bg-indigo-50 border-b border-slate-100 last:border-0 transition-colors group">
                <div class="font-bold text-indigo-700 group-hover:text-indigo-800">${d.title}</div>
                <div class="text-sm text-slate-500 mt-1">${d.desc}</div>
              </a>
            `).join('');
          };

          // Event Listeners
          document.addEventListener('keydown', (e) => {
            if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
              e.preventDefault();
              if (searchModal.classList.contains('hidden')) {
                openSearch();
              } else {
                closeSearch();
              }
            }
            if (e.key === 'Escape' && !searchModal.classList.contains('hidden')) {
              closeSearch();
            }
          });

          document.getElementById('search-button').addEventListener('click', openSearch);
          closeBtn.addEventListener('click', closeSearch);
          searchModal.addEventListener('click', (e) => {
            if (e.target === searchModal) closeSearch();
          });
          
          searchInput.addEventListener('input', (e) => renderResults(e.target.value));
        });
      </script>
  """

  return html"""
    <html class="h-full">
    <head>
      <title>Crown Framework | Professional Meta-Framework</title>
      <meta name="viewport" content="width=device-width, initial-scale=1">
      {jsScript}
    </head>
    <body class="h-full bg-[radial-gradient(ellipse_at_top_left,_var(--tw-gradient-stops))] from-slate-50 via-white to-indigo-50/30 text-slate-900 antialiased selection:bg-indigo-100 selection:text-indigo-900 relative">
      
      <!-- Search Modal -->
      <div id="search-modal" class="hidden fixed inset-0 z-50 bg-slate-900/50 backdrop-blur-sm items-start justify-center pt-20 px-4">
        <div class="bg-white w-full max-w-2xl rounded-2xl shadow-2xl overflow-hidden animate-fade-in border border-slate-200">
          <div class="flex items-center px-4 py-3 border-b border-slate-100">
            <span class="text-slate-400 text-xl mr-3">🔍</span>
            <input type="text" id="search-input" placeholder="Search documentation..." class="flex-grow bg-transparent border-none focus:outline-none text-lg text-slate-800 placeholder-slate-400 py-2">
            <button id="close-search" class="px-2 py-1 bg-slate-100 text-slate-500 text-xs rounded-md border border-slate-200 hover:bg-slate-200 transition-colors">ESC</button>
          </div>
          <div id="search-results" class="max-h-96 overflow-y-auto">
            <!-- Results populated by JS -->
          </div>
        </div>
      </div>

      <div class="min-h-full flex flex-col">
        <header class="sticky top-0 z-40 w-full backdrop-blur-md bg-white/70 border-b border-slate-200/60">
          <div class="max-w-5xl mx-auto px-4 h-16 flex justify-between items-center text-sm font-medium">
            <a href="/" class="flex items-center gap-2 group cursor-pointer">
              <div class="w-8 h-8 bg-indigo-600 rounded-lg flex items-center justify-center shadow-lg shadow-indigo-200 group-hover:scale-110 transition-transform">
                <span class="text-white text-lg font-bold">👑</span>
              </div>
              <span class="font-extrabold text-lg tracking-tight bg-clip-text text-transparent bg-gradient-to-r from-indigo-600 to-violet-600">Crown</span>
            </a>
            
            <nav class="hidden sm:flex items-center gap-8 text-slate-600 font-semibold">
              <a href="/docs" class="hover:text-indigo-600 transition-colors">Documentation</a>
              <a href="/editor" class="hover:text-indigo-600 transition-colors">Editor Demo</a>
              <a href="/blog/welcome" class="hover:text-indigo-600 transition-colors">Blog</a>
            </nav>

            <div class="flex items-center gap-4">
              <button id="search-button" class="group flex items-center justify-between w-48 sm:w-64 bg-slate-100/50 hover:bg-slate-100 border border-slate-200/60 text-slate-500 px-3 py-2 rounded-xl transition-all shadow-sm">
                <span class="flex items-center gap-2"><span class="opacity-70">🔍</span> Search...</span>
                <div class="hidden sm:flex items-center gap-1 text-xs font-mono bg-white px-1.5 py-0.5 rounded shadow-sm border border-slate-200 text-slate-400">
                  <kbd>⌘</kbd><kbd>K</kbd>
                </div>
              </button>
              <button class="hidden sm:block px-4 py-2 bg-slate-900 text-white rounded-full hover:bg-slate-800 transition-all shadow-md hover:shadow-lg active:scale-95">Get Started</button>
            </div>
          </div>
        </header>

        <main class="flex-grow py-12 px-4 text">
          <div class="max-w-5xl mx-auto">
            {content}
          </div>
        </main>

        <footer class="py-12 border-t border-slate-200/60 bg-white/30 backdrop-blur-sm">
          <div class="max-w-5xl mx-auto px-4 flex flex-col md:flex-row justify-between items-center gap-6">
            <div class="flex items-center gap-2">
              <span class="font-bold text-slate-400">Crown Framework</span>
              <span class="text-slate-300">|</span>
              <p class="text-slate-400">© 2026 Nim Meta-Framework Team</p>
            </div>
            <div class="flex gap-6 text-slate-400 font-medium">
              <a href="/docs" class="hover:text-slate-600 transition-colors">Documentation</a>
              <a href="#" class="hover:text-slate-600 transition-colors">GitHub</a>
              <a href="#" class="hover:text-slate-600 transition-colors">Twitter</a>
            </div>
          </div>
        </footer>
      </div>
    </body>
    </html>
  """
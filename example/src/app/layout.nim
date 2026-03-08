import crown/core

proc layout*(content: string): string =
  return html"""
    <html class="h-full">
    <head>
      <title>Crown Framework | Professional Meta-Framework</title>
      <meta name="viewport" content="width=device-width, initial-scale=1">
    </head>
    <body class="h-full bg-[radial-gradient(ellipse_at_top_left,_var(--tw-gradient-stops))] from-slate-50 via-white to-indigo-50/30 text-slate-900 antialiased selection:bg-indigo-100 selection:text-indigo-900">
      <div class="min-h-full flex flex-col">
        <header class="sticky top-0 z-40 w-full backdrop-blur-md bg-white/70 border-b border-slate-200/60">
          <div class="max-w-5xl mx-auto px-4 h-16 flex justify-between items-center text-sm font-medium">
            <div class="flex items-center gap-2 group cursor-pointer">
              <div class="w-8 h-8 bg-indigo-600 rounded-lg flex items-center justify-center shadow-lg shadow-indigo-200 group-hover:scale-110 transition-transform">
                <span class="text-white text-lg font-bold">👑</span>
              </div>
              <span class="font-extrabold text-lg tracking-tight bg-clip-text text-transparent bg-gradient-to-r from-indigo-600 to-violet-600">Crown</span>
            </div>
            
            <nav class="hidden sm:flex items-center gap-8 text-slate-600 font-semibold">
              <a href="/" class="hover:text-indigo-600 transition-colors">Framework</a>
              <a href="/editor" class="hover:text-indigo-600 transition-colors">Editor Demo</a>
              <a href="/blog/welcome" class="hover:text-indigo-600 transition-colors">Blog</a>
            </nav>

            <div class="flex items-center gap-3">
              <button class="px-4 py-2 bg-slate-900 text-white rounded-full hover:bg-slate-800 transition-all shadow-md hover:shadow-lg active:scale-95">Get Started</button>
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
              <a href="#" class="hover:text-slate-600 transition-colors">Documentation</a>
              <a href="#" class="hover:text-slate-600 transition-colors">GitHub</a>
              <a href="#" class="hover:text-slate-600 transition-colors">Twitter</a>
            </div>
          </div>
        </footer>
      </div>
    </body>
    </html>
  """

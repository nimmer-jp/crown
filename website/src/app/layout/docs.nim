import crown/core
import ./layout as main_layout

proc layout*(content: string): string =
  let activeScript = """
    <script>
      document.addEventListener('DOMContentLoaded', () => {
        const currentPath = window.location.pathname;
        const links = document.querySelectorAll('#docs-sidebar a');
        links.forEach(link => {
          // Remove active classes
          link.classList.remove('text-indigo-600', 'font-medium', 'bg-indigo-50');
          link.classList.add('text-slate-600');
          
          // Add active classes for current path
          if (link.getAttribute('href') === currentPath || (currentPath === '/docs' && link.getAttribute('href') === '/docs/')) {
            link.classList.add('text-indigo-600', 'font-medium', 'bg-indigo-50');
            link.classList.remove('text-slate-600', 'hover:text-indigo-600', 'hover:bg-indigo-50');
          }
        });
      });
    </script>
  """
  
  let docsContent = html"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 flex flex-col md:flex-row gap-8">
      {activeScript}
      <!-- Sidebar Navigation -->
      <aside class="w-full md:w-64 flex-shrink-0 md:block border-b md:border-b-0 md:border-r border-slate-200 pb-8 md:pb-0 md:pr-8">
        <nav id="docs-sidebar" class="md:sticky top-24 space-y-8">
          <div>
            <h3 class="font-bold text-slate-900 mb-3 px-3 text-sm uppercase tracking-wider">Overview</h3>
            <ul class="space-y-1">
              <li>
                <a href="/docs" class="block px-3 py-2 text-sm text-slate-600 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors">Getting Started</a>
              </li>
            </ul>
          </div>
          <div>
            <h3 class="font-bold text-slate-900 mb-3 px-3 text-sm uppercase tracking-wider">Core Concepts</h3>
            <ul class="space-y-1">
              <li>
                <a href="/docs/routing" class="block px-3 py-2 text-sm text-slate-600 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors">File-System Routing</a>
              </li>
              <li>
                <a href="/docs/layout_inheritance" class="block px-3 py-2 text-sm text-slate-600 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors">Layout Inheritance</a>
              </li>
              <li>
                <a href="/docs/interactivity" class="block px-3 py-2 text-sm text-slate-600 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors">Native Client Sync</a>
              </li>
              <li>
                <a href="/docs/pwa" class="block px-3 py-2 text-sm text-slate-600 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors">Zero-Config PWA</a>
              </li>
            </ul>
          </div>
        </nav>
      </aside>

      <!-- Main Content Area -->
      <div class="flex-1 min-w-0 animate-fade-in">
        <div class="prose prose-slate max-w-none text-slate-600">
          {content}
        </div>
      </div>
    </div>
  """
  return main_layout.layout(docsContent)

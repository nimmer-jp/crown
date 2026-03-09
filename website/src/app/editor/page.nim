import crown/core
import tiara

proc post*(req: Request): string =
  let content = req.postParams.getOrDefault("content", "")
  return html"""
    {Tiara.toast(message="保存しました！ (入力内容: " & content & ")")}
  """

proc page*(req: Request): string =
  let initialContent = "Hello, Crown Framework! 👑"
  return html"""
    <div class="max-w-3xl mx-auto space-y-12 py-8">
      <div class="space-y-4">
        <h1 class="text-4xl font-extrabold tracking-tight text-slate-900 line-tight">
          Crown Editor
        </h1>
        <p class="text-lg text-slate-500 leading-relaxed font-medium">
          Experience seamless, reactive updates with zero-JS server-side rendering.
        </p>
      </div>

      <div class="relative">
        <!-- Floating decoration -->
        <div class="absolute -top-6 -left-6 w-12 h-12 bg-indigo-600/10 rounded-full blur-2xl"></div>
        <div class="absolute -bottom-6 -right-6 w-12 h-12 bg-violet-600/10 rounded-full blur-2xl"></div>

        <form 
          crown-post="/editor" 
          crown-target="#save-status" 
          class="relative bg-white/80 backdrop-blur-xl p-10 rounded-[2.5rem] shadow-2xl shadow-indigo-100 border border-slate-200/60 overflow-hidden"
        >
          <div class="space-y-8">
            <div class="space-y-3">
              <label class="block text-sm font-bold text-slate-400 uppercase tracking-widest px-1">Content Editor</label>
              <textarea 
                name="content" 
                rows="6" 
                class="w-full p-6 bg-slate-50 border border-slate-100 rounded-3xl text-slate-900 focus:ring-4 focus:ring-indigo-500/10 focus:border-indigo-500/30 transition-all font-medium text-lg placeholder:text-slate-300 resize-none"
                placeholder="Enter your thoughts here..."
              >{initialContent}</textarea>
            </div>
            
            <button 
              type="submit" 
              class="w-full group relative py-5 bg-slate-900 text-white font-bold rounded-3xl shadow-xl hover:shadow-indigo-200 hover:bg-slate-800 transition-all active:scale-[0.98] overflow-hidden"
            >
              <span class="relative z-10 flex items-center justify-center gap-2">
                Save Changes 
                <span class="group-hover:translate-x-1 transition-transform">→</span>
              </span>
              <div class="absolute inset-0 bg-gradient-to-r from-indigo-600 to-violet-600 opacity-0 group-hover:opacity-100 transition-opacity"></div>
            </button>
          </div>
        </form>
      </div>

      <div id="save-status" class="min-h-[80px]">
        <!-- Notifications will appear here -->
      </div>

      <div class="flex justify-center">
        <a href="/" class="group inline-flex items-center gap-2 text-slate-400 font-bold hover:text-indigo-600 transition-colors">
          <span class="group-hover:-translate-x-1 transition-transform">←</span>
          Return to Dashboard
        </a>
      </div>
    </div>
  """

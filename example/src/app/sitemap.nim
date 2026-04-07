import crown/core

proc sitemap*(req: Request): string =
  ## Served at GET /sitemap.xml
  let host = getEnv("PUBLIC_HOST", "http://localhost:5000")
  return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" &
      "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n" &
      "  <url><loc>" & host & "/</loc></url>\n" &
      "  <url><loc>" & host & "/editor</loc></url>\n" &
      "</urlset>\n"

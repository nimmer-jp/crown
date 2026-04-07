import crown/core

proc robots*(req: Request): string =
  ## Served at GET /robots.txt
  "User-agent: *\nAllow: /\n"

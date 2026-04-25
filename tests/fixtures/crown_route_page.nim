import crown/core

proc page*(req: Request): Response =
  discard req
  htmlResponse("ok")

proc layout*(content: string): string =
  "<main>" & content & "</main>"

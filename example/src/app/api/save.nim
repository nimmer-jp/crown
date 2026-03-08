import crown/core

proc post*(req: Request): Response =
  let content = req.params.getStr("content")
  let responseData = %*{
    "status": "success",
    "message": "Data saved successfully!",
    "savedContent": content
  }
  return jsonResponse(responseData)

proc get*(req: Request): Response =
  let data = %*{
    "status": "ok",
    "message": "Crown API is running",
    "version": "0.1.0"
  }
  return jsonResponse(data)

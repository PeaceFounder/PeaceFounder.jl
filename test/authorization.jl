import PeaceFounder.Authorization: AuthClientMiddleware, AuthServerMiddleware
import HTTP: Request, Response


credential = "identifier"
secret = rand(UInt8, 10)

server = AuthServerMiddleware(req -> Response(200, "Hello World ($(String(copy(req.body))))"), credential, secret)
client = AuthClientMiddleware(server, credential, secret)

response = client(Request("GET", "/test", ["Host"=>"peacefounder.org"], "Hello World"))

using SMTPClient

isdefined(@__MODULE__,:password) || (password = readline())
url = "smtps://smtp.gmail.com:465" 

opt = SendOptions(
    isSSL = true,
    username = "akels14@gmail.com",
    passwd = password,verbose=true)

body = IOBuffer(
    """
    From: akels14@gmail.com
    To: graphitewriter@gmail.com
    Subject: Julia Test 2

    Test Message 23
    """
)


from = "akels14@gmail.com"

rcpt = ["graphitewriter@gmail.com"]

resp = send(url, rcpt, from, body, opt)


module Authorization

# Note: HTTP requests can be malicioulsy reordered during transmission. It's crucial to design APIs 
# to be resilient against reordering so that unintended state changes would not be possible. 
# Additionally, short timeout periods for requests should be used.

# The authorization HMAC functions

# TODO: 
# - think about a cleanup
# - parametrize hash function
# - make verify more verbose

using Base64
using Nettle
using Dates
using HTTP: Request, Response

sha256(data) = Nettle.digest("sha256", data)
sha256(data, key) = Nettle.digest("sha256", key, data)

function get_header(headers, key)

    for (keyi, value) in headers
        if  keyi == key
            return value
        end
    end

    return nothing
end

verify(request::Union{Request, Response}, secret::String) = verify(request, base64decode(secret))

function verify(method, target, headers, body, secret::Vector{UInt8})

    # Compute content hash
    contentHash = Base64.base64encode(sha256(body))

    # Extract received content hash and signature
    contentHashReceived = get_header(headers, "x-ms-content-sha256")
    authorizationHeader = get_header(headers, "Authorization")
    signatureReceived = split(authorizationHeader, "&Signature=")[end]

    # Verify content hash
    if contentHash != contentHashReceived
        return false
    end

    # Recreate string to sign
    utcNow = get_header(headers, "x-ms-date")
    host = get_header(headers, "Host")
    signedHeaders = "x-ms-date;host;x-ms-content-sha256"
    stringToSign = join([method, target, join([utcNow, host, contentHashReceived], ";")], '\n')

    # Recreate the HMAC signature
    hmac = sha256(stringToSign, secret)
    signature = base64encode(hmac)

    # Verify the signature
    return signature == signatureReceived
end

verify(req::Request, secret::Vector{UInt8}) = verify(req.method, req.target, req.headers, req.body, secret)
verify(resp::Response, target, secret::Vector{UInt8}) = verify("REPLY", target, resp.headers, resp.body, secret)


signRequest(host, method, url, body, credential, secret::String) = signRequest(host, method, url, body, credential, base64decode(secret))


# This one is direct implementation of the JS version
function signRequest(host, method, url, body, credential, secret::Vector{UInt8}; now = () -> Dates.now())

    contentHash = Base64.base64encode(sha256(body))

    utcNow = Dates.format(now(), "E, dd u yyyy HH:MM:SS") * " GMT"

    signedHeaders = "x-ms-date;host;x-ms-content-sha256"
    
    stringToSign = join([method, url, join([utcNow, host, contentHash], ";")], '\n')
    
    hmac = sha256(stringToSign, secret)
    signature = base64encode(hmac)

    return [
        "x-ms-date" => utcNow,
        "x-ms-content-sha256" => contentHash,
        "Authorization" => "HMAC-SHA256 Credential=" * credential * "&SignedHeaders=" * signedHeaders * "&Signature=" * signature
    ]
end


function timestamp(date_str::AbstractString)

    date_format = DateFormat("dd u yyyy HH:MM:SS")
    relevant_part = join(split(date_str)[2:end-1], " ")

    parsed_date = DateTime(relevant_part, date_format)

    return parsed_date
end


function timestamp(req::Request)
    
    datetime_string = get_header(req.headers, "x-ms-date")

    return timestamp(datetime_string)
end


function timestamp(resp::Response)

    datetime_string = get_header(resp.headers, "x-ms-date")

    return timestamp(datetime_string)
end


function credential(authorization_string::AbstractString)

    regex = r"Credential=([^&]+)"
    m = match(regex, authorization_string)

    credential = m !== nothing ? m.captures[1] : "No match found"

    return credential
end


function credential(req::Request)

    authorization = get_header(req.headers, "Authorization")

    return credential(authorization)
end


function credential(resp::Response)

    authorization = get_header(resp.headers, "Authorization")

    return credential(authorization)
end

is_same_credential(request::Request, response::Response) = credential(request) == credential(response)


using Infiltrator


# I may need to make one level deeper to call it a proper middleware
function AuthClientMiddleware(server, credential::AbstractString, secret::Union{String, Vector{UInt8}}; match_timestamps=true)
    
    return function(request::Request)
        
        (; method, target, body) = request
        host = get_header(request.headers, "Host")
        
        auth_headers = signRequest(host, method, target, body, credential, secret)
        append!(request.headers, auth_headers)

        response = server(request)

        if response.status == 200

            if match_timestamps && timestamp(request) != timestamp(response)
                return Response(502, "Timestamp of the response does not match that of the request indicating that it is response for a different request.")
            end

            # Check that signature is valid
            # This part could be more granular
            if !verify(response, request.target, secret)
                return Response(502, "Response signature invalid")
            end

            if !is_same_credential(request, response)
                @warn "Credential of the response does not match that of the request"
            end

        end
            
        return response
    end
end



function AuthServerMiddleware(handler, credential::AbstractString, secret::Union{String, Vector{UInt8}})

    return function(req::Request)

        # This part could be more granular
        if verify(req, secret)

            response = handler(req)

            host = get_header(req.headers, "Host")
            auth_headers = signRequest(host, "REPLY", req.target, response.body, credential, secret; now = () -> timestamp(req))
            
            append!(response.headers, auth_headers)
            push!(response.headers, "Host" => host)

            return response
        else
            return Response(401, "Unauthorized Access")
        end
        
    end
end


export timestamp, credential, AuthClientMiddleware, AuthServerMiddleware

end

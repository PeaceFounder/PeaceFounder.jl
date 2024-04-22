module TempAccessCodes

using Dates
using Base64
using Nettle

struct AccessCode{T} 
    credential::String
    code::Vector{UInt8}
    closes::DateTime
    permit::T
end

struct AccessList{T} 
    codes::Vector{AccessCode{T}}
    expiry_window::Int
end

AccessList{T}(; expiry_window=900) where T = AccessList{T}(AccessCode[], expiry_window)

Base.length(list::AccessList) = length(list.codes)

function Base.get(null::Function, auth_list::AccessList, credential::AbstractString; ctime = now(UTC))

    for code in auth_list.codes
        if code.credential == credential
            if code.closes > ctime
                return (code.code, code.permit)
            else
                cleanup!(auth_list; ctime)
                break
            end
        end
    end

   return null()
end

Base.get(access_list::AccessList, credential::AbstractString, default; ctime = now(UTC)) = get(() -> default, access_list, credential; ctime)

function Base.get(access_list::AccessList, credential::AbstractString; ctime = now(UTC)) 
    get(access_list, credential; ctime) do
        error("Not Found") 
    end
end

function create!(auth::AccessList{T}, credential::String, code::Vector{UInt8}, permit::T; ctime = now(UTC), show_warn = true) where T

    cleanup!(auth; ctime)

    for code in auth.codes
        if code.credential == credential
            show_warn && @warn "Access code with a given credential already exists"
            return
        end
    end
    
    closes = ctime + Second(auth.expiry_window)
    access_code = AccessCode(credential, code, closes, permit)

    push!(auth.codes, access_code)

    return
end 

# credential is derived from code. We are currently fixated on sha256 to make easy interoperability with JavaScript
# (fixation here reduces the number of dependecies on would need to manage on JS)
# Optional argument can be provided for a hasher here in the future if necessary

# A table to construct maping between crddential and key for 4 byte code is around 16GB which is somewhat insuficient
# - Use proposal UUID as additional info added to the key thus it would need to be generated on the spot
# - 

sha256(data) = Nettle.digest("sha256", data)

function credential(code::Vector{UInt8})
    _hash = sha256(code)
    return Base64.base64encode(_hash)
end

create!(auth::AccessList{T}, code::Vector{UInt8}, permit::T; ctime = now(UTC)) where T = create!(auth, credential(code), code, permit; ctime)


function cleanup!(auth::AccessList; ctime = now(UTC))
    
    i = 1

    while i <= length(auth.codes)

        code = auth.codes[i]

        if code.closes < ctime #expiry_time
            deleteat!(auth.codes, i)
        else
            i += 1
        end

    end

    return
end

end

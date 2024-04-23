module Base32

# Note: All this code was produced by ChatGPT at a second try starting with a query 
# > Can you write Crockford Base32 encode/decode in Julia?

# Define the Crockford Base32 Alphabet
const CROCKFORD_BASE32_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

# Create encoder function
function encode_crockford_base32(data::Vector{UInt8})
    bits = 0
    value = 0
    encoded = []
    base = length(CROCKFORD_BASE32_ALPHABET)

    for byte in data
        value = (value << 8) | byte
        bits += 8
        while bits >= 5
            encoded = push!(encoded, CROCKFORD_BASE32_ALPHABET[1 + (value >> (bits - 5) & 0x1F)])
            bits -= 5
        end
    end

    if bits > 0
        encoded = push!(encoded, CROCKFORD_BASE32_ALPHABET[1 + ((value << (5 - bits)) & 0x1F)])
    end

    return join(encoded)
end


function decode_crockford_base32(encoded::String)
    encoded = replace(uppercase(encoded), r"[OLIU]" => s -> s[1] == 'O' ? '0' : s[1] == 'L' ? '1' : s[1] == 'I' ? '1' : 'V')
    bits = 0
    value = 0
    decoded = UInt8[]

    for char in encoded
        n = findfirst(==(char), CROCKFORD_BASE32_ALPHABET)
        if isnothing(n)
            continue # skip invalid characters
        end
        value = (value << 5) | (n - 1)
        bits += 5
        while bits >= 8
            shift_amount = bits - 8
            decoded_byte = UInt8((value >> shift_amount) & 0xFF)
            push!(decoded, decoded_byte)
            value = value & ((1 << shift_amount) - 1)  # Mask out the bits we've already used
            bits -= 8
        end
    end

    return decoded
end


end

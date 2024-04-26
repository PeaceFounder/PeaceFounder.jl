module BitSaver

struct BitMask
    bits::BitVector
    BitMask(bits::BitVector) = new(copy(bits)) # BitMask is used for transportation and storage
end

# It may become useful to define equality between BitMask and BitVector
# This is equal in the same sense as In32(1) == Int64(1)
Base.:(==)(x::BitMask, y::BitMask) = x.bits == y.bits
Base.:(==)(x::BitVector, y::BitMask) = x == y.bits
Base.:(==)(x::BitMask, y::BitVector) = x.bits == y

Base.length(mask::BitMask) = length(mask.bits)
Base.getindex(mask::BitMask, N::Int) = mask.bits[N]

function Base.show(io::IO, mask::BitMask)
    str = join([ i ? '0' : '1' for i in mask.bits])
    print(io, str)
    print(io, " \033[90m(BitMask)\033[0m")
end

function bits2bytes(bits::BitVector)
    # Calculate padding needed to reach a multiple of 8
    padding = (8 - length(bits) % 8) % 8
    # Create a new BitVector with padding added
    padded_bits = copy(bits)
    append!(padded_bits, falses(padding))  # Corrected to `falses`

    # The first byte is the padding indicator
    result = Vector{UInt8}([UInt8(padding)])

    # Split the padded_bits into bytes and append to result
    for i in 1:8:length(padded_bits)
        push!(result, UInt8(0))
        for j in 0:7
            result[end] |= (padded_bits[i+j] << j)
        end
    end

    return result
end

function bytes2bits(bytes::Vector{UInt8})
    # First byte is the padding indicator
    padding = Int(bytes[1])
    # Initialize an empty BitVector
    bits = BitVector()

    # Process the remaining bytes
    for i in 2:length(bytes)
        byte = bytes[i]
        for j in 0:7
            push!(bits, (byte >> j) & 0x01 == 0x01)
        end
    end

    # Remove the padding bits
    resize!(bits, length(bits) - padding)
    return bits
end


function Base.convert(::Type{BitMask}, bytes::Vector{UInt8})
    bits = bytes2bits(bytes)
    return BitMask(bits)
end

function Base.convert(::Type{Vector{UInt8}}, mask::BitMask)
    bytes = bits2bytes(mask.bits)
    return bytes
end



end

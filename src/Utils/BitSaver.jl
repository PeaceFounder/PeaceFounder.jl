module BitSaver

include("BitCompressor.jl")
import .BitCompressor 

struct BitMask
    bits::BitVector
    function BitMask(bits::BitVector; internal=false)
        if internal # Assume 
            return new(bits)
        else
            if count(bits) < div(length(bits), 2) # ones are sparse
                compr_bits = BitCompressor.compress(bits)
                
                if length(compr_bits) < length(bits)
                    #@info "BitMask compressed in sparsity in ones"
                    pushfirst!(compr_bits, true) # sparsity between ones
                    pushfirst!(compr_bits, true)
                    return new(compr_bits)
                end

            else
                compr_bits = BitCompressor.compress(.!bits)

                if length(compr_bits) < length(bits)
                    #@info "BitMask compressed in sparsity in zeros"
                    pushfirst!(compr_bits, false) # sparsity between zeroes
                    pushfirst!(compr_bits, true)
                    return new(compr_bits)
                end
            end
        end

        #@info "BitMask uncompressed"
        _bits = copy(bits)
        pushfirst!(_bits, false) 
        return new(_bits)
    end
end


iscompressed(mask::BitMask) = mask.bits[1]

function is_sparse_ones(mask::BitMask) 
    @assert iscompressed(mask)
    return mask.bits[2]
end

function bits(mask::BitMask)
    if iscompressed(mask)
        bits = BitCompressor.decompress(mask.bits[3:end])
        if is_sparse_ones(mask)
            return bits
        else
            return .!bits
        end
    else
        #return mask.bits[2:end]
        return view(mask.bits, 2:length(mask.bits))
    end
end


# It may become useful to define equality between BitMask and BitVector
# This is equal in the same sense as In32(1) == Int64(1)
Base.:(==)(x::BitMask, y::BitMask) = x.bits == y.bits # comparing compressed bits
Base.:(==)(x::BitVector, y::BitMask) = x == bits(y)
Base.:(==)(x::BitMask, y::BitVector) = bits(x) == y

# While compression algorithm evolves we shall rely on bits
Base.length(mask::BitMask) = length(bits(mask))
Base.getindex(mask::BitMask, N::Int) = bits(mask)[N]

function Base.show(io::IO, mask::BitMask)
    str = join([ i ? '0' : '1' for i in bits(mask)])
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
    return BitMask(bits; internal=true)
end

function Base.convert(::Type{Vector{UInt8}}, mask::BitMask)
    bytes = bits2bytes(mask.bits)
    return bytes
end

end

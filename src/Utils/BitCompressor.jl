module BitCompressor

# The compression strategy here uses sparsity of the bits either ones or zeroes 
# The encoding simply lists spaces between ones which are encoded in a variable size integers as follows
# 0: 00
# 1: 01
# 2: 10 0010
# 3: 10 0011
# 4: 10 0101
# ...
# 16: 10 1111
# 17: 110 0001 0000

export compress, decompress

function bits2int(bv::BitVector)
    num = 0
    len = length(bv)
    for i in 1:len
        if bv[i]
            num += 2^(len - i)
        end
    end
    return num
end

function next_number(m, compressed::BitVector)

    if compressed[m] == false
        return (m + 2, Int(compressed[m + 1]))
    end

    n = 1 # n could have started from 0

    for i in m:length(compressed)
        
        if compressed[i]

            n += 1

        else
            
            s = 2^n
            
            vec = compressed[i+1:i + s]
            return (i + s + 1, bits2int(vec))

        end
    end

    return nothing
end

function get_length(compressed::BitVector)

    n = 1
    s = 0

    while n < length(compressed)
        (n, N) = next_number(n, compressed)
        s += N + 1
    end

    return s - 1
end

function decompress(compressed::BitVector) # It could be made with AbstractVector{Bool} type

    M = get_length(compressed)

    bv = BitVector((false for i in 1:M))

    n = 1
    s = 0

    while true #n < length(compressed)
        (n, N) = next_number(n, compressed)
        s += N + 1

        if s > M
            break
        else
            bv[s] = true
        end
    end
    
    return bv
end

function int2bits(n::Integer)
    # Special case for zero
    if n == 0
        return BitVector([false])
    end

    bits = []
    while n > 0
        push!(bits, n % 2 == 1)
        n = n ÷ 2
    end
    return BitVector(reverse(bits))
end


function inbits(n::Integer, c::Int, s::Int)

    N = c+s + 1
    result = BitVector((i <= c for i in 1:N))

    bits = int2bits(n)

    for j in 0:(length(bits) - 1)
        result[end-j] = bits[end-j]
    end

    return result
end


function distance2bits(N::Integer)

    s = 0

    # This special case woul be unneded if 
    # the progression would start from 2 bits instead
    if (N < 2)
        return inbits(N, 0, 1)
    end

    c = 1 # Need to start here

    while true
        
        # Number of bits allocated for the number
        nbits = 2^(c + 1)

        if (N < 2^nbits)
            return inbits(N, c, 2^(c + 1))
        end

        c += 1
    end
end

function compress(orig::BitVector)

    compressed = BitVector()
    n = 0

    for i in 1:length(orig)
        if orig[i] == true
            append!(compressed, distance2bits(i - n - 1))
            n = i
        end
    end

    # Need to commit also n
    append!(compressed, distance2bits(length(orig) - n))
    
    return compressed
end

function query_bit(compressed::BitVector, k::Int)

    n = 1
    s = 0

    while n < length(compressed)
        (n, N) = next_number(n, compressed)

        if s + 1 == k
            return true
        end

        s += N + 1
    end

    return false
end

end

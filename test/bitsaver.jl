using Test
using PeaceFounder.BitSaver: BitMask, bits2bytes, bytes2bits, BitCompressor


for i in 1:100
    original = BitVector(rand() < 0.1 for i in 1:1000)
    compressed = BitCompressor.compress(original)    
    @test BitCompressor.decompress(compressed) == original
end


for i in 1:100

    N = rand(1:10)
    bytes = rand(UInt8, N)

    padding = rand(0:7)
    bytes[1] = UInt8(padding)
    bytes[end] = bytes[end] >> padding

    @test bits2bytes(bytes2bits(bytes)) == bytes
end


for i in 1:100
    bits = BitVector(rand(0:1) for i in 1:rand(5:50))
    mask = BitMask(bits)
    @test bits == mask

    bytes = convert(Vector{UInt8}, mask)
    @test convert(BitMask, bytes) == mask
end

for i in 1:100
    bits = BitVector(rand() < 0.1 for i in 1:rand(5:50))
    mask = BitMask(bits)
    @test bits == mask
   
    bytes = convert(Vector{UInt8}, mask)
    @test convert(BitMask, bytes) == mask
end

for i in 1:100
    bits = BitVector(!(rand() < 0.1) for i in 1:rand(5:50))
    mask = BitMask(bits)
    @test bits == mask
   
    bytes = convert(Vector{UInt8}, mask)
    @test convert(BitMask, bytes) == mask
end


function compress_ratio(P)

    original = BitVector(rand() < P ? 0 : 1 for i in 1:100000)
    compressed = BitCompressor.compress(original)

    return length(compressed)/length(original)
end

# for P in 0:0.1:1
#     ratio = compress_ratio(P)
#     println("P = $P => $ratio")
# end

# P = 0.0 => 2.00002
# P = 0.1 => 1.83972
# P = 0.2 => 1.72608
# P = 0.3 => 1.656
# P = 0.4 => 1.58432
# P = 0.5 => 1.50438
# P = 0.6 => 1.37365
# P = 0.7 => 1.19634
# P = 0.8 => 0.94154
# P = 0.9 => 0.6152
# P = 1.0 => 0.00037

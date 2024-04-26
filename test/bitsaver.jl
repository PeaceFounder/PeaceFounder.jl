using Test
using PeaceFounder.BitSaver: BitMask, bits2bytes, bytes2bits

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
   
    bytes = convert(Vector{UInt8}, mask)
    @test convert(BitMask, bytes) == mask
end

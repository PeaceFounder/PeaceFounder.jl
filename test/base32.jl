using Test
import PeaceFounder.Base32: decode_crockford_base32, encode_crockford_base32

for i in 1:1000

    N = rand(1:20)
    vect = rand(UInt8, N)

    @test decode_crockford_base32(encode_crockford_base32(vect)) == vect
end

# https://cryptii.com/pipes/crockford-base32
@test "19ec85725b96db" |> hex2bytes == "37P8AWJVJVDG" |> decode_crockford_base32
@test "8288f723d00392ee7d" |> hex2bytes == "GA4FE8YG0E9EWZ8" |> decode_crockford_base32

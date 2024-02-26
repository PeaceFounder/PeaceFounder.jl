using Test
using PeaceFounder.StaticSets: StaticSet, findindex


inside = [join(rand(['a':'z'; 'A':'Z'; '0':'9'], 10)) for _ in 1:2_000_00]


set = StaticSet(inside)

for (i, el) in enumerate(inside)
    @test findindex(el, set) == i
end


outside = [join(rand(['a':'z'; 'A':'Z'; '0':'9'], 10)) for _ in 1:2_000_00]

for el in outside

    N = findindex(el, set)

    if !isnothing(N)
        @test el in inside
        continue
    end

    @test isnothing(N)
end

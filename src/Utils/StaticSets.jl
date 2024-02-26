module StaticSets


struct Link
    hash::UInt32
    index::UInt32 # I may need to use Int32
end

Base.isless(a::Link, b::Link) = isless(a.hash, b.hash) 


struct StaticSet{T}
    map::Vector{Link}
    elements::Vector{T} # assume them to be all distinct

    function StaticSet(elements::Vector{T}) where T
        
        map = Vector{Link}(undef, length(elements))

        for (i, ei) in enumerate(elements)
            _hash = Base.hash(ei)
            _hash_32 = Base.hash_64_32(_hash) # I need to mock this up for a test
            
            map[i] = Link(_hash_32, i)
        end

        sort!(map)

        return new{T}(map, elements)
    end
end

Base.length(set::StaticSet) = length(set.elements)
Base.in(element::T, set::StaticSet{T}) where T = !isnothing(findindex(element, set))


function binary_search(element::UInt32, collection::Vector{Link})

    left = 1
    right = length(collection)

    while left <= right
        mid = div(left + right, 2)
        
        pivot = collection[mid]
        if pivot.hash == element
            return mid, pivot
        elseif pivot.hash < element
            left = mid + 1  # Adjust search to the right half
        else
            right = mid - 1  # Adjust search to the left half
        end
    end

    return nothing
end


function findindex(element::T, set::StaticSet{T}) where T

    _hash = Base.hash(element) |> Base.hash_64_32

    res = binary_search(_hash, set.map)
    isnothing(res) && return nothing
    N, link = res

    element == set.elements[link.index] && return link.index

    i = N - 1
    while i >= 1 && set.map[i].hash == _hash
        index = set.map[i].index
        element == set.elements[index] && return index
        i -= 1
    end

    j = N + 1
    while j <= length(set) && set.map[j].hash == _hash
        index = set.map[j].index
        element == set.elements[index] && return index
        j += 1
    end

    return nothing
end


export StaticSet, findindex

end

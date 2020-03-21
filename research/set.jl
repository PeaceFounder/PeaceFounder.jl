struct ID
    id::BigInt
end

Base.:(==)(a::ID,b::ID) = a.id==b.id
Base.hash(a::ID, h::UInt) = Base.hash(a.id,hash(:ID, h))

a,b,c = ID(1), ID(2), ID(3)

set = Set(ID[a,b,c])


@show a in set

    

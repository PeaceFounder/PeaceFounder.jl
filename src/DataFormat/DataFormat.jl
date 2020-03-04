module DataFormat

import Serialization

function binary(x)
    io = IOBuffer()
    Serialization.serialize(io,x)
    return take!(io)
end

loadbinary(data) = Serialization.deserialize(IOBuffer(data))

### Until the file fomrat is designed.
serialize(io::IO,x) = Serialization.serialize(io,x)
deserialize(io::IO) = Serialization.deserialize(io)

export binary, loadbinary, serialize, deserialize

end

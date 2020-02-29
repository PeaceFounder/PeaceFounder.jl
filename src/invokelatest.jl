@generated function Mixer(args...)
    if findfirst(x->x<:New,args)==nothing
        return quote
            error("A method error. Please define what to do for Mixer$args")
        end
    else
        return quote
            return invokelatest(Mixer,unbox(args)...)
        end
    end
end

@generated function Braider(args...)
    if findfirst(x->x<:New,args)==nothing
        return quote
            error("A method error. Please define what to do for Braider$args")
        end
    else
        return quote
            return invokelatest(Braider,unbox(args)...)
        end
    end
end

@generated function SystemConfig(args...)
    if findfirst(x->x<:New,args)==nothing
        return quote
            error("A method error. Please define what to do for SystemConfig$args")
        end
    else
        return quote
            return invokelatest(SystemConfig,unbox(args)...)
        end
    end
end

@generated function save(args...)
    if findfirst(x->x<:New,args)==nothing
        return quote
            error("A method error. Please define what to do for save$args")
        end
    else
        return quote
            return invokelatest(save,unbox(args)...)
        end
    end
end




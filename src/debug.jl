### For debugging @async crahshes 
import Base.sync_varname
import Base.@async

macro async(expr)

    tryexpr = quote
        try
            $expr
        catch err
            @warn "error within async" exception=err # line $(__source__.line):
            @show stacktrace(catch_backtrace())
        end
    end

    thunk = esc(:(()->($tryexpr)))

    var = esc(sync_varname)
    quote
        local task = Task($thunk)
        if $(Expr(:isdefined, var))
            push!($var, task)
        end
        schedule(task)
        task
    end
end

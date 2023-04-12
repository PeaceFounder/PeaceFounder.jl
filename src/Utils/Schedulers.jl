module Schedulers

using Dates

mutable struct Scheduler
    condition::Condition
    pool_interval::Union{Int, Nothing}
    retry_interval::Union{Int, Nothing}
    delay::Int
    started::Bool
    finished::Bool
    schedule::Vector{Tuple{DateTime, <:Any}}
end

Scheduler(T; pool_interval=nothing, retry_interval=nothing, delay=0) = Scheduler(Condition(), pool_interval, retry_interval, delay, false, false, Tuple{DateTime, T}[])
Scheduler(; pool_interval=nothing, retry_interval=nothing, delay=0) = Scheduler(Nothing; pool_interval, retry_interval, delay)


Base.notify(scheduler::Scheduler) = notify(scheduler.condition)
Base.notify(scheduler::Scheduler, value) = notify(scheduler.condition, value)

Base.lock(scheduler::Scheduler) = lock(scheduler.condition)
Base.unlock(scheduler::Scheduler) = unlock(scheduler.condition)

# This seems something interesting to put in the code
function waituntil(time::DateTime)

    interval = time - now()
    
    if interval > Dates.Second(0)

        seconds = interval.value/1000
        timer = Timer(seconds)
        wait(timer)
        
    end

    return
end

function next_event(scheduler::Scheduler)

    length(scheduler.schedule) == 0 && return nothing

    timestamp, value = scheduler.schedule[1]

    _interval = timestamp - Dates.now()
    seconds = _interval.value/1000

    return seconds, value
end


isstarted(scheduler::Scheduler) = scheduler.started
isfinished(scheduler::Scheduler) = scheduler.finished


function Base.wait(scheduler::Scheduler) 

    if isstarted(scheduler) && isfinished(scheduler)

        popfirst!(scheduler.schedule)

        scheduler.started = false
        scheduler.finished = false

    end

    if isnothing(next_event(scheduler))
        wait(scheduler.condition) # It should be here
    end

    time, value = next_event(scheduler)

    if isstarted(scheduler) && !isfinished(scheduler)

        scheduler.started = true
        scheduler.finished = true

        if isnothing(scheduler.retry_interval)
            error("Retry interval not set")
        else
            Timer(timer -> notify(scheduler), scheduler.retry_interval)
            wait(scheduler.condition)
        end

    elseif !isstarted(scheduler)

        scheduler.started = true
        scheduler.finished = true
        
        if time > 0
        
            Timer(timer -> notify(scheduler), time) 
            wait(scheduler.condition) 

        end
    else
        error("Impossible scheduler state")
    end

    return value
end


function schedule!(scheduler::Scheduler, timestamp::DateTime, value)
    
    push!(scheduler.schedule, (timestamp, value))
    sort!(scheduler.schedule; lt = (x, y) -> isless(x[1], y[1]))

    notify(scheduler)
    
    return
end

schedule!(scheduler::Scheduler, timestamp::DateTime) = schedule!(scheduler, timestamp, nothing)


retry!(scheduler::Scheduler) = scheduler.finished = false;


export Scheduler, schedule!, retry!, wait, notify # wait and notify as extension from base

end

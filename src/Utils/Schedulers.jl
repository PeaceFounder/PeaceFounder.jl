module Schedulers

using Dates

"""
    mutable struct Scheduler
        condition::Condition
        pool_interval::Union{Int, Nothing}
        retry_interval::Union{Int, Nothing}
        delay::Int
        started::Bool
        finished::Bool
        schedule::Vector{Tuple{DateTime, <:Any}}
    end

Represents a waitable object which resumes at predetermined scheduled times. A typical use for it 
is in the event loop like:

    scheduler = Scheduler(; retry_interval = 1)

    schedule!(scheduler, now() + Second(1), value)

    while true
        value = wait(scheduler)
        try
            # Do some stuff
        catch
            retry!(scheduler)
        end
    end

In the event loop one manages a state machine which can succed and fail. If it succeds a scheduled time is taken out from the scheduler and proceeds waiting the next event. In the case event at scheduled time had failed the scheduler is notified with [`retry!`](@ref) method and attempts to run the event loop againafter `retry_interval` until succeeds. 
"""
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

"""
    notify(scheduler::Scheduler[, value])

Notify a scheduler with a value which is returned at `wait`.
"""
Base.notify(scheduler::Scheduler; ctime::DateTime = now(UTC)) = notify(scheduler.condition, ctime)

"""
    waituntil(time::DateTime)

Waits until given `time` is reached. 
"""
function waituntil(time::DateTime; ctime = now(UTC))

    interval = time - ctime
    
    if interval > Dates.Second(0)

        seconds = interval.value/1000
        timer = Timer(seconds)
        wait(timer)
        
    end

    return
end

"""
    next_event(scheduler::Scheduler)

Return the next event in seconds and coresponding event value. Return nothing if 
no events are scheduled.
"""
function next_event(scheduler::Scheduler; ctime = now(UTC))

    isempty(scheduler) && return nothing

    timestamp, value = scheduler.schedule[1]

    _interval = timestamp - ctime
    seconds = _interval.value/1000

    return seconds, value
end


Base.isempty(scheduler::Scheduler) = length(scheduler.schedule) == 0

isstarted(scheduler::Scheduler) = scheduler.started
isfinished(scheduler::Scheduler) = scheduler.finished

"""
    wait(scheduler::Scheduler)

Wait until next event is reached and return it's value. In the case event have run through 
smoothelly the scheduler event is droped with the next `wait` call. See also [`retry!`](@ref) method.
"""
function Base.wait(scheduler::Scheduler; ctime::DateTime = now(UTC)) 

    if isstarted(scheduler) && isfinished(scheduler)
        
        # The lock is unnecessary as long as we limit ourselves to a single thread
        popfirst!(scheduler.schedule)
        scheduler.started = false
        scheduler.finished = false

    end

    while isempty(scheduler)
        ctime = wait(scheduler.condition) # It should be here
    end

    if isstarted(scheduler) && !isfinished(scheduler)

        scheduler.started = true
        scheduler.finished = true

        if isnothing(scheduler.retry_interval)
            error("Retry interval not set")
        else
            Timer(timer -> notify(scheduler), scheduler.retry_interval)
            wait(scheduler.condition) # An external wakeup would simply retry. A new value inserted preceding would be treated first
        end

    elseif !isstarted(scheduler)

        scheduler.started = true
        scheduler.finished = true

        while (time = next_event(scheduler; ctime) |> first) > 0
            Timer(timer -> notify(scheduler), time) # If waiting happens here 
            ctime = wait(scheduler.condition) 
        end

    else
        error("Impossible scheduler state")
    end

    # next_event is called also here to ensure that latest event that could have been scheduled along others is treated first
    return next_event(scheduler) |> last
end


"""
    schedule!(scheduler::Scheduler, timestamp::DateTime[, value])

Schedule an event at `timestamp` with a provided `value`. 

    schedule!(scheduler, now() + Second(1), value)

"""
function schedule!(scheduler::Scheduler, timestamp::DateTime, value)
    
    push!(scheduler.schedule, (timestamp, value))
    sort!(scheduler.schedule; lt = (x, y) -> isless(x[1], y[1]))

    notify(scheduler)
    
    return
end

schedule!(scheduler::Scheduler, timestamp::DateTime) = schedule!(scheduler, timestamp, nothing)

"""
    retry!(scheduler::Scheduler)

Notifies the scheduler that event have run unsucesfully which reschedules it after specified `retry_time`(See [`Scheduler`](@ref)). 
"""
retry!(scheduler::Scheduler) = scheduler.finished = false;


export Scheduler, schedule!, retry!, wait, notify # wait and notify as extension from base

end

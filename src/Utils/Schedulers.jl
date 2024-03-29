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

    lock(scheduler) do 
        schedule!(scheduler, now() + Second(1), value)
    end

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
Base.notify(scheduler::Scheduler) = notify(scheduler.condition)
Base.notify(scheduler::Scheduler, value) = notify(scheduler.condition, value)

"""
    lock(scheduler::Scheduler)

Lock a scheduler. This is necessary to avoid simultanous modifications of the `schedule` field.
Note that other `Scheduler` fields are not protected with the lock as thoose are considered
internal. 
"""
Base.lock(scheduler::Scheduler) = lock(scheduler.condition)
Base.unlock(scheduler::Scheduler) = unlock(scheduler.condition)


"""
    waituntil(time::DateTime)

Waits until given `time` is reached. 
"""
function waituntil(time::DateTime)

    interval = time - now()
    
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
function next_event(scheduler::Scheduler)

    length(scheduler.schedule) == 0 && return nothing

    timestamp, value = scheduler.schedule[1]

    _interval = timestamp - Dates.now()
    seconds = _interval.value/1000

    return seconds, value
end


isstarted(scheduler::Scheduler) = scheduler.started
isfinished(scheduler::Scheduler) = scheduler.finished

"""
    wait(scheduler::Scheduler)

Wait until next event is reached and return it's value. In the case event have run through 
smoothelly the scheduler event is droped with the next `wait` call. See also [`retry!`](@ref) method.
"""
function Base.wait(scheduler::Scheduler) 

    if isstarted(scheduler) && isfinished(scheduler)
        
        # Need to test this
        #lock(scheduler) do 
        popfirst!(scheduler.schedule)
        #end

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


"""
    schedule!(scheduler::Scheduler, timestamp::DateTime[, value])

Schedule an event at `timestamp` with a provided `value`. To avoid messing up a schedule acquire 
a scheduler's lock before adding the event as:

    lock(scheduler) do
        schedule!(scheduler, now() + Second(1), value)
    end
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

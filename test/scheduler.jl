using Test
using Dates
using PeaceFounder.Schedulers

scheduler = Scheduler(; retry_interval = 1)

println("Scheduling an event")
schedule!(scheduler, now(UTC) + Second(1))
wait(scheduler)
println("Event Occured")
retry!(scheduler)
wait(scheduler)
println("Event Retried")
retry!(scheduler)
wait(scheduler)
println("Event Retried\n")

# Testing a simple way of notifying

println("Scheduling an event")
schedule!(scheduler, now(UTC) + Second(10))

task = Task() do
    wait(scheduler)
    println("Event Occured")
end 
yield(task)

notify(scheduler.condition, now(UTC) + Second(10))
wait(task)



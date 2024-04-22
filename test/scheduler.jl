using Test
using Dates
using PeaceFounder.Schedulers

scheduler = Scheduler(; retry_interval = 1)

schedule!(scheduler, now(UTC) + Second(1))

print("Hello ")
wait(scheduler)
print("World!")
retry!(scheduler)
wait(scheduler)
println("!!")

schedule!(scheduler, now(UTC) + Second(1))

print("Hello ")
wait(scheduler)
print("World!")
retry!(scheduler)
wait(scheduler)
print("!!")
retry!(scheduler)
wait(scheduler)
println("!!")
#wait(scheduler)

using Test
using Dates
using PeaceFounder.Schedulers

scheduler = Scheduler(; retry_interval = 3)

schedule!(scheduler, now() + Second(1))

print("Hello ")
wait(scheduler)
print("World!")
retry!(scheduler)
wait(scheduler)
println("!!")

schedule!(scheduler, now() + Second(1))

print("Hello ")
wait(scheduler)
print("World!")
retry!(scheduler)
wait(scheduler)
print("!!")
retry!(scheduler)
wait(scheduler)
println("!!")



using Test
using Dates
using PeaceFounder.TempAccessCodes: AccessList, create!, cleanup!

access_list = AccessList{Int}()

ctime = Dates.now()

event_A = ctime
event_B = ctime + Second(500)
event_C = event_A + Second(901)
event_D = event_B + Second(901)

create!(access_list, "Alice", UInt8[1], 1; ctime = event_A)
create!(access_list, "Bob", UInt8[2], 2; ctime = event_B)

@test (UInt8[1], 1) == get(access_list, "Alice"; ctime = event_B) do; end

create!(access_list, "Eve", UInt8[3], 3; ctime = event_C)

@test nothing == get(access_list, "Alice"; ctime = event_C) do; end

@test (UInt8[2], 2) == get(access_list, "Bob"; ctime = event_C) do; end
@test nothing == get(access_list, "Bob"; ctime = event_D) do; end

# Testing dublicates

create!(access_list, "Alice", UInt8[1], 1; ctime = event_D)
@test (UInt8[1], 1) == get(access_list, "Alice"; ctime = event_D) do; end

create!(access_list, "Eve", UInt8[3], 5; ctime = event_D, show_warn = false)

@test (UInt8[3], 3) == get(access_list, "Eve"; ctime = event_D) do; end # unafected 

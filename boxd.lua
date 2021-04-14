local component = require("component")
local computer = require("computer")
local pullSignal = computer.pullSignal
_G.BOX_CONTAINERS = {}

function kill(container)
    if BOX_CONTAINERS[container] then
        print("Container " .. container .. " was killed!")
    else
        print("No container " .. container .. " exists.")
    end
end

local function supervise(container, signal)
    if not container.paused then
        local data = {coroutine.resume(container.resume, table.unpack(signal))}

        
    end
end

local function hypervise(signal)
    if signal then
        for container in pairs(BOX_CONTAINERS) do
            if signal[1] == "key_down" or signal[1] == "key_up" or signal[1] == "clipboard" and BOX_CONTAINERS[container].component.list[signal[2]] then
                supervise(container, signal)
            end
        end
    else
        for container in pairs(BOX_CONTAINERS) do
            if BOX_CONTAINERS[container].resumeAt >= computer.uptime() then
                supervise(container, {})
            end
        end
    end
end

function start()
    computer.pullSignal = function(timeout)
        local signal = {pullSignal(timeout)}
        hypervise(signal)
        return table.unpack(signal)
    end

    print("Boxd started.")
end

function stop()
    computer.pullSignal = pullSignal
    if BOX_CONTAINERS.n > 0 then
        print("Killing containers...")
        for container in pairs(BOX_CONTAINERS) do
            BOX_CONTAINERS[container] = nil
        end
    end
    print("Boxd stopped.")
end
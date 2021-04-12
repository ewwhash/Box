local computer_global = require("computer")
local component = require("component")
local unicode = require("unicode")

local signalQueue = {}
local computer = setmetatable({
    pullSignal = function(timeout)
        local signal = {computer_global.pullSignal(timeout)}

        if signal[1] == "box-n1" then
            return table.unpack(signal, 2)
        end
    end,
    pushSignal = function(...)
        computer_global.pushSignal("box-n1", ...)
    end
}, {__index = _G})

computer.pushSignal("key_down")
print(computer.pullSignal())
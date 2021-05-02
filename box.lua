local shell = require("shell")
local component = require("component")
local computer = require("computer")
local unicode = require("unicode")
local serialization = require("serialization")
local thread = require("thread")
local process = require("process")
local coroutine_

for _, v in pairs(process.list) do
    if v.path == "/init.lua" then
        coroutine_ = v.data.coroutine_handler
        break
    end
end

local coroutine = coroutine_
coroutine.create = function(f)
    coroutine_.create(f, true)
end

local methods = require("box.methods")
local docs = require("box.docs")
local signals = require("box.signal")

local function uuid()
    local template ="xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    local random = math.random
    return string.gsub(template, "[xy]", function (c)
        local v = (c == "x") and random(0, 0xf) or random(8, 0xb)
        return string.format("%x", v)
    end)
end

local function spcall(...)
    local result = table.pack(pcall(...))
    if not result[1] then
        error(tostring(result[2]), 0)
    else
        return table.unpack(result, 2, result.n)
    end
end

local function createContainer()
    local container, libcomponent, libcomputer, sandbox

    libcomponent = {
        doc = function(address, method)
            checkArg(1, address, "string")
            checkArg(2, method, "string")
            if container.component.list[address].pass then
                return component.doc(address, method)
            end
            return docs[container.component.list[address].type] or {}
        end,
        methods = function(address)
            checkArg(1, address, "string")
            if container.component.list[address].pass then
                return component.methods(address)
            end
            return methods[container.component.list[address].type] or {}
        end,
        invoke = function(address, method, ...)
            checkArg(1, address, "string")
            checkArg(2, method, "string")
            if container.component.list[address].pass then
                return component.invoke(address, method, ...)
            end
            return spcall(container.component.list[address].callback[method], ...)
        end,
        list = function(filter, exact)
            local componentsFiltered = {}
            local componentsFilteredIndex = {}
            for address in pairs(container.component.list) do
                if not filter or (exact and container.component.list[address].type == filter or container.component.list[address].type:find(filter)) then
                    componentsFiltered[address] = container.component.list[address].type
                    table.insert(componentsFilteredIndex, {
                        address, container.component.list[address].type
                    })
                end
            end
            local i = 0
            return setmetatable(componentsFiltered, {
                __call = function()
                    i = i + 1
                    if componentsFilteredIndex[i] then
                        return componentsFilteredIndex[i][1], componentsFilteredIndex[i][2]
                    end
                end
            })
        end,
        fields = function(address) -- Legacy???
            checkArg(1, address, "string")
            return container.component.list[address].fields
        end,
        proxy = function(address)
            checkArg(1, address, "string")
            if container.component.cache[address] then
                return container.component.cache[address]
            end
            if container.component.list[address] then
                if container.component.list[address].pass then
                    return component.proxy(address)
                end
                local proxy = {address = address, type = container.component.list[address].type, slot = container.component.list[address].slot}
                for key in pairs(container.component.list[address].callback) do
                    proxy[key] = setmetatable({}, {
                        __call = function(...)
                            return libcomponent.invoke(address, key, ...)
                        end,
                        __tostring = function()
                            return libcomponent.doc(address, key) or tostring(container.component.list[address].callback[key])
                        end
                    })
                end
                container.component.cache[address] = proxy
                return proxy
            else
                return nil, "no such component"
            end
        end,
        type = function(address)
            checkArg(1, address, "string")
            return container.component.list[address].type
        end,
        slot = function(address)
            checkArg(1, address, "string")
            return container.component.list[address].slot
        end
    }

    libcomputer = {
        pullSignal = function(timeout)
            local signal = coroutine_.yield(timeout or math.huge)
            table.remove(container.signalQueue, 1)
            return table.unpack(signal or {})
        end,
        pushSignal = function(...)
            table.insert(container.signalQueue, table.pack(...))
        end,
        address = setmetatable({}, {
            __call = function()
                return container.address
            end,
            __tostring = function()
                return container.address
            end
        }),
        shutdown = function() 
            container.coroutine = nil
            coroutine_.yield(0)
        end,
        getDeviceInfo = function() return {} end,
        tmpAddress = computer.tmpAddress,
        freeMemory = computer.freeMemory,
        totalMemory = computer.totalMemory,
        uptime = function ()
            return computer.uptime() - container.startUptime
        end,
        energy = 1000,
        maxEnergy = 1000,
        users = {},
        addUser = function() return false end,
        removeUser = function() return false end,
        beep = computer.beep,
        getProgramLocations = computer.getProgramLocations,
        getArchitecture = computer.getArchitecture,
        getArchitectures = computer.getArchitectures,
        setArchitecture = function() end,
    }

    sandbox = {
        assert = assert,
        error = error,
        getmetatable = getmetatable,
        next = next,
        pairs = pairs,
        pcall = pcall,
        rawequal = rawequal,
        rawget = rawget,
        rawlen = rawlen,
        rawset = rawset,
        select = select,
        setmetatable = setmetatable,
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        _VERSION = _VERSION,
        xpcall = xpcall,
        coroutine = {
            create = coroutine_.create,
            resume = coroutine_.resume,
            running = coroutine_.running,
            status = coroutine_.status,
            wrap = coroutine_.wrap,
            yield = function(...)
                return coroutine_.yield(nil, ...)
            end,
            isyieldable = coroutine_.isyieldable
        },
        string = string,
        table = table,
        math = math,
        bit32 = bit32,
        os = {
            clock = os.clock,
            date = os.date,
            difftime = os.difftime,
            time = os.time
        },
        ipairs = ipairs,
        debug = debug,
        utf8 = utf8,
        checkArg = checkArg,
        component = libcomponent,
        computer = libcomputer,
        unicode = unicode
    }
    sandbox._G = sandbox

    container = {
        address = uuid(),
        coroutine = nil,
        signalQueue = {},
        startUptime = 0,
        sandbox = sandbox,
        component = {
            add = function(type, slot, callbacks)
                local UUID
                repeat
                    UUID = uuid()
                until not container.component.list[UUID] and not component.type(UUID)
                
                container.component.list[UUID] = {
                    address = UUID, 
                    type = type, 
                    slot = slot, 
                    callback = setmetatable(callbacks, {
                        __index = function()
                            error("no such method")
                        end
                    }),
                    fields = {}
                }

                container.sandbox.computer.pushSignal("component_added", UUID, type)
            end,
            remove = function(address)
                if container.component.list[address] then
                    container.sandbox.computer.pushSignal("component_removed", address, container.component.list[address].type)
                    container.component.list[address] = nil
                end
            end,
            pass = function(address)
                if component.get(address) then
                    container.component.list[address] = container.component.list[address] or {
                        address = address,
                        type = component.type(address),
                        slot = component.slot(address),
                        fields = component.fields(address),
                        pass = true
                    }

                    return true
                else
                    return false, "component " .. address .. "is not available"
                end
            end,
            list = {},
            cache = {}
        },
        bootstrap = function(code)            
            local chunk, err = load(code, "=container", "t", container.sandbox)

            if chunk then
                container.coroutine = coroutine_.create(function()
                    coroutine_.yield("error", xpcall(chunk, debug.traceback))
                end)
                return true
            end

            return chunk, err
        end,
        resume = function()
            if container.coroutine then
                if container.paused then
                    return false, "container is paused"
                end

                local result = table.pack(coroutine_.resume(container.coroutine, container.signalQueue[1]))

                if result[1] then -- coroutine resume successfull
                    if result[2] == "error" then
                        return false, result[4]
                    end
                    if result[2] == "SHUTDOWN" then
                        container.coroutine = nil
                        return true, "shutdown"
                    end
                    if result[2] == nil then
                        return true, math.huge
                    end
                    if type(result[2]) == "number" then
                        return true, result[2]
                    end
                    return false
                end
                
                return false, result[2] -- probably coroutine is dead
            end
            
            return false, "container is shut down"
        end,
        state = function()
            container.paused = not container.paused
        end,
        passSignal = function(signal)
            if signals[signal[1]] then
                return signals[signal[1]](container, signal)
            end
            return false
        end,
    }

    return container
end

local container = createContainer()
container.component.pass(component.gpu.address) -- gpu
container.component.pass(component.screen.address) -- screen
container.component.pass(component.keyboard.address) -- keyboard
container.component.pass(computer.tmpAddress())
container.component.pass(component.internet.address)
container.component.pass(component.computer.address)
container.component.pass(component.eeprom.address)
container.component.pass(component.get("2da")) -- boot drive

local file = io.open("/home/box/eeprom.lua", "r")
local data = file:read("a")
file:close()

container.bootstrap(data)

local function supervisor() 
    while true do
        local success, result = container.resume()

        if success then
            if container.coroutine then
                if not container.signalQueue[1] then
                    local deadline = computer.uptime() + result -- result is always number if coroutine is alive

                    repeat
                        local signal = {computer.pullSignal(deadline - computer.uptime())}

                        if container.passSignal(signal) then
                            break
                        end
                    until computer.uptime() >= deadline
                end
            else
                print(result)
            end
        else
            print(result or "unknown error")
            break
        end
    end
end

supervisor()
container = nil
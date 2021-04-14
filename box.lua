local shell = require("shell")
local component = require("component")
local computer = require("computer")
local unicode = require("unicode")
local serialization = require("serialization")
local thread = require("thread")

local methods = require("box.methods")
local docs = require("box.docs")

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

local function createSandbox()
    local sandbox, libcomponent, libcomputer, env
    local components, cache, signalQueue = {}, {}, {}

    libcomponent = {
        doc = function(address, method)
            checkArg(1, address, "string")
            checkArg(2, method, "string")
            if components[address].pass then
                return component.doc(address, method)
            end
            return docs[components[address].type] or {}
        end,
        methods = function(address)
            checkArg(1, address, "string")
            if components[address].pass then
                return component.methods(address)
            end
            return methods[components[address].type] or {}
        end,
        invoke = function(address, method, ...)
            checkArg(1, address, "string")
            checkArg(2, method, "string")
            if components[address].pass then
                return component.invoke(address, method, ...)
            end
            return spcall(components[address].callback[method], ...)
        end,
        list = function(filter, exact)
            local componentsFiltered = {}
            local componentsFilteredIndex = {}
            for address in pairs(components) do
                if not filter or (exact and components[address].type == filter or components[address].type:match(filter)) then
                    componentsFiltered[address] = components[address].type
                    table.insert(componentsFilteredIndex, {
                        address, components[address].type
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
            return components[address].fields
        end,
        proxy = function(address)
            checkArg(1, address, "string")
            if cache[address] then
                return cache[address]
            end
            if components[address] then
                if components[address].pass then
                    return component.proxy(address)
                end
                local proxy = {address = address, type = components[address].type, slot = components[address].slot}
                for key in pairs(components[address].callback) do
                    proxy[key] = setmetatable({}, {
                        __call = function(...)
                            return libcomponent.invoke(address, key, ...)
                        end,
                        __tostring = function()
                            return libcomponent.doc(address, key) or tostring(components[address].callback[key])
                        end
                    })
                end
                cache[address] = proxy
                return proxy
            else
                return nil, "no such component"
            end
        end,
        type = function(address)
            checkArg(1, address, "string")
            return components[address].type
        end,
        slot = function(address)
            checkArg(1, address, "string")
            return components[address].slot
        end
    }

    libcomputer = {
        pullSignal = function(timeout)
            local signal = coroutine.yield(timeout or math.huge)
            table.remove(sandbox.signalQueue, 1)
            return table.unpack(signal or {})
        end,
        pushSignal = function(...)
            table.insert(signalQueue, table.pack(...))
        end,
        address = setmetatable({}, {
            __call = function()
                return sandbox.address
            end,
            __tostring = function()
                return sandbox.address
            end
        }),
        shutdown = function() coroutine.yield(true) end,
        getDeviceInfo = function() return {} end,
        tmpAddress = computer.tmpAddress,
        totalMemory = computer.totalMemory,
        uptime = function ()
            return computer.uptime() - sandbox.startUptime
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

    env = {
        _G = nil,
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
            create = coroutine.create,
            resume = coroutine.resume,
            running = coroutine.running,
            status = coroutine.status,
            wrap = coroutine.wrap,
            yield = function(...)
                return coroutine.yield(nil, ...)
            end,
            isyieldable = coroutine.isyieldable
        },
        string = string,
        table = table,
        math = math,
        bit32 = bit32,
        os = {
            clock = os.clock,
            date = os.date,
            difftime = os.difftime,
            execute = nil,
            exit = nil,
            remove = nil,
            rename = nil,
            time = os.time,
            tmpname = nil
        },
        debug = debug,
        utf8 = utf8,
        checkArg = checkArg,
        component = libcomponent,
        computer = libcomputer,
        unicode = unicode,
        print = print
    }
    env._G = env

    sandbox = {
        address = uuid(),
        coroutine = nil,
        signalQueue = signalQueue,
        startUptime = 0,
        env = env,
        component = {
            add = function(type, slot, callbacks)
                local UUID
                repeat
                    UUID = uuid()
                until not components[UUID] and not component.type(UUID)
                
                components[UUID] = {
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

                sandbox.env.computer.pushSignal("component_added", UUID, type)
            end,
            remove = function(address)
                if components[address] then
                    sandbox.env.computer.pushSignal("component_removed", address, components[address].type)
                    components[address] = nil
                end
            end,
            pass = function(address)
                if component.get(address) then
                    if not components[address] then
                        components[address] = {
                            address = address,
                            type = component.type(address),
                            slot = component.slot(address),
                            fields = component.fields(address),
                            pass = true
                        }
                    end

                    return true
                else
                    return false, "component " .. address .. "is not available"
                end
            end,
            list = components,
            cache = cache
        },
        bootstrap = function(code)            
            local chunk, err = load(code, "=container", "t", env)

            if chunk then
                sandbox.coroutine = (
                    function()
                        coroutine.yield(xpcall(chunk, debug.traceback))
                    end
                )
                return true
            end
            return chunk, err
        end,
        pause = function()
            sandbox.paused = true
        end,
        resume = function()
            sandbox.paused = false
        end
    }

    return sandbox
end

_G. sandbox = createSandbox()
sandbox.component.pass(component.get('eec')) -- gpu
sandbox.component.pass(component.get('6e1')) -- screen
sandbox.component.pass(component.get('33c')) -- keyboard
sandbox.component.pass(component.internet.address)
sandbox.component.pass(component.computer.address)
sandbox.component.pass(component.eeprom.address)

local file = io.open("./bootstrap-test.lua", "r")
local data = file:read("a")
file:close()

sandbox.bootstrap(data)

-- local event, hypervisor = require("event")

-- local function ignoreEvents()
--     event.ignore("key_down", hypervisor)
--     event.ignore("key_up", hypervisor)
--     event.ignore("clipboard", hypervisor)
-- end

-- local function resume()
--     if not sandbox.paused then
--         local data = {coroutine.resume(sandbox.coroutine, sandbox.signalQueue[1])}

--         if data[2] then
--             if type(data[2]) == "number" then
--                 event.timer(data[2], resume)
--             else
--                 ignoreEvents()
--                 sandbox = nil
--             end
--         else
--             debug_print(data[3])
--             ignoreEvents()
--             sandbox = nil
--         end
--     end
-- end

-- function hypervisor(...)
--     local signal = {...}
--     if sandbox.component.list[signal[2]] then
--         table.insert(sandbox.signalQueue, 1, signal)
--         event.cancel(resumeTimer)
--         resume()
--     end
-- end

-- event.listen("key_down", hypervisor)
-- event.listen("key_up", hypervisor)
-- event.listen("clipboard", hypervisor)
-- resume()b

local function supervisor() 
    while true do    
        local data = {coroutine.resume(sandbox.coroutine, sandbox.signalQueue[1])}
        
        if sandbox.paused then
            break
        elseif data[1] then
            if type(data[2]) == "number" then
                local deadline = computer.uptime() + (data[2])

                repeat
                    local signal = {computer.pullSignal(deadline - computer.uptime())}

                    if signal[1] == "key_down" or signal[1] == "key_up" or signal[1] == "clipboard" and sandbox.component.list[signal[2]] then
                        table.insert(sandbox.signalQueue, 1, signal)
                        break
                    end
                until computer.uptime() >= deadline
            else
                break
            end
        else
            print(data[2])
        end
    end
end

thread.create(supervisor):detach():attach(2)
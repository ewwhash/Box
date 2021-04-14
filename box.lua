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

local function createContainer()
    local container, libcomponent, libcomputer, sandbox
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
                if not filter or (exact and components[address].type == filter or components[address].type:find(filter)) then
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
            table.remove(container.signalQueue, 1)
            return table.unpack(signal or {})
        end,
        pushSignal = function(...)
            table.insert(signalQueue, table.pack(...))
        end,
        address = setmetatable({}, {
            __call = function()
                return container.address
            end,
            __tostring = function()
                return container.address
            end
        }),
        shutdown = function() coroutine.yield("SHUTDOWN") end,
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
        signalQueue = signalQueue,
        startUptime = 0,
        sandbox = sandbox,
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

                container.sandbox.computer.pushSignal("component_added", UUID, type)
            end,
            remove = function(address)
                if components[address] then
                    container.sandbox.computer.pushSignal("component_removed", address, components[address].type)
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
            local chunk, err = load(code, "=container", "t", sandbox)

            if chunk then
                container.coroutine = coroutine.create(
                    function()
                        coroutine.yield(xpcall(chunk, debug.traceback))
                    end
                )
                return true
            end
            return chunk, err
        end,
        pause = function()
            container.paused = true
        end,
        resume = function()
            container.paused = false
        end
    }

    return container
end

-- local event, hypervisor = require("event")

-- local function ignoreEvents()
--     event.ignore("key_down", hypervisor)
--     event.ignore("key_up", hypervisor)
--     event.ignore("clipboard", hypervisor)
-- end

-- local function resume()
--     if not container.paused then
--         local data = {coroutine.resume(container.coroutine, container.signalQueue[1])}

--         if data[2] then
--             if type(data[2]) == "number" then
--                 event.timer(data[2], resume)
--             else
--                 ignoreEvents()
--                 container = nil
--             end
--         else
--             debug_print(data[3])
--             ignoreEvents()
--             container = nil
--         end
--     end
-- end

-- function hypervisor(...)
--     local signal = {...}
--     if container.component.list[signal[2]] then
--         table.insert(container.signalQueue, 1, signal)
--         event.cancel(resumeTimer)
--         resume()
--     end
-- end

-- event.listen("key_down", hypervisor)
-- event.listen("key_up", hypervisor)
-- event.listen("clipboard", hypervisor)
-- resume()

local container = createContainer()
container.component.pass('eec093b4-7529-48a1-bd6a-b1ed5816d410') -- gpu
container.component.pass('7da60adc-bc35-43c6-a1b5-91c2c25fa7cd') -- screen
container.component.pass('f1ce1629-706a-480b-a216-863cee2906a6') -- keyboard
container.component.pass(computer.tmpAddress())
container.component.pass(component.get('807'))
container.component.pass(component.internet.address)
container.component.pass(component.computer.address)
container.component.pass(component.eeprom.address)

local file = io.open("/home/box/bootstrap-test.lua", "r")
local data = file:read("a")
file:close()

container.bootstrap(data)

local function supervisor() 
    while true do    
        local data = {coroutine.resume(container.coroutine, container.signalQueue[1])}
        
        print(table.unpack(data))
        if container.paused then
            print("PAUSED")
            break
        elseif data[1] then
            if type(data[2]) == "number" and not container.signalQueue[1] then
                local deadline = computer.uptime() + (data[2])

                repeat
                    local signal = {computer.pullSignal(deadline - computer.uptime())}

                    if container.component.list[signal[2]] and (signal[1] == "key_down" or signal[1] == "key_up" or signal[1] == "clipboard") then
                        table.insert(container.signalQueue, 1, signal)
                        break
                    end
                until computer.uptime() >= deadline
            elseif data[2] == "SHUTDOWN" then
            else -- Yield from container
                if container.signalQueue[1] then
                    coroutine.resume(container.coroutine, container.signalQueue[1])
                else
                    local signal = {computer.pullSignal()}

                    if container.component.list[signal[2]] and (signal[1] == "key_down" or signal[1] == "key_up" or signal[1] == "clipboard") then
                        coroutine.resume(container.coroutine, signal)
                    end
                end
            end
        else
            print(table.unpack(data)) -- Error encountered
            break
        end
    end
end

component.setPrimary('gpu', 'e5765f35-6570-4423-a12d-4d75457aa29c')
component.setPrimary('screen', '3973a0e2-cecf-466a-9a42-806a5f3d3ce9')
-- thread.create(supervisor):detach()
io.stdin:write("\n\n\n.!.")
io.stdin:write(xpcall(supervisor, debug.traceback))
component.setPrimary('gpu', 'e5765f35-6570-4423-a12d-4d75457aa29c')
component.setPrimary('screen', '3973a0e2-cecf-466a-9a42-806a5f3d3ce9')
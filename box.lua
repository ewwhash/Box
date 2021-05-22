local component = component or require and require("component") or error("no component library")
local computer = computer or require and require("computer") or error("no computer library")
local unicode = unicode or require and require("unicode") or error("no unicode library")

local function spcall(...)
    local result = table.pack(pcall(...))
    if not result[1] then
        error(tostring(result[2]), 0)
    else
        return table.unpack(result, 2, result.n)
    end
end

local function methodsCallback(methods)
    return setmetatable(methods, {
        __index = function()
            error("no such method")
        end
    })
end

local signals = { -- signal passthrough
    key_down = function(container, signal)
        if container.components[signal[2]] then
            return container:pushSignal(signal)
        end
        return false
    end,
    key_up = function(container, signal)
        if container.components[signal[2]] then
            return container:pushSignal(signal)
        end
        return false
    end,
    screen_resized = function(container, signal)
        if container.components[signal[2]] then
            return container:pushSignal(signal)
        end
        return false
    end,
    clipboard = function(container, signal)
        if container.components[signal[2]] then
            return container:pushSignal(signal)
        end
        return false
    end,
    touch = function(container, signal)
        if container.components[signal[2]] then
            return container:pushSignal(signal)
        end
        return false
    end,
    drag = function(container, signal)
        if container.components[signal[2]] then
            return container:pushSignal(signal)
        end
        return false
    end,
    drop = function(container, signal)
        if container.components[signal[2]] then
            return container:pushSignal(signal)
        end
        return false
    end,
    scroll = function(container, signal)
        if container.components[signal[2]] then
            return container:pushSignal(signal)
        end
        return false
    end,
    walk = function(container, signal)
        if container.components[signal[2]] then
            return container:pushSignal(signal)
        end
        return false
    end,
    redstone_chanded = function(container, signal)
        if container.components[signal[2]] then
            return container:pushSignal(signal)
        end
        return false
    end,
    motion = function(container, signal)
        if container.components[signal[2]] then
            return container:pushSignal(signal)
        end
        return false
    end,
    modem_message = function(container, signal)
        if container.components[signal[2]] then
            return container:pushSignal(signal)
        end
        return false
    end,
    component_removed = function(container, signal)
        if container.passedComponents[signal[2]] then
            return container.passedComponents[signal[2]]:detach()
        end
        return false
    end,
    component_added = function(container, signal)
        if container.passedComponents[signal[2]] then
            return container.passedComponents[signal[2]]:attach()
        end

        for address in pairs(container.components) do
            if container.components[address].type == "disk_drive" and container.components[address].pass and signal[2] == component.invoke(address, "media") then
                return container:passComponent(signal[2], true)
            end
        end

        return false
    end
}

local function uuid()
    local template ="xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    local random = math.random
    local uuid = string.gsub(template, "[xy]", function (c)
        local v = (c == "x") and random(0, 0xf) or random(8, 0xb)
        return string.format("%x", v)
    end)
    return uuid
end

local function componentUUID(container)
    local UUID
    repeat
        UUID = uuid()
    until not (container.components[UUID] or UUID == container.address)
    return UUID
end

local function resume(container)
    if container.coroutine then
        local signal = container.temp.signalQueue[1] or {}
        table.remove(container.temp.signalQueue, 1)
        local success, result, error = coroutine.resume(container.coroutine, table.unpack(signal))
        
        if success then -- coroutine resume successfull
            if result == false and error then -- error from container
                return false, error
            end
            if result == false then -- otherwise computer shutdown
                return false, "container shutdown"
            end
            if result == true then
                return container:bootstrap()
            end
            if coroutine.status(container.coroutine) == "dead" then
                return false, "container halted"
            end
            return true, result or math.huge
        end
        
        return false, result or "unknown error" -- probably coroutine is dead
    end
    
    return false, "coroutine dead"
end

local function loop(container)
    container.temp.startUptime = computer.uptime()

    while true do
        local success, result = container:resume()

        if success then
            if not container.temp.signalQueue[1] then
                local deadline = computer.uptime() + result

                repeat
                    local signal = {computer.pullSignal(deadline - computer.uptime())}

                    if container:passSignal(signal) then
                        if signal[1] == "key_down" and signal[4] == 211 then
                            return "force shutdown"
                        end

                        break
                    end
                until computer.uptime() >= deadline
            end
        else
            container.temp.clear()
            return result
        end
    end
end

local function bootstrap(container)
    container.temp.clear()
    container.temp.sandbox = {
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
        string = string,
        table = table,
        math = math,
        bit32 = bit32,
        ipairs = ipairs,
        debug = debug,
        utf8 = utf8,
        checkArg = checkArg,
        unicode = unicode,
        component = container.libcomponent,
        computer = container.libcomputer,
        coroutine = {
            create = coroutine.create,
            resume = function(co, ...) -- custom resume part for bubbling sysyields
                checkArg(1, co, "thread")
                local args = table.pack(...)
                while true do -- for consecutive sysyields
                    local result = table.pack(
                    coroutine.resume(co, table.unpack(args, 1, args.n)))
                    if result[1] then -- success: (true, sysval?, ...?)
                        if coroutine.status(co) == "dead" then -- return: (true, ...)
                            return true, table.unpack(result, 2, result.n)
                        elseif result[2] ~= nil then -- yield: (true, sysval)
                            args = table.pack(coroutine.yield(result[2]))
                        else -- yield: (true, nil, ...)
                            return true, table.unpack(result, 3, result.n)
                        end
                    else -- error: result = (false, string)
                        return false, result[2]
                    end
                end
            end,
            running = coroutine.running,
            status = coroutine.status,
            wrap = function(f) -- for bubbling coroutine.resume
                local co = coroutine.create(f)
                return function(...)
                    local result = table.pack(container.temp.coroutine.resume(co, ...))
                    if result[1] then
                        return table.unpack(result, 2, result.n)
                    else
                        error(result[2], 0)
                    end
                end
            end,
            yield = function(...) -- custom yield part for bubbling sysyields
                return coroutine.yield(nil, ...)
            end,
            -- Lua 5.3.
            isyieldable = coroutine.isyieldable
        },
        load = function(ld, source, mode, env)
            return load(ld, source, mode, env or container.temp.sandbox)
        end,
        os = {
            clock = os.clock,
            date = os.date,
            difftime = os.difftime,
            time = os.time
        }
    }
    container.temp.sandbox._G = container.temp.sandbox

    local eeprom = container.libcomponent.list("eeprom")()

    if eeprom then
        local code = container.libcomponent.invoke(eeprom, "get")
        if code and #code > 0 then
            local bios, reason = load(code, "=bios", nil, container.temp.sandbox)

            if bios then
                container.coroutine = coroutine.create(function()
                    local success, result = xpcall(bios, debug.traceback)

                    if success then -- container halted
                        return true
                    end

                    return false, result
                end)

                return true, 0
            end

            return false, "failed loading bios: " .. reason
        end
    end

    return false, "no bios found; install a configured EEPROM"
end

local function addComponent(container, type, uuid, callbacks, docs, deviceInfo)
    container.components[uuid] = {
        address = uuid, 
        type = type, 
        slot = -1, 
        callback = methodsCallback(callbacks),
        docs = docs or {},
        deviceInfo = deviceInfo or {
            description = "Generic Box™ component",
            product = "Generic " .. unicode.upper(type),
            class = "Generic",
            vendor = "Box™",
            clock = "0/0/0/0/0/0",
            width = math.huge,
            size = math.huge,
        },
        remove = function()
            container.computer.pushSignal{"component_removed", uuid, type}
            container.components[uuid] = nil
            return true
        end
    }

    container:pushSignal{"component_added", uuid, type}
    return container.components[uuid]
end

local function passComponent(container, address, weak)
    if component.type(address) then
        if component.type(address) == "disk_drive" and component.invoke(address, "media") then
            local success, result = container:passComponent(component.invoke(address, "media"), true)

            if not success then
                return success, result
            end
        end

        if container.components[address] then
            return false, "component " .. address .. " collision detected"
        end

        container.passedComponents[address] = {
            address = address,
            type = component.type(address),
            slot = component.slot(address),
            fields = component.fields(address),
            detach = function()
                container.computer:pushSignal{"component_removed", address, container.components[address].type}
                container.components[address] = nil
                if weak then
                    container.passedComponents[address] = nil
                end
                return true
            end,
            attach = function()
                container.components[address] = container.passedComponents[address]
                container:pushSignal{"component_added", address, container.passedComponents[address].type}
                return true
            end,
            remove = function()
                container.passedComponents[address]:detach()
                container.passedComponents[address] = nil
                return true
            end,
            pass = true,
            weak = weak
        }

        container.passedComponents[address]:attach()
        return container.passedComponents[address]
    else
        return false, "component " .. address .. " is not available"
    end
end

local function pushSignal(container, signal) -- Difference between container.libcomputer.pushSignal and container.pushSignal is that container.pushSignal can pass signal table directlry (without packing/unpacking).
    if #container.temp.signalQueue >= 256 then
        return false
    end

    table.insert(container.temp.signalQueue, signal)
    return true
end

local function passSignal(container, signal)
    if signals[signal[1]] then
        return signals[signal[1]](container, signal)
    end
    return false
end

local function createContainer(address)
    local container, componentCallback

    componentCallback = {
        __call = function(self, ...)
            return container.libcomponent.invoke(self.address, self.name, ...)
        end,
        __tostring = function(self)
            return container.libcomponent.doc(self.address, self.name)
        end
    }

    address = address or uuid()

    container = {
        address = address,

        bootstrap = bootstrap,
        resume = resume,
        loop = loop,

        pushSignal = pushSignal,
        passSignal = passSignal,

        addComponent = addComponent,
        passComponent = passComponent,
        passedComponents = {},
        uuid = componentUUID,

        temp = {
            clear = function()
                container.temp.coroutine = nil
                container.temp.startUptime = 0
                container.temp.componentCache = {}
                container.temp.sandbox = {}
                container.temp.signalQueue = {}
            end
        },

        components = {
            [address] = {
                address = address,
                type = "computer",
                slot = -1,
                callbacks = methodsCallback{
                    beep = function(...) 
                        return container.libcomputer.beep(...) 
                    end,
                    getProgramLocations = function(...) 
                        return container.libcomputer.getProgramLocations(...)
                    end,
                    isRunning = function()
                        if container.temp.coroutine and coroutine.status(container.temp.coroutine) == "running" then
                            return true
                        end

                        return false
                    end,
                    start = function() 
                        return false 
                    end,
                    stop = function() 
                        container.libcomputer.shutdown() 
                    end
                },
                docs = {
                    beep = "function([frequency:string or number[, duration:number]]) -- Plays a tone, useful to alert users via audible feedback.",
                    getDeviceInfo = "function():table -- Collect information on all connected devices.",
                    getProgramLocations = "function():table -- Returns a map of program name to disk label for known programs.",
                    start = "function():boolean -- Starts the computer. Returns true if the state changed.",
                    stop = "function():boolean -- Stops the computer. Returns true if the state changed.",
                    isRunning = "function():boolean -- Returns whether the computer is running."
                },
                deviceInfo = {
                    capacity = -1,
                    class = "system",
                    description = "Computer",
                    product = "Blocker",
                    vendor = "Box™"
                }
            }
        },

        libcomponent = {
            doc = function(address, method)
                checkArg(1, address, "string")
                checkArg(2, method, "string")
                if container.components[address] then
                    if container.components[address].pass then
                        return component.doc(address, method)
                    end
                    return container.components[address].docs[method] or tostring(container.components[address].callback[method])
                end
                error("no such component")
            end,
            methods = function(address)
                checkArg(1, address, "string")
                if container.components[address] then
                    if container.component[address].pass then
                        return component.methods(address)
                    end
                    local methods = {}
                    for key in pairs(container.components[address].callback) do
                        methods[key] = false
                    end
                    return methods
                end
                return nil, "no such component"
            end,
            invoke = function(address, method, ...)
                checkArg(1, address, "string")
                checkArg(2, method, "string")
                if container.components[address] then
                    if container.components[address].pass then
                        return component.invoke(address, method, ...)
                    end
                    return spcall(container.components[address].callback[method], ...)
                end
            
                error("no such component")
            end,
            list = function(filter, exact)
                local componentsFiltered = {}
                local componentsFilteredIndex = {}
                for address in pairs(container.components) do
                    if not filter or (exact and container.components[address].type == filter or container.components[address].type:find(filter)) then
                        componentsFiltered[address] = container.components[address].type
                        table.insert(componentsFilteredIndex, {
                            address, container.components[address].type
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
                return {}
            end,
            proxy = function(address)
                checkArg(1, address, "string")
                if container.temp.componentCache[address] then
                    return container.temp.componentCache[address]
                end
                if container.components[address] then
                    if container.components[address].pass then
                        return component.proxy(address)
                    end
                    local proxy = {address = address, type = container.components[address].type, slot = container.components[address].slot}
                    for key in pairs(container.components[address].callback) do
                        proxy[key] = setmetatable({address = address, name = key}, componentCallback)
                    end
                    container.temp.componentCache[address] = proxy
                    return proxy
                else
                    return nil, "no such component"
                end
            end,
            type = function(address)
                checkArg(1, address, "string")
                return container.components[address].type
            end,
            slot = function(address)
                checkArg(1, address, "string")
                return container.components[address].slot
            end
        },

        libcomputer = {            
            pullSignal = function(timeout)
                return coroutine.yield(timeout)
            end,
            pushSignal = function(...)
                if #container.temp.signalQueue >= 256 then
                    return false
                end

                table.insert(container.temp.signalQueue, table.pack(...))
                return true
            end,
            address = function()
                return container.address
            end,
            getDeviceInfo = function()
                local realDeviceInfo = computer.getDeviceInfo()
                local deviceInfo = {}
        
                for k, v in pairs(realDeviceInfo) do
                    if v.class == "processor" then
                        deviceInfo[container.component:uuid()] = v
                    elseif v.class == "memory" then
                        deviceInfo[container.component:uuid()] = v
                    elseif container.passedComponents[k] then
                        deviceInfo[k] = v
                    end
                end
                
                for k, v in pairs(container.components) do
                    if not v.pass then
                        deviceInfo[k] = v.deviceInfo
                    end
                end
        
                return deviceInfo
            end,
            tmpAddress = computer.tmpAddress,
            freeMemory = computer.freeMemory,
            totalMemory = computer.totalMemory,
            uptime = function()
                return computer.uptime() - container.temp.startUptime
            end,
            energy = function()
                return 1000
            end,
            maxEnergy = function()
                return 1000
            end,
            users = function()
                return table.unpack({})
            end,
            shutdown = function(reboot)
                coroutine.yield(not not reboot)
            end,
            addUser = function() return false end,
            removeUser = function() return false end,
            beep = computer.beep,
            getProgramLocations = computer.getProgramLocations,
            getArchitecture = computer.getArchitecture,
            getArchitectures = computer.getArchitectures,
            setArchitecture = function() end
        }
    }

    container.temp.clear()
    return container
end

return {
    createContainer = createContainer
}
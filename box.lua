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

--------------------------------------------------------------------------------

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
            if container.components[address].type == "disk_drive" and container.components[address].pass and signal[2] == select(2, pcall(component.invoke, address, "media")) then
                return container:passComponent(signal[2], true)
            end
        end

        return false
    end
}

local docs = {
    computer={
        beep="function([frequency:string or number[, duration:number]]) -- Plays a tone, useful to alert users via audible feedback.",
        getDeviceInfo="function():table -- Collect information on all connected devices.",
        getProgramLocations="function():table -- Returns a map of program name to disk label for known programs.",
        isRunning="function():boolean -- Returns whether the computer is running.",
        start="function():boolean -- Starts the computer. Returns true if the state changed.",
        stop="function():boolean -- Stops the computer. Returns true if the state changed."},
    eeprom={
        get="function():string -- Get the currently stored byte array.",
        getChecksum="function():string -- Get the checksum of the data on this EEPROM.",
        getData="function():string -- Get the currently stored byte array.",
        getDataSize="function():number -- Get the storage capacity of this EEPROM.",
        getLabel="function():string -- Get the label of the EEPROM.",
        getSize="function():number -- Get the storage capacity of this EEPROM.",
        makeReadonly="function(checksum:string):boolean -- Make this EEPROM readonly if it isn't already. This process cannot be reversed!",
        set="function(data:string) -- Overwrite the currently stored byte array.",
        setData="function(data:string) -- Overwrite the currently stored byte array.",
        setLabel="function(data:string):string -- Set the label of the EEPROM."},
    filesystem={close="function(handle:userdata) -- Closes an open file descriptor with the specified handle.",
        exists="function(path:string):boolean -- Returns whether an object exists at the specified absolute path in the file system.",
        getLabel="function():string -- Get the current label of the drive.",
        isDirectory="function(path:string):boolean -- Returns whether the object at the specified absolute path in the file system is a directory.",
        isReadOnly="function():boolean -- Returns whether the file system is read-only.",
        lastModified="function(path:string):number -- Returns the (real world) timestamp of when the object at the specified absolute path in the file system was modified.",
        list="function(path:string):table -- Returns a list of names of objects in the directory at the specified absolute path in the file system.",
        makeDirectory="function(path:string):boolean -- Creates a directory at the specified absolute path in the file system. Creates parent directories, if necessary.",
        open="function(path:string[, mode:string='r']):userdata -- Opens a new file descriptor and returns its handle.",
        read="function(handle:userdata, count:number):string or nil -- Reads up to the specified amount of data from an open file descriptor with the specified handle. Returns nil when EOF is reached.",
        remove="function(path:string):boolean -- Removes the object at the specified absolute path in the file system.",
        rename="function(from:string, to:string):boolean -- Renames/moves an object from the first specified absolute path in the file system to the second.",
        seek="function(handle:userdata, whence:string, offset:number):number -- Seeks in an open file descriptor with the specified handle. Returns the new pointer position.",
        setLabel="function(value:string):string -- Sets the label of the drive. Returns the new value, which may be truncated.",
        size="function(path:string):number -- Returns the size of the object at the specified absolute path in the file system.",
        spaceTotal="function():number -- The overall capacity of the file system, in bytes.",
        spaceUsed="function():number -- The currently used capacity of the file system, in bytes.",
        write="function(handle:userdata, value:string):boolean -- Writes the specified data to an open file descriptor with the specified handle."},
    gpu={
        bind="function(address:string[, reset:boolean=true]):boolean -- Binds the GPU to the screen with the specified address and resets screen settings if `reset` is true.",
        copy="function(x:number, y:number, width:number, height:number, tx:number, ty:number):boolean -- Copies a portion of the screen from the specified location with the specified size by the specified translation.",
        fill="function(x:number, y:number, width:number, height:number, char:string):boolean -- Fills a portion of the screen at the specified position with the specified size with the specified character.",
        get="function(x:number, y:number):string, number, number, number or nil, number or nil -- Get the value displayed on the screen at the specified index, as well as the foreground and background color. If the foreground or background is from the palette, returns the palette indices as fourth and fifth results, else nil, respectively.",
        getBackground="function():number, boolean -- Get the current background color and whether it's from the palette or not.",
        getDepth="function():number -- Returns the currently set color depth.",
        getForeground="function():number, boolean -- Get the current foreground color and whether it's from the palette or not.",
        getPaletteColor="function(index:number):number -- Get the palette color at the specified palette index.",
        getResolution="function():number, number -- Get the current screen resolution.",
        getScreen="function():string -- Get the address of the screen the GPU is currently bound to.",
        getViewport="function():number, number -- Get the current viewport resolution.",
        maxDepth="function():number -- Get the maximum supported color depth.",
        maxResolution="function():number, number -- Get the maximum screen resolution.",
        set="function(x:number, y:number, value:string[, vertical:boolean]):boolean -- Plots a string value to the screen at the specified position. Optionally writes the string vertically.",
        setBackground="function(value:number[, palette:boolean]):number, number or nil -- Sets the background color to the specified value. Optionally takes an explicit palette index. Returns the old value and if it was from the palette its palette index.",
        setDepth="function(depth:number):number -- Set the color depth. Returns the previous value.",
        setForeground="function(value:number[, palette:boolean]):number, number or nil -- Sets the foreground color to the specified value. Optionally takes an explicit palette index. Returns the old value and if it was from the palette its palette index.",
        setPaletteColor="function(index:number, color:number):number -- Set the palette color at the specified palette index. Returns the previous value.",
        setResolution="function(width:number, height:number):boolean -- Set the screen resolution. Returns true if the resolution changed.",
        setViewport="function(width:number, height:number):boolean -- Set the viewport resolution. Cannot exceed the screen resolution. Returns true if the resolution changed."},
    internet={
        connect="function(address:string[, port:number]):userdata -- Opens a new TCP connection. Returns the handle of the connection.",
        isHttpEnabled="function():boolean -- Returns whether HTTP requests can be made (config setting).",
        isTcpEnabled="function():boolean -- Returns whether TCP connections can be made (config setting).",
        request="function(url:string[, postData:string[, headers:table[, method:string]]]):userdata -- Starts an HTTP request. If this returns true, further results will be pushed using `http_response` signals."},
    screen={
        getAspectRatio="function():number, number -- The aspect ratio of the screen. For multi-block screens this is the number of blocks, horizontal and vertical.",
        getKeyboards="function():table -- The list of keyboards attached to the screen.",
        isOn="function():boolean -- Returns whether the screen is currently on.",
        isPrecise="function():boolean -- Returns whether the screen is in high precision mode (sub-pixel mouse event positions).",
        isTouchModeInverted="function():boolean -- Whether touch mode is inverted (sneak-activate opens GUI, instead of normal activate).",
        setPrecise="function(enabled:boolean):boolean -- Set whether to use high precision mode (sub-pixel mouse event positions).",
        setTouchModeInverted="function(value:boolean):boolean -- Sets whether to invert touch mode (sneak-activate opens GUI, instead of normal activate).",
        turnOff="function():boolean -- Turns off the screen. Returns true if it was on.",
        turnOn="function():boolean -- Turns the screen on. Returns true if it was off."
    }
}

local deviceInfo = {
    computer = {
        capacity="-1",
        class="system",
        description="Computer",
        product="Blocker",
        vendor="Box™"
    },
    internet = {
        description = "Internet modem",
        product = "Generic internet modem",
        vendor = "Box™"
    },
    filesystem = {
        capacity = "-1",
        class = "volume",
        clock = "0/0/0/0/0/0",
        description = "Filesystem",
        product = "Generic filesystem",
        vendor = "Box™"
    },
    keyboard = {
        description = "Keyboard",
        product = "Generic keyboard",
        vendor = "Box™"
    },
    screen = {
        class="display",
        description="Text buffer",
        product="Generic screen",
        vendor="Box™",
        width="-1"
    },
    gpu = {
        capacity="-1",
        class="display",
        clock="0/0/0/0/0/0",
        description="Graphics controller",
        product="MPG2000 GTZ",
        vendor="Box™",
        width="-1"
    },
    eeprom = {
        capacity = "-1",
        class = "memory",
        description = "EEPROM",
        product = "FlashStick2k",
        size = "-1",
        vendor = "Box™"
    }
}

--------------------------------------------------------------------------------

local function uuid()
    local template ="xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    local random = math.random
    local uuid = string.gsub(template, "[xy]", function (c)
        local v = (c == "x") and random(0, 0xf) or random(8, 0xb)
        return string.format("%x", v)
    end)
    return uuid
end

local function createComponent(component)
    local component = component
    component.doc = component.doc or docs[component.type] or {}
    component.deviceInfo = component.deviceInfo or deviceInfo[component.type] or {
        description = "Generic Box™ component",
        product = "Generic " .. unicode.upper(component.type),
        class = "Generic",
        vendor = "Box™",
        clock = "0/0/0/0/0/0",
        width = math.huge,
        size = math.huge,
    }
    component.callback = methodsCallback(component.callback)

    return component
end

local function resume(container)
    if container.temp.coroutine then
        local signal = container.temp.signalQueue[1] or {}
        table.remove(container.temp.signalQueue, 1)
        local success, result, error = coroutine.resume(container.temp.coroutine, table.unpack(signal))
        
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
            if coroutine.status(container.temp.coroutine) == "dead" then
                return false, "container halted"
            end
            return true, result or math.huge
        end
        
        return false, result or "unknown error" -- probably coroutine is dead
    end
    
    return false, "coroutine dead"
end

local function loop(container)
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
        component = {
            doc = container.libcomponent.doc,
            invoke = container.libcomponent.invoke,
            list = container.libcomponent.list,
            methods = container.libcomponent.methods,
            proxy = container.libcomponent.proxy,
            type = container.libcomponent.type,
            slot = container.libcomponent.slot,
            fields = container.libcomponent.fields
        },
        computer = {
            address = container.libcomputer.address,
            tmpAddress = function() return container.libcomputer.tmpAddress() end,
            freeMemory = container.libcomputer.freeMemory,
            totalMemory = container.libcomputer.totalMemory,
            energy = container.libcomputer.energy,
            maxEnergy = container.libcomputer.maxEnergy,
            uptime = container.libcomputer.uptime,
            shutdown = container.libcomputer.shutdown,
            users = container.libcomputer.users,
            addUser = container.libcomputer.addUser,
            removeUser = container.libcomputer.removeUser,
            pushSignal = container.libcomputer.pushSignal,
            pullSignal = container.libcomputer.pullSignal,
            beep = container.libcomputer.beep,
            getDeviceInfo = container.libcomputer.getDeviceInfo,
            setArchitecture = container.libcomputer.setArchitecture,
            getArchitecture = container.libcomputer.getArchitecture,
            getArchitectures = container.libcomputer.getArchitectures,
            getProgramLocations = container.libcomputer.getProgramLocations
        },
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

    if container.beforeBootstrap then
        container:beforeBootstrap()
    end

    local eeprom = container.libcomponent.list("eeprom")()

    if eeprom then
        local code = container.libcomponent.invoke(eeprom, "get")
        if code and #code > 0 then
            local bios, reason = load(code, "=bios", nil, container.temp.sandbox)

            if bios then
                if container.onBootstrap then
                    container:onBootstrap()
                end

                container.temp.coroutine = coroutine.create(function()
                    container.temp.startUptime = computer.uptime()
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

local function removeComponent(component)
    component.container:pushSignal{"component_removed", uuid, component.type}
    if component.container.passedComponents[component.address] then
        component.container.passedComponents[component.address] = nil
    end
    component.container.components[component.address] = nil
end

local function attachComponent(container, component)
    container:pushSignal{"component_added", uuid, component.type}
    if container.components[component.address] then
        error("component " .. component.address .. " is already attached")
    end

    container.components[component.address] = component
    container.components[component.address].container = container
    container.components[component.address].remove = removeComponent

    return component
end

local function detachPassedComponent(component)
    component.container:pushSignal{"component_removed", component.address, component.type}
    component.container.components[component.address] = nil
    if component.container.passedComponents[component.address].weak then
        component.container.passedComponents[component.address] = nil
    end
end

local function attachPassedComponent(component)
    component.container:pushSignal{"component_added", component.address, component.container.passedComponents[component.address].type}
    component.container.components[component.address] = component.container.passedComponents[component.address]
    return true
end

local function passComponent(container, address, weak)
    if component.type(address) then
        if component.type(address) == "disk_drive" then
            local result, address = pcall(component.invoke, address, "media") -- fuck this, server disk drive does not have 'media' method

            if result then
                local success, result = container:passComponent(address, true)

                if not success then
                    return success, result
                end
            end
        end

        if container.components[address] then
            return false, "component " .. address .. " collision detected"
        end

        container.passedComponents[address] = {
            address = address,
            type = component.type(address),
            detach = detachPassedComponent,
            attach = attachPassedComponent,
            remove = removeComponent,
            pass = true,
            weak = weak,
            container = container
        }

        container.passedComponents[address]:attach()
        return container.passedComponents[address]
    end

    error("component " .. address .. " is not available")
end

local function pushSignal(container, signal) -- Difference between container.libcomputer.pushSignal and container.pushSignal is that container.pushSignal can pass signal table directly (without packing/unpacking) and coroutine checking (signal won't be passed if container wasn't started)
    if #container.temp.signalQueue >= 256 then
        return false
    elseif container.temp.startUptime == 0 then
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

        attachComponent = attachComponent,
        passComponent = passComponent,
        passedComponents = {},

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
            [address] = createComponent{
                address = address,
                type = "computer", 
                callback = {
                    getDeviceInfo = function(...)
                        return container.libcomputer.getDeviceInfo(...)
                    end,
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
                container = container,
                removeComponent = removeComponent
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
                    if container.components[address].pass then
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
                    local proxy = {address = address, type = container.components[address].type, slot = container.components[address].slot or -1}
                    for key in pairs(container.components[address].callback) do
                        proxy[key] = setmetatable({address = address, name = key}, componentCallback)
                    end
                    container.temp.componentCache[address] = proxy
                    return proxy
                end
                return nil, "no such component"
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
                    if v.class == "processor" or v.class == "memory" then
                        deviceInfo[k] = v
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
            tmpAddress = function()
                error("not implemented")
            end,
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
    
--------------------------------------------------------------------------------

-- local container = createContainer()
-- container.libcomputer.tmpAddress = function()
--     return computer.tmpAddress()
-- end

-- for address, type in pairs(component.list()) do
--     container:passComponent(address)
-- end

-- print(container:bootstrap())
-- print(container:loop())

return {
    createContainer = createContainer,
    createComponent = createComponent,
    uuid = uuid
}

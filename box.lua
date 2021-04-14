local shell = require("shell")
local component = require("component")
local computer = require("computer")
local unicode = require("unicode")
local serialization = require("serialization")
local thread = require("thread")

--Methods list---------------------------------------------------------------------------------------------------------

local methods = {
    computer={
        beep=false,
        getDeviceInfo=true,
        getProgramLocations=false,
        isRunning=true,
        start=false,
        stop=false
    },
    eeprom={
        get=true,
        getChecksum=true,
        getData=true,
        getDataSize=true,
        getLabel=true,
        getSize=true,
        makeReadonly=true,
        set=false,
        setData=false,
        setLabel=false
    },
    filesystem={
        close=true,
        exists=true,
        getLabel=true,
        isDirectory=true,
        isReadOnly=true,
        lastModified=true,
        list=false,
        makeDirectory=false,
        open=true,
        read=true,
        remove=false,
        rename=false,
        seek=true,
        setLabel=false,
        size=true,
        spaceTotal=true,
        spaceUsed=true,
        write=true
    },
    gpu={
        bind=false,
        copy=true,
        fill=true,
        get=true,
        getBackground=true,
        getDepth=true,
        getForeground=true,
        getPaletteColor=true,
        getResolution=true,
        getScreen=true,
        getViewport=true,
        maxDepth=true,
        maxResolution=true,
        set=true,
        setBackground=true,
        setDepth=false,
        setForeground=true,
        setPaletteColor=true,
        setResolution=false,
        setViewport=false
    },
    internet={
        connect=false,
        isHttpEnabled=true,
        isTcpEnabled=true,
        request=false
    },
    modem={
        broadcast=false,
        close=false,
        getStrength=true,
        getWakeMessage=true,
        isOpen=true,
        isWired=true,
        isWireless=true,
        open=false,
        send=false,
        setStrength=false,
        setWakeMessage=false
    },
    screen={
        getAspectRatio=true,
        getKeyboards=false,
        isOn=true,
        isPrecise=true,
        isTouchModeInverted=true,
        setPrecise=false,
        setTouchModeInverted=false,
        turnOff=false,
        turnOn=false
    }
}

--Docs list------------------------------------------------------------------------------------------------------------         

local docs = { 
    computer={
        beep="function([frequency:string or number[, duration:number]]) -- Plays a tone, useful to alert users via audible feedback.",
        getDeviceInfo="function():table -- Collect information on all connected devices.",
        getProgramLocations="function():table -- Returns a map of program name to disk label for known programs.",
        isRunning="function():boolean -- Returns whether the computer is running.",
        start="function():boolean -- Starts the computer. Returns true if the state changed.",
        stop="function():boolean -- Stops the computer. Returns true if the state changed."
    },
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
        setLabel="function(data:string):string -- Set the label of the EEPROM."
    },
    filesystem={
        close="function(handle:userdata) -- Closes an open file descriptor with the specified handle.",
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
        write="function(handle:userdata, value:string):boolean -- Writes the specified data to an open file descriptor with the specified handle."
    },
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
        setViewport="function(width:number, height:number):boolean -- Set the viewport resolution. Cannot exceed the screen resolution. Returns true if the resolution changed."
    },
    internet={
        connect="function(address:string[, port:number]):userdata -- Opens a new TCP connection. Returns the handle of the connection.",
        isHttpEnabled="function():boolean -- Returns whether HTTP requests can be made (config setting).",
        isTcpEnabled="function():boolean -- Returns whether TCP connections can be made (config setting).",
        request="function(url:string[, postData:string[, headers:table[, method:string]]]):userdata -- Starts an HTTP request. If this returns true, further results will be pushed using `http_response` signals."
    },
    modem={
        broadcast="function(port:number, data...) -- Broadcasts the specified data on the specified port.",
        close="function([port:number]):boolean -- Closes the specified port (default: all ports). Returns true if ports were closed.",
        getStrength="function():number -- Get the signal strength (range) used when sending messages.",
        getWakeMessage="function():string, boolean -- Get the current wake-up message.",
        isOpen="function(port:number):boolean -- Whether the specified port is open.",
        isWired="function():boolean -- Whether this card has wired networking capability.",
        isWireless="function():boolean -- Whether this card has wireless networking capability.",
        open="function(port:number):boolean -- Opens the specified port. Returns true if the port was opened.",
        send="function(address:string, port:number, data...) -- Sends the specified data to the specified target.",
        setStrength="function(strength:number):number -- Set the signal strength (range) used when sending messages.",
        setWakeMessage="function(message:string[, fuzzy:boolean]):string -- Set the wake-up message and whether to ignore additional data/parameters."
    },
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

--Utilites------------------------------------------------------------------------------------------------------------- 

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

--Sandbox creation-----------------------------------------------------------------------------------------------------

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
                sandbox.coroutine = coroutine.create(chunk)
                --     function()
                --         coroutine.yield(xpcall(chunk, debug.traceback))
                --     end
                -- )
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

local i = 0
local function supervisor() 
    while true do    
        local data = {coroutine.resume(sandbox.coroutine, sandbox.signalQueue[1])}
        i = i + 1
        print(i)
        computer.beep(2000, 3)
        
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
local shell = require("shell")
local component = require("component")
local computer = require("computer")
local unicode = require("unicode")

local args, options = shell.parse(...)

-------------------------------------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------------------------------------

local function spcall(...)
    local result = table.pack(pcall(...))
    if not result[1] then
        error(tostring(result[2]), 0)
    else
        return table.unpack(result, 2, result.n)
    end
end

local function createComponent(machine, address, type, slot, callbacks)
    checkArg(1, address, "string")
    checkArg(2, type, "string")
    checkArg(3, slot, "number")
    checkArg(4, callbacks, "table")
    if component.type(address) then
        return nil, "real component with the same address already exists"
    end
    if machine.component.list[address] then
        return nil, "component already exists"
    end
    machine.component.list[address] = {
        address = address, 
        type = type, 
        slot = slot, 
        callback = setmetatable(callbacks, {
            __index = function()
                error("no such method")
            end
        }),
        fields = {}
    }
    machine.sandbox.computer.pushSignal("component_added", address, machine.component.list[address].type)
    return true
end

local function removeComponent(machine, address)
    checkArg(1, address, "string")
    if machine.component.list[address] then
        machine.sandbox.computer.pushSignal("component_removed", address, machine.component.list[address].type)
        machine.component.list[address] = nil
        return true
    end
    return false
end

local function passthroughComponent(machine, address)
    checkArg(1, address, "string")
    local type = component.type(address)
    if type then
        machine.component.list[address] = {address = address, type = type, slot = component.slot(address), passthrough = true}
        return true
    end
    return nil, "component doesn't exists"
end

local function randomUUID(addresses)
    local address

    repeat
        local r = math.random
        address = ("%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x"):format(
            r(0,255),r(0,255),r(0,255),r(0,255),
            r(0,255),r(0,255),
            r(64,79),r(0,255),
            r(128,191),r(0,255),
            r(0,255),r(0,255),r(0,255),r(0,255),r(0,255),r(0,255)
        )
    until not component.get(address) and not addresses[address]

    return address
end

local function createSandbox(pure)
    local machine, libcomponent

    libcomponent = {
        doc = function(address, method)
            checkArg(1, address, "string")
            checkArg(2, method, "string")
            if machine.component.list[address].passthrough then
                return component.doc(address, method)
            end
            return docs[machine.component[address].type] or {}
        end,
        methods = function(address)
            checkArg(1, address, "string")
            if machine.component.list[address].passthrough then
                return component.methods(address)
            end
            return methods[machine.component[address].type] or {}
        end,
        invoke = function(address, method, ...)
            checkArg(1, address, "string")
            checkArg(2, method, "string")
            if machine.component.list[address].passthrough then
                return component.invoke(address, method, ...)
            end
            return spcall(machine.component.list[address].callback[method], ...)
        end,
        list = function(filter, exact)
            checkArg(1, filter, "string")
            local componentsFiltered = {}
            for address in pairs(machine.component.list) do
                if not filter or (exact and machine.component.list[address].type == filter or machine.component.list[address].type:match(filter)) then
                    componentsFiltered[address] = machine.component.list[address].type
                end
            end
            return componentsFiltered
        end,
        fields = function(address) -- Legacy???
            checkArg(1, address, "string")    
            if machine.component.list[address].passthrough then
                return component.fields(address)
            end
            return machine.component.list[address].fields
        end,
        proxy = function(address)
            checkArg(1, address, "string")
            if machine.component.list[address].passthrough then
                return component.proxy(address)
            end
            if machine.component.cache[address] then
                return machine.component.cache[address]
            end
            if machine.component.list[address] then
                local proxy = {address = address, type = machine.component.list[address].type, slot = machine.component.list[address].slot}
                for key in pairs(machine.component.list[address].callback) do
                    proxy[key] = setmetatable({}, {
                        __call = function(...)
                            return libcomponent.invoke(address, key, ...)
                        end,
                        __tostring = function()
                            return libcomponent.doc(address, key) or tostring(machine.component.list[address].callback[key])
                        end
                    })
                end
                machine.component.cache[address] = proxy
                return proxy
            else
                return nil, "no such component"
            end
        end,
        type = function(address)
            checkArg(1, address, "string")
            return machine.component.list[address].type
        end,
        slot = function(address)
            checkArg(1, address, "string")
            return machine.component.list[address].slot
        end
    }

    local libcomputer = {
        pullSignal = function(timeout)
            local signal = {computer.pullSignal(timeout)}

            if signal[1] == "box" and signal[2] == machine.address then
                return table.unpack(signal, 3)
            end
        end,
        pushSignal = function(...)
            computer.pushSignal("box", machine.address, ...)
        end,
        address = function() return machine.computer.address end,
        shutdown = function() coroutine.yield("SHUTDOWN") end,
        getDeviceInfo = function() return {} end,
        tmpAddress = computer.tmpAddress,
        totalMemory = computer.totalMemory,
        uptime = function ()
            return computer.uptime() - machine.startUptime
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
        setArchitecture = function() end
    }

    machine = {
        coroutine = nil,
        startUptime = 0,
        address = randomUUID({}),
        component = {
            lib = libcomponent,
            create = function(...)
                local uuid = randomUUID(machine.component.list)
                createComponent(machine, uuid, ...)
            end,
            remove = function(address)
                removeComponent(machine, address)
            end,
            list = {},
            cache = {}
        },
        bootstrap = function()
            local eeprom = libcomponent.list("eeprom")()
            if eeprom then
                local code = libcomponent.invoke(eeprom, "get")
                if code and #code > 0 then
                    local bios, reason = load(code, "=bios", "t", machine.sandbox)
                    if bios then
                        machine.coroutine = coroutine.create(bios)
                        machine.startUptime = computer.uptime()
                        return true
                    end
                    error("failed loading bios: " .. reason, 0)
                end
            end
            error("no bios found; install a configured EEPROM", 0)
        end
    }
end

createSandbox()
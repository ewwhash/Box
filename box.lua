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

local signals = { -- signal passthrough
    key_down = function(container, signal)
        if container.components[signal[2]] then
            container:pushSignal(signal)
            return true
        end
        return false
    end,
    key_up = function(container, signal)
        if container.components[signal[2]] then
            container:pushSignal(signal)
            return true
        end
        return false
    end,
    screen_resized = function(container, signal)
        if container.components[signal[2]] then
            container:pushSignal(signal)
            return true
        end
        return false
    end,
    clipboard = function(container, signal)
        if container.components[signal[2]] then
            container:pushSignal(signal)
            return true
        end
        return false
    end,
    touch = function(container, signal)
        if container.components[signal[2]] then
            container:pushSignal(signal)
            return true
        end
        return false
    end,
    drag = function(container, signal)
        if container.components[signal[2]] then
            container:pushSignal(signal)
            return true
        end
        return false
    end,
    drop = function(container, signal)
        if container.components[signal[2]] then
            container:pushSignal(signal)
            return true
        end
        return false
    end,
    scroll = function(container, signal)
        if container.components[signal[2]] then
            container:pushSignal(signal)
            return true
        end
        return false
    end,
    walk = function(container, signal)
        if container.components[signal[2]] then
            container:pushSignal(signal)
            return true
        end
        return false
    end,
    redstone_chanded = function(container, signal)
        if container.components[signal[2]] then
            container:pushSignal(signal)
            return true
        end
        return false
    end,
    motion = function(container, signal)
        if container.components[signal[2]] then
            container:pushSignal(signal)
            return true
        end
        return false
    end,
    modem_message = function(container, signal)
        if container.components[signal[2]] then
            container:pushSignal(signal)
            return true
        end
        return false
    end,
    component_removed = function(container, signal)
        if container.components[signal[2]] then
            if signal[2] == spcall(container.libcomponent.invoke, container.libcomponent.list("disk_drive")(), "media") then
                container:removePassedComponent(signal[2])
            end
            container:removeComponent(signal[2])
            return true
        end
        return false
    end,
    component_added = function(container, signal)
        if container.passedComponents[signal[2]] then
            container:readdPassedComponent(signal[2])
            return true
        elseif signal[2] == select(2, pcall(container.libcomponent.invoke, container.libcomponent.list("disk_drive")(), "media")) then
            container:passComponent(signal[2])
            return true
        end
        return false
    end
}

local function uuid()
    local template ="xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    local random = math.random
    math.randomseed(os.time())
    return string.gsub(template, "[xy]", function (c)
        local v = (c == "x") and random(0, 0xf) or random(8, 0xb)
        return string.format("%x", v)
    end)
end

local function randomComponentUUID(self)
    local UUID
    repeat
        UUID = uuid()
    until not self.components[UUID]
    return UUID
end

local function resume(self)
    if self.coroutine then
        if self.paused then
            return false, "container is paused"
        end

        local signal = self.signalQueue[1] or {}
        table.remove(self.signalQueue, 1)
        local success, result, error = coroutine.resume(self.coroutine, table.unpack(signal))
        
        if success then -- coroutine resume successfull
            if result == false and error then -- error from container
                return false, error
            end
            if result == false then -- otherwise computer shutdown
                self:clear()
                return false, "container shutdown"
            end
            if result == true then
                return self:bootstrap()
            end
            if coroutine.status(self.coroutine) == "dead" then
                return false, "container halted"
            end
            return true, result or math.huge
        end
        
        return false, result or "unknown error" -- probably coroutine is dead
    end
    
    return false, "coroutine dead"
end

local function loop(self)
    while true do
        local success, result = self:resume()

        if success then
            if not self.signalQueue[1] then
                local deadline = computer.uptime() + result

                repeat
                    local signal = {computer.pullSignal(deadline - computer.uptime())}

                    if signal[1] == "key_down" and signal[4] == 211 then
                        self:clear()
                        return "force shutdown"
                    end

                    if self:passSignal(signal) then
                        break
                    end
                until computer.uptime() >= deadline
            end
        else
            return result
        end
    end
end

local function bootstrap(self)
    self:clear()
        
    local eeprom = self.sandbox.component.list("eeprom")()
    if eeprom then
        local code = self.sandbox.component.invoke(eeprom, "get")
        if code and #code > 0 then
            local bios, reason = load(code, "=bios", "t", self.sandbox)
            if bios then
                self.coroutine = coroutine.create(function()
                    self.startUptime = computer.uptime()
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

local function addComponent(self, type, uuid, callbacks, docs, deviceInfo)
    self.components[uuid] = {
        address = uuid, 
        type = type, 
        slot = -1, 
        callback = setmetatable(callbacks, {
            __index = function()
                error("no such method")
            end
        }),
        docs = docs or {},
        deviceInfo = deviceInfo or {
            description = "Generic Box™ component",
            product = "Generic " .. unicode.upper(type),
            class = "Generic",
            vendor = "Box™",
            clock = "0/0/0/0/0/0",
            width = math.huge,
            size = math.huge,
        }
    }

    self:pushSignal{"component_added", uuid, type}
    return self.components[uuid]
end

local function readdPassedComponent(self, address)
    if self.passedComponents[address] then
        if self.components[address] then
            self:removeComponent(address)
        end
        self.components[address] = self.passedComponents[address]
        self:pushSignal{"component_added", address, self.passedComponents[address].type}
        return true
    end
    return false
end

local function passComponent(self, address)
    if component.type(address) then
        if component.type(address) == "disk_drive" and component.invoke(address, "media") then
            self:passComponent(component.invoke(address, "media"))
        end

        if self.components[address] then
            return false, "component " .. address .. " collision detected"
        end

        self.passedComponents[address] = {
            address = address,
            type = component.type(address),
            slot = component.slot(address),
            fields = component.fields(address),
            pass = true
        }

        return self:readdPassedComponent(address)
    else
        return false, "component " .. address .. "is not available"
    end
end

local function removeComponent(self, address)
    if self.components[address] then
        self:pushSignal{"component_removed", address, self.components[address].type}
        self.components[address] = nil
    end
end

local function removePassedComponent(self, address)
    self:removeComponent(self, address)
    self.passedComponents[address] = nil
end

local function pushSignal(self, signal)
    table.insert(self.signalQueue, 1, signal)
end

local function passSignal(self, signal)
    if signals[signal[1]] then
        return signals[signal[1]](self, signal)
    end
    return false
end

local function clear(self)
    self.signalQueue = {}
    self.componentCache = {}
    self.startUptime = 0
    self.coroutine = nil
end

local function createContainer()
    local container, componentCallback, libcomponent, libcomputer, sandbox = {}

    componentCallback = {
        __call = function(self, ...)
            return libcomponent.invoke(self.address, self.name, ...)
        end,
        __tostring = function(self)
            return libcomponent.doc(self.address, self.name)
        end
    }

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
                return spcall(container.components[address].callback[method], container.components[address], ...)
            else
                return error("no such component")
            end
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
            if container.componentCache[address] then
                return container.componentCache[address]
            end
            if container.components[address] then
                if container.components[address].pass then
                    return component.proxy(address)
                end
                local proxy = {address = address, type = container.components[address].type, slot = container.components[address].slot}
                for key in pairs(container.components[address].callback) do
                    proxy[key] = setmetatable({address = address, name = key}, componentCallback)
                end
                container.componentCache[address] = proxy
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
    }
    
    libcomputer = {
        pullSignal = function(timeout)
            return coroutine.yield(timeout)
        end,
        pushSignal = function(...)
            table.insert(container.signalQueue, table.pack(...))
            return true
        end,
        address = function()
            return container.address
        end,
        getDeviceInfo = function()
            local realDeviceInfo = computer.getDeviceInfo()
            local deviceInfo = {}
    
            for k, v in pairs(realDeviceInfo) do
                if container.components[k] then
                    k = container:randomComponentUUID() -- avoiding collision
                end
                if v.class == "processor" then
                    deviceInfo[k] = v
                elseif v.class == "memory" then
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
        tmpAddress = computer.tmpAddress,
        freeMemory = computer.freeMemory,
        totalMemory = computer.totalMemory,
        uptime = function()
            return computer.uptime() - container.startUptime
        end,
        energy = 1000,
        maxEnergy = 1000,
        users = {},
        shutdown = function(reboot)
            coroutine.yield(not not reboot)
        end,
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
        load = load,
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
                    local result = table.pack(container.coroutine.resume(co, ...))
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
        unicode = unicode,
        
        print = print
    }
    sandbox._G = sandbox

    container = {
        paused = false,
        address = uuid(),

        signalQueue = {},
        componentCache = {},
        startUptime = 0,
        coroutine = nil,

        libcomponent = libcomponent,
        libcomputer = libcomputer,
        sandbox = sandbox,

        components = {},
        passedComponents = {},

        randomComponentUUID = randomComponentUUID,
        addComponent = addComponent,
        readdPassedComponent = readdPassedComponent,
        passComponent = passComponent,
        removeComponent = removeComponent,
        removePassedComponent = removePassedComponent,
        pushSignal = pushSignal,
        passSignal = passSignal,
        bootstrap = bootstrap,
        resume = resume,
        loop = loop,
        clear = clear
    }

    return container
end

local oldPalette, oldBackground, oldForeground, oldWidth, oldHeight = {}, component.gpu.getBackground(), component.gpu.getForeground()

local container = createContainer()

container:passComponent(component.keyboard.address)
container:passComponent(component.internet.address)
container:passComponent(computer.tmpAddress())
container:passComponent(component.computer.address)
container:passComponent(component.gpu.address)
container:passComponent(component.screen.address)
-- container:passComponent(component.get('b46')) -- disk drive

container:addComponent("eeprom", container:randomComponentUUID(), {
    get = function()
        local file = io.open("/home/box/bios.lua", "r")
        local data = file:read("*a")
        file:close()
        
        return data
    end,
    set = function(self)
    end,
    getLabel = function(self)
        return "Box BIOS"
    end,
    setLabel = function(self)
    end,
    getSize = function(self)
        return 4096
    end,
    getDataSize = function(self)
    end,
    getData = function(self)
        return ""
    end,
    setData = function(self, data)
    end,
    getChecksum = function(self)
        return "hv62jd1"
    end,
    makeReadonly = function(self)
        return false
    end
})

local function halt(reason)
    component.gpu.setResolution(oldWidth, oldHeight)
    component.gpu.setBackground(oldBackground)
    component.gpu.setForeground(oldForeground)
    for i = 1, 15 do
        component.gpu.setPaletteColor(i, oldPalette[i])
    end
    require("tty").clear()
    print((reason or "unknown reason"))

    if reason ~= "container shutdown" and reason ~= "force shutdown" then
        computer.beep("--")
    end
end

require("tty").clear()
local success, result = container:bootstrap()

if not success then
    halt(result)
end

for i = 1, 15 do
    oldPalette[i] = component.gpu.getPaletteColor(i)
end
oldWidth, oldHeight = component.gpu.getResolution()

require("process").info().data.signal = function() computer.beep() end
halt(container:loop())

-- local screen = container:addComponent("screen", container:randomComponentUUID(), {
--     isOn = function(self)
--         return true
--     end,
--     turnOn = function(self)
--         return
--     end,
--     turnOff = function(self)
--         return
--     end,
--     getAspectRatio = function(self)
--         return component.screen.getAspectRatio()
--     end,
--     geyKeyboards = function(self)
--         return {
--             container.libcomponent.list("keyboard")(),
--             n = 1
--         }
--     end,
--     setPrecise = function(self)
--         return false
--     end,
--     isPrecise = function(self)
--         return component.screen.isPrecise()
--     end,
--     setTouchModeEnabled = function(self)
--         return false
--     end,
--     isTouchModeInverted = function(self)
--         return component.screen.isTouchModeInverted()
--     end
-- })

-- local function redrawTitleBar()
--     component.gpu.setBackground(0xf0f0f0)
--     component.gpu.fill(1, 1, 160, 1, " ")
-- end

-- local gpu = container:addComponent("gpu", container:randomComponentUUID(), {
--     bind = function(self, address, reset)
--         return true
--     end,
--     getScreen = function(self)
--         return screen.address
--     end,
--     getBackground = function(self)
--         return component.gpu.getBackground()
--     end,
--     setBackground = function(self, ...)
--         return component.gpu.setBackground(...)
--     end,
--     getForeground = function(self, ...)
--         return component.gpu.getForeground(...)
--     end,
--     setForeground = function(self, ...)
--         return component.gpu.setForeground(...)
--     end,
--     getPaletteColor = function(self, ...)
--         return component.gpu.getPaletteColor(...)
--     end,
--     setPaletteColor = function(self, ...)
--         return component.gpu.setPaletteColor(...)
--     end,
--     maxDepth = function(self)
--         return component.gpu.maxDepth()
--     end,
--     getDepth = function(self)
--         return component.gpu.getDepth()
--     end,
--     setDepth = function(self, ...)
--         return false
--     end,
--     maxResolution = function(self)
--         return self.maxWidth - (1*proportion), self.maxHeight - 1
--     end,
--     getResolution = function(self)
--         local w, h = component.gpu.getResolution()
--         return w - (1*proportion), h - 1
--     end,
--     setResolution = function(self, width, height)
--         print(width, height)
--         if height > self.maxWidth - 1 then
--             error("unsupported resolution")
--         end
--         return component.gpu.setResolution(width, height)
--     end,
--     getViewport = function(self)
--         return self.maxWidth - (1*proportion), self.maxHeight - 1
--     end,
--     setViewport = function(self, width, height)
--         return false
--     end,
--     get = function(self, x, y)
--         -- local w, h = component.gpu.getResolution()
--         -- if y - 1 > h then
--         --     error("index out of bounds")
--         -- end
--         return component.gpu.get(x, y + 1)
--     end,
--     set = function(self, x, y, symbol, vertical)
--         return component.gpu.set(x, y + 1, symbol, vertical)
--     end,
--     copy = function(self, x, y, w, h, tx, ty)
--         gpu.copy(x, y - ty + 1, w, h + ty + 1, tx, ty)
--     end,
--     fill = function(self, x, y, w, h, char)
--         return component.gpu.fill(x, y + 1, w, h, char)
--     end
-- })

-- gpu.maxWidth, gpu.maxHeight = 

return {
    createContainer = createContainer
}

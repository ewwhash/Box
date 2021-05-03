local component = require("component")
local computer = require("computer")
local unicode = require("unicode")

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

local function resume(self)
    if self.coroutine then
        if self.paused then
            return false, "container is paused"
        end

        local signal = self.signalQueue[1] or {}
        table.remove(self.signalQueue, 1)
        local result = table.pack(coroutine.resume(self.coroutine, table.unpack(signal)))

        if result[1] then -- coroutine resume successfull
            if result[2] == "error" then
                return false, result[3]
            end
            if result[2] == false then
                self.coroutine = nil
                return false, "container is shutdown"
            end
            if result[2] == true then
                local success, result = self:bootstrap()

                if success then
                    return true, 0
                end

                return false, result
            end
            if coroutine.status(self.coroutine) == "dead" then
                return false, "computed halted"
            end
            return true, result[2] or math.huge
        end
        
        return false, result[2] or "unknown error" -- probably coroutine is dead
    end
    
    return false, "coroutine is not exists"
end

local function loop(self)
    while true do
        local success, result = self:resume()

        if success then
            if not self.signalQueue[1] then
                local deadline = computer.uptime() + result

                repeat
                    local signal = {computer.pullSignal(deadline - computer.uptime())}

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
    self.signalQueue = {}
    self.componentCache = {}
    self.sandbox = {
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
                    local result = table.pack(self.coroutine.resume(co, ...))
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
        component = {
            doc = function(address, method)
                checkArg(1, address, "string")
                checkArg(2, method, "string")
                if self.components[address].pass then
                    return component.doc(address, method)
                end
                return docs[self.components[address].type] or {}
            end,
            methods = function(address)
                checkArg(1, address, "string")
                if self.components[address].pass then
                    return component.methods(address)
                end
                return methods[self.components[address].type] or {}
            end,
            invoke = function(address, method, ...)
                checkArg(1, address, "string")
                checkArg(2, method, "string")
                if self.components[address].pass then
                    return component.invoke(address, method, ...)
                end
                return spcall(self.components[address].callback[method], ...)
            end,
            list = function(filter, exact)
                local componentsFiltered = {}
                local componentsFilteredIndex = {}
                for address in pairs(self.components) do
                    if not filter or (exact and self.components[address].type == filter or self.components[address].type:find(filter)) then
                        componentsFiltered[address] = self.components[address].type
                        table.insert(componentsFilteredIndex, {
                            address, self.components[address].type
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
                return self.components[address].fields
            end,
            proxy = function(address)
                checkArg(1, address, "string")
                if self.componentCache[address] then
                    return self.componentCache[address]
                end
                if self.components[address] then
                    if self.components[address].pass then
                        return component.proxy(address)
                    end
                    local proxy = {address = address, type = self.components[address].type, slot = self.components[address].slot}
                    for key in pairs(self.components[address].callback) do
                        proxy[key] = setmetatable({}, {
                            __call = function(...)
                                return self.sandbox.invoke(address, key, ...)
                            end,
                            __tostring = function()
                                return self.sandbox.doc(address, key) or tostring(self.components[address].callback[key])
                            end
                        })
                    end
                    self.componentCache[address] = proxy
                    return proxy
                else
                    return nil, "no such component"
                end
            end,
            type = function(address)
                checkArg(1, address, "string")
                return self.components[address].type
            end,
            slot = function(address)
                checkArg(1, address, "string")
                return self.components[address].slot
            end
        },
        computer = {
            pullSignal = function(timeout)
                return coroutine.yield(timeout)
            end,
            pushSignal = function(...)
                table.insert(self.signalQueue, table.pack(...))
                return true
            end,
            address = function()
                return self.address
            end,
            getDeviceInfo = function() return {} end,
            tmpAddress = computer.tmpAddress,
            freeMemory = computer.freeMemory,
            totalMemory = computer.totalMemory,
            uptime = function()
                return computer.uptime() - self.startUptime
            end,
            energy = 1000,
            maxEnergy = 1000,
            users = {},
            shutdown = function(reboot)
                coroutine.yield(not not reboot)
            end,
            addUser = function() return false end,
            removeUser = function() return false end,
            beep = function(...)
                computer.beep(...)
                coroutine.yield(0)
            end,
            getProgramLocations = computer.getProgramLocations,
            getArchitecture = computer.getArchitecture,
            getArchitectures = computer.getArchitectures,
            setArchitecture = function() end,
        },
        unicode = unicode
    }
    self.sandbox._G = self.sandbox

    local eeprom = self.sandbox.component.list("eeprom")()
    if eeprom then
        local code = self.sandbox.component.invoke(eeprom, "get")
        if code and #code > 0 then
            local bios, reason = load(code, "=bios", "t", self.sandbox)
            if bios then
                self.coroutine = coroutine.create(function()
                    self.startUptime = computer.uptime()
                    local success, result = xpcall(bios, debug.traceback)

                    if success then
                        coroutine.yield()
                    end

                    coroutine.yield("error", result)
                end)
                return true
            end
            return false, "failed loading bios: " .. reason
        end
    end
    return false, "no bios found; install a configured EEPROM"
end

local function addComponent(self, type, slot, callbacks)
    local UUID
    repeat
        UUID = uuid()
    until not self.components[UUID] and not component.type(UUID)
    
    self.components[UUID] = {
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

    self:pushSignal{"component_added", UUID, type}
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
    if component.get(address) then
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
    return true
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

local function createContainer()
    local container = {}

    container = {
        address = uuid(),
        components = {},
        passedComponents = {},

        signalQueue = {},
        componentCache = nil,
        sandbox = nil,
        startUptime = nil,

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
    }

    return container
end

-- local container = createContainer()

-- container:passComponent(component.gpu.address)
-- container:passComponent(component.screen.address)
-- container:passComponent(component.keyboard.address)
-- container:passComponent(computer.tmpAddress())
-- container:passComponent(component.internet.address)
-- container:passComponent(component.computer.address)
-- container:passComponent(component.eeprom.address)
-- container:passComponent(component.get("2da")) -- boot floppy

-- require("process").info().data.signal = function() end
-- local success, reason = container:bootstrap()

-- if not success then
--     print(reason)
--     os.exit()
-- end

-- local stopReason = container:loop()
-- component.gpu.setBackground(0x000000)
-- component.gpu.setForeground(0xffffff)
-- require("tty").clear()
-- print(stopReason .. "\nPress any key to continue")

-- while true do
--     if require("event").pull("key_down") then
--         os.exit()
--     end
-- end

return {
    createContainer = createContainer
}
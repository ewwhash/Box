local shell = require("shell")
local component = require("component")
local computer = require("computer")
local unicode = require("unicode")

local args, options = shell.parse(...)

local gpu = component.gpu
local eeprom = component.eeprom
local screen

local components = {
    gpu = component.gpu,
    eeprom = {

    },
    filesystem = {

    },
    eeprom = {
         
    },
    screen = {

    },
    keyboard = {

    },
    internet = {

    },
    modem = {

    }
}

-- local virtualFilesystem, sandbox = {
--     address = filesystem.address,
--     type = filesystem.type,
--     slot = filesystem.slot,
--     spaceUsed =     ,
--     open = function(path, mode)
--         checkArg(path, "string")
--         return filesystem.open(workingPath .. path, mode)
--     end,
--     seek = filesystem.seek,
--     makeDirectory = function(path)
--         checkArg(path, "string")
--         return filesystem.makeDirectory(workingPath .. path)
--     end,
--     exists = function(path)
--         checkArg(path, "string")
--         return filesystem.exists(workingPath .. path)
--     end,
--     isReadOnly = filesystem.isReadOnly,
--     write = filesystem.write,
--     spaceTotal = filesystem.spaceTotal,
--     isDirectory = function(path)
--         checkArg(path, "string")
--         return filesystem.isDirectory(workingPath .. path)
--     end,
--     rename = function(from, to)
--         checkArg(path, "string")
--         return filesystem.rename(workingPath .. from, workingPath .. to)
--     end,
--     list = function(path)
--         checkArg(path, "string")
--         return filesystem.list(workingPath .. path)
--     end,
--     lastModified = function(path)
--         checkArg(path, "string")
--         return filesystem.lastModified(workingPath .. path)
--     end,
--     getLabel = filesystem.getLabel,
--     remove = function(path)
--         checkArg(path, "string")
--         filesystem.remove(workingPath .. path)
--     end,
--     close = filesystem.close,
--     size = function(path)
--         checkArg(path, "string")
--         return filesystem.size(path) 
--     end,
--     read = filesystem.read,
--     setLabel = function() end,
-- }

if true or pure then
    local libcomponent = {
        doc = component.doc,
        invoke = function(address, method, ...)
            if address == virtualFilesystem.address then
                error()
                return virtualFilesystem[method](...)
            end

            return component.invoke(address, method, ...)
        end,
        list = component.list,
        methods = component.methods,
        fields = component.fields,
        proxy = function(address)
            if address == virtualFilesystem.address then
                return virtualFilesystem
            end

            return component.proxy(address)
        end,
        type = component.type,
        slot = component.slot   
    }

    local libcomputer = {
        address = computer.address,
        tmpAddress = function() end, 
        shutdown = function() coroutine.yield("COMPUTER_SHUTDOWN") end,
        pushSignal = computer.pushSignal,
        pullSignal = computer.pullSignal,
        getDeviceInfo = computer.getDeviceInfo,
        freeMemory = computer.freeMemory,
        totalMemory = computer.totalMemory,
        uptime = computer.uptime,
        energy = computer.energy,
        maxEnergy = computer.maxEnergy,
        users = computer.users,
        addUser = function() end,
        removeUser = function() end,
        beep = computer.beep,
        getProgramLocations = computer.getProgramLocations,
        getArchitecture = computer.getArchitecture,
        getArchitectures = computer.getArchitectures,
        setArchitecture = function() end
    }

    sandbox = {
        assert = assert,
        error = error, -- todo
        _G = nil,
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
        coroutine = coroutine,
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
        unicode = require("unicode")
    }
else
    sandbox = setmetatable({
        component = setmetatable({
            invoke = function(address, method, ...)
                if address == virtualFilesystem.address then
                    computer.beep()
                    return virtualFilesystem[method](...)
                else
                    return component.invoke(address, method, ...)
                end
            end
        }, {__index = component})
    }, {__index = _G})
end

require("process").info().data.signal = function() end

local code

do local 
    file = io.open("OS.lua", "r")
    code = file:read("*a")
    file:close()
end

print(require'serialization'.serialize(virtualFilesystem.list("/")))
local success, reason = load(code, "=OS.lua", nil, sandbox)

if success then
    container = coroutine.create(success)
    local success, reason = coroutine.resume(container)

    computer.pushSignal"interrupted"
    io.read()
    component.gpu.setResolution(oldWidth, oldHeight)
    component.gpu.setBackground(0x000000)
    component.gpu.setForeground(0xffffff)
    require("term").clear()

    if reason then
        io.stderr:write(reason)
    end
else
    error(reason)
end
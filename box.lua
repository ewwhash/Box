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
        elseif signal[2] == spcall(container.libcomponent.invoke, container.libcomponent.list("disk_drive")(), "media") then
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
        unicode = unicode
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

local gpu = component.gpu
local container = createContainer()

container:passComponent(component.keyboard.address)
container:passComponent(component.internet.address)
container:passComponent(computer.tmpAddress())
container:passComponent(component.computer.address)
container:passComponent(component.get('b46')) -- disk drive

local eepromData = ""
container:addComponent("eeprom", container:randomComponentUUID(), {
    get = function()
        return [[
local a,b,c,d,e,f,g,h,i,j,k,l,m,n=component,computer,unicode,math,{"/init.lua","/OS.lua"},{},{},{}local function o(p)local q={b.pullSignal(p)}q[1]=q[1]or""if cyan and(q[1]:match("ey")and not cyan:match(q[5])or q[1]:match("cl")and not cyan:match(q[4]))then return""end;g[q[4]or""]=q[1]:match"do"and 1;if g[29]and(g[46]or g[32])and q[1]:match"do"then return"F"end;return table.unpack(q)end;local function r(s)return a.list(s)()and a.proxy(a.list(s)())end;local function t(u,v)n={}for w in u:gmatch"[^\r\n]+"do n[#n+1]=w:gsub("\t",v and"    "or"")end end;local function x(p,y,z,A,B,C,D)A=b.uptime()+(p or d.huge)::E::B,D,D,C=o(A-b.uptime())if B=="F"or B:match"do"and(C==y or y==0)then return 1,z and z()elseif b.uptime()<A then goto E end end;local function G(H,I,J,K,L)k.setBackground(K or 0x002b36)k.setForeground(L or 0x8cb9c5)k.set(H,I,J)end;local function M(H,I,N,O,K,L)k.setBackground(K or 0x002b36)k.setForeground(L or 0x8cb9c5)k.fill(H,I,N,O," ")end;local function P()M(1,1,i,j)end;local function Q(R)return d.floor(i/2-R/2)end;local function S(I,u,K,L)G(Q(c.len(u)),I,u,K,L)end;local function T()k,l=r"gp",r"sc"if k and l then if k.getScreen()~=l.address then k.bind(l.address)end;local U,V,W=l.getAspectRatio()i,j=k.maxResolution()W=2*(16*U-4.5)/(16*V-4.5)if W>i/j then j=d.floor(i/W)else i=d.floor(j*W)end;k.setResolution(i,j)k.setPaletteColor(9,0x002b36)k.setPaletteColor(11,0x8cb9c5)end end;local function X(u,Y,Z,y,z,I)if k and l then P()t(u)I=d.ceil(j/2-#n/2)if Y then S(I-1,Y,0x002b36,0xffffff)I=I+1 end;for _=1,#n do S(I,n[_])I=I+1 end;x(Z or 0,y or 0,z)end end;local function a0(u,a1)return c.len(u)>a1 and c.sub(u,1,a1).."…"or u end;local function a2(a3,I,a4,a5,L)local u,a6,a7,a8,a9,H,B,aa,C,D="",c.len(a3),1,1;L=L or 0x8cb9c5::E::H=a4 and Q(c.len(u)+a6)or 1;a9=H+a6+a7-1;M(1,I,i,1)G(H,I,a3 ..u,F,L)if a9<=i then G(a9,I,k.get(a9,I),a8 and L or 0x002b36,a8 and 0x002b36 or L)end;B,D,aa,C=o(.5)if B:match"do"then if C==203 and a7>1 then a7=a7-1 elseif C==205 and a7<=c.len(u)then a7=a7+1 elseif C==200 and a5 then u=a5;a7=c.len(a5)+1 elseif C==208 and a5 then u=""a7=1 elseif C==14 and#u>0 and a7>1 then u=g[29]and""or c.sub(c.sub(u,1,a7-1),1,-2)..c.sub(u,a7,-1)a7=g[29]and 1 or a7-1 elseif C==28 then return u elseif aa>=32 and c.len(a6 ..u)<i-a6 then u=c.sub(u,1,a7-1)..c.char(aa)..c.sub(u,a7,-1)a7=a7+1 end;a8=1 elseif B:match"cl"then u=c.sub(u,1,a7-1)..aa..c.sub(u,a7,-1)a7=a7+c.len(aa)elseif B:match"mp"or B=="F"then m=B:match"mp"and 1;return elseif not B:match"up"then a8=not a8 end;goto E end;local function ab(C,ac,ad,ae,af)af=af or xpcall;local ag,ah=load("return "..C,ac,F,ad)if not ag then ag,ah=load(C,ac,F,ad)end;if ag then if ae and k then x(.3)M(1,1,i or 0,j or 0,0)k.setPaletteColor(9,0x969696)k.setPaletteColor(11,0xb4b4b4)end;return af(ag,debug.traceback)end;return F,ah end;local function ai(aj)local r,ak,al,_=a.proxy(aj),{s=1,z=1}if r and aj~=b.tmpAddress()then _=#f+1;f[_]={r=r,l=ak,d=r,p=function(am,I)am=am and P()or am;S(I or j/2,am and("Booting %s from %s (%s)"):format(al,r.getLabel()or"N/A",a0(aj,i>80 and 36 or 6))or al and("Boot%s %s (%s)"):format((#ak==1 and" "..al or"").." from",a0(r.getLabel()or"N/A",6),a0(aj,6))or("Boot from %s (%s) isn't available"):format(r.getLabel()or"N/A",a0(aj,6)),F,not am and 0xffffff)am=am and not h and cyan:match("$")and(X("Hold ENTER to boot")or x(F,28))end}f[_].b=function()if al then local an,ao,ag,ap,ah=r.open(al,"r"),""::E::ag=r.read(an,d.huge)if ag then ao=ao..ag;goto E end;r.close(an)pcall(f[_].p,1)ag=b.getBootAddress()~=aj and b.setBootAddress(aj)ap,ah=ab(ao,"="..al,F,1)ap=ap and pcall(b.shutdown)pcall(T)pcall(X,ah,"¯\\_(ツ)_/¯",d.huge,0,b.shutdown)error(ah)end end;for aq=1,#e do if r.exists(e[aq])then al=al or e[aq]ak[#ak+1]={e[aq],function()al=e[aq]f[_].b()end}end end end end;local function ar()f={}ai(b.getBootAddress()or"")for aj in next,a.list"file"do ai(aj~=b.getBootAddress()and aj or"")end end;local function as(at,I,au,av,aw,ax)local ay,H=0;for _=1,#at do ay=ay+c.len(at[_][1])+au end;ay=ay-au;H=Q(ay)if ax then ax()end;for _=1,#at do if at.s==_ and aw then M(H-au/2,I-d.floor(av/2),c.len(at[_][1])+au,av,0x8cb9c5)G(H,I,at[_][1],0x8cb9c5,0x002b36)else G(H,I,at[_][1],0x002b36,0x8cb9c5)end;H=H+c.len(at[_][1])+au end end;local function az(ad,ao,aA,u)P()ad=setmetatable({print=function(...)u=table.pack(...)for _=1,u.n do if type(u[_])=="table"then aA=''for aB,aC in pairs(u[_])do aA=aA..tostring(aB).."    "..tostring(aC).."\n"end;u[_]=aA else u[_]=tostring(u[_])end end;t(table.concat(u,"    "),1)for _=1,#n do k.copy(1,1,i,j-1,0,-1)M(1,j-1,i,1)G(1,j-1,n[_])end end,proxy=r,sleep=function(p)x(p,32,error)end},{__index=_G})::E::ao=a2("> ",j,F,ao,0xffffff,ad)if ao then ad.print("> "..ao)M(1,j,i,1)G(1,j,">")ad.print(select(2,ab(ao,"=shell",ad)))goto E end end;local function aD()h=1,not k and error("No drives available")::aE::local aF,aG,aH,aI,B,C,aJ,aK,I,aL,aM,D={s=1}aH={s=1,p=1,{"Halt",b.shutdown},{"Shell",az},r"net"and{"Netboot",function()P()S(j/2-1,"Netboot",F,0xffffff)aK=a2("URL: ",j/2+1,1,F,0x8cb9c5)if aK and#aK>0 then local an,ao,ag=r"net".request(aK,F,F,{["user-agent"]="Netboot"}),""if an then X("Downloading script...","Netboot")::E::ag=an.read()if ag then ao=ao..ag;goto E end;ao=select(2,ab(ao,"=stdin",F,1,pcall))or""T()X(ao,"Netboot",#ao==0 and 0 or d.huge)else X("Invalid URL","Netboot",d.huge)end end end}}aG=#aH+1;m=F;aM=F;ar()for _=1,#f do aF[_]={a0(f[_].d.getLabel()or"N/A",6),function()if#f[_].l>0 then aM=_;aI=f[aM].l;if#aI==1 then aI[1][2]()end end end}end;aI=#f>0 and aF or aH::E::pcall(function()P()if aI.z then S(j/2-2,"Select boot entry",F,0xffffff)as(aI,j/2+2,6,3,1)else I=j/2-(#f>0 and-1 or 1)as(aF,I-4,8,3,not aI.p and 1,function()if#f>0 then aL=f[aF.s].r;f[aF.s].p(F,I+3)S(I+5,("Storage %s%% / %s / %s"):format(d.floor(aL.spaceUsed()/(aL.spaceTotal()/100)),aL.isReadOnly()and"Read only"or"Read & Write",aL.spaceTotal()<2^20 and"FDD"or aL.spaceTotal()<2^20*12 and"HDD"or"RAID"))for _=aG,#aH do aH[_]=F end;aH[aG]={"Rename",function()P()S(j/2-1,"Rename",F,0xffffff)aJ=a2("Enter new name: ",j/2+1,1,F,0x8cb9c5)if aJ and#aJ>0 and pcall(aL.setLabel,aJ)then aL.setLabel(aJ)aF[aF.s][1]=a0(aL.getLabel()or"N/A",6)end end}if not aL.isReadOnly()then aH[aG+1]={"Format",function()aL.remove("/")aL.setLabel(F)aF[aF.s][1]=a0(aL.getLabel()or"N/A",6)end}end else S(I+3,"No drives available",F,0xffffff)end end)as(aH,I,6,1,aI.p and 1 or F)end end)B,D,D,C=o()D=B=="F"and b.shutdown()if B:match"mp"or m then pcall(T)goto aE end;if B:match"do"and k and l then aI=(C==200 or C==208)and(aI.z and aF or#f>0 and(aI.p and aF or aH))or aI;aI.s=C==203 and(aI.s==1 and#aI or aI.s-1)or C==205 and(aI.s==#aI and 1 or aI.s+1)or aI.s;if C==28 then aI[aI.s][2]()end end;goto E end;b.getBootAddress=function()return r"pro"and r"pro".getData()end;b.setBootAddress=function(aN)return r"pro"and r"pro".setData(aN)end;ar()T()X("Hold ALT to stay in bootloader",F,1,56,aD)for _=1,#f do f[_].b()end;aD()     
        ]]
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
        return eepromData
    end,
    setData = function(self, data)
        checkArg(1, data, "string")
        eepromData = data
    end,
    getChecksum = function(self)
        return "hv62jd1"
    end,
    makeReadonly = function(self)
        return false
    end
})

local screen = container:addComponent("screen", container:randomComponentUUID(), {
    isOn = function(self)
        return true
    end,
    turnOn = function(self)
        return
    end,
    turnOff = function(self)
        return
    end,
    getAspectRatio = function(self)
        return component.screen.getAspectRatio()
    end,
    geyKeyboards = function(self)
        return {
            container.libcomponent.list("keyboard")(),
            n = 1
        }
    end,
    setPrecise = function(self)
        return false
    end,
    isPrecise = function(self)
        return component.screen.isPrecise()
    end,
    setTouchModeEnabled = function(self)
        return false
    end,
    isTouchModeInverted = function(self)
        return component.screen.isTouchModeInverted()
    end
})

local function redrawTitleBar()
    component.gpu.setBackground(0xf0f0f0)
    component.gpu.fill(1, 1, 160, 1, " ")
end

local oldPalette, oldWidth, oldHeight = {}

local gpu = container:addComponent("gpu", container:randomComponentUUID(), {
    bind = function(self, address, reset)
        return true
    end,
    getScreen = function(self)
        return screen.address
    end,
    getBackground = function(self)
        return component.gpu.getBackground()
    end,
    setBackground = function(self, ...)
        debug_print(debug.traceback())
        computer.beep(1700, 0.07)
        require'event'.pull("key_down")
        return component.gpu.setBackground(...)
    end,
    getForeground = function(self, ...)
        return component.gpu.getForeground(...)
    end,
    setForeground = function(self, ...)
        return component.gpu.setForeground(...)
    end,
    getPaletteColor = function(self, ...)
        return component.gpu.getPaletteColor(...)
    end,
    setPaletteColor = function(self, ...)
        return component.gpu.setPaletteColor(...)
    end,
    maxDepth = function(self)
        return component.gpu.maxDepth()
    end,
    getDepth = function(self)
        return component.gpu.getDepth()
    end,
    setDepth = function(self, ...)
        return false
    end,
    maxResolution = function(self)
        return oldWidth, oldHeight - 1
    end,
    getResolution = function(self)
        local w, h = component.gpu.getResolution()
        return w, h - 1
    end,
    setResolution = function(self, width, height)
        if height - 1 > oldHeight then
            error("unsupported resolution")
        end
        return component.gpu.setResolution(width, height + 1)
    end,
    getViewport = function(self)
        return oldWidth, oldHeight - 1
    end,
    setViewport = function(self, width, height)
        return false
    end,
    get = function(self, x, y)
        -- local w, h = component.gpu.getResolution()
        -- if y - 1 > h then
        --     error("index out of bounds")
        -- end
        return component.gpu.get(x, y + 1)
    end,
    set = function(self, x, y, symbol, vertical)
        return component.gpu.set(x, y + 1, symbol, vertical)
    end,
    copy = function(self, x, y, w, h, tx, ty)
        local result = component.gpu.copy(x, y, w, h, tx, ty + 1)
        -- if result then
        --     redrawTitleBar()
        -- end
        return result
    end,
    fill = function(self, x, y, w, h, char)
        return component.gpu.fill(x, y + 1, w, h, char)
    end
})

local function halt(reason)
    component.gpu.setResolution(oldWidth, oldHeight)
    component.gpu.setBackground(0x000000)
    component.gpu.setForeground(0xffffff)
    for i = 1, 15 do
        component.gpu.setPaletteColor(i, oldPalette[i])
    end
    require("tty").clear()
    print((reason or "unknown reason") .. "\nPress any key to continue")

    if reason ~= "container shutdown" then
        computer.beep("--")
    end

    for i = 1, 10 do
        os.sleep(0) -- collecting garbage
    end

    while true do
        if require("event").pull("key_down") then
            os.exit()
        end
    end
end

require("process").info().data.signal = function() end
require("tty").clear()
local success, result = container:bootstrap()

if not success then
    halt(result)
end

for i = 1, 15 do
    oldPalette[i] = component.gpu.getPaletteColor(i)
end
oldWidth, oldHeight = component.gpu.getResolution()

halt(container:loop())

return {
    createContainer = createContainer
}
local component = require("component")
local serialization = require("serialization")

local docs = {
    
}

local methods = {
    
}

for address, componentType in component.list() do
    if not docs[componentType] then
        for method, isDirect in pairs(component.methods(address)) do
            docs[method] = component.doc(address, method)
            methods[method] = isDirect
        end
    end
end

docs = serialization.serialize(docs)
methods = serialization.serialize(methods)

local file = io.open("docs.lua", "w")
file:write(docs)
file:close()
file = io.open("methods.lua", "w")
file:write(methods)
file:close()
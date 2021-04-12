local component = require("component")
local serialization = require("serialization")

local docs, methods = {}, {}

for address, componentType in component.list() do
    if not docs[componentType] then
        docs[componentType] = {}
        methods[componentType] = {}

        for method, isDirect in pairs(component.methods(address)) do
            docs[componentType][method] = component.doc(address, method)
            methods[componentType][method] = isDirect
        end
    end
end

docs = serialization.serialize(docs, math.huge)
methods = serialization.serialize(methods, math.huge)

local file = io.open("docs.lua", "w")
file:write(docs)
file:close()
file = io.open("methods.lua", "w")
file:write(methods)
file:close()
local thread = require("thread")

local function createMagicTable()
    local self

    self = {
        yield = function()
            print("here")
            coroutine.yield("rip")
            print("here again") -- at this moment we are dead
        end,
        runCode = function(code)
            local chunk, reason = load(code, "=stdin", "t", {yield = self.yield, print = print})

            if chunk then
                self.coroutine = coroutine.create(chunk)
            end

            return chunk, reason
        end,
        coroutine = nil
    }

    return self
end

local magic = createMagicTable()
magic.runCode("yield() print('dead')")

local function test()
    while true do
        local success, reason = coroutine.resume(magic.coroutine)
        print(success, reason)
        if not success then
            require'computer'.beep()
            return
        end
        os.sleep(0)
    end
end

thread.create(test):detach()
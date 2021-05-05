-- local GUI = require("UI.GUI")
local buffer = require("UI.buffer")
-- local image = require("UI.image")

local component = require("component")
local unicode = require("unicode")
local computer = require("computer")
local width, height = component.gpu.getResolution()

buffer.setGPUProxy(component.gpu)

for y = 1, height do
    for x = 1, width do
        local symbol, foreground, background = component.gpu.get(x, y)
        buffer.set(x, y, background, foreground, symbol)
    end
end

local oldScreen = buffer.copy(1, 1, width, height)
print(computer.freeMemory() / 1024 / 1024)

--------------------------------------------------------------------------------

-- local function close()
-- 	for i = 1, 10 do
-- 		os.sleep(0)
-- 	end
--     os.exit()
-- end

-- local function windowCheck(window, x, y)
-- 	local child
-- 	for i = #window.children, 1, -1 do
-- 		child = window.children[i]
		
-- 		if
-- 			not child.hidden and
-- 			not child.disabled and
-- 			child:isPointInside(x, y)
-- 		then
-- 			if not child.passScreenEvents and child.eventHandler then
-- 				return true
-- 			elseif child.children then
-- 				local result = windowCheck(child, x, y)
-- 				if result == true then
-- 					return true
-- 				elseif result == false then
-- 					return false
-- 				end
-- 			end
-- 		end
-- 	end
-- end

-- local function windowEventHandler(workspace, window, e1, e2, e3, e4, ...)
-- 	if window.movingEnabled then
-- 		if e1 == "touch" then
-- 			if not windowCheck(window, e3, e4) then
-- 				window.lastTouchX, window.lastTouchY = e3, e4
-- 			end

-- 			if window ~= window.parent.children[#window.parent.children] then
-- 				window:moveToFront()
				
-- 				if window.onFocus then
-- 					window.onFocus(workspace, window, e1, e2, e3, e4, ...)
-- 				end

-- 				workspace:draw()
-- 			end
-- 		elseif e1 == "drag" and window.lastTouchX and not windowCheck(window, e3, e4) then
-- 			local xOffset, yOffset = e3 - window.lastTouchX, e4 - window.lastTouchY
-- 			if xOffset ~= 0 or yOffset ~= 0 then
-- 				window.localX, window.localY = window.localX + xOffset, window.localY + yOffset
-- 				window.lastTouchX, window.lastTouchY = e3, e4
				
-- 				workspace:draw()
-- 			end
-- 		elseif e1 == "drop" then
-- 			window.lastTouchX, window.lastTouchY = nil, nil
-- 		end
-- 	end
-- end

-- local function windowResize(window, width, height, ignoreOnResizeFinished)
-- 	window.width, window.height = width, height
	
-- 	if window.onResize then
-- 		window.onResize(width, height)
-- 	end

-- 	if window.onResizeFinished and not ignoreOnResizeFinished then
-- 		window.onResizeFinished()
-- 	end

-- 	return window
-- end

-- --------------------------------------------------------------------------------

-- local workspace = GUI.workspace()
-- workspace:addChild(GUI.panel(1, 1, width, height, 0x2D2D2D))
-- -- workspace:addChild(GUI.image(1, 2, image.transform(image.load("/home/space.pic"), width, height)))
-- -- workspace:addChild(GUI.object(1, 1, width, height)).draw = function()
-- --     -- buffer.paste(1, -5, oldScreen)
-- -- end

-- local window = workspace:addChild(GUI.container(20, 10, 72, 22))

-- local function windowMaximize()
--     window:maximize()
--     window.movingEnabled = not window.movingEnabled
-- end

-- window.passScreenEvents = false
-- window.resize = windowResize
-- window.maximize = GUI.windowMaximize
-- window.minimize = GUI.windowMinimize
-- window.eventHandler = windowEventHandler
-- window.movingEnabled = true

-- window.backgroundPanel = window:addChild(GUI.panel(1, 1, width, height, 0xffffff))
-- window.backgroundPanel.colors.transparency = 0.3

-- window:addChild(GUI.button(1, 1, 1, 1, nil, 0xFF4940, nil, 0x992400, "⬤")).onTouch = close
-- window:addChild(GUI.button(3, 1, 1, 1, nil, 0xFFB640, nil, 0x996D00, "⬤")).onTouch = close
-- window:addChild(GUI.button(5, 1, 1, 1, nil, 0x00B640, nil, 0x006D40, "⬤")).onTouch = windowMaximize

-- window:addChild(GUI.roundedButton(2, 18, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "Rounded button")).onTouch = function()
-- 	GUI.alert(require'computer'.freeMemory()/1024/1024)
-- end

-- --------------------------------------------------------------------------------

-- require("process").info().data.signal = close
-- workspace:draw()
-- workspace:start()
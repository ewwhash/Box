local signals = { -- signals passthrough
    key_down = function(container, signal)
        if container.component.list[signal[2]] then
            table.insert(container.signalQueue, signal)
            return true
        end
        return false
    end,
    key_up = function(container, signal)
        if container.component.list[signal[2]] then
            table.insert(container.signalQueue, signal)
            return true
        end
        return false
    end,
    clipboard = function(container, signal)
        if container.component.list[signal[2]] then
            table.insert(container.signalQueue, signal)
            return true
        end
        return false
    end,
    screen_resized = function(container, signal)
    end,
    touch = function(container, signal)
        if container.component.list[signal[2]] then
            table.insert(container.signalQueue, signal)
            return true
        end
        return false
    end,
    drag = function(container, signal)
        if container.component.list[signal[2]] then
            table.insert(container.signalQueue, signal)
            return true
        end
        return false
    end,
    drop = function(container, signal)
        if container.component.list[signal[2]] then
            table.insert(container.signalQueue, signal)
            return true
        end
        return false
    end,
    scroll = function(container, signal)
        if container.component.list[signal[2]] then
            table.insert(container.signalQueue, signal)
            return true
        end
        return false
    end,
    walk = function(container, signal)
        if container.component.list[signal[2]] then
            table.insert(container.signalQueue, signal)
            return true
        end
        return false
    end,
    redstone_chanded = function(container, signal)
        if container.component.list[signal[2]] then
            table.insert(container.signalQueue, signal)
            return true
        end
        return false
    end,
    motion = function(container, signal)
        if container.component.list[signal[2]] then
            table.insert(container.signalQueue, signal)
            return true
        end
        return false
    end,
    modem_message = function(container, signal)
        if container.component.list[signal[2]] then
            table.insert(container.signalQueue, signal)
            return true
        end
        return false
    end,
    component_removed = function(container, signal)
        if container.component.list[signal[2]] then
            container.component.remove(signal[2])
            table.insert(container.signalQueue, signal)
            return true
        end
        return false
    end
}

return signals
local signals = { -- signals passthrough
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
            container:removeComponent(signal[2])
            return true
        end
        return false
    end,
    component_added = function(container, signal)    
        if container.passedComponents[signal[2]] then
            container:readdPassedComponent(signal[2])
            return true
        end
        return false
    end
}

return signals
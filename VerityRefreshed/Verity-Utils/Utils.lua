-- EQUILIBRIUM UTILITY MODULE
-- Shared helper functions for all builds
-- Optimized for performance and safety

local Utils = {}

-- Safe Service Getter (Prevents crashes on missing services)
function Utils.SafeGetService(serviceName)
    local success, service = pcall(function()
        return game:GetService(serviceName)
    end)
    return success and service or nil
end

-- Safe Child Finder (Returns nil instead of erroring)
function Utils.FindChildSafe(parent, childName)
    if not parent then return nil end
    return parent:FindFirstChild(childName)
end

-- Tween Helper
function Utils.CreateTween(instance, properties, duration, style)
    local tweenInfo = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = Utils.SafeGetService("TweenService"):Create(instance, tweenInfo, properties)
    return tween
end

-- Debounce Wrapper
function Utils.Debounce(func, delay)
    local lastCall = 0
    return function(...)
        local now = tick()
        if now - lastCall >= delay then
            lastCall = now
            return func(...)
        end
    end
end

-- Safe Table Get (Nested access without errors)
function Utils.SafeGet(table, ...)
    local keys = {...}
    local current = table
    for _, key in ipairs(keys) do
        if type(current) ~= "table" then return nil end
        current = current[key]
    end
    return current
end

return Utils

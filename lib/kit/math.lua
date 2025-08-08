
local dbg = require("lib.kit.debug") or {print = function() end,warn = function() end,error = function() end}

local mat = {}

--//转换为有限精确string
function mat.floattrans (x,i)
    return string.format("%." .. i .. "f", x)
end
--//输出数轴两侧范围区间内的值
function mat.sideSp(min,max)
    local n = math.random(0,1)
    if n == 0 then
        return math.random(min,max)
    else
        return math.random(-max,-min)
    end
end
--//线性插值
function mat.Lerp(a, b, t)
    if type(a) ~= "number" or type(b) ~= "number" or type(t) ~= "number" then
        dbg.error("Lerp(a, b, t): all arguments must be numbers")
        return a or 0
    end
    t = math.max(0, math.min(1, t))
    return a * (1 - t) + b * t
end

function mat.Parab(St,En,t,ct)
    local r_ct = 0.5
    local r_t = 0.5
    if ct then
        if type(ct) == "number" then
            r_ct = math.max(0.1, math.min(ct,0.9))
        else
            dbg.error("ct isn't a number!")
        end
    end
    if t then
        if type(t) == "number" then
            r_t = math.max(0, math.min(t,1))
        else
            dbg.error("ct isn't a number!")
        end
    end

    local a1 = 1 / (r_ct^2)
    local pv = a1 * r_ct

    local denom = (1 - r_ct)^2
    local a2 = (pv * (1 - r_ct) - 0.5) * 2 / denom

    local x
    if r_t <= r_ct then
        x = pv / 2 * r_t
    else
        local dt = r_t - r_ct
        x = 0.5 + pv * dt - 0.5 * a2 * dt^2
    end

    return mat.Lerp(St,En,x)
end
--将正负数转化为+1，-1
function mat.direction (n)
    if type(n) == "number" then
        if n > 0 then
            return 1
        elseif n < 0 then
            return -1
        end
    end
    return 0
end
--转化为特定方向
function mat.reversion (n,r)
    if type(n) == "number" then
        if r == 0 then
            return -math.abs(n)
        else
            return math.abs(n)
        end
    end
    return 0
end

return mat
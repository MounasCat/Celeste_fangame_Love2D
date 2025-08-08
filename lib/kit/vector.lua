--[[
        注意：这里的坐标是正常的直角坐标系坐标（y轴向上为正）
           ^Y
           |
           |           
    -------o------>X
           |
           |
           |
]]

local dbg = require("lib.kit.debug") or {print = function() end,warn = function() end,error = function() end}

local function floattrans (x,i)
    return string.format("%." .. i .. "f", x)
end

local vec = {}
    
--attention: call this function will change the y to negative,and generate a new tabel,
--be careful the RAM if you always call it.
function vec.vec2(r_x,r_y)
    local r = {x = 0,y = 0}
    if type(r_x) == "number" and type(r_y) == "number" then
        r.x,r.y = r_x,-r_y
    else
        dbg.error("one of r_x,r_y isn't a number!")
    end
    return r
end

function vec.pVec2(v1,v2)--sum
    if type(v1) == "table" and type(v2) == "table" then
        if type(v1.x) == "number" and type(v1.y) and type(v2.x) == "number" and type(v2.y) then
            return(v1.x + v2.x),(v1.y + v2.y)
        else
            dbg.error("one of x,y isn't a number!")
        end
    else
        dbg.error("one of v1,v2 isn't a table!")
    end
    return 0, 0
end

function vec.sVec2(v1,v2)--sub
    if type(v1) == "table" and type(v2) == "table" then
        if type(v1.x) == "number" and type(v1.y) and type(v2.x) == "number" and type(v2.y) then
            return(v1.x - v2.x),(v1.y - v2.y)
        else
            dbg.error("one of x,y isn't a number!")
        end
    else
        dbg.error("one of v1,v2 isn't a table!")
    end
    return 0, 0
end
function vec.mVec2(v1,v2)--multi
    if type(v1) == "table" and type(v2) == "table" then
        if type(v1.x) == "number" and type(v1.y) and type(v2.x) == "number" and type(v2.y) then
            return (v1.x * v2.x), (v1.y * v2.y)
        else
            dbg.error("one of x,y isn't a number!")
        end
    else
        dbg.error("one of v1,v2 isn't a table!")
    end
    return 0, 0
end
function vec.NmVec2(Vec2,N)--multi a number
   if type(Vec2) == "table" then
        if type(Vec2.x) == "number" and type(Vec2.y) then
            if type(N) == "number" then
                return Vec2.x*N, Vec2.y*N
            else
                dbg.error("N isn't a number")
            end
        else
            dbg.error("one of x,y isn't a number!")
        end
    else
        dbg.error("Vec2 isn't a table!")
    end
    return 0, 0
end
function vec.dtVec2(v1,v2,dt,lx,ly)
     if type(v1) == "table" and type(v2) == "table" then
        if type(v1.x) == "number" and type(v1.y) and type(v2.x) == "number" and type(v2.y) then
            return (v1.x + v2.x*dt), (v1.y + v2.y*dt)
        else
            dbg.error("one of x,y isn't a number!")
        end
    else
        dbg.error("one of v1,v2 isn't a table!")
    end
    return 0, 0
end

function vec.AtoVec2(A)--transform orientaion to the vector2(y is -)
    if type(A) == "number" then
        return 1 * math.cos(A),-1 * math.sin(A)
    else
        dbg.error("A isn't a number!")
    end
    return 0, 0
end

function vec.Vec2toA(Vec2)--transform vector2 to the orientaion
    if type(Vec2) == "table" then
        if type(Vec2.x) == "number" and type(Vec2.y) then
            if Vec2.x >= 0 then
                return math.atan(-Vec2.y/Vec2.x)
            else
                return math.pi + math.atan(Vec2.y/-Vec2.x)
            end
        else
            dbg.error("one of x,y isn't a number!")
        end
    else
        dbg.error("Vec2 isn't a table!")
    end
    return 0
end

--attention: call this function will change the y to negative,and generate a new tabel,
--be careful the RAM if you always call it.
function vec.Vec2toL2Dxy(Vec2)
    if type(Vec2) == "table" then
        if type(Vec2.x) == "number" and type(Vec2.y) == "number" then
            return Vec2.x,-Vec2.y
        else
            dbg.error("one of x,y isn't a number!")
        end
    else
        dbg.error("Vec2 isn't a table!")
    end
    return 0, 0
end

function vec.ToUnit(Vec2)
    local d = 0.01
    if type(Vec2) == "table" then
        if type(Vec2.x) == "number" and type(Vec2.y) == "number" then
            if math.sqrt(Vec2.x^2 + Vec2.y^2) ~= 0 then
                d = math.sqrt(Vec2.x^2 + Vec2.y^2)
            end
            return Vec2.x/d,Vec2.y/d
        else
            dbg.error("one of x,y isn't a number!")
        end
    else
        dbg.error("Vec2 isn't a table!")
    end
    return 0, 0
end

function vec.ToInputUnit(Vec2,unit)
    local d = 0.01
    local _u = 1
    if unit ~= nil then
        if type(unit) == "number" then
            if unit >= 0 and unit <= 10^3 then
                _u = unit
            else
                dbg.error("unit over limit!")
            end
        else
            dbg.error("unit isn't a number!")
        end
    end
    if type(Vec2) == "table" then
        if type(Vec2.x) == "number" and type(Vec2.y) == "number" then
            if math.sqrt(Vec2.x^2 + Vec2.y^2) ~= 0 then
                d = math.sqrt(Vec2.x^2 + Vec2.y^2)
            end
            return Vec2.x/d*_u,Vec2.y/d*_u
        else
            dbg.error("one of x,y isn't a number!")
        end
    else
        dbg.error("Vec2 isn't a table!")
    end
    return _u, _u
end

function vec.Torelate(v1,v2)--v1 ->(relate to) v2
    if type(v1) == "table" and type(v2) == "table" then
        if type(v1.x) == "number" and type(v1.y) and type(v2.x) == "number" and type(v2.y) then
            return v1.x - v2.x, v1.y - v2.y
        else
            dbg.error("one of x,y isn't a number!")
        end
    else
        dbg.error("one of v1,v2 isn't a table!")
    end
    return 0, 0
end
function vec.Toglobal(v1,v2)--v1(relate to v2(global)) ->(trans to) global vec2
    if type(v1) == "table" and type(v2) == "table" then
        if type(v1.x) == "number" and type(v1.y) and type(v2.x) == "number" and type(v2.y) then
            return v1.x + v2.x, v1.y + v2.y
        else
            dbg.error("one of x,y isn't a number!")
        end
    else
        dbg.error("one of v1,v2 isn't a table!")
    end
    return 0, 0
end

function vec.Tostr(Vec2,f)
    local r = "Vector2(0, 0)"
    local _f = 2
    if f ~= nil then
        if type(f) == "number" then
            if f >= 0 and f <= 10 then
                _f = f
            else
                dbg.error("f over limit!")
            end
        else
            dbg.error("f isn't a number!")
        end
    end
    if type(Vec2) == "table" then
        if type(Vec2.x) == "number" and type(Vec2.y) == "number" then
            r = "Vector2(" .. floattrans(Vec2.x,_f) .. ", " .. floattrans(Vec2.y,_f) .. ")"
        else
            dbg.error("one of x,y isn't a number!")
        end
    else
        dbg.error("Vec2 isn't a table!")
    end
    return r
end

function vec.Lerp(v1, v2, t)
    local _t = 0.5
    if t ~= nil then
        if type(t) == "number" then
            _t = math.max(0, math.min(1, t or 0.5))
        else
            dbg.error("f isn't a number! or over limit!")
        end
    end
    if type(v1) == "table" and type(v2) == "table" then
        if type(v1.x) == "number" and type(v1.y) and type(v2.x) == "number" and type(v2.y) then
            return v1.x * (1 - _t) + v2.x * _t, v1.y * (1 - _t) + v2.y * _t
        else
            dbg.error("one of x,y isn't a number!")
        end
    else
        dbg.error("one of v1,v2 isn't a table!")
    end
    return 0, 0
end

function vec.Distance(v1,v2)
    if type(v1) == "table" and type(v2) == "table" then
        if type(v1.x) == "number" and type(v1.y) and type(v2.x) == "number" and type(v2.y) then
            return math.sqrt( (v1.x - v2.x)^2 + (v1.y - v2.y)^2 )
        else
            dbg.error("one of x,y isn't a number!")
        end
    else
        dbg.error("one of v1,v2 isn't a table!")
    end
    return 0
end

return vec;
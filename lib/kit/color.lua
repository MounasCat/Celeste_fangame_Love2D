local dbg = require("lib.kit.debug") or {print = function() end,warn = function() end,error = function() end}

local col = {}

local CONSTENT_RGB = 0.00392157
col.CONSTENT_RGB = CONSTENT_RGB

col.NormalLines = {}

function Numlerp (St,En,t)
    t = math.max(0, math.min(1, t))
    return St * (1 - t) + En * t
end

local function CheckRGBformat(c)
    local pass = true
    if type(c) == "table" then
        if type(c.R) ~= nil then
            if type(c.R) == "number" then
                c.R = math.max(0,math.min(c.R,255))
            else
                pass = false
            end
        else
            pass = false
        end
        if type(c.G) ~= nil then
            if type(c.G) == "number" then
                c.G = math.max(0,math.min(c.G,255))
            else
                pass = false
            end
        else
            pass = false
        end
        if type(c.B) ~= nil then
            if type(c.B) == "number" then
                c.B = math.max(0,math.min(c.B,255))
            else
                pass = false
            end
        else
            pass = false
        end

    else
        pass = false
    end
    return pass
end

function col.toRatio(c,alpha)
    local r_R,r_G,r_B = 0,0,0
    if type(c) == "table" then
        if c.R ~= nil then
            if type(c.R) == "number" then
                r_R = math.max(0,math.min(c.R*CONSTENT_RGB,1))
            else
                dbg.error("c.R isn't a number!")
            end
        end
        if c.G ~= nil then
            if type(c.G) == "number" then
                r_G = math.max(0,math.min(c.G*CONSTENT_RGB,1))
            else
                dbg.error("c.G isn't a number!")
            end
        end
        if c.B ~= nil then
            if type(c.B) == "number" then
                r_B = math.max(0,math.min(c.B*CONSTENT_RGB,1))
            else
                dbg.error("c.B isn't a number!")
            end
        end
    else
        dbg.error("c isn't a table!")
    end
    return r_R,r_G,r_B,alpha or 1
end

function col.toRGB(oR,oG,oB)
    local r_R,r_G,r_B = 0,0,0
    if oR ~= nil then
        if type(oR) == "number" then
            r_R = math.max(0,math.min(oR*255,255))
        else
            dbg.error("R isn't a number!")
        end
    end
    if oG ~= nil then
        if type(oG) == "number" then
            r_G = math.max(0,math.min(oG*255,255))
        else
            dbg.error("G isn't a number!")
        end
    end
    if oB ~= nil then
        if type(oB) == "number" then
            r_B = math.max(0,math.min(oB*255,255))
        else
            dbg.error("B isn't a number!")
        end
    end
    return r_R,r_G,r_B
end

function col.loveSetColorRGB (c,alpha)
    local r_R,r_G,r_B = 0,0,0

    if type(c) == "table" then
        if c.R ~= nil then
            if type(c.R) == "number" then
                r_R = c.R
            else
                dbg.error("c.R isn't a number!")
            end
        end
        if c.G ~= nil then
            if type(c.G) == "number" then
                 r_G = c.G
            else
                dbg.error("c.G isn't a number!")
            end
        end
        if c.B ~= nil then
            if type(c.B) == "number" then
                 r_B = c.B
            else
                dbg.error("c.B isn't a number!")
            end
        end
    else
        dbg.error("c isn't a table!")
    end
    
    love.graphics.setColor(r_R/255,r_G/255,r_B/255,alpha or 1)
end

function col.Lerp(c1,c2,t,mode)--default RGB,
    local r_R,r_G,r_B = 0,0,0
    local _t = 0.5
    if t ~= nil then
        if type(t) == "number" then
            _t = math.max(0, math.min(1, t or 0.5))
        else
            dbg.error("f isn't a number! or over limit!")
        end
    end
    
    if CheckRGBformat(c1) and CheckRGBformat(c2) then
        r_R = Numlerp(c1.R,c2.R,_t)
        r_G = Numlerp(c1.G,c2.G,_t)
        r_B = Numlerp(c1.B,c2.B,_t)
    else
        dbg.error("c1's or c2's format is invalid!")
    end

    return r_R,r_G,r_B
end

function col.NormalLinesUpdater(dt)
    for _ = #col.NormalLines, 1, -1 do
        local v = col.NormalLines[_]

        --handle modes
        if v.Mode == "Lerp" then
            v.NowColor.R,v.NowColor.G,v.NowColor.B = col.Lerp(v.SetColor,v.TargetColor,v.Timer/v.setTime)
        elseif v.Mode == "" then
        end

        --IsRepeat?
        if v.Repeat then
            if type(v.Repeatbool) == "nil" then
                v.Repeatbool = true
            end
        end

        if not v.Repeat then
            if v.Timer + dt < v.setTime then
                v.Timer = v.Timer + dt
            else
                table.remove(col.NormalLines,_)
            end
        else
            if v.Repeatbool then
                if v.Timer + dt < v.setTime then
                    v.Timer = v.Timer + dt
                else
                    v.Timer = v.setTime
                    v.Repeatbool = false
                end
            else
                if v.Timer - dt > 0 then
                    v.Timer = v.Timer - dt
                else
                    v.Timer = 0
                    v.Repeatbool = true
                end
            end
        end

    end
end
function col.AddNormalLines(settings)
    local L = {}
    L = {
        setTime = 1,
        Timer = 0,

        Mode = "Lerp",
        Repeat = false, --attention:if true,you must detele it by youself!!!
        SetColor = {R = 0,G = 0, B = 0},
        TargetColor = {R = 0,G = 0, B = 0},
        NowColor = {R = 0,G = 0, B = 0}
    }
    if settings.SetTime then
        L.setTime = settings.SetTime
    end
    if settings.Mode then
        L.Mode = settings.Mode
    end
    if settings.Repeat then
        L.Repeat = settings.Repeat
    end
    if settings.SetColor then
        L.SetColor.R,L.SetColor.G,L.SetColor.B = settings.SetColor.R,settings.SetColor.G,settings.SetColor.B
    end
    if settings.TargetColor then
        L.TargetColor.R,L.TargetColor.G,L.TargetColor.B = settings.TargetColor.R,settings.TargetColor.G,settings.TargetColor.B
    end
    L.NowColor.R,L.NowColor.G,L.NowColor.B = L.SetColor.R,L.SetColor.G,L.SetColor.B
    table.insert(col.NormalLines,L)

    return L
end

return col;
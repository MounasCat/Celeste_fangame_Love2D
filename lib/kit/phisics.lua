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

--//数学
function numLerp(St,En,t)
    return St * (1 - t) + En * t
end
function smoothStep(x)
    -- 保证输入在 [0, 1]
    x = math.max(0, math.min(1, x))
    return x * x * (3 - 2 * x)
end
function bounceStep(x)
    x = math.max(0, math.min(1, x))
    return math.sin((x^2)*(math.pi*2))
end

local sound = {
    refresh = {
        refresh_return_01 = love.audio.newSource("audio/mob/player/Interaction/refresh_return_01.wav","static"),
        refresh_return_02 = love.audio.newSource("audio/mob/player/Interaction/refresh_return_02.wav","static"),
        refresh_return_03 = love.audio.newSource("audio/mob/player/Interaction/refresh_return_03.wav","static"),
    },
}
for i = 1,3 do
    sound.refresh["refresh_return_0" .. i]:setVolume(0.6)
end

--//声音播放机
local function soundPlay(s,p)
    p = p or 0
    s = s or sound.defalut[math.random(1,#sound.defalut)]
    s:stop(); s:seek(p); s:play()
end

local phi = {}

phi.groundFriction = 1800
phi.airFriction = 650
phi.moveAirFriction = 260
phi.slideDown = 114
--//以下内容由render.lua的loadMap()加载进来
phi.collisionGrid = {
    tile = 8,
    point = {x = 0, y = 0},
    grid = {},
    visible = false,--渲染网格图
}--以对象左上角顶点坐标为基础

phi.dangersID = {
    spikeU,spikeL,spikeD,spikeR = 0,0,0,0
}
phi.dangerGrid = {--tile与point使用collisionGrid的数据
    grid = {},
    visible = false,--渲染大小图
}

phi.objects = {
    key = {},
    normal = {},
    visible = false,--渲染体积图，而非对象实际图像
}--以对象左上角顶点坐标为基础,以collisionGrid里的point为标准

phi.debugVec2_1 = {x = 0,y = 0}
phi.debugVec2_2 = {x = 0,y = 0}
phi.debugNum = 0

function phi.aabbOverlap(x1, y1, x2, y2, rx1, ry1, rx2, ry2)
    local minAX, maxAX = math.min(x1, x2), math.max(x1, x2)
    local minAY, maxAY = math.min(y1, y2), math.max(y1, y2)
    local minBX, maxBX = math.min(rx1, rx2), math.max(rx1, rx2)
    local minBY, maxBY = math.min(ry1, ry2), math.max(ry1, ry2)

    return minAX < maxBX and maxAX > minBX and minAY < maxBY and maxAY > minBY
end
 --1_:上，2_:左,3_:下,4_:右
local board_mapping = {
    [11] = 1,[12] = 1,
    [21] = 2,[22] = 2,
    [31] = 3,[32] = 3,
    [41] = 4,[42] = 4
}
function phi.BoardDirection(num,target)--不是目标就返回false
    if num then
        return board_mapping[num] == target
    end
    return false
end


--[[
local _k3,_k4 = {x = 0,y = 0},{x = 0,y = 0}
function phi.checkpointDetector(p1x,p1y,p2x,p2y)--从phi.objects.key检测 (已弃用:优化问题)
    for _,v in pairs(phi.objects.key) do
        if v.type == "checkpoint" then

            _k3.x,_k3.y = phi.collisionGrid.point.x + v.x, phi.collisionGrid.point.y - v.y
            _k4.x,_k4.y = _k3.x + v.width, _k3.y - v.height

            if p1x < _k4.x and p2x > _k3.x and p1y > _k4.y and p2y < _k3.y then
                return true,v--checkpoint
            end
        end
    end
    return false
end
--]]

local _k5,_k6 = {x = 0,y = 0},{x = 0,y = 0}
function phi.eventDetector(p1x,p1y,p2x,p2y)--从phi.objects.key检测
    for _,v in pairs(phi.objects.key) do
        if v.type == "setDash0" then
            _k5.x,_k5.y = phi.collisionGrid.point.x + v.x, phi.collisionGrid.point.y - v.y
            _k6.x,_k6.y = _k5.x + v.width, _k5.y - v.height

            if p1x < _k6.x and p2x > _k5.x and p1y > _k6.y and p2y < _k5.y then
                return true,v.type,nil
            end
        elseif v.type == "setDash1" then
            _k5.x,_k5.y = phi.collisionGrid.point.x + v.x, phi.collisionGrid.point.y - v.y
            _k6.x,_k6.y = _k5.x + v.width, _k5.y - v.height

            if p1x < _k6.x and p2x > _k5.x and p1y > _k6.y and p2y < _k5.y then
                return true,v.type,nil
            end
        elseif v.type == "setDash2" then
            _k5.x,_k5.y = phi.collisionGrid.point.x + v.x, phi.collisionGrid.point.y - v.y
            _k6.x,_k6.y = _k5.x + v.width, _k5.y - v.height

            if p1x < _k6.x and p2x > _k5.x and p1y > _k6.y and p2y < _k5.y then
                return true,v.type,nil
            end
        elseif v.type == "changeMap" then--//R3返回的是这个obj的名字
            _k5.x,_k5.y = phi.collisionGrid.point.x + v.x, phi.collisionGrid.point.y - v.y
            _k6.x,_k6.y = _k5.x + v.width, _k5.y - v.height

            if p1x < _k6.x and p2x > _k5.x and p1y > _k6.y and p2y < _k5.y then
                return true,v.type,v.name
            end
        elseif v.type == "changelevel" then--//R3返回的是这个obj的名字
            _k5.x,_k5.y = phi.collisionGrid.point.x + v.x, phi.collisionGrid.point.y - v.y
            _k6.x,_k6.y = _k5.x + v.width, _k5.y - v.height

            if p1x < _k6.x and p2x > _k5.x and p1y > _k6.y and p2y < _k5.y then
                return true,v.type,v.name
            end
        elseif v.type == "refresh" then--//R3返回的是这个obj
            _k5.x,_k5.y = phi.collisionGrid.point.x + v.x, phi.collisionGrid.point.y - v.y
            _k6.x,_k6.y = _k5.x + v.width, _k5.y - v.height

            if p1x < _k6.x and p2x > _k5.x and p1y > _k6.y and p2y < _k5.y then
                return true,v.type,v
            end
        elseif v.type == "checkpoint" then--//R3返回的是这个obj
            _k5.x,_k5.y = phi.collisionGrid.point.x + v.x, phi.collisionGrid.point.y - v.y
            _k6.x,_k6.y = _k5.x + v.width, _k5.y - v.height

            if p1x < _k6.x and p2x > _k5.x and p1y > _k6.y and p2y < _k5.y then
                return true,v.type,v
            end
        end
    end
    return false
end
local _k1,_k2 = {x = 0,y = 0},{x = 0,y = 0}
function phi.dangerDetector(p1x,p1y,p2x,p2y,speed)
     for y,_ in pairs(phi.dangerGrid.grid) do
        for x,N in pairs(phi.dangerGrid.grid[y]) do
            if N ~= 0 then--是否为空
                if N == 1 and speed.y <= 0 then--上尖刺
                    _k1.x = phi.collisionGrid.point.x + (x-1)*phi.collisionGrid.tile--左上角
                    _k1.y = phi.collisionGrid.point.y - (y-1)*phi.collisionGrid.tile - 5--左上角
                    _k2.x =  _k1.x + phi.collisionGrid.tile--右下角
                    _k2.y =  _k1.y - 3--像素大小,右下角
                    if p1x < _k2.x and p2x > _k1.x and p1y > _k2.y and p2y < _k1.y then
                        return true,N--die
                    end
                elseif N == 2 and speed.x >= 0 then--左尖刺
                    _k1.x = phi.collisionGrid.point.x + (x-1)*phi.collisionGrid.tile + 5--左上角
                    _k1.y = phi.collisionGrid.point.y - (y-1)*phi.collisionGrid.tile--左上角
                    _k2.x =  _k1.x + 3--像素大小,右下角
                    _k2.y =  _k1.y - phi.collisionGrid.tile--右下角
                    if p1x < _k2.x and p2x > _k1.x and p1y > _k2.y and p2y < _k1.y then
                        return true,N--die
                    end
                elseif N == 3 and speed.y >= 0 then--下尖刺
                    _k1.x = phi.collisionGrid.point.x + (x-1)*phi.collisionGrid.tile--左上角
                    _k1.y = phi.collisionGrid.point.y - (y-1)*phi.collisionGrid.tile--左上角
                    _k2.x =  _k1.x + phi.collisionGrid.tile--右下角
                    _k2.y =  _k1.y - 3--像素大小,右下角
                    if p1x < _k2.x and p2x > _k1.x and p1y > _k2.y and p2y < _k1.y then
                        return true,N--die
                    end
                elseif N == 4 and speed.x <= 0 then--右尖刺
                    _k1.x = phi.collisionGrid.point.x + (x-1)*phi.collisionGrid.tile--左上角
                    _k1.y = phi.collisionGrid.point.y - (y-1)*phi.collisionGrid.tile--左上角
                    _k2.x =  _k1.x + 3--右下角
                    _k2.y =  _k1.y - phi.collisionGrid.tile--像素大小,右下角
                    if p1x < _k2.x and p2x > _k1.x and p1y > _k2.y and p2y < _k1.y then
                        return true,N--die
                    end
                end


            end
        end
    end
    return false
end
local _k7,_k8 = {x = 0,y = 0},{x = 0,y = 0}
function phi.squeezeDetector(p1x,p1y,p2x,p2y)
    for y,xt in pairs(phi.collisionGrid.grid) do
        for x,YES in pairs(xt) do
            if YES then
                _k7.x = phi.collisionGrid.point.x + (x-1)*phi.collisionGrid.tile
                _k7.y = phi.collisionGrid.point.y - (y-1)*phi.collisionGrid.tile
                _k8.x = _k7.x + phi.collisionGrid.tile
                _k8.y = _k7.y - phi.collisionGrid.tile

                if p1x < _k8.x and p2x > _k7.x and p1y > _k8.y and p2y < _k7.y then
                    return true--die
                end
            end
        end
    end
    for _,v in pairs(phi.objects.normal) do
        if string.sub(v.type,1,6) == "mover_" then
            if not v.properties.vanished and not v.properties.specific then--这里specific是为了单向板做处理

                _k7.x = phi.collisionGrid.point.x + v.x
                _k7.y = phi.collisionGrid.point.y - v.y
                _k8.x = _k7.x + v.width
                _k8.y = _k7.y - v.height

                if p1x < _k8.x and p2x > _k7.x and p1y > _k8.y and p2y < _k7.y then
                    return true,v--die
                end
            end
        end
    end
    return false,nil
end
local _k9,_k10 = {x = 0,y = 0},{x = 0,y = 0}
function phi.triggerDetector(p1x,p1y,p2x,p2y)
    for _,v in pairs(phi.objects.normal) do
        if string.sub(v.type,1,8) == "trigger_" then
            if v.properties.objIndex then

                _k9.x = phi.collisionGrid.point.x + v.x
                _k9.y = phi.collisionGrid.point.y - v.y
                _k10.x = _k9.x + v.width
                _k10.y = _k9.y - v.height

                if p1x < _k10.x and p2x > _k9.x and p1y > _k10.y and p2y < _k9.y then
                    return v--trigger
                end
            end
        end
    end
    return nil
end
--[[
local _k11,_k12 = {x = 0,y = 0},{x = 0,y = 0}
function phi.fixMoveDetector(p1x,p1y,p2x,p2y,p3x,p3y,p4x,p4y)--(已弃用:优化问题)
    local p1,p2,p3,p4
    --//先从地图开始
    for y,xt in pairs(phi.collisionGrid.grid) do
        for x,YES in pairs(xt) do
            if YES then
                _k11.x = phi.collisionGrid.point.x + (x-1)*phi.collisionGrid.tile
                _k11.y = phi.collisionGrid.point.y - (y-1)*phi.collisionGrid.tile
                _k12.x = _k11.x + phi.collisionGrid.tile
                _k12.y = _k11.y - phi.collisionGrid.tile

                if p1x > _k11.x and p1x < _k12.x and p1y < _k11.y and p1y > _k12.y then
                    p1 = true
                end
                if p2x > _k11.x and p2x < _k12.x and p2y < _k11.y and p2y > _k12.y then
                    p2 = true
                end
                if p3x > _k11.x and p3x < _k12.x and p3y < _k11.y and p3y > _k12.y then
                    p3 = true
                end
                if p4x > _k11.x and p4x < _k12.x and p4y < _k11.y and p4y > _k12.y then
                    p4 = true
                end
               
            end
        end
    end
    --//再从机关开始
    for _,v in pairs(phi.objects.normal) do
        if string.sub(v.type,1,6) == "mover_" then
            if not v.properties.vanished then
                _k11.x = phi.collisionGrid.point.x + v.x
                _k11.y = phi.collisionGrid.point.y - v.y
                _k12.x = _k11.x + v.width
                _k12.y = _k11.y - v.height

                if p1x > _k11.x and p1x < _k12.x and p1y < _k11.y and p1y > _k12.y then
                    p1 = true
                end
                if p2x > _k11.x and p2x < _k12.x and p2y < _k11.y and p2y > _k12.y then
                    p2 = true
                end
                if p3x > _k11.x and p3x < _k12.x and p3y < _k11.y and p3y > _k12.y then
                    p3 = true
                end
                if p4x > _k11.x and p4x < _k12.x and p4y < _k11.y and p4y > _k12.y then
                    p4 = true
                end
                
            end
        end
    end
    return p1,p2,p3,p4
end
]]

--from botton and top to detect
--true: top
--false: botton
--nil: haven't touch
local _p5,_p6 = {x = 0,y =0},{x = 0, y = 0}
function phi.fromBAT(cx,tpy,bpy,halfW,fromObj,speedY)
    speedY = speedY or 0
    if not fromObj then
        for y,xt in pairs(phi.collisionGrid.grid) do
            for x,YES in pairs(xt) do
                if YES then

                    _p5.x = phi.collisionGrid.point.x + (x-1)*phi.collisionGrid.tile
                    _p5.y = phi.collisionGrid.point.y - (y-1)*phi.collisionGrid.tile
                    _p6.x = _p5.x + phi.collisionGrid.tile
                    _p6.y = _p5.y - phi.collisionGrid.tile


                    if cx - halfW < _p6.x and cx + halfW > _p5.x and tpy > _p6.y and tpy < _p5.y then--top
                        return true,_p5.y,_p6.y
                    elseif cx - halfW < _p6.x and cx + halfW > _p5.x and bpy > _p6.y and bpy < _p5.y then--botton
                        return false,_p5.y,_p6.y
                    end
                end
            end
        end
    else
        for _,v in pairs(phi.objects.normal) do
            if string.sub(v.type,1,6) == "mover_" then
                if not v.properties.vanished then

                    _p5.x = phi.collisionGrid.point.x + v.x
                    _p5.y = phi.collisionGrid.point.y - v.y
                    _p6.x = _p5.x + v.width
                    _p6.y = _p5.y - v.height

                    if cx - halfW < _p6.x and cx + halfW > _p5.x and tpy > _p6.y and tpy < _p5.y then--top
                        if v.properties.specific then--是否为单向板
                            if speedY then
                                if speedY > 0 and phi.BoardDirection(v.properties.specific,3) then
                                    return true,v,_p5.y,_p6.y--返回v为了推动玩家
                                end
                            end
                            return nil,0,0
                        else
                            return true,v,_p5.y,_p6.y--返回v为了推动玩家
                        end
                    elseif cx - halfW < _p6.x and cx + halfW > _p5.x and bpy > _p6.y and bpy < _p5.y then--botton
                        if v.properties.specific then--是否为单向板
                            if speedY then
                                if speedY <= 0 and phi.BoardDirection(v.properties.specific,1) and bpy >= _p6.y + 6 then--误差宽容
                                    return false,v,_p5.y,_p6.y--返回v为了推动玩家
                                end
                            end
                            return nil,0,0
                        else
                            return false,v,_p5.y,_p6.y--返回v为了锁定锚
                        end
                    end
                end
            end
        end
    end
    return nil,0,0
end
local _p9,_p10 = {x = 0,y =0},{x = 0, y = 0}
function phi.fromTop(cx,tpy,halfW,fromObj,fill)
    if not fromObj then
        for y,xt in pairs(phi.collisionGrid.grid) do
            for x,YES in pairs(xt) do
                if YES then
                    _p9.x = phi.collisionGrid.point.x + (x-1)*phi.collisionGrid.tile
                    _p9.y = phi.collisionGrid.point.y - (y-1)*phi.collisionGrid.tile
                    _p10.x = _p9.x + phi.collisionGrid.tile
                    _p10.y = _p9.y - phi.collisionGrid.tile

                    if not fill then
                        if cx - halfW < _p10.x and cx + halfW > _p9.x and tpy > _p10.y and tpy < _p9.y then--A line
                            return true
                        end
                    else
                        if cx - halfW < _p10.x and cx + halfW > _p9.x and tpy > _p10.y and tpy - 4 < _p9.y then--A rectangle
                            return true
                        end
                    end
                end
            end
        end
    else
        for _,v in pairs(phi.objects.normal) do
            if string.sub(v.type,1,6) == "mover_" then
                if not v.properties.vanished then

                    _p9.x = phi.collisionGrid.point.x + v.x
                    _p9.y = phi.collisionGrid.point.y - v.y
                    _p10.x = _p9.x + v.width
                    _p10.y = _p9.y - v.height

                    if not fill then
                        if cx - halfW < _p10.x and cx + halfW > _p9.x and tpy > _p10.y and tpy < _p9.y then--A line
                            return true
                        end
                    else
                        if cx - halfW < _p10.x and cx + halfW > _p9.x and tpy > _p10.y and tpy - 4 < _p9.y then--A rectangle
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

--from left and right to detect
--true: left
--false: right
--nil: haven't touch
local _p7,_p8 = {x = 0,y =0},{x = 0, y = 0}
function phi.fromLAR(cy,lpx,rpx,halfH,fromObj,speedX)
    if not fromObj then
        for y,xt in pairs(phi.collisionGrid.grid) do
            for x,YES in pairs(xt) do
                if YES then

                    _p7.x = phi.collisionGrid.point.x + (x-1)*phi.collisionGrid.tile
                    _p7.y = phi.collisionGrid.point.y - (y-1)*phi.collisionGrid.tile
                    _p8.x = _p7.x + phi.collisionGrid.tile
                    _p8.y = _p7.y - phi.collisionGrid.tile


                    if lpx < _p8.x and lpx > _p7.x and cy + halfH >= _p8.y and cy - halfH <= _p7.y then--A line left
                        return true,_p8.x
                    elseif rpx < _p8.x and rpx > _p7.x and cy + halfH >= _p8.y and cy - halfH <= _p7.y then--A line right
                        return false,_p7.x
                    end
                end
            end
        end
    else
        for _,v in pairs(phi.objects.normal) do
            if string.sub(v.type,1,6) == "mover_" then
                if not v.properties.vanished then

                    _p7.x = phi.collisionGrid.point.x + v.x
                    _p7.y = phi.collisionGrid.point.y - v.y
                    _p8.x = _p7.x + v.width
                    _p8.y = _p7.y - v.height

                    if lpx < _p8.x and lpx > _p7.x and cy + halfH >= _p8.y and cy - halfH <= _p7.y then--A line left
                        if v.properties.specific then--是否为单向板
                            if speedX then
                                if speedX <= 0 and phi.BoardDirection(v.properties.specific,4) then
                                    return true,v
                                end
                            end
                            return nil,0
                        else
                            return true,v
                        end
                    elseif rpx < _p8.x and rpx > _p7.x and cy + halfH >= _p8.y and cy - halfH <= _p7.y then--A line right
                        if v.properties.specific then--是否为单向板
                            if speedX then
                                if speedX >= 0 and phi.BoardDirection(v.properties.specific,2) then
                                    return false,v
                                end
                            end
                            return nil,0
                        else
                            return false,v
                        end
                    end
                end
            end
        end
    end
    return nil,0
end
local _p11,_p12 = {x = 0,y =0},{x = 0, y = 0}
function phi.fromLeft(cy,lpx,halfH,onTop,fromObj)
    if not fromObj then
        for y,xt in pairs(phi.collisionGrid.grid) do
            for x,YES in pairs(xt) do
                if YES then
                    _p11.x = phi.collisionGrid.point.x + (x-1)*phi.collisionGrid.tile
                    _p11.y = phi.collisionGrid.point.y - (y-1)*phi.collisionGrid.tile
                    _p12.x = _p11.x + phi.collisionGrid.tile
                    _p12.y = _p11.y - phi.collisionGrid.tile

                    if not onTop then
                        if lpx < _p12.x and lpx > _p11.x and cy + halfH >= _p12.y and cy - halfH <= _p11.y then--A line
                            return true
                        end
                    else
                        if lpx < _p12.x and lpx > _p11.x and cy + halfH >= _p12.y and cy + halfH/2 <= _p11.y then--A line
                            return true
                        end
                    end
                end
            end
        end
    else
        for _,v in pairs(phi.objects.normal) do
            if string.sub(v.type,1,6) == "mover_" then
                if not v.properties.vanished then
                    _p11.x = phi.collisionGrid.point.x + v.x
                    _p11.y = phi.collisionGrid.point.y - v.y
                    _p12.x = _p11.x + v.width
                    _p12.y = _p11.y - v.height

                    if not onTop then
                        if lpx < _p12.x and lpx > _p11.x and cy + halfH >= _p12.y and cy - halfH <= _p11.y then--A line
                            if v.properties.specific then--是否为单向板
                                if phi.BoardDirection(v.properties.specific,4) then
                                    if not v.properties.canClimb then
                                        return true,true,v,_p12.x--不要问为什么要返回第四个值，问就是出现奇怪的bug(第三个table是锁定锚)
                                    else
                                        return true,false,v,_p12.x--不要问为什么要返回第四个值，问就是出现奇怪的bug(第三个table是锁定锚)
                                    end
                                end
                                return false,false,nil
                            else--非单向板
                                if not v.properties.canClimb then
                                    return true,true,v,_p12.x--不要问为什么要返回第四个值，问就是出现奇怪的bug(第三个table是锁定锚)
                                else
                                    return true,false,v,_p12.x--不要问为什么要返回第四个值，问就是出现奇怪的bug(第三个table是锁定锚)
                                end
                            end
                        end
                    else
                        if lpx < _p12.x and lpx > _p11.x and cy + halfH >= _p12.y and cy + halfH/2 <= _p11.y then--A line
                            if v.properties.specific then--是否为单向板
                                if phi.BoardDirection(v.properties.specific,4) then
                                    if not v.properties.canClimb then
                                        return true,true,v,_p12.x--不要问为什么要返回第四个值，问就是出现奇怪的bug(第三个table是锁定锚)
                                    else
                                        return true,false,v,_p12.x--不要问为什么要返回第四个值，问就是出现奇怪的bug(第三个table是锁定锚)
                                    end
                                end
                                return false,false,nil
                            else--非单向板
                                if not v.properties.canClimb then
                                    return true,true,v,_p12.x--不要问为什么要返回第四个值，问就是出现奇怪的bug(第三个table是锁定锚)
                                else
                                    return true,false,v,_p12.x--不要问为什么要返回第四个值，问就是出现奇怪的bug(第三个table是锁定锚)
                                end
                            end

                        end
                    end
                end
            end
        end
    end
    return false,false,nil
end
local _p13,_p14 = {x = 0,y =0},{x = 0, y = 0}
function phi.fromRight(cy,lpx,halfH,onTop,fromObj)
    if not fromObj then
        for y,xt in pairs(phi.collisionGrid.grid) do
            for x,YES in pairs(xt) do
                if YES then
                    _p13.x = phi.collisionGrid.point.x + (x-1)*phi.collisionGrid.tile
                    _p13.y = phi.collisionGrid.point.y - (y-1)*phi.collisionGrid.tile
                    _p14.x = _p13.x + phi.collisionGrid.tile
                    _p14.y = _p13.y - phi.collisionGrid.tile

                    if not onTop then
                        if lpx < _p14.x and lpx > _p13.x and cy + halfH >= _p14.y and cy - halfH <= _p13.y then--A line
                            return true
                        end
                    else
                        if lpx < _p14.x and lpx > _p13.x and cy + halfH >= _p14.y and cy + halfH/2 <= _p13.y then--A line
                            return true
                        end
                    end
                end
            end
        end
    else
        for _,v in pairs(phi.objects.normal) do
            if string.sub(v.type,1,6) == "mover_" then
                if not v.properties.vanished then
                    _p13.x = phi.collisionGrid.point.x + v.x
                    _p13.y = phi.collisionGrid.point.y - v.y
                    _p14.x = _p13.x + v.width
                    _p14.y = _p13.y - v.height


                    if not onTop then
                        if lpx < _p14.x and lpx > _p13.x and cy + halfH >= _p14.y and cy - halfH <= _p13.y then--A line
                            if v.properties.specific then--是否为单向板
                                if phi.BoardDirection(v.properties.specific,2) then
                                    if not v.properties.canClimb then
                                        return true,true,v,_p13.x--不要问为什么要返回第四个值，问就是出现奇怪的bug
                                    else
                                        return true,false,v,_p13.x--不要问为什么要返回第四个值，问就是出现奇怪的bug
                                    end
                                end
                                return false,false,nil
                            else--非单向板
                                if not v.properties.canClimb then
                                    return true,true,v,_p13.x--不要问为什么要返回第四个值，问就是出现奇怪的bug
                                else
                                    return true,false,v,_p13.x--不要问为什么要返回第四个值，问就是出现奇怪的bug
                                end
                            end
                        end
                    else
                        if lpx < _p14.x and lpx > _p13.x and cy + halfH >= _p14.y and cy + halfH/2 <= _p13.y then--A line
                            if v.properties.specific then--是否为单向板
                                if phi.BoardDirection(v.properties.specific,2) then
                                    if not v.properties.canClimb then
                                        return true,true,v,_p13.x--不要问为什么要返回第四个值，问就是出现奇怪的bug
                                    else
                                        return true,false,v,_p13.x--不要问为什么要返回第四个值，问就是出现奇怪的bug
                                    end
                                end
                                return false,false,nil
                            else--非单向板
                                if not v.properties.canClimb then
                                    return true,true,v,_p13.x--不要问为什么要返回第四个值，问就是出现奇怪的bug
                                else
                                    return true,false,v,_p13.x--不要问为什么要返回第四个值，问就是出现奇怪的bug
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return false,false,nil
end

local _p15,_p16 = {x = 0,y =0},{x = 0, y = 0}
local function objResetDetector(p1x,p1y,p2x,p2y,obj)--检测机关是否被玩家挡住
    _p15.x = phi.collisionGrid.point.x + obj.properties.ox
    _p15.y = phi.collisionGrid.point.y - obj.properties.oy
    _p16.x = _p15.x + obj.width
    _p16.y = _p15.y - obj.height

    if p1x < _p16.x and p2x > _p15.x and p1y > _p16.y and p2y < _p15.y then
        return true
    end
    return nil
end

function phi.objectsReset()--重设Obj
    for _,v in pairs(phi.objects.normal) do
        if string.sub(v.type,1,6) == "mover_" then
            --//For mover_
            v.properties.getTimer = 0
            v.properties.waitTimer = 0
            v.properties.ING = false
            v.properties.direction.x,v.properties.direction.y = 0,0
            v.properties.origin = true
            v.x,v.y = v.properties.ox,v.properties.oy
            v.properties.vanished = false
            v.properties.reSetTime = 0
            v.lastPosition.x,v.lastPosition.y = 0,0
        elseif string.sub(v.type,1,6) == "spring" then
            --//For spring
            if v.properties.timer then v.properties.timer = 0 end
        end
    end
    for _,v in pairs(phi.objects.key) do
        if string.sub(v.type,1,7) == "refresh" then
            v.properties.vanished = false
            v.properties.timer = 0
        end
    end
end
local OBJ_PG
function phi.objectsUpdater(dt,plyPos,plySiz)--用于更新obj(通过player)
    --//key类
    for _,v in pairs(phi.objects.key) do
        if string.sub(v.type,1,7) == "refresh" then
            if v.properties.vanished then
                if v.properties.timer - dt <= 0 then
                    v.properties.timer = 0
                    v.properties.vanished = false
                    soundPlay(sound.refresh["refresh_return_0" .. math.random(1,3)])
                else
                    v.properties.timer = v.properties.timer - dt
                end
            else
                v.y = v.properties.oy + math.floor(math.sin(love.timer:getTime()*4)*2)
            end
        end
    end
    --//normal类
    for _,v in pairs(phi.objects.normal) do
        if string.sub(v.type,1,6) == "mover_"then
            v.lastPosition.x = phi.collisionGrid.point.x + v.x
            v.lastPosition.y = phi.collisionGrid.point.y - v.y
            if v.properties["repeat"] then--来回移动机关设置--origin默认true
                --//计时器更新
                if v.properties.getTimer == 0 then
                    if v.properties.waitTimer - dt <= 0 then
                        v.properties.waitTimer = 0
                        v.properties.origin = not v.properties.origin
                        v.properties.getTimer = v.properties.getTime/100
                    else
                        v.properties.waitTimer = v.properties.waitTimer - dt
                    end
                end
                if v.properties.waitTimer == 0 then
                    if v.properties.getTimer - dt <= 0 then
                        v.properties.getTimer = 0--总会出现0
                        v.properties.waitTimer = v.properties.wait/100
                    else
                        v.properties.getTimer = v.properties.getTimer - dt
                    end
                end
                OBJ_PG = v.properties.getTimer*100/v.properties.getTime

                if v.properties.origin == false then--去目的地
                    v.x = numLerp(v.properties.ox,v.properties.ox + v.properties.moveX,smoothStep(1 - OBJ_PG))
                    v.y = numLerp(v.properties.oy,v.properties.oy - v.properties.moveY,smoothStep(1 - OBJ_PG))
                else--回到起点
                    v.x = numLerp(v.properties.ox,v.properties.ox + v.properties.moveX,smoothStep(OBJ_PG))
                    v.y = numLerp(v.properties.oy,v.properties.oy - v.properties.moveY,smoothStep(OBJ_PG))
                end


            elseif v.properties.bounce then--回弹机关设置--已在触发时自动设置时间--origin默认true
                --//计时器
                if v.properties.ING then
                    if v.properties.getTimer - dt < 0 then
                        v.properties.ING = false
                        v.properties.getTimer = 0
                        if v.properties["break"] then
                            v.properties.vanished = true
                            if v.properties.reStar then
                                v.properties.waitTimer = v.properties.reTime/100
                            end
                        end
                    else
                        v.properties.getTimer = v.properties.getTimer - dt
                    end
                end
                --恢复计时器(Break and reStar == true)
                if v.properties.vanished == true and v.properties.reStar then
                    if v.properties.waitTimer - dt < 0 then
                        v.properties.waitTimer = 0
                        if not objResetDetector(
                            plyPos.x - plySiz.width/2,plyPos.y + plySiz.height/2,
                            plyPos.x + plySiz.width/2,plyPos.y - plySiz.height/2,
                            v
                        ) then v.properties.vanished = false end
                    else
                        v.properties.waitTimer = v.properties.waitTimer -dt
                    end
                end
                OBJ_PG = v.properties.getTimer*100/v.properties.getTime

                --//移动逻辑
                v.x = v.properties.ox + v.properties.direction.x*bounceStep(OBJ_PG)
                v.y = v.properties.oy - v.properties.direction.y*bounceStep(OBJ_PG)

            else--普通移动机关设置--origin默认true--已在触发时自动设置时间(wait与getTime)
                --//计时器
                if v.properties.ING then
                    if v.properties.waitTimer - dt < 0 then
                        v.properties.waitTimer = 0
                        v.properties.origin = false
                        if v.properties.getTimer - dt < 0 then
                            v.properties.ING = false
                            v.properties.getTimer = 0
                            if v.properties["break"] then--破坏后返回
                                v.properties.vanished = true
                                if v.properties.reStar then
                                    v.properties.reSetTime = v.properties.reTime/100
                                end
                            elseif v.properties.reStar then--仅返回
                                v.properties.reSetTime = v.properties.reTime/100
                            end
                        else
                            v.properties.getTimer = v.properties.getTimer - dt
                        end
                    else
                        v.properties.waitTimer = v.properties.waitTimer - dt
                    end
                end
                --恢复计时器(Break and reStar == true)
                if v.properties.vanished == true and v.properties.reStar and v.properties["break"] then--破坏加返回
                    if v.properties.reSetTime - dt < 0 then
                        v.properties.reSetTime = 0
                        if not objResetDetector(
                            plyPos.x - plySiz.width/2,plyPos.y + plySiz.height/2,
                            plyPos.x + plySiz.width/2,plyPos.y - plySiz.height/2,
                            v
                        ) then v.properties.vanished = false; v.properties.origin = true;  end
                    else
                        v.properties.reSetTime = v.properties.reSetTime - dt
                    end
                elseif v.properties.vanished == false and v.properties.reStar and not v.properties.origin and v.properties.getTimer == 0 then--仅返回
                    if v.properties.reSetTime - dt <= 0 then
                        v.properties.reSetTime = 0
                        v.properties.origin = true
                    else
                        v.properties.reSetTime = v.properties.reSetTime - dt
                    end
                end
                if v.properties.reSetTime <= 0 then
                    OBJ_PG = 1 - v.properties.getTimer*100/v.properties.getTime
                else
                    OBJ_PG = v.properties.reSetTime*100/v.properties.reTime
                end

                --//移动逻辑
                if v.properties.waitTimer > 0 and v.properties.shake then
                    v.x = v.properties.ox + math.random(-10,10)/10
                    v.y = v.properties.oy + math.random(-10,10)/10
                elseif not v.properties.origin then
                    v.x = numLerp(v.properties.ox,v.properties.ox + v.properties.moveX,smoothStep(OBJ_PG))
                    v.y = numLerp(v.properties.oy,v.properties.oy - v.properties.moveY,smoothStep(OBJ_PG))
                elseif v.properties.reSetTime > 0 then
                    v.x = numLerp(v.properties.ox,v.properties.ox + v.properties.moveX,smoothStep(OBJ_PG))
                    v.y = numLerp(v.properties.oy,v.properties.oy - v.properties.moveY,smoothStep(OBJ_PG))
                else
                    v.x = v.properties.ox
                    v.y = v.properties.oy
                end

            end
        end
    end
end

return phi
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
local M_mat = require("lib.kit.math")
local M_vec = require("lib.kit.vector")

--//数学
function vecLerp(v1, v2, t)
    local _t = t or 0.5
    return v1.x * (1 - _t) + v2.x * _t, v1.y * (1 - _t) + v2.y * _t or 0, 0
end
function numLerp(St,En,t)
    return St * (1 - t) + En * t
end

local cam = {}
cam.__index = cam

cam.shaking = {
    size = 15,
    timer = 0,
}

cam.offset = M_vec.vec2(0,0)

--//摄像头晃动
function cam.shakingUpdater(dt)
    if cam.shaking.timer > 0 then
        cam.shaking.timer = cam.shaking.timer - dt
        cam.offset.x,cam.offset.y = M_mat.sideSp(8,cam.shaking.size)/10,M_mat.sideSp(8,cam.shaking.size)/10
    else
        cam.shaking.timer = 0
        cam.offset.x,cam.offset.y = 0, 0
    end
end

--//创建新的摄像头
function cam.newCamera(x, y, scale, rotation)
    local self = setmetatable({},cam)
    self.position = {x = x or 0, y = y or 0}
    self.showPosition = {x = self.position.x, y = self.position.y}
    self.scale = scale or 1
    self.showScale = self.scale
    self.rotation = rotation or 0
    self.showRotation = self.rotation
    self.mode = "follow"
    self.scroll = true
    self.scrollRatio = 0.2--相对视角范围大小的比例
    --//其他信息
    self.cornerP1 = M_vec.vec2(0,0)--//当前视角范围的左上角点相对的世界坐标
    self.cornerP2 = M_vec.vec2(0,0)--//当前视角范围的右上角点相对的世界坐标
    self.LimitW = 0--//当前游戏内渲染窗口相对于世界坐标的宽度
    self.LimitH = 0--//当前游戏内渲染窗口相对于世界坐标的高度
    --//限制视角范围
    self.edgeMode = true
    self.edgeP1 = M_vec.vec2(0,0)--左上角
    self.edgeP2 = M_vec.vec2(0,0)--右下角
    --[[
    attach -> just set sP = p
    follow -> use lerp to move the sP to p smoothly
    ]]
    self.obj = 0--if = 0,then have no obj to be attached by cam
    return self
end

--//更新一些信息
function cam:infoUpdater(WINDOW_INFO)--以实际坐标为准self.position
    self.LimitW,self.LimitH = WINDOW_INFO.InWidth/self.scale, WINDOW_INFO.InHeight/self.scale
    self.cornerP1.x,self.cornerP1.y = self.position.x - self.LimitW*0.5,self.position.y + self.LimitH*0.5
    self.cornerP2.x,self.cornerP2.y = self.position.x + self.LimitW*0.5,self.position.y - self.LimitH*0.5
end
--//范围跟随更新
function cam:scrollUpdater()
    if self.scroll and self.obj ~= 0 then
        --//X轴移动
        if (self.obj.x - self.position.x) > (self.LimitW/2)*self.scrollRatio then--右边界
            self.position.x = self.position.x + ((self.obj.x - self.position.x) - (self.LimitW/2)*self.scrollRatio)
        elseif (self.obj.x - self.position.x) < -(self.LimitW/2)*self.scrollRatio then--左边界
            self.position.x = self.position.x + ((self.obj.x - self.position.x) + (self.LimitW/2)*self.scrollRatio)
        end
        --//Y轴移动
        if (self.obj.y - self.position.y) > (self.LimitH/2)*self.scrollRatio then--上边界
            self.position.y = self.position.y + ((self.obj.y - self.position.y) - (self.LimitH/2)*self.scrollRatio)
        elseif (self.obj.y - self.position.y) < -(self.LimitH/2)*self.scrollRatio then--下边界
            self.position.y = self.position.y + ((self.obj.y - self.position.y) + (self.LimitH/2)*self.scrollRatio)
        end
    end
end
--//摄像头范围设置及更新
function cam:limitEdge(WINDOW_INFO)
    if self.edgeP1.x ~= 0 and self.edgeP1.y ~= 0 and self.edgeP2.x ~= 0 and self.edgeP2.y ~= 0 then
        --//检测X轴是否超界
        if self.position.x - self.edgeP1.x <= self.LimitW/2 then--左边界
            self.position.x = self.edgeP1.x + self.LimitW/2
        elseif self.edgeP2.x - self.position.x <= self.LimitW/2 then--右边界
            self.position.x = self.edgeP2.x - self.LimitW/2
        end
        if self.showPosition.x - self.edgeP1.x <= self.LimitW/2 then--左边界
            self.showPosition.x = self.edgeP1.x + self.LimitW/2
        elseif self.edgeP2.x - self.showPosition.x <= self.LimitW/2 then--右边界
            self.showPosition.x = self.edgeP2.x - self.LimitW/2
        end
        --//检测Y轴是否超界
        if self.edgeP1.y - self.position.y <= self.LimitH/2 then--上边界
            self.position.y = self.edgeP1.y - self.LimitH/2
        elseif self.position.y - self.edgeP2.y <= self.LimitH/2 then--下边界
            self.position.y = self.edgeP2.y + self.LimitH/2
        end
        if self.edgeP1.y - self.showPosition.y <= self.LimitH/2 then--上边界
            self.showPosition.y = self.edgeP1.y - self.LimitH/2
        elseif self.showPosition.y - self.edgeP2.y <= self.LimitH/2 then--下边界
            self.showPosition.y = self.edgeP2.y + self.LimitH/2
        end
    end
end
--//应用摄像头
function cam:attach(WINDOW_INFO)
    --//观测对象
    if self.obj ~= 0 then
        if self.obj.x and self.obj.y then
            if self.scroll then
                self:scrollUpdater()
            else
                self.position.x,self.position.y = self.obj.x,self.obj.y
            end
        else
            dbg.warn("camera's obj is invalid!")
            self.obj = 0
        end
    end

    --//限制视角
    if self.edgeMode then
        self:limitEdge(WINDOW_INFO)
    end

    --//移动模式
    if self.mode == "attach" then
        self.showPosition.x,self.showPosition.y = self.position.x, self.position.y
        self.showRotation = self.rotation
    elseif self.mode == "follow" then
        self.showPosition.x,self.showPosition.y = vecLerp(self.showPosition,self.position,0.1)
        self.showScale = numLerp(self.showScale,self.scale,0.1)
        self.showRotation = numLerp(self.showRotation,self.rotation,0.1)
    else
        self.showPosition.x,self.showPosition.y = self.position.x, self.position.y
        self.showScale = self.scale
        self.showRotation = self.rotation
    end

    love.graphics.push()

    love.graphics.translate(WINDOW_INFO.InWidth/2,WINDOW_INFO.InHeight/2)--先放到屏幕中心
    love.graphics.scale(self.showScale)--改变整个坐标系
    love.graphics.rotate(self.showRotation)--改变整个坐标系
    love.graphics.translate(
        -self.showPosition.x + cam.offset.x,
        self.showPosition.y + cam.offset.y
    )
    
end
--//解应用
function cam:detach()
    love.graphics.pop()
end
--//设置摄像头位置（世界坐标）
function cam:setPosition(x, y)
    self.position.x = x or 0
    self.position.y = y or 0
end
--//移动摄像头位置（相对目前坐标）
function cam:move(x, y)
    self.position.x = self.position.x + x or 0
    self.position.y = self.position.y + y or 0
end
--//设置缩放
function cam:setScale(s)
    self.scale = s or 1
end
--//设置缩放（有限）
function cam:setZoom(factor)
    self.scale = math.max(0.1,math.min(factor,10))
end
--//设置旋转
function cam:setRotation(angle)
    self.rotation = angle
end
--//设置锚定目标
function cam:setObject(obj)
    if type(obj) == "table" then
        self.obj = obj
        self.position.x,self.position.y = obj.x,obj.y
    else
        dbg.warn("addObject():the obj isn't a table!")
    end
end
--//解开锚定
function cam:freeMode()
    self.obj = 0
end
--设置跟随方式
function cam:setMode(name)
    if name == "attach" then
        self.mode = name
    elseif name == "follow" then
        self.mode = name
    end
end
--设置范围跟随
function cam:setScroll(bool)
    if bool == true then
        self.scroll = true
    elseif bool == false then
        self.scroll = false
    end
end
--设置有限范围(视角上)
function cam:setEdgeMode(bool)
    if bool == true then
        self.setEdgeMode = true
    elseif bool == false then
        self.setEdgeMode = false
    end
end

return cam
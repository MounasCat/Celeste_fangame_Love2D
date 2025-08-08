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

local M_vec = require("lib.kit.vector")
local M_col = require("lib.kit.color")
local M_win = require("lib.kit.window")

--//数学
function numLerp(St,En,t)
    return St * (1 - t) + En * t
end
function smoothStep(x)
    x = math.max(0, math.min(1, x))
    return 1 - math.pow(1 - x, 3)
end
function align8_down(n)
    return math.floor(n / 8) * 8
end

--//内置textrue
local mover_texture = {}
local mover_sheet = love.graphics.newImage("assets/Texture/mover.png")
mover_sheet:setFilter("nearest", "nearest")
local function mover_textureLoader ()
    local tileSize = 8

    local sheetWidth = mover_sheet:getWidth()
    local sheetHeight = mover_sheet:getHeight()

    --计算图集中tile的行列数
    local tilesX = sheetWidth / tileSize
    local tilesY = sheetHeight / tileSize

    --创建quads表
    for y = 0, tilesY - 1 do
        for x = 0, tilesX - 1 do
            local quad = love.graphics.newQuad(
                x * tileSize, y * tileSize,
                tileSize, tileSize,
                sheetWidth, sheetHeight
            )
            table.insert(mover_texture, quad)
        end
    end
end;mover_textureLoader()
local mover_valid = {
    [11] = true,[12] = true,[21] = true,[22] = true,
    [31] = true,[32] = true,[41] = true,[42] = true,
}--只是specific合法代号，并非quads里对应id

local key_texture = {
    cystal = {
        num = 1,
        setTime = 0.1,
        timer = 0,
        ["vanished"] = love.graphics.newImage("assets/Texture/DashCystal/vanished.png")
    }
}
for i = 1,5 do
    key_texture.cystal[i] = love.graphics.newImage("assets/Texture/DashCystal/F" .. i ..".png")
    key_texture.cystal[i]:setFilter("nearest", "nearest")
end
key_texture.cystal.vanished:setFilter("nearest", "nearest")

local render = {
    shaders = {},
    maps = {
        nowMap = nil,
        mapW = 0,mapH = 0,
        mapBlur = 0.3,
        mapR = 0, mapG = 0, mapB = 0,
        mapRGBsize = 0,
        snowStyle = 0,
        snowR = 255, snowG = 255, snowB = 255,
    },
    effects = {
        particals = {},
        dashlines = {},
        speedcircle = {},
        dashShader = {},
        shadow = {},
    },
    background = {
        skyDis = 0.2,mountDis = 0.15,tree1Dis = 0.1,tree2Dis = 0.05,

        sky = nil,mount = nil,tree1 = nil,tree2 = nil,snow = 0,

        skyH = 0,skyW = 0,mountH = 0,mountW = 0,
        tree1H = 0,tree1W = 0,tree2H = 0,tree2W = 0,

        skyS = 1,mountS = 1,tree1S = 1,tree2S = 1
    },
}
local shaders = render.shaders
local effects = render.effects
local background = render.background
render.floorMode = false

--//有效雪花类型号码
render.snowStyle_valid = {
    [1] = true,[2] = true,[3] = true,
    [4] = true,[5] = true
}

render.TestX,render.TestY = 0,0

--//替代love的一些东西
function render.print(text,x,y,r,sx,sy,ox,oy)
    love.graphics.print(text,x,-y,r,sx,sy,ox,oy)
end
function render.rectangle(mode,x,y,width,height)
    if render.floorMode then
        love.graphics.rectangle(mode,math.floor(x + 0.5),-math.floor(y + 0.5),width,height)
    else
        love.graphics.rectangle(mode,x,-y,width,height)
    end
end
function render.circle(mode,x,y,radius)
    if render.floorMode then
        love.graphics.circle(mode,math.floor(x + 0.5),-math.floor(y + 0.5),radius)
    else
        love.graphics.circle(mode,x,-y,radius)
    end
end
function render.draw(drawable,x,y,r,sx,sy,ox,oy)
    if render.floorMode then
        love.graphics.draw(drawable,math.floor(x + 0.5),-math.floor(y + 0.5),r,sx,sy,ox,oy)
    else
        love.graphics.draw(drawable,x,-y,r,sx,sy,ox,oy)
    end
end

--//移动类机关检测属性完整性
local function moverChecker (t)
    if not type(t.bounce) == "bool" then return false end
    if not type(t["break"]) == "bool" then return false end
    if not type(t.canClimb) == "bool" then return false end
    if not type(t.getTime) == "number" then return false end
    if not type(t.moveX) == "number" then return false end
    if not type(t.moveY) == "number" then return false end
    if not type(t.passive) == "bool" then return false end
    if not type(t.reStar) == "bool" then return false end
    if not type(t.reTime) == "number" then return false end
    if not type(t["repeat"]) == "bool" then return false end
    if not type(t.shake) == "bool" then return false end
    if not type(t.texture) == "number" then return false end
    if not type(t.wait) == "number" then return false end
    return true
end
--//图片预加载
function render.loadImage(path)
    local success, result = pcall(love.graphics.newImage, path)
    if success then
        result:setFilter("nearest", "nearest")
        return result
    else
        return nil
    end
end

--//地图加载
local mapTemp, mapData, quads = {},{},{}
function render.loadMap(WORLD,M_phi,path,Camera)
    mapData = nil
    mapData = require(path)

    local tilesetData = mapData.tilesets[1]--只支持一张tileset
    local imagePath = tilesetData.image:gsub("^%.%./%.%./", "")
    local image = love.graphics.newImage(imagePath)
    image:setFilter("nearest", "nearest")

    -- generate quads
    quads = nil
    quads = {}
    local margin = tilesetData.margin or 0
    local spacing = tilesetData.spacing or 0
    local tileW = tilesetData.tilewidth
    local tileH = tilesetData.tileheight
    local cols = math.floor((tilesetData.imagewidth - 2 * margin + spacing) / (tileW + spacing))--从1开始
    local rows = math.floor((tilesetData.imageheight - 2 * margin + spacing) / (tileH + spacing))--从1开始

    for i = 0, cols * rows - 1 do
        local x = (i % cols) * tileW
        local y = math.floor(i / cols) * tileH
        quads[i + 1] = love.graphics.newQuad(x, y, tileW, tileH, image:getDimensions())
    end

    mapTemp = nil
    mapTemp = {}
    --创建地图消息
    mapTemp.width = mapData.width
    mapTemp.height = mapData.height
    mapTemp.tilewidth = mapData.tilewidth
    mapTemp.tileheight = mapData.tileheight
    mapTemp.image = image
    mapTemp.quads = quads
    mapTemp.layers = mapData.layers

    --改变WORLD的Size和Tiled的大小来对应
    WORLD.Tile.Width = mapData.tilewidth
    WORLD.Tile.Height = mapData.tileheight
    WORLD.Size.x = mapData.width
    WORLD.Size.y = mapData.height

    --//加载Dangers(以quads为准，1为开头)
    M_phi.dangersID.spikeU,M_phi.dangersID.spikeL,M_phi.dangersID.spikeD,M_phi.dangersID.spikeR = 1,2,3,4

    --//删除旧数据
    M_phi.collisionGrid.grid = nil
    M_phi.objects.key = nil
    M_phi.objects.normal = nil
    M_phi.dangerGrid.grid = nil

    Camera.edgeP1.x,Camera.edgeP1.y = 0,0
    Camera.edgeP2.x,Camera.edgeP2.y = 0,0

    render.maps.mapW,render.maps.mapH = 0,0
    background.sky = nil; background.mount = nil; background.tree = nil; background.snow = 0
    background.skyS = 1; background.mountS = 1; background.treeS = 1

    --//加载地图大小
    render.maps.mapW = mapData.tilewidth*mapData.width
    render.maps.mapH = mapData.tileheight*mapData.height

    --//加载Camera里的边界点坐标
    Camera.edgeP1.x,Camera.edgeP1.y = -render.maps.mapW/2 + mapData.tilewidth,render.maps.mapH/2 - mapData.tileheight
    Camera.edgeP2.x,Camera.edgeP2.y = render.maps.mapW/2 - mapData.tilewidth,-render.maps.mapH/2 + mapData.tileheight

    --//加载滤镜设置
    if type(mapData.properties.blur) == "number" then render.maps.mapBlur = math.max(0,math.min(mapData.properties.blur/100,1)) else render.maps.mapBlur = 0.3 end

    if type(mapData.properties.r) == "number" then render.maps.mapR = math.max(0,math.min(mapData.properties.r/255,1)) else render.maps.mapR = 0 end
    if type(mapData.properties.g) == "number" then render.maps.mapG = math.max(0,math.min(mapData.properties.g/255,1)) else render.maps.mapG = 0 end
    if type(mapData.properties.b) == "number" then render.maps.mapB = math.max(0,math.min(mapData.properties.b/255,1)) else render.maps.mapB = 0 end
    if type(mapData.properties.RGBsize) == "number" then render.maps.mapRGBsize = math.max(0,math.min(mapData.properties.RGBsize/100,1)) else render.maps.mapRGBsize = 0 end

    --//加载背景
    if type(mapData.properties.skyPath) == "string" then
        background.sky = render.loadImage(mapData.properties.skyPath)
        if background.sky then
            background.skyW,background.skyH = background.sky:getDimensions()
            if render.maps.mapW >= render.maps.mapH then
                background.skyS = (render.maps.mapW + background.skyDis*render.maps.mapW)/background.skyW
            else
                background.skyS = (render.maps.mapH + background.skyDis*render.maps.mapH)/background.skyH
            end
        end
    end
    if type(mapData.properties.mountPath) == "string" then
        background.mount = render.loadImage(mapData.properties.mountPath)
        if background.mount then
            background.mountW,background.mountH = background.mount:getDimensions()
            if render.maps.mapW >= render.maps.mapH then
                background.mountS = (render.maps.mapW + background.mountDis*render.maps.mapW)/background.mountW
            else
                background.mountS = (render.maps.mapW + background.mountDis*render.maps.mapW)/background.mountW
            end
        end
    end
    if type(mapData.properties.tree1Path) == "string" then
        background.tree1 = render.loadImage(mapData.properties.tree1Path)
        if background.tree1 then
            background.tree1W,background.tree1H = background.tree1:getDimensions()
            if render.maps.mapW >= render.maps.mapH then
                background.tree1S = (render.maps.mapW + background.tree1Dis*render.maps.mapW)/background.tree1W
            else
                background.tree1S = (render.maps.mapW + background.tree1Dis*render.maps.mapW)/background.tree1W
            end
        end
    end
    if type(mapData.properties.tree2Path) == "string" then
        background.tree2 = render.loadImage(mapData.properties.tree2Path)
        if background.tree2 then
            background.tree2W,background.tree2H = background.tree2:getDimensions()
            if render.maps.mapW >= render.maps.mapH then
                background.tree2S = (render.maps.mapW + background.tree2Dis*render.maps.mapW)/background.tree2W
            else
                background.tree2S = (render.maps.mapW + background.tree2Dis*render.maps.mapW)/background.tree2W
            end
        end
    end
    --//雪样式处理
    if type(mapData.properties.snowStyle) == "number" then
        render.maps.snowStyle = mapData.properties.snowStyle
    else
        render.maps.snowStyle = 0
    end
    --//雪颜色设置处理
    if type(mapData.properties.snowR) == "number" then
        render.maps.snowR = math.max(0,math.min(mapData.properties.snowR,255))/255
    else
        render.maps.snowR = 1
    end
    if type(mapData.properties.snowG) == "number" then
        render.maps.snowG = math.max(0,math.min(mapData.properties.snowG,255))/255
    else
        render.maps.snowG = 1
    end
    if type(mapData.properties.snowB) == "number" then
        render.maps.snowB = math.max(0,math.min(mapData.properties.snowB,255))/255
    else
        render.maps.snowB = 1
    end

    --//加载进phisics
    for _, layer in ipairs(mapTemp.layers) do
        if layer.class == "block" and layer.type == "tilelayer" then --加载碰撞（图块层）
            --初始化
            M_phi.collisionGrid.tile = mapTemp.tilewidth
            M_phi.collisionGrid.point.x = -layer.width*mapTemp.tilewidth/2
            M_phi.collisionGrid.point.y = layer.height*mapTemp.tileheight/2--上为正方向
            M_phi.collisionGrid.grid = {}
            M_phi.dangerGrid.grid = {}
            for y = 1,layer.height do
                M_phi.collisionGrid.grid[y] = {}
                M_phi.dangerGrid.grid[y] = {}
                for x = 1,layer.width do
                    M_phi.collisionGrid.grid[y][x] = false
                    M_phi.dangerGrid.grid[y][x] = 0
                end
            end
            --检测
            for y = 0, layer.height - 1 do
                for x = 0, layer.width - 1 do
                    local i = x + y * layer.width + 1
                    local gid = layer.data[i]
                    if gid and gid > 4 then--前4号被占了
                        M_phi.collisionGrid.grid[y + 1][x + 1] = true
                    elseif gid <= 4 and gid > 0 then--1,2,3,4 尖刺占位
                        M_phi.dangerGrid.grid[y+1][x+1] = gid
                    end
                end
            end
        elseif layer.class == "key" and layer.type == "objectgroup" then --必要组件（对象层）
            M_phi.objects.key = {}
            for i,v in pairs(layer.objects) do
                M_phi.objects.key[i] = v
                --//恢复水晶
                if v.type == "refresh" then
                    if type(v.properties.wait) == "number" then
                        v.properties.wait = math.abs(v.properties.wait)
                        v.properties.timer = 0
                        v.vanished = false
                    else--默认设置
                        v.properties.wait = 2.5
                        v.properties.timer = 0
                        v.properties.vanished = false
                    end
                    --初始y轴位置
                    v.properties.oy = v.y
                    v.width = 12
                    v.height = 12 
                end
            end
        elseif layer.class == "normal" and layer.type == "objectgroup" then --非必要组件（对象层)
            M_phi.objects.normal = {}
            for i,v in pairs(layer.objects) do

                if string.sub(v.type,1,6) == "mover_" and tonumber(string.sub(v.type,7)) then--移动机关
                    if moverChecker(v.properties) then
                        M_phi.objects.normal[i] = v
                        --必备
                        if v.properties.objID == nil then--for trigger(未使用)
                            v.properties.objID = tonumber(string.sub(i,7))
                        end
                        if v.properties.getTimer == nil then--for reapet and bounce and normal mover
                            v.properties.getTimer = 0
                        end
                        if v.properties.waitTimer == nil then--for reapet(用做等待时间) and bounce(用做回复时间) and normal(用做回复时间) mover
                            v.properties.waitTimer = 0
                        end
                        if v.properties.ING == nil then--for bounce and normal mover
                            v.properties.ING = false
                        end
                        if v.properties.direction == nil then--for bounce
                            v.properties.direction = M_vec.vec2(0,0)
                        end
                        if v.properties.origin == nil then--for reapet normal mover
                            v.properties.origin = true
                        end
                        if not v.properties.ox and not v.properties.oy then
                            v.properties.ox = v.x
                            v.properties.oy = v.y
                        end
                        if v.properties.vanished == nil then
                            v.properties.vanished = false
                        end
                        if v.properties.reSetTime == nil then
                            v.properties.reSetTime = 0
                        end
                        if not v.lastPosition then
                            v.lastPosition = M_vec.vec2(0,0)
                        end
                        --可选择
                        --多材质
                        local multiTextureID = 1
                        if type(v.properties.multiTexture) == "string" then
                            v.properties["textures"] = {}
                            for num in string.gmatch(v.properties.multiTexture, "%S+") do
                                if tonumber(num) and v.properties["textures"][multiTextureID] == nil then
                                    v.properties["textures"][multiTextureID] = tonumber(num)
                                    multiTextureID = multiTextureID + 1
                                end
                            end
                        else
                            v.properties.multiTexture = nil
                        end
                        --//特殊类
                        if type(v.properties.specific) == "number" then
                            if not mover_valid[v.properties.specific] then
                                v.properties.specific = nil
                            end
                        else
                            v.properties.specific = nil
                        end

                        --调整大小
                        v.width = math.max(8,align8_down(v.width))
                        v.height = math.max(8,align8_down(v.height))
                    end
                elseif string.sub(v.type,1,8) == "trigger_" and tonumber(string.sub(v.type,9)) then--预加载机关触发
                    M_phi.objects.normal[i] = v
                    --调整大小
                    v.width = math.max(8,align8_down(v.width))
                    v.height = math.max(8,align8_down(v.height))
                elseif string.sub(v.type,1,6) == "spring" then--弹簧
                    M_phi.objects.normal[i] = v
                    v.properties.timer = 0--动画设置时间
                end

            end
            --正式加载机关触发
            for _,tri in pairs(M_phi.objects.normal) do
                if string.sub(tri.type,1,8) == "trigger_" and tonumber(string.sub(tri.type,9)) then
                    for __,obj in pairs(M_phi.objects.normal) do
                        if obj.type == "mover_" .. string.sub(tri.type,9) then
                            if tri.properties.objIndex == nil and not obj.properties["repeat"] and not obj.properties.bounce then
                                tri.properties.objIndex = obj--自带索引
                            end
                        end
                    end
                end
            end

        end
    end

    --//绘制地图
    function mapTemp:draw(offsetX, offsetY, mode)
        offsetX = offsetX or 0
        offsetY = offsetY or 0
        local drawX,drawY,gid,i
        for _, layer in ipairs(self.layers) do--对多层级layer渲染
            --图层信息
            if layer.tintcolor then
                love.graphics.setColor(layer.tintcolor[1]/255,layer.tintcolor[2]/255,layer.tintcolor[3]/255,layer.opacity)
            else
                love.graphics.setColor(1,1,1,layer.opacity)
            end
            --图块层渲染（先）
            if layer.type == "tilelayer" then
                for y = 0, layer.height - 1 do
                    for x = 0, layer.width - 1 do
                        i = x + y * layer.width + 1
                        gid = layer.data[i]
                        if gid and gid > 0 then--判断是否该画上
                            if mode == "center" then
                                drawX = x * tileW - layer.width*mapTemp.tilewidth/2
                                drawY = y * tileH - layer.height*mapTemp.tileheight/2
                                love.graphics.draw(self.image, self.quads[gid], drawX, drawY)
                            else
                                drawX = x * tileW + offsetX
                                drawY = y * tileH - offsetY
                                love.graphics.draw(self.image, self.quads[gid], drawX, drawY)
                            end
                        end
                    end
                end
            end
        end

        --//对应的quads在Tiled里点击一个Tile查看ID
        --//normal渲染
        local px,py
        for _,v in pairs(M_phi.objects.normal) do
            if string.sub(v.type,1,6) == "mover_" then
                if not v.properties.vanished then--是否消失

                    if v.properties.specific then--//单向板渲染
                        px = v.x - mapTemp.width*mapTemp.tilewidth/2
                        py = v.y - mapTemp.height*mapTemp.tileheight/2
                        if v.properties.specific == 11 then--上-左开
                            local length = v.width/8
                            for x = 0,length - 1 do
                                if x == 0 then
                                    love.graphics.draw(mover_sheet, mover_texture[1], px + x*8, py)
                                elseif x == length - 1 then
                                    love.graphics.draw(mover_sheet, mover_texture[3], px + x*8, py)
                                else
                                    love.graphics.draw(mover_sheet, mover_texture[2], px + x*8, py)
                                end       
                            end
                        elseif v.properties.specific == 12 then--上-右开
                            local length = v.width/8
                            for x = 0,length - 1 do
                                if x == length - 1 then
                                    love.graphics.draw(mover_sheet, mover_texture[13], px + x*8, py)
                                elseif x == 0 then
                                    love.graphics.draw(mover_sheet, mover_texture[11], px + x*8, py)
                                else
                                    love.graphics.draw(mover_sheet, mover_texture[12], px + x*8, py)
                                end       
                            end
                        elseif v.properties.specific == 21 then--左-上开
                            local length = v.height/8
                            for y = 0,length - 1 do
                                if y == 0 then
                                    love.graphics.draw(mover_sheet, mover_texture[21], px, py + y*8)
                                elseif y == length - 1 then
                                    love.graphics.draw(mover_sheet, mover_texture[41], px, py + y*8)
                                else
                                    love.graphics.draw(mover_sheet, mover_texture[31], px, py + y*8)
                                end       
                            end
                        elseif v.properties.specific == 22 then--左-下开
                            local length = v.height/8
                            for y = 0,length - 1 do
                                if y == length - 1 then
                                    love.graphics.draw(mover_sheet, mover_texture[42], px, py + y*8)
                                elseif y == 0 then
                                    love.graphics.draw(mover_sheet, mover_texture[22], px, py + y*8)
                                else
                                    love.graphics.draw(mover_sheet, mover_texture[32], px, py + y*8)
                                end       
                            end
                        elseif v.properties.specific == 31 then--下-左开
                            local length = v.width/8
                            for x = 0,length - 1 do
                                if x == 0 then
                                    love.graphics.draw(mover_sheet, mover_texture[4], px + x*8, py + v.height - 8)
                                elseif x == length - 1 then
                                    love.graphics.draw(mover_sheet, mover_texture[6], px + x*8, py + v.height - 8)
                                else
                                    love.graphics.draw(mover_sheet, mover_texture[5], px + x*8, py + v.height - 8)
                                end       
                            end
                        elseif v.properties.specific == 32 then--下-左开
                            local length = v.width/8
                            for x = 0,length - 1 do
                                if x == length - 1 then
                                    love.graphics.draw(mover_sheet, mover_texture[16], px + x*8, py + v.height - 8)
                                elseif x == 0 then
                                    love.graphics.draw(mover_sheet, mover_texture[14], px + x*8, py + v.height - 8)
                                else
                                    love.graphics.draw(mover_sheet, mover_texture[15], px + x*8, py + v.height - 8)
                                end       
                            end
                        elseif v.properties.specific == 41 then--右-上开
                            local length = v.height/8
                            for y = 0,length - 1 do
                                if y == 0 then
                                    love.graphics.draw(mover_sheet, mover_texture[23], px + v.width - 8, py + y*8)
                                elseif y == length - 1 then
                                    love.graphics.draw(mover_sheet, mover_texture[43], px + v.width - 8, py + y*8)
                                else
                                    love.graphics.draw(mover_sheet, mover_texture[33], px + v.width - 8, py + y*8)
                                end       
                            end
                        elseif v.properties.specific == 42 then--右-上开
                            local length = v.height/8
                            for y = 0,length - 1 do
                                if y == length - 1 then
                                    love.graphics.draw(mover_sheet, mover_texture[44], px + v.width - 8, py + y*8)
                                elseif y == 0 then
                                    love.graphics.draw(mover_sheet, mover_texture[24], px + v.width - 8, py + y*8)
                                else
                                    love.graphics.draw(mover_sheet, mover_texture[34], px + v.width - 8, py + y*8)
                                end       
                            end
                        end
                    elseif v.properties.multiTexture and v.properties.textures then--//多材质渲染
                        px = v.x - mapTemp.width*mapTemp.tilewidth/2
                        py = v.y - mapTemp.height*mapTemp.tileheight/2
                        for y = 0,v.height/8 - 1 do
                            for x = 0,v.width/8 - 1 do
                                if v.properties.textures[x+y*(v.width/8) + 1] then
                                    love.graphics.draw(self.image, self.quads[v.properties.textures[x+y*(v.width/8) + 1] + 1], px + x*8, py + y*8)
                                else
                                    love.graphics.draw(self.image, self.quads[math.random(1,#self.quads)], px + x*8, py + y*8)
                                end
                            end
                        end
                    elseif self.quads[v.properties.textrue + 1] then --//单材质渲染
                        px = v.x - mapTemp.width*mapTemp.tilewidth/2
                        py = v.y - mapTemp.height*mapTemp.tileheight/2
                        for x = 0,v.width/8 - 1 do
                            for y = 0,v.height/8 - 1 do
                                love.graphics.draw(self.image, self.quads[v.properties.textrue + 1], px + x*8, py + y*8)
                            end
                        end
                    end

                end
            end
        end

        --//key渲染
        for _,v in pairs(M_phi.objects.key) do
            if string.sub(v.type,1,7) == "refresh" then
                px = v.x - mapTemp.width*mapTemp.tilewidth/2
                py = v.y - mapTemp.height*mapTemp.tileheight/2

                if not v.properties.vanished then
                    love.graphics.draw(key_texture.cystal[key_texture.cystal.num],px,py)
                else
                    love.graphics.draw(key_texture.cystal["vanished"],px,py)
                end
            end
        end

    end

    return mapTemp
end

--//粒子效果
local DashParticalColor1 = M_col.AddNormalLines({
    Repeat = true,
    SetColor = {R = 52,G = 255, B = 255},
    TargetColor = {R =255,G = 255, B = 255},
    SetTime = 0.1
})
local DashParticalColor2 = M_col.AddNormalLines({
    Repeat = true,
    SetColor = {R = 255,G = 102, B = 255},
    TargetColor = {R =255,G = 255, B = 255},
    SetTime = 0.1
})
function render.setParticals(mode,d,p,c,s,t,r)
    local L = {
        position = M_vec.vec2(0,0),
        color = {R = 150,G = 150, B = 255},
        direction = M_vec.vec2(0,0),
        size = 1,
        random = 10,

        setTime = 1,--0 == delete
        timer = 1,

        sign = "",--d == dash,s == smoke
    }

    if mode == "dash1" then
        L.color = DashParticalColor1
        L.setTime = 1.4
        L.size = 1
        L.random = 10
        L.sign = "d"
    elseif mode == "dash2" then
        L.color = DashParticalColor2
        L.setTime = 1.4
        L.size = 1
        L.random = 10
        L.sign = "d"
    elseif mode == "smoke" then
        L.color.R,L.color.G,L.color.B = 255,255,255
        if math.random(0,1) == 0 then
            L.size = 1.25
        else
            L.size = 1
        end
        L.random = 2
        L.setTime = math.random(2,10)/10
        L.sign = "s"
    end
    if c then
        L.color = c
    end
    if t then
        L.setTime = t
    end
    if p then
        L.position.x,L.position.y = p.x,p.y
    end
    if d then
        L.direction.x,L.direction.y = d.x,d.y
    end
    if s then
        L.size = s
    end
    if r then
        L.random = r
    end
    L.timer = L.setTime

    table.insert(effects.particals,L)
end
function render.particalPUpdater(dt)
    for _ = #effects.particals, 1, -1 do
        local v = effects.particals[_]

        v.position.x = v.position.x + math.random(-v.random,v.random)*0.15 + v.direction.x*1.6
        v.position.y = v.position.y + math.random(-v.random,v.random)*0.15  + v.direction.y*1.6

        if v.sign == "d" then
            v.direction.y = math.max(-1,math.min(v.direction.y - 0.15,1))
            v.direction.x = numLerp(v.direction.x,0,0.02)
        end
    end
end
function render.particalTUpdater(dt)
    for _ = #effects.particals, 1, -1 do
        local v = effects.particals[_]
        if v.timer - dt <= 0 then
            table.remove(effects.particals,_)
        else
            v.timer = v.timer - dt
        end
    end
end
function render.drawParticals()
    for _ = #effects.particals, 1, -1 do
        local v = effects.particals[_]
        
        if v.sign == "d" then
            love.graphics.setColor(M_col.toRatio(v.color.NowColor,v.timer/v.setTime))
        elseif v.sign == "s" then
            love.graphics.setColor(M_col.toRatio(v.color))
        else
            love.graphics.setColor(M_col.toRatio(v.color,v.timer/v.setTime))
        end
        render.rectangle("fill",v.position.x,v.position.y,v.size,v.size)
    end
end

--//Dash线条效果（没错是代码写出来的）
function render.dashlineUpdater(dt)
    for _ = #effects.dashlines, 1, -1 do
        local v = effects.dashlines[_]
        if v.timer - dt <= 0 then
            table.remove(effects.dashlines,_)
        else
            v.timer = v.timer - dt
        end
    end
end
function render.drawDashLines()
    love.graphics.setColor(1,1,1,1)
    for _ = #effects.dashlines, 1, -1 do
        local v = effects.dashlines[_]
        local px,py = v.position.x,v.position.y

        if v.direction == 0 then
            if v.timer > 0.2 then
                render.rectangle("fill",px - 1,py + 3.5,1,7)
                render.rectangle("fill",px + 1,py + 3.5,1,7)
                render.rectangle("fill",px,py + 6,1,12)
            elseif v.timer > 0.1 then
                render.rectangle("fill",px - 1,py + 3.5,1,7)
                render.rectangle("fill",px + 1,py + 3.5,1,7)
                render.rectangle("fill",px,py + 6,1,12)
            elseif v.timer > 0.08 then
                render.rectangle("fill",px,py + 8,1,16)
            elseif v.timer > 0.05 then
                render.rectangle("fill",px,py + 11,1,9)
                render.rectangle("fill",px,py - 2,1,9)
            elseif v.timer > 0 then
                render.rectangle("fill",px,py + 6,1,1)
                render.rectangle("fill",px,py + 11,1,3)
                render.rectangle("fill",px,py - 5,1,1)
                render.rectangle("fill",px,py - 8,1,3)
            end
        elseif v.direction == 1 then
            if v.timer > 0.21 then
                render.rectangle("fill",px - 3.5,py - 1,7,1)
                render.rectangle("fill",px - 3.5,py + 1,7,1)
                render.rectangle("fill",px - 6  ,py,12,1)
            elseif v.timer > 0.14 then
                render.rectangle("fill",px - 3.5,py - 1,7,1)
                render.rectangle("fill",px - 3.5,py + 1,7,1)
                render.rectangle("fill",px - 6  ,py,12,1)
            elseif v.timer > 0.12 then
                render.rectangle("fill",px - 8,py ,16,1)
            elseif v.timer > 0.05 then
                render.rectangle("fill",px + 3,py ,9,1)
                render.rectangle("fill",px - 12,py ,9,1)
            elseif v.timer > 0.02 then
                render.rectangle("fill",px + 3,py,1,1)
                render.rectangle("fill",px + 8,py,4,1)
                render.rectangle("fill",px - 4,py ,1,1)
                render.rectangle("fill",px - 12,py ,4,1)
            end
        elseif v.direction == 2 then
            if v.timer > 0.21 then
                for i = 0,8 do render.rectangle("fill",px - 4 + i,py - 4 + i ,1,1) end
                for i = 0,7 do render.rectangle("fill",px - 4 + i,py - 3 + i ,1,1) end
                for i = 0,7 do render.rectangle("fill",px - 3 + i,py - 4 + i ,1,1) end
                for i = 0,4 do render.rectangle("fill",px - 3 + i,py - 1 + i ,1,1) end
                for i = 0,4 do render.rectangle("fill",px - 1 + i,py - 3 + i ,1,1) end
            elseif v.timer > 0.16 then
                 for i = 0,8 do render.rectangle("fill",px - 4 + i,py - 4 + i ,1,1) end
                for i = 0,7 do render.rectangle("fill",px - 4 + i,py - 3 + i ,1,1) end
                for i = 0,7 do render.rectangle("fill",px - 3 + i,py - 4 + i ,1,1) end
                for i = 0,4 do render.rectangle("fill",px - 3 + i,py - 1 + i ,1,1) end
                for i = 0,4 do render.rectangle("fill",px - 1 + i,py - 3 + i ,1,1) end
            elseif v.timer > 0.14 then
                for i = 0,10 do render.rectangle("fill",px - 5 + i,py - 5 + i ,1.5,1.5) end
            elseif v.timer > 0.08 then
                for i = 0,4 do render.rectangle("fill",px - 6 + i,py - 6 + i ,1.5,1.5) end
                for i = 0,4 do render.rectangle("fill",px + 2 + i,py + 2 + i ,1.5,1.5) end
                render.rectangle("fill",px,py,1,1)
            elseif v.timer > 0.04 then
                for i = 0,3 do render.rectangle("fill",px - 8 + i,py - 8 + i ,1,1) end
                for i = 0,1 do render.rectangle("fill",px - 3 + i,py - 3 + i ,1,1) end
                for i = 0,1 do render.rectangle("fill",px + 2 + i,py + 2 + i ,1,1) end
                for i = 0,3 do render.rectangle("fill",px + 5 + i,py + 5 + i ,1,1) end
            end
        elseif v.direction == 3 then
            if v.timer > 0.21 then
                for i = 0,8 do render.rectangle("fill",px + 4 - i,py - 4 + i ,1,1) end
                for i = 0,7 do render.rectangle("fill",px + 4 - i,py - 3 + i ,1,1) end
                for i = 0,7 do render.rectangle("fill",px + 3 - i,py - 4 + i ,1,1) end
                for i = 0,4 do render.rectangle("fill",px + 3 - i,py - 1 + i ,1,1) end
                for i = 0,4 do render.rectangle("fill",px + 1 - i,py - 3 + i ,1,1) end
            elseif v.timer > 0.16 then
                for i = 0,8 do render.rectangle("fill",px + 4 - i,py - 4 + i ,1,1) end
                for i = 0,7 do render.rectangle("fill",px + 4 - i,py - 3 + i ,1,1) end
                for i = 0,7 do render.rectangle("fill",px + 3 - i,py - 4 + i ,1,1) end
                for i = 0,4 do render.rectangle("fill",px + 3 - i,py - 1 + i ,1,1) end
                for i = 0,4 do render.rectangle("fill",px + 1 - i,py - 3 + i ,1,1) end
            elseif v.timer > 0.14 then
                for i = 0,10 do render.rectangle("fill",px + 5 - i,py - 5 + i ,1.5,1.5) end
            elseif v.timer > 0.08 then
                for i = 0,4 do render.rectangle("fill",px + 6 - i,py - 6 + i ,1.5,1.5) end
                for i = 0,4 do render.rectangle("fill",px - 2 - i,py + 2 + i ,1.5,1.5) end
                render.rectangle("fill",px,py,1,1)
            elseif v.timer > 0.04 then
                for i = 0,3 do render.rectangle("fill",px + 8 - i,py - 8 + i ,1,1) end
                for i = 0,1 do render.rectangle("fill",px + 3 - i,py - 3 + i ,1,1) end
                for i = 0,1 do render.rectangle("fill",px - 2 - i,py + 2 + i ,1,1) end
                for i = 0,3 do render.rectangle("fill",px - 5 - i,py + 5 + i ,1,1) end
            end
        end
    end
end
function render.setDashLines(direction,p)
    L = {
        direction = 0,--0:上,下,1:左,右,2:右上,左下,3:左上,左下
        timer = 0.25,
        position = M_vec.vec2(0,0),
    }
    if direction then
        L.direction = direction
    end
    if p then
        L.position.x,L.position.y = p.x,p.y
    end
    table.insert(effects.dashlines,L)
end

--//速度圈圈效果
function render.speedcircleUpdater(dt)
    for _ = #effects.speedcircle, 1, -1 do
        local v = effects.speedcircle[_]

        if v.timer + dt >= v.setTime then
            v.timer = v.setTime
            if v.keepTime - dt < 0 then
                table.remove(effects.speedcircle,_)
            else
                v.keepTime = v.keepTime - dt
            end
        else
            v.timer = v.timer + dt
        end
    end
end
function render.drawSpeedcircle()
    for _ = #effects.speedcircle, 1, -1 do
        local v = effects.speedcircle[_]

        local t = v.timer/v.setTime
        local alpha = 1 - t
        local scale = 1 + t * 3

        local angle = M_vec.Vec2toA(v.direction) + math.pi/2
        love.graphics.push()
        love.graphics.translate(v.position.x, -v.position.y)
        love.graphics.rotate(angle)
        love.graphics.scale(scale, 0.35 * scale) -- 横向拉伸
        love.graphics.setColor(1, 1, 1, alpha)
        render.circle("line", 0, 0, v.size)
        love.graphics.pop()

    end
    love.graphics.setColor(1, 1, 1, 1)
end
function render.setSpeedcircle(p,d,c,s,t)
    local L = {
        position = M_vec.vec2(0,0),
        color = {R = 150,G = 150, B = 150},
        direction = M_vec.vec2(0,0),
        size = 3,

        setTime = 0.6,
        timer = 0,

        keepTime = 0.25,
    }

    if c then
        L.color = c
    end
    if t then
        L.setTime = t
    end
    if p then
        L.position.x,L.position.y = p.x,p.y
    end
    if d then
        L.direction.x,L.direction.y = d.x,d.y
    end
    if s then
        L.size = s
    end
    
    table.insert(effects.speedcircle,L)
end

--//残影效果
local pureColorShader = love.graphics.newShader([[
   extern vec4 targetColor;

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {

        // 获取像素颜色，只用 alpha
        vec4 texColor = Texel(texture, texture_coords);

        // 输出纯色 + 原图 alpha
        return vec4(targetColor.rgb, texColor.a * targetColor.a);
    }
]])
local pureColorShaderflipX = love.graphics.newShader([[
   extern vec4 targetColor;

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        // 水平翻转
        texture_coords.x = 1.0 - texture_coords.x;

        // 获取像素颜色，只用 alpha
        vec4 texColor = Texel(texture, texture_coords);

        // 输出纯色 + 原图 alpha
        return vec4(targetColor.rgb, texColor.a * targetColor.a);
    }
]])
local DEFAULT_IMAGE = love.graphics.newImage("assets/Player/Template/Template.png")
function render.shadowUpdater(dt)
    for _ = #effects.shadow, 1, -1 do
        local v = effects.shadow[_]

        if v.timer - dt <= 0 then
            table.remove(effects.shadow,_)
        else
            v.timer = v.timer - dt
        end
    end
end
function render.drawShadow()
    for _ = #effects.shadow, 1, -1 do
        local v = effects.shadow[_]

        if v.faceSide == "left" then
            pureColorShaderflipX:send("targetColor", {M_col.toRatio(v.color,math.max(v.timer/v.setTime - 0.4,0))})
            love.graphics.setShader(pureColorShaderflipX)
        else
            pureColorShader:send("targetColor", {M_col.toRatio(v.color,math.max(v.timer/v.setTime - 0.4,0))})
            love.graphics.setShader(pureColorShader)
        end
        render.draw(
            v.image, 
            v.position.x - v.width/2 + v.dx - 2.2,
            v.position.y + v.height/2 + v.dy + 2.8,
            0,
            v.width/9,
            v.height/17
        )
        love.graphics.setShader()
    end
end
function render.setShadow(p,w,h,dx,dy,i,f,c,t)
    local L = {
        position = M_vec.vec2(0,0),
        color = {R = 150,G = 150, B = 150},
        image = DEFAULT_IMAGE,
        faceSide = "right",
        width = 10,height = 10,
        dx = 0,dy = 0,

        setTime = 1.2,
        timer = 0,
    }
    if p then
        L.position.x,L.position.y = p.x,p.y
    end
    if w then
        L.width = w
    end
    if h then
        L.height = h
    end
    if i then
        L.image = i
    end
    if f then
        L.faceSide = f
    end
    if c then
        L.color = c
    end
    if t then
        L.setTime = t
    end
    L.timer = L.setTime
    table.insert(effects.shadow,L)
end

--//扭曲效果
function render.dashshaderUpdater(dt)
    for _ = #effects.dashShader, 1, -1 do
        local v = effects.dashShader[_]
        if v.timer + dt >= v.setTime then
            v.timer = v.setTime
            table.remove(effects.dashShader,_)
        else
            v.timer = v.timer + dt
            if v.mode == "all" and v.timer/v.setTime >= 0.5 then
                table.remove(effects.dashShader,_)
            end
        end
    end
end
function render.drawDashshader(canvas,shader,Camera,WINDOW_INFO)
    local finalCanvas = canvas
    for i = #effects.dashShader, 1, -1 do
        local v = effects.dashShader[i]
        local PG = smoothStep(v.timer / v.setTime) -- progress
        local IN_radius = v.radius

        -- 获取屏幕像素位置（绝对）
        local cx, cy = M_win.toCanvasPosition(v.position, Camera)
        local wp = {cx, cy}

        -- 半径随进度缩放
        if PG < 0.5 then
            IN_radius = v.radius * (PG / 0.5)
        else
            IN_radius = v.radius * (1 - (PG - 0.5) / 0.5)
        end

        -- 渲染
        local tempCanvas = M_win.createCanvas()
        love.graphics.setCanvas(tempCanvas)
        love.graphics.setColor(1, 1, 1, 1)

        shader:send("center", wp)
        shader:send("radius", IN_radius)
        shader:send("progress", PG)
        love.graphics.setShader(shader)
        love.graphics.draw(finalCanvas,0,0)

        love.graphics.setShader()
        love.graphics.setCanvas()
        finalCanvas = tempCanvas
    end
    return finalCanvas
end
function render.setDashshader(p,r,t,m)
    L = {
        position = M_vec.vec2(0,0),
        radius = 40,

        setTime = 0.25,
        timer = 0,

        mode = "",
    }

    if p then
        L.position.x,L.position.y = p.x,p.y
    end
    if r then
        L.radius = r
    end
    if t then
        L.setTime = t
    end
    if m == "all" then
        L.mode = m
    end

    table.insert(effects.dashShader,L)
end

--//聚光灯效果
shaders.spotlight = love.graphics.newShader([[
    extern vec2 center;        // 聚光灯中心位置（屏幕坐标）
    extern number radius;      // 半径
    extern number smoothness;  // 边缘柔和程度，例如 0.1

    vec4 effect(vec4 color, Image texture, vec2 texCoords, vec2 screenCoords) {
        float dist = distance(screenCoords, center) / radius;
        float alpha = smoothstep(1.0, 1.0 - smoothness, dist);
        vec4 texColor = Texel(texture, texCoords);
        return texColor * mix(vec4(0.0, 0.0, 0.0, 1.0), color, alpha);
    }
]])
function render.setSpotlight(canvas, position, Camera, WINDOW_INFO, radius, smoothness)
    local cx, cy = M_win.toCanvasPosition(position, Camera)
    local wp = {cx, cy}

    local r = radius or 15
    local s = smoothness or 0.1

    local tempCanvas = M_win.createCanvas()

    love.graphics.setCanvas(tempCanvas)
    love.graphics.setColor(1, 1, 1, 1)

    shaders.spotlight:send("center", wp)
    shaders.spotlight:send("radius", r)
    shaders.spotlight:send("smoothness", s)

    love.graphics.setShader(shaders.spotlight)
    love.graphics.draw(canvas, 0, 0)
    love.graphics.setShader()
    love.graphics.setCanvas()

    return tempCanvas
end

--//模糊效果
shaders.blur = love.graphics.newShader([[
    extern number radius;        // 模糊半径
    extern number strength;      // 发光强度
    extern vec2 screenSize;      // 屏幕大小

    vec4 effect(vec4 color, Image texture, vec2 texCoords, vec2 screenCoords) {
        vec4 sum = vec4(0.0);
        number total = 0.0;

        // 以屏幕坐标计算像素偏移
        for (int x = -4; x <= 4; x++) {
            for (int y = -4; y <= 4; y++) {
                vec2 offset = vec2(x, y) * radius / screenSize;
                number weight = 1.0 - length(vec2(x, y)) / 5.656; // 5.656 ≈ sqrt(32)
                sum += Texel(texture, texCoords + offset) * weight;
                total += weight;
            }
        }

        vec4 blurred = sum / total;
        vec4 base = Texel(texture, texCoords);
        
        // 将模糊部分加在明亮区域上
        vec4 glow = mix(base, blurred, strength);
        return glow * color;
    }
]])
function render.setBlur(canvas,WINDOW_INFO,num)
    local tempCanvas = M_win.createCanvas()

    love.graphics.setCanvas(tempCanvas)
    love.graphics.setColor(1, 1, 1, 1)

    shaders.blur:send("radius", 2.0)
    if type(num) == "number" then
        shaders.blur:send("strength", math.max(0,math.min(num,1)))
    else
        shaders.blur:send("strength", render.maps.mapBlur)
    end
    shaders.blur:send("screenSize", {WINDOW_INFO.Width, WINDOW_INFO.Height})
    love.graphics.setShader(shaders.blur)
    love.graphics.draw(canvas)

    love.graphics.setShader()
    love.graphics.setCanvas()
    return tempCanvas
end

--//颜色滤镜
shaders.colorShader = love.graphics.newShader([[
    extern vec4 filterColor; // 外部传入的滤镜颜色 (r, g, b, a)

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
    {
        vec4 texColor = Texel(texture, texture_coords) * color;
        // 将原始颜色与滤镜颜色混合（你可以调混合比重）
        return mix(texColor, filterColor, filterColor.a);
    }
]])
function render.setColorShader(canvas,Ct)
    local tempCanvas = M_win.createCanvas()

    love.graphics.setCanvas(tempCanvas)
    love.graphics.setColor(1, 1, 1, 1)
    if type(Ct) == "table" then
        shaders.colorShader:send("filterColor", Ct)
    else
        shaders.colorShader:send("filterColor", {render.maps.mapR, render.maps.mapG, render.maps.mapB, render.maps.mapRGBsize})
    end
    love.graphics.setShader(shaders.colorShader)
    love.graphics.draw(canvas)

    love.graphics.setShader()
    love.graphics.setCanvas()
    return tempCanvas
end

--//测试用
shaders.crt = love.graphics.newShader([[
    extern number time;
    float t = time * 0.0;

    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords)
    {
        vec2 cuv = uv * 2.0 - 1.0;
        
        float dist = dot(cuv, cuv);
        float bend = 0.2;

        // 强制放大画面一点(0.85 < 原来的 0.833)
        float scaleFix = 0.78;  // 你可以调成 0.8、0.75 更大视野
        cuv *= scaleFix;

        cuv *= 1.0 + bend * dot(cuv, cuv);
        uv = (cuv + 1.0) * 0.5;
        uv = clamp(uv, 0.0, 1.0);

        vec4 col;
        col.r = texture2D(tex, uv).r;
        col.g = texture2D(tex, uv).g;
        col.b = texture2D(tex, uv).b;
        col.a = 1.0;

        return col * color;
    }
]])
shaders.gray = love.graphics.newShader([[
    extern number time;
    float t = time * 0.0;

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 texColor = Texel(texture, texture_coords);
        float gray = dot(texColor.rgb, vec3(0.299, 0.587, 0.114));
        return vec4(vec3(gray), texColor.a) * color;
    }
]])

--//UI模糊
shaders.UI_Blur = love.graphics.newShader([[
    extern number radius;
    extern number softness;
    extern vec2 screenSize;
    extern number time;

    vec4 effect(vec4 color, Image texture, vec2 texCoords, vec2 screenCoords) {
        vec2 uv = screenCoords / screenSize;
        vec2 center = vec2(0.5, 0.5);

        // 加入时间扰动 - 轻微流动感
        uv.x += 0.01 * sin(uv.y * 10.0 + time);
        uv.y += 0.01 * cos(uv.x * 10.0 + time);

        float dist = distance(uv, center);
        float mixFactor = smoothstep(radius, radius - softness, dist);

        vec4 pixel = Texel(texture, texCoords);
        vec3 iceColor = vec3(0.6, 0.8, 1.0);
        pixel.rgb = mix(pixel.rgb, iceColor, mixFactor);

        return pixel * color;
    }
]])

--//部分预设
--注意这里center的Y向下为正
shaders.rippleShader = love.graphics.newShader([[
    extern vec2 center;
    extern number radius;
    extern number progress;

    vec4 effect(vec4 color, Image texture, vec2 texCoord, vec2 screenCoord)
    {
    vec2 dir = screenCoord - center;
    float dist = length(dir);
    vec2 offset = vec2(0.0);

    float ringWidth = radius * 0.5;
    float halfWidth = ringWidth * 0.5;

    float outerRadius;
    float innerRadius;
    float strength = 0.0;

    if (progress < 0.5) {
        float t = progress / 0.5;
        outerRadius = mix(0.0, radius, t);
        innerRadius = outerRadius - ringWidth;

        if (dist >= innerRadius && dist <= outerRadius) {
            float fade = 1.0 - (dist - innerRadius) / ringWidth;

            // 判断是内半环还是外半环
            float distInnerDiff = dist - innerRadius;

            if (distInnerDiff < halfWidth) {
                // 内半环：向外扭曲，扭曲方向取反
                strength = -fade * 0.03;
            } else {
                // 外半环：向内扭曲，保持原方向
                strength = fade * 0.03;
            }
        }

    } else {
        float t = (progress - 0.5) / 0.5;
        outerRadius = mix(radius, radius * 4.5, t);
        innerRadius = outerRadius - ringWidth;

        if (dist >= innerRadius && dist <= outerRadius) {
            float fade = 1.0 - (dist - innerRadius) / ringWidth;
            float strengthFade = 1.0 - t;

            float distInnerDiff = dist - innerRadius;

            if (distInnerDiff < halfWidth) {
                // 内半环向外扭曲，强度减弱
                strength = -fade * 0.03 * strengthFade;
            } else {
                // 外半环向内扭曲，强度减弱
                strength = fade * 0.03 * strengthFade;
            }
        }
    }

    // 根据 strength 方向，计算偏移向量
    offset = -normalize(dir) * strength;

    return Texel(texture, texCoord + offset) * color;
    }

]])
shaders.flipX = love.graphics.newShader([[
    extern number time;
    float t = time * 0.0;

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {

    texture_coords.x = 1.0 - texture_coords.x;

    return Texel(texture, texture_coords) * color;
    }
]])
shaders.origin = love.graphics.newShader([[
    extern number time;
    float t = time * 0.0;

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
    {
        return Texel(texture, texture_coords) * color;
    }
]])

--//测试用
function render.shaderSetup(canvas,WINDOW_INFO,Shader)
    local canvasTemp = love.graphics.newCanvas(WINDOW_INFO.InWidth,WINDOW_INFO.InHeight)
    canvasTemp:setFilter("nearest", "nearest")

    love.graphics.setCanvas(canvasTemp)
    love.graphics.clear()
    love.graphics.setShader(shaders[Shader])
    shaders[Shader]:send("time", love.timer.getTime())

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(canvas)--把canvas画到canvasTemp上,其中canvas没有改变
    
    love.graphics.setShader()
    love.graphics.setCanvas()
    return canvasTemp
end

--//玩家形象和头发
shaders.flipX_changeHair = love.graphics.newShader([[
    extern vec3 oldColor1;
    extern vec3 newColor1;
    extern vec3 oldColor2;
    extern vec3 newColor2;
    extern number threshold;

    vec4 effect(vec4 color, Image texture, vec2 texCoords, vec2 screenCoords) {
        // 翻转
        texCoords.x = 1.0 - texCoords.x;

        // 原始像素
        vec4 pixel = Texel(texture, texCoords);

        // 染色逻辑
        float diff1 = distance(pixel.rgb, oldColor1);
        float diff2 = distance(pixel.rgb, oldColor2);

        if (diff1 < threshold) {
            pixel.rgb = newColor1;
        } else if (diff2 < threshold) {
            pixel.rgb = newColor2;
        }

        return pixel * color;
    }
]])
shaders.changeHair = love.graphics.newShader([[
    extern vec3 oldColor1;
    extern vec3 newColor1;
    extern vec3 oldColor2;
    extern vec3 newColor2;
    extern number threshold;

    vec4 effect(vec4 color, Image texture, vec2 texCoords, vec2 screenCoords) {
        vec4 pixel = Texel(texture, texCoords);

        float diff1 = distance(pixel.rgb, oldColor1);
        float diff2 = distance(pixel.rgb, oldColor2);

        if (diff1 < threshold) {
            pixel.rgb = newColor1;
        } else if (diff2 < threshold) {
            pixel.rgb = newColor2;
        }

        return pixel * color;
    }
]])
local function hairChanger(shader)
    love.graphics.setShader(shader)
    shader:send("oldColor1", M_ply.hair.LRed)--红色头发（正常）
    shader:send("oldColor2", M_ply.hair.DRed)--红色头发（暗色）

    if M_ply.hair.NowColor == "Pink" then
        shader:send("newColor1", M_ply.hair.LPink)
        shader:send("newColor2", M_ply.hair.DPink)
    elseif M_ply.hair.NowColor == "Red" then
        shader:send("newColor1", M_ply.hair.LRed)
        shader:send("newColor2", M_ply.hair.DRed)
    elseif M_ply.hair.NowColor == "Blue" then
        shader:send("newColor1", M_ply.hair.LBlue)
        shader:send("newColor2", M_ply.hair.DBlue)
    elseif M_ply.hair.NowColor == "White" then
        shader:send("newColor1", M_ply.hair.White)
        shader:send("newColor2", M_ply.hair.White)
    end       
    shader:send("threshold", 0.01)
end
function render.drawPlayer(GAME_CANVAS,M_ply,Camera)
    love.graphics.setCanvas(GAME_CANVAS)
    if M_ply.state.faceSide == "left" then
        hairChanger(shaders.flipX_changeHair)
    else
        hairChanger(shaders.changeHair)
    end

    --画头发
    if not M_ply.state.dying then
        for i = 1,6 do
            if i == 1 then
                render.draw(M_ply.texture.Hair[1],
                    M_ply.position.x + M_ply.hair.Dx + M_ply.hair["v" .. i].x - 5.5,
                    M_ply.position.y + M_ply.hair.Dy + M_ply.hair["v" .. i].y + 5.5
                )
            elseif i == 2 then
                render.draw(M_ply.texture.Hair[1],
                    M_ply.position.x + M_ply.hair.Dx + M_ply.hair["v" .. i].x - 5.5*0.95,
                    M_ply.position.y + M_ply.hair.Dy + M_ply.hair["v" .. i].y + 5.5*0.95,
                    0,
                    0.95,
                    0.95
                )
            elseif i == 3 then
                render.draw(M_ply.texture.Hair[1],
                    M_ply.position.x + M_ply.hair.Dx + M_ply.hair["v" .. i].x - 11*0.90/2,
                    M_ply.position.y + M_ply.hair.Dy + M_ply.hair["v" .. i].y + 11*0.90/2,
                    0,
                    0.90,
                    0.90
                )
            elseif i == 4 then
                render.draw(M_ply.texture.Hair[1],
                    M_ply.position.x + M_ply.hair.Dx + M_ply.hair["v" .. i].x - 11*0.85/2,
                    M_ply.position.y + M_ply.hair.Dy + M_ply.hair["v" .. i].y + 11*0.85/2,
                    0,
                    0.85,
                    0.85
                )
            elseif i == 5 then
                render.draw(M_ply.texture.Hair[1],
                    M_ply.position.x + M_ply.hair.Dx + M_ply.hair["v" .. i].x - 11*0.75/2,
                    M_ply.position.y + M_ply.hair.Dy + M_ply.hair["v" .. i].y + 11*0.75/2,
                    0,
                    0.75,
                    0.75
                )
            elseif i == 6 then
                render.draw(M_ply.texture.Hair[1],
                    M_ply.position.x + M_ply.hair.Dx + M_ply.hair["v" .. i].x - 11*0.55/2,
                    M_ply.position.y + M_ply.hair.Dy + M_ply.hair["v" .. i].y + 11*0.5/2,
                    0,
                    0.55,
                    0.55
                )
            end
        end
    end

    --//画人物
    --体力提示
    if M_ply.state.stamina/M_ply.state.maxStamina < 0.3 then
        love.graphics.setColor(M_col.toRatio(LOW_STAMINA_COLOR.NowColor))
    else
        love.graphics.setColor(1,1,1,1)
    end
    
    render.draw(
        M_ply.nowTexture, 
        M_ply.position.x - M_ply.textureSize.width/2 + M_ply.textureSize.Dx - 2.75,
        M_ply.position.y + M_ply.textureSize.height/2 + M_ply.textureSize.Dy + 1.5,
        0,
        M_ply.textureSize.width/9,
        M_ply.textureSize.height/17
    )
    love.graphics.setShader()
end

--//key_obj小动画更新
function render.objAnimationUpdater(dt)
    for i,v in pairs(key_texture) do
        if v.timer - dt <= 0 then
            v.timer = v.setTime
            if v.num >= #v then
                v.num = 1
            else
                v.num = v.num + 1
            end
        else
            v.timer = v.timer - dt
        end
    end
end

--//视差背景
--//小 = 远
local function layerDraw(Camera,Img,Dis,W,H,S)
    local OffsetX,OffsetY
    OffsetX,OffsetY = Camera.showPosition.x * Dis ,Camera.showPosition.y * Dis
    render.draw(Img,
    -(W*S)/2 -OffsetX,
    (H*S)/2 -OffsetY,
    0,
    S,S)
end
function render.drawBackground(Camera,WINDOW_INFO)
    love.graphics.setColor(1,1,1,1)
    love.graphics.setShader()
    if background.sky then
        layerDraw(Camera,background.sky,background.skyDis,background.skyW,background.skyH,background.skyS)
    end
    if background.mount then
        layerDraw(Camera,background.mount,background.mountDis,background.mountW,background.mountH,background.mountS)
    end
    if background.tree1 then
        layerDraw(Camera,background.tree1,background.tree1Dis,background.tree1W,background.tree1H,background.tree1S)
    end
    if background.tree2 then
        layerDraw(Camera,background.tree2,background.tree2Dis,background.tree2W,background.tree2H,background.tree2S)
    end
end

--//降落物效果
local snowflake = {}
render.snowfalkeSetTime = 0.05
render.snowflakeTimer = 0
render.globalSnowSpeed = 0--加法*时间
function render.snowflakeUpdater(dt,Camera,M_ply)--需要M_ply是因为我要获取GamingTime
    --//计算
    for _ = #snowflake, 1, -1 do
        local v = snowflake[_]

        if _G.IN_GAME_RENDER then
            if v.mode == 1 then
                if v.position.y > Camera.cornerP1.y + v.radius then
                    table.remove(snowflake,_)
                else
                    v.position.x = v.sx + math.sin(M_ply.GamingTime*v.waveSpeed)*v.waveSize
                    v.position.y = v.position.y + Camera.LimitH/v.time*dt + render.globalSnowSpeed*dt
                end
            elseif v.mode == 2 then
                if v.position.x < Camera.cornerP1.x - v.radius then
                    table.remove(snowflake,_)
                else
                    v.position.x = v.position.x - Camera.LimitW/v.time*dt + render.globalSnowSpeed*dt
                    v.position.y = v.sy + math.sin(M_ply.GamingTime*v.waveSpeed)*v.waveSize
                end
            elseif v.mode == 3 then
                if v.position.y < Camera.cornerP2.y - v.radius then
                    table.remove(snowflake,_)
                else
                    v.position.x = v.sx + math.sin(M_ply.GamingTime*v.waveSpeed)*v.waveSize
                    v.position.y = v.position.y - Camera.LimitH/v.time*dt + render.globalSnowSpeed*dt
                end
            elseif v.mode == 4 then
                if v.position.x > Camera.cornerP2.x + v.radius then
                    table.remove(snowflake,_)
                else
                    v.position.x = v.position.x + Camera.LimitW/v.time*dt + render.globalSnowSpeed*dt
                    v.position.y = v.sy + math.sin(M_ply.GamingTime*v.waveSpeed)*v.waveSize
                end
            elseif v.mode == 5 then
                if v.position.y < Camera.cornerP2.y - v.radius then
                    table.remove(snowflake,_)
                else
                    v.position.x = v.sx + math.sin(M_ply.GamingTime*v.waveSpeed)*v.waveSize
                    v.position.y = v.position.y - Camera.LimitH/v.time*dt + render.globalSnowSpeed*dt
                end
            else
                table.remove(snowflake,_)
            end
        else
            table.remove(snowflake,_)
        end

    end
end
function render.snowflakeDraw()
    for _ = #snowflake, 1, -1 do
        local v = snowflake[_]
        love.graphics.setColor(
            render.maps.snowR,
            render.maps.snowG,
            render.maps.snowB,
            v.alpha
        )
        render.rectangle("fill",math.floor(v.position.x),math.floor(v.position.y),v.radius,v.radius)
    end
end
function render.snowflakeAdder(mode,Camera)--交由main.lua写入
    local L = {
        position = M_vec.vec2(0,0),
        alpha = 1,
        mode = 0,
        radius = 1,
        waveSize = 2,
        waveSpeed = 0.2,
        time = 4,
        sx = 0,sy = 0
    }

    L.alpha = math.random(4,10)/10
    L.radius = math.random(10,20)/10
    L.waveSize = math.random(20,60)
    L.waveSpeed = math.random(2,8)/10
    L.time = math.random(3,6)

    if mode == 1 then
        L.position.x = Camera.cornerP1.x + math.random(0,Camera.LimitW)
        L.position.y = Camera.cornerP2.y - L.radius
        L.mode = mode
    elseif mode == 2 then
        L.position.x = Camera.cornerP2.x + L.radius
        L.position.y = Camera.cornerP2.y + math.random(0,Camera.LimitH)
        L.mode = mode
    elseif mode == 3 then
        L.position.x = Camera.cornerP1.x + math.random(0,Camera.LimitW)
        L.position.y = Camera.cornerP1.y + L.radius
        L.mode = mode
    elseif mode == 4 then
        L.position.x = Camera.cornerP1.x - L.radius
        L.position.y = Camera.cornerP2.y + math.random(0,Camera.LimitH)
        L.mode = mode
    elseif mode == 5 then
        L.position.x = Camera.cornerP1.x + math.random(0,Camera.LimitW)
        L.position.y = Camera.cornerP1.y + L.radius
        L.mode = mode
    else
        L.position.x = Camera.cornerP1.x + math.random(0,Camera.LimitW)
        L.position.y = Camera.cornerP2.y - L.radius
        L.mode = 1
    end
    L.sx,L.sy = L.position.x,L.position.y

    table.insert(snowflake,L)
end
function render.snowflakeAuto(dt,Camera)
    if render.snowStyle_valid[render.maps.snowStyle] and render.maps.snowStyle ~= 0 then
        if render.snowflakeTimer - dt <= 0 then
            render.snowflakeTimer = render.snowfalkeSetTime
            render.snowflakeAdder(render.maps.snowStyle,Camera)
        else
            render.snowflakeTimer = render.snowflakeTimer - dt
        end
    end
    return #snowflake
end

return render
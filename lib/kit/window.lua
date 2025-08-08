
local dbg = require("lib.kit.debug") or {print = function() end,warn = function() end,error = function() end}

function transRGB (cRGB)
    return cRGB.R/255,cRGB.G/255,cRGB.B/255,cRGB.alpha or 1
end
function loveSetColorRGB (cRGB,alpha)
    love.graphics.setColor(cRGB.R/255,cRGB.G/255,cRGB.B/255,alpha or 1)
end

local win = {}
--规定尺寸16:9
win.GAME_FILLMODE = ""
win.GAME_WIDTH = 1600--1280--40*8--320 * 4
win.GAME_HEIGHT = 900--720--22.5*8--180 * 4
win.GAME_BACKGROUND_COLOR = {R = 50, G = 50, B = 50}
win.GAME_FILLING_COLOR = {R = 0, G = 0, B = 0}

win.scale,win.offsetX,win.offsetY = 0,0,0

function win.updateScale()
    local windowW, windowH = love.graphics.getDimensions()
    local scaleX = windowW / win.GAME_WIDTH
    local scaleY = windowH / win.GAME_HEIGHT
    win.scale = math.min(scaleX, scaleY)

    win.offsetX = (windowW - win.GAME_WIDTH * win.scale) / 2
    win.offsetY = (windowH - win.GAME_HEIGHT * win.scale) / 2
end

function win.createCanvas(W,H,N)
    local canvas = love.graphics.newCanvas(win.GAME_WIDTH, win.GAME_HEIGHT)
    if W and H then
        canvas = love.graphics.newCanvas(W, H)
    else
        canvas = love.graphics.newCanvas(win.GAME_WIDTH, win.GAME_HEIGHT)
    end
    if N ~= false then
        canvas:setFilter("nearest", "nearest")
    end
    return canvas
end

function win.setCanvas(GAME_CANVAS)
    love.graphics.setCanvas(GAME_CANVAS)
    love.graphics.clear(transRGB(win.GAME_BACKGROUND_COLOR))
end

function win.endCanvas(GAME_CANVAS)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setCanvas()
    love.graphics.clear(transRGB(win.GAME_FILLING_COLOR))
    love.graphics.draw(GAME_CANVAS, win.offsetX, win.offsetY, 0, win.scale, win.scale)
end

function win.shaderHandler(canvasTemp)
    love.graphics.setColor(1, 1, 1)
    love.graphics.clear(transRGB(win.GAME_FILLING_COLOR))
    love.graphics.draw(canvasTemp, win.offsetX, win.offsetY, 0, win.scale, win.scale)
end

function win.toCanvasPosition(position, Camera)
    local dx = position.x - Camera.showPosition.x
    local dy = position.y - Camera.showPosition.y

    local cR = math.cos(-Camera.showRotation)
    local sR = math.sin(-Camera.showRotation)

    local rx = dx * cR - dy * sR
    local ry = dx * sR + dy * cR

    local sx = rx * Camera.showScale
    local sy = ry * Camera.showScale

    local centerX = (win.GAME_WIDTH / 2) + sx
    local centerY = (win.GAME_HEIGHT / 2) - sy

    return centerX, centerY
end

return win
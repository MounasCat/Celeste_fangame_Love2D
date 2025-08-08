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

local M_vec = require("lib.kit.vector")
local M_col = require("lib.kit.color")
local M_win = require("lib.kit.window")

local text = require("text")

local render = require("render")

local sound = {
    mainMenu = love.audio.newSource("audio/UI/ui_main_title_firstinput.wav","static"),

    rollUp = love.audio.newSource("audio/UI/ui_main_roll_up.wav","static"),
    rollDown = love.audio.newSource("audio/UI/ui_main_roll_down.wav","static"),

    rollleft = love.audio.newSource("audio/UI/ui_main_button_toggle_off.wav","static"),
    rollright = love.audio.newSource("audio/UI/ui_main_button_toggle_on.wav","static"),

    paused = love.audio.newSource("audio/UI/ui_game_pause.wav","static"),
    unpaused = love.audio.newSource("audio/UI/ui_game_unpause.wav","static"),
    back = love.audio.newSource("audio/UI/ui_main_button_back.wav","static"),
    select = love.audio.newSource("audio/UI/ui_main_button_select.wav","static"),

    backToMainMenu = love.audio.newSource("audio/UI/ui_main_savefile_begin.wav","static"),

    chooseMap = love.audio.newSource("audio/UI/ui_main_button_climb.wav","static"),
}
for i,v in pairs(sound) do
    v:setVolume(0.5)
end

local music = {
    menu = love.audio.newSource("audio/music/Postcard from Celeste Mountain - Lena Raine.flac","stream"),
}
for i,v in pairs(music) do
    v:setLooping(true)
    v:setVolume(1.5)
end

--//声音播放机
local function soundPlay(s,p)
    p = p or 0
    s = s or sound.defalut[math.random(1,#sound.defalut)]
    s:stop(); s:seek(p); s:play()
end


local function smoothStep(x)
    -- 保证输入在 [0, 1]
    x = math.max(0, math.min(1, x))
    return x * x * (3 - 2 * x)
end
local function bounce(x)
    x = x or 0
    return -math.sin((x + 0.1)*1.666666667*math.pi) + 0.5
end

UI = {
    IN_GAME = {
        IS_ON = false,
        IS_ON_MENU = false,
        MENU_SET = {},
    },
    OUT_GAME = {
        IS_ON = false,
        MENU_SET = {},
        MAP_SET = {},
    },
}

UI.CAN_OPERATION = true

local fontSize = {
    ["default"] = 15,

    ["warn"] = 30,

    ["title0"] = 70,
    ["title1"] = 70,
    ["select0"] = 40,
    ["select1"] = 40,
    ["tip0"] = 20,
    ["tip1"] = 20,
}

local DEFAULT_FONTSET

local WARN_FONTSET

local TITLE_FONTSET_0
local TITLE_FONTSET_1
local SELECT_FONTSET_0
local SELECT_FONTSET_1
local TIP_FONTSET_0
local TIP_FONTSET_1

local IN_GAME,OUT_GAME = UI.IN_GAME,UI.OUT_GAME

UI.IN_GAME_MENU_INDEX = 1
UI.IN_GAME_MENU_FRAME = 0--0为初始画面，1为选项画面
UI.IN_GAME.MENU_SET = {
    [0] = {
        ["Title"] = {
            IsTitle = true,
            msg = text[text.Language].IN_GAME_MENU["PAUSED"],
        },
        [1] = {
            msg = text[text.Language].IN_GAME_MENU["Resume"],
            func = function () end,
        },
        [2] = {
            msg = text[text.Language].IN_GAME_MENU["Retry"],
            func = function () end,
        },
        [3] = {
            msg = text[text.Language].IN_GAME_MENU["Restar"],
            func = function () end,
        },
        [4] = {
            msg = text[text.Language].IN_GAME_MENU["Options"],
            func = function () end,
        },
        [5] = {
            msg = text[text.Language].IN_GAME_MENU["Back to select"],
            func = function () end,
        },
    },
    [1] = {
        ["Title"] = {
            IsTitle = true,
            msg = text[text.Language].IN_GAME_MENU["OPTIONS"],
        },
        [1] = {
            msg = text[text.Language].IN_GAME_MENU["Language"] .. ": " .. text.Language,
            func = function() end,
        },
        [2] = {
            msg = text[text.Language].IN_GAME_MENU["Back"],
            func = function() end,
        },
    }
}

UI.OUT_GAME_INDEX = 1
UI.OUT_GAME_FRAME = 0--0为主菜单画面，1为选图画面，2为选项画面
UI.OUT_MAP_INDEX = 1
UI.OUT_GAME.MAP_SET = {
    [1] = {
        name = "gametest",
        image = "",
        path = "",
        passed = false,
        deadTimes = 0,

    },
    [2] = {
        name = "forest",
        image = "",
        path = "",
        passed = false,
        deadTimes = 0,

    }
}
UI.OUT_GAME.MENU_SET = {
    [0] = {
        ["Title"] = {
            IsTitle = true,
            msg = text[text.Language].OUT_GAME_MENU["MAIN MENU"],
        },
        [1] = {
            msg = text[text.Language].OUT_GAME_MENU["Start"],
            func = function () end,
        },
        [2] = {
            msg = text[text.Language].OUT_GAME_MENU["Options"],
            func = function () end,
        },
        [3] = {
            msg = text[text.Language].OUT_GAME_MENU["Quit"],
            func = function () end,
        },
    },
    [1] = {
        ["Title"] = {
            IsTitle = true,
            msg = text[text.Language].IN_GAME_MENU["MAP CHOOSE"],
        },

        [1] = {
            msg = "< [" .. UI.OUT_GAME.MAP_SET[UI.OUT_MAP_INDEX].name .. "] >",
            func = function() end,
        },
        [2] = {
            msg = text[text.Language].IN_GAME_MENU["Back"],
            func = function() end,
        },
    },
    [2] = {
        ["Title"] = {
            IsTitle = true,
            msg = text[text.Language].IN_GAME_MENU["OPTIONS"],
        },
        [1] = {
            msg = text[text.Language].IN_GAME_MENU["Language"] .. ": " .. text.Language,
            func = function() end,
        },
        [2] = {
            msg = text[text.Language].IN_GAME_MENU["Back"],
            func = function() end,
        },
    }
}

--//第一次进入游戏的提示警告
UI.FIRST_JOIN_SETTIME = 5
UI.FIRST_JOIN_TIMER = UI.FIRST_JOIN_SETTIME
UI.FIRST_JOIN = true
--//选择地图后的停滞时间
UI.MAP_CHOOSE_SETTIME = 2
UI.MAP_CHOOSE_TIMER = 0
UI.MAP_CHOOSE_CONFIRM = false
--//从游戏中回到主菜单过场时间
UI.BACK_MAINMENU_SETTIME = 2
UI.BACK_MAINMENU_TIMER = 0
UI.BACK_MAINMENU_CONFIRM = false

--//选择后的回弹效果
UI.BOUNCE_SELECTE_SETTIME = 0.2
UI.BOUNCE_SELECTE_TIMER = 0
--//进入后的回弹效果
UI.BOUNCE_ENTER_SETTIME = 0.1
UI.BOUNCE_ENTER_TIMER = 0
--//地图选择的回弹效果
UI.BOUNCE_MAP_SETTIME = 0.2
UI.BOUNCE_MAP_TIMER = 0
UI.BOUNCE_MAP_DIRECTION = 1--1:right,-1:left
--//进入主菜单的效果
UI.MAIN_MENU_SETTIME = 1.6
UI.MAIN_MENU_TIMER = 0

--//雪花添加时间设置
UI.MAIN_MENU_SNOW_SETTIME = 0.1
UI.MAIN_MENU_SNOW_TIMER = 0

UI.snowflake = {}
function UI.snowflakeUpdater(WINDOW_INFO,dt)
    for _ = #UI.snowflake, 1, -1 do
        local v = UI.snowflake[_]

        if OUT_GAME.IS_ON then
            if v.faceSide == "right" then
                if v.position.x > WINDOW_INFO.Width + v.radius then
                    table.remove(UI.snowflake,_)
                else
                    v.position.x = v.position.x + WINDOW_INFO.Width/v.time*dt + UI.MAIN_MENU_TIMER*WINDOW_INFO.Width*dt
                    v.position.y = v.sy + math.sin(love.timer:getTime()*v.waveSpeed)*v.waveSize
                end
            elseif v.faceSide == "left" then
                if v.position.x < -v.radius then
                    table.remove(UI.snowflake,_)
                else
                    v.position.x = v.position.x - WINDOW_INFO.Width/v.time*dt - UI.MAIN_MENU_TIMER*WINDOW_INFO.Width*dt
                    v.position.y = v.sy + math.sin(love.timer:getTime()*v.waveSpeed)*v.waveSize
                end
            elseif v.faceSide == "down" then
                if v.position.y > WINDOW_INFO.Height + v.radius then
                    table.remove(UI.snowflake,_)
                else
                    v.position.y = v.position.y + WINDOW_INFO.Height/v.time*dt + UI.MAIN_MENU_TIMER*WINDOW_INFO.Width*dt
                    v.position.x = v.sx + math.sin(love.timer:getTime()*v.waveSpeed)*v.waveSize
                end
            elseif v.faceSide == "up" then
                if v.position.y < -v.radius then
                    table.remove(UI.snowflake,_)
                else
                    v.position.y = v.position.y - WINDOW_INFO.Height/v.time*dt - UI.MAIN_MENU_TIMER*WINDOW_INFO.Width*dt
                    v.position.x = v.sx + math.sin(love.timer:getTime()*v.waveSpeed)*v.waveSize
                end
            else
                table.remove(UI.snowflake,_)
            end
        else
            table.remove(UI.snowflake,_)
        end
    end
end
function UI.snowflakeAdder(WINDOW_INFO,direction)--0:up,1:left,2:down,3:right
    local L = {
        position = M_vec.vec2(0,0),
        alpha = 1,
        faceSide = "right",
        radius = 5,
        waveSize = 2,
        waveSpeed = 0.2,
        time = 4,
        sx = 0,sy = 0
    }

    L.alpha = math.random(4,10)/10
    L.radius = math.random(3,8)
    L.waveSize = math.random(20,60)
    L.waveSpeed = math.random(2,8)/10
    L.time = math.random(3,6)

    if direction == 0 then
        L.faceSide = "up"
        L.position.x = math.random(0,WINDOW_INFO.Width)
        L.position.y = WINDOW_INFO.Height + L.radius
    elseif direction == 1 then
        L.faceSide = "left"
        L.position.x = WINDOW_INFO.Width + L.radius
        L.position.y = math.random(0,WINDOW_INFO.Height)
    elseif direction == 2 then
        L.faceSide = "down"
        L.position.x = math.random(0,WINDOW_INFO.Width)
        L.position.y = -L.radius
    elseif direction == 3 then
        L.faceSide = "right"
        L.position.x = -L.radius
        L.position.y = math.random(0,WINDOW_INFO.Height)
    else
        L.faceSide = "up"
        L.position.x = math.random(0,WINDOW_INFO.Width)
        L.position.y = WINDOW_INFO.Height + L.radius
    end
    L.sx,L.sy = L.position.x,L.position.y

    table.insert(UI.snowflake,L)
end
function UI.snowDraw()
    for _ = #UI.snowflake, 1, -1 do
        local v = UI.snowflake[_]
        love.graphics.setColor(1,1,1,v.alpha)
        love.graphics.circle("fill",v.position.x,v.position.y,v.radius)
    end
end

function UI.languageUpdater ()
    --//加载字体
    if text.Font[text.Language] == "" then
        DEFAULT_FONTSET = love.graphics.newFont(fontSize.default)

        WARN_FONTSET = love.graphics.newFont(fontSize.warn)

        TITLE_FONTSET_0 = love.graphics.newFont(fontSize.title0); TITLE_FONTSET_1 = love.graphics.newFont(fontSize.title1)
        SELECT_FONTSET_0 = love.graphics.newFont(fontSize.select0);SELECT_FONTSET_1 = love.graphics.newFont(fontSize.select1)
        TIP_FONTSET_0 = love.graphics.newFont(fontSize.tip0); TIP_FONTSET_1 = love.graphics.newFont(fontSize.tip1)
    else
        DEFAULT_FONTSET = love.graphics.newFont(text.Font[text.Language],fontSize.default)

        WARN_FONTSET = love.graphics.newFont(text.Font[text.Language],fontSize.warn)

        TITLE_FONTSET_0 = love.graphics.newFont(text.Font[text.Language],fontSize.title0); TITLE_FONTSET_1 = love.graphics.newFont(text.Font[text.Language],fontSize.title1)
        SELECT_FONTSET_0 = love.graphics.newFont(text.Font[text.Language],fontSize.select0); SELECT_FONTSET_1 = love.graphics.newFont(text.Font[text.Language],fontSize.select1)
        TIP_FONTSET_0 = love.graphics.newFont(text.Font[text.Language],fontSize.tip0); TIP_FONTSET_1 = love.graphics.newFont(text.Font[text.Language],fontSize.tip1);
    end
    --//暂停菜单页面
    UI.IN_GAME.MENU_SET[0]["Title"].msg = text[text.Language].IN_GAME_MENU["PAUSED"]
    UI.IN_GAME.MENU_SET[0][1].msg = text[text.Language].IN_GAME_MENU["Resume"]
    UI.IN_GAME.MENU_SET[0][2].msg = text[text.Language].IN_GAME_MENU["Retry"]
    UI.IN_GAME.MENU_SET[0][3].msg = text[text.Language].IN_GAME_MENU["Restar"]
    UI.IN_GAME.MENU_SET[0][4].msg = text[text.Language].IN_GAME_MENU["Options"]
    UI.IN_GAME.MENU_SET[0][5].msg = text[text.Language].IN_GAME_MENU["Back to select"]
    --//选项页面(游戏内)
    UI.IN_GAME.MENU_SET[1]["Title"].msg = text[text.Language].IN_GAME_MENU["OPTIONS"]
    UI.IN_GAME.MENU_SET[1][1].msg = text[text.Language].IN_GAME_MENU["Language"] .. ": " .. text.Language
    UI.IN_GAME.MENU_SET[1][2].msg = text[text.Language].IN_GAME_MENU["Back"]
    --//主菜单页面
    UI.OUT_GAME.MENU_SET[0]["Title"].msg = text[text.Language].OUT_GAME_MENU["MAIN MENU"]
    UI.OUT_GAME.MENU_SET[0][1].msg = text[text.Language].OUT_GAME_MENU["Start"]
    UI.OUT_GAME.MENU_SET[0][2].msg = text[text.Language].OUT_GAME_MENU["Options"]
    UI.OUT_GAME.MENU_SET[0][3].msg = text[text.Language].OUT_GAME_MENU["Quit"]
    --//选图页面
    UI.OUT_GAME.MENU_SET[1]["Title"].msg = text[text.Language].OUT_GAME_MENU["MAP CHOOSE"]
    UI.OUT_GAME.MENU_SET[1][2].msg = text[text.Language].IN_GAME_MENU["Back"]
    --//选项页面(游戏外)
    UI.OUT_GAME.MENU_SET[2]["Title"].msg = text[text.Language].IN_GAME_MENU["OPTIONS"]
    UI.OUT_GAME.MENU_SET[2][1].msg = text[text.Language].IN_GAME_MENU["Language"] .. ": " .. text.Language
    UI.OUT_GAME.MENU_SET[2][2].msg = text[text.Language].IN_GAME_MENU["Back"]
end;UI.languageUpdater()

UI.backToMAIN_MENU = function() end--预声明

function UI.timeUpdater(dt,WINDOW_INFO)--main.lua
    --第一次进入游戏的提示
    if UI.FIRST_JOIN_TIMER > 0 then
        if UI.FIRST_JOIN_TIMER - dt <=0 then
            UI.FIRST_JOIN_TIMER = 0
        else
            UI.FIRST_JOIN_TIMER = UI.FIRST_JOIN_TIMER - dt
        end
    end
    --选择时的回弹效果
    if UI.BOUNCE_SELECTE_TIMER - dt <=0 then
        UI.BOUNCE_SELECTE_TIMER = 0
    else
        UI.BOUNCE_SELECTE_TIMER = UI.BOUNCE_SELECTE_TIMER - dt
    end
    --地图选择的回弹效果
    if UI.BOUNCE_MAP_TIMER - dt <=0 then
        UI.BOUNCE_MAP_TIMER = 0
    else
        UI.BOUNCE_MAP_TIMER = UI.BOUNCE_MAP_TIMER - dt
    end
    --进入时的回弹效果
    if UI.BOUNCE_ENTER_TIMER - dt <= 0 then
        UI.BOUNCE_ENTER_TIMER = 0
    else
        UI.BOUNCE_ENTER_TIMER = UI.BOUNCE_ENTER_TIMER - dt
    end
    --进入主菜单效果
    if UI.MAIN_MENU_TIMER - dt <= 0 then
        UI.MAIN_MENU_TIMER = 0
    else
        UI.MAIN_MENU_TIMER = UI.MAIN_MENU_TIMER - dt
    end
    --主菜单雪花更新
    if OUT_GAME.IS_ON then
        if UI.MAIN_MENU_SNOW_TIMER - dt <= 0 then
            UI.MAIN_MENU_SNOW_TIMER = UI.MAIN_MENU_SNOW_SETTIME
            UI.snowflakeAdder(WINDOW_INFO,1)
        else
            UI.MAIN_MENU_SNOW_TIMER = UI.MAIN_MENU_SNOW_TIMER - dt
        end
    end
    --选择地图过场
    if UI.MAP_CHOOSE_TIMER - dt <= 0 then
        UI.MAP_CHOOSE_TIMER = 0
    else
        UI.MAP_CHOOSE_TIMER = UI.MAP_CHOOSE_TIMER - dt
    end
    --返回主菜单过程（带打开）
    if UI.BACK_MAINMENU_CONFIRM then
        if UI.BACK_MAINMENU_TIMER - dt <= 0 then
            UI.BACK_MAINMENU_TIMER = 0
            UI.BACK_MAINMENU_CONFIRM = false
            UI.backToMAIN_MENU(M_ply)
        else
            UI.BACK_MAINMENU_TIMER = UI.BACK_MAINMENU_TIMER - dt
        end
    end
end

local TIP_COLOR = M_col.AddNormalLines({
    Repeat = true,
    SetColor = {R = 255,G = 255, B = 102},
    TargetColor = {R =178,G = 255, B = 102},
    SetTime = 0.1
})--.NowColor

function UI.openMENU(M_ply)
    if IN_GAME.IS_ON then
        UI.IN_GAME_MENU_INDEX = 1
        UI.IN_GAME_MENU_FRAME = 0
        IN_GAME.IS_ON_MENU = true
        UI.BOUNCE_ENTER_TIMER = UI.BOUNCE_ENTER_SETTIME
        UI.BOUNCE_SELECTE_TIMER = UI.BOUNCE_SELECTE_SETTIME
        soundPlay(sound.paused)
        if M_ply then
            M_ply.ISGAMING = false
        end
    end
end
function UI.closeMENU(M_ply)
    if IN_GAME.IS_ON then
        UI.IN_GAME_MENU_INDEX = 1
        UI.IN_GAME_MENU_FRAME = 0
        IN_GAME.IS_ON_MENU = false
        soundPlay(sound.unpaused)

        if M_ply then
            M_ply.ISGAMING = true
        end
    end
end
function UI.operationMENU(operation,M_ply)
    if UI.CAN_OPERATION then
        if operation == "up" then
            if UI.IN_GAME.IS_ON_MENU then
                UI.IN_GAME_MENU_INDEX = math.max(1,math.min(UI.IN_GAME_MENU_INDEX - 1,#UI.IN_GAME.MENU_SET[UI.IN_GAME_MENU_FRAME]))
            elseif UI.OUT_GAME.IS_ON then
                UI.OUT_GAME_INDEX = math.max(1,math.min(UI.OUT_GAME_INDEX - 1,#UI.OUT_GAME.MENU_SET[UI.OUT_GAME_FRAME]))
            end
            UI.BOUNCE_SELECTE_TIMER = UI.BOUNCE_SELECTE_SETTIME
            soundPlay(sound.rollUp,0)
        elseif operation == "down" then
            if UI.IN_GAME.IS_ON_MENU then
                UI.IN_GAME_MENU_INDEX = math.max(1,math.min(UI.IN_GAME_MENU_INDEX + 1,#UI.IN_GAME.MENU_SET[UI.IN_GAME_MENU_FRAME]))
            else
                UI.OUT_GAME_INDEX = math.max(1,math.min(UI.OUT_GAME_INDEX + 1,#UI.OUT_GAME.MENU_SET[UI.OUT_GAME_FRAME]))
            end
            UI.BOUNCE_SELECTE_TIMER = UI.BOUNCE_SELECTE_SETTIME
            soundPlay(sound.rollDown,0)
        elseif operation == "confirm" then
            if UI.IN_GAME.IS_ON_MENU then
                UI.IN_GAME.MENU_SET[UI.IN_GAME_MENU_FRAME][UI.IN_GAME_MENU_INDEX].func(M_ply)
            else
                if UI.OUT_GAME_INDEX == 1 and UI.OUT_GAME_FRAME == 1 then--//确认地图
                    UI.CAN_OPERATION = false
                    UI.MAP_CHOOSE_TIMER = UI.MAP_CHOOSE_SETTIME
                    UI.MAP_CHOOSE_CONFIRM = true
                    soundPlay(sound.chooseMap)
                    music.menu:stop()
                    --接下来交给main.lua
                else
                    UI.OUT_GAME.MENU_SET[UI.OUT_GAME_FRAME][UI.OUT_GAME_INDEX].func(M_ply)
                end
            end
            UI.BOUNCE_ENTER_TIMER = UI.BOUNCE_ENTER_SETTIME
            soundPlay(sound.select)
        elseif operation == "left" then
            if UI.OUT_GAME_FRAME == 1 and UI.OUT_GAME_INDEX == 1 then--规定的位置
                UI.OUT_MAP_INDEX = math.max(1,math.min(UI.OUT_MAP_INDEX - 1,#UI.OUT_GAME.MAP_SET))
                UI.OUT_GAME.MENU_SET[1][1].msg = "< [" .. UI.OUT_GAME.MAP_SET[UI.OUT_MAP_INDEX].name .. "] >"
                soundPlay(sound.rollleft)
                UI.BOUNCE_MAP_TIMER = UI.BOUNCE_MAP_SETTIME
                UI.BOUNCE_MAP_DIRECTION = -1
            end
        elseif operation == "right" then
            if UI.OUT_GAME_FRAME == 1 and UI.OUT_GAME_INDEX == 1 then--规定的位置
                UI.OUT_MAP_INDEX = math.max(1,math.min(UI.OUT_MAP_INDEX + 1,#UI.OUT_GAME.MAP_SET))
                UI.OUT_GAME.MENU_SET[1][1].msg = "< [" .. UI.OUT_GAME.MAP_SET[UI.OUT_MAP_INDEX].name .. "] >"
                soundPlay(sound.rollright)
                UI.BOUNCE_MAP_TIMER = UI.BOUNCE_MAP_SETTIME
                UI.BOUNCE_MAP_DIRECTION = 1
            end
        end
    end
end

function UI.backToMAIN_MENU(M_ply)
    UI.OUT_GAME_INDEX = 1
    UI.OUT_GAME_FRAME = 0
    UI.OUT_MAP_INDEX = 1

    UI.MAIN_MENU_TIMER = UI.MAIN_MENU_SETTIME
    UI.BOUNCE_ENTER_TIMER = UI.BOUNCE_ENTER_SETTIME
    UI.BOUNCE_SELECTE_TIMER = UI.BOUNCE_SELECTE_SETTIME

    _G.IN_GAME_RENDER = false
    OUT_GAME.IS_ON = true
    IN_GAME.IS_ON = false
    IN_GAME.IS_ON_MENU = false
    UI.CAN_OPERATION = true
    M_ply.ISGAMING = false

    --UI.snowClear()
    soundPlay(sound.mainMenu)
    soundPlay(music.menu)
end

local tempLength,tempHeight = 0,0
local function putText(text,R,G,B,a,Font1,Font2,x,y)
    text = text or "nil"
    R,G,B,a = R or 1, G or 1, B or 1, a or 1
    Font1,Font2 = Font1 or DEFAULT_FONTSET,Font2 or DEFAULT_FONTSET
    x,y = x or 0,y or 0

    --黑色描边
    love.graphics.setColor(0.1,0.1,0.1,a)
    love.graphics.setFont(Font1)
    tempLength = Font1:getWidth(text)
    tempHeight = Font1:getHeight(text)
    love.graphics.print(text,x - tempLength/2,y - tempHeight/2 + 5)
    --显示文本
    love.graphics.setColor(R,G,B,a)
    love.graphics.setFont(Font2)
    tempLength = Font2:getWidth(text)
    tempHeight = Font2:getHeight(text)
    love.graphics.print(text,x - tempLength/2,y - tempHeight/2)
end

function UI.firstJoin(WINDOW_INFO,M_ply)
    if UI.FIRST_JOIN_TIMER > 0 then
        local PG = 1 - UI.FIRST_JOIN_TIMER/UI.FIRST_JOIN_SETTIME
        local warnH = WARN_FONTSET:getHeight("TEXT") + 5
        local allHeight = warnH*#text[text.Language].FirstJoin
        if PG < 0.2 then
            for i,v in pairs(text[text.Language].FirstJoin) do
                putText(v,1,1,1,PG/0.2,WARN_FONTSET,WARN_FONTSET,
                    WINDOW_INFO.Width/2, WINDOW_INFO.Height/2 - allHeight/2 + (i-1)*warnH + warnH/2
                )
            end
        elseif PG < 0.8 then
            for i,v in pairs(text[text.Language].FirstJoin) do
                putText(v,1,1,1,1,WARN_FONTSET,WARN_FONTSET,
                    WINDOW_INFO.Width/2, WINDOW_INFO.Height/2 - allHeight/2 + (i-1)*warnH + warnH/2
                )
            end
        else
            for i,v in pairs(text[text.Language].FirstJoin) do
                putText(v,1,1,1,(1 - PG)/0.2,WARN_FONTSET,WARN_FONTSET,
                    WINDOW_INFO.Width/2, WINDOW_INFO.Height/2 - allHeight/2 + (i-1)*warnH + warnH/2
                )
            end
        end
    else
        if UI.FIRST_JOIN then--初始化界面
            UI.FIRST_JOIN = false
            UI.backToMAIN_MENU(M_ply)
        end
    end
end
function UI.drawIN_GAME(WINDOW_INFO)
    if IN_GAME.IS_ON then
        --//游戏暂停菜单
        if IN_GAME.IS_ON_MENU then
            --黑色蒙版
            love.graphics.setColor(0,0,0,0.6)
            love.graphics.rectangle("fill",0,0,WINDOW_INFO.Width,WINDOW_INFO.Height)
            --选择
            local selectH = SELECT_FONTSET_0:getHeight("TEXT") + 2
            local titleH = TITLE_FONTSET_0:getHeight("TEXT")
            local allHeight = selectH*#UI.IN_GAME.MENU_SET[UI.IN_GAME_MENU_FRAME] - selectH - 60 - smoothStep(UI.BOUNCE_ENTER_TIMER/UI.BOUNCE_ENTER_SETTIME)*40
            for i,v in pairs(UI.IN_GAME.MENU_SET[UI.IN_GAME_MENU_FRAME]) do
                if v.IsTitle then
                    putText(v.msg,0.6,0.6,0.6,1,TITLE_FONTSET_1,TITLE_FONTSET_0,
                        WINDOW_INFO.Width/2, WINDOW_INFO.Height/2 - allHeight/2 - titleH
                    )
                else
                    if i == UI.IN_GAME_MENU_INDEX then
                        local PG = UI.BOUNCE_SELECTE_TIMER / UI.BOUNCE_SELECTE_SETTIME
                        putText(v.msg,
                            TIP_COLOR.NowColor.R*M_col.CONSTENT_RGB,
                            TIP_COLOR.NowColor.G*M_col.CONSTENT_RGB,
                            TIP_COLOR.NowColor.B*M_col.CONSTENT_RGB,1,
                            SELECT_FONTSET_1,SELECT_FONTSET_0,
                            WINDOW_INFO.Width/2, WINDOW_INFO.Height/2 - allHeight/2 + (i-1)*selectH + selectH/2 + smoothStep(PG)*selectH/4
                        )
                    else
                        putText(v.msg,1,1,1,1,SELECT_FONTSET_1,SELECT_FONTSET_0,
                            WINDOW_INFO.Width/2, WINDOW_INFO.Height/2 - allHeight/2 + (i-1)*selectH + selectH/2
                        )
                    end
                end
            end
            --按键提示
            local tipH,tipW = TIP_FONTSET_0:getHeight("TEXT")
            local tip1W = TIP_FONTSET_0:getWidth(text[text.Language].IN_GAME_MENU.TIP1)
            local tip2W = TIP_FONTSET_0:getWidth(text[text.Language].IN_GAME_MENU.TIP2)
            local tip3W = TIP_FONTSET_0:getWidth(text[text.Language].IN_GAME_MENU.TIP3)
            putText(text[text.Language].IN_GAME_MENU.TIP1,
                1,1,1,1,
                TIP_FONTSET_0,TIP_FONTSET_1,
                WINDOW_INFO.Width - tip1W/2,WINDOW_INFO.Height - tipH/2 - tipH*2
            )
            putText(text[text.Language].IN_GAME_MENU.TIP2,
                1,1,1,1,
                TIP_FONTSET_0,TIP_FONTSET_1,
                WINDOW_INFO.Width - tip2W/2,WINDOW_INFO.Height - tipH/2 - tipH
            )
            putText(text[text.Language].IN_GAME_MENU.TIP3,
                1,1,1,1,
                TIP_FONTSET_0,TIP_FONTSET_1,
                WINDOW_INFO.Width - tip3W/2,WINDOW_INFO.Height - tipH/2
            )
        end
        --//返回动画
        if UI.BACK_MAINMENU_CONFIRM then
            love.graphics.setColor(0,0,0,1)
            local num = 12
            local PG = smoothStep(math.max((UI.BACK_MAINMENU_TIMER - UI.BACK_MAINMENU_SETTIME/2)/(UI.BACK_MAINMENU_SETTIME/2),0))
            local W = WINDOW_INFO.Width/(num*2)
            local H = WINDOW_INFO.Height/num*2
            for i = 1,num do
                love.graphics.rectangle("fill",
                W*(i-1),
                WINDOW_INFO.Height*PG + (num - i)*H - (num - i)*H*(1 - PG),
                W,
                WINDOW_INFO.Height*2)
                love.graphics.rectangle("fill",
                WINDOW_INFO.Width - W*i,
                WINDOW_INFO.Height*PG + (num - i)*H - (num - i)*H*(1 - PG),
                W,
                WINDOW_INFO.Height*2)
            end
        end
    end
end
function UI.drawOUT_GAME(WINDOW_INFO)
    if OUT_GAME.IS_ON then
        local PG = smoothStep(UI.MAIN_MENU_TIMER/UI.MAIN_MENU_SETTIME)
        local ratio = 1
        local R_W = WINDOW_INFO.Width
        --//背景
        love.graphics.setColor(0.2,0.2,0.4,1)

        render.shaders.UI_Blur:send("radius", 0.6)
        render.shaders.UI_Blur:send("softness", 0.2)
        render.shaders.UI_Blur:send("screenSize", { WINDOW_INFO.Width, WINDOW_INFO.Height })
        render.shaders.UI_Blur:send("time", love.timer:getTime())

        love.graphics.setShader(render.shaders.UI_Blur)

        love.graphics.circle("fill",
            WINDOW_INFO.Width/2,
            WINDOW_INFO.Height/2,
            R_W*(1-PG)
        )
        love.graphics.setShader()
        --//雪花
        UI.snowDraw()

       --选择
        local selectH = SELECT_FONTSET_0:getHeight("TEXT") + 2
        local titleH = TITLE_FONTSET_0:getHeight("TEXT")
        local allHeight = selectH*#UI.OUT_GAME.MENU_SET[UI.OUT_GAME_FRAME] - selectH - 60 - smoothStep(UI.BOUNCE_ENTER_TIMER/UI.BOUNCE_ENTER_SETTIME)*40
        for i,v in pairs(UI.OUT_GAME.MENU_SET[UI.OUT_GAME_FRAME]) do
            if v.IsTitle then
                putText(v.msg,0.6,0.6,0.6,1 - PG,TITLE_FONTSET_1,TITLE_FONTSET_0,
                    WINDOW_INFO.Width/2, WINDOW_INFO.Height/2 - allHeight/2 - titleH
                )
            else
                if i == UI.OUT_GAME_INDEX then
                    local A_PG = UI.BOUNCE_SELECTE_TIMER / UI.BOUNCE_SELECTE_SETTIME
                    putText(v.msg,
                        TIP_COLOR.NowColor.R*M_col.CONSTENT_RGB,
                        TIP_COLOR.NowColor.G*M_col.CONSTENT_RGB,
                        TIP_COLOR.NowColor.B*M_col.CONSTENT_RGB,1 - PG,
                        SELECT_FONTSET_1,SELECT_FONTSET_0,
                        WINDOW_INFO.Width/2 + smoothStep(UI.BOUNCE_MAP_TIMER/UI.BOUNCE_MAP_SETTIME)*UI.BOUNCE_MAP_DIRECTION*16 , WINDOW_INFO.Height/2 - allHeight/2 + (i-1)*selectH + selectH/2 + smoothStep(A_PG)*selectH/4
                    )
                else
                    putText(v.msg,1,1,1,1 - PG,SELECT_FONTSET_1,SELECT_FONTSET_0,
                        WINDOW_INFO.Width/2, WINDOW_INFO.Height/2 - allHeight/2 + (i-1)*selectH + selectH/2
                    )
                end
            end
        end

        --//按键提示
        if UI.OUT_GAME_FRAME ~= 1 then
            local tipH,tipW = TIP_FONTSET_0:getHeight("TEXT")
            local tip1W = TIP_FONTSET_0:getWidth(text[text.Language].IN_GAME_MENU.TIP1)
            local tip2W = TIP_FONTSET_0:getWidth(text[text.Language].IN_GAME_MENU.TIP2)
            local tip3W = TIP_FONTSET_0:getWidth(text[text.Language].IN_GAME_MENU.TIP3)
            putText(text[text.Language].IN_GAME_MENU.TIP1,
                1,1,1,1-PG,
                TIP_FONTSET_0,TIP_FONTSET_1,
                WINDOW_INFO.Width - tip1W/2,WINDOW_INFO.Height - tipH/2 - tipH*2
            )
            putText(text[text.Language].IN_GAME_MENU.TIP2,
                1,1,1,1-PG,
                TIP_FONTSET_0,TIP_FONTSET_1,
                WINDOW_INFO.Width - tip2W/2,WINDOW_INFO.Height - tipH/2 - tipH
            )
            putText(text[text.Language].IN_GAME_MENU.TIP3,
                1,1,1,1-PG,
                TIP_FONTSET_0,TIP_FONTSET_1,
                WINDOW_INFO.Width - tip3W/2,WINDOW_INFO.Height - tipH/2
            )
        else
            local tipH,tipW = TIP_FONTSET_0:getHeight("TEXT")
            local tip1W = TIP_FONTSET_0:getWidth(text[text.Language].OUT_GAME_MENU.TIP1)
            local tip2W = TIP_FONTSET_0:getWidth(text[text.Language].OUT_GAME_MENU.TIP2)
            local tip3W = TIP_FONTSET_0:getWidth(text[text.Language].OUT_GAME_MENU.TIP3)
            putText(text[text.Language].OUT_GAME_MENU.TIP1,
                1,1,1,1-PG,
                TIP_FONTSET_0,TIP_FONTSET_1,
                WINDOW_INFO.Width - tip1W/2,WINDOW_INFO.Height - tipH/2 - tipH*2
            )
            putText(text[text.Language].OUT_GAME_MENU.TIP2,
                1,1,1,1-PG,
                TIP_FONTSET_0,TIP_FONTSET_1,
                WINDOW_INFO.Width - tip2W/2,WINDOW_INFO.Height - tipH/2 - tipH
            )
            putText(text[text.Language].OUT_GAME_MENU.TIP3,
                1,1,1,1-PG,
                TIP_FONTSET_0,TIP_FONTSET_1,
                WINDOW_INFO.Width - tip3W/2,WINDOW_INFO.Height - tipH/2
            )
        end

        --//选择地图过场
        if UI.MAP_CHOOSE_CONFIRM then
            love.graphics.setColor(0,0,0,1)
            local num = 12
            local PG = smoothStep(math.max((UI.MAP_CHOOSE_TIMER - UI.MAP_CHOOSE_SETTIME/2)/(UI.MAP_CHOOSE_SETTIME/2),0))
            local W = WINDOW_INFO.Width/(num*2)
            local H = WINDOW_INFO.Height/num*2
            for i = 1,num do
                love.graphics.rectangle("fill",
                W*(i-1),
                WINDOW_INFO.Height*PG + (num - i)*H - (num - i)*H*(1 - PG),
                W,
                WINDOW_INFO.Height*2)
                love.graphics.rectangle("fill",
                WINDOW_INFO.Width - W*i,
                WINDOW_INFO.Height*PG + (num - i)*H - (num - i)*H*(1 - PG),
                W,
                WINDOW_INFO.Height*2)
            end
        end
    end
end

--//将一些函数传给UI.Lua里
local function sendToUI()
    --//StartGame传入
    UI.OUT_GAME.MENU_SET[0][1].func = function()
        UI.OUT_MAP_INDEX = 1

        UI.OUT_GAME_INDEX = 1
        UI.OUT_GAME_FRAME = 1
        UI.BOUNCE_ENTER_TIMER = UI.BOUNCE_ENTER_SETTIME
        UI.BOUNCE_SELECTE_TIMER = UI.BOUNCE_SELECTE_SETTIME
    end
    --//Quit传入
    UI.OUT_GAME.MENU_SET[0][3].func = function()
        love.event.quit()
    end
    --//Resume传入
    UI.IN_GAME.MENU_SET[0][1].func = UI.closeMENU
    --//Options传入
    UI.IN_GAME.MENU_SET[0][4].func = function()
        UI.IN_GAME_MENU_INDEX = 1
        UI.IN_GAME_MENU_FRAME = 1
        UI.BOUNCE_ENTER_TIMER = UI.BOUNCE_ENTER_SETTIME
        UI.BOUNCE_SELECTE_TIMER = UI.BOUNCE_SELECTE_SETTIME
    end
    UI.OUT_GAME.MENU_SET[0][2].func = function()
        UI.OUT_GAME_INDEX = 1
        UI.OUT_GAME_FRAME = 2
        UI.BOUNCE_ENTER_TIMER = UI.BOUNCE_ENTER_SETTIME
        UI.BOUNCE_SELECTE_TIMER = UI.BOUNCE_SELECTE_SETTIME
    end
    --//BackToMenu传入
    UI.IN_GAME.MENU_SET[0][5].func = function()
        UI.BACK_MAINMENU_TIMER = UI.BACK_MAINMENU_SETTIME
        UI.BACK_MAINMENU_CONFIRM = true
        UI.CAN_OPERATION = false
        soundPlay(sound.backToMainMenu)
    end
    --//OPTIONS-Language切换传入
    UI.IN_GAME.MENU_SET[1][1].func = function()
        for i,v in pairs(text.list) do
            if v == text.Language then
                if i + 1 > #text.list then
                    text.Language = text.list[1]
                    UI.languageUpdater()
                    break
                else
                    text.Language = text.list[i + 1]
                    UI.languageUpdater()
                    break
                end
            end
        end
    end
    UI.OUT_GAME.MENU_SET[2][1].func = function()
        for i,v in pairs(text.list) do
            if v == text.Language then
                if i + 1 > #text.list then
                    text.Language = text.list[1]
                    UI.languageUpdater()
                    break
                else
                    text.Language = text.list[i + 1]
                    UI.languageUpdater()
                    break
                end
            end
        end
    end
    --//OPTIONS-Back传入
    UI.IN_GAME.MENU_SET[1][#UI.IN_GAME.MENU_SET[1]].func = function()
        UI.IN_GAME_MENU_INDEX = 1
        UI.IN_GAME_MENU_FRAME = 0
        UI.BOUNCE_ENTER_TIMER = UI.BOUNCE_ENTER_SETTIME
        UI.BOUNCE_SELECTE_TIMER = UI.BOUNCE_SELECTE_SETTIME
        sound.select:stop()
        soundPlay(sound.back)
    end
    UI.OUT_GAME.MENU_SET[2][#UI.OUT_GAME.MENU_SET[2]].func = function()
        UI.OUT_GAME_INDEX = 1
        UI.OUT_GAME_FRAME = 0
        UI.BOUNCE_ENTER_TIMER = UI.BOUNCE_ENTER_SETTIME
        UI.BOUNCE_SELECTE_TIMER = UI.BOUNCE_SELECTE_SETTIME
        sound.select:stop()
        soundPlay(sound.back)
    end
    --//MapChoose-Back传入
    UI.OUT_GAME.MENU_SET[1][#UI.OUT_GAME.MENU_SET[1]].func = function()
        UI.OUT_GAME_INDEX = 1
        UI.OUT_GAME_FRAME = 0
        UI.BOUNCE_ENTER_TIMER = UI.BOUNCE_ENTER_SETTIME
        UI.BOUNCE_SELECTE_TIMER = UI.BOUNCE_SELECTE_SETTIME
        sound.select:stop()
        soundPlay(sound.back)
    end
end;sendToUI()


return UI
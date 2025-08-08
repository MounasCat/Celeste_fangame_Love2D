
--//数学
function floattrans (x,i)
    return string.format("%." .. i .. "f", x)
end
function loveSetColorRGB (cRGB,alpha)
    love.graphics.setColor(cRGB.R/255,cRGB.G/255,cRGB.B/255,alpha or 1)
end

local audio = {}
audio.console_tips = love.audio.newSource("audio/effect/console_tips.ogg","static")
audio.console_tips:setVolume(0.7)
audio.console_tips:setPitch(1.5)

local dbg = {}

--//管理
dbg.CONSOLE_HISTORY = {
    [1] ={
        msg = "dbg.version->2025/8/1",
        color = {R = 255,G = 255,B = 255},
    }
}
dbg.CONSOLE_ORDERS_HISTORY = {}
dbg.CONSOLE_ORDERS_HISTORY_INDEX = #dbg.CONSOLE_ORDERS_HISTORY

--//一些设置
dbg.CONSOLE_Input = ""
dbg.CONSOLE_InputIndex = 0
dbg.CONSOLE_IsOn = false
dbg.CONSOLE_Key = "/"
dbg.CONSOLE_enterKey = "return"
dbg.CONSOLE_SUGGEST_LIST = {}
dbg.CONSOLE_SUGGEST_INDEX = 1

--//字体大小预设
local PRINT_FONTSET_1 = love.graphics.newFont(13)
local PRINT_FONTSET_2 = love.graphics.newFont(14)
local PRINT_FONTSET_3 = love.graphics.newFont(15)
local PRINT_FONTSET_4 = love.graphics.newFont(16)
local PRINT_FONTSET_5 = love.graphics.newFont(17)
local PRINT_FONTSET_6 = love.graphics.newFont(18)

dbg.INFOColorRGB = {R = 204,G = 204,B = 255}

function dbg.InfoUpdater(Info_T)
    local msg = ""
    for i,v in pairs(Info_T) do
        if msg == "" then
            msg = msg .. tostring(i) .. ": " .. tostring(v)
        else
            msg = msg .. "\n" .. tostring(i) .. ": " .. tostring(v)
        end
    end

    love.graphics.setColor(0,0,0)
    love.graphics.setFont(PRINT_FONTSET_1)
    love.graphics.print(msg,4,1)
    love.graphics.setColor(transRGB(dbg.INFOColorRGB))
    love.graphics.setFont(PRINT_FONTSET_1)
    love.graphics.print(msg,3)
end

--//插入并播放声音
local function insertToHistory(L)
    table.insert(dbg.CONSOLE_HISTORY,L)
    audio.console_tips:play()
end

--//外部脚本输入
function dbg.print(msg)
    if _G.DEBUG_ON then
        if type(msg) == "string" then
            local L ={
                msg = "[print] " .. msg,
                color = {R = 100,G = 220,B = 220},
            }
            insertToHistory(L)
        end
    end
end
function dbg.warn(msg)
    if _G.DEBUG_ON then
        if type(msg) == "string" then
            local L ={
                msg = "[warn] " .. msg,
                color = {R = 220,G = 220,B = 100},
            }
            insertToHistory(L)
        end
    end
end
function dbg.error(msg)
    if _G.DEBUG_ON then
        if type(msg) == "string" then
            local L ={
                msg = "[error] " .. msg,
                color = {R = 220,G = 100,B = 100},
            }
            insertToHistory(L)
        end
    end
end

--//绘画
local CONSOLE_TIP_CLOCK, CONSOLE_TIP_SETCLOCK, CONSOLE_TIP_ON = 0, 0.5, false
function dbg.updateConsole(WINDOW_INFO,_DT)
    local FontH = PRINT_FONTSET_5:getHeight("T")
    local InPutWidth = PRINT_FONTSET_5:getWidth(string.sub(dbg.CONSOLE_Input,1,dbg.CONSOLE_InputIndex))
    local count = #dbg.CONSOLE_HISTORY
    local limit = 9
    if dbg.CONSOLE_IsOn then
        --Background
        love.graphics.setColor(0,0,0,0.5)
        love.graphics.rectangle("fill",0,WINDOW_INFO.Height - (FontH + 1),WINDOW_INFO.Width, FontH + 2)
        love.graphics.setColor(0.6,0.6,0.8,0.8)
        love.graphics.rectangle("fill",0,WINDOW_INFO.Height - (FontH + 2),WINDOW_INFO.Width, 2)
        --History
        for i = count, 1, -1 do
            local v = dbg.CONSOLE_HISTORY[i]
            local num = count - i + 2
            if num > limit then
                break
            end

            love.graphics.setColor(0,0,0,1 - num/limit)
            love.graphics.setFont(PRINT_FONTSET_5)
            love.graphics.print(v.msg, 5, WINDOW_INFO.Height - (4 + num*FontH) + 1)

            loveSetColorRGB(v.color,1 - num/limit)
            love.graphics.setFont(PRINT_FONTSET_5)
            love.graphics.print(v.msg, 4, WINDOW_INFO.Height - (4 + num*FontH))
        end
        --Input
        love.graphics.setColor(0,0,0,1)
        love.graphics.setFont(PRINT_FONTSET_5)
        love.graphics.print(dbg.CONSOLE_Input, 7, WINDOW_INFO.Height - (FontH - 1))
        love.graphics.setColor(1,1,1,1)
        love.graphics.setFont(PRINT_FONTSET_5)
        love.graphics.print(dbg.CONSOLE_Input, 5, WINDOW_INFO.Height - (FontH + 1))
        --Flash
        if CONSOLE_TIP_CLOCK >= CONSOLE_TIP_SETCLOCK then
            CONSOLE_TIP_ON = not CONSOLE_TIP_ON
            CONSOLE_TIP_CLOCK = 0
        else
            CONSOLE_TIP_CLOCK = CONSOLE_TIP_CLOCK + _DT
        end
        if CONSOLE_TIP_ON then
            love.graphics.setColor(0,0,0,1)
            love.graphics.rectangle("fill",InPutWidth + 7,WINDOW_INFO.Height - (FontH - 3),2,FontH - 4)
            love.graphics.setColor(0.9,0.9,0.9,1)
            love.graphics.rectangle("fill",InPutWidth + 5,WINDOW_INFO.Height - (FontH - 2),2,FontH - 4)
        end
        --Suggestion
        if #dbg.CONSOLE_SUGGEST_LIST > 1 then
            for i, cmd in ipairs(dbg.CONSOLE_SUGGEST_LIST) do
                love.graphics.setColor(0, 0, 0,0.8)
                love.graphics.print(cmd, 100 + 1, 200 + 20 * i + 1)

                love.graphics.setColor(1, 1, 1,1)
                love.graphics.print(cmd, 100, 200 + 20 * i)
            end
        end
    else
        for i = count, 1, -1 do
            local v = dbg.CONSOLE_HISTORY[i]
            local num = count - i + 1
            if num > limit then
                break
            end

            love.graphics.setColor(0,0,0,1 - num/limit)
            love.graphics.setFont(PRINT_FONTSET_5)
            love.graphics.print(v.msg, 5, WINDOW_INFO.Height - (4 + num*FontH) + 1)

            loveSetColorRGB(v.color,1 - num/limit)
            love.graphics.setFont(PRINT_FONTSET_5)
            love.graphics.print(v.msg, 4, WINDOW_INFO.Height - (4 + num*FontH))
        end
    end
end

--//预先指令（同时在main里也有嵌入）
dbg.CONSOLE_ORDERS = {
    ["/"] = function()end,

    ["/clean"] = function()
        for k in pairs(dbg.CONSOLE_HISTORY) do
            dbg.CONSOLE_HISTORY[k] = nil
        end

        insertToHistory({
            msg = "clean-> cleaned successfully!",
            color = {R = 100,G = 220,B = 100},
        })
    end,

    ["/print"] = function(args)
        local r_msg = ""
        for i = 2,#args do
            r_msg = r_msg .. args[i] .. " "
        end
        insertToHistory({
            msg = "print-> " .. r_msg,
            color = {R = 100,G = 220,B = 220},
        })
    end,

    ["/warn"] = function(args)
        local r_msg = ""
        for i = 2,#args do
            r_msg = r_msg .. args[i] .. " "
        end
        insertToHistory({
            msg = "warn-> " .. r_msg,
            color = {R = 220,G = 220,B = 100},
        })
    end,

    ["/error"] = function(args)
        local r_msg = ""
        for i = 2,#args do
            r_msg = r_msg .. args[i] .. " "
        end
        insertToHistory({
            msg = "error-> " .. r_msg,
            color = {R = 220,G = 100,B = 100},
        })
    end,
}

--//输入建议
function dbg.refreshSuggestionList()
    local input = dbg.CONSOLE_Input
    local base = input:match("^%S*") or ""

    local matches = {}
    for k in pairs(dbg.CONSOLE_ORDERS) do
        if k:sub(1, #base) == base then
            table.insert(matches, k)
        end
    end
    table.sort(matches)
    
    dbg.CONSOLE_SUGGEST_LIST = matches
    dbg.CONSOLE_SUGGEST_INDEX = 1

    if #matches == 1 then
        dbg.CONSOLE_Input = matches[1]
        dbg.CONSOLE_InputIndex = #dbg.CONSOLE_Input
        dbg.CONSOLE_SUGGEST_LIST = nil
        dbg.CONSOLE_SUGGEST_LIST = {}
    elseif #matches > 1 then
        dbg.CONSOLE_Input = matches[1]
        dbg.CONSOLE_InputIndex = #dbg.CONSOLE_Input
    end
end
function dbg.nextSuggestion()
    if #dbg.CONSOLE_SUGGEST_LIST > 1 then
        dbg.CONSOLE_SUGGEST_INDEX = (dbg.CONSOLE_SUGGEST_INDEX % #dbg.CONSOLE_SUGGEST_LIST) + 1
        local suggestion = dbg.CONSOLE_SUGGEST_LIST[dbg.CONSOLE_SUGGEST_INDEX]
        dbg.CONSOLE_Input = suggestion
        dbg.CONSOLE_InputIndex = #suggestion
    end
end

--//输入处理
function dbg.consoleInput(msg)
    L = {
        msg = " ",
        color = {R = 255,G = 255,B = 255},
    }
    if string.sub(msg,1,1) == "/" then
        args = {}
        for word in string.gmatch(msg, "%S+") do
            table.insert(args, word)
        end

        if dbg.CONSOLE_ORDERS[args[1]] then
            dbg.CONSOLE_ORDERS[args[1]](args)
        else
            L.msg = "Unknow order -> [" .. args[1] .. "]"
            L.color = {R = 220, G = 100, B =100}
            insertToHistory(L)
        end
    else
        L.msg = msg
        insertToHistory(L)
    end
end

--//可输入字符字母以及数字
local normalCharTable = {
    a="a", b="b", c="c", d="d", e="e", f="f", g="g", h="h", i="i", j="j",
    k="k", l="l", m="m", n="n", o="o", p="p", q="q", r="r", s="s", t="t",
    u="u", v="v", w="w", x="x", y="y", z="z",
    ["1"]="1", ["2"]="2", ["3"]="3", ["4"]="4", ["5"]="5",
    ["6"]="6", ["7"]="7", ["8"]="8", ["9"]="9", ["0"]="0",
    ["-"]="-", ["="]="=",
    ["["]="[", ["]"]="]",
    [";"]=";", ["'"]="'",
    [","]=",", ["."]=".",["/"]="/",
    ["`"]="`",
    ["space"]=" ",  -- space

    kp0 = "0", kp1 = "1", kp2 = "2", kp3 = "3", kp4 = "4",
    kp5 = "5", kp6 = "6", kp7 = "7", kp8 = "8", kp9 = "9",
    ["kp."] = ".", ["kp/"] = "/", ["kp*"] = "*",
    ["kp-"] = "-", ["kp+"] = "+", ["kp="] = "=",
    ["kp,"] = ",",
}
local shiftCharTable = {
    a="A", b="B", c="C", d="D", e="E", f="F", g="G", h="H", i="I", j="J",
    k="K", l="L", m="M", n="N", o="O", p="P", q="Q", r="R", s="S", t="T",
    u="U", v="V", w="W", x="X", y="Y", z="Z",
    ["1"]="!", ["2"]="@", ["3"]="#", ["4"]="$", ["5"]="%",
    ["6"]="^", ["7"]="&", ["8"]="*", ["9"]="(", ["0"]=")",
    ["-"]="_", ["="]="+",
    ["["]="{", ["]"]="}",
    [";"]=":", ["'"]='"',
    [","]="<", ["."]=">", ["/"]="?",
    ["`"]="~",
    ["space"]=" ",  -- space

    kp0 = "0", kp1 = "1", kp2 = "2", kp3 = "3", kp4 = "4",
    kp5 = "5", kp6 = "6", kp7 = "7", kp8 = "8", kp9 = "9",
    ["kp."] = ".", ["kp/"] = "/", ["kp*"] = "*",
    ["kp-"] = "-", ["kp+"] = "+", ["kp="] = "=",
    ["kp,"] = ",",
}

--//控制台调控
function dbg.consoleKeys(Key)
     --input layer
    if Key == dbg.CONSOLE_enterKey or Key == "kpenter" and dbg.CONSOLE_IsOn then
        dbg.CONSOLE_IsOn = not dbg.CONSOLE_IsOn
        if dbg.CONSOLE_Input ~= "" then
            dbg.consoleInput(dbg.CONSOLE_Input)
            table.insert(dbg.CONSOLE_ORDERS_HISTORY,dbg.CONSOLE_Input)
        end
        dbg.CONSOLE_Input = ""
        dbg.CONSOLE_InputIndex = 0
        dbg.CONSOLE_ORDERS_HISTORY_INDEX = #dbg.CONSOLE_ORDERS_HISTORY
    elseif Key == "escape" and dbg.CONSOLE_IsOn then
        dbg.CONSOLE_IsOn = not dbg.CONSOLE_IsOn
    end

    if normalCharTable[Key] and dbg.CONSOLE_IsOn and not love.keyboard.isDown("lshift","rshift") then
        dbg.CONSOLE_Input = string.sub(dbg.CONSOLE_Input, 1, dbg.CONSOLE_InputIndex) .. normalCharTable[Key] .. string.sub(dbg.CONSOLE_Input, dbg.CONSOLE_InputIndex + 1)
        dbg.CONSOLE_InputIndex = dbg.CONSOLE_InputIndex + 1
        dbg.CONSOLE_SUGGEST_LIST = nil
        dbg.CONSOLE_SUGGEST_LIST = {}
        dbg.CONSOLE_SUGGEST_INDEX = 1
    elseif shiftCharTable[Key] and dbg.CONSOLE_IsOn and love.keyboard.isDown("lshift","rshift") then
        dbg.CONSOLE_Input = string.sub(dbg.CONSOLE_Input, 1, dbg.CONSOLE_InputIndex) .. shiftCharTable[Key] .. string.sub(dbg.CONSOLE_Input, dbg.CONSOLE_InputIndex + 1)
        dbg.CONSOLE_InputIndex = dbg.CONSOLE_InputIndex + 1
        dbg.CONSOLE_SUGGEST_LIST = nil
        dbg.CONSOLE_SUGGEST_LIST = {}
        dbg.CONSOLE_SUGGEST_INDEX = 1
    end
    --quickly out layer
    if Key == dbg.CONSOLE_Key and not dbg.CONSOLE_IsOn then
        dbg.CONSOLE_IsOn = not dbg.CONSOLE_IsOn
        dbg.CONSOLE_Input = dbg.CONSOLE_Input .. "/"
        dbg.CONSOLE_InputIndex = dbg.CONSOLE_InputIndex + 1
        dbg.CONSOLE_SUGGEST_LIST = nil
        dbg.CONSOLE_SUGGEST_LIST = {}
        dbg.CONSOLE_SUGGEST_INDEX = 1
    end
    --delete layer
    if Key == "backspace" and dbg.CONSOLE_IsOn then
        if dbg.CONSOLE_InputIndex ~= 0 then
            msg = dbg.CONSOLE_Input
            dbg.CONSOLE_Input = string.sub(msg, 1, dbg.CONSOLE_InputIndex - 1) .. string.sub(msg, dbg.CONSOLE_InputIndex + 1)
            dbg.CONSOLE_InputIndex = dbg.CONSOLE_InputIndex - 1
            dbg.CONSOLE_SUGGEST_LIST = nil
            dbg.CONSOLE_SUGGEST_LIST = {}
            dbg.CONSOLE_SUGGEST_INDEX = 1
        end
    end
    --switch position layer
    if Key == "left" and dbg.CONSOLE_IsOn then
        dbg.CONSOLE_InputIndex = math.max(0, math.min(dbg.CONSOLE_InputIndex - 1, #dbg.CONSOLE_Input))
        dbg.CONSOLE_SUGGEST_LIST = nil
        dbg.CONSOLE_SUGGEST_LIST = {}
        dbg.CONSOLE_SUGGEST_INDEX = 1
    elseif Key == "right" and dbg.CONSOLE_IsOn then
        dbg.CONSOLE_InputIndex = math.max(0, math.min(dbg.CONSOLE_InputIndex + 1, #dbg.CONSOLE_Input))
        dbg.CONSOLE_SUGGEST_LIST = nil
        dbg.CONSOLE_SUGGEST_LIST = {}
        dbg.CONSOLE_SUGGEST_INDEX = 1
    end
    --history layer
    if Key == "up" and dbg.CONSOLE_IsOn then
        if dbg.CONSOLE_ORDERS_HISTORY_INDEX ~= 0 then
            dbg.CONSOLE_ORDERS_HISTORY_INDEX = math.max(1,math.min(dbg.CONSOLE_ORDERS_HISTORY_INDEX - 1, #dbg.CONSOLE_ORDERS_HISTORY))
            dbg.CONSOLE_Input = dbg.CONSOLE_ORDERS_HISTORY[dbg.CONSOLE_ORDERS_HISTORY_INDEX]
            dbg.CONSOLE_InputIndex = #dbg.CONSOLE_Input
        end
    elseif Key == "down" and dbg.CONSOLE_IsOn then
        if dbg.CONSOLE_ORDERS_HISTORY_INDEX ~= 0 then
            dbg.CONSOLE_ORDERS_HISTORY_INDEX = math.max(1,math.min(dbg.CONSOLE_ORDERS_HISTORY_INDEX + 1, #dbg.CONSOLE_ORDERS_HISTORY))
            dbg.CONSOLE_Input = dbg.CONSOLE_ORDERS_HISTORY[dbg.CONSOLE_ORDERS_HISTORY_INDEX]
            dbg.CONSOLE_InputIndex = #dbg.CONSOLE_Input
        end
    end
    --suggestion layer
    if Key == "tab" and dbg.CONSOLE_IsOn then
        if #dbg.CONSOLE_SUGGEST_LIST == 0 then
            dbg.refreshSuggestionList()
        else
            dbg.nextSuggestion()
        end
    end
end

return dbg
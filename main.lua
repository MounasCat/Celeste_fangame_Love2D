 
function love.load()
    --****************************************************************************************************--
    --[][][][][Models][][][][]-
    M_vec = require("lib.kit.vector")
    M_col = require("lib.kit.color")
    M_mat = require("lib.kit.math")
    M_dbg = require("lib.kit.debug")
    M_win = require("lib.kit.window")
    M_cam = require("lib.kit.camera")
    M_dat = require("lib.kit.data")
    M_phi = require("lib.kit.phisics")

    render = require("render")
    UI = require("UI")

    M_ply = require("lib.mob.player")

    --[][][][][System settings][][][][]-

    ON_FRAME = 60--1s

    _DT = 0
    _OSTIME = 0

    Delay = 0
    SaveDelay = 0

    IN_GAME_RENDER = false

    DEBUG_ON = false

    GRAPHICS_FPS = 0
    WINDOW_INFO = {
        Width = love.graphics.getWidth(),
        Height = love.graphics.getHeight(),
        InWidth = M_win.GAME_WIDTH,
        InHeight = M_win.GAME_HEIGHT,
        scale = 1,
        offsetX = 0,
        offsetY = 0,
        ox = 0,
        oy = 0,
        Rscale = 1,
    }
    love.window.setMode(M_win.GAME_WIDTH, M_win.GAME_HEIGHT, {
        fullscreen = false,
        resizable = true,
        vsync = true
    })
    love.graphics.setDefaultFilter("nearest", "nearest")

    MOUSE_POSITION = {x = 0,y = 0}--只与外窗口有关，而非游戏内窗口

    WORLD = {
        Tile = {Width = 8, Height = 8},--在loadMap里自动适应
        Size = {x = 120, y = 40},--在loadMap里自动适应
        Visible = false,--指的是Tiled格数是否可见，而非整个地图
        Objects = {},
        LEFT_CORNER = {x = 0, y = 0},
    }

    Camera = M_cam.newCamera(0,0,4,0)--4 是由于1280/320=4，提高像素量来防止模糊
    Camera:setObject(M_ply.position)

    GAME_CANVAS = M_win.createCanvas()
    GAME_SHADER_ON = false
    GAME_SHADER_TESTER = {
        Time = 0,
        shader = "crt",
    }--仅改变GAME_CANVAS画布

    M_win.updateScale()--更新一下窗口

    --//获取数据
    GAME_DATA = M_dat.getData()

    --[][][][][Assets/Audios/Maps][][][][]-
    assets = {}
    audio = {}
    BGM = nil
    BGM_VOLUME = 0
    BGM_NOW_VOLUME = 0
    
    audio.music = {
        default = {
            source = love.audio.newSource("audio/music/train.wav","stream"),
            volume = 0.4,
            start = 0,
        },
        intro = {
            source = love.audio.newSource("audio/music/intro.wav","stream"),
            volume = 0.4,
            start = 31,
        },
        cave = {
            source = love.audio.newSource("audio/music/cave.ogg","stream"),
            volume = 0.4,
            start = 0,
        },
    }
    for i,v in pairs(audio.music) do
        v.source:setLooping(true)
    end

    audio.events = {}
    audio.events.spotlight_Out_1 = love.audio.newSource("audio/effect/spotlight_outro_in.wav","stream")
    audio.events.spotlight_Out_2 = love.audio.newSource("audio/effect/spotlight_outro_finish.wav","stream")
    audio.events.spotlight_In_1 = love.audio.newSource("audio/effect/spotlight_intro_in.wav","stream")
    audio.events.spotlight_In_2 = love.audio.newSource("audio/effect/spotlight_intro_finish.wav","stream")

    --[][][][][Functions][][][][]-
    --//获取tick
    function tick()
        return os.clock()
    end
    function delayUpdater(t)
        if M_ply.ISGAMING then
            render.particalPUpdater(0.1)
            M_cam.shakingUpdater(0.1)
        end
    end
    --//垃圾收集机/间隔更新器
    function ON_FRAMEUpdater()
        if ON_FRAME < 60 then
            ON_FRAME = ON_FRAME + 1
        end
        if ON_FRAME == 6 then --0.1s updater
            delayUpdater(0.1)
            collectgarbage("collect")
        end
        if ON_FRAME == 12 then --0.2s updater
            delayUpdater(0.1)
            collectgarbage("collect")
        end
        if ON_FRAME == 18 then --0.3s updater
            delayUpdater(0.1)
            collectgarbage("collect")
        end
        if ON_FRAME == 24 then --0.4s updater
            delayUpdater(0.1)
            collectgarbage("collect")
        end
        if ON_FRAME == 30 then --0.5s updater
            delayUpdater(0.1)
            collectgarbage("collect")
        end
        if ON_FRAME == 36 then --0.6s updater
            delayUpdater(0.1)
            collectgarbage("collect")
        end
        if ON_FRAME == 42 then --0.7s updater
            delayUpdater(0.1)
            collectgarbage("collect")
        end
        if ON_FRAME == 48 then --0.8s updater
            delayUpdater(0.1)
            collectgarbage("collect")
        end
        if ON_FRAME == 54 then --0.9s updater
            delayUpdater(0.1)
            collectgarbage("collect")
        end
        if ON_FRAME == 60 then --1s updater
            delayUpdater(0.1)
            ON_FRAME = 0
            collectgarbage("collect")
        end
    end
    --//BGM声音大小缓变
    function BGMUpdater(dt,autoChange,OutGame)
        if BGM then
            if BGM.source then
                if BGM_NOW_VOLUME < BGM_VOLUME then
                    BGM_NOW_VOLUME = math.min(BGM_NOW_VOLUME + 0.5 * dt, BGM_VOLUME)
                elseif BGM_NOW_VOLUME > BGM_VOLUME then
                    BGM_NOW_VOLUME = math.max(BGM_NOW_VOLUME - 0.5 * dt, BGM_VOLUME)
                end
                BGM.source:setVolume(BGM_NOW_VOLUME)
            end
            if autoChange then
                if not OutGame then
                    if UI.IN_GAME.IS_ON and UI.IN_GAME.IS_ON_MENU then
                        BGM_VOLUME = BGM.volume/5
                    else
                        BGM_VOLUME = BGM.volume
                    end
                else
                    BGM_VOLUME = 0
                end
            end
        end
    end

    --****************************************************************************************************--

    --[][][][][Press Buffer][][][][]-
    BUFFER_KEYS = {}
    function ReLoadBUFFER_KEYS ()
        BUFFER_KEYS = nil
        BUFFER_KEYS = {}
        for i,v in pairs(M_ply.keyboard.jump) do
            BUFFER_KEYS[v] = {
                During = false,
                SetTime = 0.12,
                Timer = 0
            }
        end
        for i,v in pairs(M_ply.keyboard.dash) do
            BUFFER_KEYS[v] = {
                During = false,
                SetTime = 0.12,
                Timer = 0
            }
        end
    end;ReLoadBUFFER_KEYS()

    for i,v in pairs(M_ply.keyboard.jump) do
        BUFFER_KEYS[v] = {
            During = false,
            SetTime = 0.12,
            Timer = 0
        }
    end
    function Update_keys(dt)
        for i,v in pairs(BUFFER_KEYS) do
            if v ~= nil then
                if v.Timer > 0 then
                    v.Timer = v.Timer - dt
                elseif v.Timer <= 0 then
                    v.Timer = 0
                    v.During = false
                end
            end
        end
    end
    function Is_Keys(Name,specific)
        if specific then
            for _,v in pairs(M_ply.keyboard[specific]) do
                if BUFFER_KEYS[v] ~= nil and BUFFER_KEYS[v].During then
                    return true
                end
            end
        else
            if BUFFER_KEYS[Name] ~= nil then
                return BUFFER_KEYS[Name].During
            end
        end
        return false
    end
    function PressedKeys(Name)
        if BUFFER_KEYS[Name] ~= nil then
            BUFFER_KEYS[Name].Timer = BUFFER_KEYS[Name].SetTime
            BUFFER_KEYS[Name].During = true
        end
    end
    function HavePressed_Keys(Name,specific)
        if specific then
            for _,v in pairs(M_ply.keyboard[specific]) do
                if BUFFER_KEYS[v] ~= nil then
                    BUFFER_KEYS[v].During = false
                    BUFFER_KEYS[v].Timer = 0
                end
            end
        else
            if BUFFER_KEYS[Name] ~= nil then
                BUFFER_KEYS[Name].During = false
                BUFFER_KEYS[Name].Timer = 0
            end
        end
    end

    --[][][][][Press Strength][][][][]-


    --[][][][][Actions][][][][]-
    function toSpawn()
        for _,v in pairs(M_phi.objects.key) do
            if v.type == "spawn" then
                local p = M_phi.collisionGrid.point
                M_ply.position.x,M_ply.position.y = p.x + v.x + v.width/2,p.y - v.y - v.height/2
                Camera.showPosition.x,Camera.showPosition.y = p.x + v.x + v.width/2,p.y - v.y - v.height/2
                Camera.position.x,Camera.position.y = p.x + v.x + v.width/2,p.y - v.y - v.height/2
            end
        end
    end

    --//改变地图
    GAME_MAP_CHANGING = false
    GAME_MAP_CHANGING_TEMP = false
    GAME_MAP_CHANGING_PATH = ""
    GAME_MAP_CHANGING_BGM = ""
    GAME_MAP_CHANGING_PG_Set_1,GAME_MAP_CHANGING_PG_Set_2,GAME_MAP_CHANGING_PG_Set_3,GAME_MAP_CHANGING_PG_Set_4 = 0.8,0.5,0.8,1
    GAME_MAP_CHANGING_PG_1,GAME_MAP_CHANGING_PG_2,GAME_MAP_CHANGING_PG_3,GAME_MAP_CHANGING_PG_4 = 0,0,0,0
    GAME_MAP_CHANGING_PG_B1,GAME_MAP_CHANGING_PG_B2,GAME_MAP_CHANGING_PG_B3,GAME_MAP_CHANGING_PG_B4 = false,false,false,false
    CS_1,CS_2,CS_3,CS_4 = false,false,false,false

    GAME_MAP_CHANGING_RADIUS = 125
    GAME_MAP_CHANGING_SMOOTHNESS = 0.1
    GAME_MAP_CHANGING_RADIUS_NOW = 0

    function changeMap(mapPath,BGMName,FirstLoad)
        if require("maps.game." .. mapPath) and not GAME_MAP_CHANGING then
            GAME_MAP_CHANGING_PG_1 = GAME_MAP_CHANGING_PG_Set_1
            GAME_MAP_CHANGING_PG_2 = GAME_MAP_CHANGING_PG_Set_2
            GAME_MAP_CHANGING_PG_3 = GAME_MAP_CHANGING_PG_Set_3
            GAME_MAP_CHANGING_PG_4 = GAME_MAP_CHANGING_PG_Set_4
            GAME_MAP_CHANGING_PG_B1,GAME_MAP_CHANGING_PG_B2,GAME_MAP_CHANGING_PG_B3,GAME_MAP_CHANGING_PG_B4 = false,false,false,false
            CS_1,CS_2,CS_3,CS_4 = false,false,false,false
            GAME_MAP_CHANGING_RADIUS_NOW = WINDOW_INFO.InWidth
            if FirstLoad then
                GAME_MAP_CHANGING_PG_1,GAME_MAP_CHANGING_PG_2 = 0,0
                GAME_MAP_CHANGING_PG_B1,GAME_MAP_CHANGING_PG_B2 = true,true
                CS_1,CS_2 = true,true
                GAME_MAP_CHANGING_RADIUS_NOW = 0
            end

            GAME_MAP_CHANGING = true
            GAME_MAP_CHANGING_TEMP = false
            M_ply.ISGAMING = false
            M_ply.changeMapFromPlayer = ""
            M_ply.checkpoint = nil
            GAME_MAP_CHANGING_PATH = mapPath
            local file = require("maps.game." .. mapPath)
            GAME_MAP_CHANGING_BGM = "default"
            if type(BGMName) == "string" then
                if audio.music[BGMName] then
                    GAME_MAP_CHANGING_BGM = BGMName
                end
            end
            if file.properties.music then
                if audio.music[file.properties.music] then
                    GAME_MAP_CHANGING_BGM = file.properties.music
                end
            end
            BGM_VOLUME = 0.075
            M_dbg.print(tostring(BGM_VOLUME))
        else
            M_dbg.error("fail load map: " .. "[" .. mapPath .. "]!")
        end
    end
    function changeMapUpdater(dt)
        if GAME_MAP_CHANGING_PG_4 > 0 then
            --//计时器
            if GAME_MAP_CHANGING_PG_1 - dt > 0 then
                if GAME_MAP_CHANGING_PG_B1 then
                    GAME_MAP_CHANGING_PG_1 = GAME_MAP_CHANGING_PG_1 - dt
                end
            else
                GAME_MAP_CHANGING_PG_1 = 0
                if GAME_MAP_CHANGING_PG_2 - dt > 0 then
                    if GAME_MAP_CHANGING_PG_B2 then
                        GAME_MAP_CHANGING_PG_2 = GAME_MAP_CHANGING_PG_2 - dt
                    end
                else
                    GAME_MAP_CHANGING_PG_2 = 0
                    if GAME_MAP_CHANGING_PG_3 - dt > 0 then
                        if GAME_MAP_CHANGING_PG_B3 then
                            GAME_MAP_CHANGING_PG_3 = GAME_MAP_CHANGING_PG_3 - dt
                        end
                    else
                        GAME_MAP_CHANGING_PG_3 = 0
                        GAME_MAP_CHANGING = false
                        if GAME_MAP_CHANGING_PG_4 - dt > 0 then
                            if GAME_MAP_CHANGING_PG_B4 then
                                GAME_MAP_CHANGING_PG_4 = GAME_MAP_CHANGING_PG_4 - dt
                            end
                        else
                            GAME_MAP_CHANGING_PG_4 = 0
                        end
                    end
                end
            end

            --//聚光灯半径计算
            if not GAME_MAP_CHANGING_PG_B1 then
                GAME_MAP_CHANGING_RADIUS_NOW = math.max(GAME_MAP_CHANGING_RADIUS,GAME_MAP_CHANGING_RADIUS_NOW - GAME_MAP_CHANGING_RADIUS/0.08*dt)
            elseif GAME_MAP_CHANGING_PG_1 == 0 and GAME_MAP_CHANGING_PG_2 ~= 0 then
                BGM_VOLUME = 0
                GAME_MAP_CHANGING_RADIUS_NOW = math.max(0,GAME_MAP_CHANGING_RADIUS_NOW - GAME_MAP_CHANGING_RADIUS/0.15*dt)
            elseif GAME_MAP_CHANGING_PG_2 == 0 and GAME_MAP_CHANGING_PG_3 ~= 0 then
                GAME_MAP_CHANGING_RADIUS_NOW = math.min(GAME_MAP_CHANGING_RADIUS,GAME_MAP_CHANGING_RADIUS_NOW + GAME_MAP_CHANGING_RADIUS/0.15*dt)
            elseif GAME_MAP_CHANGING_PG_3 == 0 then
                GAME_MAP_CHANGING_RADIUS_NOW = math.max(GAME_MAP_CHANGING_RADIUS,GAME_MAP_CHANGING_RADIUS_NOW + GAME_MAP_CHANGING_RADIUS/0.15*dt)
            end

            --//开关
            if not GAME_MAP_CHANGING_PG_B1 and GAME_MAP_CHANGING_RADIUS_NOW == GAME_MAP_CHANGING_RADIUS then
                GAME_MAP_CHANGING_PG_B1 = true
            end
            if GAME_MAP_CHANGING_PG_B1 and not GAME_MAP_CHANGING_PG_B2 and GAME_MAP_CHANGING_RADIUS_NOW == 0 then
                GAME_MAP_CHANGING_PG_B2 = true
            end
            if GAME_MAP_CHANGING_PG_B1 and GAME_MAP_CHANGING_PG_B2 and not GAME_MAP_CHANGING_PG_B3 and GAME_MAP_CHANGING_RADIUS_NOW == GAME_MAP_CHANGING_RADIUS then
                GAME_MAP_CHANGING_PG_B3 = true
            end
            if GAME_MAP_CHANGING_PG_B1 and GAME_MAP_CHANGING_PG_B2 and GAME_MAP_CHANGING_PG_B3 and not GAME_MAP_CHANGING_PG_B4 and GAME_MAP_CHANGING_RADIUS_NOW > WINDOW_INFO.InWidth then
                GAME_MAP_CHANGING_PG_B4 = true
            end

            --//音效
            if not CS_1 then
                audio.events.spotlight_Out_1:stop()
                audio.events.spotlight_Out_1:seek(0)
                audio.events.spotlight_Out_1:play()
                CS_1 = true
            end
            if not CS_2 and GAME_MAP_CHANGING_PG_1 < 0.3 then
                audio.events.spotlight_Out_2:stop()
                audio.events.spotlight_Out_2:seek(0)
                audio.events.spotlight_Out_2:play()
                CS_2 = true
            end
             if not CS_3 and GAME_MAP_CHANGING_PG_2 < 0.3 then
                audio.events.spotlight_In_1:stop()
                audio.events.spotlight_In_1:seek(0)
                audio.events.spotlight_In_1:play()
                CS_3 = true
            end
             if not CS_4 and GAME_MAP_CHANGING_PG_3 < 0.1 then
                audio.events.spotlight_In_2:stop()
                audio.events.spotlight_In_2:seek(0)
                audio.events.spotlight_In_2:play()
                CS_4 = true
            end

            if GAME_MAP_CHANGING_PG_B2 and not GAME_MAP_CHANGING_TEMP then
                GAME_MAP_CHANGING_TEMP = true
                render.maps.nowMap = nil--地图在这加载
                render.maps.nowMap = render.loadMap(WORLD,M_phi,"maps.game." .. GAME_MAP_CHANGING_PATH,Camera)
                --//重置
                M_phi.objectsReset()
                toSpawn()
                M_ply.restart()
                M_ply.state.setDashTimes = 1--因为 M_ply.restart() 不带这个（单纯死亡不会重置最大dash次数）
                M_ply.GamingTime = 0--重置游戏时间
                M_dbg.print("Map[" .. GAME_MAP_CHANGING_PATH .."] load")
                if BGM then
                    BGM.source:stop()
                    BGM = false
                end
                if audio.music[GAME_MAP_CHANGING_BGM] then
                    BGM = audio.music[GAME_MAP_CHANGING_BGM]
                end
                M_dbg.print("BGM[" .. GAME_MAP_CHANGING_BGM .."] loaded")
            end

            if GAME_MAP_CHANGING_PG_3 == 0 and not M_ply.ISGAMING then
                M_ply.ISGAMING = true
                BGM_VOLUME_CHANGE = true
                if BGM then
                    BGM.source:seek(BGM.start)
                    BGM_VOLUME = BGM.volume
                    BGM.source:play()
                end
            end

        end
    end
    function changeMapBetween(canvas,position,Camera,WINDOW_INFO)
        local finalCanvas = canvas
        if GAME_MAP_CHANGING_PG_4 ~= 0 then
            local cx, cy = M_win.toCanvasPosition(position, Camera)
            local wp = {cx, cy}

            local tempCanvas = M_win.createCanvas()
            love.graphics.setCanvas(tempCanvas)
            love.graphics.setColor(1, 1, 1, 1)

            render.shaders.spotlight:send("center", wp)
            render.shaders.spotlight:send("radius", GAME_MAP_CHANGING_RADIUS_NOW)
            render.shaders.spotlight:send("smoothness", GAME_MAP_CHANGING_SMOOTHNESS)

            love.graphics.setShader(render.shaders.spotlight)
            love.graphics.draw(finalCanvas, 0, 0)
            love.graphics.setShader()
            love.graphics.setCanvas()

            finalCanvas = tempCanvas
        end

        return finalCanvas
    end

    LOW_STAMINA_COLOR = M_col.AddNormalLines({
        Repeat = true,
        SetColor = {R =255 ,G = 50, B = 50},
        TargetColor = {R =255,G = 255, B = 255},
        SetTime = 0.08
    })

    --changeMap("gametest")

    --[][][][][UIs][][][][]--
    --//录入一些功能
    UI.IN_GAME.MENU_SET[0][3].func = function()--Restar
        UI.closeMENU(M_ply)
        changeMap(GAME_MAP_CHANGING_PATH)
    end

    --****************************************************************************************************--
    --[][][][][Debug][][][][]-
    CONSOLE_ORDERS = {}
    Printcount = 3
    Printstr = ""

    CONSOLE_ORDERS.printcount = function(args)
        if tonumber(args[2]) then
            Printcount = tonumber(args[2])
            M_dbg.print("Operated.")
        else
            M_dbg.error("it Must be a number!")
        end
    end
    CONSOLE_ORDERS.printstr = function(args)
        if args[2] then
            local r = ""
            for i = 2,#args do
                r = r .. args[i] .. " "
            end
            Printstr = r
            M_dbg.print("Operated.")
        else
            M_dbg.error("it Must be a string!")
        end
    end
    CONSOLE_ORDERS.worldVisble = function(args)
        if args[2] == "true" then
            WORLD.Visible = true
            M_dbg.print("Operated.")
        elseif args[2] == "false" then
            WORLD.Visible = false
            M_dbg.print("Operated.")
        else
            M_dbg.warn("invalid bool.")
        end
    end
    CONSOLE_ORDERS.camMove = function(args)
        if tonumber(args[2]) and tonumber(args[3]) then
            Camera:move(tonumber(args[2]),tonumber(args[3]))
            M_dbg.print("Operated.")
        else
            M_dbg.error("x or y Must be a number!")
        end
    end
    CONSOLE_ORDERS.camSetpos = function(args)
        if tonumber(args[2]) and tonumber(args[3]) then
            Camera:setPosition(tonumber(args[2]),tonumber(args[3]))
            M_dbg.print("Operated.")
        else
            M_dbg.error("x or y Must be a number!")
        end
    end
    CONSOLE_ORDERS.camSetrot = function(args)
        if tonumber(args[2]) then
            Camera:setRotation(tonumber(args[2]))
            M_dbg.print("Operated.")
        else
            M_dbg.error("rotation Must be a number!")
        end
    end
    CONSOLE_ORDERS.camSetzoom = function(args)
        if tonumber(args[2]) then
            Camera:setZoom(tonumber(args[2]))
            M_dbg.print("Operated.")
        else
            M_dbg.error("scale Must be a number!")
        end
    end
    CONSOLE_ORDERS.camSetobj = function(args)
        if args[2] then
            if args[2] == "player" then
                Camera:setObject(M_ply.position)
            elseif WORLD_OBJECTS[tostring(args[2])] then
                M_dbg.print("Operated.")
                Camera:setObject(WORLD_OBJECTS[tostring(args[2])])
            else
                M_dbg.error("the obj[" .. tostring(args[2]) .."] dosen't exist!")
            end
        else
            M_dbg.error("obj's name Must be a string!")
        end
    end
    CONSOLE_ORDERS.camSetfree = function(args)
        Camera:freeMode()
        M_dbg.print("Operated.")
    end
    CONSOLE_ORDERS.camSetmode = function(args)
        if args[2] == "attach" then
            Camera.mode = args[2]
            M_dbg.print("Operated.")
        elseif args[2] == "follow" then
            M_dbg.print("Operated.")
            Camera.mode = args[2]
        else
            M_dbg.warn("invalid bool.")
        end
    end
    CONSOLE_ORDERS.camScroll = function(args)
        if args[2] == "true" then
            Camera.scroll = true
            M_dbg.print("Operated.")
        elseif args[2] == "false" then
            M_dbg.print("Operated.")
            Camera.scroll = false
        else
            M_dbg.warn("the mode's name dosen't exist!")
        end
    end
    CONSOLE_ORDERS.camEdge = function(args)
        if args[2] == "true" then
            Camera.edgeMode = true
            M_dbg.print("Operated.")
        elseif args[2] == "false" then
            M_dbg.print("Operated.")
            Camera.edgeMode = false
        else
            M_dbg.warn("the mode's name dosen't exist!")
        end
    end
    CONSOLE_ORDERS.winSize = function(args)
        if tonumber(args[2]) and tonumber(args[3]) then
            M_win.GAME_WIDTH = math.max(320, args[2])
            M_win.GAME_HEIGHT = math.max(180, args[3])
            M_win.updateScale()
            M_dbg.print("Operated.")
        else
            M_dbg.error("WIDTH or HEIGHT Must be a number!")
        end
    end
    CONSOLE_ORDERS.shaderOn = function(args)
        if args[2] == "true" then
            GAME_SHADER_ON = true
            M_dbg.print("Operated.")
        elseif args[2] == "false" then
            GAME_SHADER_ON = false
            M_dbg.print("Operated.")
        else
            M_dbg.warn("invalid bool.")
        end
    end
    CONSOLE_ORDERS.shaderTester = function(args)
        if args[2] then--what shader
            if args[2] == "stop" then
                GAME_SHADER_TESTER.Time = 0
            elseif render.shaders[args[2]] then
                local t = 1
                if tonumber(args[3]) then--what during time
                    t = math.max(0,math.min(tonumber(args[3]),10))
                end
                GAME_SHADER_TESTER.Time = t
                GAME_SHADER_TESTER.shader = args[2]
                M_dbg.print("Operated.")
            else
                GAME_SHADER_TESTER.shader = "origin"
                M_dbg.warn("invalid command(shader: origin).")
            end
        end
    end
    CONSOLE_ORDERS.dataView = function(args)
        if args[2] == "state" then
            if M_dat.dataOn then
                M_dbg.print("the data system is ON")
            else
                M_dbg.print("the data system is OFF")
            end
        else
            M_dbg.warn("invalid command.")
        end
    end
    CONSOLE_ORDERS.mapViewer = function(args)
        if args[2] == "ON" then
            M_phi.collisionGrid.visible = true
            M_phi.objects.visible = true
            M_dbg.print("Operated.")
        elseif args[2] == "OFF" then
            M_phi.collisionGrid.visible = false
             M_phi.objects.visible = false
            M_dbg.print("Operated.")
        else
            M_dbg.warn("invalid command(ON/OFF).")
        end
    end
    CONSOLE_ORDERS.toSpawn = function(args)
        toSpawn()
    end
    CONSOLE_ORDERS.detectorViewer = function(args)
        if args[2] == "ON" then
            M_ply.collisionVisible = true
            M_ply.DetectorVisible = true
            M_dbg.print("Operated.")
        elseif args[2] == "OFF" then
            M_ply.collisionVisible = false
            M_ply.DetectorVisible = false
            M_dbg.print("Operated.")
        else
            M_dbg.warn("invalid command(ON/OFF).")
        end
    end
    CONSOLE_ORDERS.hitboxViewer = function(args)
        if args[2] == "ON" then
            M_ply.hitboxVisible = true
            M_dbg.print("Operated.")
        elseif args[2] == "OFF" then
            M_ply.hitboxVisible = false
            M_dbg.print("Operated.")
        else
            M_dbg.warn("invalid command(ON/OFF).")
        end
    end
    CONSOLE_ORDERS.doubleDash = function(args)
        if M_ply.state.setDashTimes == 1 then
            M_ply.state.setDashTimes = 2
            M_dbg.print("setDashTimes = 2.")
        elseif M_ply.state.setDashTimes == 2 then
            M_ply.state.setDashTimes = 1
            M_dbg.print("setDashTimes = 1.")
        end
    end
    CONSOLE_ORDERS.pauseGame = function(args)
        if args[2] == "true" then
            if not GAME_MAP_CHANGING then
                M_ply.ISGAMING = false
                M_dbg.print("pause.")
            else
                M_dbg.print("illegal operation.(changing map)")
            end
        elseif args[2] == "false" then
            if not GAME_MAP_CHANGING then
                M_ply.ISGAMING = true
            else
                M_dbg.print("illegal operation.(changing map)")
            end
            M_dbg.print("continue.")
        else
            M_dbg.warn("invalid bool.")
        end
    end
    CONSOLE_ORDERS.loadMap = function(args)
        if not GAME_MAP_CHANGING then
            if args[2] then
                changeMap(args[2],args[3])
            else
                M_dbg.warn("invalid name.")
            end
        else
            M_dbg.warn("processing.")
        end
    end
    CONSOLE_ORDERS.setDelay = function(args)
        if not GAME_MAP_CHANGING and M_ply.ISGAMING then
            if type(tonumber(args[2])) == "number" then
                Delay = math.max(0,math.min(math.floor(tonumber(args[2])),60))
            else
                M_dbg.warn("invalid operation.")
            end
        else
            M_dbg.warn("illegal operation.")
        end
    end
    for i,v in pairs(CONSOLE_ORDERS) do
        M_dbg.CONSOLE_ORDERS["/" .. tostring(i)] = function(args)
            v(args)
        end
    end

end

function love.update(dt)
    --****************************************************************************************************--
    --[][][][][Systems][][][][]-
    _DT = dt
    _OSTIME = love.timer.getTime()

    ON_FRAMEUpdater()

    GRAPHICS_FPS = love.timer.getFPS()

    --[][][][][Mouse systems][][][][]-
    MOUSE_POSITION.x, MOUSE_POSITION.y = love.mouse.getPosition()

    --[][][][][Keys systems][][][][]-
    --//预输入更新
    Update_keys(dt)
    if not M_ply.state.dying and M_ply.ISGAMING then
        --//使用预输入的键
        if Is_Keys(nil,"jump") and M_ply.coyoteTimer ~= 0 and M_ply.state.canNextDash then--地跳
            HavePressed_Keys(nil,"jump")
            M_ply.Jump()
        elseif Is_Keys(nil,"jump") and M_ply.state.canClimbJump and M_ply.state.canNextDash then--墙跳
            HavePressed_Keys(nil,"jump")
            M_ply.Jump()
        end
        if Is_Keys(nil,"dash") and not M_ply.state.IsDash and M_ply.state.canNextDash then
            HavePressed_Keys(nil,"dash")
            M_ply.dash()
        end
        --//玩家左右移动
        if M_ply.KeyDetector("left") then
            M_ply.MoveL()
        elseif M_ply.KeyDetector("right") then
            M_ply.MoveR()
        else
            M_ply.MoveS()
        end
        --//玩家按住爬键
        if M_ply.KeyDetector("climb") then
            if not M_ply.state.IsJumping then
                M_ply.state.IsPressClimbKey = true
            elseif not M_ply.state.onGround then
                M_ply.state.IsPressClimbKey = true
            else
                M_ply.state.IsPressClimbKey = false
            end
        else
            M_ply.state.IsPressClimbKey = false
        end
    end

    --[][][][][Window systems][][][][]-
    WINDOW_INFO.Width = love.graphics.getWidth()
    WINDOW_INFO.Height = love.graphics.getHeight()
    WINDOW_INFO.InWidth = M_win.GAME_WIDTH
    WINDOW_INFO.InHeight = M_win.GAME_HEIGHT
    WINDOW_INFO.scale = M_win.scale
    WINDOW_INFO.offsetX = M_win.offsetX
    WINDOW_INFO.offsetY = M_win.offsetY
    WINDOW_INFO.ox, WINDOW_INFO.oy = math.floor(WINDOW_INFO.offsetX + 0.5), math.floor(WINDOW_INFO.offsetY + 0.5)
    WINDOW_INFO.Rscale = math.floor(WINDOW_INFO.scale * 1000 + 0.5) / 1000

    --[][][][][Camera systems][][][][]-
    CameraSpeed = love.keyboard.isDown("lshift") and 500 or 300
    if not M_dbg.CONSOLE_IsOn and not UI.IN_GAME.IS_ON_MENU and not UI.OUT_GAME.IS_ON then
        if love.keyboard.isDown("up") then
            Camera:move(0,CameraSpeed*_DT)
        end
        if love.keyboard.isDown("left") then
            Camera:move(-CameraSpeed*_DT,0)
        end
        if love.keyboard.isDown("down") then
            Camera:move(0,-_DT*CameraSpeed)
        end
        if love.keyboard.isDown("right") then
            Camera:move(_DT*CameraSpeed,0)
        end
    end

    Camera:infoUpdater(WINDOW_INFO)

    --[][][][][World systems][][][][]-
    WORLD.LEFT_CORNER.x = -WORLD.Size.x*WORLD.Tile.Width/2
    WORLD.LEFT_CORNER.y = WORLD.Size.y*WORLD.Tile.Height/2

    --[][][][][Game systems][][][][]-
    if not M_ply.state.dying and M_ply.ISGAMING and not M_dbg.CONSOLE_IsOn then
        if SaveDelay <= 0 then
            --//Delay重置
            SaveDelay = Delay
            --//玩家蹲下检测
            if not M_ply.state.IsDashDuring then
                M_ply.ToSquat("down")
            end
            --//方向更新
            M_ply.directionUpdater()
            --//玩家更新
            M_ply.updater(dt)
        else
            SaveDelay = SaveDelay - 1
        end
    elseif M_ply.state.dying then
        SaveDelay = 0
    end

    --//死亡/复活
    if M_ply.deadTimer > 0 then
        M_ply.dead(dt,Camera)
    end
    if M_ply.reviveTimer > 0 then
        M_ply.revive(dt)
    end

    --//BGM更新
    if not GAME_MAP_CHANGING then
        if not UI.OUT_GAME.IS_ON then
            BGMUpdater(dt,true)
        else
            BGMUpdater(dt,true,true)
        end
    else
        BGMUpdater(dt,false)
    end

    --//改变地图
    changeMapUpdater(dt)
    if M_ply.changeMapFromPlayer ~= "" and not GAME_MAP_CHANGING then
        changeMap(M_ply.changeMapFromPlayer)
    end
    if UI.MAP_CHOOSE_CONFIRM then
        if UI.MAP_CHOOSE_TIMER <= UI.MAP_CHOOSE_SETTIME/2 and not IN_GAME_RENDER then
            IN_GAME_RENDER = true
        end
        if UI.MAP_CHOOSE_TIMER <= 0 then
            UI.MAP_CHOOSE_CONFIRM = false
            UI.OUT_GAME.IS_ON = false
            UI.IN_GAME.IS_ON = true
            UI.IN_GAME.IS_ON_MENU = false
            UI.CAN_OPERATION = true
            changeMap(UI.OUT_GAME.MAP_SET[UI.OUT_MAP_INDEX].name,nil,true)
        end
    end

    --[][][][][Shader/render systems][][][][]--
    GAME_SHADER_TESTER.Time = math.max(0,GAME_SHADER_TESTER.Time - dt)

    if M_ply.ISGAMING and SaveDelay <= 0 and M_ply.lagTimer == 0 then
        render.particalTUpdater(dt)
        render.dashlineUpdater(dt)
        render.speedcircleUpdater(dt)
        render.dashshaderUpdater(dt)
        render.shadowUpdater(dt)
        render.snowflakeUpdater(dt,Camera,M_ply)

        render.snowflakeAuto(dt,Camera)
    end

    render.objAnimationUpdater(dt)

    --[][][][][color.lua][][][][]--
    M_col.NormalLinesUpdater(dt)

    --[][][][][UI system][][][][]--
    UI.timeUpdater(dt,WINDOW_INFO)
    UI.snowflakeUpdater(WINDOW_INFO,dt)


    --****************************************************************************************************--
end

function love.draw()
    --****************************************************************************************************--
    GAME_CANVAS = M_win.createCanvas()
    if IN_GAME_RENDER then
        M_win.setCanvas(GAME_CANVAS)
        Camera:attach(WINDOW_INFO,WORLD)
        --[][][][][BackBround][][][][]-
        render.drawBackground(Camera,WINDOW_INFO)

        render.snowflakeDraw()

        --[][][][][InGame][][][][]-
        --//绘制地图
        love.graphics.setColor(1, 1, 1, 1)
        if render.maps.nowMap then
            render.maps.nowMap:draw(0,0,"center")
        end
        --//shadow特效
        render.drawShadow()
        --//DashLine特效
        render.drawDashLines()
        --//speedcircle特效
        render.drawSpeedcircle()
        --//玩家碰撞面积
        if M_ply.collisionVisible then
            love.graphics.setColor(1, 0.5, 1,0.8)
            render.rectangle("line",
                M_ply.position.x - M_ply.collisionSize.width/2,
                M_ply.position.y + M_ply.collisionSize.height/2,
                M_ply.collisionSize.width,
                M_ply.collisionSize.height
            )
        end
        if M_ply.DetectorVisible then
            --显示跳墙面积
            love.graphics.setColor(1, 1, 0.5,0.8)
            render.rectangle("fill",
                M_ply.position.x - M_ply.collisionSize.width/2 - 3,
                M_ply.position.y + (M_ply.collisionSize.height)/2,
                3,
                M_ply.collisionSize.height
            )
            render.rectangle("fill",
                M_ply.position.x + M_ply.collisionSize.width/2,
                M_ply.position.y + (M_ply.collisionSize.height)/2,
                3,
                M_ply.collisionSize.height
            )
            --显示爬墙/滑墙面积
            love.graphics.setColor(0.2, 0.2, 1,1)
            render.rectangle("fill",
                M_ply.position.x - M_ply.collisionSize.width/2 - 1,
                M_ply.position.y + (M_ply.collisionSize.height-2)/2,
                1,
                M_ply.collisionSize.height/2 - 4
            )
            render.rectangle("fill",
                M_ply.position.x + M_ply.collisionSize.width/2,
                M_ply.position.y + (M_ply.collisionSize.height-2)/2,
                1,
                M_ply.collisionSize.height/2 - 4
            )
            --显示修正像素
            love.graphics.setColor(1, 0.2, 0.2,0.8)
            render.rectangle("fill",
                M_ply.position.x - M_ply.collisionSize.width/2 - 1,
                M_ply.position.y + (M_ply.collisionSize.height-2)/2 + 2,
                2,
                2
            )
            render.rectangle("fill",
                M_ply.position.x + M_ply.collisionSize.width/2 - 1,
                M_ply.position.y + (M_ply.collisionSize.height-2)/2 + 2,
                2,
                2
            )
            render.rectangle("fill",
                M_ply.position.x - M_ply.collisionSize.width/2 - 1,
                M_ply.position.y - (M_ply.collisionSize.height-2)/2,
                2,
                2
            )
            render.rectangle("fill",
                M_ply.position.x + M_ply.collisionSize.width/2 - 1,
                M_ply.position.y - (M_ply.collisionSize.height-2)/2,
                2,
                2
            )
        end
        --//玩家形象
        --显示缩放面积/以及冲刺提示
        --[[
        if M_ply.state.dashTimes < 1 then
            love.graphics.setColor(0.5, 1, 1,1)
        elseif M_ply.state.dashTimes < 2 then
            love.graphics.setColor(1, 0.4,0.4,1)
        else
            love.graphics.setColor(1, 0.6,0.8,1)
        end
        render.rectangle("fill",
            M_ply.position.x - M_ply.textureSize.width/2 + M_ply.textureSize.Dx,
            M_ply.position.y + M_ply.textureSize.height/2 + M_ply.textureSize.Dy,
            M_ply.textureSize.width,
            M_ply.textureSize.height
        )
        --]]
        --[][][][][][][][][][][][]显示玩家sprites[][][][][][][][][][][][][]--
        --画出玩家基础形象--
        love.graphics.push()
        render.drawPlayer(GAME_CANVAS,M_ply,Camera,WINDOW_INFO)
        love.graphics.pop()
        --//显示体力条/冲刺提示
        love.graphics.setColor(0, 0, 0, 1)
        render.rectangle("fill",
            M_ply.position.x - 3.25,
            M_ply.position.y + 1.25 + 10,
            8.5,
            1.5
        )
        if M_ply.hair.NowColor == "Pink" then
            love.graphics.setColor(M_ply.hair["LPink"][1], M_ply.hair["LPink"][2], M_ply.hair["LPink"][3],1)
        elseif M_ply.hair.NowColor == "Red" then
            love.graphics.setColor(M_ply.hair["LRed"][1], M_ply.hair["LRed"][2], M_ply.hair["LRed"][3],1)
        elseif M_ply.hair.NowColor == "Blue" then
            love.graphics.setColor(M_ply.hair["LBlue"][1], M_ply.hair["LBlue"][2], M_ply.hair["LBlue"][3],1)
        elseif M_ply.hair.NowColor == "White" then
            love.graphics.setColor(M_ply.hair["White"][1], M_ply.hair["White"][2], M_ply.hair["White"][3],1)
        end
        render.rectangle("fill",
            M_ply.position.x - 3,
            M_ply.position.y + 1 + 10,
            (M_ply.state.stamina/M_ply.state.maxStamina)*8,
            1
        )
        --//玩家Hitbox面积
        if M_ply.hitboxVisible then
            love.graphics.setColor(0.5, 1, 0.5,0.4)
            render.rectangle("fill",
                M_ply.position.x - M_ply.hitboxSize.width/2 + M_ply.hitboxSize.Dx,
                M_ply.position.y + M_ply.hitboxSize.height/2 + M_ply.hitboxSize.Dy,
                M_ply.hitboxSize.width,
                M_ply.hitboxSize.height
            )
            love.graphics.setColor(0.5, 1, 0.5,0.8)
            render.rectangle("line",
                M_ply.position.x - M_ply.hitboxSize.width/2 + M_ply.hitboxSize.Dx,
                M_ply.position.y + M_ply.hitboxSize.height/2 + M_ply.hitboxSize.Dy,
                M_ply.hitboxSize.width,
                M_ply.hitboxSize.height
            )
        end

        --//粒子效果
        render.drawParticals()

        --[][][][][World Viewer][][][][]-
        if WORLD.Visible then
            love.graphics.setColor(0.4, 1, 0.4,1)
            love.graphics.rectangle("fill",-1,-2500,2,5000)
            love.graphics.setColor(1, 0.4, 0.4, 1)
            love.graphics.rectangle("fill",-2500,-1,5000,2)

            for i = 1,WORLD.Size.x do
                for v = 1,WORLD.Size.y do
                    love.graphics.setColor(0.5, 0.5, 0.5,0.2)
                    render.rectangle("line", WORLD.LEFT_CORNER.x + (i-1)*WORLD.Tile.Width, WORLD.LEFT_CORNER.y - (v-1)*WORLD.Tile.Height, WORLD.Tile.Width, WORLD.Tile.Height)
                end
            end

            love.graphics.setColor(0.4, 0.4, 1, 1)
            render.circle("fill", 0, 0, 2)
        end
        --[][][][][Map Viewer][][][][]--
        --//查看碰撞面积
        if M_phi.collisionGrid.visible then
            for y,_ in pairs(M_phi.collisionGrid.grid) do
                for x,__ in pairs(M_phi.collisionGrid.grid[y]) do
                    if M_phi.collisionGrid.grid[y][x] then
                        love.graphics.setColor(0.7, 1, 0.7,0.5)
                        render.rectangle(
                            "line",
                            M_phi.collisionGrid.point.x + (x-1)*M_phi.collisionGrid.tile,
                            M_phi.collisionGrid.point.y - (y-1)*M_phi.collisionGrid.tile,
                            M_phi.collisionGrid.tile,M_phi.collisionGrid.tile
                        )
                    end
                end
            end
        end
        --//查看dangers面积
        if  M_phi.dangerGrid.visible then
            love.graphics.setColor(1, 0.2, 0.2,1)
            for y,_ in pairs(M_phi.dangerGrid.grid) do
                for x,__ in pairs(M_phi.dangerGrid.grid[y]) do
                    if M_phi.dangerGrid.grid[y][x] > 0 then
                        if M_phi.dangerGrid.grid[y][x] == 1 then--上尖刺
                            render.rectangle(
                                "line",
                                M_phi.collisionGrid.point.x + (x-1)*M_phi.collisionGrid.tile,
                                M_phi.collisionGrid.point.y - (y-1)*M_phi.collisionGrid.tile - 5,
                                M_phi.collisionGrid.tile,3
                            )
                        elseif M_phi.dangerGrid.grid[y][x] == 2 then--左尖刺
                            render.rectangle(
                                "line",
                                M_phi.collisionGrid.point.x + (x-1)*M_phi.collisionGrid.tile + 5,
                                M_phi.collisionGrid.point.y - (y-1)*M_phi.collisionGrid.tile,
                                3,M_phi.collisionGrid.tile
                            )
                        elseif M_phi.dangerGrid.grid[y][x] == 3 then--下尖刺
                            render.rectangle(
                                "line",
                                M_phi.collisionGrid.point.x + (x-1)*M_phi.collisionGrid.tile,
                                M_phi.collisionGrid.point.y - (y-1)*M_phi.collisionGrid.tile,
                                M_phi.collisionGrid.tile,3
                            )
                        elseif M_phi.dangerGrid.grid[y][x] == 4 then--右尖刺
                            render.rectangle(
                                "line",
                                M_phi.collisionGrid.point.x + (x-1)*M_phi.collisionGrid.tile,
                                M_phi.collisionGrid.point.y - (y-1)*M_phi.collisionGrid.tile,
                                3,M_phi.collisionGrid.tile
                            )
                        end
                    end
                end
            end
            love.graphics.setColor(1, 1, 1, 1)
        end

        --//查看对象面积/类型
        if M_phi.objects.visible then
            for _,v in pairs(M_phi.objects.normal) do
                love.graphics.setColor(0.5, 0.5, 1,0.8)
                render.rectangle("line",M_phi.collisionGrid.point.x + v.x,M_phi.collisionGrid.point.y - v.y,v.width,v.height)
                love.graphics.setColor(0.5, 0.5, 1,0.4)
                render.rectangle("fill",M_phi.collisionGrid.point.x + v.x,M_phi.collisionGrid.point.y - v.y,v.width,v.height)
                love.graphics.setFont(love.graphics.newFont(20))
                love.graphics.setColor(0, 0, 0, 1)
                render.print(v.name .. "(" .. v.type .. ")",M_phi.collisionGrid.point.x + v.x + 0.5,M_phi.collisionGrid.point.y - v.y - 0.5,0,0.2,0.2)
                love.graphics.setColor(1, 1, 1, 1)
                render.print(v.name .. "(" .. v.type .. ")",M_phi.collisionGrid.point.x + v.x,M_phi.collisionGrid.point.y - v.y,0,0.2,0.2)
            end
            for _,v in pairs(M_phi.objects.key) do
                love.graphics.setColor(1, 0.5, 0.5,0.8)
                render.rectangle("line",M_phi.collisionGrid.point.x + v.x,M_phi.collisionGrid.point.y - v.y,v.width,v.height)
                love.graphics.setColor(1, 0.5, 0.5,0.4)
                render.rectangle("fill",M_phi.collisionGrid.point.x + v.x,M_phi.collisionGrid.point.y - v.y,v.width,v.height)
                love.graphics.setFont(love.graphics.newFont(20))
                love.graphics.setColor(0, 0, 0, 1)
                render.print(v.name .. "(" .. v.type .. ")",M_phi.collisionGrid.point.x + v.x + 0.5,M_phi.collisionGrid.point.y - v.y - 0.5,0,0.2,0.2)
                love.graphics.setColor(1, 1, 1, 1)
                render.print(v.name .. "(" .. v.type .. ")",M_phi.collisionGrid.point.x + v.x,M_phi.collisionGrid.point.y - v.y,0,0.2,0.2)
            end
        end

        Camera:detach()
        M_win.endCanvas(GAME_CANVAS)
        --[][][][][InGame UIs][][][][]-
        

        --[][][][][Shaders][][][][]-
        --//Dash弯曲
        GAME_CANVAS = render.drawDashshader(GAME_CANVAS,render.shaders.rippleShader,Camera,WINDOW_INFO)
        --//手电筒效果
        if M_ply.flashlight then
            GAME_CANVAS = render.setSpotlight(
                GAME_CANVAS,M_ply.position,
                Camera,WINDOW_INFO,150,0.4
            )
        end
        --开场/离场聚光灯效果
        GAME_CANVAS = changeMapBetween(GAME_CANVAS,M_ply.position,Camera,WINDOW_INFO)
        --//地图色调
        GAME_CANVAS = render.setColorShader(GAME_CANVAS)
        --//模糊效果
        GAME_CANVAS = render.setBlur(GAME_CANVAS,WINDOW_INFO)

        --[][][][][Finally Output][][][][]--
        M_win.endCanvas(GAME_CANVAS)

        --[][][][][OutGame UIs][][][][]-

        --//死亡/复活过场
        if M_ply.deadTimer > 0 then
            M_ply.deadFrame(math.max(0,math.min((M_ply.deadPG - 0.4)/0.4,1)),WINDOW_INFO)
        elseif M_ply.reviveTimer > 0 then
            M_ply.deadFrame(math.max(0,math.min((M_ply.revivePG - 0.2)/0.8,1)),WINDOW_INFO)
        end
    end

    --//UI绘画
    UI.drawIN_GAME(WINDOW_INFO)
    UI.drawOUT_GAME(WINDOW_INFO)

    UI.firstJoin(WINDOW_INFO,M_ply)
    

    --****************************************************************************************************--
    --[][][][][Debug][][][][]--
    if DEBUG_ON then
        M_dbg.InfoUpdater({
            ["GRAPHICS_FPS"] = GRAPHICS_FPS,["USING RAM"] = M_mat.floattrans(collectgarbage("count"),3),
            ["P1"] = M_vec.Tostr(Camera.cornerP1),["P2"] = M_vec.Tostr(Camera.cornerP2),
            ["TestX"] = render.TestX
        })
        M_dbg.updateConsole(WINDOW_INFO,_DT)
    end
    --****************************************************************************************************--
end

function love.keypressed(key)
    --[Buffer keys]--
    if not M_dbg.CONSOLE_IsOn then
        if BUFFER_KEYS[key] then
            PressedKeys(key)
        end
        --[Normal keys]--
        if key == "escape" then
            if not GAME_MAP_CHANGING and GAME_MAP_CHANGING_PG_4 <= 0 and not M_ply.state.dying and not UI.OUT_GAME.IS_ON and UI.IN_GAME.IS_ON then--仅在非地图切换，非死亡状态，外层UI关闭状态下打开
                if not UI.IN_GAME.IS_ON_MENU then--打开暂停菜单
                    UI.openMENU(M_ply)
                elseif UI.IN_GAME.IS_ON_MENU and UI.IN_GAME_MENU_FRAME > 0 then--返回上一面
                    UI.IN_GAME_MENU_FRAME = UI.IN_GAME_MENU_FRAME - 1
                elseif UI.IN_GAME.IS_ON_MENU then--关闭暂停菜单
                    UI.closeMENU(M_ply)
                end
            end
        elseif key == "up" then
            --//暂停菜单上选
            if UI.IN_GAME.IS_ON_MENU and UI.IN_GAME.IS_ON then
                UI.operationMENU("up",M_ply)
            end
            --//主菜单上选
            if UI.OUT_GAME.IS_ON then
                UI.operationMENU("up",M_ply)
            end
        elseif key == "down" then
            --//暂停菜单下选
            if UI.IN_GAME.IS_ON_MENU and UI.IN_GAME.IS_ON then
                UI.operationMENU("down",M_ply)
            end
            --//主菜单下选
            if UI.OUT_GAME.IS_ON then
                UI.operationMENU("down",M_ply)
            end
        elseif key == "left" then
            --//主菜单左选
            if UI.OUT_GAME.IS_ON then
                UI.operationMENU("left",M_ply)
            end
        elseif key == "right" then
            --//主菜单右选
            if UI.OUT_GAME.IS_ON then
                UI.operationMENU("right",M_ply)
            end
        elseif key == "c" then
            --//暂停菜单确认
            if UI.IN_GAME.IS_ON_MENU and UI.IN_GAME.IS_ON then
                UI.operationMENU("confirm",M_ply)
            end
            --//主菜单确认
            if UI.OUT_GAME.IS_ON then
                UI.operationMENU("confirm",M_ply)
            end
        end
    end
    if DEBUG_ON then
        --[Debug keys]--
        M_dbg.consoleKeys(key)
    end
    --[First join skip]--
    if UI.FIRST_JOIN_TIMER > 0 then
        if UI.FIRST_JOIN_TIMER < UI.FIRST_JOIN_SETTIME*0.5 and UI.FIRST_JOIN_TIMER > UI.FIRST_JOIN_SETTIME*0.2 then
            UI.FIRST_JOIN_TIMER = UI.FIRST_JOIN_SETTIME*0.2
        end
    end
end

function love.resize(w, h)
    M_win.updateScale()
end
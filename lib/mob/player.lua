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
local M_phi = require("lib.kit.phisics")
local M_mat = require("lib.kit.math")
local M_cam = require("lib.kit.camera")

local render = require("render")

local UI = require("UI")

--//声效
local sound = {
    foot = {
        stepNum = 1,
        defalut = {},
        wood = {},
    },
    dash = {
        Rleft = love.audio.newSource("audio/mob/player/Dash/dash_red_left.wav","static"),
        Rright = love.audio.newSource("audio/mob/player/Dash/dash_red_right.wav","static"),
        Pleft = love.audio.newSource("audio/mob/player/Dash/dash_pink_left.wav","static"),
        Pright = love.audio.newSource("audio/mob/player/Dash/dash_pink_right.wav","static"),
    },
    jump = {
        NormalJump = love.audio.newSource("audio/mob/player/Jump/jump.wav","static"), 
        SuperJump = love.audio.newSource("audio/mob/player/Jump/jump_super.wav","static"), 
        LwallJump = love.audio.newSource("audio/mob/player/Jump/jump_wall_left.wav","static"),
        RwallJump = love.audio.newSource("audio/mob/player/Jump/jump_wall_right.wav","static"),
        SuperSlide = love.audio.newSource("audio/mob/player/Jump/jump_superslide.wav","static"),
        SuperWall = love.audio.newSource("audio/mob/player/Jump/jump_superwall_A001.wav","static"),
    },
    stand = {
        [1] = love.audio.newSource("audio/mob/player/Stand/stand_02.wav","static"),
    },
    wall = {
        Sliding = love.audio.newSource("audio/mob/player/Wall/wallslide_general.wav","static"),
    },
    duck = {
        Num = 1,
        [1] = love.audio.newSource("audio/mob/player/Duck/duck_01.wav","static"),
        [2] = love.audio.newSource("audio/mob/player/Duck/duck_02.wav","static"),
        [3] = love.audio.newSource("audio/mob/player/Duck/duck_03.wav","static"),
    },
    dead = {
        normal = love.audio.newSource("audio/mob/player/Death/death.wav","static"),
        gold = love.audio.newSource("audio/mob/player/Death/death_goldenberry.wav","static"),
        revive = love.audio.newSource("audio/mob/player/Death/death_revive.mp3","static"),
        pre = love.audio.newSource("audio/mob/player/Death/predeath.wav","static"),
    },
    effect = {
        spike = love.audio.newSource("audio/effect/land_02_dreamblockinactive_03.wav","static"),
        getStrawberry = love.audio.newSource("audio/effect/strawberry_pulse.wav","static"),
        strawberry = love.audio.newSource("audio/effect/strawberry_red_get_5000.wav","static"),
        checkpoint = love.audio.newSource("audio/effect/checkpointconfetti.wav","static"),
    },
    interaction = {
        refresh_touch_01 = love.audio.newSource("audio/mob/player/Interaction/refresh_touch_01.wav","static"),
        refresh_touch_02 = love.audio.newSource("audio/mob/player/Interaction/refresh_touch_02.wav","static"),
        refresh_touch_03 = love.audio.newSource("audio/mob/player/Interaction/refresh_touch_03.wav","static"),
    },
    defalut = {
        [1] = love.audio.newSource("audio/effect/pico8_flag.wav","static")
    },
}
sound.jump.NormalJump:setVolume(0.5);sound.jump.LwallJump:setVolume(0.5)
sound.jump.RwallJump:setVolume(0.5);sound.jump.SuperJump:setVolume(0.75)
sound.jump.SuperSlide:setVolume(0.75);sound.jump.SuperWall:setVolume(0.75)
sound.stand[1]:setVolume(1)

sound.wall.Sliding:setVolume(0.5);sound.wall.Sliding:setLooping(true)

sound.dead.normal:setVolume(0.8);sound.dead.gold:setVolume(0.8)
sound.dead.revive:setVolume(0.8);sound.dead.revive:setPitch(2.5)

sound.effect.spike:setVolume(0.8);sound.effect.spike:setPitch(1.5)
sound.effect.checkpoint:setVolume(0.3);

for i = 1,7 do
    sound.foot.defalut[i] = love.audio.newSource("audio/mob/player/FootStep/Default/F" .. i .. ".wav","static")
    sound.foot.defalut[i]:setVolume(0.6)
    sound.foot.wood[i] = love.audio.newSource("audio/mob/player/FootStep/Wood/F" .. i .. ".wav","static")
    sound.foot.wood[i]:setVolume(0.6)
end
for i = 1,3 do
    sound.interaction["refresh_touch_0" .. i]:setVolume(0.6)
end


--//数学
function vecLerp(v1, v2, t)
    local _t = t or 0.5
    return v1.x * (1 - _t) + v2.x * _t, v1.y * (1 - _t) + v2.y * _t or 0, 0
end
function numLerp(St,En,t)
    t = math.max(0,math.min(t,1))
    return St * (1 - t) + En * t
end
local function nolimitLerp(St,En,t)
    return St * (1 - t) + En * t
end
function easeOutElastic(x)
    local smooth = x * x * (3 - 2 * x)
    local overshoot = 0.25 * x * (1 - x) * math.sin(6 * math.pi * x)
    return smooth + overshoot
end
local bezierSetting = {
    p0 = {x=0, y=0},
    p1 = {x=0.2, y=-1.5},
    p2 = {x=0.8, y=2.5},
    p3 = {x=1, y=1},
}
function bezier(t)
    local u = 1 - t
    local tt = t * t
    local uu = u * u
    local uuu = uu * u
    local ttt = tt * t

    return uuu * bezierSetting.p0.y + 3 * uu * t * bezierSetting.p1.y + 3 * u * tt * bezierSetting.p2.y + ttt * bezierSetting.p3.y
end
function smoothStep(x)
    -- 保证输入在 [0, 1]
    x = math.max(0, math.min(1, x))
    return x * x * (3 - 2 * x)
end
local function bounce(x)
    x = x or 0
    return -math.sin((x + 0.1)*1.666666667*math.pi) + 0.5
end

--//声音播放机
local function soundPlay(s,p)
    p = p or 0
    s = s or sound.defalut[math.random(1,#sound.defalut)]
    s:stop(); s:seek(p); s:play()
end

local ply = {}

--//键盘预设
ply.keyboard = {
    ["up"] = {[1] = "w"},
    ["left"] = {[1] = "a"},
    ["down"] = {[1] = "s"},
    ["right"] = {[1] = "d"},
    ["jump"] = {[1] = "j",[2] = ";"},
    ["dash"] = {[1] = "k"},
    ["climb"] = {[1] = "l"},
}
function ply.KeyDetector(target)
    if type(target) == "string" then
        if ply.keyboard[target] then
            for _,v in pairs(ply.keyboard[target]) do
                if love.keyboard.isDown(v) then
                    return true
                end
            end
        else
            dbg.warn("can't find the target!(key)")
        end
    end
    return false
end

ply.ISGAMING = false
ply.changeMapFromPlayer = ""

ply.flashlight = false

ply.checkpoint = nil

ply.anchor = nil

ply.lagTimer = 0
ply.GamingTime = 0

--//图像
ply.texture = {
    Hair = {--specific
        [1] = love.graphics.newImage("assets/Player/Hair/Hair_1.png"),
        [2] = love.graphics.newImage("assets/Player/Hair/Hair_2.png"),
    },
    Idle = {
        ["setTime"] = 0.06,
        ["timer"] = 0.06,
        ["number"] = 1,
    },
    RunSlow = {
        ["setTime"] = 0.06,
        ["timer"] = 0.06,
        ["number"] = 1,
    },
    RunFast = {
        ["setTime"] = 0.06,
        ["timer"] = 0.06,
        ["number"] = 1,
    },
    Flip = {--specific
        ["number"] = 1,
    },
    Dash = {--specific
        [1] = love.graphics.newImage("assets/Player/Dash/Dash_1.png"),--左下，右下，下，左，右
        [2] = love.graphics.newImage("assets/Player/Dash/Dash_2.png"),--左上，右上
        [3] = love.graphics.newImage("assets/Player/Dash/Dash_1.png"),--上
    },
    Climb = {
        ["setTime"] = 0.04,
        ["timer"] = 0.06,
        ["number"] = 1,

    },
    Slide = {
        ["setTime"] = 0.1,
        ["timer"] = 0.1,
        ["number"] = 1,
        [1] = love.graphics.newImage("assets/Player/Slide/Slide_1.png"),
    },
    Jump = {--specific
        [1] = love.graphics.newImage("assets/Player/Jump/Jump_1.png"),
        [2] = love.graphics.newImage("assets/Player/Jump/Jump_2.png"),
    },
    Fall = {--specific
        [1] = love.graphics.newImage("assets/Player/Fall/Fall_1.png"),
        [2] = love.graphics.newImage("assets/Player/Fall/Fall_2.png"),
    },
    Dead = {--specific
    },
    Default = {
        ["setTime"] = 0.1,
        ["timer"] = 0.05,
        ["number"] = 1,
        [1] = love.graphics.newImage("assets/Player/Template/Template.png"),
    }
}
for i = 1,10 do--Idle
    ply.texture.Idle[i] = love.graphics.newImage("assets/Player/Idle/Idle_" .. tostring(i) ..".png")
end
for i = 1,12 do--RunSlow
    ply.texture.RunSlow[i] = love.graphics.newImage("assets/Player/RunSlow/RunSlow_" .. tostring(i) ..".png")
end
for i = 1,12 do--RunFast
    ply.texture.RunFast[i] = love.graphics.newImage("assets/Player/RunFast/RunFast_" .. tostring(i) ..".png")
end
for i = 1,6 do--Climb
    ply.texture.Climb[i] = love.graphics.newImage("assets/Player/Climb/Climb_" .. tostring(i) ..".png")
end
for i = 1,8 do--Flip
    ply.texture.Flip[i] = love.graphics.newImage("assets/Player/Flip/Flip_" .. tostring(i) ..".png")
end
for i = 1,12 do--Dead
    ply.texture.Dead[i] = love.graphics.newImage("assets/Player/Dead/Dead_" .. tostring(i) ..".png")
end
for _,v in pairs(ply.texture) do
    for __,i in pairs(v) do
        if __ ~= "timer" and __ ~= "setTime" and __ ~= "number" then
            i:setFilter("nearest", "nearest")
        end
    end
end

ply.nowTextureMode = ""
ply.nowTexture = ply.texture.Default[1]--玩家当前图片

--//状态
ply.state = {
    maxStamina = 110,
    stamina = 110,

    stateName = "",--（会更改)只有fall 和 onground
    faceSide = "right",--player面朝的方向（会更改) left or right
    wallSide = "right",--碰到墙面对的方向（会更改) left or right
    dashTB = "top",--暂时未使用 top or botton or Nah

    dying = false,
    dyingDirection = 1,--1:左上，2:右上，3:左下，4:右下

    canMove = true,--//指左右移动，不包括跳跃与蹲下（会更改）start:true
    canJump = true,--//是否能执行Jump（不会更改）start:true
    canClimb = false,--//能否攀爬（会更改）start:false
    canSlide = false,--//能否滑墙（会更改）start:false
    canClimbJump = false,--//能否墙跳（会更改）start:false
    canDash = true,--//能否Dash（不会更改）start:true
    canNextDash = true,--//可以进行下一次的Dash（会更改）start:true

    onlyKick = false,--只进行踢墙跳（会更改）start:false

    onGround = false,--//如名（会更改) start:false
    IsSquat = false,--//如名（会更改) start:false
    IsDash = false,--//正在Dash中（与IsDash不同，会结束更慢）（会更改)start:false
    IsMoreDash = false,--//正在进行特殊类（会更改)Dash start:false
    IsDashDuring = false,--//正在Dash中（与IsDash不同，会结束更早）（会更改)start:false
    IsMove = false,--//如名（会更改) start:false
    IsForce = false,--//如名（会更改) start:false
    IsJumping = false,--//如名（会更改) start:false
    IsSlowDown = false,--//如名（会更改) start:false
    IsClimbing = false,--//如名（会更改) start:false
    IsPressClimbKey = false,--//如名（会更改) start:false
    IsSliding = false,--//如名（会更改) start:false
    IsFlipping = false,--//如名（会更改) start:false--仅在地面生效

    setDashTimes = 1,--//起始/恢复的Dash次数
    dashTimes = 1,--//目前的Dash次数（会更改)

    setClimbJumpTime = 0.25,--//设置的墙跳时间，期间禁止攀爬（会更改)
    climbJumpTimer = 0,--//墙跳时间（会更改)

    wallJumpFriction = 0,

    deadDistance = 12,

    shadowMode = 0,--0:blue 1:pink
}
--//速度参数
ply.speedSetting = {
    run = 90,--//如名
    runTime = 0.1,
    airTime = 0.138,
    jump = 105,--//如名
    normalDown = 160,
    fastDown = 240,
    wallJump = 105,--//如名
    wallJumpFriction = 500,--//这里的数值是减少的空气阻力
    wallKick = 145,--//如名
    wallbounce = 300,
    dash = 240,--//如名240

    anchorX_1 = 1.8,--普通跳跃
    anchorX_2 = 3.5,--爬墙跳
    anchorY = 2,
    wallkickRatio = 1.15
}
--//加速度参数
ply.accelerationSetting = {
    gravity = 900,
    slowGravity = 450,--//缓降
    overGravity = 300,--//按住下键

    groundMove = 600,
    groundMid = 500,
    groundSame = 400,

    airMove = 600,
    airSame = 260,
}

--//基础数据
ply.speed = M_vec.vec2(0,0)
ply.lastSpeedx = 0
ply.lastSpeedy = 0
ply.acceleration = M_vec.vec2(0,0)
ply.moveDirection = 0  --left is -1,right is +1
ply.position = M_vec.vec2(0,0)
ply.direction = M_vec.vec2(0,0)
ply.lastDashDirection = M_vec.vec2(0,0)
ply.lastDeadPosition = M_vec.vec2(0,0)

--死亡时间设置
ply.deadSetTime = 1
ply.deadTimer = 0
ply.deadPG = 0
--复活时间设置
ply.reviveSetTime = 0.75
ply.reviveTimer = 0
ply.revivePG = 0

--力的设置（实际上是速度）
ply.forceX = 0
ply.forceY = 0
--跳跃力度设置
ply.jumpStrengthTime = 0.15
ply.jumpStrength = 0--0.5~1
--跳跃时间设置 0.01677 ~ 1frame
ply.jumpingSetTime = 0.2
ply.walljumpingSetTime = 0.14
ply.jumpingTimer = 0
--//墙跳时间设置(会暂时减轻X轴上的空气阻力)
ply.wallJumpSetTime = 0.2
ply.wallJumpTimer = 0
--//狼跳时间设置
ply.coyoteSetTime = 0.08
ply.coyoteTimer = 0
--//延迟落地时间设置（废弃）
ply.groundSetTime = 0.1
ply.groundTimer = 0.1
--//Dash的时间设置（更新IsDash）
ply.dashSetTime = 0.25
ply.dashTimer = 0
--//Dash的时间设置（更新IsDashDuring）
ply.dashSetDuring = 0.15
ply.dashDuring = 0
--//恢复Dash的时间
ply.reDashSetTime = 0.01
ply.reDashTime = 0
--//开始Dash时的停顿时间--会暂停机关更新
ply.preDashSetTime = 0.04
ply.preDashTime = 0
--//恢复Dash时的闪烁效果
ply.dashTwinkSetTime = 0.08
ply.dashTwinkTimer = 0
--//Slide时的烟雾生成间隔
ply.slideSmokeSetTime = 0.04
ply.slideSmokeTime = 0
--//Dash时的Shadow设置
ply.shadowSetTime = 0.08--0.08秒生成一个
ply.shadowTimer = 0--计数器
ply.shadowLeaved = 0--剩余生成个数
--//SpeedCircle设置
ply.circleSetTime = 0.25--0.08秒生成一个
ply.circleTimer = 0--计数器
ply.circleLeaved = 0--剩余生成个数
--//力进行的时间（减少）
ply.forceTimer = 0
--//脚步声设置
ply.footStepSetTime = 0.375
ply.footStepTimer = ply.footStepSetTime
ply.lastFootStep = nil
--//转身动画设置
ply.flipSetTime = 0.03
ply.flipTimer = 0.03
ply.lastFlipDirection = 0--// -1: left 1:right
ply.flipDirection = 0 --// -1: left 1:right
--//帮助修正玩家位置次数设置
ply.fixMoveSetTimes = 1
ply.fixMoveTimes = 1


--//检测箱（不是碰撞箱）
ply.hitboxSize = {
    width = 6,
    height = 9,
    originWidth = 6,
    originHeight = 9,
    Dx = 0,--修正量
    Dy = 0,--修正量（使其位于底端）
}--one tile,type is CollisionBox
ply.hitboxVisible = false

--//像素存储
ply.subpixel = {
    x = 0,
    y = 0,
}

--碰撞箱
ply.collisionSize = {
    width = 8,
    height = 10,
    originWidth = 8,
    originHeight = 10,
    smolRatio = 2.5,--蹲下时对碰撞面积的缩放
}
ply.collisionVisible = false
ply.DetectorVisible = false

--Player的sprite缩放
ply.textureSize = {--下面自动读取上面的数据
    width = 8,
    height = 14,
    originWidth = 8,
    originHeight = 14,
    smolRatio = 1.75,--蹲下时对sprite面积的缩放
    Dx = 0,--修正量
    Dy = 0,--修正量（使其位于底端）
}

--动画设置
ply.animationSet = {
    groundSet = 2.5,--落地压缩
    ground = 0,
    squatSet = 1,--蹲下压缩系数
    squat = 0,
    squatTime = 0.08,

    dashParticalSet = 0.005,--在dash时0.005秒放出一个粒子
    dashPartical = 0,
}

ply.dashColor = {
    c1 = {R = 122,G = 255, B = 255},
    c2 = {R = 255,G = 102, B = 255},
}

--头发设置
ply.hair = {
    --颜色（L为亮色，D为暗色)
    NowColor = "Red",
    LRed = {0.85882353, 0.17254902, 0.17254902},
    DRed = {0.58039216, 0.18823529, 0.18823529},
    LBlue = {0.5, 1.0, 1.0},
    DBlue = {0.3, 0.9, 0.9},
    LPink = {1.0, 0.6, 1.0},
    DPink = {0.9, 0.5, 0.9},

    White = {1.0, 1.0, 1.0},

    --统一方向
    uniV = M_vec.vec2(0,0),

    --节点预飘动方向
    nowV1 = M_vec.vec2(0,0),nowV2 = M_vec.vec2(0,0),nowV3 = M_vec.vec2(0,0),
    nowV4 = M_vec.vec2(0,0),nowV5 = M_vec.vec2(0,0),nowV6 = M_vec.vec2(0,0),

    --节点实际飘动方向
    v1 = M_vec.vec2(0,0),v2 = M_vec.vec2(0,0),v3 = M_vec.vec2(0,0),
    v4 = M_vec.vec2(0,0),v5 = M_vec.vec2(0,0),v6 = M_vec.vec2(0,0),

    --圆间半径
    s1 = 3,s2 = 2.5,s3 = 2,s4 = 2,s5 = 2,s6 = 2,

    --第一个节点相对玩家位置的偏移位置
    Dy = 4,
    Dx = 0.25,
}

local function directionTranser(dx,Opp)--//数字转换方向（string）
    if dx > 0 then
        if Opp then
            return "left"
        else
            return "right"
        end
    elseif dx < 0 then
        if Opp then
            return "right"
        else
            return "left"
        end
    else
        return ""
    end
end

local function animationUpdater(dt)--动画更新机
    if ply.texture[ply.nowTextureMode] and not ply.state.dying and not ply.state.IsDashDuring then
        if ply.texture[ply.nowTextureMode].timer - dt < 0 then
            ply.texture[ply.nowTextureMode].timer = ply.texture[ply.nowTextureMode].setTime
            if ply.texture[ply.nowTextureMode].number >= #ply.texture[ply.nowTextureMode] then
                ply.texture[ply.nowTextureMode].number = 1
            else
                ply.texture[ply.nowTextureMode].number = ply.texture[ply.nowTextureMode].number + 1
            end
        else
            ply.texture[ply.nowTextureMode].timer = ply.texture[ply.nowTextureMode].timer - dt
        end
        ply.nowTexture = ply.texture[ply.nowTextureMode][ply.texture[ply.nowTextureMode].number]
    end
end
local function flipUpdater(dt,Reset)--转身更新机--包括重置
    if not Reset then
        if directionTranser(ply.speed.x) ~= ply.state.faceSide and not ply.state.IsFlipping and ply.flipDirection ~= ply.lastFlipDirection then--转身
            ply.state.IsFlipping = true
            ply.texture.Flip.number = 1
            if ply.speed.x > 0 then
                ply.flipDirection = -1
                ply.lastFlipDirection = -1
            elseif ply.speed.x < 0 then
                ply.flipDirection = 1
                ply.lastFlipDirection = 1
            end
        end
        
        if ply.state.IsFlipping then
            if ply.texture.Flip.number <= 5 and ply.flipDirection ~= ply.lastFlipDirection then--转身中途又转回来
                if ply.texture.Flip.number ~= 1 then
                    if ply.flipTimer - dt <= 0 then
                        ply.flipTimer = ply.flipSetTime
                        if ply.texture.Flip.number >= 2 then
                            ply.texture.Flip.number = ply.texture.Flip.number - 1
                        else
                            ply.state.IsFlipping = false
                        end
                    else
                        ply.flipTimer = ply.flipTimer - dt
                    end
                else
                    ply.state.IsFlipping = false
                end
            else--正常回转过程
                if ply.flipTimer - dt <= 0 then
                    ply.flipTimer = ply.flipSetTime
                    if ply.texture.Flip.number >= 8 then
                        ply.state.IsFlipping = false
                        ply.texture.Flip.number = 1
                    else
                        ply.texture.Flip.number = ply.texture.Flip.number + 1
                    end
                else
                    ply.flipTimer = ply.flipTimer - dt
                end
            end
        end
    else
        --//恢复原始设置
        ply.state.IsFlipping = false
        ply.flipTimer = ply.flipSetTime
        ply.texture.Flip.number = 1
    end
end
local function jellyUpdater()--果冻效果更新机
    --//玩家图片缩放
    local oriW = ply.textureSize.originWidth
    local oriH = ply.textureSize.originHeight
    local afterSmol =  ply.textureSize.originHeight/ply.textureSize.smolRatio
    local fallNum = 0
    if ply.speed.y < -239 then
        fallNum = 3
    elseif ply.speed.y < -200 then
        fallNum = 2
    elseif ply.speed.y < -159 then
        fallNum = 1
    end
    --下落与上升缩放

    if ply.speed.y > 0 and not ply.state.IsClimbing and not ply.state.IsSquat then
        if not ply.state.IsDash then
            ply.textureSize.width = math.max(oriW-3,math.min(oriW - 3*(ply.speed.y/150),oriW))
            ply.textureSize.height = math.max(oriH/2,math.min(oriH + 3*(ply.speed.y/150),oriH*2))
        else
            ply.textureSize.width = ply.textureSize.originWidth
            ply.textureSize.height =ply.textureSize.originHeight
        end
    else
        ply.textureSize.width = math.max(oriW-3,math.min(oriW - fallNum,oriW))
        ply.textureSize.height = math.max(oriH/2,math.min(oriH + fallNum,oriH*2))
    end
    ply.textureSize.Dy = ply.textureSize.height/2 - ply.collisionSize.height/2--让sprite的下底边与碰撞下底边重合
    --特殊动画缩放(针对落地与蹲下)--在上面基础上缩放
    local PG = (ply.animationSet.squatSet)
    if ply.state.onGround then
        --落地
        ply.textureSize.width = ply.textureSize.width + ply.animationSet.ground
        ply.textureSize.height = ply.textureSize.height - ply.animationSet.ground
        ply.textureSize.Dy = ply.textureSize.Dy - ply.animationSet.ground/4
    end
    --蹲下
    local t = bounce(ply.animationSet.squat)
    if ply.state.IsSquat and ply.state.onGround then--地面且蹲下
        ply.textureSize.height = nolimitLerp(ply.textureSize.originHeight,afterSmol,t)
        ply.textureSize.Dy = ply.textureSize.Dy - nolimitLerp(0,3.75,t)
    elseif not ply.state.IsSquat and ply.state.onGround then--地面且不蹲下
       ply.textureSize.height = nolimitLerp(ply.textureSize.originHeight,afterSmol,t)
        ply.textureSize.Dy = ply.textureSize.Dy - nolimitLerp(0,3.75,t)
    elseif ply.state.IsSquat and not ply.state.onGround then--不在地面且蹲下
        ply.textureSize.height = afterSmol
        ply.textureSize.Dy = ply.textureSize.Dy - 3.75
    end
end
local function hairUpdater(dt)--头发更新机
    --//颜色
    if ply.state.IsDashDuring then
        ply.hair.NowColor = "White"
        ply.dashTwinkTimer = ply.dashTwinkSetTime
    else
        if ply.state.onGround and ply.dashTwinkTimer ~= 0 then
            if ply.dashTwinkTimer - dt <= 0 then
                ply.dashTwinkTimer = 0
                ply.hair.NowColor = "White"
            else
                ply.dashTwinkTimer = ply.dashTwinkTimer - dt
                ply.hair.NowColor = "White"
            end
        else
            if ply.state.dashTimes < 1 then
                ply.hair.NowColor = "Blue"
            elseif ply.state.dashTimes < 2 then
                ply.hair.NowColor = "Red"
            else
                ply.hair.NowColor = "Pink"
            end
        end
    end
    --//轨迹

    ply.hair.uniV.x,ply.hair.uniV.y = math.max(-1,math.min(ply.speed.x/200,1)),math.max(-1,math.min(ply.speed.y/200,1))--里面的数字为根据速度大小的来变动的常数,这里为预惯性
    ply.hair.uniV.x,ply.hair.uniV.y = -ply.hair.uniV.x,-ply.hair.uniV.y
    if M_ply.speed.y == 0 then
        ply.hair.uniV.y = -0.5
    end
    
    local cX,cY = 0.05,0.08--阻尼系数
    local sX,sY = math.abs(ply.speed.x/400),math.abs(ply.speed.y/400)--里面的数字为根据速度大小的来变动的常数，实际惯性

    local floatSize = 0.5--头发上下飘动大小
    local floatSpeed = 4--头发上下飘动速度

    ply.hair.nowV1.x = numLerp(ply.hair.nowV1.x,ply.hair.uniV.x,cX + sX)
    ply.hair.nowV1.y = numLerp(ply.hair.nowV1.y,ply.hair.uniV.y,cY + sY)
    ply.hair.v1.x,ply.hair.v1.y = ply.hair.nowV1.x,ply.hair.nowV1.y

    for i = 2,6 do --距离计算：(ply.hair["s" .. i] + ply.hair["s" .. li])/2
        local li = i - 1
        ply.hair["nowV" .. i].x = numLerp(ply.hair["nowV" .. i].x,ply.hair.uniV.x,cX - li*0.005 + sX)
        ply.hair["nowV" .. i].y = numLerp(ply.hair["nowV" .. i].y,ply.hair.uniV.y,cY - li*0.005 + sY)
        ply.hair["v" .. i].x = ply.hair["v" .. li].x + ply.hair["nowV" .. i].x*(ply.hair["s" .. i] + ply.hair["s" .. li])/2
        ply.hair["v" .. i].y = ply.hair["v" .. li].y + ply.hair["nowV" .. i].y*(ply.hair["s" .. i] + ply.hair["s" .. li])/2 + math.sin(love.timer:getTime()*floatSpeed + li)*floatSize
    end
end
local function footStepUpdater(dt)--脚步声更新机
    if ply.state.onGround and ply.state.IsMove and not ply.state.IsSquat and not ply.state.IsFlipping then
        if ply.footStepTimer - dt < 0 then
            ply.footStepTimer = ply.footStepSetTime
            --暂停上一个脚步声
            if ply.lastFootStep then
                ply.lastFootStep:stop()
            end
            if sound.foot.stepNum >= 7 then
                sound.foot.stepNum = 1
            else
                sound.foot.stepNum = sound.foot.stepNum + 1
            end
            ply.lastFootStep = sound.foot.defalut[sound.foot.stepNum]
            if ply.anchor then
                if ply.anchor.properties.specific then--单向板
                    ply.lastFootStep = sound.foot.wood[sound.foot.stepNum]
                end
            end
            soundPlay(ply.lastFootStep)
        else
            ply.footStepTimer = ply.footStepTimer - dt
        end
    elseif ply.state.IsFlipping then
        ply.footStepTimer = 0
    end
end

function ply.restart()--//设置重设
    ply.anchor = nil; ply.lagTimer = 0

    ply.state.maxStamina = 100;ply.state.stamina = 100;

    ply.state.stateName = ""; ply.state.faceSide = "right"; ply.state.wallSide = "right"; ply.state.dashTB = "top";

    ply.state.dying = false;

    ply.state.canMove = true; ply.state.canJump = true; ply.state.canClimb = false; ply.state.canSlide = false;ply.state.canClimbJump = false; ply.state.canDash = true; ply.state.canNextDash = true;

    ply.state.onlyKick = false;

    ply.state.onGround = false; ply.state.IsSquat = false; ply.state.IsDash = false; ply.state.IsMoreDash = false; ply.state.IsDashDuring = false; ply.state.IsMove = false;
    ply.state.IsForce = false; ply.state.IsJumping = false; ply.state.IsSlowDown = false; ply.state.IsClimbing = false; ply.state.IsPressClimbKey = false; ply.state.IsSliding = false;

    ply.state.dashTimes = ply.state.setDashTimes; ply.climbJumpTimer = 0;

    ply.speed.x,ply.speed.y = 0,0; ply.lastSpeedx = 0
    ply.acceleration.x,ply.acceleration.y = 0,0 ; ply.moveDirection = 0
    ply.direction.x,ply.direction.y = 0,0 ; ply.lastDashDirection.x,ply.lastDashDirection.y = 0,0

    ply.forceX = 0; ply.forceY = 0; ply.jumpStrength = 0; ply.jumpingTimer = 0; 
    ply.coyoteTimer = 0; ply.groundTimer = 0.1; ply.dashTimer = 0; ply.dashDuring = 0; 
    ply.reDashTime = 0; ply.preDashTime = 0; ply.slideSmokeTime = 0; ply.shadowTimer = 0;
    ply.shadowLeaved = 0; ply.circleLeaved = 0; ply.circleTimer = 0; ply.forceTimer = 0;
    ply.footStepTimer = ply.footStepSetTime; ply.lastFlipDirection = 0; ply.flipDirection = 0;
    ply.fixMoveSetTimes = 1; ply.fixMoveTimes = 1

    ply.hitboxSize.width,ply.hitboxSize.height = ply.hitboxSize.originWidth,ply.hitboxSize.originHeight
    ply.hitboxSize.Dx,ply.hitboxSize.Dy = 0,0; ply.subpixel.x,ply.subpixel.y = 0,0;
    ply.collisionSize.width,ply.collisionSize.height = ply.collisionSize.originWidth,ply.collisionSize.originHeight;
    ply.textureSize.width,ply.textureSize.height = ply.textureSize.originWidth,ply.textureSize.originHeight;
    ply.textureSize.Dx,ply.textureSize.Dy = 0,0;

    ply.animationSet.ground,ply.animationSet.squat = 0,0;

    ply.hair.uniV.x,ply.hair.uniV.y = 0,0; 
    for i = 1,6 do
        ply.hair["nowV" .. i].x,ply.hair["nowV" .. i].y = 0,0
        ply.hair["v" .. i].x,ply.hair["v" .. i].y = 0,0
    end
end

local function dashRemove()--//Dash取消
    ply.state.IsDashDuring = false
    ply.state.IsDash = false
    ply.state.IsMoreDash = true
    ply.dashDuring = 0
    ply.dashTimer = 0
    ply.shadowLeaved = 0
    ply.shadowTimer = ply.shadowSetTime
end
local function anchorUpdater()--//跟随机关移动
    if ply.ISGAMING and ply.anchor and not ply.state.dying then
        --//同步移动
        if ply.anchor.lastPosition.x ~= M_phi.collisionGrid.point.x + ply.anchor.x then
            --//检测碰撞
            local tryx = ply.position.x + ((M_phi.collisionGrid.point.x + ply.anchor.x) - ply.anchor.lastPosition.x)
            local lpx = tryx - ply.collisionSize.width / 2
            local rpx = tryx + ply.collisionSize.width / 2
            local r_1 = M_phi.fromLAR(ply.position.y, lpx, rpx, ply.collisionSize.height / 2 - 1)
            local r_2 = M_phi.fromLAR(ply.position.y, lpx, rpx, ply.collisionSize.height / 2 - 1,true,ply.speed.x)
            if r_1 == nil and r_2 == nil then
                if not ply.state.IsClimbing and not ply.state.IsSliding then
                    ply.position.x = tryx
                else
                    if ply.state.faceSide == "left" then
                        ply.position.x = (M_phi.collisionGrid.point.x + ply.anchor.x) + ply.anchor.width + ply.collisionSize.width/2
                    elseif ply.state.faceSide == "right" then
                        ply.position.x = (M_phi.collisionGrid.point.x + ply.anchor.x) - ply.collisionSize.width/2
                    end
                end
            end
        end
        if ply.anchor then
            if ply.anchor.lastPosition.y ~= M_phi.collisionGrid.point.y - ply.anchor.y then
                ply.position.y = ply.position.y + ((M_phi.collisionGrid.point.y - ply.anchor.y) - ply.anchor.lastPosition.y)
            end
        end
    end
end
local function objDetector()--//机关推动玩家
    local lpx,rpx,info,obj
    --//X轴
    lpx = ply.position.x - ply.collisionSize.width / 2
    rpx = ply.position.x + ply.collisionSize.width / 2
    info,obj = M_phi.fromLAR(ply.position.y, lpx, rpx, ply.collisionSize.height / 2 - 1,true,ply.speed.x)
    if info ~= nil then
        ply.position.x = ply.position.x + ((M_phi.collisionGrid.point.x + obj.x) - obj.lastPosition.x)
    end
    --//Y轴
    lpx = ply.position.y + ply.collisionSize.height / 2
    rpx = ply.position.y - ply.collisionSize.height / 2
    info,obj = M_phi.fromBAT(ply.position.x, lpx, rpx, ply.collisionSize.width / 2 - 1,true,ply.speed.x)
    if info == true then--处在obj上面
        ply.position.y = ply.position.y + ((M_phi.collisionGrid.point.y - obj.y) - obj.lastPosition.y) - 2
    end
end
local function objActivater(obj)--//机关激活器
    if obj then
        if string.sub(obj.type,1,6) == "mover_" then
            if not obj.properties.specific then
                if obj.properties.bounce and not obj.properties.ING then--弹弹
                    obj.properties.getTimer = obj.properties.getTime/100
                    obj.properties.ING = true
                    obj.properties.direction.x = ply.position.x - (M_phi.collisionGrid.point.x + obj.properties.ox + obj.width/2)
                    obj.properties.direction.y = ply.position.y - (M_phi.collisionGrid.point.y - obj.properties.oy - obj.height/2)
                    obj.properties.direction.x,obj.properties.direction.y = M_vec.ToInputUnit(obj.properties.direction,12)
                elseif not obj.properties["repeat"] and not obj.properties.ING and not obj.properties.passive and obj.properties.origin then--普通
                    obj.properties.getTimer = obj.properties.getTime/100
                    obj.properties.waitTimer = obj.properties.wait/100
                    obj.properties.ING = true
                end
            end
        elseif string.sub(obj.type,1,8) == "trigger_" then--触发
            if obj.properties.objIndex then
                if not obj.properties.objIndex.properties.ING and not obj.properties.objIndex.properties["repeat"] and not obj.properties.objIndex.properties.bounce and obj.properties.objIndex.properties.passive and obj.properties.objIndex.properties.origin then
                    obj.properties.objIndex.properties.getTimer = obj.properties.objIndex.properties.getTime/100
                    obj.properties.objIndex.properties.waitTimer = obj.properties.objIndex.properties.wait/100
                    obj.properties.objIndex.properties.ING = true
                else
                end
            else
                dbg.warn("can't find the obj from trigger!")
            end
        end
    end
end
local function moveX(amount)--//X轴移动检测
    if amount == 0 then return 0 end

    local sign = amount > 0 and 1 or -1
    local absAmount = math.abs(amount)
    local tryx = ply.position.x + amount

    local lpx = tryx - ply.collisionSize.width / 2
    local rpx = tryx + ply.collisionSize.width / 2

    local fromObj = false

    --//优先检测地图块碰撞
    local result = M_phi.fromLAR(ply.position.y, lpx, rpx, ply.collisionSize.height / 2 - 1)
    --//如果为空，再检测对象块,并标记为对象类碰撞
    if result == nil then
        result = M_phi.fromLAR(ply.position.y, lpx, rpx, ply.collisionSize.height / 2 - 1, true,ply.speed.x)
        fromObj = true
    end

    if result == nil then
        ply.position.x = tryx
        return amount
    else
        --//回退寻找最大可行位移（使用二分法）
        local low, high = 0, absAmount
        local finalMove = 0

        while low <= high do
            local mid = math.floor((low + high) / 2)
            local testx = ply.position.x + sign * mid
            local test_lpx = testx - ply.collisionSize.width / 2
            local test_rpx = testx + ply.collisionSize.width / 2
            local test_result = M_phi.fromLAR(ply.position.y, test_lpx, test_rpx, ply.collisionSize.height / 2 - 1)

            if test_result == nil then
                test_result = M_phi.fromLAR(ply.position.y, test_lpx, test_rpx, ply.collisionSize.height / 2 - 1, true,ply.speed.x)
            end

            if test_result == nil then
                finalMove = mid
                low = mid + 1
            else
                high = mid - 1
            end
        end

        --//应用最大可行位移
        if finalMove > 0 then
            ply.position.x = math.floor(ply.position.x + sign * finalMove)
        end

        --//尝试修正
        local fix_d = 3
        local fix_lpx = ply.position.x - ply.collisionSize.width / 2 - 2
        local fix_rpx = ply.position.x + ply.collisionSize.width / 2 + 2
        local fix_result = nil--if is nil then can be fixed
        local fix_direction = nil--false : down; true : up
        
        if ply.fixMoveTimes > 0 and not ply.state.onGround then
            if not fromObj then--如果是从地图上碰撞
                fix_result = M_phi.fromLAR(ply.position.y + fix_d, fix_lpx, fix_rpx, ply.collisionSize.height / 2 - 1)
                if fix_result == nil then fix_direction = true; ply.fixMoveTimes = ply.fixMoveTimes - 1 end

                if fix_result ~= nil then 
                    fix_result = M_phi.fromLAR(ply.position.y - fix_d, fix_lpx, fix_rpx, ply.collisionSize.height / 2 - 1)
                    if fix_result == nil then fix_direction = false; ply.fixMoveTimes = ply.fixMoveTimes - 1 end
                end
            else--如果是从对象上碰撞
                fix_result = M_phi.fromLAR(ply.position.y + fix_d, fix_lpx, fix_rpx, ply.collisionSize.height / 2 - 1, true,ply.speed.x) 
                if fix_result == nil then fix_direction = true; ply.fixMoveTimes = ply.fixMoveTimes - 1 end

                if fix_result ~= nil then
                    fix_result = M_phi.fromLAR(ply.position.y - fix_d, fix_lpx, fix_rpx, ply.collisionSize.height / 2 - 1, true,ply.speed.x) 
                    if fix_result == nil then fix_direction = false; ply.fixMoveTimes = ply.fixMoveTimes - 1 end
                end
            end
        else
            fix_result = true
        end


        --碰撞响应
        if fix_result ~= nil then
            ply.circleLeaved = 0
            ply.forceTimer = 0
            ply.state.IsForce = false
            ply.speed.x = 0
        else
            if fix_direction == true then
                ply.position.y = ply.position.y + fix_d
                dbg.print("fix")
            elseif fix_direction == false then
                ply.position.y = ply.position.y - fix_d
            end
        end

        return sign * finalMove
    end
end
local function moveY(amount)--//Y轴移动检测
    local sign = amount > 0 and 1 or -1
    local moved = 0
    for i = 1, math.abs(amount) do
        local tryY = ply.position.y + sign
        local tpy = tryY + ply.collisionSize.height / 2
        local bpy = tryY - ply.collisionSize.height / 2
        --//检测地图块碰撞
        local result = M_phi.fromBAT(ply.position.x, tpy, bpy, ply.collisionSize.width / 2 - 1)
        local theAnchor,fromObj
        --//没有地图块则检测对象块碰撞
        if result == nil then
            result,theAnchor = M_phi.fromBAT(ply.position.x, tpy, bpy, ply.collisionSize.width / 2 - 1,true,ply.speed.y)
            fromObj = true
        end

        if result == nil then--啥也没碰
            ply.position.y = tryY
            ply.position.y = math.floor(ply.position.y)
            moved = moved + sign
        else
            if result == false then--碰到地面了
                --//anchor设置
                if ply.anchor == nil and theAnchor then
                    theAnchor.lastPosition.x = M_phi.collisionGrid.point.x + theAnchor.x
                    theAnchor.lastPosition.y = M_phi.collisionGrid.point.y - theAnchor.y
                    ply.anchor = theAnchor
                    --//激活机关
                    objActivater(theAnchor)
                end
                --//speedcircle重置
                if not ply.state.IsDash then
                    ply.circleLeaved = 0
                end
                ply.speed.y = 0
            else--顶到头了

                --//尝试修正
                local fix_d = 3
                local fix_tpy = ply.position.y + ply.collisionSize.height / 2 + 2
                local fix_result = false--if is false then can be fixed
                local fix_direction = nil--false : right; true : left
                
                if ply.fixMoveTimes > 0 and not ply.state.onGround then
                    if not fromObj then--如果是从地图上碰撞
                        fix_result = M_phi.fromTop(ply.position.x - fix_d, fix_tpy, ply.collisionSize.width / 2 - 1)
                        --dbg.print(tostring(fix_result))
                        if fix_result == false then fix_direction = true; ply.fixMoveTimes = ply.fixMoveTimes - 1 end

                        if fix_result ~= false then 
                            fix_result = M_phi.fromTop(ply.position.x + fix_d, fix_tpy, ply.collisionSize.width / 2 - 1)
                            if fix_result == false then fix_direction = false; ply.fixMoveTimes = ply.fixMoveTimes - 1 end
                        end
                    else--如果是从对象上碰撞
                        fix_result = M_phi.fromTop(ply.position.x - fix_d, fix_tpy, ply.collisionSize.width / 2 - 1,true)
                        if fix_result == false then fix_direction = true; ply.fixMoveTimes = ply.fixMoveTimes - 1 end

                        if fix_result ~= false then
                            fix_result = M_phi.fromTop(ply.position.x + fix_d, fix_tpy, ply.collisionSize.width / 2 - 1,true)
                            if fix_result == false then fix_direction = false; ply.fixMoveTimes = ply.fixMoveTimes - 1 end
                        end
                    end
                else
                    fix_result = true
                end
                
                if fix_result ~= false then
                    if not ply.state.IsDashDuring then
                        ply.speed.y = 0
                    end
                else
                    if fix_direction == true then
                        ply.position.x = ply.position.x - fix_d
                    elseif fix_direction == false then
                        ply.position.x = ply.position.x + fix_d
                    end
                end
                --[[重置Dash
                dashRemove()
                --]]
                
                --//重置y速度积累
                ply.lastSpeedy = 0
                --//speedcircle重置
                ply.circleLeaved = 0
                ply.state.IsJumping = false
                --ply.nowTextureMode = "Default"
            end
            break
        end
    end
    return moved
end
--[[
local function fixMove()--//帮助玩家偏移位置(已废弃)
    if not ply.state.onGround and ply.fixMoveTimes > 0 then--仅限滞空检测
        local w,h = ply.collisionSize.width/2 + 1,ply.collisionSize.height/2 + 1
        local hit = 0
        local p1,p2,p3,p4,_1x,_1y = M_phi.fixMoveDetector(
            ply.position.x - w,ply.position.y + h,--p1
            ply.position.x + w,ply.position.y + h,--p2
            ply.position.x - w,ply.position.y - h,--p3
            ply.position.x + w,ply.position.y - h--p4
        )--对应左上角，右上角，左下角，右下角
        if p1 then hit = hit + 1 end
        if p2 then hit = hit + 1 end
        if p3 then hit = hit + 1 end
        if p4 then hit = hit + 1 end

        dbg.print("d")
        
        if hit == 1 then
            if ply.speed.y > 0 then--只针对p1,p2
                if p1 and ply.speed.x > 0 then
                    ply.position.x = ply.position.x + 1
                    ply.fixMoveTimes = ply.fixMoveTimes - 1
                elseif p2 and ply.speed.x < 0 then
                    ply.position.x = ply.position.x - 1
                    ply.fixMoveTimes = ply.fixMoveTimes - 1
                end
            else--只针对p3,p4
                if p1 and ply.speed.x < 0 then
                    ply.position.y = ply.position.y - 1
                    ply.fixMoveTimes = ply.fixMoveTimes - 1
                elseif p2 and ply.speed.x > 0 then
                    ply.position.y = ply.position.y - 1
                    ply.fixMoveTimes = ply.fixMoveTimes - 1
                elseif p3 and ply.speed.x < 0 then
                    ply.position.y = ply.position.y + 1
                    ply.fixMoveTimes = ply.fixMoveTimes - 1
                elseif p4 and ply.speed.x > 0 then
                    ply.position.y = ply.position.y + 1
                    ply.fixMoveTimes = ply.fixMoveTimes - 1
                end
            end
        end
        
    end
end
--]]
local function squatRemove()--//移除下蹲
    if ply.state.IsSquat then
        local Cratio = ply.collisionSize.smolRatio--蹲下比例
        local oriW,oriH = ply.collisionSize.originWidth,ply.collisionSize.originHeight
        local ToTop = (oriH/Cratio)/2 + (oriH - oriH/Cratio)--计算蹲下后其上边与站起后的上边的距离
        if ply.collisionSize.height == oriH/Cratio and not M_phi.fromTop(ply.position.x, ply.position.y + ToTop, oriW/2,nil,true) and not M_phi.fromTop(ply.position.x, ply.position.y + ToTop, oriW/2,true,true) then
            ply.position.y = ply.position.y + (oriH - oriH/Cratio)/2--修正Y轴
            ply.collisionSize.height = oriH--恢复原高
            ply.hitboxSize.height = ply.hitboxSize.originHeight
            ply.state.IsSquat = false
            ply.state.canMove = true
        end
    end
end

local function checkpointUpdater(CHECKER,POINTER)--//检查点更新(与下面事件更新使用)
    --[[弃案(优化问题)
    CHECKER,POINTER = M_phi.checkpointDetector(
        ply.position.x - ply.hitboxSize.width/2,
        ply.position.y + ply.hitboxSize.height/2,
        ply.position.x + ply.hitboxSize.width/2,
        ply.position.y - ply.hitboxSize.height/2
    )
    --]]
    if CHECKER and ply.checkpoint ~= POINTER then
        ply.checkpoint = POINTER
        sound.effect.checkpoint:stop()
        sound.effect.checkpoint:seek(0)
        sound.effect.checkpoint:play()
        --dbg.print("checkpoint: " .. POINTER.name)
    end
end
local temp_vec2 = M_vec.vec2(0,0)
local function eventUpdater()--//事件更新/判断
    local R1,R2,R3 = false,"",""
    R1,R2,R3 = M_phi.eventDetector(
        ply.position.x - ply.hitboxSize.width/2,
        ply.position.y + ply.hitboxSize.height/2,
        ply.position.x + ply.hitboxSize.width/2,
        ply.position.y - ply.hitboxSize.height/2
    )
    if R1 and ply.ISGAMING then
        if R2 == "setDash0" and ply.state.setDashTimes ~= 0 then
            ply.state.setDashTimes = 0
            ply.state.dashTimes = 0
        elseif R2 == "setDash1" and ply.state.setDashTimes ~= 1 then
            ply.state.setDashTimes = 1
            ply.state.dashTimes = 1
        elseif R2 == "setDash2" and ply.state.setDashTimes ~= 2 then
            ply.state.setDashTimes = 2
            ply.state.dashTimes = 2
        elseif R2 == "changeMap" then
            if R3 ~= ply.changeMapFromPlayer then
                ply.changeMapFromPlayer = R3
            end
        elseif R2 == "changelevel" then

        elseif R2 == "refresh" then
            if not R3.properties.vanished then
                if ply.state.dashTimes == 0 or ply.state.stamina ~= ply.state.maxStamina then
                    R3.properties.timer = R3.properties.wait
                    R3.properties.vanished = true
                    ply.state.stamina = ply.state.maxStamina
                    if ply.state.dashTimes == 0 then
                        ply.state.dashTimes = 1
                    end
                    --//声效
                    soundPlay(sound.interaction["refresh_touch_0" .. math.random(1,3)])
                    --//白条特效
                    temp_vec2.x = M_phi.collisionGrid.point.x + R3.x + R3.width/2
                    temp_vec2.y = M_phi.collisionGrid.point.y - R3.y - R3.height/2
                    render.setDashLines(0,temp_vec2);render.setDashLines(1,temp_vec2)
                    render.setDashLines(2,temp_vec2);render.setDashLines(3,temp_vec2)
                    --//弯曲特效
                    render.setDashshader(temp_vec2,60,0.5)
                     --//晃动特效
                    M_cam.shaking.size = 30
                    M_cam.shaking.timer = 0.25
                    --//停滞时间
                    ply.lagTimer = ply.lagTimer + 0.04
                end
            end
        elseif R2 == "checkpoint" then
            checkpointUpdater(R1,R3)
        end
    end
end

local function smokeAdder(type,side)--//添加烟雾
    if not type then
        local smokeN = (-ply.speed.x)/200
        if ply.groundTimer > 0 then--起跳
            for i = 1,4 do
                render.setParticals("smoke",{x = 0 + -smokeN,y = 0.2},{x = ply.position.x - 1 ,y = ply.position.y - ply.collisionSize.height/2 + i/2},nil,1.25)
                render.setParticals("smoke",{x = 0 + -smokeN,y = 0.2},{x = ply.position.x + 1 ,y = ply.position.y - ply.collisionSize.height/2 + i/2},nil,1.25)
            end
            for i = 1,4 do
                render.setParticals("smoke",{x = -0.1 + -smokeN,y = 0},{x = ply.position.x - ply.collisionSize.width/4,y = ply.position.y - ply.collisionSize.height/3},nil,1.25)
                render.setParticals("smoke",{x = 0.1 + -smokeN,y = 0},{x = ply.position.x + ply.collisionSize.width/4,y = ply.position.y - ply.collisionSize.height/3},nil,1.25)
            end
        else--落地
            for i = 1,4 do
                render.setParticals("smoke",{x = -0.25 + smokeN,y = 0.25},{x = ply.position.x - ply.collisionSize.width/2,y = ply.position.y - ply.collisionSize.height/2})
                render.setParticals("smoke",{x = 0.25 + smokeN,y = 0.25},{x = ply.position.x + ply.collisionSize.width/2,y = ply.position.y - ply.collisionSize.height/2})
            end
            for i = 1,2 do
                render.setParticals("smoke",{x = 0 + smokeN,y = 0.1},{x = ply.position.x - ply.collisionSize.width/4,y = ply.position.y - ply.collisionSize.height/2},nil,1)
                render.setParticals("smoke",{x = 0 + smokeN,y = 0.1},{x = ply.position.x + ply.collisionSize.width/4,y = ply.position.y - ply.collisionSize.height/2},nil,1)
            end
        end
    elseif type == "slide" then
        if side == "l" then
            for i = 1,2 do
                render.setParticals("smoke",{x = 0,y = -0.1},{x = ply.position.x - ply.collisionSize.width/2,y = ply.position.y + ply.collisionSize.height/2},nil,1)
                render.setParticals("smoke",{x = 0,y = -0.1},{x = ply.position.x - ply.collisionSize.width/2,y = ply.position.y + ply.collisionSize.height/2},nil,1)
            end
        else
            for i = 1,2 do
                render.setParticals("smoke",{x = 0,y = -0.1},{x = ply.position.x + ply.collisionSize.width/2,y = ply.position.y + ply.collisionSize.height/2},nil,1)
                render.setParticals("smoke",{x = 0,y = -0.1},{x = ply.position.x + ply.collisionSize.width/2,y = ply.position.y + ply.collisionSize.height/2},nil,1)
            end
        end
    elseif type == "wallJump" then
        if side == "l" then
            for i = 1,4 do
                render.setParticals("smoke",{x = 0.1,y = -0.25},{x = ply.position.x - ply.collisionSize.width/2 + i/2,y = ply.position.y - ply.collisionSize.height/2},nil,1.25)
                render.setParticals("smoke",{x = 0.1,y = -0.1},{x = ply.position.x - ply.collisionSize.width/2 + i/2,y = ply.position.y - ply.collisionSize.height/2},nil,1.25)
            end
        else
            for i = 1,4 do
                render.setParticals("smoke",{x = -0.1,y = -0.25},{x = ply.position.x + ply.collisionSize.width/2 - i/2,y = ply.position.y - ply.collisionSize.height/2},nil,1.25)
                render.setParticals("smoke",{x = -0.1,y = -0.25},{x = ply.position.x + ply.collisionSize.width/2 - i/2,y = ply.position.y - ply.collisionSize.height/2},nil,1.25)
            end
        end
    end
end
local function shadowUpdater(dt)--//残影更新
    if ply.shadowLeaved > 0 then
        if ply.shadowTimer - dt <= 0 then
            ply.shadowLeaved = math.max(0,math.min(ply.shadowLeaved - 1,8))
            if ply.state.shadowMode == 0 then 
                render.setShadow(
                    ply.position,
                    ply.textureSize.width,ply.textureSize.height,
                    ply.textureSize.Dx,ply.textureSize.Dy,
                    ply.nowTexture,--image
                    ply.state.faceSide,
                    ply.dashColor.c1
                )
            else
                render.setShadow(
                    ply.position,
                    ply.textureSize.width,ply.textureSize.height,
                    ply.textureSize.Dx,ply.textureSize.Dy,
                    ply.nowTexture,--image
                    ply.state.faceSide,
                    ply.dashColor.c2
                )
            end
            ply.shadowTimer = ply.shadowSetTime
        else
            ply.shadowTimer = ply.shadowTimer - dt
        end
    else
        ply.shadowTimer = 0
    end
end
local function speedcircleUpdater(dt)--//速度圈圈更新
    if ply.circleLeaved > 0 then
        if ply.circleTimer - dt <= 0 then
            ply.circleLeaved = math.max(0,math.min(ply.circleLeaved - 1,8))
            ply.circleTimer = ply.circleSetTime
            --speedCircle
            if not ply.state.onGround then
                render.setSpeedcircle(ply.position,ply.speed)
            end
        else
            ply.circleTimer = ply.circleTimer - dt
        end
    else
        ply.circleTimer = 0
    end
end

function ply.directionUpdater()--//目前朝向方向在
    if ply.KeyDetector("up") then
        ply.direction.y = 1
    elseif ply.KeyDetector("down") then
        ply.direction.y = -1
    else
        ply.direction.y = 0
    end
    if ply.KeyDetector("left") then
        ply.direction.x = -1
    elseif ply.KeyDetector("right") then
        ply.direction.x = 1
    else
        ply.direction.x = 0
    end
    ply.direction.x,ply.direction.y = M_vec.ToUnit(ply.direction)
end
function ply.dash()--//预Dash阶段
    if ply.state.dashTimes > 0 and not ply.state.IsDash and ply.state.canNextDash then
        ply.state.canNextDash = false
        ply.preDashTime = ply.preDashSetTime

        --//Dash回复时间重制
        if ply.state.IsMoreDash then
            ply.reDashTime = ply.reDashSetTime
        else
            ply.reDashTime = ply.reDashSetTime
        end

        --//晃动特效
        M_cam.shaking.size = 15
        M_cam.shaking.timer = 0.2

        --//解除force作用
        ply.state.IsForce = false
        ply.state.forceTimer = 0
        ply.forceX = 0
        ply.forceY = 0

        --//解除在jumping时的作用
        ply.jumpingTimer = 0
        ply.state.IsJumping = false

        --//解除climb
        ply.state.IsClimbing = false

        --//继承速度
        ply.lastSpeedx = ply.speed.x
        if ply.speed.y > 0 then
            ply.lastSpeedy = ply.speed.y*0.2
        end
        --//sppedcircle
        --render.setSpeedcircle(
        --   ply.position,
        --    ply.speed,nil,40,2
        --)
        --//解除下蹲
        if not ply.state.onGround then
            squatRemove()
        end
        --//DD
        if ply.direction.x == 0 and ply.direction.y < 0 then
            local Cratio = ply.collisionSize.smolRatio--蹲下比例
            local oriW,oriH = ply.collisionSize.originWidth,ply.collisionSize.originHeight
            local ToTop = (oriH/Cratio)/2 + (oriH - oriH/Cratio)--计算蹲下后其上边与站起后的上边的距离
            if not ply.state.IsSquat then
                ply.position.y = ply.position.y - (oriH - oriH/Cratio)/2 + 2--修正Y轴(多加了2px)
                ply.state.IsSquat = true
                ply.state.canMove = false
            end
            ply.collisionSize.height = oriH/Cratio--对实际碰撞
            ply.hitboxSize.height = ply.hitboxSize.originHeight/8*3
        end

    end
end
local function playDashSound(direction)--//Dash声音播放
    if direction == "left" then
        if ply.state.dashTimes == 0 then
            soundPlay(sound.dash.Rleft,0.01)
        else
            soundPlay(sound.dash.Pleft,0.01)
        end
    else
        if ply.state.dashTimes == 0 then
            soundPlay(sound.dash.Rright,0.01)
        else
            soundPlay(sound.dash.Pright,0.01)
        end
    end
end
function ply.canToDash()--//Dash进行
    --Dash设置重置
    ply.dashTimer = ply.dashSetTime
    ply.dashDuring = ply.dashSetDuring
    ply.state.IsDash = true
    ply.state.canNextDash = false
    ply.state.dashTimes = ply.state.dashTimes - 1
    --Dash弯曲
    render.setDashshader(M_ply.position)
    --//改变sprite
    if ply.direction.y < 0 then
        ply.nowTexture = ply.texture.Dash[1]
    elseif ply.direction.y ~= -1 then
        ply.nowTexture = ply.texture.Dash[2]
    end
    --DashShadow
    ply.shadowLeaved = 3
    if ply.state.dashTimes == 0 then
        ply.state.shadowMode = 0
    else
        ply.state.shadowMode = 1
    end
    --重置speedcircle
    ply.circleLeaved = 0

    if ply.direction.x ~= 0 or ply.direction.y ~= 0 then
        if ply.state.onGround and ply.state.IsSquat then--蹲下向左右Dash
            ply.direction.y = 0
            ply.speed.x,ply.speed.y = M_vec.NmVec2(ply.direction,ply.speedSetting.dash*1.5)
            if ply.anchor and ply.direction.y == -1 then--防止在移动块上撞地猝死
                ply.speed.y = 30
            end
        else
            if ply.direction.y == 0 then--水平
                ply.speed.x,ply.speed.y = M_vec.NmVec2(ply.direction,ply.speedSetting.dash)
            else--斜水平
                ply.speed.x,ply.speed.y = M_vec.NmVec2(ply.direction,ply.speedSetting.dash)
                if ply.anchor and ply.direction.y == -1 then--防止在移动块上撞地猝死
                    ply.speed.y = 30
                end
            end
        end
        --//速度继承（只要不是直接向上或向下都可以继承）
        if ply.direction.y ~= 1 and ply.direction.y ~= -1 and ply.direction.x ~= 0 and math.abs(ply.lastSpeedx) > ply.speedSetting.dash*1.2 then
            ply.speed.x = ply.speed.x + math.abs(ply.lastSpeedx)*M_mat.direction(ply.speed.x)
        end
        --[[
        if ply.direction.y == -1 then--加强一下向下dash力度
            ply.speed.y = ply.speed.y
            dbg.print("down")
        end
        ]]
        --//设置上次Dash方向
        ply.lastDashDirection.x,ply.lastDashDirection.y = ply.direction.x,ply.direction.y

        if ply.direction.x < 0 then
            playDashSound("left")
        else
            playDashSound("right")
        end
        --设置Dash线条特效
        if ply.direction.x == 0 and ply.direction.y ~= 0 then
            render.setDashLines(0,ply.position)--上下
        elseif ply.direction.y == 0 and ply.direction.x ~= 0 then
            render.setDashLines(1,ply.position)--左右
        elseif (ply.direction.y > 0 and ply.direction.x > 0) or (ply.direction.y < 0 and ply.direction.x < 0) then
            render.setDashLines(2,ply.position)--右上,左下
        elseif (ply.direction.y > 0 and ply.direction.x < 0) or (ply.direction.y < 0 and ply.direction.x > 0) then
            render.setDashLines(3,ply.position)--左上,左下
        end
    else--没有按方向键
        render.setDashLines(1,ply.position)--左右
        if ply.state.faceSide == "left" then
            playDashSound("left")
            ply.lastDashDirection.x,ply.lastDashDirection.y = -1,0
            ply.speed.x,ply.speed.y = M_vec.NmVec2({x = -1,y = 0},ply.speedSetting.dash*1.2)
        else
            playDashSound("right")
            ply.lastDashDirection.x,ply.lastDashDirection.y = 1,0
            ply.speed.x,ply.speed.y = M_vec.NmVec2({x = 1,y = 0},ply.speedSetting.dash*1.2)
        end
    end
    --//取消尝试在机关上下冲
    if ply.anchor and ply.lastDashDirection.y == -1 then
        dashRemove()
    end
end
function ply.dashUpdate(dt)--//Dash更新
    --//时间刷新
    if ply.dashTimer > 0 then

        ply.dashTimer = ply.dashTimer - dt
    else
        ply.dashTimer = 0
        if ply.state.IsDash then
            --//改变sprite
            ply.nowTextureMode = "Default"

            ply.state.IsDash = false
        end
    end

    --//已经启动Dash，判断是否能Dash
    if ply.preDashTime > 0 then
        ply.preDashTime = ply.preDashTime - dt
        ply.speed.x,ply.speed.y = 0,0
    else
        ply.preDashTime = 0
        if ply.state.canNextDash == false then

            ply.canToDash()

            ply.state.canNextDash = true
        end
    end

    --//落地重置速度继承
    if ply.state.onGround and not ply.state.IsDash then
        ply.lastSpeedx = 0
    end

    if ply.dashDuring > 0 then
        ply.state.IsDashDuring = true
        ply.dashDuring = ply.dashDuring - dt
        --//Dash时的粒子效果
        if ply.animationSet.dashPartical == 0 then
            ply.animationSet.dashPartical = ply.animationSet.dashParticalSet
            
            if ply.state.dashTimes == 0 then
                render.setParticals("dash1",ply.lastDashDirection,ply.position)
                render.setParticals("dash1",ply.lastDashDirection,ply.position)
            else
                render.setParticals("dash2",ply.lastDashDirection,ply.position)
                render.setParticals("dash2",ply.lastDashDirection,ply.position)
            end
        else
            ply.animationSet.dashPartical = math.max(0,math.min(ply.animationSet.dashPartical - dt,ply.animationSet.dashParticalSet))
        end
        --//回复Dash2(预恢复)
        if ply.dashDuring < 0.04 then
            if ply.state.onGround then
                if ply.reDashTime > 0 then
                    ply.reDashTime = ply.reDashTime - dt
                end
            end
            if ply.state.onGround then
                if ply.reDashTime <= 0 then
                    ply.state.dashTimes = ply.state.setDashTimes
                    ply.state.IsMoreDash = false
                end
            end
        end

    else
        --//回复Dash1
        if ply.state.onGround then
            if ply.reDashTime > 0 then
                ply.reDashTime = ply.reDashTime - dt
            end
        end
        if ply.state.onGround then
            if ply.reDashTime <= 0 then
                ply.state.dashTimes = ply.state.setDashTimes
                ply.state.IsMoreDash = false
            end
        end

        ply.dashDuring = 0
        --//Dash结束时
        if ply.state.IsDashDuring then
            ply.state.IsDashDuring = false
            if ply.lastDashDirection.x ~= 0 then
                if ply.state.faceSide == "left" then
                    --//速度放下
                    if math.abs(ply.lastSpeedx) <= ply.speedSetting.dash*1.2 then
                        ply.speed.x = -ply.speedSetting.run
                    else
                        ply.speed.x = -math.abs(ply.lastSpeedx)-- -ply.speedSetting.run
                    end
                else
                    --//速度放下
                    if math.abs(ply.lastSpeedx) <= ply.speedSetting.dash*1.2 then
                        ply.speed.x = ply.speedSetting.run
                    else
                        ply.speed.x = math.abs(ply.lastSpeedx)--ply.speedSetting.run
                    end
                end
                --//统一转身
                if ply.lastDashDirection.x > 0 then
                    ply.flipDirection = 1
                elseif ply.lastDashDirection.x < 0 then
                    ply.flipDirection = -1
                else
                    ply.flipDirection = 0
                end
            end
            ply.speed.y = 100 * M_mat.direction(ply.lastDashDirection.y)
            --//解除下蹲
            if not ply.state.onGround then
                squatRemove()
            end
        end
    end
end
function ply.forceUpdate(dt)--//力更新
    if ply.forceTimer > 0 then
        if not ply.state.IsForce then
            ply.state.IsForce = true
        end
        ply.forceTimer = ply.forceTimer - dt
    else
        ply.forceTimer = 0
        if ply.state.IsForce then
            local speedTempX = math.abs(ply.speed.x)
            ply.state.IsForce = false
            ply.speed.x = ply.lastDashDirection.x*speedTempX*1.2
        end
    end
end

function ply.MoveL()--//向左移动趋向
    if not ply.state.IsDashDuring then--Dash时不做响应
        ply.state.IsMove = true
        if not ply.state.IsClimbing then
            ply.state.faceSide = "left"
        end
        if ply.state.canMove then--是否蹲下了
            if ply.state.onGround then--是否碰到地面
                ply.moveDirection = -1--在地面时的方向
            else
                ply.moveDirection = -1--在空中时的方向
            end
        elseif not ply.state.canMove and not ply.state.onGround then--蹲下状态在空中的状态
            ply.moveDirection = -1
        else
            ply.moveDirection = 0
        end
        --转身
        ply.lastFlipDirection = -1
    end
end
function ply.MoveR()--//向右移动趋向
     if not ply.state.IsDashDuring then--Dash时不做响应
        ply.state.IsMove = true
        if not ply.state.IsClimbing then
            ply.state.faceSide = "right"
        end
        if ply.state.canMove then--是否蹲下了
            if ply.state.onGround then--是否碰到地面
                ply.moveDirection = 1--在地面时的方向
            else
                ply.moveDirection = 1--在空中时的方向
            end
        elseif not ply.state.canMove and not ply.state.onGround then--蹲下状态在空中的状态
            ply.moveDirection = 1
        else
            ply.moveDirection = 0
        end
        --转身
        ply.lastFlipDirection = 1
    end
end
function ply.MoveS()--//停止移动
    ply.moveDirection = 0
    ply.state.IsMove = false
end

local function wallDetect()--//墙体检测
    local r,notClimb,theAnchor

    --墙跳（不包括爬墙,滑墙））
    if M_phi.fromLeft(ply.position.y,ply.position.x - ply.collisionSize.width/2 - 3,ply.collisionSize.height/2 - 0.5) then
        ply.state.canClimbJump = true
        ply.state.wallSide = "left"
    elseif M_phi.fromRight(ply.position.y,ply.position.x + ply.collisionSize.width/2 + 3,ply.collisionSize.height/2 - 0.5) then
        ply.state.canClimbJump = true
        ply.state.wallSide = "right"
    else
        --//对对象碰撞检测
        r,notClimb,theAnchor = M_phi.fromLeft(ply.position.y,ply.position.x - ply.collisionSize.width/2 - 3,ply.collisionSize.height/2 - 0.5,false,true)
        if r then
            ply.state.canClimbJump = true
            ply.state.wallSide = "left"
        else
            r,notClimb,theAnchor = M_phi.fromRight(ply.position.y,ply.position.x + ply.collisionSize.width/2 + 3,ply.collisionSize.height/2 - 0.5,false,true)
            if r then
                ply.state.canClimbJump = true
                ply.state.wallSide = "right"
            else--无碰撞结果
                ply.state.canClimbJump = false
                ply.state.wallSide = ""
            end
        end
    end
    --爬墙/滑墙
    if M_phi.fromLeft(ply.position.y,ply.position.x - ply.collisionSize.width/2 - 1,ply.collisionSize.height/2 - 1) then
        ply.state.canClimb = true
        ply.state.canSlide = true
    elseif M_phi.fromRight(ply.position.y,ply.position.x + ply.collisionSize.width/2 + 1,ply.collisionSize.height/2 - 1) then
        ply.state.canClimb = true
        ply.state.canSlide = true
    else
        --//对对象碰撞检测
        r,notClimb,theAnchor = M_phi.fromLeft(ply.position.y,ply.position.x - ply.collisionSize.width/2 - 1,ply.collisionSize.height/2 - 1,false,true)
        if r then--左边
            if notClimb then
                ply.state.canClimb = false
                ply.state.onlyKick = true
            else
                ply.state.onlyKick = false
                ply.state.canClimb = true
            end
            ply.state.canSlide = true
        else
            r,notClimb,theAnchor = M_phi.fromRight(ply.position.y,ply.position.x + ply.collisionSize.width/2 + 1,ply.collisionSize.height/2 - 1,false,true)
            if r then--右边
                if notClimb then
                    ply.state.canClimb = false
                    ply.state.onlyKick = true
                else
                    ply.state.onlyKick = false
                    ply.state.canClimb = true
                end
                ply.state.canSlide = true
            else--无碰撞结果
                ply.state.canClimb = false
                ply.state.canSlide = false
                ply.state.onlyKick = false
            end
        end
        --//设置锚点
        if theAnchor and (ply.state.IsClimbing or ply.state.IsSliding) and ply.anchor ~= theAnchor then
            theAnchor.lastPosition.x = M_phi.collisionGrid.point.x + theAnchor.x
            theAnchor.lastPosition.y = M_phi.collisionGrid.point.y - theAnchor.y
            ply.anchor = theAnchor
        end
        --//激活
        if theAnchor and ply.state.IsClimbing then
            objActivater(theAnchor)
        end
    end

end
local function toSlide(dt)--//滑墙
    if ply.state.wallSide == "left" and ply.direction.x < 0 and not ply.state.IsDash and not ply.state.IsClimbing and not ply.state.onGround and not ply.state.IsSquat and ply.state.canSlide and ply.speed.y <= 0 then
        --//重置y轴速度
        if not ply.state.IsSliding then
            ply.speed.y = 0
        end
        ply.state.IsSliding = true
        if not sound.wall.Sliding:isPlaying() then
            sound.wall.Sliding:play()
        end
        if ply.slideSmokeTime + dt >= ply.slideSmokeSetTime then
            ply.slideSmokeTime = 0
            smokeAdder("slide","l")
        else
            ply.slideSmokeTime = ply.slideSmokeTime + dt
        end
    elseif ply.state.wallSide == "right" and ply.direction.x > 0 and not ply.state.IsDash and not ply.state.IsClimbing and not ply.state.onGround and not ply.state.IsSquat and ply.state.canSlide and ply.speed.y <= 0 then
        --//重置y轴速度
        if not ply.state.IsSliding then
            ply.speed.y = 0
        end
        ply.state.IsSliding = true
        if not sound.wall.Sliding:isPlaying() then
            sound.wall.Sliding:play()
        end
        if ply.slideSmokeTime + dt >= ply.slideSmokeSetTime then
            ply.slideSmokeTime = 0
            smokeAdder("slide","r")
        else
            ply.slideSmokeTime = ply.slideSmokeTime + dt
        end
    else
        if not ply.state.IsClimbing then
            sound.wall.Sliding:stop()
        end
        ply.state.IsSliding = false
    end
end
local function toClimb(dt)--//爬墙
    if ply.state.wallSide == "left" and ply.state.faceSide == "left" and ply.state.IsPressClimbKey and ply.state.stamina > 0 and ply.state.climbJumpTimer == 0 and ply.state.canClimb and not ply.state.IsSquat and ply.state.canClimb and not (ply.state.IsDash and ply.lastDashDirection.y == 1) then
        ply.state.IsClimbing = true
        ply.speed.x = 0
        ply.state.stamina = math.max(0,math.min(ply.state.stamina - ply.state.maxStamina/4*dt,ply.state.maxStamina))
        --//Dash取消
        if ply.state.IsDash then dashRemove() end
    elseif ply.state.wallSide == "right" and ply.state.faceSide == "right" and ply.state.IsPressClimbKey and ply.state.stamina > 0 and ply.state.climbJumpTimer == 0 and ply.state.canClimb and not ply.state.IsSquat and ply.state.canClimb and not (ply.state.IsDash and ply.lastDashDirection.y == 1) then
        ply.state.IsClimbing = true
        ply.speed.x = 0
        ply.state.stamina = math.max(0,math.min(ply.state.stamina - ply.state.maxStamina/4*dt,ply.state.maxStamina))
        --//Dash取消
        if ply.state.IsDash then dashRemove() end
    else
        if ply.state.IsClimbing then
            ply.speed.y = ply.speed.y + 20
        end
        ply.state.IsClimbing = false
    end
    if ply.state.IsClimbing then
        if ply.KeyDetector("up") then
            ply.speed.y = 35
            if sound.wall.Sliding:isPlaying() then
                sound.wall.Sliding:stop()
            end
        elseif ply.KeyDetector("down") then
            ply.speed.y = -45
            --//烟
            if not sound.wall.Sliding:isPlaying() then
                sound.wall.Sliding:play()
            end
            if ply.state.wallSide == "left" then
                if ply.slideSmokeTime + dt >= ply.slideSmokeSetTime then
                    ply.slideSmokeTime = 0
                    smokeAdder("slide","l")
                else
                    ply.slideSmokeTime = ply.slideSmokeTime + dt
                end
            else
                if ply.slideSmokeTime + dt >= ply.slideSmokeSetTime then
                    ply.slideSmokeTime = 0
                    smokeAdder("slide","r")
                else
                    ply.slideSmokeTime = ply.slideSmokeTime + dt
                end
            end
        else
            ply.speed.y = 0
            if sound.wall.Sliding:isPlaying() then
                sound.wall.Sliding:stop()
            end
        end
    end

    if ply.state.climbJumpTimer - dt < 0 then
        ply.state.climbJumpTimer = 0
    else
        ply.state.climbJumpTimer = ply.state.climbJumpTimer - dt
    end
end
local function walljump()
    if ply.state.IsPressClimbKey and not ply.state.IsSquat and ply.state.stamina ~= 0 and directionTranser(ply.direction.x,true) ~= ply.state.wallSide and ply.state.canClimbJump and not ply.state.onlyKick then--是否为直上墙跳
        --检查是否在anchor上
        local anchorSpeedY,anchorSpeedX
        if ply.anchor then
            anchorSpeedX =  math.max(-600,math.min(((M_phi.collisionGrid.point.x + ply.anchor.x) - ply.anchor.lastPosition.x)/0.016*ply.speedSetting.anchorX_2,600))
            anchorSpeedY = math.max(0, ((M_phi.collisionGrid.point.y - ply.anchor.y) - ply.anchor.lastPosition.y)/0.016*ply.speedSetting.anchorY)
        end
        --//Dash取消
        dashRemove()
        
        --//惯性水平速度
        if anchorSpeedX then
            --//设置speedcircle
            if math.abs(anchorSpeedX) > 400 then
                ply.circleTimer = 0.1
                ply.circleLeaved = ply.circleLeaved + 2
            elseif math.abs(anchorSpeedX) > 200 then
                ply.circleTimer = 0.1
                ply.circleLeaved = ply.circleLeaved + 1
            end
            ply.speed.x = ply.speed.x + anchorSpeedX
        end
        if anchorSpeedY == 0 or anchorSpeedY == nil then
            --//正常跳跃
            ply.jumpingTimer = ply.walljumpingSetTime
            ply.state.IsJumping = true
        else
            --//惯性跳跃
            if anchorSpeedY > 260 then
                ply.circleTimer = 0.1
                ply.circleLeaved = ply.circleLeaved + 2
            elseif anchorSpeedY > 160 then
                ply.circleTimer = 0.1
                ply.circleLeaved = ply.circleLeaved + 1
            end
            ply.speed.y = ply.speedSetting.jump + anchorSpeedY
        end
        ply.anchor = nil
        ply.state.onGround = false
        --//减体力
        ply.state.stamina = math.max(0, ply.state.stamina - 27.5)
        --//改变方向
        if ply.state.wallSide == "left" then
            ply.state.faceSide = "left"
            smokeAdder("wallJump","l")
        else
            ply.state.faceSide = "right"
            smokeAdder("wallJump","r")
        end
        
        if ply.circleLeaved == 0 then
            soundPlay(sound.jump.NormalJump,0.001)
        else
            soundPlay(sound.jump.SuperSlide,0.001)
        end
    else--[][][][][][][][][][][][][][]正常左右墙跳
        --//Dash取消
       dashRemove()

        --//取消爬行
        ply.state.IsClimbing = false
        local anchorSpeedY,anchorSpeedX
        if ply.anchor then
            anchorSpeedX =  math.max(-600,math.min(((M_phi.collisionGrid.point.x + ply.anchor.x) - ply.anchor.lastPosition.x)/0.016*ply.speedSetting.anchorX_2,600))
            anchorSpeedY = math.max(0, ((M_phi.collisionGrid.point.y - ply.anchor.y) - ply.anchor.lastPosition.y)/0.016*ply.speedSetting.anchorY)
        end
        --//Y轴上的速度
        if anchorSpeedY == 0 or anchorSpeedY == nil then
            --//正常跳跃
            ply.jumpingTimer = ply.walljumpingSetTime
            ply.state.IsJumping = true
        else
            --//惯性跳跃
            if anchorSpeedY > 260 then
                ply.circleTimer = 0.1
                ply.circleLeaved = ply.circleLeaved + 2
            elseif anchorSpeedY > 160 then
                ply.circleTimer = 0.1
                ply.circleLeaved = ply.circleLeaved + 1
            end
            ply.speed.y = ply.speedSetting.jump + anchorSpeedY
        end
        
        --//设置墙跳阻力
        ply.wallJumpTimer = ply.wallJumpSetTime
        --//看方向设置属性
        if ply.state.wallSide == "left" then------------------------左边
            smokeAdder("wallJump","l")
            --//改变方向
            ply.state.faceSide = "right"
            --//播放声效
            soundPlay(sound.jump.LwallJump,0.001)
            --//设置X轴速度
            if anchorSpeedX then
                if math.abs(anchorSpeedX) > ply.speedSetting.wallKick then
                    --//惯性水平速度
                    if anchorSpeedX then
                        --//设置speedcircle
                        if math.abs(anchorSpeedX) > 400 then
                            ply.circleTimer = 0.1
                            ply.circleLeaved = ply.circleLeaved + 2
                        elseif math.abs(anchorSpeedX) > 200 then
                            ply.circleTimer = 0.1
                            ply.circleLeaved = ply.circleLeaved + 1
                        end
                        ply.speed.x = ply.speed.x + anchorSpeedX
                    end
                else--//正常
                    if ply.KeyDetector("left") then--中性跳
                        ply.speed.x = ply.speedSetting.wallKick*ply.speedSetting.wallkickRatio
                    else
                        ply.speed.x = ply.speedSetting.wallKick
                    end
                end
            else--//正常
                if ply.KeyDetector("left") then--中性跳
                    ply.speed.x = ply.speedSetting.wallKick*ply.speedSetting.wallkickRatio
                else
                    ply.speed.x = ply.speedSetting.wallKick
                end
            end
            --//解除锚定
            ply.anchor = nil
        else--------------------------------------------------------右边
            smokeAdder("wallJump","r")
            ply.state.faceSide = "left"
            --//播放声效
            soundPlay(sound.jump.RwallJump,0.001)
            --//设置X轴速度
            if anchorSpeedX then
                if math.abs(anchorSpeedX) > ply.speedSetting.wallKick then
                    --//设置speedcircle
                    if math.abs(anchorSpeedX) > 400 then
                        ply.circleTimer = 0.1
                        ply.circleLeaved = ply.circleLeaved + 2
                    elseif math.abs(anchorSpeedX) > 200 then
                        ply.circleTimer = 0.1
                        ply.circleLeaved = ply.circleLeaved + 1
                    end
                    ply.speed.x = ply.speed.x + anchorSpeedX
                
                else--//正常
                    if ply.KeyDetector("right") then--中性跳
                        ply.speed.x = -ply.speedSetting.wallKick*ply.speedSetting.wallkickRatio
                    else
                        ply.speed.x = -ply.speedSetting.wallKick
                    end
                end
            else--//正常
                if ply.KeyDetector("right") then--中性跳
                    ply.speed.x = -ply.speedSetting.wallKick*ply.speedSetting.wallkickRatio
                else
                    ply.speed.x = -ply.speedSetting.wallKick
                end
            end
            --//解除锚定
            ply.anchor = nil
        end
        --//额外声效
        if ply.circleLeaved ~= 0 then soundPlay(sound.jump.SuperSlide,0.001) end
    end
end
local function forceAdder(time,size)
    ply.forceTimer = time or 0.4
    size = size or 200
    if ply.KeyDetector("left") then
        if math.abs(ply.lastSpeedx) < size then
            ply.forceX = -size --- math.abs(ply.lastSpeedx)*0.2
        else
            ply.forceX = -math.abs(ply.lastSpeedx)*1.2
        end
        ply.lastDashDirection.x = -1
    elseif ply.KeyDetector("right") then
        if math.abs(ply.lastSpeedx) < size then
            ply.forceX = size --+ math.abs(ply.lastSpeedx)*0.2
        else
            ply.forceX = math.abs(ply.lastSpeedx)*1.2
        end
        ply.lastDashDirection.x = 1
    elseif ply.state.faceSide == "left" then
        if math.abs(ply.lastSpeedx) < size then
            ply.forceX = -size --- math.abs(ply.lastSpeedx)*0.2
        else
            ply.forceX = -math.abs(ply.lastSpeedx)*1.2
        end
        ply.lastDashDirection.x = -1
    else
        if math.abs(ply.lastSpeedx) < size then
            ply.forceX = size --+ math.abs(ply.lastSpeedx)*0.2
        else
            ply.forceX = math.abs(ply.lastSpeedx)*1.2
        end
        ply.lastDashDirection.x = 1
    end
end
function ply.Jump()--//跳跃相关
    if ply.state.canJump then
        if ply.state.onGround or ply.coyoteTimer ~= 0 and not ply.state.IsJumping then--地面跳
            --检查是否在anchor上
            local anchorSpeedY,anchorSpeedX
            if ply.anchor then
                anchorSpeedX = math.max(-600,math.min(((M_phi.collisionGrid.point.x + ply.anchor.x) - ply.anchor.lastPosition.x)/0.016*ply.speedSetting.anchorX_1,600)) 
                anchorSpeedY = math.max(0, ((M_phi.collisionGrid.point.y - ply.anchor.y) - ply.anchor.lastPosition.y)/0.016*ply.speedSetting.anchorY)
            end
            if anchorSpeedX == nil then anchorSpeedX = 0 end
            if anchorSpeedY == nil then anchorSpeedY = 0 end
            if not ply.state.IsDashDuring and not ply.state.IsDash then
                --//在狼跳时重新添加烟雾
                if ply.coyoteTimer ~= ply.coyoteSetTime then
                    smokeAdder()
                end
                --//惯性水平速度
                if anchorSpeedX then
                    --//设置speedcircle
                    if math.abs(anchorSpeedX) > 400 then
                        ply.circleTimer = 0.1
                        ply.circleLeaved = ply.circleLeaved + 2
                    elseif math.abs(anchorSpeedX) > 200 then
                        ply.circleTimer = 0.1
                        ply.circleLeaved = ply.circleLeaved + 1
                    end
                    ply.speed.x = ply.speed.x + anchorSpeedX
                end
                ply.speed.x = ply.speed.x + ply.moveDirection*40
                
                if anchorSpeedY < ply.speedSetting.jump then
                    --//正常跳跃
                    ply.jumpingTimer = ply.jumpingSetTime
                    ply.state.IsJumping = true
                else
                    --//惯性跳跃
                    if anchorSpeedY > 260 then
                        ply.circleTimer = 0.1
                        ply.circleLeaved = ply.circleLeaved + 2
                    elseif anchorSpeedY > 160 then
                        ply.circleTimer = 0.1
                        ply.circleLeaved = ply.circleLeaved + 1
                    end
                    ply.speed.y = ply.speedSetting.jump + anchorSpeedY
                end
                ply.state.onGround = false
                if ply.circleLeaved == 0 then
                    soundPlay(sound.jump.NormalJump,0.001)
                else
                    soundPlay(sound.jump.SuperSlide,0.001)
                end
            elseif ply.state.IsDash and (ply.state.onGround or ply.coyoteTimer ~= 0) and ply.lastDashDirection.x ~= 0 and ply.lastDashDirection.y == 0 and not ply.state.IsSquat then--super
                smokeAdder()
                local super = 160
                ply.speed.y = 210 + ply.lastSpeedy + anchorSpeedY
                ply.state.onGround = false
                --//Dash取消
                dashRemove()

                --//设置speedcircle
                ply.circleTimer = ply.circleSetTime
                ply.circleLeaved = 3
                --DashShadow
                ply.shadowTimer = ply.shadowSetTime
                ply.shadowLeaved = 2
                --//Force设置
                forceAdder(0.4,super)
                ply.forceX = ply.forceX + anchorSpeedX
                --//播放声效
                soundPlay(sound.jump.NormalJump,0.001)
                soundPlay(sound.jump.SuperSlide,0.001)
            elseif ply.state.IsDash and (ply.state.onGround or ply.coyoteTimer ~= 0) and ply.lastDashDirection.x ~= 0 and not ply.state.IsSquat then--wavedash
                smokeAdder()
                local wavedash = 230
                ply.speed.y = 160 + ply.lastSpeedy + anchorSpeedY
                ply.state.onGround = false
                --//Dash取消
                dashRemove()

                --//设置speedcircle
                ply.circleTimer = ply.circleSetTime
                ply.circleLeaved = 3
                --DashShadow
                ply.shadowTimer = ply.shadowSetTime
                ply.shadowLeaved = 2
                --//Force设置
                forceAdder(0.4,wavedash)
                ply.forceX = ply.forceX + anchorSpeedX

                --//播放声效
                soundPlay(sound.jump.NormalJump,0.001)
                soundPlay(sound.jump.SuperSlide,0.001)
            elseif ply.state.IsDash and (ply.state.onGround or ply.coyoteTimer ~= 0) and ply.lastDashDirection.x ~= 0 and ply.lastDashDirection.y == 0 and ply.state.IsSquat then--hyper
                smokeAdder()
                local hyper = 230
                ply.speed.y = 160 + ply.lastSpeedy + anchorSpeedY
                ply.state.onGround = false
                --//Dash取消
                dashRemove()

                --//设置speedcircle
                ply.circleTimer = ply.circleSetTime
                ply.circleLeaved = 3
                --DashShadow
                ply.shadowTimer = ply.shadowSetTime
                ply.shadowLeaved = 2
                --//解除下蹲
                squatRemove()
                 --//Force设置
                forceAdder(0.4,hyper)
                ply.forceX = ply.forceX + anchorSpeedX
                 --//播放声效
                soundPlay(sound.jump.NormalJump,0.001)
                soundPlay(sound.jump.SuperSlide,0.001)
            end

        elseif ply.state.canClimbJump then
            ply.state.climbJumpTimer = ply.state.setClimbJumpTime
            if not (ply.state.IsDash and ply.lastDashDirection.y == 1) then--是否为普通墙跳
                walljump()
            elseif ply.lastDashDirection.y > 0 and ply.lastDashDirection.x == 0 then--wall bounce
                --//改变sprite
                ply.nowTextureMode = "Default"
                --//设置墙跳阻力（已废弃）
                ply.wallJumpTimer = ply.wallJumpSetTime
                --设置Y轴速度
                ply.speed.y = ply.speedSetting.wallbounce + ply.lastSpeedy
                ply.state.onGround = false
                --取消Dash
                ply.state.IsDashDuring = false
                ply.state.IsMoreDash = true
                ply.dashDuring = 0
                ply.dashTimer = 0

                --设置Dash残影
                ply.shadowTimer = ply.shadowSetTime
                ply.shadowLeaved = 1
                 --//设置speedcircle
                ply.circleTimer = 0.1
                ply.circleLeaved = 1

                if ply.state.wallSide == "left" then--左边弹起
                    --//添加烟雾
                    smokeAdder("wallJump","l")
                    --//播放声效
                    soundPlay(sound.jump.LwallJump,0.001)
                    --X轴速度设置
                    if M_mat.direction(ply.speed.x) >= 0 then--如果同方向就叠加
                        ply.speed.x = ply.speed.x + ply.speedSetting.wallKick*ply.speedSetting.wallkickRatio*0.9
                    else
                        ply.speed.x = ply.speedSetting.wallKick*ply.speedSetting.wallkickRatio*0.9
                    end
                    --//改变朝向
                    ply.state.faceSide = "left"
                else--右边弹起
                    --//添加烟雾
                    smokeAdder("wallJump","l")
                    --//播放声效
                    soundPlay(sound.jump.RwallJump,0.001)
                    --X轴速度设置
                    if M_mat.direction(ply.speed.x) <= 0 then--如果同方向就叠加
                        ply.speed.x = ply.speed.x - ply.speedSetting.wallKick*ply.speedSetting.wallkickRatio*0.9
                    else
                        ply.speed.x = -ply.speedSetting.wallKick*ply.speedSetting.wallkickRatio*0.9
                    end
                    --//改变朝向
                    ply.state.faceSide = "right"
                end
                --//设置上一次Dash朝向
                ply.lastDashDirection.x = 0
                ply.lastDashDirection.y = 1
                --//播放声效
                soundPlay(sound.jump.SuperWall,0.001)
            end
        end
    end
end
local function normalJumpUpdater(dt)--跳跃力度更新
    if ply.jumpingTimer - dt <= 0 then
        ply.state.IsJumping = false
        ply.jumpingTimer = 0
        ply.jumpStrength = 1
    else
        if ply.state.IsJumping then
            ply.speed.y = ply.speedSetting.jump*ply.jumpStrength + ply.lastSpeedy
        else
            ply.jumpingTimer = 0
        end
        ply.jumpingTimer = ply.jumpingTimer - dt
    end
    if ply.state.IsJumping then
        if ply.KeyDetector("jump") then--增加跳跃力度
            ply.jumpStrength = math.max(0, math.min(ply.jumpStrength + 1/ply.jumpStrengthTime*dt, 1))
        else
            ply.state.IsJumping = false
            ply.jumpingTimer = 0
            ply.jumpStrength = 1
        end
    end
end
local function wallJumpFriction(dt)--//墙跳后空气阻力更改（废弃）
    if ply.wallJumpTimer - dt > 0 then
        ply.state.wallJumpFriction = ply.speedSetting.wallJumpFriction
        ply.wallJumpTimer = ply.wallJumpTimer - dt
    else
        ply.wallJumpTimer = 0
        ply.state.wallJumpFriction = 0
    end
end
local function fallSlow()--//缓降
    if not ply.state.IsJumping and math.abs(ply.speed.y) <= 40 and ply.KeyDetector("jump") then
        ply.state.IsSlowDown = true
    else
        ply.state.IsSlowDown = false
    end
end

function ply.ToSquat(key)--//蹲下
    local Cratio = ply.collisionSize.smolRatio--蹲下比例
    local oriW,oriH = ply.collisionSize.originWidth,ply.collisionSize.originHeight
    local ToTop = (oriH/Cratio)/2 + (oriH - oriH/Cratio)--计算蹲下后其上边与站起后的上边的距离
    if ply.KeyDetector(key) and ply.state.onGround then
        if not ply.state.IsSquat then
            ply.position.y = ply.position.y - (oriH - oriH/Cratio)/2--修正Y轴
            ply.state.IsSquat = true
            ply.state.canMove = false
            --//蹲下动画
            --//蹲下声效
            sound.duck[sound.duck.Num]:stop()
            if sound.duck.Num >= 3 then
                sound.duck.Num = 1
            else
                sound.duck.Num = sound.duck.Num + 1
            end
            soundPlay(sound.duck[sound.duck.Num],0)
        end
        ply.collisionSize.height = oriH/Cratio--对实际碰撞
        ply.hitboxSize.height = ply.hitboxSize.originHeight/4
    else
        if ply.state.onGround then
            if ply.collisionSize.height == oriH/Cratio and not M_phi.fromTop(ply.position.x, ply.position.y + ToTop, oriW/2 - 1) then
                ply.position.y = ply.position.y + (oriH - oriH/Cratio)/2--修正Y轴
                ply.collisionSize.height = oriH--恢复原高
                ply.hitboxSize.height = ply.hitboxSize.originHeight
                if ply.state.IsSquat then
                    ply.state.IsSquat = false
                    ply.state.canMove = true
                    --//起来动画
                    


                end
            end
        end
    end
end

function ply.isOnGround()--//是否在地面
    local footY = ply.position.y - ply.collisionSize.height / 2 - 1
    local tpy = ply.position.y + ply.collisionSize.height / 2
    local result = M_phi.fromBAT(ply.position.x, tpy, footY, ply.collisionSize.width / 2 - 1)
    if result == nil then
        result = M_phi.fromBAT(ply.position.x, tpy, footY, ply.collisionSize.width / 2 - 1,true)
    end
    return result == false
end

function ply.toDead(N)--//死亡预设
    --//设置死亡位置/方向
    ply.lastDeadPosition.x,ply.lastDeadPosition.y = ply.position.x,ply.position.y
    if N == 0 then--原地死亡
        if ply.state.faceSide == "right" then
            ply.state.dyingDirection = 1
        else
            ply.state.dyingDirection = 2
        end
    elseif N == 1 then--上刺
        if ply.state.faceSide == "right" then
            ply.state.dyingDirection = 1
        else
            ply.state.dyingDirection = 2
        end
    elseif N == 2 then--左刺
        ply.state.dyingDirection = 1
    elseif N == 3 then--下刺
        if ply.state.faceSide == "right" then
            ply.state.dyingDirection = 3
        else
            ply.state.dyingDirection = 4
        end
    elseif N == 4 then--右刺
        ply.state.dyingDirection = 2
    end
    
    if ply.state.dyingDirection == 0 then
        --//扭曲
        render.setDashshader(
        {x = ply.lastDeadPosition.x,y = ply.lastDeadPosition.y},
        500,1.5,"all")
    elseif ply.state.dyingDirection == 1 then
        ply.position.x,ply.position.y = ply.position.x + 6,ply.position.y - 6
        --//扭曲
        render.setDashshader(
        {x = ply.lastDeadPosition.x - ply.state.deadDistance,y = ply.lastDeadPosition.y + ply.state.deadDistance},
        500,1.5,"all")
    elseif ply.state.dyingDirection == 2 then
        ply.position.x,ply.position.y = ply.position.x - 6,ply.position.y - 6
        --//扭曲
        render.setDashshader(
        {x = ply.lastDeadPosition.x + ply.state.deadDistance,y = ply.lastDeadPosition.y + ply.state.deadDistance},
        500,1.5,"all")
    elseif ply.state.dyingDirection == 3 then
        ply.position.x,ply.position.y = ply.position.x + 6,ply.position.y + 6
        --//扭曲
        render.setDashshader(
        {x = ply.lastDeadPosition.x - ply.state.deadDistance,y = ply.lastDeadPosition.y - ply.state.deadDistance},
        500,1.5,"all")
    elseif ply.state.dyingDirection == 4 then
        ply.position.x,ply.position.y = ply.position.x - 6,ply.position.y + 6
        --//扭曲
        render.setDashshader(
        {x = ply.lastDeadPosition.x + ply.state.deadDistance,y = ply.lastDeadPosition.y - ply.state.deadDistance},
        500,1.5,"all")
    end
    --//触发声效
    soundPlay(sound.dead.pre,0)
    --//Camera晃动特效
    M_cam.shaking.size = 20
    M_cam.shaking.timer = 0.2

    --//重置(不包括玩家坐标)
    ply.restart()
    --//设置死亡时间
    ply.deadTimer = ply.deadSetTime
    ply.state.dying = true
end
function ply.dieOfSqueeze()--//挤压检测
    local beSqueeze,v
    if not ply.state.IsSquat then
        beSqueeze,v = M_phi.squeezeDetector(
            ply.position.x - ply.hitboxSize.width/2 + ply.hitboxSize.Dx,
            ply.position.y + ply.hitboxSize.height/4 ,
            ply.position.x + ply.hitboxSize.width/2 + ply.hitboxSize.Dx,
            ply.position.y - ply.hitboxSize.height/4 
        ) 
    else
        beSqueeze,v = M_phi.squeezeDetector(
            ply.position.x - ply.hitboxSize.width/2 + ply.hitboxSize.Dx,
            ply.position.y + ply.hitboxSize.height/6 ,
            ply.position.x + ply.hitboxSize.width/2 + ply.hitboxSize.Dx,
            ply.position.y - ply.hitboxSize.height/6 
        ) 
    end
    --dbg.print(tostring(ply.hitboxSize.Dy))
    if beSqueeze then ply.toDead(0) end
end

function ply.updater (dt)--//主更新机
    if ply.lagTimer <= 0 then
        --//游戏时间机
        ply.lagTimer = 0
        ply.GamingTime = ply.GamingTime + dt
        --//果冻效果
        jellyUpdater()
        --//落地动画刷新
        if ply.animationSet.ground > 0 then
            ply.animationSet.ground = ply.animationSet.ground - ply.animationSet.groundSet/0.15*dt --0.15秒结束
        else
            ply.animationSet.ground = 0
        end
        --蹲下动画刷新
        if not ply.state.IsSquat then--注意，这里是蹲下时数字减少
            if ply.animationSet.squat - ply.animationSet.squatSet/ply.animationSet.squatTime*dt > 0 then
                ply.animationSet.squat = ply.animationSet.squat - ply.animationSet.squatSet/ply.animationSet.squatTime*dt
            else
                ply.animationSet.squat = 0
            end
        else
            if ply.animationSet.squat + ply.animationSet.squatSet/ply.animationSet.squatTime*dt < ply.animationSet.squatSet then
                ply.animationSet.squat = ply.animationSet.squat + ply.animationSet.squatSet/ply.animationSet.squatTime*dt
            else
                ply.animationSet.squat = ply.animationSet.squatSet
            end
        end


        --//延迟落地时间
        if ply.groundTimer > 0 then
            ply.groundTimer = math.max(0, math.min(ply.groundTimer - dt,0.2))
        else
            ply.state.onGround = false
            ply.state.stateName = "fall"
        end

        --//Y轴速度计算
        if not ply.state.IsDashDuring and not ply.state.IsClimbing then
            if ply.direction.y >= 0 and not ply.state.IsJumping then--没有主动按下下键的下落速度
                if not ply.state.Onground then--是否在地面
                    if not ply.state.IsSliding then--是否在滑墙
                        ply.speed.y = math.max(-ply.speedSetting.normalDown,math.min(ply.speed.y + ply.acceleration.y*dt,800))
                    else
                        if ply.speed.y < 0 then
                            ply.speed.y = math.max(-ply.speedSetting.normalDown,math.min(ply.speed.y - M_phi.slideDown*dt,800))
                        else
                            ply.speed.y = math.max(-ply.speedSetting.normalDown,math.min(ply.speed.y + ply.acceleration.y*dt,800))
                        end
                    end
                else
                    ply.speed.y = math.max(-ply.speedSetting.normalDown,math.min(ply.speed.y + ply.acceleration.y*dt,800))
                end
            else--主动按下下键的下落速度
                ply.speed.y = math.max(-ply.speedSetting.fastDown,math.min(ply.speed.y + ply.acceleration.y*dt,800))--修改满向下速度
            end
        end

        --//X轴速度计算
        if not ply.state.IsDashDuring and ply.state.canNextDash and not ply.state.IsClimbing then
            if ply.state.onGround then--在地上(一套快速加速与快速降速的逻辑)
                if ply.state.IsMove and not ply.state.IsSquat then--移动/加速阶段
                    if ply.moveDirection == -1 then--想向左
                        if ply.speed.x <= 0 then--速度向左
                            if math.abs(ply.speed.x) <= ply.speedSetting.run then--小于标准速度
                                ply.speed.x = math.max(-ply.speedSetting.run, ply.speed.x + ply.accelerationSetting.groundMove*dt*ply.moveDirection)
                            else--大于标准速度
                                ply.speed.x = ply.speed.x - ply.accelerationSetting.groundSame*dt*M_mat.direction(ply.speed.x)
                            end
                        else--速度向右
                            ply.speed.x = ply.speed.x - ply.accelerationSetting.groundMove*dt*M_mat.direction(ply.speed.x)
                        end
                    elseif ply.moveDirection == 1 then--想向右
                        if ply.speed.x >= 0 then--速度向右
                            if math.abs(ply.speed.x) <= ply.speedSetting.run then--小于标准速度
                                ply.speed.x = math.min(ply.speedSetting.run, ply.speed.x + ply.accelerationSetting.groundMove*dt*ply.moveDirection)
                            else--大于标准速度
                                ply.speed.x = ply.speed.x - ply.accelerationSetting.groundSame*dt*M_mat.direction(ply.speed.x)
                            end
                        else--速度向左
                            ply.speed.x = ply.speed.x - ply.accelerationSetting.groundMove*dt*M_mat.direction(ply.speed.x)
                        end
                    end
                else--不移动/在蹲下(地面)
                    if ply.state.IsSquat then--在蹲下
                        if math.abs(ply.speed.x) <= ply.accelerationSetting.groundMid*dt then
                            ply.speed.x = 0
                        else
                            ply.speed.x = ply.speed.x - (ply.accelerationSetting.groundMid + ply.accelerationSetting.groundMove)*dt*M_mat.direction(ply.speed.x)
                        end
                    else--不蹲且不移动
                        if math.abs(ply.speed.x) <= ply.accelerationSetting.groundMove*dt then
                            ply.speed.x = 0
                        else
                            ply.speed.x = ply.speed.x - ply.accelerationSetting.groundMove*dt*M_mat.direction(ply.speed.x)
                        end
                    end
                end
            else--[][][][][][][][][][][][][][][][][][][][][][][][][][][][][][]在空中(另一套惯性逻辑)
                if ply.state.IsMove then--移动/加速阶段
                    if not ply.state.IsForce then--有没有外力
                        if ply.moveDirection == -1 then--想向左
                            if ply.speed.x <= 0 then--速度向左
                                if math.abs(ply.speed.x) <= ply.speedSetting.run then--小于标准速度
                                    ply.speed.x = math.max(-ply.speedSetting.run, ply.speed.x + ply.accelerationSetting.airMove*dt*ply.moveDirection)
                                else--大于标准速度
                                    ply.speed.x = ply.speed.x - ply.accelerationSetting.airSame*dt*M_mat.direction(ply.speed.x)
                                end
                            else--速度向右
                                ply.speed.x = ply.speed.x - ply.accelerationSetting.airMove*dt*M_mat.direction(ply.speed.x)
                            end
                        elseif ply.moveDirection == 1 then--想向右
                            if ply.speed.x >= 0 then--速度向右
                                if math.abs(ply.speed.x) <= ply.speedSetting.run then--小于标准速度
                                    ply.speed.x = math.min(ply.speedSetting.run, ply.speed.x + ply.accelerationSetting.airMove*dt*ply.moveDirection)
                                else--大于标准速度
                                    ply.speed.x = ply.speed.x - ply.accelerationSetting.airSame*dt*M_mat.direction(ply.speed.x)
                                end
                            else--速度向左
                                ply.speed.x = ply.speed.x - ply.accelerationSetting.airMove*dt*M_mat.direction(ply.speed.x)
                            end
                        end
                    else--有外力
                    ply.speed.x = ply.forceX
                    end
                else--不移动(这次不包括蹲下的额外处理)
                    if not ply.state.IsForce then--有没有外力
                        if math.abs(ply.speed.x) <= ply.accelerationSetting.airMove*dt then
                            ply.speed.x = 0
                        else
                            ply.speed.x = ply.speed.x - ply.accelerationSetting.airMove*dt*M_mat.direction(ply.speed.x)
                        end
                    else--有外力
                        ply.speed.x = ply.forceX
                    end
                end
            end
        elseif ply.state.IsClimbing then--攀爬时
            ply.speed.x = 0
        else--Dash时/Dash启动时

        end

        --//缓降
        fallSlow()
        --//Y轴加速度计算
        if not ply.state.onGround then
            if not ply.state.IsDashDuring and ply.state.canNextDash and not ply.state.IsJumping then
                if ply.state.IsSlowDown then
                    ply.acceleration.y = -ply.accelerationSetting.slowGravity
                else
                    if ply.speed.y >= -ply.speedSetting.normalDown then
                        ply.acceleration.y = -ply.accelerationSetting.gravity
                    else
                        ply.acceleration.y = -ply.accelerationSetting.overGravity
                    end
                end
            else
                ply.acceleration.y = 0
            end
        else
            ply.acceleration.y = 0
        end

        --//Y轴速度积累衰竭
        if not ply.state.onGround and not ply.state.IsDash then
            ply.lastSpeedy = numLerp(ply.lastSpeedy,0,0.05)
        elseif ply.state.onGround and not ply.state.IsDash then
            ply.lastSpeedy = 0
        end

        --//地图机关更新
        if M_ply.ISGAMING and not M_ply.state.dying then
            M_phi.objectsUpdater(dt,ply.position,ply.collisionSize)
        end
        --//anchor位置计算
        anchorUpdater()
        --//对象推动
        objDetector()

        --//墙检测（为了爬墙与墙跳）
        wallDetect()
        --//滑墙
        toSlide(dt)
        --//爬墙
        toClimb(dt)
        --//墙跳阻力
        wallJumpFriction(dt)

        --//Subpixel 精度位移计算
        local dx = ply.speed.x * dt + ply.subpixel.x
        local dy = ply.speed.y * dt + ply.subpixel.y
        local mx = math.floor(dx)
        local my = math.floor(dy)
        --//保存不足为1个像素的移动数据
        ply.subpixel.x = dx - mx
        ply.subpixel.y = dy - my
        --//移动
        moveX(mx)
        moveY(my)
        --fixMove()
        --//跳跃力度
        normalJumpUpdater(dt)

        --//落地/空中判断
        if ply.isOnGround() then--碰到地面
            if not ply.state.onGround then
                --//smoke效果//不包括狼跳
                smokeAdder()
                --//落地声效
                soundPlay(sound.stand[1],0)
                --//重置转身
                flipUpdater(nil,true)
                --//重置fixMove
                ply.fixMoveTimes = ply.fixMoveSetTimes
            end
            ply.state.onGround = true
            ply.groundTimer = ply.groundSetTime--虽然没用上，但最好还是不要删。
            ply.state.stateName = "Onground"
            --//狼跳时间重置
            ply.coyoteTimer = ply.coyoteSetTime
            --//体力恢复
            ply.state.stamina = ply.state.maxStamina
            --//重置y速度积累
            if not ply.state.IsDash then 
                ply.lastSpeedy = 0
            end
            --//设置动画(地面)
            if ply.speed.x == 0 and not ply.state.IsFlipping then
                ply.nowTextureMode = "Idle"
                --//重置转身
                flipUpdater(nil,true)
            else
                --转身更新机
                flipUpdater(dt)

                if ply.state.IsFlipping then
                    ply.nowTextureMode = ""
                    ply.nowTexture = ply.texture.Flip[ply.texture.Flip.number]
                else--跑步
                
                    if math.abs(ply.speed.x) < 100 then
                        if ply.nowTextureMode == "RunFast" then
                            ply.texture.RunSlow.number = ply.texture.RunFast.number
                        end
                        ply.nowTextureMode = "RunSlow"
                    else
                        if ply.nowTextureMode == "RunSlow" then
                            ply.texture.RunFast.number = ply.texture.RunSlow.number
                        end
                        ply.nowTextureMode = "RunFast"
                    end

                end
            end
        else--在空中
            --//anchor重置
            if not ply.state.IsClimbing and not ply.state.IsSliding then
                ply.anchor = nil
            end
            ---落地动画重制
            ply.animationSet.ground = ply.animationSet.groundSet

            ply.state.onGround = false
            ply.state.stateName = "fall"
            --//狼跳时间减少
            if ply.coyoteTimer - dt > 0 then
                ply.coyoteTimer = ply.coyoteTimer - dt
            else
                ply.coyoteTimer = 0
            end
            --//设置动画(空中)
            if ply.state.IsSliding or ply.state.IsClimbing then
                if ply.speed.y > 0 then
                    ply.nowTextureMode = "Climb"
                else
                    ply.nowTextureMode = "Slide"
                end
            else
                ply.nowTextureMode = ""
                if not ply.state.IsDashDuring then
                    if ply.speed.y > 10 then
                        ply.nowTexture = ply.texture.Jump[1]
                    elseif ply.speed.y > -40 then
                        ply.nowTexture = ply.texture.Jump[2]
                    elseif ply.speed.y <= -40 and ply.speed.y >= -100 then
                        ply.nowTexture = ply.texture.Fall[1]
                    elseif ply.speed.y < -100 then
                        ply.nowTexture = ply.texture.Fall[2]
                    end
                end
            end
            --更新转向信息
            if ply.state.faceSide == "left" then
                ply.flipDirection = -1
            else
                ply.flipDirection = 1
            end
        end

        --//Shadow特效更新
        shadowUpdater(dt)
        --//circle特效更新
        speedcircleUpdater(dt)
        --//动画更新
        animationUpdater(dt)
        --//头发
        hairUpdater(dt)
        --//脚步声
        footStepUpdater(dt)

        --//Dash时间刷新
        ply.dashUpdate(dt)
        --//Force时间刷新
        ply.forceUpdate(dt)

        --//事件检测
        eventUpdater()

        --//trigger触发
        objActivater(M_phi.triggerDetector(
            ply.position.x - ply.hitboxSize.width/2,
            ply.position.y + ply.hitboxSize.height/2,
            ply.position.x + ply.hitboxSize.width/2,
            ply.position.y - ply.hitboxSize.height/2
        ))

        --//danger检测
        local Isdanger,N = M_phi.dangerDetector(
            ply.position.x - ply.hitboxSize.width/2 + ply.hitboxSize.Dx,
            ply.position.y + ply.hitboxSize.height/2 + ply.hitboxSize.Dy,
            ply.position.x + ply.hitboxSize.width/2 + ply.hitboxSize.Dx,
            ply.position.y - ply.hitboxSize.height/2 + ply.hitboxSize.Dy,
            ply.speed
        ) 
        if Isdanger then ply.toDead(N) else ply.dieOfSqueeze() end
    else
        ply.lagTimer = ply.lagTimer - dt
    end
end

local PLAYDEADSOUND = true
local FRAMEMODE,FRAMEPROCESS = 2,"IN"
local _PG
local DEADFRAMES = {--死亡过场写入
    [1] = function(PG,H,W)
        H = H*0.1
        love.graphics.setColor(0,0,0,1)
        if FRAMEPROCESS == "IN" then
            for i = 0,4 do
                render.rectangle("fill",0, -H*i*2, W*smoothStep(PG),H)--左
                render.rectangle("fill",W - W*smoothStep(PG), -H*((i + 1)*2 - 1), W,H)--右
            end
        else
            for i = 0,4 do
                render.rectangle("fill",0, -H*((i + 1)*2 - 1), W*smoothStep(PG),H)--左
                render.rectangle("fill",W - W*smoothStep(PG), -H*i*2, W,H)--右
            end
        end
    end,
    [2] = function(PG,H,W)
        H = H*0.1
        love.graphics.setColor(0,0,0,1)
        if FRAMEPROCESS == "IN" then
            for i = 0,9 do
                render.rectangle("fill",0, -H*i, W*smoothStep( math.max(0,math.min( (PG - i*0.1)/(1 - i*0.1) ,1)) ),H)--左
            end
        else
            for i = 0,9 do
                render.rectangle("fill",W - W*smoothStep( math.max(0,math.min( (PG - i*0.1)/(1 - i*0.1) ,1)) ), -H*i, W,H)--右
            end
        end
    end,
    [3] = function(PG,H,W)
        love.graphics.setColor(0,0,0,1)
        local Size,HSize = 100,100/2
        local yT,xT = math.floor(H/Size + 0.5),math.floor(W/Size + 0.5)
        if FRAMEPROCESS == "IN" then
            for x = 0,xT do
                for y = 0,yT do
                    _PG = math.max( 0,math.min( (PG - (x+y)/(xT+yT))/(1 - (x+y)/(xT+yT)) ) )
                    render.rectangle("fill",x*Size,- y*Size + _PG*HSize, Size*_PG,Size*_PG)
                end
            end
        else
            for x = 0,xT do
                for y = 0,yT do
                    _PG = math.max( 0,math.min( (PG - (x+y)/(xT+yT))/(1 - (x+y)/(xT+yT)) ) )
                    render.rectangle("fill",x*Size,- y*Size + _PG*HSize, Size*_PG,Size*_PG)
                end
            end
        end
    end,
}
function ply.dead(dt,Camera)--//死亡更新
    if ply.deadTimer - dt < 0 then
        --//重设机关
        M_phi.objectsReset()
        --//死亡声音播放
        PLAYDEADSOUND = true
        --//复活时间设置
        ply.reviveTimer = ply.reviveSetTime
        --//复活声效
        soundPlay(sound.dead.revive,1)
        --//设0
        ply.deadTimer = 0
        --//设置过程模式为OUT
        FRAMEPROCESS = "OUT"
        --//传送至复活点
        local p = M_phi.collisionGrid.point
        if ply.checkpoint then
            local Tx = M_phi.collisionGrid.point.x + ply.checkpoint.x + ply.checkpoint.width/2
            local Ty = M_phi.collisionGrid.point.y - ply.checkpoint.y - ply.checkpoint.height/2
            M_ply.position.x,M_ply.position.y = Tx,Ty
            Camera.showPosition.x,Camera.showPosition.y = Tx,Ty
            Camera.position.x,Camera.position.y = Tx,Ty
        else
            for _,v in pairs(M_phi.objects.key) do
                if v.type == "spawn" then
                    M_ply.position.x,M_ply.position.y = p.x + v.x + v.width/2,p.y - v.y - v.height/2
                    Camera.showPosition.x,Camera.showPosition.y = p.x + v.x + v.width/2,p.y - v.y - v.height/2
                    Camera.position.x,Camera.position.y = p.x + v.x + v.width/2,p.y - v.y - v.height/2
                end
            end
        end
    else
        --//设置过程模式为IN
        FRAMEPROCESS = "IN"
        --//计时器
        ply.deadTimer = ply.deadTimer - dt
        --//过程计算
        ply.deadPG = (ply.deadSetTime - ply.deadTimer)/ply.deadSetTime -- 0~1
        --//动画更新（elseif大蛇）
        if ply.deadPG < 0.2 then ply.nowTexture = ply.texture.Dead[1]
        elseif ply.deadPG < 0.30 then ply.nowTexture = ply.texture.Dead[2]
        elseif ply.deadPG < 0.36 then ply.nowTexture = ply.texture.Dead[3]
        elseif ply.deadPG < 0.42 then ply.nowTexture = ply.texture.Dead[4]
        elseif ply.deadPG < 0.48 then ply.nowTexture = ply.texture.Dead[5]
        elseif ply.deadPG < 0.54 then ply.nowTexture = ply.texture.Dead[6]
        elseif ply.deadPG < 0.60 then ply.nowTexture = ply.texture.Dead[7]
        elseif ply.deadPG < 0.66 then ply.nowTexture = ply.texture.Dead[8]
        elseif ply.deadPG < 0.72 then ply.nowTexture = ply.texture.Dead[9]
        elseif ply.deadPG < 0.78 then ply.nowTexture = ply.texture.Dead[10]
        elseif ply.deadPG < 0.84 then ply.nowTexture = ply.texture.Dead[11]
        elseif ply.deadPG < 0.90 then ply.nowTexture = ply.texture.Dead[12]
        end
        --//规定时间时播放
        if ply.deadPG > 0.35 and PLAYDEADSOUND then
            PLAYDEADSOUND = false
            --//播放死亡声效
            soundPlay(sound.dead.normal,0)
            --//晃动特效
            M_cam.shaking.size = 50
            M_cam.shaking.timer = 0.3
        end
        --//死亡惯性方向设置
        if ply.deadPG < 0.4 then            
            if ply.state.dyingDirection == 1 then--向左上飞
                ply.state.faceSide = "right"
                ply.position.x = numLerp(ply.position.x,ply.lastDeadPosition.x - ply.state.deadDistance,0.1)
                ply.position.y = numLerp(ply.position.y,ply.lastDeadPosition.y + ply.state.deadDistance,0.1)
            elseif ply.state.dyingDirection == 2 then--向右上飞
                ply.state.faceSide = "left"
                ply.position.x = numLerp(ply.position.x,ply.lastDeadPosition.x + ply.state.deadDistance,0.1)
                ply.position.y = numLerp(ply.position.y,ply.lastDeadPosition.y + ply.state.deadDistance,0.1)
            elseif ply.state.dyingDirection == 3 then--向左下飞
                ply.state.faceSide = "right"
                ply.position.x = numLerp(ply.position.x,ply.lastDeadPosition.x - ply.state.deadDistance,0.1)
                ply.position.y = numLerp(ply.position.y,ply.lastDeadPosition.y - ply.state.deadDistance,0.1)
            elseif ply.state.dyingDirection == 4 then--向右下飞
                ply.state.faceSide = "left"
                ply.position.x = numLerp(ply.position.x,ply.lastDeadPosition.x + ply.state.deadDistance,0.1)
                ply.position.y = numLerp(ply.position.y,ply.lastDeadPosition.y - ply.state.deadDistance,0.1)
            end
        end
        --[[
        ply.deadPG:0.4~0.8过渡动画
        ply.deadPG:0.8~1.0全黑屏
        --]]
    end
end
function ply.revive(dt)--//复活更新
    if ply.reviveTimer - dt < 0 then
        --//重设设置
        ply.reviveTimer = 0
        ply.state.dying = false
        ply.nowTexture = ply.texture.Default[1]
        --//随机过场设置
        FRAMEMODE = math.random(1,#DEADFRAMES)
    else
        --//计时器/过程数
        ply.reviveTimer = ply.reviveTimer - dt
        ply.revivePG = ply.reviveTimer/ply.reviveSetTime -- 1~0
        --//动画
        if ply.revivePG > 0.70 then ply.nowTexture = ply.texture.Dead[7]
        elseif ply.revivePG > 0.64 then ply.nowTexture = ply.texture.Dead[8]
        elseif ply.revivePG > 0.58 then ply.nowTexture = ply.texture.Dead[9]
        elseif ply.revivePG > 0.52 then ply.nowTexture = ply.texture.Dead[10]
        elseif ply.revivePG > 0.46 then ply.nowTexture = ply.texture.Dead[11]
        elseif ply.revivePG > 0.40 then ply.nowTexture = ply.texture.Dead[12]
        elseif ply.revivePG > 0.34 then ply.nowTexture = ply.texture.Dead[5]
        elseif ply.revivePG > 0.28 then ply.nowTexture = ply.texture.Dead[4]
        elseif ply.revivePG > 0.22 then ply.nowTexture = ply.texture.Dead[3]
        elseif ply.revivePG > 0.16 then ply.nowTexture = ply.texture.Dead[2]
        elseif ply.revivePG > 0.10 then ply.nowTexture = ply.texture.Dead[1]
        end
    end
end
function ply.deadFrame(PG,WINDOW_INFO)--//播放死亡过场 PG: dead 0 ~ 1--revive 1 ~ 0
    local H = WINDOW_INFO.Height
    local W = WINDOW_INFO.Width
    DEADFRAMES[FRAMEMODE](PG,H,W)
end

--//将一些函数传给UI.Lua里
local function sendToUI()
    --//Retry传入
    UI.IN_GAME.MENU_SET[0][2].func = function ()
        if not ply.state.dying then
            UI.closeMENU(ply)
            ply.toDead(0)
        end
    end

end;sendToUI()

return ply
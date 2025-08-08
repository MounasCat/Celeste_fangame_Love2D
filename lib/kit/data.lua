local dbg = require("lib.kit.debug") or {print = function() end,warn = function() end,error = function() end}
local dkjson = require("lib.kit.dkjson")

local dat = {}

local originData = {
    deadTimes = 0,

    langauage = "English"
    
}
dat.dataOn = false

local function dataChecker (data,template)
    local t = template or originData
    for i,v in pairs(t) do
        if type(v) == "table" and type(data[tostring(i)]) == "table" then--callback function for check.
            if not dataChecker(data[tostring(i)],v) then
                return false
            end
        elseif type(data[tostring(i)]) ~= type(v)  then
            return false
        end
    end
    return true
end

function dat.getData()
    local data
    if dat.dataOn then
        if love.filesystem.getInfo("data.json") then
            data = dkjson.decode(love.filesystem.read("data.json"))
            if not dataChecker(data) then
                dbg.error("the data.json is uncomplete,turn to false data mode.")
                data = originData
            end
        else
            dbg.warn("haven't found the data.json,turn to false data mode.")
            data = originData
        end
    else
        dbg.print("false data mode is on.")
        data = originData
    end
    return data
end

function dat.saveData(data)
    if dat.dataOn then
        if dataChecker(data) then
            love.filesystem.write("data.json", dkjson.encode(data, { indent = true }))
            dbg.print("data saved.")
        else
            dbg.error("the data{} is incomplete,save failed.")
        end
    end
end

function dat.insertData(parent,name,value)
    if type(parent) == "table" and type(name) == "string" and value ~= nil then
        parent[name] = value
    else
        dbg.warn("incomlete format when call insertData().")
    end
end

return dat
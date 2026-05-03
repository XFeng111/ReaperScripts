--@noindex

---@class AK_Map : userdata
---@class AK_Array : userdata
---@class AK_Variant : userdata
-- AK_Map|AK_Array|AK_Variant 是 ReaWwise 中的特殊数据类型，表示 AK JSON 结构中的 Map、Array 和 Variant 类型。

AK_Module = {}
-- ==============================================

---@param map_ak AK_Map
---@param key_str string
---@param value_str string
function AK_Module.MapSet_str(map_ak, key_str, value_str)
    local value_ak = reaper.AK_AkVariant_String(value_str)
    reaper.AK_AkJson_Map_Set(map_ak, key_str, value_ak)

    return map_ak
end

---@param map_ak AK_Map
---@param key_str string
---@param value_int number
function AK_Module.MapSet_int(map_ak, key_str, value_int)
    local value_ak = reaper.AK_AkVariant_Int(value_int)
    reaper.AK_AkJson_Map_Set(map_ak, key_str, value_ak)

    return map_ak
end

--[[
local importLanguage = "importLanguage"
local SFX = "SFX"
local default = reaper.AK_AkJson_Map()
AK_Module.MapSet_str(default, importLanguage, SFX)
 ]]

---@param map_ak AK_Map
---@param key_str string
---@param value_bool boolean
function AK_Module.MapSet_bool(map_ak, key_str, value_bool)
    local value_ak = reaper.AK_AkVariant_Bool(value_bool)
    reaper.AK_AkJson_Map_Set(map_ak, key_str, value_ak)

    return map_ak
end

--[[
local arguments = reaper.AK_AkJson_Map()
local autoAddToSourceControl = "autoAddToSourceControl"
AK_Module.MapSet_bool(arguments, autoAddToSourceControl, true)
 ]]

---@param array_ak AK_Array
---@param element_str string
function AK_Module.ArrayAdd_str(array_ak, element_str)
    local element_ak = reaper.AK_AkVariant_String(element_str)
    reaper.AK_AkJson_Array_Add(array_ak, element_ak)

    return array_ak
end

---@param array_ak AK_Array
---@param element_table table
function AK_Module.ArrayAdd_table(array_ak, element_table)
    for i, e in ipairs(element_table) do
        local element_ak = reaper.AK_AkVariant_String(e)
        reaper.AK_AkJson_Array_Add(array_ak, element_ak)
    end

    return array_ak
end

---@param array_ak AK_Array
---@param array table
function AK_Module.ArrayToAKArray(array_ak, array)
    local array_list = array
    for j = 1, #array_list do
        local array_item = array_list[j]
        AK_Module.ArrayAdd_str(array_ak, array_item)
    end

    return array_ak
end

--[[ 
local array_ak = reaper.AK_AkJson_Array()
local array = { "name", "originalFilePath", "path" }
AK_Module.ArrayToAKArray(array_ak, array)
 ]]

---@param map_ak AK_Map
---@param key_list table
---@param value_list table
function AK_Module.TwoTableToAKMap(map_ak, key_list, value_list)
    -- 遍历两个列表，确保它们长度一致，并将键值对添加到map_ak中
    for i = 1, #key_list do
        -- 确保两个列表长度一致，避免索引越界
        if i > #value_list then
            break
        end
        local key = key_list[i]
        local value = value_list[i]

        if type(value) == "string" then
            -- 调用AK_Module.MapSet_str函数设置键值对
            AK_Module.MapSet_str(map_ak, key, value)
        elseif type(value) == "number" then
            -- 调用AK_Module.MapSet_int函数设置键值对
            AK_Module.MapSet_int(map_ak, key, value)
        elseif type(value) == "boolean" then
            -- 调用AK_Module.MapSet_bool函数设置键值对
            AK_Module.MapSet_bool(map_ak, key, value)
        else
            -- 如果value不是字符串或布尔值，直接将其设置为map_ak的值
            reaper.AK_AkJson_Map_Set(map_ak, key, value)
        end
    end

    return map_ak
end

---@param result AK_Map
---@param key_str string
---@return table Value_table
function AK_Module.Get_ObjectValue(result, key_str)
    Value_table = {} -- 初始化返回表，避免返回nil

    Status = reaper.AK_AkJson_GetStatus(result)
    if not Status then
        reaper.ShowConsoleMsg("result 返回值为空\n")
        return Value_table
    end

    -- 兼容获取 objects/return 键（优先级：objects → return）
    local objects = nil
    -- 先尝试获取 objects（对应 ak.wwise.ui.getSelectedObjects）
    objects = reaper.AK_AkJson_Map_Get(result, "objects")
    -- 若 objects 为空/不存在，尝试获取 return（对应 ak.wwise.core.object.get）
    if not objects or reaper.AK_AkJson_Array_Size(objects) == 0 then
        objects = reaper.AK_AkJson_Map_Get(result, "return")
        -- 二次判空：若return也不存在，直接返回空表
        if not objects then
            reaper.ShowConsoleMsg("result 中未找到 objects/return 字段\n")
            return Value_table
        end
    end
    
    for i = 0, reaper.AK_AkJson_Array_Size(objects) - 1 do
        local item = reaper.AK_AkJson_Array_Get(objects, i) --[[@as AK_Map]]
        -- 如果传入key_str取值为「“children” + 点 + 纯字母数字后缀」格式（如 "children.name"），需要二次历遍获取
        if string.match(key_str, "^children%.%w+$") then
            local array_ak = reaper.AK_AkJson_Map_Get(item, key_str) --[[@as AK_Array]]
            for j = 0, reaper.AK_AkJson_Array_Size(array_ak) - 1 do
                local value_ak = reaper.AK_AkJson_Array_Get(array_ak, j) --[[@as AK_Variant]]
                Value_str = reaper.AK_AkVariant_GetString(value_ak)
                table.insert(Value_table, Value_str)
                -- reaper.ShowConsoleMsg("对象信息: " .. tostring(Value_str) .. "\n")

            end
            
        else
            local value_ak = reaper.AK_AkJson_Map_Get(item, key_str) --[[@as AK_Variant]]
            Value_str = reaper.AK_AkVariant_GetString(value_ak)
            table.insert(Value_table, Value_str)
            -- reaper.ShowConsoleMsg("对象信息: " .. tostring(Value_str) .. "\n")
            
        end

    end
    
    return Value_table
end

return AK_Module
--@noindex

package.path = package.path..';'..debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- 将模块目录添加到package.path中
AM = require("AK_Module")
TF = require("Tool_Func")

AK_Func = {}

function AK_Func.init ()
    -- 初始化函数，连接Wwise
    if not reaper.AK_Waapi_Connect("127.0.0.1", 8080) then
        reaper.ShowConsoleMsg("连接 Wwise 失败")
        return
    end
    reaper.ShowConsoleMsg("连接 Wwise 成功\n\n")
end

function AK_Func.disconnect()
    -- 断开Wwise连接
    reaper.AK_AkJson_ClearAll()
    reaper.AK_Waapi_Disconnect()

    reaper.ShowConsoleMsg("已断开 Wwise 连接\n\n")

end

---@param parent_id string
---@param obj_name string
---@param rs_int number
---@param onNameConflict string
---@return AK_Map result_ak
function AK_Func.rs_container_create(parent_id, obj_name, rs_int, onNameConflict)
    local result_ak
    local rs_int = rs_int or 1
    local onNameConflict = onNameConflict or "merge"

    local args = reaper.AK_AkJson_Map()
    local key_list = { "onNameConflict", "parent", "type", "name", "@RandomOrSequence" }
    local value_list = { onNameConflict, parent_id, "RandomSequenceContainer", obj_name, rs_int }
    AM.TwoTableToAKMap(args, key_list, value_list)

    result_ak = reaper.AK_Waapi_Call("ak.wwise.core.object.create", args, reaper.AK_AkJson_Map())
    local status = reaper.AK_AkJson_GetStatus(result_ak)
    if not status then
        reaper.ShowConsoleMsg("Wwise创建RandomSequenceContainer失败")

        reaper.AK_AkJson_ClearAll()
        reaper.AK_Waapi_Disconnect()
        return result_ak
    end
    reaper.ShowConsoleMsg("创建RandomSequenceContainer成功")

    return result_ak
end


---@param parent string id or path
---@param obj_type string
---@param obj_name string
---@param onNameConflict string
---@return AK_Map result_ak, boolean state
function AK_Func.object_create(parent, obj_type, obj_name, onNameConflict)
    local result_ak
    local onNameConflict = onNameConflict or "merge"

    local args = reaper.AK_AkJson_Map()
    local key_list = { "onNameConflict", "parent", "type", "name" }
    local value_list = { onNameConflict, parent, obj_type, obj_name }
    AM.TwoTableToAKMap(args, key_list, value_list)

    result_ak = reaper.AK_Waapi_Call("ak.wwise.core.object.create", args, reaper.AK_AkJson_Map())
    local status = reaper.AK_AkJson_GetStatus(result_ak)
    if not status then
        reaper.ShowConsoleMsg("Wwise创建" .. obj_name .. "[" .. obj_type .. "]" .. "失败")

        return result_ak, false
    end
    reaper.ShowConsoleMsg("Wwise创建" .. obj_name .. "[" .. obj_type .. "]" .. "成功\n")

    return result_ak, true
end

---@param parent_path string 父级目录的路径，默认为 "\\Events"
---@param parent_type string 父级目录的类型，默认为 "Work Unit"
---@param parent_name string 创建Event的父级路径，需要创建在哪个目录or文件夹下，默认为 "Default Work Unit"
---@param onNameConflict string 导入方式，默认为 "merge"
---@param name_table table Event名称表
---@param target_id_table table 需要创建的Event的对象ID表
---@param actionType string Action类型，默认为 "1"(Play)，可修改为 "2"(Stop)
---@return AK_Map result_ak, boolean state state为true表示成功，false表示失败，result_ak为返回的AK_Map
function AK_Func.event_creat(parent_path, parent_type, parent_name, onNameConflict, name_table, target_id_table, actionType)
    
    local parent_path = parent_path or "\\Events"
    local parent_type = parent_type or "Work Unit"
    local parent_name = parent_name or "Default Work Unit"
    local onNameConflict = onNameConflict or "merge"
    local actionType = actionType or"1"
    --------------------------------------
    local args = reaper.AK_AkJson_Map()
    
    local children_Array = reaper.AK_AkJson_Array()
    
    local result_ak
    --------------------------------------
    for name, target_id in TF.zip(name_table, target_id_table) do
        -- child_Map
        local child_Map = reaper.AK_AkJson_Map()

        if actionType == "1" then
            AM.TwoTableToAKMap(child_Map, { "name", "type" }, { "Play_" .. name, "Event" })
        elseif actionType == "2" then
            AM.TwoTableToAKMap(child_Map, { "name", "type" }, { "Stop_" .. name, "Event" })
        else
            reaper.ShowConsoleMsg("actionType参数错误: 1 - Play or 2 - Stop \n")
            return result_ak, false
        end
        
        -- target_Map
        local target_Array = reaper.AK_AkJson_Array()
        local target_Map = reaper.AK_AkJson_Map()
        local tar_key_list = {"name", "type", "@ActionType", "@Target"}
        local tar_value_list = {"", "Action", actionType, target_id}
        AM.TwoTableToAKMap(target_Map, tar_key_list, tar_value_list)

        if actionType == "2" then
            -- 创建Stop Event 的话，需要添加 @Scope（1-Global） 和 @FadeTime (0.8s)
            reaper.AK_AkJson_Map_Set(target_Map, "@Scope", reaper.AK_AkVariant_String("1"))
            reaper.AK_AkJson_Map_Set(target_Map, "@FadeTime", reaper.AK_AkVariant_String("0.8"))

        end
    
        -- child_Map 添加 "children"
        reaper.AK_AkJson_Array_Add(target_Array, target_Map)
        reaper.AK_AkJson_Map_Set(child_Map, "children", target_Array)
    
        reaper.AK_AkJson_Array_Add(children_Array, child_Map)
    end
    --------------------------------
    -- args_Map
    local args_key_list = { "parent", "type", "name", "onNameConflict", "children" }
    local args_value_list = { parent_path, parent_type, parent_name, onNameConflict, children_Array }
    AM.TwoTableToAKMap(args, args_key_list, args_value_list)
    --------------------------------
    
    result_ak = reaper.AK_Waapi_Call("ak.wwise.core.object.create", args, reaper.AK_AkJson_Map())
    if not reaper.AK_AkJson_GetStatus(result_ak) then
        reaper.ShowConsoleMsg("Event创建失败\n")
        return result_ak, false
    end

    for _, name in pairs(name_table) do
        if actionType == "1" then
            reaper.ShowConsoleMsg("Play_" .. name .. "创建成功\n")
        elseif actionType == "2" then
            reaper.ShowConsoleMsg("Stop_" .. name .. "创建成功\n")
        end
    end

    return result_ak, true
end

---@param actionType string Action类型，默认为 "1"(Play)，可修改为 "2"(Stop)
---@param name_table table Event名称表
---@param target_id_table table 需要创建的Event的对象ID表
---@return AK_Map result_ak, boolean state state为true表示成功，false表示失败，result_ak为返回的AK_Map
function AK_Func.event_creat_FromOld(actionType, name_table, target_id_table) -- 按照Actor路径创建Event
    local result_ak, state = reaper.AK_AkJson_Map(), false

    local obj_parent_ak = AF.object_get(target_id_table[1], {"parent.id"})
    local object_parent_id = AM.Get_ObjectValue(obj_parent_ak, "parent.id")[1]
    local par_children_ak = AF.object_get(object_parent_id, { "children.id" }) -- 获取到父级的所有子级对象
    local par_children_table = AM.Get_ObjectValue(par_children_ak, "children.id") -- 获取到父级的所有子级对象ID表
    local e_parent_path, e_parent_type = "", ""
    for _, child_id in pairs(par_children_table) do
        local child_refer_ak = AF.object_get(child_id, { "referencesTo.id" })     
        if reaper.AK_AkJson_GetStatus(child_refer_ak) then
            local refer_return_ak = reaper.AK_AkJson_Map_Get(child_refer_ak, 'return') --[[@as AK_Array]]
            local refer_id_map = reaper.AK_AkJson_Array_Get(refer_return_ak, 0)      --[[@as AK_Map]]
            local refer_id_array = reaper.AK_AkJson_Map_Get(refer_id_map, 'referencesTo.id') --[[@as AK_Array]]
            local refer_id_variant = reaper.AK_AkJson_Array_Get(refer_id_array, 0)      --[[@as AK_Variant]]
            local refer_id = reaper.AK_AkVariant_GetString(refer_id_variant) or "" --[[@as string]]          -- 获取到reference的ID
            if refer_id ~= "" then
                local event_info_ak = AF.object_get(refer_id, { "parent.parent.path", "parent.parent.type" }) -- 获取到reference的名称

                e_parent_path = AM.Get_ObjectValue(event_info_ak, "parent.parent.path")[1] -- 获取到reference的路径
                e_parent_type = AM.Get_ObjectValue(event_info_ak, "parent.parent.type")[1] -- 获取到reference的类型
                reaper.ShowConsoleMsg("找到已有资源的Event创建路径：" .. e_parent_path .. "类型:" .. e_parent_type .. "\n")
                break
            end
        end
    end

    if e_parent_path == "" then
        reaper.ShowConsoleMsg("未找到已有资源的Event创建路径，请检测同层级已有资源是否存在Event引用关系！\n")
        return reaper.AK_AkJson_Map(), false
    end
    
    local e_par_cr_path = e_parent_path:match("(.*)[\\/]") or "\\Events"
    local e_parent_name = e_parent_path:match("[^\\]+\\([^\\]+)$") or "Default Work Unit" -- 获取到父级Event的名称
    result_ak, state = AF.event_creat(e_par_cr_path, e_parent_type, e_parent_name, "merge", name_table, target_id_table, actionType)
    
    if not reaper.AK_AkJson_GetStatus(result_ak) then
        reaper.ShowConsoleMsg('Folder创建失败，尝试使用Work Unit')
        result_ak, state = AF.event_creat(e_par_cr_path, "Work Unit", e_parent_name, "merge", name_table, target_id_table, actionType)
    end
    
    return result_ak, state
end

---@param path string Actor路径
---@param actionType string Action类型，默认为 "1"(Play)，可修改为 "2"(Stop)
---@param name_table table Event名称表
---@param target_id_table table 需要创建的Event的对象ID表
---@param path_mode string path传入模式，默认为 "1"(Object路径)，可修改为 "2"(Object的Parent路径)
---@return AK_Map result_ak, boolean state state为true表示成功，false表示失败，result_ak为返回的AK_Map
function AK_Func.event_creat_FromActorPath(path, actionType, name_table, target_id_table, path_mode) -- 按照Actor路径创建Event
    local object_path

    if path_mode == "1" then
        object_path = path
    elseif path_mode == "2" then
        object_path = path .. "\\objectName"
    end

    local path_parts = {}
    for part in object_path:gmatch("[^\\]+") do
        table.insert(path_parts, part)
    end
    local folderName2_last = path_parts[#path_parts - 1] -- 取倒数第 2 个 目录名称

    local folderName2_3_last = ""                        -- 取 第2 ~倒数第3 目录路径
    for i = 2, #path_parts - 2 do
        folderName2_3_last = folderName2_3_last .. "\\" .. path_parts[i]
    end

    --------------------------------------
    local parent_path = "\\Events" ..  folderName2_3_last  -- 导入的父级文件夹必须存在，需提前创建目标导入父级
    local parent_type = "Folder"
    local parent_name = folderName2_last
    local onNameConflict = "merge"


    local res_creat_ak, state
    res_creat_ak, state = AK_Func.event_creat(parent_path, parent_type, parent_name, onNameConflict, name_table, target_id_table, actionType)
    -- AK_Func.event_creat(parent_path, parent_type, parent_name, onNameConflict, name_table, target_id_table, "2")

    if not state then
        --[[
    -- 废弃逻辑参考：如果创建失败，尝试重取父级目录，再次创建Event
        for i = 3, #path_parts - 1 do -- #path_parts-1 防止减到自身长度取到0的nil空值报错,保证后续索引永远 ≥1
            reaper.ShowConsoleMsg("尝试重取父级目录，再次创建Event\n")
            parent_path = "\\Events" .. "\\" .. path_parts[#path_parts - i]
            parent_name = path_parts[#path_parts - (i - 1)]

            res_creat_ak, state = Event_creat(parent_path, parent_type, parent_name, onNameConflict, name_table, target_id_table, "1")
            if state then
                break
            end
        end
        if not state then
            reaper.ShowConsoleMsg("重取父级目录失败，请检查路径中的父级目录名称是否在Events下存在\n")
        end

     ]]

        reaper.ShowConsoleMsg("尝试依次创建父级目录后再次创建Event —— 首级为WorkUnit 其余为Folder\n")

        AF.object_create("\\Events", "Work Unit", path_parts[2], "merge")
        res_creat_ak, state = AK_Func.event_creat(parent_path, parent_type, parent_name, onNameConflict, name_table, target_id_table, actionType)

        if not state then
            local p_path = "\\Events"
            for i = 3, #path_parts - 1 do
                p_path = p_path .. "\\" .. path_parts[i - 1]
                AF.object_create(p_path, "Folder", path_parts[i], "merge")
                res_creat_ak, state = AK_Func.event_creat(parent_path, parent_type, parent_name, onNameConflict, name_table,
                    target_id_table, actionType)

                if state then
                    break
                end
            end
            if not state then
                reaper.ShowConsoleMsg("Event创建失败，若Events路径下有新建文件夹不需要，则撤回后再次重试\n")
            end
        end
    end
    return res_creat_ak, state

end


---@param parent_id string 父级ID
---@param obj_type string 子对象容器类型：'WorkUnit', 'Folder', 'RandomContainer', 'ActorMixer', 'SequenceContainer', 'SwitchContainer', 'BlendContainer', 'Sound'
---@param obj_name string 子对象容器名称
---@param onNameConflict string 冲突处理方式：'merge', 'replace', 'rename'
---@return AK_Map result_ak
function AK_Func.container_create(parent_id, obj_type, obj_name, onNameConflict)
    local result_ak
    local onNameConflict = onNameConflict or "merge"
    
    if obj_type == "RandomContainer" then
        result_ak = AK_Func.rs_container_create(parent_id, obj_name, 1, onNameConflict)
    
    elseif obj_type == "SequenceContainer" then
        result_ak = AK_Func.rs_container_create(parent_id, obj_name, 0, onNameConflict)
    
    else
        result_ak = AK_Func.object_create(parent_id, obj_type, obj_name, onNameConflict)
        
    end
    
    return result_ak
end

---@param importOperation string 导入操作：'replaceExisting', 'useExisting', 'merge'
---@param importLanguage_table table 导入语言表
---@param originalsSubFolder_table table
---@param audioFile_table table
---@param objectPath_table table
---@param objectType string
---@param opt_list table
---@return AK_Map result_ak
function AK_Func.audio_importWwise(importOperation, importLanguage_table, originalsSubFolder_table, audioFile_table, objectPath_table, objectType, opt_list)
    --[[
    "imports": [
            {
                "originalsSubFolder":originalsSubFolder,
                "audioFile": audioFile,
                "objectPath": objectPath,
                "objectType":objectType,
                "importLanguage": "SFX"
            }
        ]
    ]]
    
    local imports = reaper.AK_AkJson_Array()
    
    
    for importLanguage, originalsSubFolder, audioFile, objectPath in TF.zip(importLanguage_table, originalsSubFolder_table, audioFile_table, objectPath_table) do
        local key_list = { "originalsSubFolder", "audioFile", "objectPath", "objectType", "importLanguage" }
        local value_list = { originalsSubFolder, audioFile, objectPath, objectType, importLanguage }
        
        local importItem = reaper.AK_AkJson_Map()
        AM.TwoTableToAKMap(importItem, key_list, value_list)
        reaper.AK_AkJson_Array_Add(imports, importItem)
        

        reaper.ShowConsoleMsg(audioFile .. " 导入: " .. objectPath .. "\n")
        if importLanguage == "SFX" then
            reaper.ShowConsoleMsg("originals路径: \\Originals\\" .. importLanguage .. "\\" .. originalsSubFolder .. "\n")
        else
            reaper.ShowConsoleMsg("originals路径: \\Originals\\Voices\\" .. importLanguage .. "\\" .. originalsSubFolder .. "\n")
        end
    end

    --[[
    args = {
        "importOperation": "replaceExisting",
        "default": {
            "importLanguage": "SFX"
        },
        "imports": [
            {
                "originalsSubFolder":originalsSubFolder,
                "audioFile": audioFile,
                "objectPath": objectPath,
                "objectType":objectType
            }
        ]
    }
     ]]
    local args = reaper.AK_AkJson_Map()
    AM.MapSet_str(args, "importOperation", importOperation)
    reaper.AK_AkJson_Map_Set(args, "imports", imports)

    --[[
    options = {
        "return": ["name","path","originalFilePath"]
    }
    ]]
    local options = reaper.AK_AkJson_Map()
    local opt_ak = reaper.AK_AkJson_Array()

    local options_list = opt_list
    AM.ArrayToAKArray(opt_ak, options_list)
    reaper.AK_AkJson_Map_Set(options, "return", opt_ak)

    local import_result_Map = reaper.AK_Waapi_Call("ak.wwise.core.audio.import", args, options)
    local status = reaper.AK_AkJson_GetStatus(import_result_Map)

    if status then
        reaper.ShowConsoleMsg("【ak.wwise.core.audio.import 执行成功】" .. "\n")
    else
        reaper.ShowConsoleMsg("【ak.wwise.core.audio.import 执行失败】，请检查路径获取是否正确" .. "\n")
    end

    return import_result_Map -- return import_result_Map: AK_Map
end

---@param result AK_Map
function AK_Func.errorMsg(result)
    local errorMessage = reaper.AK_AkJson_Map_Get(result, "message") --[[@as AK_Variant]]
    local errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)

    reaper.ShowConsoleMsg("Import failed: " .. errorMessageStr .. "\n")

    local details = reaper.AK_AkJson_Map_Get(result, "details") --[[@as AK_Map]]
    local log = reaper.AK_AkJson_Map_Get(details, "log") --[[@as AK_Array]]
    local logSize = reaper.AK_AkJson_Array_Size(log)

    for i = 0, logSize - 1 do
        local logItem = reaper.AK_AkJson_Array_Get(log, i) --[[@as AK_Map]]
        local logItemMessage = reaper.AK_AkJson_Map_Get(logItem, "message") --[[@as AK_Variant]]
        local logItemMessageStr = reaper.AK_AkVariant_GetString(logItemMessage)
        reaper.ShowConsoleMsg("[" .. i .. "]" .. logItemMessageStr .. "\n")
    end
    
end

---@param object_id string
---@param returns_table table
---@return AK_Map result_ak
function AK_Func.object_get(object_id, returns_table)
    local result_ak
    -- 构造返回字段
    local returns = reaper.AK_AkJson_Array()
    AM.ArrayAdd_table(returns, returns_table)

    local waql_query = "$\"" ..  object_id .. "\""
    local args = reaper.AK_AkJson_Map()
    AM.MapSet_str(args, "waql", waql_query)

    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", returns)

    -- 获取选中对象
    result_ak = reaper.AK_Waapi_Call("ak.wwise.core.object.get", args, options)
    local status = reaper.AK_AkJson_GetStatus(result_ak)
    if not status then
        reaper.ShowConsoleMsg("获取对象失败，确认对象ID是否正确")

        reaper.AK_AkJson_ClearAll()
        reaper.AK_Waapi_Disconnect()
        return result_ak
    end

    return result_ak
end

---@param returns_table table
---@return AK_Map result_ak
function AK_Func.ui_getSelectedObjects(returns_table)
    local result_ak
    -- 构造返回字段
    local returns = reaper.AK_AkJson_Array()
    local returns_table = returns_table
    AM.ArrayAdd_table(returns, returns_table)

    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", returns)

    -- 获取选中对象
    result_ak = reaper.AK_Waapi_Call("ak.wwise.ui.getSelectedObjects", reaper.AK_AkJson_Map(), options)
    local status = reaper.AK_AkJson_GetStatus(result_ak)
    if not status then
        reaper.ShowConsoleMsg("获取选中对象失败，确认wwise界面已选中对象后重新运行")

        reaper.AK_AkJson_ClearAll()
        reaper.AK_Waapi_Disconnect()
        return result_ak
    end
    
    return result_ak
end

---@param result AK_Map
---@return table FilePath
function AK_Func.getfilePath_FromSelectedSound(result)

    local filePath = {}
    local result_type = AM.Get_ObjectValue(result, "type")
    -- DebugMsg(result_type)

    -- 仅当选中对象为 Sound 类型时才继续获取音频路径
    for i, t in ipairs(result_type) do
        if t ~= "Sound" and t ~= "sound" then
            reaper.ShowConsoleMsg("当前选中对象类型为: " .. tostring(t) .. "\n请选中一个 Sound 对象后再执行。")
            return filePath
        end
    end

    filePath = AM.Get_ObjectValue(result, "sound:originalWavFilePath")
    -- DebugMsg(filePath)
    return filePath

end

---@param filePath_table table wav文件路径列表
---@param name_table table 对象名称列表
---@return table tr1_table 轨道结构tr1，MediaTrack对象的表
function AK_Func.importReaper_FromSound(filePath_table, name_table)
    for filePath, name in TF.zip(filePath_table, name_table) do
        -- 获取【当前工程】的完整路径（.rpp 文件）
        local retval, projfn = reaper.EnumProjects(-1)
        if not projfn then
            reaper.ShowConsoleMsg("未获取当前工程路径")
            return {}
        end

        -- 复制wav文件到：当前工程所在目录 + "\Media\" + "name.wav"
        local filename = (filePath:match("[^\\/]+$") or ""):match("^(.+)%..+$") or ""
        local dir_proj = projfn:match(".+[\\/]")
        local destPath = dir_proj .. "Media\\" .. filename .. ".wav"

        -- 复制文件,失败则创建Media文件夹后再次复制
        local dir_Media = dir_proj .. "Media"
        if TF.copyFile(filePath, destPath) == false then
            os.execute("md \"" .. dir_Media .. "\" > nul 2>&1")
            TF.copyFile(filePath, destPath)
        end

        -- 显示结果
        reaper.ShowConsoleMsg("Sound对象：" .. name .. "\n" .. filePath .. "已复制到 " .. destPath .. "\n\n")

        -- reaper工程创建指定轨道结构
        local originalsSubFolder, lang_marker = TF.get_originalsSubFolder(filePath, "")
        
        local last_track = reaper.GetTrack(0, reaper.CountTracks(0) - 1)
        reaper.SetOnlyTrackSelected(last_track)
        
        -- 子轨道添加音频Item，编辑光标空开20s，避免重叠
        TF.addAudioToTrack(destPath, 20, true)
        
        -- 创建指定路径的轨道结构
        local tr1_table = TF.createStructure_items(originalsSubFolder, lang_marker)

        return tr1_table
    end

    -- 重新统一颜色，防止自动播放
    TF.setColor_ItemAndTrack()
    TF.playAndStop()

    reaper.ShowConsoleMsg("wav导入到reaper工程完成！" .. "\n\n")    
    
end

--- 递归查找所有type为Sound/sound的子项ID（去重），直接返回结果表
---@param object_id string 父对象ID
---@param depth number 可选：递归深度（内部使用，外部无需传）
---@return table child_table 包含所有不重复Sound类型child_id的表（无匹配则返回空表）
function AK_Func.getChild_SoundId(object_id, depth)
    -- 初始化结果表（当前层级的ID容器）
    local child_table = {}
    -- 递归深度限制：避免死递归（建议保留）
    depth = depth or 0
    local max_depth = 100
    if depth > max_depth then
        reaper.ShowConsoleMsg("递归深度超过限制，终止：object_id=" .. tostring(object_id) .. "\n")
        return child_table
    end

    -- 1. 获取子项数据
    local returns_table = { "children.id", "children.type" }
    local result_ak = AK_Func.object_get(object_id, returns_table)
    if not result_ak then
        reaper.ShowConsoleMsg("获取子项失败：object_id=" .. tostring(object_id) .. "\n")
        return child_table
    end

    -- 2. 解析ID和type表，空值兜底
    local id_table = AM.Get_ObjectValue(result_ak, "children.id") or {}
    local type_table = AM.Get_ObjectValue(result_ak, "children.type") or {}

    -- 3. 遍历当前层级子项
    for idx, child_id in ipairs(id_table) do
        local child_type = type_table[idx]
        local type_lower = string.lower(child_type or "")

        -- 3.1 找到Sound/sound类型 → 去重后插入当前表
        if type_lower == "sound" then
            if not TF.is_id_duplicate(child_table, child_id) then
                table.insert(child_table, child_id)
                -- reaper.ShowConsoleMsg("找到Sound类型子项（去重后）：id=" .. child_id .. "\n")
            else
                reaper.ShowConsoleMsg("ID已存在，跳过：" .. child_id .. "\n")
            end
        end

        -- 3.2 递归遍历子项的子项，获取子结果表并去重合并
        local sub_child_table = AK_Func.getChild_SoundId(child_id, depth + 1)
        -- 遍历子表，去重后合并到当前表
        for _, sub_id in ipairs(sub_child_table) do
            if not TF.is_id_duplicate(child_table, sub_id) then
                table.insert(child_table, sub_id)
                -- reaper.ShowConsoleMsg("合并子层级Sound ID（去重后）：id=" .. sub_id .. "\n")
            end
        end
    end

    -- 4. 顶层调用时提示无结果（可选）
    if #id_table == 0 and depth == 0 then
        reaper.ShowConsoleMsg("无可用子项：object_id=" .. tostring(object_id) .. "\n")
    end

    -- 5. 返回去重后的结果表
    return child_table
end

--[[ 
-- ============== 调用示例 ==============
-- 1. 调用函数，直接接收去重后的结果表
local parent_object_id = "{874CC972-8752-4D28-9563-0ABFCEFA1DCB}"
local sound_id_table = AK_Func.getChild_SoundId(parent_object_id,5)

-- 2. 打印结果（验证去重效果）
reaper.ShowConsoleMsg("\n===== 去重后所有Sound类型子项ID =====\n")
if #sound_id_table == 0 then
    reaper.ShowConsoleMsg("未找到任何Sound类型子项\n")
else
    for i, id in ipairs(sound_id_table) do
        reaper.ShowConsoleMsg(i .. ": " .. id .. "\n")
    end
end
 ]]


return AK_Func
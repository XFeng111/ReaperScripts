--@noindex

-- 调试脚本开始
-- dofile(reaper.GetResourcePath() .."/Scripts/XFeng111_ReaperScripts/LUA Sockets/Reaper_MobDebug.lua")

--[[ AK_Module.lua | AK_Func.lua | Tool_Func.lua脚本必须放在： 
Reaper安装路径/Scripts/XFeng111_ReaperScripts/Tools/ReaWwise_Tool/module/... 
否则require找不到模块 ]]
package.path = package.path..';'.. debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]:match("(.*[\\/])[^\\/]+[\\/]?$") .. "module/?.lua;" -- 将模块目录添加到package.path中

AM = require("AK_Module")
AF = require("AK_Func")
TF = require("Tool_Func")

-- ==============================================

---@param object_id string
---@param returns_table table
---@return table s_filePath_table, table s_name_table, table s_path_table, table sp_typeNote_table 文件路径表，名称表，路径表，父类型表
local function importReaper_getImportArgsTable(object_id, returns_table)
    local s_filePath_table, s_name_table, s_path_table, sp_type_table, sp_typeNote_table = {}, {}, {}, {}, {}
    
    local res_ak = AF.object_get(object_id, returns_table)
    local filePath = AF.getfilePath_FromSelectedSound(res_ak)
    local name = AM.Get_ObjectValue(res_ak, "name")
    local path = AM.Get_ObjectValue(res_ak, "path")
    local parentType = AM.Get_ObjectValue(res_ak, "parent.type")
    TF.table_append(s_filePath_table, filePath)
    TF.table_append(s_name_table, name)
    TF.table_append(s_path_table, path)

    TF.table_append(sp_type_table, parentType)
    TF.getTypeNote_table(sp_type_table, sp_typeNote_table, true)
    return s_filePath_table, s_name_table, s_path_table, sp_typeNote_table
end

---@param parentType_table table 传入的父类型表
---@param parentPath_table table 传入的父路径表
---@param sound_id_table table 传入的Sound对象id总表
---@param s_id string 对象id，该对象应为Sound类型
---@param returns_table table 返回值表
---@return table parentType_table, table parentPath_table, table sound_id_table 父类型表，父路径表，Sound对象id总表
local function importReaper_getStructureArgsTable(parentType_table, parentPath_table, sound_id_table, s_id, returns_table)
    local res_ak = AF.object_get(s_id, returns_table)
    local s_pt_table = AM.Get_ObjectValue(res_ak, "parent.type")
    local s_pp_table = AM.Get_ObjectValue(res_ak, "parent.path")
    local s_id_table = AM.Get_ObjectValue(res_ak, "id")

    TF.table_append(parentType_table, s_pt_table)
    TF.table_append(parentPath_table, s_pp_table)
    TF.table_append(sound_id_table, s_id_table)
    return parentType_table, parentPath_table, sound_id_table
end

---@param id string 对象id
---@param returns_table table 返回值表
---@param type_child_table table 子轨道对象类型表
---@param tr1_child_table table 传入子轨道结构tr1，MediaTrack对象的表
---@return table tr1_child_table 子轨道结构tr1，MediaTrack对象的表
local function importReaper_FromSound_GetTr1ChildTable(id, returns_table, type_child_table, tr1_child_table)
    local t1 = type_child_table[1]
    
    if t1 == "Sound" or t1 == "sound" then
        local s_filePath_table, s_name_table, _, _ = importReaper_getImportArgsTable(id, returns_table)
        local tr1_table = AF.importReaper_FromSound(s_filePath_table, s_name_table)

        TF.table_append(tr1_child_table, tr1_table)
    else
        reaper.ShowConsoleMsg(id .. "不是Sound类型，导入失败")
    end
    
    return tr1_child_table
end


---@param parentType_table table 父类型表
---@param parentPath_table table 父路径表
---@param id_table table 对象id表
---@param returns_table table 返回值表
local function importReaper_createStructure(parentType_table, parentPath_table, id_table, returns_table)
    local pp_pt_merged_dict = TF.mergeToParentIdDict(parentPath_table, parentType_table, true)
    local pp_id_merged_dict = TF.mergeToParentIdDict(parentPath_table, id_table, true)
    
    
    for parent_path, id_list in pairs(pp_id_merged_dict) do
        local parent_type = pp_pt_merged_dict[parent_path][1]
        local tr1_child_table = {} -- 子轨道结构tr1，MediaTrack对象的表

        for i, id in ipairs(id_list) do
            local res_ak = AF.object_get(id, returns_table)
            local type_child_table = AM.Get_ObjectValue(res_ak, "type")

            importReaper_FromSound_GetTr1ChildTable(id, returns_table, type_child_table, tr1_child_table)
        end

        TF.createStructure_Folder(parent_path, parent_type, tr1_child_table)
    end

end


-- ==============================================

function Rea_ImportReaper()

    local returns_table = {"sound:originalWavFilePath", "name", "type", "path", "id", "parent.path", "parent.type"}
    local result_ak = AF.ui_getSelectedObjects(returns_table)
    local id_table = AM.Get_ObjectValue(result_ak, "id")
    local type_table = AM.Get_ObjectValue(result_ak, "type")
    local path_table = AM.Get_ObjectValue(result_ak, "path")
    
    
    reaper.InsertTrackAtIndex(reaper.CountTracks(0), true) -- 创建一个空轨道
    local pr_track = reaper.GetTrack(0, reaper.CountTracks(0) - 1) -- 获取新创建的空轨道
    
    for id, type, path in TF.zip(id_table, type_table, path_table) do
        if type == "Sound" or type == "sound" then
            local parentType_table, parentPath_table, sound_id_table = {}, {}, {}

            importReaper_getStructureArgsTable(parentType_table, parentPath_table, sound_id_table, id, returns_table) -- 获取创建reaper轨道结构所需的参数
            importReaper_createStructure(parentType_table, parentPath_table, sound_id_table, returns_table)
        else
            local child_SoundId_table = AF.getChild_SoundId(id, 5)
            local parentType_table, parentPath_table, sound_id_table = {}, {}, {}

            for i, s_id in ipairs(child_SoundId_table) do
                importReaper_getStructureArgsTable(parentType_table, parentPath_table, sound_id_table, s_id, returns_table) -- 获取创建reaper轨道结构所需的参数
            end
            importReaper_createStructure(parentType_table, parentPath_table, sound_id_table, returns_table)

        end

        
        reaper.Main_OnCommand(40296, 0) -- 轨道: 选择所有轨道 ⇌ Track: Select all tracks
        reaper.Main_OnCommand(40358, 0) -- 轨道: 设置为随机颜色 ⇌ Track: Set to random colors
        TF.setColor_ItemAndTrack()
        
        -- 同名父轨道下的子轨道合并
        local type_note = TF.getTypeNote_table({type}, {}, true)[1]
        local pr_name = "[" .. type_note .. "]" .. path .. "\\"
        local idx_prTrack_sameName = TF.getParentTrackNameToIdx_Map(pr_track)[pr_name] -- 获取父轨道名称相同的轨道索引
        if idx_prTrack_sameName then
            local del_track = reaper.GetTrack(0, idx_prTrack_sameName)
            reaper.SetMediaTrackInfo_Value(del_track, "I_FOLDERDEPTH", 0)
            reaper.DeleteTrack(del_track)
        end
        
        reaper.SetMediaTrackInfo_Value(pr_track, "I_FOLDERDEPTH", 1)
        reaper.GetSetMediaTrackInfo_String(pr_track, "P_NAME", pr_name, true)
        reaper.Main_OnCommand(40635, 0) -- 时间选区: 移除 (取消选择) 时间选区 ⇌ Time selection: Remove (unselect) time selection
        
        
    end


end


-- ==============================================
--主函数执行 Rea_ImportReaper
-- ==============================================

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

AF.init() -- 连接Wwise初始化

Rea_ImportReaper()

AF.disconnect() -- 断开Wwise连接

reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("wwise import audio to reaper", -1)

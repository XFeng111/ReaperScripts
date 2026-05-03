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


function Rea_ImportWwise()
    local track_info_params = TF.renderGroupItem()
    local import_results, import_id_table, import_name_table, import_type_table = {}, {}, {}, {}
    
    -- 获取【当前工程】的完整路径（.rpp 文件）
    local retval, projfn = reaper.EnumProjects(-1)
    if not projfn then
        reaper.ShowConsoleMsg("未获取当前工程路径")
        return
    end
    
    local dir = projfn:match(".+[\\/]")
    
    local objectType = "Sound"
    local opt_list = { "id", "name", "type", "path" }
    local importLanguage_table, originalsSubFolder_table, audioFile_table, objectPath_table, crType_table = {}, {}, {}, {}, {}
    
    for group_id, track_info in pairs(track_info_params) do
        if track_info_params == nil then
            reaper.ShowConsoleMsg("未获取到有效的轨道信息")
            return
        end
    
        local filename = track_info.empty_item_notes
    
        local originalsSubFolder, marker = TF.get_originalsSubFolder(track_info.child_2_TrackName, "")
        local audioFile= dir .. "Mixdown\\" .. filename .. ".wav"
        local objectPath = track_info.parent_TrackName:match("%[%a+%](.*)") .. track_info.child_1_TrackName:match("%[%a+%](.*)")
        
        table.insert(crType_table, track_info.parent_TrackName:match("%b[]")) -- 获取父级容器类型标记[ran]/[swi]/...
        table.insert(importLanguage_table, marker)
        table.insert(originalsSubFolder_table, originalsSubFolder)
        table.insert(audioFile_table, audioFile)
        table.insert(objectPath_table, objectPath)
    end
    
    local split_importLanguage_table = TF.splitTable(importLanguage_table, 50)
    local split_originalsSubFolder_table = TF.splitTable(originalsSubFolder_table, 50)
    local split_audioFile_table = TF.splitTable(audioFile_table, 50)
    local split_objectPath_table = TF.splitTable(objectPath_table, 50)

    for i = 1, #split_originalsSubFolder_table do
        local s_importLanguage_table = split_importLanguage_table[i]
        local s_originalsSubFolder_table = split_originalsSubFolder_table[i]
        local s_audioFile_table = split_audioFile_table[i]
        local s_objectPath_table = split_objectPath_table[i]
        -- 临时方式：使用两次import，第一次确保导入的音频文件存在Sound
        -- AF.audio_importWwise("useExisting", s_importLanguage_table, s_originalsSubFolder_table, s_audioFile_table, s_objectPath_table, objectType, opt_list)
        local res = AF.audio_importWwise("useExisting", s_importLanguage_table, s_originalsSubFolder_table, s_audioFile_table, s_objectPath_table, objectType, opt_list)
        table.insert(import_results, res)

        local ids = AM.Get_ObjectValue(res, "id")
        local names = AM.Get_ObjectValue(res, "name")
        local types = AM.Get_ObjectValue(res, "type")
        TF.table_append(import_id_table, ids)
        TF.table_append(import_name_table, names)
        TF.table_append(import_type_table, types)
    end
    reaper.ShowConsoleMsg(#originalsSubFolder_table .. "个，Sound导入完成\n\n")
    
    local import_info_Cr = TF.groupByParentPath(import_type_table, import_id_table, import_name_table, objectPath_table, crType_table, true)
    local import_info_Sound = TF.groupByParentPath(import_type_table, import_id_table, import_name_table, objectPath_table, crType_table, false)
    
    return import_results, import_info_Cr, import_info_Sound
end


-- ==============================================
--主函数执行 Rea_ImportWwise
-- ==============================================

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

AF.init() -- 连接Wwise初始化

Rea_ImportWwise()

AF.disconnect() -- 断开Wwise连接

reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("reaper import audio to wwise", -1)
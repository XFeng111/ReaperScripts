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

function Rea_SetPath_ParentTrack() -- 设置父级Track上的Wwise层级路径
    local folder_TrackName = ""
    local returns_table = {"sound:originalWavFilePath", "name", "type", "path", "id"}
    local result_ak = AF.ui_getSelectedObjects(returns_table)
    local objectId = AM.Get_ObjectValue(result_ak, "id")[1]
    local objectType_table = AM.Get_ObjectValue(result_ak, "type")
    local objectType = objectType_table[1]
    local objectPath = AM.Get_ObjectValue(result_ak, "path")[1] --lua 「1-based 索引」
    
    local typeNote_table = {}
    TF.getTypeNote_table(objectType_table, typeNote_table, true)
    local typeNote = typeNote_table[1]

    local trFolder = reaper.GetSelectedTrack(0, 0)
    local folder_depth = reaper.GetMediaTrackInfo_Value(trFolder, "I_FOLDERDEPTH")

    if not trFolder or folder_depth ~= 1 then
        reaper.ShowConsoleMsg("未选择父级Track！")
        return
    end

    if objectType == "Sound" then
        -- 父轨道名：[sou]'path': '[sou]Actor-Mixer\Footstep\Run\'
        folder_TrackName = "[" .. typeNote .. "]" .. objectPath:sub(1, objectPath:find("\\[^\\]*$"))
    else
        folder_TrackName = "[" .. typeNote .. "]" .. objectPath .. "\\"
    end
    
    reaper.GetSetMediaTrackInfo_String(trFolder, "P_NAME", folder_TrackName, true)
    reaper.ShowConsoleMsg("父级文件夹轨道名称:" .. folder_TrackName .. "\n类型：" .. objectType .. "\n设置完成！" .. "\n\n")    
end


-- ==============================================
--主函数执行 Rea_SetPath_ParentTrack
-- ==============================================

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

AF.init() -- 连接Wwise初始化

Rea_SetPath_ParentTrack()

-- 如果[r]开头的情况Wwise内创建随机容器
-- local parent_id = "{1FEE4F5A-9C7F-4CE3-B074-3AB546A3BA35}"
-- AF.rs_container_create(parent_id, "A", 1)
-- AF.object_create(parent_id, "ActorMixer", "B")

AF.disconnect() -- 断开Wwise连接

reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Rea_SetPath_ParentTrack", -1)

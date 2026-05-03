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

---@return table name_table, table type_table, table path_table
function Rea_GetInfo_SelectedObjects() -- 获取Wwise所选对象信息
    local returns_table = {"sound:originalWavFilePath", "name", "type", "path", "id"}
    local result_ak = AF.ui_getSelectedObjects(returns_table)
    local name_table = AM.Get_ObjectValue(result_ak, "name")
    local type_table = AM.Get_ObjectValue(result_ak, "type")
    local path_table = AM.Get_ObjectValue(result_ak, "path")
    
    reaper.ShowConsoleMsg("【获取Wwise所选对象信息】\n")
    for name, type, path in TF.zip(name_table, type_table, path_table) do
        reaper.ShowConsoleMsg("名称： " .. name .. "\n类型： " .. type .. "\n路径： " .. path .. "\n\n")
    end
    return name_table, type_table, path_table
end


-- ==============================================
--主函数执行 Rea_GetInfo_SelectedObjects
-- ==============================================

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

AF.init() -- 连接Wwise初始化

Rea_GetInfo_SelectedObjects()


AF.disconnect() -- 断开Wwise连接

reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Rea_GetInfo_SelectedObjects", -1)

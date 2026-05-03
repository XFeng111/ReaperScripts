-- @noindex

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

---@return string originalsSubFolder, string containerType, string lang_marker -- originalsSubFolder:子文件夹路径，containerType:容器类型, lang_marker:导入语言（音效SFX，语音中文CN，语音英文EN）
local function input_user()
    local originalsSubFolder, containerType, lang_marker = "", "", "SFX"
    local user_ok, input_str = reaper.GetUserInputs("请输入子文件夹名和容器类型", 3, "\\Originals\\SFX\\,Container_Type,导入语言", "Plot\\Common,Random Container,SFX or CN or EN")
    if user_ok then -- 用户点击"确定"
        -- 拆分输入字符串（逗号分隔的两个值）
        originalsSubFolder, containerType = input_str:match("([^,]*),([^,]*)")
        reaper.ShowConsoleMsg("子文件夹路径：" .. originalsSubFolder .. "\n")
        reaper.ShowConsoleMsg("容器类型：" .. containerType .. "\n")
        reaper.ShowConsoleMsg("导入语言：" .. lang_marker .. "\n")
    else -- 用户点击"取消"
        reaper.ShowConsoleMsg("用户取消了输入\n")
    end
    
    return originalsSubFolder, containerType, lang_marker
end

---@param container_type string
---@param parent_path string
---@return table tr_name, table tr_container_name -- tr_name:轨道名称，tr_container_name:Wwise容器名称
local function set_container(container_type, parent_path)
    local tr_name_table = {}
    local tr_container_name_table = {}
    ------------------------------------------
    -- 步骤1：定义核心工具函数
    ------------------------------------------
    -- 函数1：提取轨道名称前缀（去掉_数字尾缀）
    -- 示例："A_01" → "A"，"B_123" → "B"，"C" → nil
    local function extractPrefix_name(track_name)
        if type(track_name) ~= "string" then return nil end
        -- 匹配尾缀：_ + 数字（1个或多个），且在字符串末尾
        local prefix_name = track_name:match("^(.*)_%d+$")
        return prefix_name
    end

    ------------------------------------------
    -- 步骤2：收集时间选区内items所在轨道的符合条件的父级轨道（名称尾缀为_数字）
    ------------------------------------------
    local multi_table = {} -- 存储{track = MediaTrack, name = 轨道名}
    local processed_parents = {} -- 避免重复处理同一父轨道

    -- 获取时间选区范围
    local start_time, end_time = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if start_time == end_time then
        reaper.ShowConsoleMsg("错误：未设置时间选区！")
        return tr_name_table, tr_container_name_table
    end

    -- 获取时间选区内的items，并收集其所在轨道
    local tracks_in_range = {}
    local item_count = reaper.CountMediaItems(0)
    for i = 0, item_count - 1 do
        local item = reaper.GetMediaItem(0, i)
        local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        
        -- 判断item是否在时间选区内（部分重叠也计入）
        if not (item_end < start_time or item_start > end_time) then
            local track = reaper.GetMediaItem_Track(item)
            if track and not tracks_in_range[track] then
                tracks_in_range[track] = true
            end
        end
    end

    -- 遍历时间选区内items所在的轨道，获取其符合条件的父轨道
    for track in pairs(tracks_in_range) do
        local parent_track = reaper.GetParentTrack(track)
        if parent_track and not processed_parents[parent_track] then
            -- 标记已处理，避免重复
            processed_parents[parent_track] = true
            
            -- 获取父轨道名称
            local retval, track_name = reaper.GetTrackName(parent_track)
            if retval and track_name ~= "" then
                -- 检查名称是否以_数字结尾
                local prefix_name = extractPrefix_name(track_name)
                if prefix_name then
                    -- 存入multi_table
                    table.insert(multi_table, {
                        track = parent_track,
                        name = track_name,
                        prefix_name = prefix_name -- 提前存储前缀，方便后续分组
                    })
                end
            end
        end
    end

    -- 校验是否有符合条件的轨道
    if #multi_table == 0 then
        reaper.ShowConsoleMsg("未找到名称尾缀为_数字的父级轨道！")
        reaper.PreventUIRefresh(-1)
        reaper.Undo_EndBlock("按父轨道名称分组执行指令", -1)
        return tr_name_table, tr_container_name_table
    end

    ------------------------------------------
    -- 步骤3：按前缀分组轨道
    ------------------------------------------
    local group_map = {} -- 结构：prefix_name → {track1, track2, ...}
    for _, item in ipairs(multi_table) do
        local prefix_name = item.prefix_name
        if not group_map[prefix_name] then
            group_map[prefix_name] = {}
        end
        table.insert(group_map[prefix_name], item.track)
    end

    ------------------------------------------
    -- 步骤4：依次处理每个分组
    ------------------------------------------
    for prefix_name, track_list in pairs(group_map) do
        -- 1. 取消所有轨道选中（确保仅选中当前分组）
        reaper.Main_OnCommand(40297, 0) -- 40297 = 取消所有轨道选中
        
        -- 2. 选中当前分组的所有轨道
        local valid_count = 0
        for _, track in ipairs(track_list) do
            if reaper.ValidatePtr(track, "MediaTrack*") then
                reaper.SetTrackSelected(track, true)
                valid_count = valid_count + 1
            end
        end
        
        -- 3. 执行指定指令（ID:42785 轨道: 将轨道移动到新文件夹）
        if valid_count > 0 then
            reaper.Main_OnCommand(42785, 0) -- 轨道: 将轨道移动到新文件夹 ⇌ Track: Move tracks to new folder
           
            -- 4. 设置Container文件夹轨名称
            local tr_child = track_list[1]
            local tr_parent = reaper.GetParentTrack(tr_child)
            local _, tr_childName = reaper.GetTrackName(tr_child)
            local tr_container_name = extractPrefix_name(tr_childName):match("%[%a+%](.*)") or ""

            local type_note = TF.getTypeNote_table({container_type}, {}, true)[1]
            
            local tr_name = "[" .. type_note .. "]" .. parent_path .. "\\<" .. container_type .. ">" .. tr_container_name .. "\\"
            reaper.GetSetMediaTrackInfo_String(tr_parent, "P_NAME", tr_name, true)

            table.insert(tr_name_table, tr_name)
            table.insert(tr_container_name_table, tr_container_name)
            reaper.ShowConsoleMsg("选中分组[" .. prefix_name .. "]的" .. valid_count .. "个轨道，\n创建Container文件夹轨：" .. tr_container_name .."\n")
        end
        
        -- 5. 可选：添加短暂延迟（防止指令执行不完整，根据需要调整）
        -- reaper.Sleep(100)
    end
    
    ------------------------------------------
    -- 步骤5：收尾操作
    ------------------------------------------
    -- 最终取消所有轨道选中
    reaper.Main_OnCommand(40297, 0) -- 40297 = 取消所有轨道选中
    reaper.ShowConsoleMsg("已处理所有符合条件的父轨道分组")
    
    return tr_name_table, tr_container_name_table
end

-- ==============================================


---@param originalsSubFolder string
---@param containerType string
---@param lang_marker string
function Rea_CreateStructure_items(originalsSubFolder, containerType, lang_marker)
    local res_ak = AF.ui_getSelectedObjects({"id", "path", "type", "name"})
    local parent_id = AM.Get_ObjectValue(res_ak, "id")[1] or ""
    local parent_path = AM.Get_ObjectValue(res_ak, "path")[1] or ""
    local parent_type = AM.Get_ObjectValue(res_ak, "type")[1] or ""
    
    local tr1_table = TF.createStructure_items(originalsSubFolder, lang_marker)
    TF.createStructure_Folder(parent_path, parent_type, tr1_table)
    
    -- 更新时间选区范围以匹配items的新位置
    if #tr1_table > 0 then
        local min_pos = math.huge
        local max_end = 0
        for _, track in ipairs(tr1_table) do
            local item_count = reaper.CountTrackMediaItems(track)
            for i = 0, item_count - 1 do
                local item = reaper.GetTrackMediaItem(track, i)
                local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                min_pos = math.min(min_pos, pos)
                max_end = math.max(max_end, pos + len)
            end
        end
        if min_pos < math.huge then
            reaper.GetSet_LoopTimeRange2(0, true, false, min_pos, max_end, false)
        end
    end
    
    set_container(containerType, parent_path)
    reaper.ShowConsoleMsg("时间选区下items结构化完成！\n")

    TF.setColor_ItemAndTrack()
    
end

-- ==============================================
-- 主函数执行 Rea_CreateStructure_items
-- ==============================================

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)


AF.init() -- 初始化Wwise API

local originalsSubFolder, containerType, lang_marker = input_user() -- 输入用户参数
if originalsSubFolder == "" and containerType == "" then return end -- 如果用户取消输入，则不执行后续操作

Rea_CreateStructure_items(originalsSubFolder, containerType, lang_marker)


AF.disconnect()


reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Rea_CreateStructure_items", -1)
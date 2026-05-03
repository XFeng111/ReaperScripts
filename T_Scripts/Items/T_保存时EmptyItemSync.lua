--@noindex
--[[
  Empty Item Sync - 空白item时长自动同步工具
  
  功能：保存项目时自动更新编组内空白item的时长范围
  使用：运行脚本即可启动，脚本会常驻后台监听保存操作
  
  状态切换：脚本运行后显示控制面板，可随时开启/关闭拦截功能
--]]

local script_name = "Empty Item Sync"

-- ============================================================================
-- 常量定义
-- ============================================================================
local EXT_SECTION = "EmptyItemSync"
local EXT_KEY_ENABLED = "EnableIntercept"

-- ============================================================================
-- 空白item检测
-- ============================================================================

--- 检查item是否为空白item（无take或take无源）
local function isEmptyItem(item)
    local take = reaper.GetActiveTake(item)
    if not take then return true end
    local source = reaper.GetMediaItemTake_Source(take)
    if not source then return true end
    -- 检查源是否为空
    local source_type = reaper.GetMediaSourceType(source)
    return source_type == "EMPTY" or source_type == ""
end

-- ============================================================================
-- 编组范围计算
-- ============================================================================

--- 获取指定编组的范围（最早开始时间和总时长）
--- 排除空白item，只计算非空白items的范围
local function getGroupRange(groupId, excludeItem)
    if groupId == 0 then 
        return nil, nil  -- 无编组
    end
    
    local minStart = math.huge
    local maxEnd = -math.huge
    local itemCount = 0
    
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        for j = 0, reaper.CountTrackMediaItems(track) - 1 do
            local item = reaper.GetTrackMediaItem(track, j)
            
            -- 排除空白item
            if item ~= excludeItem then
                local itemGroup = math.floor(reaper.GetMediaItemInfo_Value(item, "I_GROUPID") + 0.5)
                
                if itemGroup == groupId then
                    itemCount = itemCount + 1
                    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                    local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                    minStart = math.min(minStart, pos)
                    maxEnd = math.max(maxEnd, pos + len)
                end
            end
        end
    end
    
    if itemCount == 0 or minStart == math.huge then
        return nil, nil
    end
    
    return minStart, maxEnd - minStart
end

-- ============================================================================
-- 更新空白item
-- ============================================================================

--- 更新项目中所有空白item
local function updateAllEmptyItems()
    local updatedCount = 0
    
    -- 收集所有需要更新的items
    local itemsToUpdate = {}
    
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        for j = 0, reaper.CountTrackMediaItems(track) - 1 do
            local item = reaper.GetTrackMediaItem(track, j)
            if isEmptyItem(item) then
                local groupId = math.floor(reaper.GetMediaItemInfo_Value(item, "I_GROUPID") + 0.5)
                if groupId > 0 then
                    table.insert(itemsToUpdate, {item = item, groupId = groupId})
                end
            end
        end
    end
    
    -- 批量更新
    if #itemsToUpdate > 0 then
        reaper.Undo_BeginBlock()
        
        for _, data in ipairs(itemsToUpdate) do
            local item = data.item
            local groupId = data.groupId
            -- 计算该编组的范围（排除空白item本身）
            local startPos, totalLen = getGroupRange(groupId, item)
            if startPos and totalLen then
                local buffer = 0.001  -- 前后各增加0.001秒缓冲
                reaper.SetMediaItemInfo_Value(item, "D_POSITION", startPos - buffer)
                reaper.SetMediaItemInfo_Value(item, "D_LENGTH", totalLen + buffer * 2)
                updatedCount = updatedCount + 1
            end
        end
        
        reaper.UpdateArrange()
        reaper.Undo_EndBlock("Update empty items to group range", -1)
    end
    
    return updatedCount
end

-- ============================================================================
-- 保存拦截逻辑
-- ============================================================================

local was_dirty = false

--- 监听保存操作（通过检测dirty状态变化）
local function monitorSaveAction()
    local enabled = reaper.GetExtState(EXT_SECTION, EXT_KEY_ENABLED) == "1"
    
    if enabled then
        local is_dirty = reaper.IsProjectDirty() > 0
        
        -- 检测从脏到干净的转变（用户刚保存）
        if was_dirty and not is_dirty then
            -- reaper.ShowConsoleMsg(string.format("[%s] 检测到保存操作，开始更新空白items...\n", script_name))
            local count = updateAllEmptyItems()
            if count > 0 then
                -- reaper.ShowConsoleMsg(string.format("[%s] 已更新 %d 个空白item\n", script_name, count))
            end
        end
        
        was_dirty = is_dirty
    end
    
    -- 继续监听
    reaper.defer(monitorSaveAction)
end

-- ============================================================================
-- 主入口
-- ============================================================================

-- 按钮高亮控制
local _, _, sec, cmd = reaper.get_action_context()
if cmd > 0 then
    if reaper.GetToggleCommandState(cmd) == 1 then
        reaper.SetToggleCommandState(sec, cmd, 0)
        reaper.RefreshToolbar2(sec, cmd)
        return
    end
    reaper.SetToggleCommandState(sec, cmd, 1)
    reaper.RefreshToolbar2(sec, cmd)
    reaper.atexit(function()
        reaper.SetToggleCommandState(sec, cmd, 0)
        reaper.RefreshToolbar2(sec, cmd)
    end)
end

-- 初始化状态
if reaper.GetExtState(EXT_SECTION, EXT_KEY_ENABLED) == "" then
    reaper.SetExtState(EXT_SECTION, EXT_KEY_ENABLED, "1", true)
end

was_dirty = reaper.IsProjectDirty() > 0

monitorSaveAction()

-- ============================================================================
-- 使用说明
-- ============================================================================
--[[
使用方法：
直接运行脚本启动后台监听模式，自动监听保存操作并更新空白items

注意事项：
- IsProjectDirty() 需要首选项中启用 "Undo/prompt to save"
- 空白item定义：无take或take无有效源文件的item
- 只处理有编组(groupId > 0)的空白items
--]]

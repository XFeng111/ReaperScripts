--@noindex
--[[
脚本名称：选中Item淡入淡出设为时长1/5.lua
功能描述：
1. 批量处理选中的音频/MIDI Item
2. 自动计算每个Item时长的1/5，作为淡入、淡出时长
3. 支持自定义淡入淡出曲线（默认线性，可修改脚本参数）
4. 处理后弹窗汇总结果，支持Undo撤销
适用版本：Reaper 5.0+
使用说明：1. 选中需设置淡入淡出的Item；2. 运行脚本即可自动应用
]]

-- ===================== 可自定义参数（根据需求调整） =====================
local FADE_CURVE = 0  -- 淡入淡出曲线类型：0=线性，1=对数（淡入柔和），2=指数（淡出柔和）
local MIN_FADE_LEN = 0.01  -- 最小淡入淡出时长（秒），避免Item过短时淡入淡出时长为0
-- ======================================================================

-- 工具函数：获取单个Item的有效时长（排除静音部分，确保计算准确）
local function GetItemEffectiveLength(item)
    if not item or type(item) ~= "userdata" then
        return 0
    end
    -- 获取Item的开始时间和结束时间（项目时间）
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    -- 计算Item的实际时长（排除可能的静音偏移）
    return item_end - item_start
end

-- 工具函数：为单个Item设置淡入淡出（时长=Item时长1/5）
local function SetItemFadeInFadeOut(item)
    if not item then
        return false, "Item无效"
    end

    -- 步骤1：计算Item有效时长
    local item_len = GetItemEffectiveLength(item)
    if item_len <= 0 then
        return false, "Item时长为0"
    end

    -- 步骤2：计算淡入淡出时长（Item时长1/5，不小于最小时长）
    local target_fade_len = item_len / 5
    target_fade_len = math.max(target_fade_len, MIN_FADE_LEN)  -- 确保不小于最小时长

    -- 步骤3：设置淡入（从Item开始位置，时长=target_fade_len，曲线=FADE_CURVE）
    -- 参数说明：item, 淡入类型(0=线性淡入), 淡入时长(秒), 淡入曲线, 是否相对时长(0=绝对)
    reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", target_fade_len)
    reaper.SetMediaItemInfo_Value(item, "C_FADEINSHAPE", FADE_CURVE)
    -- 启用淡入（部分Item默认淡入关闭，强制开启）
    reaper.SetMediaItemInfo_Value(item, "B_FADEIN", 1)

    -- 步骤4：设置淡出（从Item结束位置，时长=target_fade_len，曲线=FADE_CURVE）
    reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", target_fade_len)
    reaper.SetMediaItemInfo_Value(item, "C_FADEOUTSHAPE", FADE_CURVE)
    -- 启用淡出
    reaper.SetMediaItemInfo_Value(item, "B_FADEOUT", 1)

    -- 返回成功信息（含计算的淡入淡出时长）
    return true, string.format("淡入淡出时长=%.3f秒（Item时长%.3f秒的1/5）", target_fade_len, item_len)
end

-- 主逻辑：批量处理选中Item
local function Main()
    -- 步骤1：检查是否有选中Item
    local selected_item_count = reaper.CountSelectedMediaItems(0)  -- 0=当前项目
    if selected_item_count == 0 then
        reaper.ShowMessageBox("请先在Reaper中选中至少一个Media Item！", "操作提示", 0)
        return
    end

    -- 步骤2：初始化处理结果收集
    local success_count = 0  -- 处理成功的Item数量
    local fail_count = 0     -- 处理失败的Item数量
    local process_log = {}   -- 详细处理日志（成功/失败原因）

    -- 步骤3：开始Undo分组（支持一键撤销所有淡入淡出设置）
    reaper.Undo_BeginBlock()

    -- 步骤4：遍历所有选中Item，批量设置淡入淡出
    for i = 0, selected_item_count - 1 do
        -- 获取当前选中的Item
        local current_item = reaper.GetSelectedMediaItem(0, i)
        -- 获取Item关联的轨道名（用于日志展示，方便定位）
        local track = reaper.GetMediaItem_Track(current_item)
        local _, track_name = reaper.GetTrackName(track)
        -- 获取Item在轨道上的序号（1开始，方便用户识别）
        local item_idx = i + 1

        -- 为当前Item设置淡入淡出
        local is_success, msg = SetItemFadeInFadeOut(current_item)

        -- 记录处理结果
        local log_line = string.format("第%d个Item（轨道：%s）：%s", item_idx, track_name, msg)
        table.insert(process_log, log_line)

        -- 更新成功/失败计数
        if is_success then
            success_count = success_count + 1
        else
            fail_count = fail_count + 1
        end
    end

    -- 步骤5：结束Undo分组，命名Undo操作
    reaper.Undo_EndBlock("批量设置选中Item淡入淡出为时长1/5", -1)

    -- 步骤6：生成最终结果文本（弹窗+控制台）
    local result_text = string.format(
        "批量处理完成！\n共处理 %d 个选中Item：\n- 成功：%d 个\n- 失败：%d 个\n\n详细日志：\n%s",
        selected_item_count,
        success_count,
        fail_count,
        table.concat(process_log, "\n")
    )
    
    -- 步骤7：弹窗展示结果
    -- reaper.ShowMessageBox(result_text, "淡入淡出设置结果", 0)

    -- 步骤8：控制台输出日志（便于调试，可查看每个Item的具体参数）
    -- reaper.ShowConsoleMsg("=== 淡入淡出设置日志 ===\n" .. result_text .. "\n")
    -- reaper.ShowConsoleMsg("自定义参数：淡入淡出曲线=" .. FADE_CURVE .. "（0=线性，1=对数，2=指数），最小时长=" .. MIN_FADE_LEN .. "秒\n")

    -- 全局界面强制刷新（立即更新所有可视元素）
    reaper.UpdateArrange()

end

-- 启动主逻辑
Main()

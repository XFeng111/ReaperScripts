--@noindex
-- 设置所有选中项目声像包络所有点值偏移指定值
-- 确保至少选中一个包含声像包络的项目

-- 检查是否有选中项目
local item_count = reaper.CountSelectedMediaItems(0)
if item_count == 0 then
    reaper.ShowMessageBox("请先选中至少一个媒体项目", "错误", 0)
    return
end

-- 获取用户输入的偏移值
local retval, user_input = reaper.GetUserInputs(
    "声像包络设置",  -- 弹窗标题
    1,               -- 1个输入框
    "声像偏移量范围:-1(R)到1(L)",  -- 输入框提示文本
    "0.5"         -- 输入框默认值
)

-- 检查用户是否点击了确认按钮
if not retval then
    return  -- 用户取消操作
end

-- 将输入的字符串转换为数字
local move_value = tonumber(user_input)
if not move_value then
    reaper.ShowMessageBox("请输入有效的数字", "错误", 0)
    return
end

-- 开始撤销块
reaper.Undo_BeginBlock()

local total_points = 0  -- 统计总共处理的包络点数量

-- 遍历所有选中的项目
for i = 0, item_count - 1 do
    -- 获取第i个选中的项目
    local item = reaper.GetSelectedMediaItem(0, i)
    if item then
        -- 获取激活的片段
        local take = reaper.GetActiveTake(item)
        if take then
            -- 获取声像包络("Pan"通常为声像包络)
            local pan_env = reaper.GetTakeEnvelopeByName(take, "Pan")
            if not pan_env then
                -- 执行指令 ID 40694：切换选中素材的声像包络状态
                reaper.Main_OnCommand(40694, 0)
                -- 再次尝试获取声像包络
                pan_env = reaper.GetTakeEnvelopeByName(take, "Pan")
            end
            
            if pan_env then
                -- 获取包络点数量
                local pointCount = reaper.CountEnvelopePoints(pan_env)
                total_points = total_points + pointCount
                
                -- 遍历所有包络点并偏移值
                for p = 0, pointCount - 1 do
                    -- 获取当前点信息
                    local _, timePos, value = reaper.GetEnvelopePoint(pan_env, p)
                    
                    -- 计算新值(偏移指定值)
                    local newValue = value + move_value
                    
                    -- 限制值在有效范围内(-1到1)
                    newValue = math.max(-1, math.min(1, newValue))
                    
                    -- 设置声像新值
                    reaper.SetEnvelopePoint(pan_env, p, timePos, newValue, nil, nil, nil, true)
                end
            end
        end
    end
end

-- 更新视图
reaper.UpdateArrange()

-- 结束撤销块
reaper.Undo_EndBlock("声像包络所有点偏移指定值", -1)

-- 显示完成信息
-- reaper.ShowMessageBox("已处理 " .. item_count .. " 个项目，共偏移 " .. total_points .. " 个声像包络点，偏移值为 " .. move_value, "完成", 0)

--@noindex

---@class MediaTrack : userdata

Tool_Func = {}

-- ==============================================
-- Lua 工具集合
-- ==============================================

---@param file_path string
---@param marker string
---@return string originalsSubFolder, string marker
function Tool_Func.get_originalsSubFolder(file_path, marker)
    local originalsSubFolder = ""
    local target_marker = marker
    -- 待匹配的标记列表
    local markers =  {marker, "SFX", "CN", "EN", "English(US)", "Chinese(Simplified)"}

    for _, m in ipairs(markers) do
        -- 转义特殊字符（适配模式匹配）
        local m_escaped = m:gsub("([%(%)%[%]%+%-%*%?%^%$])", "%%%1")
        if file_path:find("[\\/]" .. m_escaped .. "[\\/]") then
            if file_path:find("%.[^.]+$") then
                -- 如果路径有文件类型后缀，提取 marker 后面到 文件名称前\\ 之间的内容
                originalsSubFolder = file_path:match(m_escaped .. "[\\/](.*)[\\/]") or ""
            elseif file_path:find("[\\/]$") then
                -- 如果路径\\结尾，提取 marker 后面到 文件名称前\\ 之间的内容
                originalsSubFolder = file_path:match(m_escaped .. "[\\/](.*)[\\/]") or ""
            else
                -- 提取 marker 后面的所有内容
                originalsSubFolder = file_path:match(m_escaped .. "[\\/](.*)") or ""
            end
                
            -- 更新返回的标记（使用原始未转义的标记）
            target_marker = m
            -- 找到匹配项后退出循环
            break
        else
            reaper.ShowConsoleMsg("未找到标记：" .. m .. "\n")
        end
    end
    
    reaper.ShowConsoleMsg("返回标记：" .. target_marker .. "\n" .. "返回originals子文件夹：" .. originalsSubFolder .. "\n")
    return originalsSubFolder, target_marker
end

-- 将table表按n个元素分组，返回嵌套分组表
---@param input_table table - 要分组的表
---@param group_size number - 每组元素个数
function Tool_Func.splitTable(input_table, group_size)
    -- 1. 参数校验：确保输入是有效表
    if type(input_table) ~= "table" then
        reaper.ShowConsoleMsg("错误：输入不是有效表！\n")
        return {}
    end

    local group_size = group_size or 50 -- 默认50个/组
    local grouped_table = {} -- 最终返回的嵌套表
    local current_group = {} -- 临时存储当前组的元素
    local table_len = #input_table

    -- 2. 空表直接返回空嵌套表
    if table_len == 0 then
        return grouped_table
    end

    -- 3. 遍历原始表，按group_size个元素分组
    for i = 1, table_len do
        table.insert(current_group, input_table[i])

        -- 当当前组满group_size个，存入嵌套表并重置
        if #current_group == group_size then
            table.insert(grouped_table, current_group)
            current_group = {} -- 清空当前组，准备下一组
        end
    end

    -- 4. 处理最后不足group_size个的剩余元素
    if #current_group > 0 then
        table.insert(grouped_table, current_group)
    end

    return grouped_table
end

-- 功能：按父路径分组，并将 ids、names 按 50 个一组拆分
-- 参数：
--   ids         : table - id 数组
--   names       : table - 名称数组（与 ids、objectPaths 一一对应）
--   objectPaths : table - 路径数组
-- 返回：分组 + 分块后的表（key=父路径，value={ids=二维表, names=二维表}）
---@param types table - type 数组
---@param ids table - id 数组
---@param names table - 名称数组（与 ids、objectPaths 一一对应）
---@param objectPaths table - 路径数组
---@param crTypes table - 父级容器 数组（用于处理随机容器等的event创建情况）
---@param isCr boolean - 是否为容器(若true，存在容器类型则以容器单位创建，否则全以Sound单位创建)
---@return table result_group - 分组 + 分块后的表（key=父路径，value={ids=二维表, names=二维表}）
function Tool_Func.groupByParentPath(types, ids, names, objectPaths, crTypes, isCr)
    local result_group = {}
    local j = 1
    local k = 1  -- crTypes索引

    -- 定义需要特殊处理的容器类型
    local special_cr_types = {
        ["[ran]"] = true,
        ["[swi]"] = true,
        ["[ble]"] = true,
        ["[seq]"] = true
    }

    -- 遍历每一组对应数据
    for i = 1, #ids do
        local id = ids[i]
        local name = names[i]
        local objType = types[i]
        local path = ""
        local crType = ""
        
        -- 只有 type == "Sound" 才继续
        if objType ~= "Sound" then
            goto continue

        else
            path = objectPaths[j]
            crType = crTypes and crTypes[k] or ""
            j = j + 1
            k = k + 1
        end

        if not path or type(path) ~= "string" then
            -- 打印失败信息
            reaper.ShowConsoleMsg("[匹配失败] 路径无效 | name: " .. tostring(name) .. " | path: " .. tostring(path) .. "\n")
            goto continue
        end

        local parentPath = ""

        -- 判断是否使用容器分组逻辑
        if isCr and crType and special_cr_types[crType] then
            -- 容器模式：先去除路径中的 <...> 标签，再上取两级
            local clean_path = path:gsub("<[^>]+>", "")  -- 去除所有 <...> 标签
            local temp_path = clean_path:match("(.*)[\\/]")  -- 第一次上取
            if temp_path then
                parentPath = temp_path:match("(.*)[\\/]")  -- 第二次上取作为parentPath
                id = temp_path  -- 第一次上取的结果作为id
                name = temp_path:match("[\\/]([^\\/]+)$") or temp_path  -- 取id的最后一层作为name
            end
            
            if not parentPath or not id then
                reaper.ShowConsoleMsg("[匹配失败] 容器模式无法提取路径 | name: " .. tostring(name) .. " | path: " .. tostring(path) .. "\n")
                goto continue
            end
        else
            -- 普通模式：上取一级作为parentPath，使用原始id和name
            parentPath = path:match("(.*)[\\/]")
            if not parentPath then
                reaper.ShowConsoleMsg("[匹配失败] 无分隔符 | name: " .. tostring(name) .. " | path: " .. tostring(path) .. " | 匹配结果: nil\n")
                goto continue
            end
        end

        -- 检查 parentPath 是否有效
        if parentPath == "" then
            reaper.ShowConsoleMsg("[匹配失败] parentPath 为空 | name: " .. tostring(name) .. " | path: " .. tostring(path) .. "\n")
            goto continue
        end

        -- 初始化分组结构
        if not result_group[parentPath] then
            result_group[parentPath] = {
                ids = {},   -- 一维临时存储：[id1, id2, ...]
                names = {}  -- 一维临时存储：[name1, name2, ...]
            }
        end

        -- 先把元素塞进一维数组（同 parentPath 内去重：按 id 去重）
        if not result_group[parentPath]._id_set then
            result_group[parentPath]._id_set = {}
        end

        if not result_group[parentPath]._id_set[id] then
            result_group[parentPath]._id_set[id] = true
            table.insert(result_group[parentPath].ids, id)
            table.insert(result_group[parentPath].names, name)
        end

        ::continue::
    end

    -- 【关键】遍历所有分组，用 TF.splitTable 按 50 个一组拆分
    for parentPath, info in pairs(result_group) do
        info.ids = Tool_Func.splitTable(info.ids, 50)    -- 变成二维数组
        info.names = Tool_Func.splitTable(info.names, 50) -- 变成二维数组
        info._id_set = nil
    end

    return result_group
end

-- 整合两个一一对应的表为字典（相同parentType的id合并为列表）
---@param key_table table - 父类型表（如{"A","A","B","C","B"}）
---@param value_table table - ID表（元素与key_table一一对应，如{1,2,3,4,5}）
---@param is_deduplicate boolean - 可选，是否对ID去重（默认true：去重，false：不去重）
---@return table result_dict - 整合后的字典（如{A={1,2}, B={3,5}, C={4}}）
function Tool_Func.mergeToParentIdDict(key_table, value_table, is_deduplicate)
    -- 初始化返回字典
    local result_dict = {}
    -- 默认开启去重
    is_deduplicate = is_deduplicate ~= nil and is_deduplicate or true

    -- 步骤1：参数有效性校验
    if type(key_table) ~= "table" or type(value_table) ~= "table" then
        reaper.ShowConsoleMsg("错误：输入不是有效表！\n")
        return result_dict
    end
    local type_len = #key_table
    local id_len = #value_table
    if type_len ~= id_len then
        reaper.ShowConsoleMsg("警告：两个表长度不一致，仅处理到较短表的长度！\n")
        type_len = math.min(type_len, id_len)
    end

    -- 步骤2：遍历表，整合相同parentType的ID（支持去重）
    for i = 1, type_len do
        local parent_type = key_table[i]
        local id = value_table[i]

        -- 跳过空值
        if parent_type == nil or id == nil then
            goto continue
        end

        -- 初始化当前parent_type的ID列表
        if not result_dict[parent_type] then
            result_dict[parent_type] = {}
        end

        -- 步骤3：根据开关判断是否去重后添加ID
        if is_deduplicate then
            -- 去重逻辑：检查ID是否已存在，不存在才添加
            local is_exist = false
            for _, existing_id in ipairs(result_dict[parent_type]) do
                if existing_id == id then
                    is_exist = true
                    break
                end
            end
            if not is_exist then
                table.insert(result_dict[parent_type], id)
            end
        else
            -- 不去重逻辑：直接添加ID
            table.insert(result_dict[parent_type], id)
        end

        ::continue::
    end

    return result_dict
end

---@param result_table table 要遍历的结果表
function Tool_Func.debugMsg_table(result_table)
    for i, v in ipairs(result_table) do
        reaper.ShowConsoleMsg("Debug信息：" .. tostring(v) .. "\n")
    end
end

---@param srcPath string 源文件路径
---@param destPath string 目标文件路径
---@return boolean boolean , string msg 成功返回true，失败返回false和错误信息
-- 二进制拷贝
function Tool_Func.copyFile(srcPath, destPath)
    -- 参数检查
    if type(srcPath) ~= "string" or type(destPath) ~= "string" then
        return false, "路径必须是字符串"
    end

    -- 打开源文件（只读二进制模式）
    local srcFile, err = io.open(srcPath, "rb")
    if not srcFile then
        return false, "无法打开源文件: " .. tostring(err)
    end
    -- 读取全部内容
    local data = srcFile:read("*a")
    srcFile:close()
    if not data then
        return false, "读取源文件失败"
    end
    
    -- 打开目标文件（写入二进制模式）
    local destFile, err = io.open(destPath, "wb")
    if not destFile then
        return false, "无法创建目标文件: " .. tostring(err)
    end
    -- 写入数据
    local ok, writeErr = destFile:write(data)
    destFile:close()
    if not ok then
        return false, "写入目标文件失败: " .. tostring(writeErr)
    end
    return true, "文件拷贝成功"
end

---@param ... table 要遍历的多个数组式table
---@return function 迭代器，每次返回各table对应位置的值
function Tool_Func.zip(...)
    local tables = {...}
    local idx = 1
    -- 取所有table的最小长度
    local max_len = math.huge
    for _, t in ipairs(tables) do
        max_len = math.min(max_len, #t)
    end

    -- 返回迭代器函数
    return function()
        if idx > max_len then
            return nil  -- 遍历结束
        end
        -- 收集当前索引下所有table的值
        local values = {}
        for _, t in ipairs(tables) do
            table.insert(values, t[idx])
        end
        idx = idx + 1
        return table.unpack(values)  -- 解包返回（比如key, value）
    end
end

---@param Txt string 分隔符前的固定文本，如 "SFX"
---@param path string 待处理的路径字符串
---@return string result 提取的路径（无则返回空字符串）
function Tool_Func.extract_path_after_txt(path, Txt) --- 提取Txt\之后、最后一个分隔符之前的路径部分
    -- 第一步：匹配Txt\之后的所有内容
    local after_Txt = path:match(Txt .. "[\\/](.*)")
    if not after_Txt then
        return "" -- 没有Txt\开头，直接返回空
    end
    
    -- 第二步：匹配after_Txt中最后一个\或/之前的内容（无则返回空）
    -- 模式说明：^(.+)[\\/].+$ → 匹配开头到最后一个分隔符的内容
    local result = after_Txt:match("^(.+)[\\/].+$") or ""
    return result
end


-- ==============================================
-- ReaperApi 工具集合
-- ==============================================

---@param pr_track MediaTrack
function Tool_Func.getParentTrackNameToIdx_Map(pr_track) -- 获取父轨道名称到索引的映射
    local map = {}
    local totalTracks = reaper.CountTracks(0)

    for i = 0, totalTracks - 1 do
        local track = reaper.GetTrack(0, i)
        local parent_tr = reaper.GetParentTrack(track)

        if parent_tr and parent_tr ~= pr_track then
            local _, name = reaper.GetTrackName(parent_tr)
            local parentNumber = reaper.GetMediaTrackInfo_Value(parent_tr, "IP_TRACKNUMBER") - 1 -- 转0基

            -- 只存第一次出现的父轨道（避免重复）
            if not map[name] then
                map[name] = parentNumber
            end
        end
    end

    return map
end

---@param input_table table 输入的原始表（需包含字符串元素）
---@param typeNote_table table 输出的首字母表
---@param skip_invalid boolean 可选，是否跳过无效元素（空字符串/非字符串），默认true
---@return table typeNote_table
function Tool_Func.getTypeNote_table(input_table, typeNote_table, skip_invalid)
    -- 参数默认值处理
    skip_invalid = skip_invalid ~= nil and skip_invalid or true
    
    -- 校验输入是否为有效表
    if type(input_table) ~= "table" then
        reaper.ShowConsoleMsg("错误：输入不是有效表！\n")
        return typeNote_table -- 返回空表
    end
    
    -- 遍历输入表处理每个元素
    for _, str in ipairs(input_table) do
        -- 仅处理有效非空字符串
        if type(str) == "string" and str ~= "" then
            -- 提取首字母并转小写
            local multi_char = str:sub(1, 3):lower()
            table.insert(typeNote_table, multi_char)
        else
            -- 不跳过无效元素时，存入空字符串
            if not skip_invalid then
                table.insert(typeNote_table, "")
            end
            -- 跳过则无操作，直接进入下一次循环
        end
    end
    
    return typeNote_table
end


---@return table filename_table
---@return table item_table
function Tool_Func.getitems_table_inTimeLine() -- 获取时间选区内的Item和名称（不含后缀）
    local filename_table = {}
    local item_table = {}

    local start_time, end_time = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if start_time == end_time then
        reaper.ShowConsoleMsg("错误：未设置时间选区！")
        return filename_table, item_table -- 无时间选区则终止执行
    end

    local function removeFileExtension(filename)
        if type(filename) ~= "string" or filename == "" then
            return ""
        end
        -- 匹配最后一个"."后的所有字符（即文件后缀）并替换为空
        -- 兼容带多个"."的文件名（如 "demo.v1.wav" 会保留 "demo.v1"）
        local pure_name = filename:gsub("%.[^%.]+$", "")
        return pure_name
    end

    local item_count = reaper.CountMediaItems(0) -- 获取工程中所有Item数量
    if item_count == 0 then
        reaper.ShowConsoleMsg("错误：工程中无任何媒体项！")
        return filename_table, item_table
    end

    for i = 0, item_count - 1 do
        local item = reaper.GetMediaItem(0, i)
        -- 获取Item的时间范围
        local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

        -- 判断Item是否在时间选区内（部分重叠也计入）
        if not (item_end < start_time or item_start > end_time) then
            -- 获取Item的名称（优先取Active Take的名称）
            local item_name = ""
            local take = reaper.GetActiveTake(item)
            if take then
                item_name = reaper.GetTakeName(take)
            else
                item_name = "无音频的媒体项" -- 无Take的空白Item命名
            end

            -- 移除文件后缀并存入表
            local pure_item_name = removeFileExtension(item_name)
            table.insert(filename_table, pure_item_name)
            table.insert(item_table, item)
        end
    end
    return filename_table, item_table
    --[[ 
    ------------------------------------------
    -- Debug
    ------------------------------------------
    reaper.ClearConsole() -- 清空控制台历史信息
    if #filename_table == 0 then
        reaper.ShowConsoleMsg("时间选区内无有效Item名称可提取！\n")
    else
        reaper.ShowConsoleMsg("=== 时间选区内的Item名称（已去后缀）===\n")
        for idx, name in ipairs(filename_table) do
            reaper.ShowConsoleMsg(string.format("[%d] %s\n", idx, name))
        end
        reaper.ShowConsoleMsg("\n总计提取：" .. #filename_table .. " 个Item名称\n")
    end
    ]]
    
end

---@param item_table table
---@param interval_seconds number
---@return boolean
function Tool_Func.items_interval(item_table, interval_seconds)
    -- 校验参数默认值
    interval_seconds = interval_seconds or 20
    if type(interval_seconds) ~= "number" or interval_seconds < 0 then
        reaper.ShowConsoleMsg("间隔时间必须为非负数！")
        return false
    end

    -- 校验item_table有效性
    if type(item_table) ~= "table" or #item_table == 0 then
        reaper.ShowConsoleMsg("item_table为空或不是有效表！")
        return false
    end

    -- 禁止UI刷新，提升批量操作效率
    reaper.PreventUIRefresh(1)
    -- 开始撤销块（支持一键撤销）
    reaper.Undo_BeginBlock()

    -- 初始化起始位置（以第一个Item的原位置为基准，也可自定义为0）
    local current_pos = reaper.GetMediaItemInfo_Value(item_table[1], "D_POSITION")

    -- 遍历item_table，逐个设置Item位置
    for i, item in ipairs(item_table) do
        -- 校验当前Item是否有效
        if not reaper.ValidatePtr(item, "MediaItem*") then
            reaper.ShowConsoleMsg("第" .. i .. "个Item无效，跳过！\n")
            goto continue -- 跳过无效Item，继续遍历
        end

        -- 获取Item自身时长（用于计算下一个Item的起始位置）
        local item_duration = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

        -- 设置当前Item的时间轴位置（核心API）
        reaper.SetMediaItemInfo_Value(item, "D_POSITION", current_pos)

        -- 计算下一个Item的起始位置：当前位置 + Item时长 + 间隔时间
        current_pos = current_pos + item_duration + interval_seconds

        ::continue:: --遇到无效的 MediaItem 时，跳过该 Item 的后续处理，直接进入下一个 Item 的遍历，避免无效 Item 导致脚本报错或中断
    end

    -- 结束撤销块
    reaper.Undo_EndBlock("将Item间隔10秒排列", -1)
    -- 恢复UI刷新并刷新编曲界面
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()

    -- reaper.ShowConsoleMsg("操作完成！共排列" .. #item_table .. "个Item，间隔" .. interval_seconds .. "秒\n")
    return true
end


---@param tr_table table 包含MediaTrack对象的表
---@param Is_ClearOthers boolean (可选) - 是否先取消其他轨道的选中（默认true）
function Tool_Func.selectTracksInTable(tr_table, Is_ClearOthers)
    -- 校验参数默认值
    Is_ClearOthers = Is_ClearOthers ~= nil and Is_ClearOthers or true
    
    -- 1. 基础校验：tr_table是否为有效表且非空
    if type(tr_table) ~= "table" or #tr_table == 0 then
        reaper.ShowConsoleMsg("tr_table为空或不是有效表！")
        return false
    end

    -- 2. 可选：先取消所有轨道的选中（避免残留选中）
    if Is_ClearOthers then
        reaper.Main_OnCommand(40297, 0) -- 40297 = 取消所有轨道选中
    end

    -- 3. 禁止UI刷新（提升批量操作效率）
    reaper.PreventUIRefresh(1)

    -- 4. 遍历tr_table，逐个设置轨道选中状态
    local valid_count = 0 -- 统计有效轨道数量
    for i, track in ipairs(tr_table) do
        -- 校验当前MediaTrack是否有效
        if reaper.ValidatePtr(track, "MediaTrack*") then
            -- 核心API：设置轨道选中状态（true=选中，false=取消）
            reaper.SetTrackSelected(track, true)
            valid_count = valid_count + 1
        else
            -- 无效轨道打印提示（不中断流程）
            reaper.ShowConsoleMsg("第" .. i .. "个轨道无效，跳过！\n")
        end
    end

    -- 5. 恢复UI刷新并刷新界面
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()

    -- 6. 结果提示
    if valid_count == 0 then
        reaper.ShowConsoleMsg("未找到有效轨道！")
        return false
    else
        reaper.ShowConsoleMsg("成功选中" .. valid_count .. "个轨道（共遍历" .. #tr_table .. "个）\n")
        return true
    end
end


---@param item MediaItem
---@param objectName string
---@param originalsSubFolder string
---@param lang_marker string 导入语言标记
---@return MediaTrack trChild_1
---@return MediaTrack trChild_2
function Tool_Func.createTrackFolder_Mult(item, objectName, originalsSubFolder, lang_marker)
    local trChild_1_TrackName = "[sou]" .. objectName

    reaper.InsertTrackAtIndex(reaper.GetNumTracks(), true) -- 末尾插入新Track
    local new_track = reaper.GetTrack(0, reaper.GetNumTracks() - 1) -- 获取新Track
    reaper.MoveMediaItemToTrack(item, new_track) -- 将Item移动到新Track

    local trChild_2 = reaper.GetMediaItemTrack(item) -- 获取Item所在的Track
    reaper.SetOnlyTrackSelected(trChild_2) -- 选中Item所在的Track
    reaper.Main_OnCommand(42785, 0) -- 轨道: 将轨道移动到新文件夹 ⇌ Track: Move tracks to new folder
    
    local trChild_1 = reaper.GetParentTrack(trChild_2) -- 获取Item所在Track的小父级Track,trChild_1
    reaper.GetSetMediaTrackInfo_String(trChild_1, "P_NAME", trChild_1_TrackName, true)

    if lang_marker == "SFX" then
        reaper.GetSetMediaTrackInfo_String(trChild_2, "P_NAME", "[o]\\Originals\\" .. lang_marker .. "\\" .. originalsSubFolder, true)
    else
        reaper.GetSetMediaTrackInfo_String(trChild_2, "P_NAME", "[o]\\Originals\\Voices\\" .. lang_marker .. "\\" .. originalsSubFolder, true)
    end

    
    -- 统一颜色
    reaper.SetTrackSelected(trChild_1, true)
    reaper.SetTrackSelected(trChild_2, true)

    reaper.Main_OnCommand(40360, 0) -- 选中轨道设置随机颜色
    reaper.Main_OnCommand(40297, 0) -- 取消选中所有轨道

    return trChild_1, trChild_2
end

---@param originalsSubFolder string
---@param lang_marker string 导入语言标记
---@return table tr1_table 轨道结构tr1，MediaTrack对象的表
function Tool_Func.createStructure_items(originalsSubFolder, lang_marker)
    
    local filename_table, item_table = Tool_Func.getitems_table_inTimeLine()
    local tr1_table = {}
    
    Tool_Func.items_interval(item_table, 20)
    for filename, item in Tool_Func.zip(filename_table, item_table) do
        local trChild_1, trChild_2 = Tool_Func.createTrackFolder_Mult(item, filename, originalsSubFolder, lang_marker)
        table.insert(tr1_table, trChild_1)
        -- table.insert(tr_table, trChild_2)
        -- 添加 trChild_2 的父轨道空白item并编组，打Pack
        Tool_Func.createParentBlankItemAndGroup(0, trChild_2, filename)
        
    end
    
    return tr1_table
end

---@param objectPath string
---@param object_type string
function Tool_Func.createStructure_Folder(objectPath, object_type, tr1_table)
    
    -- （可选）最上层父级下，新建子轨道颜色区分
    -- Tool_Func.setColor_ItemAndTrack()          -- 重新统一颜色
    
    Tool_Func.selectTracksInTable(tr1_table, true) -- 选中tr_table中的轨道
    
    -- 创建父轨道
    reaper.Main_OnCommand(42785, 0) -- 轨道: 将轨道移动到新文件夹 ⇌ Track: Move tracks to new folder
    Tool_Func.setColor_ItemAndTrack()          -- 重新统一颜色
    
    reaper.Main_OnCommand(40297, 0) -- 取消选中所有轨道
    Tool_Func.playAndStop()                        -- 防止自动播放
    
    -- 最上层父轨道命名
    -- 父轨道名：[act]'path': '[act]Actor-Mixer\Footstep\Run\'
    local type_note = ""
    local folder_TrackName = ""
    if object_type == "" then
        type_note = "type_note"
    else
        type_note = Tool_Func.getTypeNote_table({ object_type }, {}, true)[1] or ""
    end
    
    if object_type == "Sound" then
        -- 父轨道名：[sou]'path': '[sou]Actor-Mixer\Footstep\Run\'
        folder_TrackName = "[" .. type_note .. "]" .. objectPath:sub(1, objectPath:find("\\[^\\]*$"))
    else
        folder_TrackName = "[" .. type_note .. "]" .. objectPath .. "\\"
    end
    
    local trParent = reaper.GetParentTrack(tr1_table[1]) -- 获取tr_table[1]的父轨道
    reaper.GetSetMediaTrackInfo_String(trParent, "P_NAME", folder_TrackName, true)
    
    
end


---@param itemidx integer
---@param trChild MediaTrack
---@param noteName string
---@return nil
-- 父轨道创建空白Item + 编组
function Tool_Func.createParentBlankItemAndGroup(itemidx, trChild, noteName)
    local item = reaper.GetTrackMediaItem(trChild, itemidx)
    if not item then return end

    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

    local trParent = reaper.GetParentTrack(trChild)
    if not trParent then return end

    -- 空白Item
    reaper.AddMediaItemToTrack(trParent)
    local blankItem = reaper.GetTrackMediaItem(trParent, 0)
    reaper.SetMediaItemInfo_Value(blankItem, "D_POSITION", pos)
    reaper.SetMediaItemInfo_Value(blankItem, "D_LENGTH", len)
    reaper.GetSetMediaItemInfo_String(blankItem, "P_NOTES", noteName, true)

    -- 选中对象编组
    reaper.SetMediaItemSelected(blankItem, true)
    reaper.SetMediaItemSelected(item, true)
    reaper.Main_OnCommand(40032, 0) -- 选中对象编组
    reaper.Main_OnCommandEx(reaper.NamedCommandLookup("_SWS_ITEMTRKCOL"), 0) -- 对象设置为对应轨道颜色
    reaper.Main_OnCommand(40289, 0) -- 取消选中所有对象

end

---@param filePath string
---@param cursorPosAdd number
---@param dosel boolean
---@return nil
-- 导入音频到轨道
function Tool_Func.addAudioToTrack(filePath, cursorPosAdd, dosel)
    dosel = dosel or false
    reaper.InsertMedia(filePath, 0) -- 导入音频到轨道的编辑光标位置，输入音频文件路径，0=添加到当前轨道
    reaper.MoveEditCursor(cursorPosAdd, dosel) -- 将编辑光标移动指定时间（秒），false=仅移动, true=移动+创建时间选区
end

function Tool_Func.setColor_ItemAndTrack()
    -- 统一轨道和对象颜色
    reaper.Main_OnCommand(40296, 0) -- 轨道: 选择所有轨道 ⇌ Track: Select all tracks
    reaper.Main_OnCommand(40421, 0) -- 对象: 选择轨道中的所有对象 ⇌ Item: Select all items in track
    
    reaper.Main_OnCommand(40358, 0) -- 轨道: 设置为随机颜色 ⇌ Track: Set to random colors
    reaper.Main_OnCommandEx(reaper.NamedCommandLookup("_SWS_COLCHILDREN"), 0) -- SWS: 将选定轨道的子轨道设置为相同颜色 ⇌ SWS: Set selected track(s) children to same color
    reaper.Main_OnCommandEx(reaper.NamedCommandLookup("_SWS_ITEMTRKCOL"), 0) -- 对象设置为对应轨道颜色

    reaper.Main_OnCommand(40769, 0)                                           -- 取消选中所有轨道/对象
    
    reaper.UpdateArrange() -- 刷新界面

end

function Tool_Func.playAndStop()
    -- 防止自动播放
    reaper.Main_OnCommand(40328, 0) -- 走带播放停止
    reaper.Main_OnCommand(40328, 0) -- 走带播放停止
    reaper.UpdateArrange() -- 刷新界面
end

---@return table Track_info_params -- key=编组ID，value={父级文件夹轨道名, 往下第一个子一级轨道名， 往下第一个子二级轨道名， 空白item的notes}
function Tool_Func.renderGroupItem()
    -- 时间选区是否存在
    local start_time, end_time = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if start_time == end_time then
        reaper.ShowConsoleMsg("需设置时间选区！")
        return Track_info_params
    end
    
    -- 获取所有Item
    local items_in_range = {}
    local item_count = reaper.CountMediaItems(0)
    if item_count == 0 then
        reaper.ShowConsoleMsg("时间选区内无任何Item！")
        return Track_info_params
    end
    
    -- 遍历所有Item，筛选出时间选区内的Item
    for i = 0, item_count - 1 do
        local item = reaper.GetMediaItem(0, i)
        local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        
        -- 判断Item是否在时间选区内（部分重叠也计入）
        if not (item_end < start_time or item_start > end_time) then
            table.insert(items_in_range, item)
        end
    end
    
    if #items_in_range == 0 then
        reaper.ShowConsoleMsg("时间选区内无任何Item！")
        return Track_info_params
    end
    
    -- 校验并提取Item编组信息
    local group_ids = {}  -- 存储唯一的编组ID
    local item_group_map = {} -- 按编组ID分类存储Item：group_id => {item1, item2, ...}
    
    -- 提取所有Item的编组ID
    for _, item in ipairs(items_in_range) do
        local group_id = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
        if group_id > 0 then -- 编组ID>0表示属于某个编组
            if not group_ids[group_id] then
                group_ids[group_id] = true
                item_group_map[group_id] = {}
            end
            table.insert(item_group_map[group_id], item)
        end
    end
    
    -- 检查是否有有效编组
    local group_count = 0
    for _ in pairs(group_ids) do
        group_count = group_count + 1
    end
    if group_count == 0 then
        reaper.ShowConsoleMsg("时间选区内的Item无有效编组！")
        return Track_info_params
    end
    
    -- 初始化存储参数 & 临时Region ID存储
    -- key=编组ID，value={父级文件夹轨道名, 往下第一个子一级轨道名， 往下第一个子二级轨道名， 空白item的notes}
    Track_info_params = {}
    -- 存储创建的临时Region ID，用于后续删除
    local temp_region_ids = {}
    
    -- 遍历每个Item编组处理
    for group_id, items in pairs(item_group_map) do
        -- 初始化当前编组的轨道信息
        Track_info_params[group_id] = {
            parent_TrackName = "",
            child_1_TrackName = "",
            child_2_TrackName = "",
            empty_item_notes = ""
        }
        
        -- 遍历编组内的每个Item，查找空白Item
        for _, item in ipairs(items) do
            local is_empty = false
            local take = reaper.GetActiveTake(item)
            
            -- 判断是否为空白Item（无Take 或 Take为空）
            if not take or reaper.TakeIsMIDI(take) == false and reaper.GetMediaSourceLength(reaper.GetMediaItemTake_Source(take)) == 0 then
                is_empty = true
            end
            
            if is_empty then
                -- 获取空白Item的备注信息（P_NOTES)
                local item_notes = reaper.ULT_GetMediaItemNote(item) -- 获取Item的P_NOTES
                Track_info_params[group_id].empty_item_notes = item_notes or ""

                -- 获取空白Item所在轨道
                local track = reaper.GetMediaItem_Track(item)
                if track then
                    -- 获取空白Item轨道名称
                    local retval, tr_1_name = reaper.GetTrackName(track)
                    Track_info_params[group_id].child_1_TrackName = tr_1_name
                    
                    local track_idx = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
                    -- 获取下一个轨道（如果存在）
                    local next_track = reaper.GetTrack(0, track_idx) -- 轨道索引从0开始，track_idx是1-based
                    if next_track then
                        local retval, tr_2_name = reaper.GetTrackName(next_track)
                        Track_info_params[group_id].child_2_TrackName = tr_2_name
                    else
                        Track_info_params[group_id].child_2_TrackName = "无下一个轨道"
                    end
                    -- 获取最上层父级轨道（如果存在）
                    local parent_track = reaper.GetParentTrack(track)
                    if parent_track then
                        local retval, pr_name = reaper.GetTrackName(parent_track)
                        Track_info_params[group_id].parent_TrackName = pr_name
                    else
                        Track_info_params[group_id].parent_TrackName = "无最上层父级轨道"
                    end

                end
                break -- 找到第一个空白Item即可，可根据需求修改为遍历所有
            end
        end
        
        -- 计算当前编组的总时长（取编组Item的最大时间范围）
        local group_start = math.huge
        local group_end = -math.huge
        for _, item in ipairs(items) do
            local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            group_start = math.min(group_start, item_start)
            group_end = math.max(group_end, item_end)
        end
        local group_duration = group_end - group_start
        
        -- 创建临时Region（名称为编组ID，方便识别）
        local region_id = reaper.AddProjectMarker2(0, true, group_start, group_end, "临时Region_编组"..group_id, -1, 0)
        if region_id ~= -1 then
            table.insert(temp_region_ids, region_id)
        end
    end
    
    reaper.Main_OnCommand(42230, 0) -- 文件: 使用最近渲染设置渲染工程, 自动关闭渲染对话框 ⇌ File: Render project, using the most recent render settings, auto-close render dialog
    
    -- 删除之前创建的临时Region
    for _, region_id in ipairs(temp_region_ids) do
        reaper.DeleteProjectMarker(0, region_id, true) -- true表示删除Region（Marker=false）
    end
    
    -- reaper.ShowConsoleMsg("已渲染编组item到当前工程目录/Mixdown/文件夹下，共："..group_count .. "个")
    
    --[[ -- 打印Track_info_params到控制台
    reaper.ShowConsoleMsg("\n==================== 轨道信息参数(Track_info_params) ====================\n")
    
    -- 遍历Track_info_params，打印每个编组的信息
    for group_id, track_info in pairs(Track_info_params) do
        -- 打印编组ID
        reaper.ShowConsoleMsg("编组ID: " .. tostring(group_id) .. "\n")
        -- 打印空白Item所在轨道名称
        reaper.ShowConsoleMsg("  空白Item轨道名: " .. track_info.parentTrackName .. "\n")
        -- 打印下一个轨道名称
        reaper.ShowConsoleMsg("  下一个轨道名: " .. track_info.childTrackName .. "\n")
        -- 分隔线，区分不同编组
        reaper.ShowConsoleMsg("------------------------------------------------------------------------\n")
    end
    
    -- 打印参数整体结构（可选，用于确认参数类型）
    reaper.ShowConsoleMsg("\n参数类型: " .. type(Track_info_params) .. " | 包含编组数量: " .. #(function() local t={} for k in pairs(Track_info_params) do t[#t+1]=k end return t end)() .. "\n")
     ]]

    return Track_info_params
end    

--- 检查ID是否已存在于表中（去重核心）
---@param tbl table 待检查的表
---@param str string 待检查的字符串
---@return boolean --存在返回true，不存在返回false
function Tool_Func.is_id_duplicate(tbl, str)
    if type(tbl) ~= "table" or type(str) ~= "string" then
        return false
    end
    for _, v in ipairs(tbl) do
        if v == str then
            return true
        end
    end
    return false
end

---@param t1 table @要被添加的表
---@param t2 table @包含被添加元素的表
---@return table t1 @返回添加后的表
function Tool_Func.table_append(t1, t2)
  for _, v in ipairs(t2) do
    table.insert(t1, v)
  end
  return t1
end


return Tool_Func
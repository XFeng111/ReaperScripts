--@noindex

-- ============================================================
-- 控制台消息拦截器（重定向 ShowConsoleMsg 到 UI 日志）
-- ============================================================

-- 1. 保存原始函数引用
local original_ShowConsoleMsg = reaper.ShowConsoleMsg

-- 2. 启动阶段的临时缓存（因为此时 state 尚未创建）
local captured_messages = {}

-- 3. 临时包装函数（启动阶段使用）
reaper.ShowConsoleMsg = function(msg)
    -- 不再输出到控制台，只缓存
    table.insert(captured_messages, msg:gsub('\n$', ''))
end

-- ============================================================
-- 功能函数模块路径设置
-- ============================================================
package.path = package.path..';'.. debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]:match("(.*[\\/])[^\\/]+[\\/]?$") .. "module/?.lua;" -- 将模块目录添加到package.path中
AM = require("AK_Module")
AF = require("AK_Func")
TF = require("Tool_Func")

-- 导入功能函数模块（只加载函数定义，不执行主逻辑）
local function loadFunctionModule(func_filepath)
  -- 读取文件内容
  local f = io.open(func_filepath, "r")
  if not f then
    reaper.ShowConsoleMsg('无法打开文件: ' .. func_filepath .. '\n')
    return false
  end
  
  local content = f:read("*all")
  f:close()
  
  -- 截断主执行部分（从 reaper.Undo_BeginBlock 开始）
  local main_start = content:find("reaper%.Undo_BeginBlock")
  if main_start then
    content = content:sub(1, main_start - 1)
  end
  
  -- 加载并执行（只执行函数定义部分）
  local func_chunk, load_err = load(content, func_filepath)
  if not func_chunk then
    reaper.ShowConsoleMsg('加载功能模块失败: ' .. tostring(load_err) .. '\n')
    return false
  end
  
  local success, exec_err = pcall(func_chunk)
  if not success then
    reaper.ShowConsoleMsg('执行功能模块失败: ' .. tostring(exec_err) .. '\n')
    return false
  end
  
  return true
end

-- ============================================================
-- UI 状态管理
-- ============================================================

local ctx = reaper.ImGui_CreateContext('Wwise Import UI')

local state = {
  -- 顶部
  container_type = 3,  -- 默认选中 RandomContainer（索引从0开始）
  container_type_label = 'RandomContainer',
  lang_marker = 0,  -- 导入语言（0: SFX, 1: CN, 2: EN）
  lang_marker_label = 'SFX',
  originals_subfolder = '示例：Plot\\Common',

  -- Event 选项控制
  show_event_options = false,  -- 是否显示Event选项区域
  event_path_mode = 0,  -- 0: 都不选, 1: 使用默认路径, 2: 使用ActorMixer结构, 3: 使用旧有资源
  use_special_rules = false,   -- 使用特殊规则指定路径
  all_stop = false,            -- All Stop
  use_special_rules_stop = false, -- 使用特殊规则创建Stop

  -- Event创建单位：Container / Sound
  event_unit_mode = 0, -- 0: Container, 1: Sound
  event_unit_mode_label = 'Container',

  -- Stop规则表格（只保留左列：名称匹配）
  rules_stop_open = true,
  rules_stop = {
    { name = '' },
  },

  -- 规则表格
  rules_open = true,
  rules = {
    { actor_path = '', event_path = '' },  -- 默认只有一行空规则
  },

  log_lines = {},
  log_auto_scroll = true,
  
  -- 协程控制
  coroutine_running = false,  -- 是否有协程正在运行
  coroutine_thread = nil,      -- 当前协程线程
}

-- ============================================================
-- 更新拦截器：state 创建后，将缓存写入并更新包装函数
-- ============================================================

-- 将启动阶段缓存的消息写入 state.log_lines
for _, msg in ipairs(captured_messages) do
  table.insert(state.log_lines, msg)
end
captured_messages = nil  -- 释放临时缓存

-- ============================================================
-- UI 日志函数（必须在 state 创建之后定义）
-- ============================================================

local function log(fmt, ...)
  local msg = fmt
  if select('#', ...) > 0 then
    msg = string.format(fmt, ...)
  end
  state.log_lines[#state.log_lines + 1] = msg
end

-- ============================================================
-- 更新拦截器：现在可以直接访问 state
-- ============================================================

-- 更新拦截器：现在可以直接访问 state
reaper.ShowConsoleMsg = function(msg)
  -- 不再输出到控制台，只写入UI日志
  
  -- 处理多行消息：按行分割
  for line in msg:gmatch("[^\n]+") do
    table.insert(state.log_lines, line)
    
    -- 可选：限制日志行数（防止内存溢出）
    if #state.log_lines > 1000 then
      table.remove(state.log_lines, 1)
    end
  end
  
  -- 如果在协程中，每次打印日志都检查是否需要yield（让UI实时刷新）
  if state.coroutine_running and coroutine.running() then
    local current_time = reaper.time_precise()
    if not coroutine_last_yield_time then
      coroutine_last_yield_time = current_time
    elseif (current_time - coroutine_last_yield_time) >= 0.1 then
      reaper.PreventUIRefresh(-1)  -- yield前解锁Reaper UI
      coroutine.yield()             -- yield：暂停协程，返回主循环
      coroutine_last_yield_time = reaper.time_precise()
      reaper.PreventUIRefresh(1)   -- yield后重新锁定Reaper UI
    end
  end
end

-- ============================================================
-- 协程工具函数（必须在功能绑定封装之前定义）
-- ============================================================

-- 协程时间控制（用于定期yield以更新UI）
local coroutine_last_yield_time = nil

-- 启动协程执行函数
local function runInCoroutine(func)
  if state.coroutine_running then
    log('警告: 有任务正在执行中，请稍候...')
    return
  end
  
  state.coroutine_running = true
  coroutine_last_yield_time = nil  -- 重置时间
  
  state.coroutine_thread = coroutine.create(function()
    reaper.PreventUIRefresh(1)  -- 锁定Reaper UI（上1把锁）
    
    local success, err = pcall(func)
    
    reaper.PreventUIRefresh(-1)  -- 解锁Reaper UI（解1把锁，计数器回到0）
    
    if not success then
      log('错误: ' .. tostring(err))
    end
    
    state.coroutine_running = false
    state.coroutine_thread = nil
    coroutine_last_yield_time = nil
  end)
end

-- 在主循环中推进协程
local function resumeCoroutine()
  if state.coroutine_thread and state.coroutine_running then
    local status = coroutine.status(state.coroutine_thread)
    if status == "suspended" then
      local success, err = coroutine.resume(state.coroutine_thread)
      if not success then
        log('协程错误: ' .. tostring(err))
        state.coroutine_running = false
        state.coroutine_thread = nil
        coroutine_last_yield_time = nil
      end
    elseif status == "dead" then
      state.coroutine_running = false
      state.coroutine_thread = nil
      coroutine_last_yield_time = nil
    end
  end
end

-- ============================================================
-- 按需加载功能模块（优化：只加载需要的模块，避免启动时全部加载）
-- ============================================================
local loaded_modules = {}  -- 缓存已加载的模块

-- 只加载特定模块（带缓存）
local function ensureModuleLoaded(module_name)
  -- 如果已加载，直接返回
  if loaded_modules[module_name] then
    return true
  end
  
  log('正在加载模块: ' .. module_name)
  
  local base_path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]]
  local success = loadFunctionModule(base_path .. module_name)
  
  if success then
    loaded_modules[module_name] = true
    log('模块加载成功: ' .. module_name)
  else
    log('模块加载失败: ' .. module_name)
  end
  
  return success
end

-- ============================================================
-- 功能函数绑定封装
-- ============================================================

-- 通用绑定函数：在协程中执行带Wwise连接的功能
local function executeWwiseFunction(func_name, module_name, global_func_name, ...)
  -- 按需加载：只加载当前功能需要的模块
  if not ensureModuleLoaded(module_name) then
    log('错误: 模块加载失败')
    return
  end
  
  -- 加载成功后，从全局环境获取函数引用（避免传参时函数未定义）
  local func = _G[global_func_name]
  if not func then
    log('错误: 功能函数 ' .. global_func_name .. ' 不存在')
    return
  end
  
  local args = {...}
  
  runInCoroutine(function()
    log('开始执行: ' .. func_name)
    AF.init()  -- 连接Wwise
    
    if #args > 0 then
      func(table.unpack(args))
    else
      func()
    end
    
    AF.disconnect()  -- 断开Wwise连接
    log('执行完成: ' .. func_name)
  end)
end

-- 绑定函数快捷方式（传入函数名字符串，而非函数引用）
local function bindWwiseObjectDetection()
  executeWwiseFunction(
    'Wwise对象检测', 
    'Rea_GetInfo_SelectedObjects.lua',
    'Rea_GetInfo_SelectedObjects'  -- 字符串：函数名
  )
end

local function bindSetWwisePath()
  executeWwiseFunction(
    '设置WwisePath', 
    'Rea_SetPath_ParentTrack.lua',
    'Rea_SetPath_ParentTrack'  -- 字符串：函数名
  )
end

local function bindImportReaper()
  executeWwiseFunction(
    '导入Reaper', 
    'Rea_ImportReaper.lua',
    'Rea_ImportReaper'  -- 字符串：函数名
  )
end

local function bindCreateStructure()
  -- 检查子文件夹路径是否为空
  if state.originals_subfolder == '' then
    log('错误: 请填写子文件夹OriginalsSubFolder路径')
    return
  end
  
  -- 从state获取用户选择的参数
  local originalsSubFolder = state.originals_subfolder
  local containerType = state.container_type_label
  local lang_marker = state.lang_marker_label
  
  executeWwiseFunction(
    '创建导入结构', 
    'Rea_CreateStructure_items.lua',
    'Rea_CreateStructure_items',  -- 字符串：函数名
    originalsSubFolder, 
    containerType, 
    lang_marker
  )
end

local function bindImportWwise()
  -- 检查是否勾选创建Event
  if not state.show_event_options then
    -- 未勾选创建Event，直接执行导入Wwise
    executeWwiseFunction(
      '导入Wwise', 
      'Rea_ImportWwise.lua',
      'Rea_ImportWwise'
    )
    return
  end
  
  -- 勾选了创建Event，检查是否选择了Event路径模式
  if state.event_path_mode == 0 then
    log('请选择Event创建方式')
    return
  end
  
  -- 如果勾选了使用特殊规则，校验规则表
  if state.use_special_rules then
    local has_empty = false
    for i, rule in ipairs(state.rules) do
      if rule.actor_path == '' or rule.event_path == '' then
        has_empty = true
        log('错误: 规则行 ' .. i .. ' 存在空值，请填写完整')
      end
    end
    
    if has_empty then
      log('错误: 特殊规则表存在空值，无法执行导入')
      return
    end
  end
  
  -- 如果勾选了使用特殊规则创建Stop，校验Stop规则表
  if state.use_special_rules_stop then
    local has_empty_stop = false
    for i, rule in ipairs(state.rules_stop) do
      if rule.name == '' then
        has_empty_stop = true
        log('错误: Stop规则行 ' .. i .. ' 存在空值，请填写完整')
      end
    end
    
    if has_empty_stop then
      log('错误: Stop特殊规则表存在空值，无法执行导入')
      return
    end
  end
  
  -- 执行导入Wwise + 创建Event
  if not ensureModuleLoaded('Rea_ImportWwise.lua') then
    log('错误: 模块加载失败')
    return
  end
  
  local func = _G['Rea_ImportWwise']
  if not func then
    log('错误: 功能函数 Rea_ImportWwise 不存在')
    return
  end
  
  runInCoroutine(function()
    log('开始执行: 导入Wwise')
    AF.init()  -- 连接Wwise
    
    -- 执行导入Wwise，获取返回值
    local import_results, import_info_Cr, import_info_Sound = func()

    local import_info = (state.event_unit_mode == 0) and import_info_Cr or import_info_Sound
    
    if not import_info then
      log('警告: 导入Wwise未返回import_info，跳过Event创建')
      AF.disconnect()
      log('执行完成: 导入Wwise')
      return
    end
    
    -- 如果勾选了特殊规则，进行路径替换
    if state.use_special_rules then
      log('应用特殊规则路径替换...')
      
      -- 构建规则映射表
      local rule_map = {}
      for _, rule in ipairs(state.rules) do
        rule_map[rule.actor_path] = rule.event_path
      end
      
      -- 遍历import_info，查找匹配的parentPath并替换
      local new_import_info = {}
      for parentPath, info in pairs(import_info) do
        local new_path = rule_map[parentPath]
        if new_path then
          log('路径替换: ' .. parentPath .. ' -> ' .. new_path)

          local existing = new_import_info[new_path]
          if existing then
            -- 多个parentPath映射到同一个new_path时，需要合并数据，避免覆盖丢失
            log('  → 检测到重复路径，合并数据: ' .. parentPath)
            existing.is_special_rule = true

            existing.ids = existing.ids or {}
            existing.names = existing.names or {}

            local ids = info.ids or {}
            local names = info.names or {}

            -- 保持原有分组结构：把另一组的分组 append 到末尾
            for i = 1, math.max(#ids, #names) do
              if ids[i] then table.insert(existing.ids, ids[i]) end
              if names[i] then table.insert(existing.names, names[i]) end
            end
            
            log('  → 合并后共 ' .. #existing.ids .. ' 个批次')
          else
            new_import_info[new_path] = info
            info.is_special_rule = true  -- 标记为特殊规则组
          end
        else
          new_import_info[parentPath] = info
          info.is_special_rule = false
        end
      end
      
      import_info = new_import_info
    end
    
    -- 根据event_path_mode创建Event
    log('开始创建Event...')
    
    for parentPath, info in pairs(import_info) do
      local ids = info.ids or {}
      local names = info.names or {}
      local is_special_rule = info.is_special_rule or false
      
      if #ids == 0 or #names == 0 then
        log('警告: parentPath ' .. parentPath .. ' 没有有效的ids或names，跳过')
        goto continue
      end
      
      -- 按照原始分组结构，分批创建Event（不合并到一个大表）
      for i, id_group in ipairs(ids) do
        local name_group = names[i]
        
        if not name_group or #id_group == 0 or #name_group == 0 then
          log('警告: 分组 ' .. i .. ' 数据不完整，跳过')
          goto continue_group
        end
        
        log('创建Event批次 ' .. i .. '/' .. #ids .. ' (' .. #name_group .. '个Event)')
        
        -- 特殊规则组强制使用ActorMixer结构创建
        if is_special_rule then
          log('使用特殊规则(ActorMixer结构)创建Event: ' .. parentPath)
          AF.event_creat_FromActorPath(parentPath, "1", name_group, id_group, "2")
          
          -- All Stop：再创建一次Stop Event
          if state.all_stop then
            log('  → All Stop: 创建Stop Event')
            AF.event_creat_FromActorPath(parentPath, "2", name_group, id_group, "2")
          end
        else
          -- 根据event_path_mode执行不同的创建逻辑
          if state.event_path_mode == 1 then
            -- 使用默认路径
            log('使用默认路径创建Event: ' .. parentPath)
            AF.event_creat("\\Events", "Work Unit", "Default Work Unit", "merge", name_group, id_group, "1")
            
            -- All Stop：再创建一次Stop Event
            if state.all_stop then
              log('  → All Stop: 创建Stop Event')
              AF.event_creat("\\Events", "Work Unit", "Default Work Unit", "merge", name_group, id_group, "2")
            end
            
          elseif state.event_path_mode == 2 then
            -- 使用ActorMixer结构
            log('使用ActorMixer结构创建Event: ' .. parentPath)
            AF.event_creat_FromActorPath(parentPath, "1", name_group, id_group, "2")
            
            -- All Stop：再创建一次Stop Event
            if state.all_stop then
              log('  → All Stop: 创建Stop Event')
              AF.event_creat_FromActorPath(parentPath, "2", name_group, id_group, "2")
            end
            
          elseif state.event_path_mode == 3 then
            -- 使用旧有资源
            log('使用旧有资源创建Event: ' .. parentPath)
            AF.event_creat_FromOld("1", name_group, id_group)
            
            -- All Stop：再创建一次Stop Event
            if state.all_stop then
              log('  → All Stop: 创建Stop Event')
              AF.event_creat_FromOld("2", name_group, id_group)
            end
          end
        end
        
        -- 使用特殊规则创建Stop：匹配name并筛选出Stop组
        if state.use_special_rules_stop then
          local name_group_stop = {}
          local id_group_stop = {}
          
          -- 遍历name_group，查找匹配的元素
          for j, name in ipairs(name_group) do
            local matched = false
            -- 遍历Stop规则表，查找匹配
            for _, stop_rule in ipairs(state.rules_stop) do
              if stop_rule.name ~= '' and name:lower():find(stop_rule.name:lower(), 1, true) then
                matched = true
                log('  → Stop规则匹配: ' .. name .. ' (规则: ' .. stop_rule.name .. ')')
                break
              end
            end
            
            if matched then
              table.insert(name_group_stop, name)
              table.insert(id_group_stop, id_group[j])
            end
          end
          
          -- 如果有匹配的Stop组，创建Stop Event
          if #name_group_stop > 0 then
            log('  → 创建Stop Event (' .. #name_group_stop .. '个)')
            
            if is_special_rule then
              AF.event_creat_FromActorPath(parentPath, "2", name_group_stop, id_group_stop, "2")
            else
              if state.event_path_mode == 1 then
                AF.event_creat("\\Events", "Work Unit", "Default Work Unit", "merge", name_group_stop, id_group_stop, "2")
              elseif state.event_path_mode == 2 then
                AF.event_creat_FromActorPath(parentPath, "2", name_group_stop, id_group_stop, "2")
              elseif state.event_path_mode == 3 then
                AF.event_creat_FromOld("2", name_group_stop, id_group_stop)
              end
            end
          end
        end
        
        ::continue_group::
      end
      
      ::continue::
    end
    
    log('Event创建完成')
    
    AF.disconnect()  -- 断开Wwise连接
    log('执行完成: 导入Wwise + 创建Event')
  end)
end

-- ============================================================
-- UI 函数绑定
-- ============================================================

-- 帮助提示标记（显示 (?) 和 tooltip）
local function HelpMarker(desc)
  reaper.ImGui_TextDisabled(ctx, '(?)')
  if reaper.ImGui_BeginItemTooltip(ctx) then
    reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
    reaper.ImGui_Text(ctx, desc)
    reaper.ImGui_PopTextWrapPos(ctx)
    reaper.ImGui_EndTooltip(ctx)
  end
end

local function drawHeaderLikeLine(label)
  reaper.ImGui_Separator(ctx)
  reaper.ImGui_Text(ctx, label)
end

local function drawTopArea()
  local btn_h = 40
  local btn_w = 260  -- 单个按钮宽度
  local spacing = 10 -- 按钮间距（从 ItemSpacing 来）

  -- Reaper Import Settings (改为折叠框)
  reaper.ImGui_SetNextItemOpen(ctx, true, reaper.ImGui_Cond_Once())
  if reaper.ImGui_CollapsingHeader(ctx, 'Reaper Import Settings') then
    -- 不使用Indent，手动控制缩进以便与导入Wwise对齐
    local indent_x = 16  -- 手动缩进量

    -- 按钮样式（仅设置圆角和内边距）
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 6)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 8, 6)

    -- Row 1: Wwise对象检测(固定宽度) | 设置WwisePath(占满剩余宽度)
    if reaper.ImGui_Button(ctx, 'Wwise对象检测', btn_w, btn_h) then
      bindWwiseObjectDetection()
    end
    reaper.ImGui_SameLine(ctx)
    HelpMarker('Wwise对象检测：检测Wwise中选中的对象，获取其名称、类型和路径信息\n设置WwisePath：设置Reaper父级文件夹名称为当前选中Wwise对象路径')
    
    reaper.ImGui_SameLine(ctx, 0, 10)
    if reaper.ImGui_Button(ctx, '设置WwisePath', -1, btn_h) then
      bindSetWwisePath()
    end

    -- Row 2: 导入Reaper (占满全宽)
    if reaper.ImGui_Button(ctx, '导入Reaper', -1, btn_h) then
      bindImportReaper()
    end

    reaper.ImGui_PopStyleVar(ctx, 2)
  end

  -- divider
  reaper.ImGui_Spacing(ctx)
  reaper.ImGui_Separator(ctx)
  reaper.ImGui_Spacing(ctx)

  -- Header: Wwise Import Settings
  reaper.ImGui_SetNextItemOpen(ctx, true, reaper.ImGui_Cond_Once())
  if reaper.ImGui_CollapsingHeader(ctx, 'Wwise Import Settings') then
    local indent_x = 16  -- 手动缩进量，与Reaper Import Settings一致

    local label_w = 220  -- 增大标签列宽度以显示完整文本

    -- Inputs 样式
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4)

    -- Row 1: 导入语言 (label + combo)
    reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) + indent_x)
    reaper.ImGui_AlignTextToFramePadding(ctx)
    reaper.ImGui_Text(ctx, '导入语言')
    reaper.ImGui_SameLine(ctx, label_w + indent_x, 0)
    HelpMarker('音效SFX / 语音中文CN / 语音英文EN')
    reaper.ImGui_SameLine(ctx, label_w + indent_x + 24, 0)

    reaper.ImGui_SetNextItemWidth(ctx, -1)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x48C0F0FF)  -- 输入文字蓝色
    if reaper.ImGui_BeginCombo(ctx, '##lang_marker', state.lang_marker_label) then
      local languages = {'SFX', 'CN', 'EN'}

      for i = 1, #languages do
        local idx = i - 1
        local is_selected = (state.lang_marker == idx)
        if reaper.ImGui_Selectable(ctx, languages[i], is_selected) then
          state.lang_marker = idx
          state.lang_marker_label = languages[i]
        end
        if is_selected then
          reaper.ImGui_SetItemDefaultFocus(ctx)
        end
      end

      reaper.ImGui_EndCombo(ctx)
    end
    reaper.ImGui_PopStyleColor(ctx)  -- Pop Text颜色

    -- Row 2: 容器类型 (label + combo)
    reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) + indent_x)
    reaper.ImGui_AlignTextToFramePadding(ctx)
    reaper.ImGui_Text(ctx, '容器类型')
    reaper.ImGui_SameLine(ctx, label_w + indent_x, 0)
    HelpMarker('多样本（_01/02/03）的容器类型')
    reaper.ImGui_SameLine(ctx, label_w + indent_x + 24, 0)

    reaper.ImGui_SetNextItemWidth(ctx, -1)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x48C0F0FF)  -- 输入文字蓝色
    if reaper.ImGui_BeginCombo(ctx, '##container_type', state.container_type_label) then
      local containers = {
        'Folder',
        'WorkUnit',
        'ActorMixer',
        'RandomContainer',
        'SequenceContainer',
        'SwitchContainer',
        'BlendContainer'
      }

      for i = 1, #containers do
        local idx = i - 1
        local is_selected = (state.container_type == idx)
        if reaper.ImGui_Selectable(ctx, containers[i], is_selected) then
          state.container_type = idx
          state.container_type_label = containers[i]
        end
        if is_selected then
          reaper.ImGui_SetItemDefaultFocus(ctx)
        end
      end

      reaper.ImGui_EndCombo(ctx)
    end
    reaper.ImGui_PopStyleColor(ctx)  -- Pop Text颜色

    -- Row 3: 子文件夹OriginalsSubFolder (label + input, 与combo对齐)
    reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) + indent_x)
    reaper.ImGui_AlignTextToFramePadding(ctx)
    reaper.ImGui_Text(ctx, '子文件夹OriginalsSubFolder')
    reaper.ImGui_SameLine(ctx, label_w + indent_x, 0)
    HelpMarker('需放入的Originals子文件夹路径\n例如：[Wwise工程目录]\\Originals\\SFX\\Plot\\Common，填入Plot\\Common即可')
    reaper.ImGui_SameLine(ctx, label_w + indent_x + 24, 0)  -- 与combo起始位置对齐
    reaper.ImGui_SetNextItemWidth(ctx, -1)
    local rv
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x48C0F0FF)  -- 输入文字蓝色
    rv, state.originals_subfolder = reaper.ImGui_InputText(ctx, '##originals_subfolder', state.originals_subfolder)
    reaper.ImGui_PopStyleColor(ctx)  -- Pop Text颜色

    reaper.ImGui_PopStyleVar(ctx)

    -- Row 4: 创建导入结构 (右对齐到输入框右边界)
    local avail_w, _ = reaper.ImGui_GetContentRegionAvail(ctx)
    local btn_w_create = 220
    local help_marker_offset = 30  -- HelpMarker宽度预留
    local btn_offset = avail_w - btn_w_create - help_marker_offset
    if btn_offset > 0 then
      reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) + btn_offset)
    end
    
    -- HelpMarker放在按钮左侧，与按钮中线对齐
    local cursor_y = reaper.ImGui_GetCursorPosY(ctx)
    local frame_padding_y = select(2, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding()))
    local text_line_h = reaper.ImGui_GetTextLineHeight(ctx)
    local marker_y = cursor_y + (btn_h - text_line_h) * 0.5
    -- 微调：加上FramePadding使 (?) 更接近按钮文字的垂直居中
    marker_y = marker_y + frame_padding_y * 0.25
    reaper.ImGui_SetCursorPosY(ctx, marker_y)
    HelpMarker('为Reaper时间选区下的Item创建导入结构，并在Wwise中创建对应的容器结构（如检测需要）')
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetCursorPosY(ctx, cursor_y)
    
    -- 创建导入结构按钮
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 6)
    if reaper.ImGui_Button(ctx, '创建导入结构', btn_w_create, btn_h) then
      bindCreateStructure()
    end
    reaper.ImGui_PopStyleVar(ctx)
  end

  -- divider label (添加缩进以与上方内容对齐)
  reaper.ImGui_Spacing(ctx)
  local indent_x = 16
  reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) + indent_x)
  reaper.ImGui_SeparatorText(ctx, 'Event Settings')
end

local function drawCreateEventSection()
  local rv
  local indent_x = 16  -- 与其他section的缩进保持一致

  -- 主勾选框：控制是否显示Event选项（添加缩进对齐）
  reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) + indent_x)
  rv, state.show_event_options = reaper.ImGui_Checkbox(ctx, '创建Event', state.show_event_options)
  reaper.ImGui_SameLine(ctx)
  HelpMarker('勾选后将在导入Wwise时自动创建Play Event')

  -- Event创建单位（右侧下拉）
  reaper.ImGui_SameLine(ctx, 180, 0)
  reaper.ImGui_SetNextItemWidth(ctx, 120)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x48C0F0FF)  -- 输入文字蓝色
  if reaper.ImGui_BeginCombo(ctx, '##event_unit_mode', state.event_unit_mode_label) then
    local options = { 'Container', 'Sound' }
    for i = 1, #options do
      local idx = i - 1
      local is_selected = (state.event_unit_mode == idx)
      if reaper.ImGui_Selectable(ctx, options[i], is_selected) then
        state.event_unit_mode = idx
        state.event_unit_mode_label = options[i]
      end
      if is_selected then
        reaper.ImGui_SetItemDefaultFocus(ctx)
      end
    end
    reaper.ImGui_EndCombo(ctx)
  end
  reaper.ImGui_PopStyleColor(ctx)  -- Pop Text颜色
  reaper.ImGui_SameLine(ctx)
  HelpMarker('Container：导入样本若存在容器则以容器单位创建Event\nSound：全部以Sound单位创建Event')

  -- 只有勾选时才显示Event相关选项
  if state.show_event_options then
    reaper.ImGui_Indent(ctx, indent_x * 2)  -- 子选项再缩进一次

    -- 互斥单选：使用默认路径 / 使用旧有资源 / 使用ActorMixer结构（并列对齐）
    rv, state.event_path_mode = reaper.ImGui_RadioButtonEx(ctx, '使用默认路径', state.event_path_mode, 1)
    reaper.ImGui_SameLine(ctx)
    HelpMarker('在Events\\Default Work Unit下创建Event')
    reaper.ImGui_SameLine(ctx, 250, 0)
    rv, state.event_path_mode = reaper.ImGui_RadioButtonEx(ctx, '使用旧有资源', state.event_path_mode, 3)
    reaper.ImGui_SameLine(ctx)
    HelpMarker('根据同级已有Event的路径创建新Event')
    reaper.ImGui_SameLine(ctx, 500, 0)
    rv, state.event_path_mode = reaper.ImGui_RadioButtonEx(ctx, '使用ActorMixer结构', state.event_path_mode, 2)
    reaper.ImGui_SameLine(ctx)
    HelpMarker('根据Actor路径结构在Events下创建对应层级的Event')


    -- 第二行：特殊规则指定路径（左） + 特殊规则创建Stop（中） + All Stop（右）
    rv, state.use_special_rules = reaper.ImGui_Checkbox(ctx, '##use_special_rules', state.use_special_rules)
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, '使用特殊规则指定路径')
    reaper.ImGui_SameLine(ctx)
    HelpMarker('通过规则表匹配Actor路径，替换为指定的Event路径')

    reaper.ImGui_SameLine(ctx, 320, 0)
    rv, state.use_special_rules_stop = reaper.ImGui_Checkbox(ctx, '##use_special_rules_stop', state.use_special_rules_stop)
    -- 互斥逻辑：勾选"使用特殊规则创建Stop"时，取消"All Stop"
    if rv and state.use_special_rules_stop then
      state.all_stop = false
    end
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, '使用特殊规则创建Stop')
    reaper.ImGui_SameLine(ctx)
    HelpMarker('通过规则表匹配Event名称，为匹配项创建Stop Event')

    reaper.ImGui_SameLine(ctx, 620, 0)
    rv, state.all_stop = reaper.ImGui_Checkbox(ctx, '##all_stop', state.all_stop)
    -- 互斥逻辑：勾选"All Stop"时，取消"使用特殊规则创建Stop"
    if rv and state.all_stop then
      state.use_special_rules_stop = false
    end
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, 'All Stop')
    reaper.ImGui_SameLine(ctx)
    HelpMarker('为所有导入的对象创建Stop Event（与特殊规则创建Stop互斥）')

    reaper.ImGui_Unindent(ctx, indent_x * 2)
  end
end

local function drawRulesStopTable()
  reaper.ImGui_Spacing(ctx)

  reaper.ImGui_SetNextItemOpen(ctx, state.rules_stop_open, reaper.ImGui_Cond_Always())
  if reaper.ImGui_CollapsingHeader(ctx, '使用特殊规则创建Stop') then
    state.rules_stop_open = true

    local col1_w = 200
    local col1_btn_w = 96

    reaper.ImGui_SeparatorText(ctx, '特殊规则名称匹配')
    
    -- 表格输入框样式
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4)
    
    -- 表格按钮样式
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 6)
    
    for i = 1, #state.rules_stop do
      local row = state.rules_stop[i]
      reaper.ImGui_PushID(ctx, 10000 + i)

      reaper.ImGui_SetNextItemWidth(ctx, col1_w)
      local rv
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x48C0F0FF)  -- 输入文字蓝色
      rv, row.name = reaper.ImGui_InputText(ctx, '##rule_stop_actor', row.name)
      reaper.ImGui_PopStyleColor(ctx)  -- Pop Text颜色
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, '获取名称##rule_stop_actor_name', col1_btn_w, 0) then
        if ensureModuleLoaded('Rea_GetInfo_SelectedObjects.lua') then
          AF.init()
          local name_table, type_table, path_table = Rea_GetInfo_SelectedObjects()
          AF.disconnect()

          if name_table and name_table[1] then
            row.name = name_table[1]
            log('获取名称(Stop规则名称匹配): ' .. name_table[1])
          else
            log('错误: 未获取到名称')
          end
        end
      end

      reaper.ImGui_PopID(ctx)
    end

    -- Pop 输入框和按钮的 FrameRounding
    reaper.ImGui_PopStyleVar(ctx, 2)

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 6)
    local btn_row_h = 0
    if reaper.ImGui_Button(ctx, '新增规则行##rules_stop_add', 120, btn_row_h) then
      state.rules_stop[#state.rules_stop + 1] = { name = '' }
      log('add stop rule row')
    end

    reaper.ImGui_SameLine(ctx, 0, 30)
    if reaper.ImGui_Button(ctx, '删除规则行##rules_stop_del', 120, btn_row_h) then
      if #state.rules_stop > 0 then
        state.rules_stop[#state.rules_stop] = nil
        log('delete stop rule row')
      end
    end
    reaper.ImGui_SameLine(ctx)
    HelpMarker('选中Wwise对象点击获取名称')

    reaper.ImGui_PopStyleVar(ctx)
  else
    state.rules_stop_open = false
  end
end

local function drawRulesTable()
  reaper.ImGui_Spacing(ctx)

  reaper.ImGui_SetNextItemOpen(ctx, state.rules_open, reaper.ImGui_Cond_Always())
  if reaper.ImGui_CollapsingHeader(ctx, '使用特殊规则指定路径') then
    state.rules_open = true

    -- 两列标题 + 按钮标题区域
    local col1_w = 200
    local col1_btn_w = 96   -- 缩小到原来的4/5 (120 * 0.8 = 96)
    local col1_gap = 10
    local col2_btn_w = 96   -- 缩小到原来的4/5
    local col2_gap = 10

    local col2_x = col1_w + col1_btn_w + col1_gap
    local col2_input_w = -1 - (col2_btn_w + col2_gap)

    reaper.ImGui_SeparatorText(ctx, '特殊规则Actor路径匹配')
    reaper.ImGui_SameLine(ctx, col2_x+10, 0)
    reaper.ImGui_SeparatorText(ctx, 'Event指定路径')

    -- 表格样式
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 6)

    for i = 1, #state.rules do
      local row = state.rules[i]
      reaper.ImGui_PushID(ctx, i)

      -- Col1: 名称输入框 + 获取路径
      reaper.ImGui_SetNextItemWidth(ctx, col1_w)
      local rv
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x48C0F0FF)  -- 输入文字蓝色
      rv, row.actor_path = reaper.ImGui_InputText(ctx, '##rule_actor', row.actor_path)
      reaper.ImGui_PopStyleColor(ctx)  -- Pop Text颜色
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, '获取路径##rule_actor_path', col1_btn_w, 0) then
        -- 获取Wwise选中对象的路径并填入当前行的path字段
        if ensureModuleLoaded('Rea_GetInfo_SelectedObjects.lua') then
          AF.init()  -- 连接Wwise
          local name_table, type_table, path_table = Rea_GetInfo_SelectedObjects()
          AF.disconnect()  -- 断开连接
          
          if path_table and path_table[1] then
            row.actor_path = path_table[1]
            log('获取路径(Actor路径): ' .. path_table[1])
          else
            log('错误: 未获取到路径')
          end
        end
      end

      -- Col2: 路径输入框 + 获取路径（右边界跟随表格区域）
      reaper.ImGui_SameLine(ctx, col2_x+10, 0)
      reaper.ImGui_SetNextItemWidth(ctx, col2_input_w)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x48C0F0FF)  -- 输入文字蓝色
      rv, row.event_path = reaper.ImGui_InputText(ctx, '##rule_path', row.event_path)
      reaper.ImGui_PopStyleColor(ctx)  -- Pop Text颜色
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, '获取路径##rule_event_path', col2_btn_w, 0) then
        -- 获取Wwise选中对象的路径并填入当前行的path字段
        if ensureModuleLoaded('Rea_GetInfo_SelectedObjects.lua') then
          AF.init()  -- 连接Wwise
          local name_table, type_table, path_table = Rea_GetInfo_SelectedObjects()
          AF.disconnect()  -- 断开连接
          
          if path_table and path_table[1] then
            row.event_path = path_table[1]
            log('获取路径(Event路径): ' .. path_table[1])
          else
            log('错误: 未获取到路径')
          end
        end
      end

      reaper.ImGui_PopID(ctx)
    end

    -- Pop 表格样式
    reaper.ImGui_PopStyleVar(ctx, 2)

    -- 底部按钮
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 6)
    local btn_row_h = 0
    if reaper.ImGui_Button(ctx, '新增规则行##rules_add', 120, btn_row_h) then
      state.rules[#state.rules + 1] = { actor_path = '', event_path = '' }
      log('add rule row')
    end

    reaper.ImGui_SameLine(ctx, 0, 30)  -- 间隔 30px
    if reaper.ImGui_Button(ctx, '删除规则行##rules_del', 120, btn_row_h) then
      if #state.rules > 0 then
        state.rules[#state.rules] = nil
        log('delete rule row')
      end
    end
    reaper.ImGui_SameLine(ctx)
    HelpMarker('选中Wwise对象点击获取路径')

    reaper.ImGui_PopStyleVar(ctx)
  else
    state.rules_open = false
  end
end

local function drawBottom()
  reaper.ImGui_Spacing(ctx)
  reaper.ImGui_Separator(ctx)
  reaper.ImGui_Spacing(ctx)

  -- 导入Wwise button (占满全宽)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 6)
  if reaper.ImGui_Button(ctx, '导入Wwise', -1, 44) then
    bindImportWwise()
  end
  reaper.ImGui_PopStyleVar(ctx)

  -- Stop相关开关暂不接入执行逻辑（仅UI）
  if state.all_stop then
    -- placeholder
  end

  -- 清空Log（右对齐）
  local avail_w, _ = reaper.ImGui_GetContentRegionAvail(ctx)
  local btn_w_clear = 220
  local btn_h_clear = 40
  local btn_offset = avail_w - btn_w_clear
  if btn_offset > 0 then
    reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) + btn_offset)
  end
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 6)
  if reaper.ImGui_Button(ctx, '清空Log', btn_w_clear, btn_h_clear) then
    state.log_lines = {}
  end
  reaper.ImGui_PopStyleVar(ctx)

  -- Log box
  reaper.ImGui_Spacing(ctx)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 4)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildBorderSize(), 2)

  state.log_min_height = state.log_min_height or 400
  state.log_current_height = state.log_current_height or state.log_min_height

  local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
  -- 尝试使用剩余空间，但不低于最小高度；同时不允许缩小（只增不减）
  local desired_h = math.max(state.log_min_height, avail_h)
  if desired_h > state.log_current_height then
    state.log_current_height = desired_h
  end

  -- BeginChild 的 flags 参数：设置边框
  local child_flags = reaper.ImGui_ChildFlags_Borders()
  if reaper.ImGui_BeginChild(ctx, '##log_child', -1, state.log_current_height, child_flags) then
    local log_text = table.concat(state.log_lines, '\n')
    reaper.ImGui_TextWrapped(ctx, log_text)
    reaper.ImGui_EndChild(ctx)
  end
  reaper.ImGui_PopStyleVar(ctx, 2)  -- Pop ChildRounding + ChildBorderSize
end

local function loop()
  -- 推进协程（每帧检查）
  resumeCoroutine()
  
  reaper.ImGui_SetNextWindowSize(ctx, 760, 650, reaper.ImGui_Cond_FirstUseEver())
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 14, 12)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 10, 8)
  
  -- 主题配色（可选）
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), 0x141618ff)           -- 背景
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(), 0x1b1e21ff)            -- 标题栏
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(), 0x1f2327ff)      -- 激活标题栏
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgCollapsed(), 0x1b1e21ff)   -- 折叠标题栏
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), 0x23272cff)             -- CollapsingHeader
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), 0x2b3137ff)      -- CollapsingHeader Hover
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), 0x40A8FFff)       -- CollapsingHeader Active
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(), 0x2ea7d3ff)          -- 勾选标记（蓝）
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(), 0x1b1e21ff)            -- 下拉框背景
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x2b3137ff)             -- 按钮
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x353c44ff)      -- 按钮 Hover
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x40A8FFff)       -- 按钮 Active
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), 0x1e2328ff)            -- 输入框背景
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(), 0x262d34ff)     -- 输入框 Hover
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(), 0x20262cff)      -- 输入框 Active
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), 0x0f1113ff)            -- 子窗口背景（Log区域）
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFFFFFFFF)               -- 文字颜色

  -- 获取默认字体并设置为16px（比默认大小更大更清晰）
  local default_font = reaper.ImGui_GetFont(ctx)
  reaper.ImGui_PushFont(ctx, default_font, 16)

  local visible, open = reaper.ImGui_Begin(ctx, 'Wwise Import UI', true)

  if visible then
    -- 创建可滚动的主内容区域（内容超出时自动显示垂直滚动条）
    if reaper.ImGui_BeginChild(ctx, '##main_content', -1, -1, reaper.ImGui_ChildFlags_None()) then
      drawTopArea()
      drawCreateEventSection()
      
      -- 特殊规则表格作为创建Event的子内容，只有勾选创建Event时才显示
      if state.show_event_options then
        if state.use_special_rules then
          drawRulesTable()
        end
        if state.use_special_rules_stop then
          drawRulesStopTable()
        end
      end
      
      drawBottom()
      
      reaper.ImGui_EndChild(ctx)
    end

    reaper.ImGui_End(ctx)
  end

  reaper.ImGui_PopFont(ctx)
  reaper.ImGui_PopStyleColor(ctx, 17)  -- 17个全局颜色
  reaper.ImGui_PopStyleVar(ctx, 2)

  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)

# ReaWwise_Import_Manage 工具使用说明
---
# Installation
使用ReaPack下载，Extension > ReaPack > Import Repositories... 

https://raw.githubusercontent.com/XFeng111/ReaperScripts/refs/heads/main/index.xml

# 简介
● 参考LKC的GrimSync工作流创建的导入工具（items编组为一个单位）\
● 支持一个Reaper工程设置多个Originals路径\
● 支持导入Sound资源同步多方式创建Play/Stop_Event（默认Events下，按照ActorMixer结构、按照同层级旧有资源的Event路径、特殊规则指定多路径）\
● 支持Wwise资源回流Reaper修改导回\
● 亲测入Wwise速度比LKC快（首次运行因模块加载会慢一些）

# 依赖安装
## Reaper 7版本及其以上
https://www.reaper.fm/download-old.php

## reapack安装官方ReaWwise
Copy and paste this URL in Extensions > ReaPack > Import repositories...\
https://github.com/Audiokinetic/Reaper-Tools/raw/main/index.xml

相关官网文档：https://www.audiokinetic.com/zh/community/blog/reawwise-connecting-reaper-and-wwise/

## UserPlugins模块依赖安装
ReaWwise_Import_Manage_ReaPack里UserPlugins文件夹下选择对应系统的组件，复制到：Reaper安装目录\UserPlugins\ （没有则新建个UserPlugins文件夹放入）

https://club.reaget.com/t/topic/15423

---

# 重要注意事项
## 当前编组items修改后必须先取消整体编组再重新编组！！ 
Action List
1. 对象编组: 从编组中移除对象 ⇌ Item grouping: Remove items from group
2. 对象编组: 编组对象 ⇌ Item grouping: Group items

<a href="https://www.bilibili.com/video/BV12hdtBcEru/" title="点击跳转视频">
<img src="https://raw.githubusercontent.com/XFeng111/ReaperScripts/main/user-attachments/ReaWwise_Import_Manage%20%E5%B7%A5%E5%85%B7%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E/%E9%87%8D%E6%96%B0%E7%BC%96%E7%BB%84.gif" style="width:100%;height:auto;">
</a>

## 导出设置！！
导出设置以下四项必须如下一致，否则导入wwise会失败，其余设置无要求，导入wwise默认wav格式：\
（新建工程可使用reapack包内附带下载的工程模板：Reaper安装目录\ProjectTemplates\Rea_Wwise_Import_Manage.rpp）

注：若遇到导出.wav不明文件，确认该组items编组中，空白item时长范围是否覆盖其余items所占时长，若未覆盖，调整空白item时长范围即可
（常见修改资源后时长超出导致reaper渲染导出识别不到空白item的$itemnotes情况）

**源：主控混音**

**范围：所有工程区域**

**目录：\Mixdown**

**文件名：$itemnotes**

<img src="https://raw.githubusercontent.com/XFeng111/ReaperScripts/main/user-attachments/ReaWwise_Import_Manage%20工具使用说明/工程设置.png" alt="工程设置" style="width:50%;height:auto;">

<a href="https://www.bilibili.com/video/BV1mbdtBaEhM/" title="点击跳转视频">
<img src="https://raw.githubusercontent.com/XFeng111/ReaperScripts/main/user-attachments/ReaWwise_Import_Manage%20%E5%B7%A5%E5%85%B7%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E/%E5%AF%BC%E5%87%BA%E8%AE%BE%E7%BD%AE.gif" alt="" style="width:100%;height:auto;">
</a>

---

# 使用方式说明
**" ? " < -- 哪里不会点哪里**

## Wwise回流Reaper修改导回
修改资源后items一定要重新编组！！

<a href="https://www.bilibili.com/video/BV1mbdtBaEyt/" title="点击跳转视频">
<img src="https://raw.githubusercontent.com/XFeng111/ReaperScripts/main/user-attachments/ReaWwise_Import_Manage%20%E5%B7%A5%E5%85%B7%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E/Wwise%E5%9B%9E%E6%B5%81Reaper%E4%BF%AE%E6%94%B9%E5%AF%BC%E5%9B%9E.gif" alt="" style="width:100%;height:auto;">
</a>

## 新进资源多Originals路径导入Wwise

<a href="https://www.bilibili.com/video/BV12hdtBcE6o/" title="点击跳转视频">
<img src="https://raw.githubusercontent.com/XFeng111/ReaperScripts/main/user-attachments/ReaWwise_Import_Manage%20%E5%B7%A5%E5%85%B7%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E/%E6%96%B0%E8%BF%9B%E8%B5%84%E6%BA%90%E5%A4%9AOriginals%E8%B7%AF%E5%BE%84%E5%AF%BC%E5%85%A5Wwise.gif" alt="" style="width:100%;height:auto;">
</a>

使用步骤：

  a. 在Wwise中先选中该批资源目标导入的"Actor-Mixer"下，可通过【Wwise对象检测】选项识别当前选中Wwise对象信息。（后续若需修改导入路径可通过【设置WwisePath】选项）

  b. 设置导入语言：SFX-音效（默认），CN-中文语音，EN-英文语音

  c. 设置多样本包装的容器类型，默认RandomContainer，若Wwise目标Actor路径下没有多样本对应导入容器，Wwise下会同步创建

  d. 设置子文件夹路径：参照示例输入 "Wwise的Originals路径\SFX\" 后的内容即可，如图示

  e. 设置完成后，框选时间选区，覆盖需创建的items，点击创建导入结构，创建完成后检查父子轨道名称无误即可

> **【轨道层级必需的三层嵌套轨道结构】**\
[有时候可能有四层，最上层一般只是做一个层级归类的作用，不参与实际导回代码逻辑]
> > [类型标记]ActorMixer路径
> > > [sou]Sound对象
> > > > [o]Originals路径

【特殊情况注意】
如果存在多个父子轨嵌套结构，这个第四层可能会是某些父子轨的第三层参与实际导回代码逻辑，保险起见不建议修改由脚本创建的轨道结构及其命名（重定向父轨道除外）

<img src="https://raw.githubusercontent.com/XFeng111/ReaperScripts/main/user-attachments/ReaWwise_Import_Manage%20工具使用说明/轨道层级示例.png" alt="工程设置" style="width:80%;height:auto;">


## 补充：设置父轨道路径

<a href="https://www.bilibili.com/video/BV1MbdtBYEAS/" title="点击跳转视频">
<img src="https://raw.githubusercontent.com/XFeng111/ReaperScripts/main/user-attachments/ReaWwise_Import_Manage%20%E5%B7%A5%E5%85%B7%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E/%E8%AE%BE%E7%BD%AE%E7%88%B6%E8%BD%A8%E9%81%93%E8%B7%AF%E5%BE%84.gif" alt="" style="width:100%;height:auto;">
</a>

## 导入同步创建Play_Event
多样本容器，若未通过【创建Reaper结构】同步Wwise目标路径创建对应容器，需要手动创建，否则会导入失败。

### 默认Events下

<a href="https://www.bilibili.com/video/BV1mbdtBaE4t/" title="点击跳转视频">
<img src="https://raw.githubusercontent.com/XFeng111/ReaperScripts/main/user-attachments/ReaWwise_Import_Manage%20%E5%B7%A5%E5%85%B7%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E/%E9%BB%98%E8%AE%A4Events%E4%B8%8B.gif" alt="" style="width:100%;height:auto;">
</a>

### 使用旧有资源

<a href="https://www.bilibili.com/video/BV12hdtBcEas/" title="点击跳转视频">
<img src="https://raw.githubusercontent.com/XFeng111/ReaperScripts/main/user-attachments/ReaWwise_Import_Manage%20%E5%B7%A5%E5%85%B7%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E/%E4%BD%BF%E7%94%A8%E6%97%A7%E6%9C%89%E8%B5%84%E6%BA%90.gif" alt="" style="width:100%;height:auto;">
</a>

### 使用ActorMixer结构

<a href="https://www.bilibili.com/video/BV1mbdtBaELR/" title="点击跳转视频">
<img src="https://raw.githubusercontent.com/XFeng111/ReaperScripts/main/user-attachments/ReaWwise_Import_Manage%20%E5%B7%A5%E5%85%B7%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E/%E4%BD%BF%E7%94%A8ActorMixer%E7%BB%93%E6%9E%84.gif" alt="" style="width:100%;height:auto;">
</a>

### 使用特殊规则指定路径
仅符合特定规则的目标路径指派会被替换，其余按原有选择的导入方式

<a href="https://www.bilibili.com/video/BV1KhdtBwEQJ/" title="点击跳转视频">
<img src="https://raw.githubusercontent.com/XFeng111/ReaperScripts/main/user-attachments/ReaWwise_Import_Manage%20%E5%B7%A5%E5%85%B7%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E/%E4%BD%BF%E7%94%A8%E7%89%B9%E6%AE%8A%E8%A7%84%E5%88%99%E6%8C%87%E5%AE%9A%E8%B7%AF%E5%BE%84.gif" alt="" style="width:100%;height:auto;">
</a>

### 补充：Sound单位创建Event

<a href="https://www.bilibili.com/video/BV12hdtBcESK/" title="点击跳转视频">
<img src="https://raw.githubusercontent.com/XFeng111/ReaperScripts/main/user-attachments/ReaWwise_Import_Manage%20%E5%B7%A5%E5%85%B7%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E/Sound%E5%8D%95%E4%BD%8D%E5%88%9B%E5%BB%BAEvent.gif" alt="" style="width:100%;height:auto;">
</a>

## 导入同步创建Play_Event 和Stop_Event
### 全部创建Stop

<a href="https://www.bilibili.com/video/BV1mbdtBaE4J/" title="点击跳转视频">
<img src="https://raw.githubusercontent.com/XFeng111/ReaperScripts/main/user-attachments/ReaWwise_Import_Manage%20%E5%B7%A5%E5%85%B7%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E/%E5%85%A8%E9%83%A8%E5%88%9B%E5%BB%BAStop.gif" alt="" style="width:100%;height:auto;">
</a>

### 符合特定规则名称的创建Stop

<a href="https://www.bilibili.com/video/BV12bdtBaErn/" title="点击跳转视频">
<img src="https://raw.githubusercontent.com/XFeng111/ReaperScripts/main/user-attachments/ReaWwise_Import_Manage%20%E5%B7%A5%E5%85%B7%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E/%E7%AC%A6%E5%90%88%E7%89%B9%E5%AE%9A%E8%A7%84%E5%88%99%E5%90%8D%E7%A7%B0%E7%9A%84%E5%88%9B%E5%BB%BAStop.gif" alt="" style="width:100%;height:auto;">
</a>

---

# 常见Bug及其解决方式
## GUI界面突然卡死
删除Reaper安装目录下的ReaImGui整个文件夹后重启脚本\
路径：[Reaper安装目录]\ReaImGui\
原因：ReaImGui自身问题，不明原因Bug

## local dir 报错
检查reaper工程是否有保存到一个文件夹目录（不能是为保存到本地的临时工程）\
原因：工具找不到reaper工程路径导致报错

## AK_Func 报错
> 错误:.../module/AK_Funclua:9: attempt to call a nil value (field 'AK_Waapi_Connect')

reapack重装最新版的ReaWwise

## 日志显示已执行导入Wwise，但Wwise资源没变
检查reaper导出设置是不是勾选了重名自动递增名称，取消勾选，每次手动选覆盖（暂未找到让它自动覆盖的方法），确保导出资源在 Mixdown 文件夹下，且wav名称正确\
原因：工具是按 "itemnotes" 的名称到当前reaper工程目录下的 \Mixdown 找 .wav文件，没找到对应名称的 .wav 资源当然导不进去

## 导入Wwise的ActorMixer路径错误
检查Reaper轨道层级结构，父子轨的第三层wwise对象路径指定是否正确，若不正确用 [设置WwisePath] 重新设置

---
# 欢迎投喂~

<a href="https://raw.githubusercontent.com/XFeng111/ReaperScripts/main/user-attachments/assets/%E6%AC%A2%E8%BF%8E%E6%8A%95%E5%96%82~.png" title="点击投喂">
<img src="https://raw.githubusercontent.com/XFeng111/ReaperScripts/main/user-attachments/assets/%E6%AC%A2%E8%BF%8E%E6%8A%95%E5%96%82~.png" alt="投喂" style="width:70%;height:auto;">
</a>

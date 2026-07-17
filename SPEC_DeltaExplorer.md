# DeltaExplorer 兼容规范 v1

## 目标
为 Delta Injector (https://deltaexploits.gg) 编写可执行的 Roblox Luau 脚本。

## 代码结构规范

### 绝对禁止
1. **禁止 `return (function(...)` 包装** — Delta 的 `loadstring()` 会自动做函数包装，脚本里不能再手动加。
2. **禁止 emoji（Unicode 表情符号）** — 不在字符串、注释、变量名中使用 emoji（🔍📊✕✅❌等）。只用 ASCII 字符。
3. **禁止 `task.delay()` 启动** — 初始化代码必须同步执行，不要用延迟。
4. **禁止 `coroutine.wrap()`** — 改用 `task.spawn()` 或直接 `pcall()`。
5. **禁止使用未定义的全局变量** — 所有变量必须是 `local` 或 `_G.xxx`。

### 必须遵守
1. **纯顶层代码** — 所有函数定义和启动代码必须写在文件最顶层，没有外层函数包装。
2. **GUI 挂载必须容错** — 尝试以下顺序：
   - `pcall(function() gui.Parent = game:GetService("CoreGui") end)`
   - 如果失败，用 `Players.LocalPlayer:FindFirstChild("PlayerGui")`
   - 如果还失败，显示 StarterGui 通知然后 return
3. **所有 `game:GetService` 调用**必须用 `pcall` 包裹。
4. **文件大小控制在 300 行以内** — 功能精简，小文件更稳定。
5. **所有 Instance 创建** — 必须用 `Instance.new("ClassName")`，不要用 `Instance.new` 的缩写。

### UI 规范
1. 窗口尺寸：最大 400x500
2. 背景色：Color3.fromRGB(20, 20, 28)
3. 标题栏：深灰底色，金色/黄色文字
4. 关闭按钮：红底 X 文字
5. 标签按钮：深色底色，不同色调区分功能
6. 所有按钮带 `UICorner`（圆角 6-8）
7. 拖拽：用 InputBegan/InputChanged/InputEnded 事件实现
8. **不要用 TweenService** — 可能导致不可预知的挂起

### 通知系统
1. 首选用 `StarterGui:SetCore("SendNotification", {...})` 做简单通知
2. 可选 `_G.DENotifySystem`（仅当空间足够时，至少 150 行上限）
3. `_G.DENotifySystem.SetupContainer()` 必须在容器存在时才执行

## 启动流程（标准模板）

```lua
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")

-- 通知测试
pcall(function()
    StarterGui:SetCore("SendNotification", {Title="DeltaExplorer", Text="加载中", Duration=2})
end)

-- 等待 LocalPlayer
local lp = Players.LocalPlayer
if not lp then lp = Players:FindFirstChild("LocalPlayer") end
if not lp then return end

-- 查找 PlayerGui
local pg = lp:FindFirstChild("PlayerGui")
if not pg then return end

-- 挂载 GUI
local gui = Instance.new("ScreenGui")
gui.Name = "DeltaExplorerGUI"
gui.ResetOnSpawn = false

local success = pcall(function() gui.Parent = CoreGui end)
if not success then
    pcall(function() gui.Parent = pg end)
end

-- 确保有父级
if not gui.Parent then
    gui:Destroy()
    return
end

-- 然后构建 UI...
```

## 审核清单
代码交付后必须逐个检查：
- [ ] 无 `return (function(...)` 包装
- [ ] 无 emoji 字符
- [ ] 无 `task.delay` 在启动流程
- [ ] 无未 `pcall` 包裹的 `game:GetService`
- [ ] 所有变量有 `local` 或 `_G.` 前缀
- [ ] 文件不超过 300 行
- [ ] GUI 有容错挂载
- [ ] 关闭按钮能正确销毁 GUI

## 测试方法
1. 在 Delta 中直接粘贴执行
2. 观察是否有通知弹出
3. 观察 GUI 是否显示
4. 测试关闭按钮、拖拽、标签切换

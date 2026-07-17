--[[
DeltaExplorer v2 — 纯顶层代码 Roblox 游戏分析工具
GameId: 通用 (任何 Roblox 游戏)
功能:
  1. Instance 浏览器  — 树形浏览所有对象（分页、详情弹窗）
  2. 值扫描器        — 扫描 NumberValue/IntValue/BoolValue/StringValue
  3. Remote 发现     — 列出所有 RemoteEvent/RemoteFunction/UnreliableRemoteEvent
  4. 实时监控        — 选中值后实时监听 Changed 事件
  5. 元数据面板      — LocalPlayer 基本信息 + 角色信息 + FPS
  6. 对象搜索        — 按名称关键词搜索 Instance
  7. RSPY 数据包嗅探— Hook Remote 并记录 FireServer/InvokeServer/OnClientEvent 参数
依赖: 零外部依赖 (纯 Luau)
兼容: 标准 UNC 注入器 (Delta/Ninja/Synapse/Codex)
框架: 纯顶层代码 — 无 return(function(...) wrapper, 无 end)(...) 结尾
      所有函数/变量 local, 全局仅 _G.DENotify 系列
创建日期: 2026-07-17
版本: v2.0
--]]

-- =========================== SafeGetService ===========================
local FunctionServiceCache = {}
local function SafeGetService(serviceName)
    if FunctionServiceCache[serviceName] ~= nil then
        return FunctionServiceCache[serviceName]
    end
    local success, svc = pcall(function()
        return game:GetService(serviceName)
    end)
    if success then
        FunctionServiceCache[serviceName] = svc
        return svc
    end
    FunctionServiceCache[serviceName] = false
    return nil
end

local Players = SafeGetService("Players")
local Workspace = SafeGetService("Workspace")
local CoreGui = SafeGetService("CoreGui")
local UserInputService = SafeGetService("UserInputService")
local RunService = SafeGetService("RunService")
local ReplicatedStorage = SafeGetService("ReplicatedStorage")
local Lighting = SafeGetService("Lighting")
local TweenService = SafeGetService("TweenService")
local StarterGui = SafeGetService("StarterGui")
local HttpService = SafeGetService("HttpService")

-- =========================== 全局通知系统 (DENotify) ===========================
_G.DENotifySystem = {
    Queue = {},
    Ready = false,
    Container = nil,
    ActiveNotifications = {},
    MaxNotifications = 5,
    DefaultDuration = 4,
    TweenSpeed = 0.35,
    Theme = {
        Background = Color3.fromRGB(20, 20, 25),
        BackgroundAccent = Color3.fromRGB(28, 28, 35),
        Stroke = Color3.fromRGB(60, 60, 75),
        Title = Color3.fromRGB(255, 255, 255),
        Text = Color3.fromRGB(180, 180, 190),
        Success = Color3.fromRGB(80, 220, 120),
        Error = Color3.fromRGB(255, 90, 90),
        Warning = Color3.fromRGB(255, 190, 70),
        Info = Color3.fromRGB(88, 160, 255),
        ProgressBg = Color3.fromRGB(40, 40, 50)
    },
    Icons = {
        Success = "rbxassetid://93202927221730",
        Error = "rbxassetid://76821953846248",
        Warning = "rbxassetid://125920361880643",
        Info = "rbxassetid://124560466474914",
        Close = "rbxassetid://110786993356448",
    }
}

function _G.DENotify(title, text, duration, nType)
    duration = duration or _G.DENotifySystem.DefaultDuration
    title = title or "通知"
    text = text or ""
    nType = nType or "Info"
    if not _G.DENotifySystem.Ready then
        table.insert(_G.DENotifySystem.Queue, {title, text, duration, nType})
        return
    end
    pcall(function()
        _G.DENotifySystem.CreateNotification(title, text, duration, nType)
    end)
end

function _G.DENotifySuccess(title, text, duration)
    _G.DENotify(title, text, duration or 3, "Success")
end

function _G.DENotifyError(title, text, duration)
    _G.DENotify(title, text, duration or 5, "Error")
end

function _G.DENotifyWarning(title, text, duration)
    _G.DENotify(title, text, duration or 4, "Warning")
end

function _G.DENotifyInfo(title, text, duration)
    _G.DENotify(title, text, duration or 4, "Info")
end

-- =========================== NotifySystem 核心 ===========================
function _G.DENotifySystem.CreateNotification(title, text, duration, nType)
    local ts = TweenService
    if not ts then return end
    if not _G.DENotifySystem.Container or not _G.DENotifySystem.Container.Parent then
        _G.DENotifySystem.SetupContainer()
    end
    local container = _G.DENotifySystem.Container
    if not container then return end
    local theme = _G.DENotifySystem.Theme
    local typeColor = theme[nType] or theme.Info
    local iconId = _G.DENotifySystem.Icons[nType] or _G.DENotifySystem.Icons.Info
    while #_G.DENotifySystem.ActiveNotifications >= _G.DENotifySystem.MaxNotifications do
        local oldest = _G.DENotifySystem.ActiveNotifications[1]
        if oldest then oldest:Close() end
        task.wait(0.05)
    end
    local frame = Instance.new("Frame")
    frame.Name = "DENotification"
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Size = UDim2.new(0, 0, 0, 0)
    frame.ClipsDescendants = true
    local mainBg = Instance.new("Frame")
    mainBg.Name = "MainBg"
    mainBg.Size = UDim2.new(1, 0, 1, 0)
    mainBg.BackgroundColor3 = theme.Background
    mainBg.BackgroundTransparency = 0.02
    mainBg.BorderSizePixel = 0
    mainBg.Parent = frame
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 14)
    mainCorner.Parent = mainBg
    local stroke = Instance.new("UIStroke")
    stroke.Color = theme.Stroke
    stroke.Thickness = 1.2
    stroke.Transparency = 0.3
    stroke.Parent = mainBg
    local accentLine = Instance.new("Frame")
    accentLine.Name = "AccentLine"
    accentLine.Size = UDim2.new(0, 3, 1, -16)
    accentLine.Position = UDim2.new(0, 8, 0, 8)
    accentLine.BackgroundColor3 = typeColor
    accentLine.BorderSizePixel = 0
    accentLine.Parent = mainBg
    local accentCorner = Instance.new("UICorner")
    accentCorner.CornerRadius = UDim.new(1, 0)
    accentCorner.Parent = accentLine
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 20, 0, 20)
    icon.Position = UDim2.new(0, 20, 0, 12)
    icon.BackgroundTransparency = 1
    icon.Image = iconId
    icon.ImageColor3 = typeColor
    icon.Parent = mainBg
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -90, 0, 22)
    titleLabel.Position = UDim2.new(0, 46, 0, 11)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = theme.Title
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 15
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.Parent = mainBg
    local closeBtn = Instance.new("ImageButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(1, -30, 0, 10)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Image = _G.DENotifySystem.Icons.Close
    closeBtn.ImageColor3 = Color3.fromRGB(140, 140, 150)
    closeBtn.ImageTransparency = 0.3
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = mainBg
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "Content"
    textLabel.Size = UDim2.new(1, -66, 0, 0)
    textLabel.Position = UDim2.new(0, 46, 0, 36)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = text
    textLabel.TextColor3 = theme.Text
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = 13
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextWrapped = true
    textLabel.AutomaticSize = Enum.AutomaticSize.Y
    textLabel.Parent = mainBg
    local progressBg = Instance.new("Frame")
    progressBg.Name = "ProgressBg"
    progressBg.Size = UDim2.new(1, -16, 0, 3)
    progressBg.Position = UDim2.new(0, 8, 1, -9)
    progressBg.BackgroundColor3 = theme.ProgressBg
    progressBg.BorderSizePixel = 0
    progressBg.Parent = mainBg
    local progressCorner = Instance.new("UICorner")
    progressCorner.CornerRadius = UDim.new(1, 0)
    progressCorner.Parent = progressBg
    local progressBar = Instance.new("Frame")
    progressBar.Name = "ProgressBar"
    progressBar.Size = UDim2.new(1, 0, 1, 0)
    progressBar.BackgroundColor3 = typeColor
    progressBar.BorderSizePixel = 0
    progressBar.Parent = progressBg
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = progressBar
    frame.Parent = container
    task.wait()
    local textHeight = textLabel.TextBounds.Y
    local titleWidth = titleLabel.TextBounds.X
    local textWidth = textLabel.TextBounds.X
    local width = math.clamp(math.max(titleWidth + 100, textWidth + 70), 280, 400)
    local height = math.max(78, 52 + textHeight)
    local notification = {
        Frame = frame, MainBg = mainBg, ProgressBar = progressBar,
        Duration = duration, Remaining = duration, Paused = false, Closed = false,
        Close = function(self)
            if self.Closed then return end
            self.Closed = true
            self:AnimateOut()
        end,
        AnimateOut = function(self)
            for i, n in ipairs(_G.DENotifySystem.ActiveNotifications) do
                if n == self then table.remove(_G.DENotifySystem.ActiveNotifications, i) break end
            end
            if ts then
                ts:Create(self.MainBg, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    BackgroundTransparency = 1
                }):Play()
                ts:Create(self.Frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                    Size = UDim2.new(0, 0, 0, height),
                    Position = UDim2.new(0, 0, 0, self.Frame.AbsolutePosition.Y - container.AbsolutePosition.Y)
                }):Play()
            end
            task.delay(0.3, function() self.Frame:Destroy() end)
        end
    }
    table.insert(_G.DENotifySystem.ActiveNotifications, notification)
    frame.Size = UDim2.new(0, width, 0, 0)
    if ts then
        ts:Create(frame, TweenInfo.new(_G.DENotifySystem.TweenSpeed, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, width, 0, height)
        }):Play()
        ts:Create(mainBg, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 0.02
        }):Play()
    end
    closeBtn.MouseEnter:Connect(function()
        if ts then ts:Create(closeBtn, TweenInfo.new(0.15), {
            ImageTransparency = 0, ImageColor3 = Color3.fromRGB(255, 90, 90)
        }):Play() end
    end)
    closeBtn.MouseLeave:Connect(function()
        if ts then ts:Create(closeBtn, TweenInfo.new(0.15), {
            ImageTransparency = 0.3, ImageColor3 = Color3.fromRGB(140, 140, 150)
        }):Play() end
    end)
    closeBtn.MouseButton1Click:Connect(function() notification:Close() end)
    mainBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            notification.Paused = true
            if ts then ts:Create(mainBg, TweenInfo.new(0.2), {BackgroundColor3 = theme.BackgroundAccent}):Play() end
        end
    end)
    mainBg.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            notification.Paused = false
            if ts then ts:Create(mainBg, TweenInfo.new(0.2), {BackgroundColor3 = theme.Background}):Play() end
        end
    end)
    task.spawn(function()
        local startTime = tick()
        while notification.Remaining > 0 and not notification.Closed do
            if not notification.Paused then
                notification.Remaining = duration - (tick() - startTime)
                local progress = math.clamp(notification.Remaining / duration, 0, 1)
                progressBar.Size = UDim2.new(progress, 0, 1, 0)
            else
                startTime = tick() - (duration - notification.Remaining)
            end
            task.wait(0.03)
        end
        if not notification.Closed then notification:Close() end
    end)
end

function _G.DENotifySystem.SetupContainer()
    local coreGui = CoreGui
    local players = Players
    local gui = Instance.new("ScreenGui")
    gui.Name = "DENotifyGUI_" .. math.random(10000, 99999)
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 99999
    if coreGui then
        pcall(function() gui.Parent = coreGui end)
    end
    if not gui.Parent and players and players.LocalPlayer then
        pcall(function() gui.Parent = players.LocalPlayer:WaitForChild("PlayerGui") end)
    end
    if not gui.Parent then return end
    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(0, 420, 1, -30)
    container.Position = UDim2.new(1, -15, 0, 15)
    container.AnchorPoint = Vector2.new(1, 0)
    container.BackgroundTransparency = 1
    container.Parent = gui
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.Padding = UDim.new(0, 12)
    layout.Parent = container
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 15)
    padding.PaddingRight = UDim.new(0, 15)
    padding.Parent = container
    _G.DENotifySystem.Container = container
    _G.DENotifySystem.Ready = true
    _G.DENotifySystem.ProcessQueue()
end

function _G.DENotifySystem.ProcessQueue()
    if #_G.DENotifySystem.Queue == 0 then return end
    local queue = table.clone(_G.DENotifySystem.Queue)
    _G.DENotifySystem.Queue = {}
    for i, data in ipairs(queue) do
        task.delay((i-1) * 0.15, function()
            _G.DENotify(unpack(data))
        end)
    end
end

-- =========================== 常量 ===========================
local VERSION = "v2.0"
local APP_NAME = "DeltaExplorer " .. VERSION
local MAX_LIST_ITEMS = 30
local SCAN_DEPTH_LIMIT = 20
local MONITOR_INTERVAL = 0.5
local REMOTE_SCAN_DEPTH = 12

-- =========================== 全局状态变量 ===========================
local monitorConnections = {}
local browserPage = 1
local searchResults = {}
local scanResults = {}
local remoteList = {}
local selectedMonitorPath = nil
local monitorLogs = {}
local monitoredValue = nil
local monitorRunning = false
local rspyRunning = false
local rspyRecords = {}
local rspyHooks = {}
local MAX_RSPY_RECORDS = 500
local rspyBatchId = 0
local rspyRefreshNeeded = false
local rspyRefreshConn = nil

local DE_BrowserRoot = nil
local DE_InfoPopup = nil
local DE_GUI = nil
local DE_MainUI = nil

-- =========================== 工具函数 ===========================
local function GetTimestamp()
    local now = DateTime.now()
    local h, m, s = now:Hour(), now:Minute(), now:Second()
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function SplitString(str, sep)
    local parts = {}
    if sep == "" then return parts end
    local pattern = string.format("([^%s]+)", sep)
    for part in string.gmatch(str, pattern) do
        table.insert(parts, part)
    end
    return parts
end

-- =========================== UI 工具函数 ===========================
local function MakeFrame(parent, size, pos, color, transparent)
    local f = Instance.new("Frame")
    f.Size = size or UDim2.new(0, 100, 0, 100)
    f.Position = pos or UDim2.new(0, 0, 0, 0)
    f.BackgroundColor3 = color or Color3.fromRGB(30, 30, 30)
    f.BackgroundTransparency = transparent or 0
    f.BorderSizePixel = 0
    f.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = f
    return f
end

local function MakeLabel(parent, text, size, pos, color, textSize, align)
    local l = Instance.new("TextLabel")
    l.Size = size or UDim2.new(0, 100, 0, 20)
    l.Position = pos or UDim2.new(0, 0, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = text or ""
    l.TextColor3 = color or Color3.fromRGB(220, 220, 220)
    l.TextSize = textSize or 14
    l.Font = Enum.Font.SourceSans
    l.TextXAlignment = align or Enum.TextXAlignment.Left
    l.TextWrapped = true
    l.Parent = parent
    return l
end

local function MakeButton(parent, text, size, pos, color, callback)
    local b = Instance.new("TextButton")
    b.Size = size or UDim2.new(0, 100, 0, 44)
    b.Position = pos or UDim2.new(0, 0, 0, 0)
    b.BackgroundColor3 = color or Color3.fromRGB(60, 60, 60)
    b.Text = text or "Button"
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 14
    b.Font = Enum.Font.SourceSansBold
    b.BorderSizePixel = 0
    b.AutoButtonColor = true
    b.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = b
    if callback then
        b.MouseButton1Click:Connect(callback)
    end
    return b
end

local function MakeTextBox(parent, placeholder, size, pos, callback)
    local tb = Instance.new("TextBox")
    tb.Size = size or UDim2.new(0, 100, 0, 38)
    tb.Position = pos or UDim2.new(0, 0, 0, 0)
    tb.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    tb.Text = ""
    tb.PlaceholderText = placeholder or ""
    tb.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
    tb.TextColor3 = Color3.fromRGB(220, 220, 220)
    tb.TextSize = 14
    tb.Font = Enum.Font.SourceSans
    tb.BorderSizePixel = 0
    tb.ClearTextOnFocus = false
    tb.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = tb
    if callback then
        tb.FocusLost:Connect(function(enter)
            if enter then callback(tb.Text) end
        end)
    end
    return tb
end

local function MakeScrollingFrame(parent, size, pos)
    local sf = Instance.new("ScrollingFrame")
    sf.Size = size or UDim2.new(1, 0, 1, 0)
    sf.Position = pos or UDim2.new(0, 0, 0, 0)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 6
    sf.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.None
    sf.Parent = parent
    local ui = Instance.new("UIListLayout")
    ui.SortOrder = Enum.SortOrder.LayoutOrder
    ui.Padding = UDim.new(0, 2)
    ui.Parent = sf
    return sf
end

local function MakeDivider(parent, pos, sizeOrWidth)
    local d = Instance.new("Frame")
    if typeof(sizeOrWidth) == "UDim2" then
        d.Size = sizeOrWidth
    else
        d.Size = UDim2.new(0, sizeOrWidth or 1, 0, 1)
    end
    d.Position = pos or UDim2.new(0, 0, 0, 0)
    d.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    d.BorderSizePixel = 0
    d.Parent = parent
    return d
end

local function ClearScrollFrame(sf)
    for _, v in ipairs(sf:GetChildren()) do
        if v:IsA("GuiObject") then
            v:Destroy()
        end
    end
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
end

-- =========================== 核心扫描函数 ===========================
local function GetAllChildren(root, depth, maxDepth, filterClasses)
    depth = depth or 0
    if depth > maxDepth then return {} end
    local results = {}
    local success, children = pcall(function() return root:GetChildren() end)
    if not success then return results end
    for _, child in ipairs(children) do
        local ok, clsName = pcall(function() return child.ClassName end)
        if ok then
            if not filterClasses or #filterClasses == 0 then
                table.insert(results, child)
            else
                for _, fc in ipairs(filterClasses) do
                    if clsName == fc then
                        table.insert(results, child)
                        break
                    end
                end
            end
        end
        local sub = GetAllChildren(child, depth + 1, maxDepth, filterClasses)
        for _, s in ipairs(sub) do
            table.insert(results, s)
        end
    end
    return results
end

local function SearchInstances(root, keyword, depth, maxDepth)
    depth = depth or 0
    if depth > maxDepth then return {} end
    local results = {}
    local kwLower = keyword:lower()
    local success, children = pcall(function() return root:GetChildren() end)
    if not success then return results end
    for _, child in ipairs(children) do
        local ok, name = pcall(function() return child.Name end)
        if ok then
            if name:lower():find(kwLower, 1, true) then
                table.insert(results, child)
            end
        end
        local sub = SearchInstances(child, keyword, depth + 1, maxDepth)
        for _, s in ipairs(sub) do
            table.insert(results, s)
        end
    end
    return results
end

local function GetInstanceSummary(inst)
    local info = {}
    info.Name = inst.Name
    info.ClassName = inst.ClassName
    local parentOk, parentName = pcall(function() return inst.Parent.Name end)
    info.Parent = parentOk and parentName or "N/A"
    local ok, path = pcall(function()
        local parts = {}
        local p = inst
        while p do
            table.insert(parts, 1, p.Name)
            p = p.Parent
        end
        return table.concat(parts, "/")
    end)
    info.FullPath = ok and path or inst.Name
    info.Properties = {}
    local propList = {"Value", "MaxValue", "MinValue", "Enabled", "Visible",
                       "Transparency", "Size", "Position", "Color",
                       "TeamColor", "Health", "MaxHealth", "WalkSpeed",
                       "JumpPower", "Speed"}
    for _, prop in ipairs(propList) do
        local ok2, val = pcall(function() return inst[prop] end)
        if ok2 and val ~= nil then
            if type(val) == "userdata" then
                info.Properties[prop] = tostring(val)
            elseif type(val) == "number" then
                info.Properties[prop] = string.format("%.2f", val)
            else
                info.Properties[prop] = tostring(val)
            end
        end
    end
    local attrsOk, attrs = pcall(function() return inst:GetAttributes() end)
    if attrsOk and attrs then
        info.Attributes = {}
        for k, v in pairs(attrs) do
            info.Attributes[k] = tostring(v)
        end
    end
    info.ChildCount = #inst:GetChildren()
    return info
end

-- =========================== 实例信息弹窗 ===========================
local function ShowInstanceInfo(inst)
    if DE_InfoPopup and DE_InfoPopup.Parent then
        DE_InfoPopup:Destroy()
        DE_InfoPopup = nil
    end
    local summary = GetInstanceSummary(inst)
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BorderSizePixel = 0
    if DE_MainUI then
        overlay.Parent = DE_MainUI
    else
        pcall(function() overlay.Parent = DE_GUI end)
    end
    DE_InfoPopup = overlay
    local popup = MakeFrame(overlay, UDim2.new(0, 340, 0, 420), UDim2.new(0.5, -170, 0.5, -210), Color3.fromRGB(25, 25, 35), 0)
    MakeLabel(popup, "🔍 " .. inst.Name, UDim2.new(1, -10, 0, 26), UDim2.new(0, 5, 0, 5), Color3.fromRGB(255, 200, 100), 18, Enum.TextXAlignment.Left)
    MakeButton(popup, "✕", UDim2.new(0, 30, 0, 26), UDim2.new(1, -36, 0, 5), Color3.fromRGB(80, 30, 30),
        function() overlay:Destroy() DE_InfoPopup = nil end)
    local scroll = MakeScrollingFrame(popup, UDim2.new(1, -10, 1, -40), UDim2.new(0, 5, 0, 36))
    local fields = {
        {"名称", summary.Name}, {"类名", summary.ClassName},
        {"父对象", summary.Parent}, {"完整路径", summary.FullPath},
        {"子对象数", tostring(summary.ChildCount)},
    }
    for _, f in ipairs(fields) do
        local row = MakeFrame(scroll, UDim2.new(1, -4, 0, 36), nil, Color3.fromRGB(35, 35, 45), 0)
        MakeLabel(row, f[1] .. ":", UDim2.new(0, 80, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(150, 150, 150), 13)
        MakeLabel(row, f[2], UDim2.new(1, -90, 1, 0), UDim2.new(0, 88, 0, 0), Color3.fromRGB(220, 220, 220), 13)
        MakeDivider(row, UDim2.new(0, 5, 1, 0), UDim2.new(1, -10, 0, 0))
    end
    if next(summary.Properties) then
        MakeLabel(scroll, "--- 属性 ---", UDim2.new(1, -4, 0, 22), nil, Color3.fromRGB(100, 200, 255), 14)
        for k, v in pairs(summary.Properties) do
            local row = MakeFrame(scroll, UDim2.new(1, -4, 0, 28), nil, Color3.fromRGB(35, 35, 45), 0)
            MakeLabel(row, k .. ":", UDim2.new(0, 100, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(150, 150, 180), 13)
            local valLabel = MakeLabel(row, v, UDim2.new(1, -110, 1, 0), UDim2.new(0, 108, 0, 0), Color3.fromRGB(200, 200, 200), 12)
            valLabel.TextTruncate = Enum.TextTruncate.AtEnd
        end
    end
    if summary.Attributes then
        MakeLabel(scroll, "--- Attributes ---", UDim2.new(1, -4, 0, 22), nil, Color3.fromRGB(100, 255, 200), 14)
        for k, v in pairs(summary.Attributes) do
            local row = MakeFrame(scroll, UDim2.new(1, -4, 0, 28), nil, Color3.fromRGB(35, 35, 45), 0)
            MakeLabel(row, k, UDim2.new(0, 100, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(150, 180, 150), 13)
            local valLabel = MakeLabel(row, v, UDim2.new(1, -110, 1, 0), UDim2.new(0, 108, 0, 0), Color3.fromRGB(200, 200, 200), 12)
            valLabel.TextTruncate = Enum.TextTruncate.AtEnd
        end
    end
    MakeLabel(scroll, "点击遮罩层关闭", UDim2.new(1, -4, 0, 22), nil, Color3.fromRGB(120, 120, 120), 12, Enum.TextXAlignment.Center)
    -- 监听按钮
    if inst:IsA("NumberValue") or inst:IsA("IntValue") or inst:IsA("StringValue") or inst:IsA("BoolValue") then
        MakeButton(scroll, "📊 监控此对象", UDim2.new(1, -4, 0, 34), nil, Color3.fromRGB(50, 60, 80),
            function()
                overlay:Destroy()
                DE_InfoPopup = nil
                selectedMonitorPath = summary.FullPath
                monitoredValue = inst
            end)
    end
end

-- =========================== Tab 1: Instance 浏览器 ===========================
local function BuildBrowserTree(container, root, page)
    ClearScrollFrame(container)
    local items = {}
    local success, children = pcall(function() return root:GetChildren() end)
    if not success then
        MakeLabel(container, "无法访问: " .. tostring(root), UDim2.new(1, -10, 0, 22), UDim2.new(0, 5, 0, 2), Color3.fromRGB(255, 100, 100), 14)
        return
    end
    for _, child in ipairs(children) do
        table.insert(items, child)
    end
    local totalPages = math.max(1, math.ceil(#items / MAX_LIST_ITEMS))
    page = math.min(page, totalPages)
    browserPage = page
    local startIdx = (page - 1) * MAX_LIST_ITEMS + 1
    local endIdx = math.min(startIdx + MAX_LIST_ITEMS - 1, #items)
    MakeLabel(container, "路径: " .. root.Name, UDim2.new(1, -10, 0, 22), UDim2.new(0, 5, 0, 2), Color3.fromRGB(100, 200, 255), 13)
    if totalPages > 1 then
        MakeLabel(container, string.format("第 %d/%d 页 (共 %d 项)", page, totalPages, #items),
            UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 24), Color3.fromRGB(180, 180, 180), 12)
    else
        MakeLabel(container, string.format("共 %d 个子对象", #items),
            UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 24), Color3.fromRGB(180, 180, 180), 12)
    end
    local pageY = 44
    if totalPages > 1 then
        local prevBtn = MakeButton(container, "◀ 上一页", UDim2.new(0, 80, 0, 28), UDim2.new(0, 5, 0, pageY), Color3.fromRGB(50, 50, 70),
            function()
                if browserPage > 1 then
                    BuildBrowserTree(container, DE_BrowserRoot or Workspace, browserPage - 1)
                end
            end)
        if page == 1 then prevBtn.BackgroundTransparency = 0.6 prevBtn.Active = false end
        MakeLabel(container, tostring(page) .. "/" .. tostring(totalPages), UDim2.new(0, 60, 0, 28), UDim2.new(0, 88, 0, pageY), Color3.fromRGB(200, 200, 200), 14, Enum.TextXAlignment.Center)
        local nextBtn = MakeButton(container, "下一页 ▶", UDim2.new(0, 80, 0, 28), UDim2.new(0, 150, 0, pageY), Color3.fromRGB(50, 50, 70),
            function()
                if browserPage < totalPages then
                    BuildBrowserTree(container, DE_BrowserRoot or Workspace, browserPage + 1)
                end
            end)
        if page == totalPages then nextBtn.BackgroundTransparency = 0.6 nextBtn.Active = false end
    end
    local buttonY = pageY + (totalPages > 1 and 34 or 0)
    if root ~= Workspace and root ~= Players and root ~= game then
        MakeButton(container, "⬆ 返回上级", UDim2.new(0, 100, 0, 28), UDim2.new(0, 5, 0, buttonY), Color3.fromRGB(60, 50, 50),
            function()
                local parentOk, parent = pcall(function() return root.Parent end)
                if parentOk and parent then
                    DE_BrowserRoot = parent
                    BuildBrowserTree(container, parent, 1)
                end
            end)
        buttonY = buttonY + 32
    end
    MakeButton(container, "🔄 刷新", UDim2.new(0, 80, 0, 28), UDim2.new(0, 110, 0, buttonY), Color3.fromRGB(50, 60, 50),
        function() BuildBrowserTree(container, DE_BrowserRoot or Workspace, 1) end)
    local listY = buttonY + 36
    local listFrame = MakeScrollingFrame(container, UDim2.new(1, -10, 1, -(listY + 10)), UDim2.new(0, 5, 0, listY))
    for i = startIdx, endIdx do
        local item = items[i]
        local itemFrame = MakeFrame(listFrame, UDim2.new(1, -4, 0, 30), nil, Color3.fromRGB(35, 35, 45), 0)
        local icon = "📄"
        local cls = item.ClassName
        if cls:find("Value") then icon = "🔢"
        elseif cls:find("Remote") then icon = "📡"
        elseif cls:find("Folder") or cls:find("Model") then icon = "📁"
        elseif cls:find("Player") then icon = "👤"
        elseif cls:find("Part") or cls:find("Mesh") then icon = "🧱"
        elseif cls:find("Script") then icon = "📜"
        elseif cls:find("Sound") then icon = "🔊"
        end
        local hasChildren = false
        local childOk, childCount = pcall(function() return #item:GetChildren() end)
        if childOk then hasChildren = childCount > 0 end
        local expander = hasChildren and " [+]" or "   "
        MakeLabel(itemFrame, icon .. " " .. item.Name .. "  (" .. cls .. ")" .. expander,
            UDim2.new(1, -5, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(200, 200, 200), 13)
        if hasChildren then
            itemFrame.BackgroundColor3 = Color3.fromRGB(35, 40, 50)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, 0, 1, 0)
            b.BackgroundTransparency = 1
            b.Text = ""
            b.Parent = itemFrame
            b.MouseButton1Click:Connect(function()
                DE_BrowserRoot = item
                BuildBrowserTree(container, item, 1)
            end)
        end
        local infoBtn = MakeButton(itemFrame, "ℹ", UDim2.new(0, 28, 0, 24), UDim2.new(1, -32, 0, 3), Color3.fromRGB(60, 60, 80),
            function() ShowInstanceInfo(item) end)
        infoBtn.TextSize = 16
    end
end

-- =========================== Tab 2: 值扫描器 ===========================
local function BuildValueScanner(container)
    ClearScrollFrame(container)
    MakeLabel(container, "值扫描器", UDim2.new(1, -10, 0, 24), UDim2.new(0, 5, 0, 4), Color3.fromRGB(255, 200, 100), 16)
    MakeLabel(container, "设置数值范围，扫描 NumberValue/IntValue 等实例", UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 28), Color3.fromRGB(160, 160, 160), 12)
    local minBox = MakeTextBox(container, "最小值 (如: 0)", UDim2.new(0, 120, 0, 36), UDim2.new(0, 5, 0, 52))
    local maxBox = MakeTextBox(container, "最大值 (如: 100)", UDim2.new(0, 120, 0, 36), UDim2.new(0, 130, 0, 52))
    local resultLabel = MakeLabel(container, "结果: 等待扫描", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 92), Color3.fromRGB(180, 180, 180), 13)
    local scanBtn = MakeButton(container, "🔍 开始扫描", UDim2.new(0, 140, 0, 36), UDim2.new(0, 5, 0, 114), Color3.fromRGB(50, 80, 50),
        function()
            local minVal = tonumber(minBox.Text)
            local maxVal = tonumber(maxBox.Text)
            if not minVal or not maxVal then
                resultLabel.Text = "错误: 请输入有效数字"
                return
            end
            if minVal > maxVal then minVal, maxVal = maxVal, minVal end
            resultLabel.Text = "扫描中..."
            task.delay(0.05, function()
                local results = {}
                local valueClasses = {"NumberValue", "IntValue", "DoubleConstrainedValue", "IntConstrainedValue"}
                for _, cls in ipairs(valueClasses) do
                    local found = GetAllChildren(Workspace, 0, SCAN_DEPTH_LIMIT, {cls})
                    for _, item in ipairs(found) do
                        local ok, val = pcall(function() return item.Value end)
                        if ok and type(val) == "number" and val >= minVal and val <= maxVal then
                            table.insert(results, {inst = item, val = val})
                        end
                    end
                    if Players then
                        local foundP = GetAllChildren(Players, 0, SCAN_DEPTH_LIMIT, {cls})
                        for _, item in ipairs(foundP) do
                            local ok, val = pcall(function() return item.Value end)
                            if ok and type(val) == "number" and val >= minVal and val <= maxVal then
                                table.insert(results, {inst = item, val = val})
                            end
                        end
                    end
                end
                resultLabel.Text = string.format("找到 %d 个匹配值", #results)
                local listY = 156
                local sf = MakeScrollingFrame(container, UDim2.new(1, -10, 1, -(listY + 10)), UDim2.new(0, 5, 0, listY))
                for _, r in ipairs(results) do
                    local row = MakeFrame(sf, UDim2.new(1, -4, 0, 28), nil, Color3.fromRGB(35, 35, 45), 0)
                    local path = ""
                    pcall(function()
                        local parts = {}
                        local p = r.inst
                        while p do table.insert(parts, 1, p.Name) p = p.Parent end
                        path = table.concat(parts, "/")
                    end)
                    MakeLabel(row, string.format("%.2f  |  %s", r.val, r.inst.ClassName .. ": " .. path),
                        UDim2.new(1, -5, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(180, 220, 180), 11)
                    MakeButton(row, "ℹ", UDim2.new(0, 24, 0, 22), UDim2.new(1, -28, 0, 3), Color3.fromRGB(60, 60, 80),
                        function() ShowInstanceInfo(r.inst) end):TextSize = 14
                end
            end)
        end)
    MakeButton(container, "清空结果", UDim2.new(0, 100, 0, 36), UDim2.new(0, 150, 0, 114), Color3.fromRGB(60, 40, 40),
        function()
            resultLabel.Text = "结果: 等待扫描"
            local sf = container:FindFirstChildOfClass("ScrollingFrame")
            while sf do sf:Destroy() sf = container:FindFirstChildOfClass("ScrollingFrame") end
        end)
end

-- =========================== Tab 3: Remote 发现 ===========================
local function BuildRemoteDiscovery(container)
    ClearScrollFrame(container)
    MakeLabel(container, "Remote 发现", UDim2.new(1, -10, 0, 24), UDim2.new(0, 5, 0, 4), Color3.fromRGB(100, 200, 255), 16)
    MakeLabel(container, "列出所有 RemoteEvent/RemoteFunction/UnreliableRemoteEvent", UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 28), Color3.fromRGB(160, 160, 160), 12)
    local resultLabel = MakeLabel(container, "未扫描", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 48), Color3.fromRGB(180, 180, 180), 13)
    MakeButton(container, "🔍 扫描 Remote", UDim2.new(0, 140, 0, 36), UDim2.new(0, 5, 0, 72), Color3.fromRGB(50, 50, 80),
        function()
            resultLabel.Text = "扫描中..."
            task.delay(0.05, function()
                local results = {}
                local remoteTypes = {"RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent"}
                local roots = {Workspace, Players, ReplicatedStorage, Lighting}
                if game then table.insert(roots, game) end
                for _, root in ipairs(roots) do
                    if root then
                        for _, rt in ipairs(remoteTypes) do
                            local found = GetAllChildren(root, 0, REMOTE_SCAN_DEPTH, {rt})
                            for _, item in ipairs(found) do
                                local path = ""
                                pcall(function()
                                    local parts = {}
                                    local p = item
                                    while p do table.insert(parts, 1, p.Name) p = p.Parent end
                                    path = table.concat(parts, "/")
                                end)
                                table.insert(results, {inst = item, path = path})
                            end
                        end
                    end
                end
                resultLabel.Text = string.format("找到 %d 个 Remote", #results)
                remoteList = results
                local listY = 114
                local sf = MakeScrollingFrame(container, UDim2.new(1, -10, 1, -(listY + 10)), UDim2.new(0, 5, 0, listY))
                for _, r in ipairs(results) do
                    local row = MakeFrame(sf, UDim2.new(1, -4, 0, 32), nil, Color3.fromRGB(35, 35, 45), 0)
                    local icon = r.inst.ClassName:find("Function") and "⚡" or "📡"
                    MakeLabel(row, icon .. " " .. r.inst.ClassName .. ": " .. r.inst.Name,
                        UDim2.new(1, -5, 0, 16), UDim2.new(0, 5, 0, 1), Color3.fromRGB(180, 200, 255), 13)
                    MakeLabel(row, r.path, UDim2.new(1, -5, 0, 14), UDim2.new(0, 5, 0, 17), Color3.fromRGB(140, 140, 160), 10)
                    MakeButton(row, "ℹ", UDim2.new(0, 24, 0, 22), UDim2.new(1, -28, 0, 5), Color3.fromRGB(60, 60, 80),
                        function() ShowInstanceInfo(r.inst) end):TextSize = 14
                end
            end)
        end)
end

-- =========================== Tab 4: 实时监控 ===========================
local function BuildMonitor(container)
    ClearScrollFrame(container)
    MakeLabel(container, "实时监控", UDim2.new(1, -10, 0, 24), UDim2.new(0, 5, 0, 4), Color3.fromRGB(200, 255, 200), 16)
    MakeLabel(container, "选中值对象后实时监听 Changed 事件", UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 28), Color3.fromRGB(160, 160, 160), 12)
    local pathBox = MakeTextBox(container, "路径 (如: Workspace.Part.NumberValue)", UDim2.new(1, -20, 0, 36), UDim2.new(0, 5, 0, 50))
    local statusLabel = MakeLabel(container, "监控状态: 未启动", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 90), Color3.fromRGB(180, 180, 180), 13)
    local monitorLog = MakeScrollingFrame(container, UDim2.new(1, -10, 1, -140), UDim2.new(0, 5, 0, 120))
    local logContainer = monitorLog
    MakeButton(container, "▶ 开始监控", UDim2.new(0, 120, 0, 34), UDim2.new(0, 5, 0, 96), Color3.fromRGB(50, 80, 50),
        function()
            if monitorRunning then return end
            local path = pathBox.Text
            if path ~= "" then
                statusLabel.Text = "正在解析路径: " .. path
                local target = nil
                local ok = pcall(function()
                    target = game
                    for _, part in ipairs(SplitString(path, "/")) do
                        if part ~= "" then target = target[part] end
                    end
                end)
                if ok and target then
                    monitoredValue = target
                    selectedMonitorPath = path
                end
            end
            if not monitoredValue then
                statusLabel.Text = "错误: 未选择/未找到对象"
                return
            end
            monitorRunning = true
            statusLabel.Text = "监控中: " .. (selectedMonitorPath or monitoredValue.Name) .. " (初始值: " .. tostring(pcall(function() return monitoredValue.Value end) and monitoredValue.Value or "N/A") .. ")"
            ClearScrollFrame(logContainer)
            -- 使用 Changed 事件监听
            local changedConn
            changedConn = monitoredValue.Changed:Connect(function(newVal)
                if not monitorRunning then
                    if changedConn then changedConn:Disconnect() end
                    return
                end
                local ts = GetTimestamp()
                local line = string.format("[%s] → %s", ts, tostring(newVal))
                local label = MakeLabel(logContainer, line, UDim2.new(1, -4, 0, 18), nil, Color3.fromRGB(180, 255, 180), 11)
            end)
            table.insert(monitorConnections, changedConn)
            -- 也显示当前值
            local valOk, curVal = pcall(function() return monitoredValue.Value end)
            if valOk then
                MakeLabel(logContainer, string.format("[%s] 初始值 = %s", GetTimestamp(), tostring(curVal)),
                    UDim2.new(1, -4, 0, 18), nil, Color3.fromRGB(100, 255, 100), 11)
            end
        end)
    MakeButton(container, "⏹ 停止监控", UDim2.new(0, 120, 0, 34), UDim2.new(0, 130, 0, 96), Color3.fromRGB(80, 40, 40),
        function()
            monitorRunning = false
            statusLabel.Text = "监控已停止"
            for _, c in ipairs(monitorConnections) do
                pcall(function() c:Disconnect() end)
            end
            monitorConnections = {}
        end)
    MakeButton(container, "清空日志", UDim2.new(0, 80, 0, 28), UDim2.new(0, 255, 0, 98), Color3.fromRGB(60, 50, 50),
        function() ClearScrollFrame(logContainer) end)
end

-- =========================== Tab 5: 元数据面板 ===========================
local function BuildMetadata(container)
    ClearScrollFrame(container)
    MakeLabel(container, "元数据面板", UDim2.new(1, -10, 0, 24), UDim2.new(0, 5, 0, 4), Color3.fromRGB(255, 200, 200), 16)
    local lp = Players and Players.LocalPlayer
    local yPos = 34
    if lp then
        local fields = {
            {"用户名", lp.Name}, {"显示名", lp.DisplayName},
            {"用户ID", tostring(lp.UserId)}, {"账号年龄", tostring(lp.AccountAge) .. " 天"},
            {"会员", lp.MembershipType == Enum.MembershipType.Premium and "Premium" or "免费"},
            {"Locale", lp.LocaleId},
        }
        for _, f in ipairs(fields) do
            local row = MakeFrame(container, UDim2.new(1, -10, 0, 30), UDim2.new(0, 5, 0, yPos), Color3.fromRGB(35, 35, 45), 0)
            MakeLabel(row, f[1] .. ":", UDim2.new(0, 80, 1, 0), UDim2.new(0, 8, 0, 0), Color3.fromRGB(150, 150, 150), 13)
            MakeLabel(row, f[2], UDim2.new(1, -100, 1, 0), UDim2.new(0, 92, 0, 0), Color3.fromRGB(220, 220, 220), 13)
            yPos = yPos + 33
        end
        -- 角色信息
        local char = lp.Character
        if char then
            MakeDivider(container, UDim2.new(0, 5, 0, yPos), UDim2.new(1, -10, 0, 1))
            yPos = yPos + 8
            MakeLabel(container, "角色信息", UDim2.new(1, -10, 0, 22), UDim2.new(0, 5, 0, yPos), Color3.fromRGB(100, 200, 255), 14)
            yPos = yPos + 24
            local hum = char:FindFirstChild("Humanoid")
            if hum then
                local humFields = {
                    {"血量", string.format("%.0f / %.0f", hum.Health, hum.MaxHealth)},
                    {"移速", string.format("%.1f", hum.WalkSpeed)},
                    {"跳跃", string.format("%.1f", hum.JumpPower or 50)},
                }
                for _, f in ipairs(humFields) do
                    local row = MakeFrame(container, UDim2.new(1, -10, 0, 26), UDim2.new(0, 5, 0, yPos), Color3.fromRGB(35, 40, 45), 0)
                    MakeLabel(row, f[1] .. ":", UDim2.new(0, 60, 1, 0), UDim2.new(0, 8, 0, 0), Color3.fromRGB(150, 150, 150), 12)
                    MakeLabel(row, f[2], UDim2.new(1, -80, 1, 0), UDim2.new(0, 72, 0, 0), Color3.fromRGB(220, 220, 220), 12)
                    yPos = yPos + 28
                end
            end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local pos = hrp.Position
                local row = MakeFrame(container, UDim2.new(1, -10, 0, 26), UDim2.new(0, 5, 0, yPos), Color3.fromRGB(35, 40, 45), 0)
                MakeLabel(row, "坐标:", UDim2.new(0, 60, 1, 0), UDim2.new(0, 8, 0, 0), Color3.fromRGB(150, 150, 150), 12)
                MakeLabel(row, string.format("(%.1f, %.1f, %.1f)", pos.X, pos.Y, pos.Z), UDim2.new(1, -80, 1, 0), UDim2.new(0, 72, 0, 0), Color3.fromRGB(220, 220, 220), 12)
                yPos = yPos + 28
            end
        end
    else
        MakeLabel(container, "LocalPlayer 不可用", UDim2.new(1, -10, 0, 24), UDim2.new(0, 5, 0, yPos), Color3.fromRGB(255, 100, 100), 14)
        yPos = yPos + 28
    end
    MakeDivider(container, UDim2.new(0, 5, 0, yPos), UDim2.new(1, -10, 0, 1))
    yPos = yPos + 8
    MakeLabel(container, "游戏信息", UDim2.new(1, -10, 0, 22), UDim2.new(0, 5, 0, yPos), Color3.fromRGB(200, 255, 200), 14)
    yPos = yPos + 24
    local gameFields = {
        {"PlaceId", tostring(game.PlaceId)}, {"GameId", tostring(game.GameId)},
        {"名称", game.Name}, {"FPS", "计算中..."},
    }
    for _, f in ipairs(gameFields) do
        local row = MakeFrame(container, UDim2.new(1, -10, 0, 28), UDim2.new(0, 5, 0, yPos), Color3.fromRGB(35, 35, 45), 0)
        MakeLabel(row, f[1] .. ":", UDim2.new(0, 80, 1, 0), UDim2.new(0, 8, 0, 0), Color3.fromRGB(150, 150, 150), 13)
        MakeLabel(row, f[2], UDim2.new(1, -100, 1, 0), UDim2.new(0, 92, 0, 0), Color3.fromRGB(220, 220, 220), 13)
        yPos = yPos + 31
    end
    if RunService then
        local fpsLabel = MakeLabel(container, "", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, yPos), Color3.fromRGB(100, 255, 100), 13)
        local lastTime = tick()
        local frameCount = 0
        local fpsConn = RunService.RenderStepped:Connect(function()
            frameCount = frameCount + 1
            local now = tick()
            if now - lastTime >= 1 then
                local fps = math.floor(frameCount / (now - lastTime))
                fpsLabel.Text = "实时 FPS: " .. tostring(fps)
                frameCount = 0
                lastTime = now
            end
        end)
        table.insert(monitorConnections, fpsConn)
    end
end

-- =========================== Tab 6: 对象搜索 ===========================
local function BuildSearch(container)
    ClearScrollFrame(container)
    MakeLabel(container, "对象搜索", UDim2.new(1, -10, 0, 24), UDim2.new(0, 5, 0, 4), Color3.fromRGB(255, 255, 200), 16)
    MakeLabel(container, "按名称关键词搜索 Instance", UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 28), Color3.fromRGB(160, 160, 160), 12)
    local searchBox = MakeTextBox(container, "关键词", UDim2.new(1, -130, 0, 36), UDim2.new(0, 5, 0, 50))
    local resultLabel = MakeLabel(container, "等待搜索", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 90), Color3.fromRGB(180, 180, 180), 13)
    MakeButton(container, "🔍 搜索", UDim2.new(0, 100, 0, 36), UDim2.new(1, -110, 0, 50), Color3.fromRGB(50, 50, 75),
        function()
            local kw = searchBox.Text
            if kw == "" then return end
            resultLabel.Text = "搜索中..."
            task.delay(0.05, function()
                local results = {}
                local roots = {Workspace, Players, ReplicatedStorage, Lighting}
                if game then table.insert(roots, game) end
                for _, root in ipairs(roots) do
                    if root then
                        local found = SearchInstances(root, kw, 0, SCAN_DEPTH_LIMIT)
                        for _, item in ipairs(found) do
                            table.insert(results, item)
                        end
                    end
                end
                resultLabel.Text = string.format("找到 %d 个结果", #results)
                local listY = 114
                local sf = MakeScrollingFrame(container, UDim2.new(1, -10, 1, -(listY + 10)), UDim2.new(0, 5, 0, listY))
                for _, item in ipairs(results) do
                    local row = MakeFrame(sf, UDim2.new(1, -4, 0, 26), nil, Color3.fromRGB(35, 35, 45), 0)
                    local path = ""
                    pcall(function()
                        local parts = {}
                        local p = item
                        while p do table.insert(parts, 1, p.Name) p = p.Parent end
                        path = table.concat(parts, "/")
                    end)
                    MakeLabel(row, item.ClassName .. ": " .. path,
                        UDim2.new(1, -5, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(200, 200, 220), 11)
                    local infoBtn2 = MakeButton(row, "ℹ", UDim2.new(0, 24, 0, 22), UDim2.new(1, -28, 0, 2), Color3.fromRGB(60, 60, 80),
                        function() ShowInstanceInfo(item) end)
                    infoBtn2.TextSize = 14
                end
            end)
        end)
    MakeButton(container, "清空", UDim2.new(0, 80, 0, 36), UDim2.new(1, -110, 0, 90), Color3.fromRGB(60, 40, 40),
        function()
            resultLabel.Text = "等待搜索"
            local sf = container:FindFirstChildOfClass("ScrollingFrame")
            while sf do sf:Destroy() sf = container:FindFirstChildOfClass("ScrollingFrame") end
        end)
end

-- =========================== Tab 7: RSPY 数据包嗅探 ===========================
local function RSPY_Serialize(val, depth)
    depth = depth or 0
    if depth > 4 then return "..." end
    local vt = type(val)
    if vt == "number" then return tostring(val)
    elseif vt == "string" then return string.format("%q", val)
    elseif vt == "boolean" then return tostring(val)
    elseif vt == "nil" then return "nil"
    elseif vt == "table" then
        local parts = {}
        local count = 0
        for k, v in pairs(val) do
            count = count + 1
            if count <= 16 then
                local ks = type(k) == "number" and "[" .. tostring(k) .. "]" or RSPY_Serialize(k, depth + 1)
                local vs = RSPY_Serialize(v, depth + 1)
                table.insert(parts, ks .. "=" .. vs)
            end
        end
        if count > 16 then table.insert(parts, "...") end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        local okName, name = pcall(function() return val.Name end)
        if okName then return "[Instance:" .. name .. "]" end
        local okCls, cls = pcall(function() return val.ClassName end)
        if okCls then return "[" .. cls .. "]" end
        return tostring(val)
    end
end

local function RSPY_GetPath(inst)
    local ok, path = pcall(function()
        local parts = {}
        local p = inst
        while p do
            table.insert(parts, 1, p.Name)
            p = p.Parent
        end
        return table.concat(parts, "/")
    end)
    return ok and path or inst.Name
end

local function CopyToClipboard(text)
    local ok = false
    if setclipboard then ok = pcall(setclipboard, text) end
    if not ok and toclipboard then ok = pcall(toclipboard, text) end
    if not ok then pcall(function() print("[RSPY 复制] " .. text) end) end
end

local function BuildRSPY(container)
    ClearScrollFrame(container)
    MakeLabel(container, "RSPY 数据包嗅探", UDim2.new(1, -10, 0, 24), UDim2.new(0, 5, 0, 4), Color3.fromRGB(255, 150, 255), 16)
    MakeLabel(container, "Hook Remote 并记录 FireServer/InvokeServer/OnClientEvent", UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 28), Color3.fromRGB(160, 160, 160), 12)
    local statusLabel = MakeLabel(container, "状态: 未启动", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 48), Color3.fromRGB(180, 180, 180), 13)
    local countLabel = MakeLabel(container, "记录: 0", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 68), Color3.fromRGB(180, 180, 180), 13)
    local listY = 94
    local sf = MakeScrollingFrame(container, UDim2.new(1, -10, 1, -(listY + 10)), UDim2.new(0, 5, 0, listY))
    local function RefreshRSPYDisplay()
        ClearScrollFrame(sf)
        if #rspyRecords == 0 then
            MakeLabel(sf, "暂无记录，点击开始嗅探后操作游戏", UDim2.new(1, -10, 0, 30), nil, Color3.fromRGB(150, 150, 150), 14, Enum.TextXAlignment.Center)
            return
        end
        local startIdx = math.max(1, #rspyRecords - 199)
        for i = startIdx, #rspyRecords do
            local rec = rspyRecords[i]
            local isCS = rec.direction == "C→S"
            local rowHeight = 58
            local row = MakeFrame(sf, UDim2.new(1, -4, 0, rowHeight), nil, Color3.fromRGB(30, 30, 40), 0)
            local badgeColor = isCS and Color3.fromRGB(200, 120, 50) or Color3.fromRGB(50, 120, 200)
            local badge = MakeLabel(row, rec.direction, UDim2.new(0, 42, 0, 16), UDim2.new(0, 4, 0, 4), badgeColor, 10, Enum.TextXAlignment.Center)
            badge.BackgroundTransparency = 0.3
            badge.BackgroundColor3 = badgeColor
            local nameLabel = MakeLabel(row, rec.remoteName .. " (" .. rec.remoteClass .. ")", UDim2.new(0, math.min((#rec.remoteName + #rec.remoteClass + 3) * 7 + 10, 180), 0, 18), UDim2.new(0, 52, 0, 3), Color3.fromRGB(220, 220, 255), 13)
            local pathLabel = MakeLabel(row, rec.path, UDim2.new(0, math.min(#rec.path * 6 + 10, 200), 0, 14), UDim2.new(0, 52, 0, 20), Color3.fromRGB(120, 120, 120), 10)
            local timeLbl = MakeLabel(row, "[" .. rec.time .. "]", UDim2.new(0, 70, 0, 14), UDim2.new(0, 4, 0, 38), Color3.fromRGB(150, 150, 150), 10)
            local paramStr = rec.argsStr or "(无参数)"
            if #paramStr > 40 then paramStr = string.sub(paramStr, 1, 40) .. "..." end
            MakeLabel(row, "参数: " .. paramStr, UDim2.new(1, -80, 0, 14), UDim2.new(0, 52, 0, 38), Color3.fromRGB(180, 200, 180), 10)
            MakeButton(row, "📋", UDim2.new(0, 28, 0, 24), UDim2.new(1, -32, 0, 2), Color3.fromRGB(60, 60, 80),
                function()
                    local copyText = string.format("[%s] %s\n路径: %s\n参数: %s", rec.time, rec.direction .. " " .. rec.remoteName, rec.path, rec.argsStr)
                    CopyToClipboard(copyText)
                end)
        end
    end
    local function HookAllRemotes()
        for _, hook in ipairs(rspyHooks) do
            if hook.conn then pcall(function() hook.conn:Disconnect() end) end
        end
        rspyHooks = {}
        local hookCount = 0
        local remoteTypes = {"RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent"}
        local roots = {Workspace, Players, ReplicatedStorage, Lighting, game}
        local scanned = {}
        for _, root in ipairs(roots) do
            if root then
                local remotes = GetAllChildren(root, 0, REMOTE_SCAN_DEPTH, remoteTypes)
                for _, remote in ipairs(remotes) do
                    local path = RSPY_GetPath(remote)
                    if scanned[path] then break end
                    scanned[path] = true
                    if remote.ClassName == "RemoteEvent" or remote.ClassName == "UnreliableRemoteEvent" then
                        local origFire = remote.FireServer
                        if origFire then
                            remote.FireServer = function(self, ...)
                                local args = {...}
                                local record = {
                                    time = GetTimestamp(), remoteName = remote.Name,
                                    remoteClass = remote.ClassName, path = path,
                                    direction = "C→S", args = args,
                                    argsStr = RSPY_Serialize(args, 0), batchId = rspyBatchId,
                                }
                                rspyBatchId = rspyBatchId + 1
                                table.insert(rspyRecords, record)
                                if #rspyRecords > MAX_RSPY_RECORDS then table.remove(rspyRecords, 1) end
                                rspyRefreshNeeded = true
                                countLabel.Text = string.format("记录: %d (批次: %d)", #rspyRecords, rspyBatchId)
                                return origFire(self, ...)
                            end
                            table.insert(rspyHooks, {remote = remote, type = "FireServer"})
                            hookCount = hookCount + 1
                        end
                        local conn
                        conn = remote.OnClientEvent:Connect(function(...)
                            if not rspyRunning then if conn then conn:Disconnect() end return end
                            local args = {...}
                            local record = {
                                time = GetTimestamp(), remoteName = remote.Name,
                                remoteClass = remote.ClassName, path = path,
                                direction = "S→C", args = args,
                                argsStr = RSPY_Serialize(args, 0), batchId = rspyBatchId,
                            }
                            rspyBatchId = rspyBatchId + 1
                            table.insert(rspyRecords, record)
                            if #rspyRecords > MAX_RSPY_RECORDS then table.remove(rspyRecords, 1) end
                            rspyRefreshNeeded = true
                            countLabel.Text = string.format("记录: %d (批次: %d)", #rspyRecords, rspyBatchId)
                        end)
                        table.insert(rspyHooks, {remote = remote, conn = conn})
                        hookCount = hookCount + 1
                    end
                    if remote.ClassName == "RemoteFunction" then
                        local origInvoke = remote.InvokeServer
                        if origInvoke then
                            remote.InvokeServer = function(self, ...)
                                local args = {...}
                                local record = {
                                    time = GetTimestamp(), remoteName = remote.Name,
                                    remoteClass = remote.ClassName, path = path,
                                    direction = "C→S", args = args,
                                    argsStr = "[Invoke] " .. RSPY_Serialize(args, 0), batchId = rspyBatchId,
                                }
                                rspyBatchId = rspyBatchId + 1
                                table.insert(rspyRecords, record)
                                if #rspyRecords > MAX_RSPY_RECORDS then table.remove(rspyRecords, 1) end
                                rspyRefreshNeeded = true
                                countLabel.Text = string.format("记录: %d (批次: %d)", #rspyRecords, rspyBatchId)
                                return origInvoke(self, ...)
                            end
                            table.insert(rspyHooks, {remote = remote, type = "InvokeServer"})
                            hookCount = hookCount + 1
                        end
                    end
                end
            end
        end
        rspyRunning = true
        statusLabel.Text = string.format("状态: 🟢 运行中 (%d 个 Remote 已 Hook)", hookCount)
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    end
    local function UnhookAllRemotes()
        rspyRunning = false
        for _, hook in ipairs(rspyHooks) do
            if hook.conn then pcall(function() hook.conn:Disconnect() end) end
        end
        rspyHooks = {}
        statusLabel.Text = "状态: ⏹ 已停止"
        statusLabel.TextColor3 = Color3.fromRGB(200, 200, 100)
    end
    MakeButton(container, "▶ 开始嗅探", UDim2.new(0, 120, 0, 34), UDim2.new(0, 5, 0, 90), Color3.fromRGB(50, 80, 50),
        function()
            if rspyRunning then return end
            statusLabel.Text = "正在 Hook..."
            task.delay(0.1, function() HookAllRemotes() _G.DENotifySuccess("RSPY", "数据包嗅探已启动") end)
        end)
    MakeButton(container, "⏹ 停止嗅探", UDim2.new(0, 120, 0, 34), UDim2.new(0, 130, 0, 90), Color3.fromRGB(80, 40, 40),
        function() UnhookAllRemotes() _G.DENotifyInfo("RSPY", "数据包嗅探已停止") end)
    MakeButton(container, "清空记录", UDim2.new(0, 100, 0, 34), UDim2.new(0, 255, 0, 90), Color3.fromRGB(60, 60, 40),
        function() rspyRecords = {} countLabel.Text = "记录: 0" rspyBatchId = 0 ClearScrollFrame(sf) end)
    if rspyRefreshConn then rspyRefreshConn:Disconnect() end
    rspyRefreshConn = RunService and RunService.RenderStepped:Connect(function()
        if rspyRefreshNeeded then rspyRefreshNeeded = false RefreshRSPYDisplay() end
    end)
    RefreshRSPYDisplay()
end

-- =========================== GUI 构建 ===========================
local function GetGUIParent()
    if CoreGui then
        local ok = pcall(function()
            local test = Instance.new("ScreenGui")
            test.Parent = CoreGui
            test:Destroy()
        end)
        if ok then return CoreGui end
    end
    if Players and Players.LocalPlayer then
        local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then return playerGui end
    end
    return nil
end

local function BuildMainGUI()
    local guiParent = GetGUIParent()
    if not guiParent then
        if Players and Players.LocalPlayer then
            guiParent = Players.LocalPlayer:FindFirstChild("PlayerGui")
        end
        if not guiParent then return false, "PlayerGui not found" end
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "DeltaExplorer_v2"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 100
    local success = pcall(function() gui.Parent = guiParent end)
    if not success then return false, "Cannot parent GUI" end
    DE_GUI = gui

    -- 屏幕尺寸适配
    local screenSize = Vector2.new(800, 600)
    local ok, ss = pcall(function()
        if Workspace and Workspace.CurrentCamera then
            return Workspace.CurrentCamera.ViewportSize
        end
        return nil
    end)
    if ok and ss then screenSize = ss end

    local mainW = math.min(420, screenSize.X - 20)
    local mainH = math.min(600, screenSize.Y - 40)

    local main = MakeFrame(gui, UDim2.new(0, mainW, 0, mainH), UDim2.new(0.5, -mainW/2, 0.5, -mainH/2), Color3.fromRGB(20, 20, 28), 0)
    main.Name = "MainFrame"
    DE_MainUI = main
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = main
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 80)
    stroke.Thickness = 1.5
    stroke.Parent = main

    -- 标题栏 (可拖拽)
    local titleBar = MakeFrame(main, UDim2.new(1, 0, 0, 38), nil, Color3.fromRGB(30, 30, 40), 0)
    titleBar.Name = "TitleBar"
    local titleCorn = Instance.new("UICorner")
    titleCorn.CornerRadius = UDim.new(0, 10)
    titleCorn.Parent = titleBar
    local titleLabel = MakeLabel(titleBar, "🔍 " .. APP_NAME, UDim2.new(1, -50, 1, 0), UDim2.new(0, 12, 0, 0), Color3.fromRGB(255, 255, 255), 16, Enum.TextXAlignment.Left)
    titleLabel.Font = Enum.Font.GothamBold

    -- 关闭按钮
    local closeBtn = MakeButton(titleBar, "✕", UDim2.new(0, 30, 0, 28), UDim2.new(1, -34, 0, 5), Color3.fromRGB(80, 30, 30),
        function()
            for _, c in ipairs(monitorConnections) do
                pcall(function() c:Disconnect() end)
            end
            monitorConnections = {}
            if rspyRefreshConn then rspyRefreshConn:Disconnect() rspyRefreshConn = nil end
            if rspyRunning then UnhookAllRemotes() end
            DE_GUI:Destroy()
            DE_GUI = nil
            DE_MainUI = nil
        end)
    closeBtn.TextSize = 16

    -- 拖拽功能 (触摸兼容)
    local dragging = false
    local dragInput, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    titleBar.InputChanged:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging then
            dragInput = input
        end
    end)
    if UserInputService then
        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end

    -- 标签页按钮
    local tabData = {
        {"📊", "元数据"}, {"📁", "浏览器"}, {"🔢", "值扫描"},
        {"📡", "Remote"}, {"👁", "监控"}, {"🔍", "搜索"}, {"🎣", "RSPY"},
    }
    local tabBar = MakeFrame(main, UDim2.new(1, -12, 0, 36), UDim2.new(0, 6, 0, 42), Color3.fromRGB(25, 25, 35), 0)
    tabBar.Name = "TabBar"
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Padding = UDim.new(0, 4)
    tabLayout.Parent = tabBar

    local contentArea = MakeFrame(main, UDim2.new(1, -12, 1, -(84 + 8)), UDim2.new(0, 6, 0, 84), Color3.fromRGB(22, 22, 30), 0)
    contentArea.Name = "ContentArea"
    local tabButtons = {}
    local tabContainers = {}
    local currentTabIndex = 1

    local function SwitchTab(idx)
        currentTabIndex = idx
        for i, btn in ipairs(tabButtons) do
            btn.BackgroundColor3 = (i == idx) and Color3.fromRGB(60, 80, 120) or Color3.fromRGB(35, 35, 45)
        end
        ClearScrollFrame(contentArea)
        local tabName = tabData[idx][2]
        if tabName == "元数据" then BuildMetadata(contentArea)
        elseif tabName == "浏览器" then
            DE_BrowserRoot = DE_BrowserRoot or Workspace
            BuildBrowserTree(contentArea, DE_BrowserRoot, 1)
        elseif tabName == "值扫描" then BuildValueScanner(contentArea)
        elseif tabName == "Remote" then BuildRemoteDiscovery(contentArea)
        elseif tabName == "监控" then BuildMonitor(contentArea)
        elseif tabName == "搜索" then BuildSearch(contentArea)
        elseif tabName == "RSPY" then BuildRSPY(contentArea)
        end
    end

    for i, td in ipairs(tabData) do
        local btn = MakeButton(tabBar, td[1] .. " " .. td[2], UDim2.new(0, 0, 0, 30), nil, Color3.fromRGB(35, 35, 45),
            function() SwitchTab(i) end)
        btn.AutomaticSize = Enum.AutomaticSize.X
        btn.TextSize = 12
        table.insert(tabButtons, btn)
    end

    -- 底部状态栏
    MakeLabel(main, "DeltaExplorer " .. VERSION .. " | 通用", UDim2.new(1, -12, 0, 20), UDim2.new(0, 6, 1, -22), Color3.fromRGB(120, 120, 130), 11, Enum.TextXAlignment.Center)

    -- 默认显示第一个标签
    SwitchTab(1)
    return true
end

-- =========================== 启动 ===========================
-- 启动通知
pcall(function()
    if StarterGui then
        StarterGui:SetCore("SendNotification", {
            Title = "DeltaExplorer",
            Text = "正在加载 " .. VERSION .. " ...",
            Duration = 2
        })
    end
end)

-- 延迟初始化 NotifySystem
task.delay(0.3, function()
    pcall(function()
        _G.DENotifySystem.SetupContainer()
    end)
end)

-- 延迟构建 GUI
task.delay(0.8, function()
    local ok, msg = BuildMainGUI()
    if ok then
        _G.DENotifySuccess("DeltaExplorer", "已成功加载 " .. VERSION)
    else
        _G.DENotifyError("加载失败", msg or "未知错误")
        pcall(function()
            if StarterGui then
                StarterGui:SetCore("SendNotification", {
                    Title = "DeltaExplorer 错误",
                    Text = "GUI 加载失败: " .. (msg or "未知错误"),
                    Duration = 5
                })
            end
        end)
    end
end)

-- 纯顶层代码结束 — 没有 return function(...) wrapper, 没有 end)(...)
-- 所有函数/变量均为 local, 全局仅 _G.DENotify 系列

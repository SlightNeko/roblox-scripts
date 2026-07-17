--[[
Ninja Injector — Data Explorer v1.1
GameId: 任何 Roblox 游戏（通用）
功能:
  1. Instance 浏览器  — 树形浏览 Workspace/Players 所有对象
  2. 值扫描器        — 输入数值范围，扫描 NumberValue/IntValue 等
  3. Remote 发现     — 列出所有 RemoteEvent/RemoteFunction
  4. 实时监控        — 选中值后实时监听变化并滚动显示
  5. 元数据面板      — 显示 LocalPlayer 基本信息
  6. 对象搜索        — 按名称关键词搜索 Instance
  7. RSPY 数据包嗅探— Hook Remote 并记录 FireServer/OnClientEvent 参数
依赖: 无 (纯 Luau)
兼容: Ninja Injector / 标准 UNC 注入器
创建日期: 2026-07-17
--]]

-- =========================== 服务引用 ===========================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

-- =========================== 常量 ===========================
local VERSION = "v1.1"
local APP_NAME = "Data Explorer " .. VERSION
local MAX_LIST_ITEMS = 30          -- 每页最多显示条数
local SCAN_DEPTH_LIMIT = 20        -- 对象扫描最大深度
local MONITOR_INTERVAL = 0.5       -- 监控刷新间隔（秒）
local REMOTE_SCAN_DEPTH = 10       -- Remote 扫描深度

-- =========================== 核心变量 ===========================
local DataExplorer = {}
DataExplorer.__index = DataExplorer

-- 全局状态
local currentTab = "metadata"
local monitorConnections = {}
local browserPage = 1
local searchResults = {}
local scanResults = {}
local remoteList = {}
local selectedMonitorPath = nil
local monitorLogs = {}
local monitoredValue = nil
local monitorRunning = false

-- RSPY 嗅探状态
local rspyRunning = false
local rspyRecords = {}
local rspyHooks = {}
local MAX_RSPY_RECORDS = 500
local rspyBatchId = 0
local rspyLastBatchTime = 0
local rspyRefreshNeeded = false
local rspyRefreshConn = nil

-- =========================== 兼容工具函数 ===========================

-- 获取时间戳字符串（代替 os.date，Roblox 无 os.date）
local function GetTimestamp()
    local now = DateTime.now()
    local h, m, s = now:Hour(), now:Minute(), now:Second()
    return string.format("%02d:%02d:%02d", h, m, s)
end

-- 手动分割字符串（兼容没有 string:split() 的旧版本）
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

-- 创建圆角 Frame
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

-- 创建标题标签
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

-- 创建按钮
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

-- 创建输入框
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

-- 创建滚动列表
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

-- 创建分割线
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

-- 清除滚动列表面板
local function ClearScrollFrame(sf)
    for _, v in ipairs(sf:GetChildren()) do
        if v:IsA("GuiObject") then
            v:Destroy()
        end
    end
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
end

-- =========================== 核心扫描函数 ===========================

-- 递归获取所有子对象（限制深度）
local function GetAllChildren(root, depth, maxDepth, filterClasses)
    depth = depth or 0
    if depth > maxDepth then return {} end

    local results = {}
    for _, child in ipairs(root:GetChildren()) do
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

-- 搜索 Instance 按名称关键词
local function SearchInstances(root, keyword, depth, maxDepth)
    depth = depth or 0
    if depth > maxDepth then return {} end
    local results = {}
    local kwLower = keyword:lower()

    for _, child in ipairs(root:GetChildren()) do
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

-- 获取对象的属性摘要
local function GetInstanceSummary(inst)
    local info = {}
    info.Name = inst.Name
    info.ClassName = inst.ClassName
    local parentOk, parentName = pcall(function() return inst.Parent.Name end)
    info.Parent = parentOk and parentName or "N/A"
    info.FullPath = nil
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

    -- 获取常用属性
    info.Properties = {}
    local propList = {"Value", "MaxValue", "MinValue", "Enabled", "Visible",
                       "Transparency", "Size", "Position", "Color",
                       "TeamColor", "Health", "MaxHealth", "WalkSpeed",
                       "JumpPower", "Speed"}

    for _, prop in ipairs(propList) do
        local ok, val = pcall(function() return inst[prop] end)
        if ok and val ~= nil then
            if type(val) == "userdata" then
                info.Properties[prop] = tostring(val)
            elseif type(val) == "number" then
                info.Properties[prop] = string.format("%.2f", val)
            else
                info.Properties[prop] = tostring(val)
            end
        end
    end

    -- 获取属性
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

-- =========================== Tab 1: Instance 浏览器 ===========================

local browserState = {}
-- browserState.currentPath = {root}
-- browserState.selectedIndex = nil

local function BuildBrowserTree(container, root, page)
    ClearScrollFrame(container)

    local items = {}
    local children = root:GetChildren()
    for _, child in ipairs(children) do
        table.insert(items, child)
    end

    -- 分页
    local totalPages = math.max(1, math.ceil(#items / MAX_LIST_ITEMS))
    page = math.min(page, totalPages)
    browserPage = page

    local startIdx = (page - 1) * MAX_LIST_ITEMS + 1
    local endIdx = math.min(startIdx + MAX_LIST_ITEMS - 1, #items)

    -- 标题：当前路径
    local pathLabel = MakeLabel(container, "路径: " .. root.Name, UDim2.new(1, -10, 0, 22), UDim2.new(0, 5, 0, 2), Color3.fromRGB(100, 200, 255), 13)
    pathLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- 页数信息
    if totalPages > 1 then
        MakeLabel(container, string.format("第 %d/%d 页 (共 %d 项)", page, totalPages, #items),
            UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 24), Color3.fromRGB(180, 180, 180), 12)
    else
        MakeLabel(container, string.format("共 %d 个子对象", #items),
            UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 24), Color3.fromRGB(180, 180, 180), 12)
    end

    -- 分页按钮
    local pageY = 44
    if totalPages > 1 then
        local prevBtn = MakeButton(container, "◀ 上一页", UDim2.new(0, 80, 0, 28), UDim2.new(0, 5, 0, pageY), Color3.fromRGB(50, 50, 70),
            function()
                if browserPage > 1 then
                    local newRoot = browserState.currentRoot or Workspace
                    BuildBrowserTree(container, newRoot, browserPage - 1)
                end
            end)
        if page == 1 then prevBtn.BackgroundTransparency = 0.6 prevBtn.Active = false end

        local pageLabel = MakeLabel(container, tostring(page) .. "/" .. tostring(totalPages), UDim2.new(0, 60, 0, 28), UDim2.new(0, 88, 0, pageY), Color3.fromRGB(200, 200, 200), 14, Enum.TextXAlignment.Center)

        local nextBtn = MakeButton(container, "下一页 ▶", UDim2.new(0, 80, 0, 28), UDim2.new(0, 150, 0, pageY), Color3.fromRGB(50, 50, 70),
            function()
                if browserPage < totalPages then
                    local newRoot = browserState.currentRoot or Workspace
                    BuildBrowserTree(container, newRoot, browserPage + 1)
                end
            end)
        if page == totalPages then nextBtn.BackgroundTransparency = 0.6 nextBtn.Active = false end
    end

    -- 返回上级按钮 (如果不是根节点)
    local buttonY = pageY + (totalPages > 1 and 34 or 0)
    if root ~= Workspace and root ~= Players and root ~= game then
        MakeButton(container, "⬆ 返回上级", UDim2.new(0, 100, 0, 28), UDim2.new(0, 5, 0, buttonY), Color3.fromRGB(60, 50, 50),
            function()
                local parentOk, parent = pcall(function() return root.Parent end)
                if parentOk and parent then
                    browserState.currentRoot = parent
                    BuildBrowserTree(container, parent, 1)
                end
            end)
        buttonY = buttonY + 32
    end

    -- 刷新按钮
    MakeButton(container, "🔄 刷新", UDim2.new(0, 80, 0, 28), UDim2.new(0, 110, 0, buttonY), Color3.fromRGB(50, 60, 50),
        function()
            BuildBrowserTree(container, browserState.currentRoot or Workspace, 1)
        end)

    -- 列表
    local listY = buttonY + 36
    local listFrame = MakeScrollingFrame(container, UDim2.new(1, -10, 1, -(listY + 10)), UDim2.new(0, 5, 0, listY))

    for i = startIdx, endIdx do
        local item = items[i]
        local itemFrame = MakeFrame(listFrame, UDim2.new(1, -4, 0, 30), nil, Color3.fromRGB(35, 35, 45), 0)

        -- 图标根据类名
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

        local hasChildren = #item:GetChildren() > 0
        local expander = hasChildren and " [+]" or "   "

        local label = MakeLabel(itemFrame, icon .. " " .. item.Name .. "  (" .. cls .. ")" .. expander,
            UDim2.new(1, -5, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(200, 200, 200), 13)

        -- 点击进入子目录
        if hasChildren then
            itemFrame.BackgroundColor3 = Color3.fromRGB(35, 40, 50)

            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, 0, 1, 0)
            b.BackgroundTransparency = 1
            b.Text = ""
            b.Parent = itemFrame
            b.MouseButton1Click:Connect(function()
                browserState.currentRoot = item
                BuildBrowserTree(container, item, 1)
            end)
        end

        -- 点击查看属性 (长按/右键? 手机端改用额外按钮)
        local infoBtn = MakeButton(itemFrame, "ℹ", UDim2.new(0, 28, 0, 24), UDim2.new(1, -32, 0, 3), Color3.fromRGB(60, 60, 80),
            function()
                ShowInstanceInfo(item)
            end)
        infoBtn.TextSize = 16
    end
end

-- =========================== 实例信息详情弹窗 ===========================

local infoPopup = nil

local function ShowInstanceInfo(inst)
    if infoPopup and infoPopup.Parent then
        infoPopup:Destroy()
        infoPopup = nil
    end

    local summary = GetInstanceSummary(inst)

    -- 主容器（全屏遮罩）
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BorderSizePixel = 0
    overlay.Parent = DataExplorer.MainUI
    infoPopup = overlay

    local popup = MakeFrame(overlay, UDim2.new(0, 340, 0, 420), UDim2.new(0.5, -170, 0.5, -210), Color3.fromRGB(25, 25, 35), 0)

    MakeLabel(popup, "🔍 " .. inst.Name, UDim2.new(1, -10, 0, 26), UDim2.new(0, 5, 0, 5), Color3.fromRGB(255, 200, 100), 18, Enum.TextXAlignment.Left)

    local closeBtn = MakeButton(popup, "✕", UDim2.new(0, 30, 0, 26), UDim2.new(1, -36, 0, 5), Color3.fromRGB(80, 30, 30),
        function()
            overlay:Destroy()
            infoPopup = nil
        end)

    local scroll = MakeScrollingFrame(popup, UDim2.new(1, -10, 1, -40), UDim2.new(0, 5, 0, 36))

    -- 基本信息
    local fields = {
        {"名称", summary.Name},
        {"类名", summary.ClassName},
        {"父对象", summary.Parent},
        {"完整路径", summary.FullPath},
        {"子对象数", tostring(summary.ChildCount)},
    }
    for _, f in ipairs(fields) do
        local row = MakeFrame(scroll, UDim2.new(1, -4, 0, 36), nil, Color3.fromRGB(35, 35, 45), 0)
        MakeLabel(row, f[1] .. ":", UDim2.new(0, 80, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(150, 150, 150), 13)
        MakeLabel(row, f[2], UDim2.new(1, -90, 1, 0), UDim2.new(0, 88, 0, 0), Color3.fromRGB(220, 220, 220), 13)
        MakeDivider(row, UDim2.new(0, 5, 1, 0), UDim2.new(1, -10, 0, 0))
    end

    -- 属性
    if next(summary.Properties) then
        MakeLabel(scroll, "--- 属性 ---", UDim2.new(1, -4, 0, 22), nil, Color3.fromRGB(100, 200, 255), 14)
        for k, v in pairs(summary.Properties) do
            local row = MakeFrame(scroll, UDim2.new(1, -4, 0, 24), nil, Color3.fromRGB(30, 30, 40), 0)
            MakeLabel(row, k .. ":", UDim2.new(0, 120, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(180, 180, 180), 12)
            MakeLabel(row, v, UDim2.new(1, -130, 1, 0), UDim2.new(0, 128, 0, 0), Color3.fromRGB(220, 220, 220), 12)
        end
    end

    -- 属性（Attributes）
    if summary.Attributes and next(summary.Attributes) then
        MakeLabel(scroll, "--- 自定义属性 ---", UDim2.new(1, -4, 0, 22), nil, Color3.fromRGB(100, 200, 100), 14)
        for k, v in pairs(summary.Attributes) do
            local row = MakeFrame(scroll, UDim2.new(1, -4, 0, 24), nil, Color3.fromRGB(30, 40, 30), 0)
            MakeLabel(row, k .. ":", UDim2.new(0, 120, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(180, 180, 180), 12)
            MakeLabel(row, v, UDim2.new(1, -130, 1, 0), UDim2.new(0, 128, 0, 0), Color3.fromRGB(220, 220, 220), 12)
        end
    end

    -- 监控按钮
    MakeButton(scroll, "📊 监控此对象的值", UDim2.new(1, -4, 0, 34), nil, Color3.fromRGB(50, 60, 80),
        function()
            overlay:Destroy()
            infoPopup = nil
            -- 切换到监控标签并设置监控目标
            local fullPath = summary.FullPath
            selectedMonitorPath = fullPath
            monitoredValue = inst
            SwitchToTab("monitor")
            if DataExplorer.MonitorRefresh then
                DataExplorer.MonitorRefresh()
            end
        end)
end

-- =========================== Tab 2: 值扫描器 ===========================

local function BuildValueScanner(container)
    ClearScrollFrame(container)

    MakeLabel(container, "值扫描器", UDim2.new(1, -10, 0, 28), UDim2.new(0, 5, 0, 5), Color3.fromRGB(255, 200, 100), 18, Enum.TextXAlignment.Left)
    MakeLabel(container, "扫描指定数值范围内的可修改值。", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 30), Color3.fromRGB(150, 150, 150), 12)

    -- 输入范围
    MakeLabel(container, "最小值:", UDim2.new(0, 70, 0, 24), UDim2.new(0, 5, 0, 55), Color3.fromRGB(200, 200, 200), 14)
    local minBox = MakeTextBox(container, "0", UDim2.new(0, 80, 0, 30), UDim2.new(0, 75, 0, 52))

    MakeLabel(container, "最大值:", UDim2.new(0, 70, 0, 24), UDim2.new(0, 165, 0, 55), Color3.fromRGB(200, 200, 200), 14)
    local maxBox = MakeTextBox(container, "999999", UDim2.new(0, 80, 0, 30), UDim2.new(0, 235, 0, 52))

    -- 扫描类型选择
    MakeLabel(container, "扫描类型:", UDim2.new(0, 70, 0, 24), UDim2.new(0, 5, 0, 88), Color3.fromRGB(200, 200, 200), 14)

    local scanTypes = {"NumberValue", "IntValue", "BoolValue", "StringValue", "所有值类型"}
    local selectedType = 1
    local typeLabel = MakeLabel(container, scanTypes[1], UDim2.new(0, 120, 0, 30), UDim2.new(0, 75, 0, 85), Color3.fromRGB(100, 200, 255), 14)

    local function CycleType()
        selectedType = selectedType % #scanTypes + 1
        typeLabel.Text = scanTypes[selectedType]
    end

    MakeButton(container, "切换", UDim2.new(0, 60, 0, 28), UDim2.new(0, 200, 0, 86), Color3.fromRGB(50, 50, 70), CycleType)

    -- 扫描范围选择
    MakeLabel(container, "扫描范围:", UDim2.new(0, 70, 0, 24), UDim2.new(0, 5, 0, 120), Color3.fromRGB(200, 200, 200), 14)
    local scopeOptions = {"全游戏", "Workspace", "Players", "ReplicatedStorage"}
    local selectedScope = 1
    local scopeLabel = MakeLabel(container, scopeOptions[1], UDim2.new(0, 120, 0, 30), UDim2.new(0, 75, 0, 117), Color3.fromRGB(100, 200, 255), 14)

    local function CycleScope()
        selectedScope = selectedScope % #scopeOptions + 1
        scopeLabel.Text = scopeOptions[selectedScope]
    end
    MakeButton(container, "切换", UDim2.new(0, 60, 0, 28), UDim2.new(0, 200, 0, 118), Color3.fromRGB(50, 50, 70), CycleScope)

    -- 扫描按钮
    local statusLabel = MakeLabel(container, "就绪", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 152), Color3.fromRGB(120, 120, 120), 12)

    local resultsFrame = MakeScrollingFrame(container, UDim2.new(1, -10, 1, -210), UDim2.new(0, 5, 0, 175))

    local function DoScan()
        ClearScrollFrame(resultsFrame)
        local minVal = tonumber(minBox.Text) or 0
        local maxVal = tonumber(maxBox.Text) or 999999
        if minVal > maxVal then minVal, maxVal = maxVal, minVal end
        statusLabel.Text = "扫描中..."

        -- 确定扫描根目录
        local roots = {}
        if selectedScope == 1 then -- 全游戏
            roots = {Workspace, Players, ReplicatedStorage, game:GetService("Lighting"), game:GetService("Chat")}
            -- 也扫一些常见服务
            local services = {"ReplicatedFirst", "ServerStorage", "ServerScriptService"}
            for _, sn in ipairs(services) do
                local ok, sv = pcall(function() return game:GetService(sn) end)
                if ok then table.insert(roots, sv) end
            end
        elseif selectedScope == 2 then
            roots = {Workspace}
        elseif selectedScope == 3 then
            roots = {Players}
        elseif selectedScope == 4 then
            roots = {ReplicatedStorage}
        end

        -- 过滤类
        local classFilter = {}
        local st = scanTypes[selectedType]
        if st == "所有值类型" then
            classFilter = {"NumberValue", "IntValue", "BoolValue", "StringValue",
                           "IntConstrainedValue", "NumberPose", "DoubleConstrainedValue"}
        else
            classFilter = {st}
        end

        -- 扫描
        local allMatches = {}
        local totalScanned = 0

        for _, root in ipairs(roots) do
            local ok, items = pcall(GetAllChildren, root, 0, SCAN_DEPTH_LIMIT, classFilter)
            if ok then
                for _, item in ipairs(items) do
                    totalScanned = totalScanned + 1
                    local valOk, val = pcall(function() return item.Value end)
                    if valOk and type(val) == "number" then
                        if val >= minVal and val <= maxVal then
                            table.insert(allMatches, {inst = item, value = val})
                        end
                    elseif valOk and type(val) == "boolean" and st == "BoolValue" then
                        table.insert(allMatches, {inst = item, value = val and "true" or "false"})
                    elseif valOk and type(val) == "string" and st == "StringValue" then
                        table.insert(allMatches, {inst = item, value = val})
                    end
                end
            end
        end

        statusLabel.Text = string.format("扫描完成: 检查了 %d 个对象, 找到 %d 个匹配", totalScanned, #allMatches)
        scanResults = allMatches

        -- 显示结果（分页）
        local totalPages = math.max(1, math.ceil(#allMatches / MAX_LIST_ITEMS))
        local page = 1
        local pageLabel = nil

        local function ShowPage(p)
            ClearScrollFrame(resultsFrame)
            p = math.max(1, math.min(p, totalPages))
            local si = (p - 1) * MAX_LIST_ITEMS + 1
            local ei = math.min(si + MAX_LIST_ITEMS - 1, #allMatches)

            if totalPages > 1 then
                local navFrame = MakeFrame(resultsFrame, UDim2.new(1, -4, 0, 30), nil, Color3.fromRGB(30, 30, 40), 0)
                MakeButton(navFrame, "◀", UDim2.new(0, 40, 0, 24), UDim2.new(0, 2, 0, 3), Color3.fromRGB(50, 50, 70),
                    function() ShowPage(p - 1) end)
                if pageLabel then pageLabel:Destroy() end
                pageLabel = MakeLabel(navFrame, string.format("第 %d/%d 页", p, totalPages), UDim2.new(0, 120, 0, 24), UDim2.new(0, 45, 0, 3), Color3.fromRGB(180, 180, 180), 13, Enum.TextXAlignment.Center)
                MakeButton(navFrame, "▶", UDim2.new(0, 40, 0, 24), UDim2.new(0, 170, 0, 3), Color3.fromRGB(50, 50, 70),
                    function() ShowPage(p + 1) end)
            end

            for i = si, ei do
                local match = allMatches[i]
                local row = MakeFrame(resultsFrame, UDim2.new(1, -4, 0, 36), nil, Color3.fromRGB(35, 40, 50), 0)
                local pn = "?"
                local ok, pn2 = pcall(function() return match.inst.Parent.Name end)
                if ok then pn = pn2 end

                MakeLabel(row, match.inst.Name, UDim2.new(0, 120, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(200, 200, 255), 12)
                MakeLabel(row, "(" .. match.inst.ClassName .. ")", UDim2.new(0, 110, 1, 0), UDim2.new(0, 130, 0, 0), Color3.fromRGB(140, 140, 140), 11)
                MakeLabel(row, "= " .. tostring(match.value), UDim2.new(0, 100, 1, 0), UDim2.new(0, 240, 0, 0), Color3.fromRGB(100, 255, 100), 13)

                -- 详情按钮
                MakeButton(row, "ℹ", UDim2.new(0, 24, 0, 24), UDim2.new(1, -28, 0, 6), Color3.fromRGB(60, 60, 80),
                    function() ShowInstanceInfo(match.inst) end)
            end
        end

        ShowPage(1)
    end

    MakeButton(container, "🔍 开始扫描", UDim2.new(0, 120, 0, 32), UDim2.new(0, 5, 0, 148), Color3.fromRGB(50, 80, 50), DoScan)
end

-- =========================== Tab 3: Remote 发现 ===========================

local function BuildRemoteDiscovery(container)
    ClearScrollFrame(container)

    MakeLabel(container, "Remote 发现", UDim2.new(1, -10, 0, 28), UDim2.new(0, 5, 0, 5), Color3.fromRGB(255, 200, 100), 18, Enum.TextXAlignment.Left)
    MakeLabel(container, "列出所有 RemoteEvent 和 RemoteFunction", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 30), Color3.fromRGB(150, 150, 150), 12)

    local statusLabel = MakeLabel(container, "点击扫描开始发现", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 52), Color3.fromRGB(120, 120, 120), 12)

    -- 扫描范围选择
    MakeLabel(container, "扫描范围:", UDim2.new(0, 70, 0, 24), UDim2.new(0, 5, 0, 74), Color3.fromRGB(200, 200, 200), 14)
    local scopeOptions = {"全游戏", "Workspace", "Players", "ReplicatedStorage", "所有服务"}
    local selectedScope = 1
    local scopeLabel = MakeLabel(container, scopeOptions[1], UDim2.new(0, 120, 0, 30), UDim2.new(0, 75, 0, 71), Color3.fromRGB(100, 200, 255), 14)

    local function CycleScope()
        selectedScope = selectedScope % #scopeOptions + 1
        scopeLabel.Text = scopeOptions[selectedScope]
    end
    MakeButton(container, "切换", UDim2.new(0, 60, 0, 28), UDim2.new(0, 200, 0, 72), Color3.fromRGB(50, 50, 70), CycleScope)

    local resultsFrame = MakeScrollingFrame(container, UDim2.new(1, -10, 1, -150), UDim2.new(0, 5, 0, 110))

    -- 远程详情弹窗
    local function ShowRemoteInfo(remote)
        local summary = GetInstanceSummary(remote)
        local overlay = Instance.new("Frame")
        overlay.Size = UDim2.new(1, 0, 1, 0)
        overlay.BackgroundTransparency = 0.5
        overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        overlay.BorderSizePixel = 0
        overlay.Parent = DataExplorer.MainUI

        local popup = MakeFrame(overlay, UDim2.new(0, 340, 0, 300), UDim2.new(0.5, -170, 0.5, -150), Color3.fromRGB(25, 25, 35), 0)
        MakeLabel(popup, "📡 " .. remote.Name, UDim2.new(1, -10, 0, 26), UDim2.new(0, 5, 0, 5), Color3.fromRGB(100, 200, 255), 18, Enum.TextXAlignment.Left)
        MakeButton(popup, "✕", UDim2.new(0, 30, 0, 26), UDim2.new(1, -36, 0, 5), Color3.fromRGB(80, 30, 30), function() overlay:Destroy() end)

        local scroll = MakeScrollingFrame(popup, UDim2.new(1, -10, 1, -40), UDim2.new(0, 5, 0, 36))

        local infoFields = {
            {"名称", remote.Name},
            {"类名", remote.ClassName},
            {"父对象", summary.Parent},
            {"完整路径", summary.FullPath},
        }
        for _, f in ipairs(infoFields) do
            local row = MakeFrame(scroll, UDim2.new(1, -4, 0, 28), nil, Color3.fromRGB(35, 35, 45), 0)
            MakeLabel(row, f[1], UDim2.new(0, 80, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(150, 150, 150), 13)
            MakeLabel(row, f[2], UDim2.new(1, -90, 1, 0), UDim2.new(0, 88, 0, 0), Color3.fromRGB(220, 220, 220), 13)
        end

        -- 远程参数信息（无法直接读取参数，但可以显示父级脚本信息）
        MakeLabel(scroll, "--- 父级脚本 ---", UDim2.new(1, -4, 0, 22), nil, Color3.fromRGB(100, 200, 100), 14)
        local parent = remote.Parent
        local scriptCount = 0
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
                scriptCount = scriptCount + 1
                local row = MakeFrame(scroll, UDim2.new(1, -4, 0, 24), nil, Color3.fromRGB(30, 40, 30), 0)
                MakeLabel(row, "📜 " .. child.Name, UDim2.new(1, -5, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(180, 220, 180), 12)
            end
        end
        if scriptCount == 0 then
            MakeLabel(scroll, "未找到关联脚本", UDim2.new(1, -4, 0, 20), nil, Color3.fromRGB(140, 140, 140), 12)
        end
    end

    local function DoRemoteScan()
        ClearScrollFrame(resultsFrame)
        statusLabel.Text = "扫描中..."

        local roots = {}
        if selectedScope == 1 then -- 全游戏
            roots = {Workspace, Players, ReplicatedStorage, game:GetService("Lighting")}
        elseif selectedScope == 2 then
            roots = {Workspace}
        elseif selectedScope == 3 then
            roots = {Players}
        elseif selectedScope == 4 then
            roots = {ReplicatedStorage}
        elseif selectedScope == 5 then
            -- 所有服务
            local services = {"Workspace", "Players", "ReplicatedStorage", "ReplicatedFirst",
                             "ServerStorage", "ServerScriptService", "Lighting", "Chat"}
            for _, sn in ipairs(services) do
                local ok, sv = pcall(function() return game:GetService(sn) end)
                if ok then table.insert(roots, sv) end
            end
        end

        local allRemotes = {}
        for _, root in ipairs(roots) do
            local ok, items = pcall(GetAllChildren, root, 0, REMOTE_SCAN_DEPTH, {"RemoteEvent", "RemoteFunction"})
            if ok then
                for _, item in ipairs(items) do
                    table.insert(allRemotes, item)
                end
            end
        end

        statusLabel.Text = string.format("找到 %d 个 Remote 对象", #allRemotes)
        remoteList = allRemotes

        if #allRemotes == 0 then
            MakeLabel(resultsFrame, "未发现 RemoteEvent/RemoteFunction", UDim2.new(1, -10, 0, 30), UDim2.new(0, 5, 0, 5), Color3.fromRGB(200, 100, 100), 14, Enum.TextXAlignment.Center)
            return
        end

        -- 分页显示
        local totalPages = math.max(1, math.ceil(#allRemotes / MAX_LIST_ITEMS))
        local currentPage = 1

        local function ShowPage(p)
            ClearScrollFrame(resultsFrame)
            p = math.max(1, math.min(p, totalPages))
            currentPage = p
            local si = (p - 1) * MAX_LIST_ITEMS + 1
            local ei = math.min(si + MAX_LIST_ITEMS - 1, #allRemotes)

            -- 导航
            local navFrame = MakeFrame(resultsFrame, UDim2.new(1, -4, 0, 30), nil, Color3.fromRGB(30, 30, 40), 0)
            if totalPages > 1 then
                MakeButton(navFrame, "◀", UDim2.new(0, 40, 0, 24), UDim2.new(0, 2, 0, 3), Color3.fromRGB(50, 50, 70), function() ShowPage(p - 1) end)
                MakeLabel(navFrame, string.format("第 %d/%d 页", p, totalPages), UDim2.new(0, 120, 0, 24), UDim2.new(0, 45, 0, 3), Color3.fromRGB(180, 180, 180), 13, Enum.TextXAlignment.Center)
                MakeButton(navFrame, "▶", UDim2.new(0, 40, 0, 24), UDim2.new(0, 170, 0, 3), Color3.fromRGB(50, 50, 70), function() ShowPage(p + 1) end)
            else
                MakeLabel(navFrame, string.format("共 %d 个 Remote", #allRemotes), UDim2.new(1, -10, 0, 24), UDim2.new(0, 5, 0, 3), Color3.fromRGB(180, 180, 180), 13, Enum.TextXAlignment.Left)
            end

            for i = si, ei do
                local r = allRemotes[i]
                local pn = "?"
                local ok, pn2 = pcall(function() return r.Parent.Name end)
                if ok then pn = pn2 end

                local icon = r.ClassName == "RemoteEvent" and "📡" or "🔌"
                local row = MakeFrame(resultsFrame, UDim2.new(1, -4, 0, 34), nil, Color3.fromRGB(35, 40, 50), 0)
                MakeLabel(row, icon .. " " .. r.Name, UDim2.new(0, 160, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(200, 200, 255), 13)
                MakeLabel(row, r.ClassName, UDim2.new(0, 100, 1, 0), UDim2.new(0, 170, 0, 0), Color3.fromRGB(140, 200, 255), 11)
                MakeLabel(row, "→ " .. pn, UDim2.new(0, 120, 1, 0), UDim2.new(0, 270, 0, 0), Color3.fromRGB(150, 150, 150), 11)

                MakeButton(row, "🔍", UDim2.new(0, 24, 0, 24), UDim2.new(1, -28, 0, 5), Color3.fromRGB(60, 60, 80), function() ShowRemoteInfo(r) end)
            end
        end
        ShowPage(1)
    end

    MakeButton(container, "🔍 扫描 Remote", UDim2.new(0, 140, 0, 32), UDim2.new(0, 5, 0, 105), Color3.fromRGB(50, 80, 80), DoRemoteScan)
end

-- =========================== Tab 4: 实时监控 ===========================

local function BuildRealTimeMonitor(container)
    ClearScrollFrame(container)

    MakeLabel(container, "实时监控", UDim2.new(1, -10, 0, 28), UDim2.new(0, 5, 0, 5), Color3.fromRGB(255, 200, 100), 18, Enum.TextXAlignment.Left)
    MakeLabel(container, "选中一个对象后，实时监听其值变化", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 30), Color3.fromRGB(150, 150, 150), 12)

    -- 当前监控目标
    local targetLabel = MakeLabel(container, "当前目标: 未选择", UDim2.new(1, -10, 0, 22), UDim2.new(0, 5, 0, 52), Color3.fromRGB(100, 200, 255), 14)

    -- 路径输入
    MakeLabel(container, "或在下方输入完整路径:", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 76), Color3.fromRGB(150, 150, 150), 12)
    local pathBox = MakeTextBox(container, "例如: workspace.Part.NumberValue", UDim2.new(1, -75, 0, 30), UDim2.new(0, 5, 0, 96),
        function(text)
            -- 尝试解析路径
            local ok, inst = pcall(function()
                local parts = SplitString(text, ".")
                local obj = game
                for _, part in ipairs(parts) do
                    obj = obj[part]
                    if not obj then return nil end
                end
                return obj
            end)
            if ok and inst then
                selectedMonitorPath = text
                monitoredValue = inst
                targetLabel.Text = "当前目标: " .. inst.Name .. " (" .. inst.ClassName .. ")"
            end
        end)

    -- 控制按钮
    local toggleBtn = MakeButton(container, "▶ 开始监控", UDim2.new(0, 120, 0, 32), UDim2.new(0, 5, 0, 132), Color3.fromRGB(50, 80, 50),
        function()
            if monitorRunning then
                -- 停止
                monitorRunning = false
                for _, conn in ipairs(monitorConnections) do
                    conn:Disconnect()
                end
                monitorConnections = {}
                toggleBtn.Text = "▶ 开始监控"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 80, 50)
            else
                -- 开始
                StartMonitoring()
                if monitorRunning then
                    toggleBtn.Text = "⏹ 停止监控"
                    toggleBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 50)
                end
            end
        end)

    MakeButton(container, "清空日志", UDim2.new(0, 80, 0, 28), UDim2.new(0, 130, 0, 134), Color3.fromRGB(60, 50, 50),
        function()
            monitorLogs = {}
            if DataExplorer.MonitorRefresh then
                DataExplorer.MonitorRefresh()
            end
        end)

    -- 监控日志
    local logFrame = MakeScrollingFrame(container, UDim2.new(1, -10, 1, -210), UDim2.new(0, 5, 0, 172))

    -- 刷新函数
    DataExplorer.MonitorRefresh = function()
        ClearScrollFrame(logFrame)

        if not monitoredValue then
            MakeLabel(logFrame, "未选择监控目标", UDim2.new(1, -10, 0, 30), nil, Color3.fromRGB(200, 100, 100), 14, Enum.TextXAlignment.Center)
            return
        end

        -- 显示当前值
        local valOk, curVal = pcall(function() return monitoredValue.Value end)
        if valOk then
            local curRow = MakeFrame(logFrame, UDim2.new(1, -4, 0, 26), nil, Color3.fromRGB(40, 50, 40), 0)
            MakeLabel(curRow, "当前值: " .. tostring(curVal), UDim2.new(1, -10, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(100, 255, 100), 15)
        end

        -- 显示日志
        MakeLabel(logFrame, "--- 变更记录 ---", UDim2.new(1, -4, 0, 20), nil, Color3.fromRGB(150, 150, 150), 12)

        if #monitorLogs == 0 then
            MakeLabel(logFrame, "暂无变更记录", UDim2.new(1, -10, 0, 20), nil, Color3.fromRGB(120, 120, 120), 12)
        else
            -- 只显示最近 50 条
            local startIdx = math.max(1, #monitorLogs - 50)
            for i = startIdx, #monitorLogs do
                local log = monitorLogs[i]
                local row = MakeFrame(logFrame, UDim2.new(1, -4, 0, 22), nil, Color3.fromRGB(30, 30, 40), 0)
                local color = Color3.fromRGB(255, 200, 100)
                if i % 2 == 0 then
                    color = Color3.fromRGB(200, 255, 200)
                end
                MakeLabel(row, log, UDim2.new(1, -5, 1, 0), UDim2.new(0, 5, 0, 0), color, 12)
            end
        end
    end

    local function StartMonitoring()
        if not monitoredValue then
            -- 尝试从路径解析
            if selectedMonitorPath then
                local ok, inst = pcall(function()
                    local parts = SplitString(selectedMonitorPath, ".")
                    local obj = game
                    for _, part in ipairs(parts) do
                        obj = obj[part]
                        if not obj then return nil end
                    end
                    return obj
                end)
                if ok and inst then
                    monitoredValue = inst
                end
            end
        end

        if not monitoredValue then
            targetLabel.Text = "当前目标: 无效路径!"
            targetLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end

        targetLabel.Text = "当前目标: " .. monitoredValue.Name .. " (" .. monitoredValue.ClassName .. ")"
        targetLabel.TextColor3 = Color3.fromRGB(100, 200, 255)

        -- 获取初始值
        local valOk, curVal = pcall(function() return monitoredValue.Value end)
        if valOk then
            table.insert(monitorLogs, string.format("[开始] %s = %s", GetTimestamp(), tostring(curVal)))
        end

        monitorRunning = true

        -- 连接 Changed 事件
        local changedConn
        changedConn = monitoredValue.Changed:Connect(function(newVal)
            if not monitorRunning then
                if changedConn then changedConn:Disconnect() end
                return
            end
            local ts = GetTimestamp()
            local valStr = tostring(newVal)
            table.insert(monitorLogs, string.format("[%s] → %s", ts, valStr))
            if DataExplorer.MonitorRefresh then
                DataExplorer.MonitorRefresh()
            end
        end)
        table.insert(monitorConnections, changedConn)

        -- 额外轮询已移除：Changed 事件足以覆盖值变化

        -- 初始刷新
        if DataExplorer.MonitorRefresh then
            DataExplorer.MonitorRefresh()
        end
    end

    -- 初始状态
    if monitoredValue then
        targetLabel.Text = "当前目标: " .. monitoredValue.Name .. " (" .. monitoredValue.ClassName .. ")"
        if DataExplorer.MonitorRefresh then
            DataExplorer.MonitorRefresh()
        end
    end
end

-- =========================== Tab 5: 元数据面板 ===========================

local function BuildMetadataPanel(container)
    ClearScrollFrame(container)

    MakeLabel(container, "元数据面板", UDim2.new(1, -10, 0, 28), UDim2.new(0, 5, 0, 5), Color3.fromRGB(255, 200, 100), 18, Enum.TextXAlignment.Left)
    MakeLabel(container, "当前玩家及游戏信息", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 30), Color3.fromRGB(150, 150, 150), 12)

    local scroll = MakeScrollingFrame(container, UDim2.new(1, -10, 1, -60), UDim2.new(0, 5, 0, 55))

    local function RefreshMetadata()
        ClearScrollFrame(scroll)

        -- 玩家信息
        MakeLabel(scroll, "👤 玩家", UDim2.new(1, -10, 0, 24), nil, Color3.fromRGB(255, 200, 100), 16)

        local lp = Players.LocalPlayer
        if lp then
            local fields = {
                {"名称", lp.Name},
                {"显示名", lp.DisplayName},
                {"UserId", tostring(lp.UserId)},
                {"账户年龄", tostring(lp.AccountAge)},
                {"成员组", tostring(lp.MembershipType)},
            }
            for _, f in ipairs(fields) do
                local row = MakeFrame(scroll, UDim2.new(1, -4, 0, 26), nil, Color3.fromRGB(35, 35, 45), 0)
                MakeLabel(row, f[1], UDim2.new(0, 100, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(150, 150, 150), 13)
                MakeLabel(row, f[2], UDim2.new(1, -110, 1, 0), UDim2.new(0, 108, 0, 0), Color3.fromRGB(220, 220, 220), 13)
            end

            -- 团队
            local teamOk, team = pcall(function() return lp.Team end)
            if teamOk and team then
                local row = MakeFrame(scroll, UDim2.new(1, -4, 0, 26), nil, Color3.fromRGB(35, 35, 45), 0)
                MakeLabel(row, "团队", UDim2.new(0, 100, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(150, 150, 150), 13)
                MakeLabel(row, team.Name, UDim2.new(1, -110, 1, 0), UDim2.new(0, 108, 0, 0), Color3.fromRGB(220, 220, 220), 13)
            end

            -- 角色信息
            local char = lp.Character
            if char then
                MakeLabel(scroll, "--- 角色 ---", UDim2.new(1, -10, 0, 22), nil, Color3.fromRGB(100, 200, 255), 14)

                local hum = char:FindFirstChild("Humanoid")
                if hum then
                    local health = hum.Health
                    local maxHealth = hum.MaxHealth
                    local humFields = {
                        {"血量", string.format("%.0f / %.0f", health, maxHealth)},
                        {"移速", string.format("%.1f", hum.WalkSpeed)},
                        {"跳跃", string.format("%.1f", hum.JumpPower or 50)},
                        {"浮空", tostring(hum.FloorMaterial ~= nil and "否" or "是")},
                    }
                    for _, f in ipairs(humFields) do
                        local row = MakeFrame(scroll, UDim2.new(1, -4, 0, 24), nil, Color3.fromRGB(35, 40, 45), 0)
                        MakeLabel(row, f[1], UDim2.new(0, 80, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(150, 150, 150), 12)
                        MakeLabel(row, f[2], UDim2.new(1, -90, 1, 0), UDim2.new(0, 88, 0, 0), Color3.fromRGB(220, 220, 220), 12)
                    end
                end

                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local pos = hrp.Position
                    local row = MakeFrame(scroll, UDim2.new(1, -4, 0, 24), nil, Color3.fromRGB(35, 40, 45), 0)
                    MakeLabel(row, "坐标", UDim2.new(0, 80, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(150, 150, 150), 12)
                    MakeLabel(row, string.format("(%.1f, %.1f, %.1f)", pos.X, pos.Y, pos.Z), UDim2.new(1, -90, 1, 0), UDim2.new(0, 88, 0, 0), Color3.fromRGB(220, 220, 220), 12)
                end
            end
        else
            MakeLabel(scroll, "未获取到 LocalPlayer", UDim2.new(1, -10, 0, 24), nil, Color3.fromRGB(200, 100, 100), 14)
        end

        -- 游戏信息
        MakeLabel(scroll, "--- 游戏 ---", UDim2.new(1, -10, 0, 22), nil, Color3.fromRGB(100, 200, 100), 14)

        -- 使用 tick() 快速估算 FPS（不阻塞 UI 刷新）
        local fpsStr = "N/A"
        local fpsOk, fpsResult = pcall(function()
            local sum = 0
            for i = 1, 5 do
                local t = DateTime.now().UnixTimestampMillis
                RunService.Heartbeat:Wait()
                sum = sum + (DateTime.now().UnixTimestampMillis - t) / 1000
            end
            if sum > 0 then
                return math.floor(5 / sum)
            end
            return nil
        end)
        if fpsOk and fpsResult then
            fpsStr = tostring(fpsResult)
        end

        local gameFields = {
            {"GameId", tostring(game.GameId)},
            {"PlaceId", tostring(game.PlaceId)},
            {"名称", game.Name},
            {"创建者", tostring(game.CreatorId)},
            {"FPS", fpsStr},
        }

        for _, f in ipairs(gameFields) do
            local row = MakeFrame(scroll, UDim2.new(1, -4, 0, 24), nil, Color3.fromRGB(40, 35, 35), 0)
            MakeLabel(row, f[1], UDim2.new(0, 80, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(150, 150, 150), 12)
            MakeLabel(row, f[2], UDim2.new(1, -90, 1, 0), UDim2.new(0, 88, 0, 0), Color3.fromRGB(220, 220, 220), 12)
        end
    end

    RefreshMetadata()

    MakeButton(container, "🔄 刷新", UDim2.new(0, 80, 0, 28), UDim2.new(0, 5, 0, 55), Color3.fromRGB(50, 60, 50), RefreshMetadata)
end

-- =========================== Tab 6: 对象搜索 ===========================

local function BuildObjectSearch(container)
    ClearScrollFrame(container)

    MakeLabel(container, "对象搜索", UDim2.new(1, -10, 0, 28), UDim2.new(0, 5, 0, 5), Color3.fromRGB(255, 200, 100), 18, Enum.TextXAlignment.Left)
    MakeLabel(container, "按名称关键词搜索 Instance（支持模糊匹配）", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 30), Color3.fromRGB(150, 150, 150), 12)

    -- 搜索框
    MakeLabel(container, "关键词:", UDim2.new(0, 60, 0, 24), UDim2.new(0, 5, 0, 54), Color3.fromRGB(200, 200, 200), 14)
    local searchBox = MakeTextBox(container, "输入关键词...", UDim2.new(0, 140, 0, 30), UDim2.new(0, 65, 0, 51))

    -- 搜索范围
    MakeLabel(container, "范围:", UDim2.new(0, 50, 0, 24), UDim2.new(0, 210, 0, 54), Color3.fromRGB(200, 200, 200), 14)
    local scopeOptions = {"全游戏", "Workspace", "Players", "ReplicatedStorage"}
    local selectedScope = 1
    local scopeLabel = MakeLabel(container, scopeOptions[1], UDim2.new(0, 80, 0, 30), UDim2.new(0, 260, 0, 50), Color3.fromRGB(100, 200, 255), 14)

    local function CycleScope()
        selectedScope = selectedScope % #scopeOptions + 1
        scopeLabel.Text = scopeOptions[selectedScope]
    end
    MakeButton(container, "切换", UDim2.new(0, 50, 0, 28), UDim2.new(0, 340, 0, 51), Color3.fromRGB(50, 50, 70), CycleScope)

    local statusLabel = MakeLabel(container, "输入关键词后点击搜索", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 84), Color3.fromRGB(120, 120, 120), 12)

    local resultsFrame = MakeScrollingFrame(container, UDim2.new(1, -10, 1, -140), UDim2.new(0, 5, 0, 108))

    local function DoSearch()
        ClearScrollFrame(resultsFrame)
        local keyword = searchBox.Text
        if #keyword < 1 then
            statusLabel.Text = "请输入关键词"
            return
        end

        statusLabel.Text = "搜索中..."

        -- 确定根目录
        local roots = {}
        if selectedScope == 1 then
            roots = {Workspace, Players, ReplicatedStorage}
        elseif selectedScope == 2 then
            roots = {Workspace}
        elseif selectedScope == 3 then
            roots = {Players}
        elseif selectedScope == 4 then
            roots = {ReplicatedStorage}
        end

        local allResults = {}
        local totalSearched = 0

        for _, root in ipairs(roots) do
            local ok, items = pcall(SearchInstances, root, keyword, 0, SCAN_DEPTH_LIMIT)
            if ok then
                totalSearched = totalSearched + 1
                for _, item in ipairs(items) do
                    table.insert(allResults, item)
                end
            end
        end

        statusLabel.Text = string.format("搜索完成，找到 %d 个匹配对象", #allResults)
        searchResults = allResults

        if #allResults == 0 then
            MakeLabel(resultsFrame, "未找到匹配对象", UDim2.new(1, -10, 0, 30), nil, Color3.fromRGB(200, 100, 100), 14, Enum.TextXAlignment.Center)
            return
        end

        -- 分页显示
        local totalPages = math.max(1, math.ceil(#allResults / MAX_LIST_ITEMS))
        local curPage = 1
        local navLabel = nil

        local function ShowPage(p)
            ClearScrollFrame(resultsFrame)
            p = math.max(1, math.min(p, totalPages))
            curPage = p
            local si = (p - 1) * MAX_LIST_ITEMS + 1
            local ei = math.min(si + MAX_LIST_ITEMS - 1, #allResults)

            -- 导航
            if totalPages > 1 then
                local navFrame = MakeFrame(resultsFrame, UDim2.new(1, -4, 0, 28), nil, Color3.fromRGB(30, 30, 40), 0)
                MakeButton(navFrame, "◀", UDim2.new(0, 40, 0, 22), UDim2.new(0, 2, 0, 3), Color3.fromRGB(50, 50, 70),
                    function() ShowPage(p - 1) end)
                if navLabel then navLabel:Destroy() end
                navLabel = MakeLabel(navFrame, string.format("第 %d/%d 页", p, totalPages), UDim2.new(0, 120, 0, 22), UDim2.new(0, 45, 0, 3), Color3.fromRGB(180, 180, 180), 13, Enum.TextXAlignment.Center)
                MakeButton(navFrame, "▶", UDim2.new(0, 40, 0, 22), UDim2.new(0, 170, 0, 3), Color3.fromRGB(50, 50, 70),
                    function() ShowPage(p + 1) end)
            else
                local navFrame = MakeFrame(resultsFrame, UDim2.new(1, -4, 0, 22), nil, Color3.fromRGB(30, 30, 40), 0)
                MakeLabel(navFrame, string.format("共 %d 个匹配", #allResults), UDim2.new(1, -10, 0, 22), UDim2.new(0, 5, 0, 0), Color3.fromRGB(180, 180, 180), 13, Enum.TextXAlignment.Left)
            end

            for i = si, ei do
                local item = allResults[i]
                local pn = "?"
                local ok, pn2 = pcall(function() return item.Parent.Name end)
                if ok then pn = pn2 end

                local icon = "📄"
                local cls = item.ClassName
                if cls:find("Value") then icon = "🔢"
                elseif cls:find("Remote") then icon = "📡"
                elseif cls:find("Player") then icon = "👤"
                elseif cls:find("Part") then icon = "🧱"
                elseif cls:find("Script") then icon = "📜"
                end

                local row = MakeFrame(resultsFrame, UDim2.new(1, -4, 0, 32), nil, Color3.fromRGB(35, 40, 50), 0)
                MakeLabel(row, icon .. " " .. item.Name, UDim2.new(0, 160, 1, 0), UDim2.new(0, 5, 0, 0), Color3.fromRGB(200, 200, 255), 12)
                MakeLabel(row, "(" .. cls .. ")", UDim2.new(0, 100, 1, 0), UDim2.new(0, 170, 0, 0), Color3.fromRGB(140, 140, 140), 11)
                MakeLabel(row, "→ " .. pn, UDim2.new(0, 100, 1, 0), UDim2.new(0, 270, 0, 0), Color3.fromRGB(150, 150, 150), 11)

                MakeButton(row, "ℹ", UDim2.new(0, 24, 0, 22), UDim2.new(1, -28, 0, 5), Color3.fromRGB(60, 60, 80),
                    function() ShowInstanceInfo(item) end)
            end
        end
        ShowPage(1)
    end

    MakeButton(container, "🔍 搜索", UDim2.new(0, 100, 0, 32), UDim2.new(0, 5, 0, 104), Color3.fromRGB(50, 80, 50), DoSearch)
end

-- =========================== Tab 7: RSPY 数据包嗅探 ===========================

-- 序列化参数（递归展开，最大深度 4）
local function RSPY_Serialize(val, depth)
    depth = depth or 0
    if depth > 4 then return "..." end
    local vt = type(val)
    if vt == "number" then
        return tostring(val)
    elseif vt == "string" then
        return string.format("%q", val)
    elseif vt == "boolean" then
        return tostring(val)
    elseif vt == "nil" then
        return "nil"
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
        if count > 16 then
            table.insert(parts, "...")
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        local okName, name = pcall(function() return val.Name end)
        if okName then
            return "[Instance:" .. name .. "]"
        end
        local okCls, cls = pcall(function() return val.ClassName end)
        if okCls then
            return "[" .. cls .. "]"
        end
        return tostring(val)
    end
end

-- 获取 Remote 完整路径
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

-- 向剪贴板写入（兼容多种注入器）
local function CopyToClipboard(text)
    local ok = false
    if setclipboard then
        ok = pcall(setclipboard, text)
    end
    if not ok and toclipboard then
        ok = pcall(toclipboard, text)
    end
    if not ok then
        pcall(function() print("[RSPY 复制] " .. text) end)
    end
end

-- 构建 RSPY 嗅探页签
local function BuildRSPY(container)
    ClearScrollFrame(container)

    MakeLabel(container, "🕵️ RSPY 数据包嗅探", UDim2.new(1, -10, 0, 28), UDim2.new(0, 5, 0, 5), Color3.fromRGB(255, 200, 100), 18, Enum.TextXAlignment.Left)
    MakeLabel(container, "Hook 所有 RemoteEvent/RemoteFunction，记录双向数据包", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 30), Color3.fromRGB(150, 150, 150), 12)

    local statusLabel = MakeLabel(container, "状态: 未启动", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 52), Color3.fromRGB(200, 200, 100), 14)

    local toggleBtn = MakeButton(container, "▶ 开始嗅探", UDim2.new(0, 130, 0, 34), UDim2.new(0, 5, 0, 74), Color3.fromRGB(50, 80, 50),
        function()
            if rspyRunning then
                -- 停止嗅探
                rspyRunning = false

                -- 恢复所有被 hook 的方法
                local restoredCount = 0
                for _, hookData in ipairs(rspyHooks) do
                    local remote = hookData.remote
                    local methodName = hookData.methodName
                    local original = hookData.original
                    if remote and methodName and original then
                        pcall(function()
                            remote[methodName] = original
                        end)
                        restoredCount = restoredCount + 1
                    end
                end

                -- 清理所有连接（OnClientEvent）
                for _, hookData in ipairs(rspyHooks) do
                    if hookData.conn then
                        pcall(function() hookData.conn:Disconnect() end)
                    end
                end

                rspyHooks = {}
                toggleBtn.Text = "▶ 开始嗅探"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 80, 50)
                statusLabel.Text = "状态: 已停止（恢复了 " .. tostring(restoredCount) .. " 个方法）"
                statusLabel.TextColor3 = Color3.fromRGB(200, 200, 100)
            else
                -- 开始嗅探
                rspyRecords = {}
                rspyHooks = {}
                rspyBatchId = 0

                local hookCount = 0
                local sources = {Workspace, Players, ReplicatedStorage, Lighting, game:GetService("Chat")}
                local scannedRemotes = {}

                local function TryHookInstance(inst)
                    local ok, cls = pcall(function() return inst.ClassName end)
                    if not ok then return end
                    if cls ~= "RemoteEvent" and cls ~= "RemoteFunction" then return end

                    local path = RSPY_GetPath(inst)
                    if scannedRemotes[path] then return end
                    scannedRemotes[path] = true

                    if cls == "RemoteEvent" then
                        -- Hook C→S: FireServer
                        local origFire = inst.FireServer
                        if origFire then
                            inst.FireServer = function(self, ...)
                                local args = {...}
                                local record = {
                                    time = GetTimestamp(),
                                    remoteName = inst.Name,
                                    remoteClass = cls,
                                    path = path,
                                    direction = "C→S",
                                    args = args,
                                    argsStr = RSPY_Serialize(args, 0),
                                    batchId = rspyBatchId,
                                }
                                rspyBatchId = rspyBatchId + 1
                                table.insert(rspyRecords, record)
                                if #rspyRecords > MAX_RSPY_RECORDS then
                                    table.remove(rspyRecords, 1)
                                end
                                rspyRefreshNeeded = true
                                return origFire(self, ...)
                            end
                            table.insert(rspyHooks, {remote=inst, methodName="FireServer", original=origFire})
                            hookCount = hookCount + 1
                        end

                        -- Hook S→C: OnClientEvent 包装
                        local conn
                        conn = inst.OnClientEvent:Connect(function(...)
                            if not rspyRunning then
                                if conn then conn:Disconnect() end
                                return
                            end
                            local args = {...}
                            local record = {
                                time = GetTimestamp(),
                                remoteName = inst.Name,
                                remoteClass = cls,
                                path = path,
                                direction = "S→C",
                                args = args,
                                argsStr = RSPY_Serialize(args, 0),
                                batchId = rspyBatchId,
                            }
                            rspyBatchId = rspyBatchId + 1
                            table.insert(rspyRecords, record)
                            if #rspyRecords > MAX_RSPY_RECORDS then
                                table.remove(rspyRecords, 1)
                            end
                            rspyRefreshNeeded = true
                        end)
                        table.insert(rspyHooks, {remote=inst, conn=conn})
                        hookCount = hookCount + 1

                    elseif cls == "RemoteFunction" then
                        -- Hook C→S: InvokeServer
                        local origInvoke = inst.InvokeServer
                        if origInvoke then
                            inst.InvokeServer = function(self, ...)
                                local args = {...}
                                local record = {
                                    time = GetTimestamp(),
                                    remoteName = inst.Name,
                                    remoteClass = cls,
                                    path = path,
                                    direction = "C→S",
                                    args = args,
                                    argsStr = RSPY_Serialize(args, 0),
                                    batchId = rspyBatchId,
                                }
                                rspyBatchId = rspyBatchId + 1
                                table.insert(rspyRecords, record)
                                if #rspyRecords > MAX_RSPY_RECORDS then
                                    table.remove(rspyRecords, 1)
                                end
                                rspyRefreshNeeded = true
                                return origInvoke(self, ...)
                            end
                            table.insert(rspyHooks, {remote=inst, methodName="InvokeServer", original=origInvoke})
                            hookCount = hookCount + 1
                        end
                    end
                end

                -- 递归扫描所有服务
                local function ScanForRemotes(obj, depth)
                    if depth > 20 then return end
                    local ok = pcall(function()
                        TryHookInstance(obj)
                        for _, child in ipairs(obj:GetChildren()) do
                            ScanForRemotes(child, depth + 1)
                        end
                    end)
                end

                for _, src in ipairs(sources) do
                    if src then
                        ScanForRemotes(src, 0)
                    end
                end

                rspyRunning = true
                toggleBtn.Text = "⏹ 停止嗅探"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 50)
                statusLabel.Text = "状态: 🟢 嗅探中 — 已 Hook " .. tostring(hookCount) .. " 个 Remote"
                statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)

                -- 初始刷新
                if DataExplorer.RSPYRefresh then
                    DataExplorer.RSPYRefresh()
                end
            end
        end)

    MakeButton(container, "🗑 清空记录", UDim2.new(0, 100, 0, 28), UDim2.new(0, 140, 0, 77), Color3.fromRGB(60, 50, 50),
        function()
            rspyRecords = {}
            rspyBatchId = 0
            if DataExplorer.RSPYRefresh then
                DataExplorer.RSPYRefresh()
            end
        end)

    -- 记录列表
    local recordFrame = MakeScrollingFrame(container, UDim2.new(1, -10, 1, -120), UDim2.new(0, 5, 0, 116))

    DataExplorer.RSPYRefresh = function()
        ClearScrollFrame(recordFrame)

        if #rspyRecords == 0 then
            MakeLabel(recordFrame, "暂无记录，点击「开始嗅探」后去游戏里操作", UDim2.new(1, -10, 0, 30), nil, Color3.fromRGB(150, 150, 150), 14, Enum.TextXAlignment.Center)
            return
        end

        -- 只显示最新的 200 条（UI 性能）
        local startIdx = math.max(1, #rspyRecords - 200)
        for i = startIdx, #rspyRecords do
            local rec = rspyRecords[i]

            local rowHeight = 58
            local row = MakeFrame(recordFrame, UDim2.new(1, -4, 0, rowHeight), nil, Color3.fromRGB(30, 30, 40), 0)

            -- 方向徽章
            local isCS = rec.direction == "C→S"
            local badgeColor = isCS and Color3.fromRGB(200, 120, 50) or Color3.fromRGB(50, 120, 200)
            local badge = MakeLabel(row, rec.direction, UDim2.new(0, 42, 0, 16), UDim2.new(0, 4, 0, 4), badgeColor, 10, Enum.TextXAlignment.Center)
            badge.BackgroundTransparency = 0.3
            badge.BackgroundColor3 = badgeColor

            -- Remote 名称 + 类名
            local nameLabel = MakeLabel(row, rec.remoteName .. " (" .. rec.remoteClass .. ")", UDim2.new(0, 0, 0, 18), UDim2.new(0, 52, 0, 3), Color3.fromRGB(220, 220, 255), 13)
            nameLabel.Size = UDim2.new(0, math.min((#rec.remoteName + #rec.remoteClass + 3) * 7 + 10, 180), 0, 18)

            -- 路径
            local pathLabel = MakeLabel(row, rec.path, UDim2.new(0, 0, 0, 14), UDim2.new(0, 52, 0, 20), Color3.fromRGB(120, 120, 120), 10)
            pathLabel.Size = UDim2.new(0, math.min(#rec.path * 6 + 10, 200), 0, 14)

            -- 时间
            local timeLbl = MakeLabel(row, "[" .. rec.time .. "]", UDim2.new(0, 70, 0, 14), UDim2.new(0, 4, 0, 38), Color3.fromRGB(150, 150, 150), 10)

            -- 参数预览
            local paramStr = #rec.args > 0 and rec.argsStr or "(无参数)"
            if #paramStr > 40 then
                paramStr = string.sub(paramStr, 1, 40) .. "..."
            end
            MakeLabel(row, "参数: " .. paramStr, UDim2.new(1, -80, 0, 14), UDim2.new(0, 52, 0, 38), Color3.fromRGB(180, 200, 180), 10)

            -- 一键复制按钮
            MakeButton(row, "📋", UDim2.new(0, 28, 0, 24), UDim2.new(1, -32, 0, 2), Color3.fromRGB(60, 60, 80),
                function()
                    local copyText = string.format("[%s] %s\n路径: %s\n参数: %s",
                        rec.time, rec.direction .. " " .. rec.remoteName, rec.path, rec.argsStr)
                    CopyToClipboard(copyText)
                end)
        end
    end

    -- 初始状态
    if DataExplorer.RSPYRefresh then
        DataExplorer.RSPYRefresh()
    end
end

-- =========================== 标签切换 ===========================

local function SwitchToTab(tabId)
    currentTab = tabId

    -- 隐藏所有内容面板
    local tabs = {"browser", "scanner", "remotes", "monitor", "metadata", "search", "rspy"}
    for _, id in ipairs(tabs) do
        if DataExplorer.Tabs[id] then
            DataExplorer.Tabs[id].Visible = false
        end
    end

    -- 显示选中面板
    if DataExplorer.Tabs[tabId] then
        DataExplorer.Tabs[tabId].Visible = true
    end

    -- 高亮标签按钮
    if DataExplorer.TabButtons then
        for id, btn in pairs(DataExplorer.TabButtons) do
            btn.BackgroundColor3 = (id == tabId) and Color3.fromRGB(60, 80, 100) or Color3.fromRGB(40, 40, 45)
        end
    end
end

-- =========================== Delta 兼容 GUI 父容器获取 ===========================

-- 获取安全的 GUI 父容器：先试 CoreGui（pcall），失败则用 PlayerGui
local function GetSafeParent()
    local ok = pcall(function()
        local test = Instance.new("ScreenGui")
        test.Parent = CoreGui
        test:Destroy()
    end)
    if ok then return CoreGui end

    local player = Players.LocalPlayer
    if player then
        local pg = player:FindFirstChild("PlayerGui")
        if pg then return pg end
        pg = player:WaitForChild("PlayerGui", 5)
        if pg then return pg end
    end
    return nil
end

-- 恢复所有 RSPY Hook（关闭时自动调用）
local function RestoreRSPYHooks()
    if not rspyHooks or #rspyHooks == 0 then return end
    for _, hookData in ipairs(rspyHooks) do
        local remote = hookData.remote
        local methodName = hookData.methodName
        local original = hookData.original
        if remote and methodName and original then
            pcall(function() remote[methodName] = original end)
        end
        if hookData.conn then
            pcall(function() hookData.conn:Disconnect() end)
        end
    end
    rspyHooks = {}
    rspyRunning = false
end

-- Toast 通知（兼容 Delta）
local function ShowToast(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "Data Explorer",
            Text = text or "",
            Duration = duration or 3
        })
    end)
end

-- =========================== 主 UI 构建 ===========================

local restoreBtn = nil

local function EnsureRestoreButton(screenGui)
    -- 删除已有的还原按钮
    if restoreBtn and restoreBtn.Parent then
        restoreBtn:Destroy()
        restoreBtn = nil
    end

    -- 创建浮动还原按钮
    restoreBtn = Instance.new("TextButton")
    restoreBtn.Name = "DataExplorer_Restore"
    restoreBtn.Size = UDim2.new(0, 56, 0, 56)
    restoreBtn.Position = UDim2.new(0.5, -28, 1, -70)
    restoreBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    restoreBtn.Text = "🔍"
    restoreBtn.TextSize = 24
    restoreBtn.BorderSizePixel = 0
    restoreBtn.Parent = screenGui

    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 28)
    rc.Parent = restoreBtn

    -- 拖动
    local dragging, dragStart, frameStart = false, nil, nil
    restoreBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            frameStart = restoreBtn.Position
        end
    end)
    restoreBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    local conn
    conn = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            restoreBtn.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X, frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
        end
    end)

    restoreBtn.MouseButton1Click:Connect(function()
        restoreBtn:Destroy()
        restoreBtn = nil
        if DataExplorer.MainUI and DataExplorer.MainFrame then
            DataExplorer.MainFrame.Visible = true
        end
    end)
end

local function BuildUI()
    -- 获取安全父容器（CoreGui → PlayerGui 探针）
    local safeParent = GetSafeParent()
    if not safeParent then
        warn("[DataExplorer] 无法获取 GUI 父容器")
        return
    end

    -- 安全删除旧的 UI
    local existing = safeParent:FindFirstChild("NinjaDataExplorer")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NinjaDataExplorer"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = safeParent

    DataExplorer.MainUI = screenGui

    -- 注入成功通知
    ShowToast("Data Explorer v1.1", "✅ 注入成功！已自动加载", 3)

    -- 主框架
    local screenSize = UserInputService:GetGuiInset()
    local mainSize = UDim2.new(0, math.min(400, workspace.CurrentCamera.ViewportSize.X - 20), 0, math.min(600, workspace.CurrentCamera.ViewportSize.Y - 40))
    local mainPos = UDim2.new(0, 10, 0, 40)

    local mainFrame = MakeFrame(screenGui, mainSize, mainPos, Color3.fromRGB(22, 22, 30), 0)
    DataExplorer.MainFrame = mainFrame

    -- 标题栏（可拖拽）
    local titleBar = MakeFrame(mainFrame, UDim2.new(1, 0, 0, 32), UDim2.new(0, 0, 0, 0), Color3.fromRGB(35, 35, 50), 0)
    titleBar.Name = "TitleBar"

    MakeLabel(titleBar, APP_NAME, UDim2.new(1, -80, 1, 0), UDim2.new(0, 8, 0, 0), Color3.fromRGB(255, 200, 100), 16, Enum.TextXAlignment.Left)

    -- 最小化（隐藏主窗 + 显示浮动还原按钮）
    local minBtn = MakeButton(titleBar, "─", UDim2.new(0, 30, 0, 24), UDim2.new(1, -68, 0, 4), Color3.fromRGB(50, 50, 60),
        function()
            mainFrame.Visible = false
            EnsureRestoreButton(screenGui)
        end)

    -- 关闭（自动恢复 RSPY hooks 并清理）
    MakeButton(titleBar, "✕", UDim2.new(0, 30, 0, 24), UDim2.new(1, -34, 0, 4), Color3.fromRGB(80, 30, 30),
        function()
            -- 停止监控
            monitorRunning = false
            for _, conn in ipairs(monitorConnections) do
                conn:Disconnect()
            end
            monitorConnections = {}
            -- 恢复 RSPY hook 防止游戏报错
            RestoreRSPYHooks()
            screenGui:Destroy()
        end)

    -- 拖拽逻辑
    local dragging = false
    local dragStart = nil
    local frameStart = nil

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            frameStart = mainFrame.Position
        end
    end)

    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            local newPos = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X, frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
            mainFrame.Position = newPos
        end
    end)

    -- 标签栏
    local tabBar = MakeFrame(mainFrame, UDim2.new(1, 0, 0, 38), UDim2.new(0, 0, 0, 32), Color3.fromRGB(28, 28, 38), 0)

    -- 标签定义
    local tabDefs = {
        {"browser", "🌲"},
        {"scanner", "🔍"},
        {"remotes", "📡"},
        {"monitor", "📊"},
        {"metadata", "👤"},
        {"search", "🔎"},
        {"rspy", "🕵️"},
    }

    DataExplorer.TabButtons = {}
    DataExplorer.Tabs = {}

    -- 内容容器
    local contentArea = MakeFrame(mainFrame, UDim2.new(1, 0, 1, -(32 + 38)), UDim2.new(0, 0, 0, 32 + 38), Color3.fromRGB(22, 22, 30), 0)

    -- 创建每个标签的内容面板
    for idx, tabInfo in ipairs(tabDefs) do
        local tabId = tabInfo[1]
        local tabIcon = tabInfo[2]

        -- 标签按钮
        local btnWidth = math.floor((mainSize.X.Offset - 10) / #tabDefs)
        btnWidth = math.max(45, btnWidth)

        local tabBtn = MakeButton(tabBar, tabIcon, UDim2.new(0, btnWidth, 0, 30),
            UDim2.new(0, (idx - 1) * btnWidth + 2, 0, 4),
            Color3.fromRGB(40, 40, 45),
            function() SwitchToTab(tabId) end)
        tabBtn.TextSize = 18
        DataExplorer.TabButtons[tabId] = tabBtn

        -- 内容面板
        local tabContent = MakeScrollingFrame(contentArea, UDim2.new(1, 0, 1, -4), UDim2.new(0, 0, 0, 0))
        tabContent.Visible = (tabId == "metadata") -- 默认显示元数据
        DataExplorer.Tabs[tabId] = tabContent
    end

    -- 构建各标签内容（每项独立 pcall，一个崩溃不影响其他）
    pcall(BuildBrowserTree, DataExplorer.Tabs.browser, Workspace, 1)
    pcall(BuildValueScanner, DataExplorer.Tabs.scanner)
    pcall(BuildRemoteDiscovery, DataExplorer.Tabs.remotes)
    pcall(BuildRealTimeMonitor, DataExplorer.Tabs.monitor)
    pcall(BuildMetadataPanel, DataExplorer.Tabs.metadata)
    pcall(BuildObjectSearch, DataExplorer.Tabs.search)
    pcall(BuildRSPY, DataExplorer.Tabs.rspy)
    
    -- 标记当前标签
    SwitchToTab("metadata")

    -- 等待 LocalPlayer 可用
    local playerCheck = Players.LocalPlayer
    if not playerCheck then
        local conn
        conn = Players.PlayerAdded:Connect(function(plr)
            if plr == Players.LocalPlayer then
                if DataExplorer.Tabs and DataExplorer.Tabs.metadata then
                    BuildMetadataPanel(DataExplorer.Tabs.metadata)
                end
                conn:Disconnect()
            end
        end)
    end
end

-- =========================== 安全启动 ===========================

local success, err = pcall(function()
    -- 设置默认根
    browserState.currentRoot = Workspace

    -- 构建 UI
    BuildUI()
end)

if not success then
    warn("[DataExplorer] 初始化失败: " .. tostring(err))
    -- 尝试在 GetSafeParent 创建错误提示（兼容 Delta）
    local ok, errGui = pcall(function()
        local parent = GetSafeParent()
        if not parent then return end
        local sg = Instance.new("ScreenGui")
        sg.Name = "NinjaDataExplorer_Error"
        sg.Parent = parent
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, 300, 0, 100)
        f.Position = UDim2.new(0.5, -150, 0.5, -50)
        f.BackgroundColor3 = Color3.fromRGB(30, 20, 20)
        f.Parent = sg
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -10, 1, -10)
        l.Position = UDim2.new(0, 5, 0, 5)
        l.BackgroundTransparency = 1
        l.Text = "❌ Data Explorer 初始化失败\n" .. tostring(err)
        l.TextColor3 = Color3.fromRGB(255, 100, 100)
        l.TextSize = 14
        l.TextWrapped = true
        l.Font = Enum.Font.SourceSans
        l.Parent = f
    end)
end

-- 输出成功信息
pcall(function()
    print("[DataExplorer] v1.1 已加载！")
    print("[DataExplorer] 使用标签栏切换功能：🌲浏览器 🔍扫描器 📡Remote 📊监控 👤信息 🔎搜索 🕵️RSPY")
end)

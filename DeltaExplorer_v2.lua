--[[
DeltaExplorer v2 — 通用 Roblox Lua 注入器 DeBug 工具
GameId: 通用 (任何 Roblox 游戏)
功能:
  1. 元数据面板    — LocalPlayer 信息 + 游戏信息 + 实时 FPS
  2. Instance 浏览器 — 树形浏览 Workspace（分页，每页30个）
  3. 值扫描器      — 扫描 NumberValue/IntValue/BoolValue/StringValue
  4. Remote 发现   — 列出所有 RemoteEvent/RemoteFunction/UnreliableRemoteEvent
  5. 实时监控      — 输入路径，监听 Changed 事件
  6. 对象搜索      — 按名称关键词搜索 Instance
  7. RSPY 数据包嗅探— Hook FireServer/InvokeServer + OnClientEvent，记录通信
版本: v2.0
创作日期: 2026-07-17
兼容: 标准 UNC 注入器（Delta / Ninja / Codex 等）
结构: 纯顶层代码，无 return(function(...) 包装
--]]

-- =========================== 服务引用（SafeGetService） ===========================
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
local UserInputService = SafeGetService("UserInputService")
local RunService = SafeGetService("RunService")
local ReplicatedStorage = SafeGetService("ReplicatedStorage")
local Lighting = SafeGetService("Lighting")
local TweenService = SafeGetService("TweenService")
local StarterGui = SafeGetService("StarterGui")
local CoreGui = SafeGetService("CoreGui")
local HttpService = SafeGetService("HttpService")

-- =========================== 常量 ===========================
local VERSION = "v2.0"
local APP_NAME = "DeltaExplorer " .. VERSION
local MAX_LIST_ITEMS = 30
local SCAN_DEPTH_LIMIT = 20
local REMOTE_SCAN_DEPTH = 10

-- =========================== 全局状态 ===========================
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
local DE_GUI = nil
local DE_MainUI = nil
local infoPopup = nil
local browserState = { currentRoot = nil }

-- RSPY 状态
local rspyRunning = false
local rspyRecords = {}
local rspyHooks = {}
local MAX_RSPY_RECORDS = 500
local rspyBatchId = 0
local rspyLastBatchTime = 0
local rspyRefreshNeeded = false
local rspyRefreshConn = nil

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
    if not sf then return end
    for _, v in ipairs(sf:GetChildren()) do
        if v:IsA("GuiObject") then
            v:Destroy()
        end
    end
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
end

-- =========================== 通知系统（轻量版） ===========================
local function ShowNotification(title, text, duration)
    duration = duration or 3
    pcall(function()
        if StarterGui then
            StarterGui:SetCore("SendNotification", {
                Title = title,
                Text = text,
                Duration = duration
            })
        end
    end)
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
    if infoPopup and infoPopup.Parent then
        infoPopup:Destroy()
        infoPopup = nil
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
    infoPopup = overlay

    local popup = MakeFrame(overlay, UDim2.new(0, 340, 0, 420), UDim2.new(0.5, -170, 0.5, -210), Color3.fromRGB(25, 25, 35), 0)
    MakeLabel(popup, "🔍 " .. inst.Name, UDim2.new(1, -10, 0, 26), UDim2.new(0, 5, 0, 5), Color3.fromRGB(255, 200, 100), 18, Enum.TextXAlignment.Left)
    MakeButton(popup, "✕", UDim2.new(0, 30, 0, 26), UDim2.new(1, -36, 0, 5), Color3.fromRGB(80, 30, 30),
        function()
            overlay:Destroy()
            infoPopup = nil
        end)
    local scroll = MakeScrollingFrame(popup, UDim2.new(1, -10, 1, -40), UDim2.new(0, 5, 0, 36))

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
end

-- =========================== Tab 1: 元数据面板 ===========================
local function BuildMetadata(container)
    ClearScrollFrame(container)
    MakeLabel(container, "元数据面板", UDim2.new(1, -10, 0, 24), UDim2.new(0, 5, 0, 4), Color3.fromRGB(255, 200, 200), 16)
    local lp = Players and Players.LocalPlayer
    local yPos = 34

    if lp then
        local fields = {
            {"用户名", lp.Name},
            {"显示名", lp.DisplayName},
            {"用户ID", tostring(lp.UserId)},
            {"账号年龄", tostring(lp.AccountAge) .. " 天"},
            {"会员", lp.MembershipType == Enum.MembershipType.Premium and "Premium" or "免费"},
            {"Locale", lp.LocaleId},
        }
        for _, f in ipairs(fields) do
            local row = MakeFrame(container, UDim2.new(1, -10, 0, 30), UDim2.new(0, 5, 0, yPos), Color3.fromRGB(35, 35, 45), 0)
            MakeLabel(row, f[1] .. ":", UDim2.new(0, 80, 1, 0), UDim2.new(0, 8, 0, 0), Color3.fromRGB(150, 150, 150), 13)
            MakeLabel(row, f[2], UDim2.new(1, -100, 1, 0), UDim2.new(0, 92, 0, 0), Color3.fromRGB(220, 220, 220), 13)
            yPos = yPos + 33
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
        {"PlaceId", tostring(game.PlaceId)},
        {"GameId", tostring(game.GameId)},
        {"名称", game.Name},
        {"FPS", "计算中..."},
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
        yPos = yPos + 24
    end
end

-- =========================== Tab 2: Instance 浏览器 ===========================
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
                    BuildBrowserTree(container, browserState.currentRoot or Workspace, browserPage - 1)
                end
            end)
        if page == 1 then prevBtn.BackgroundTransparency = 0.6 prevBtn.Active = false end
        MakeLabel(container, tostring(page) .. "/" .. tostring(totalPages), UDim2.new(0, 60, 0, 28), UDim2.new(0, 88, 0, pageY), Color3.fromRGB(200, 200, 200), 14, Enum.TextXAlignment.Center)
        local nextBtn = MakeButton(container, "下一页 ▶", UDim2.new(0, 80, 0, 28), UDim2.new(0, 150, 0, pageY), Color3.fromRGB(50, 50, 70),
            function()
                if browserPage < totalPages then
                    BuildBrowserTree(container, browserState.currentRoot or Workspace, browserPage + 1)
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
                    browserState.currentRoot = parent
                    BuildBrowserTree(container, parent, 1)
                end
            end)
        buttonY = buttonY + 32
    end

    MakeButton(container, "🔄 刷新", UDim2.new(0, 80, 0, 28), UDim2.new(0, 110, 0, buttonY), Color3.fromRGB(50, 60, 50),
        function()
            BuildBrowserTree(container, browserState.currentRoot or Workspace, 1)
        end)

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
                browserState.currentRoot = item
                BuildBrowserTree(container, item, 1)
            end)
        end
        local infoBtn = MakeButton(itemFrame, "ℹ", UDim2.new(0, 28, 0, 24), UDim2.new(1, -32, 0, 3), Color3.fromRGB(60, 60, 80),
            function()
                ShowInstanceInfo(item)
            end)
        infoBtn.TextSize = 16
    end
end

-- =========================== Tab 3: 值扫描器 ===========================
local function BuildValueScanner(container)
    ClearScrollFrame(container)
    MakeLabel(container, "值扫描器", UDim2.new(1, -10, 0, 24), UDim2.new(0, 5, 0, 4), Color3.fromRGB(255, 200, 100), 16)
    MakeLabel(container, "设置数值范围，扫描 NumberValue/IntValue 等实例", UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 28), Color3.fromRGB(160, 160, 160), 12)

    local minBox = MakeTextBox(container, "最小值 (如: 0)", UDim2.new(0, 120, 0, 36), UDim2.new(0, 5, 0, 52))
    local maxBox = MakeTextBox(container, "最大值 (如: 100)", UDim2.new(0, 120, 0, 36), UDim2.new(0, 130, 0, 52))
    local resultLabel = MakeLabel(container, "结果: 等待扫描", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 92), Color3.fromRGB(180, 180, 180), 13)

    MakeButton(container, "🔍 开始扫描", UDim2.new(0, 140, 0, 36), UDim2.new(0, 5, 0, 114), Color3.fromRGB(50, 80, 50),
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
                end
            end)
        end)

    MakeButton(container, "清空结果", UDim2.new(0, 100, 0, 36), UDim2.new(0, 150, 0, 114), Color3.fromRGB(60, 40, 40),
        function()
            resultLabel.Text = "结果: 等待扫描"
            local existing = container:FindFirstChildOfClass("ScrollingFrame")
            while existing do
                existing:Destroy()
                existing = container:FindFirstChildOfClass("ScrollingFrame")
            end
        end)
end

-- =========================== Tab 4: Remote 发现 ===========================
local function BuildRemoteDiscovery(container)
    ClearScrollFrame(container)
    MakeLabel(container, "Remote 发现", UDim2.new(1, -10, 0, 24), UDim2.new(0, 5, 0, 4), Color3.fromRGB(100, 200, 255), 16)
    MakeLabel(container, "列出所有 RemoteEvent/RemoteFunction", UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 28), Color3.fromRGB(160, 160, 160), 12)
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
                end
            end)
        end)
end

-- =========================== Tab 5: 实时监控 ===========================
local function BuildMonitor(container)
    ClearScrollFrame(container)
    MakeLabel(container, "实时监控", UDim2.new(1, -10, 0, 24), UDim2.new(0, 5, 0, 4), Color3.fromRGB(200, 255, 200), 16)
    MakeLabel(container, "输入 Instance 完整路径，实时监控其值变化", UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 28), Color3.fromRGB(160, 160, 160), 12)
    local pathBox = MakeTextBox(container, "路径 (如: Workspace.Part.NumberValue)", UDim2.new(1, -20, 0, 36), UDim2.new(0, 5, 0, 50))
    local statusLabel = MakeLabel(container, "监控状态: 未启动", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 90), Color3.fromRGB(180, 180, 180), 13)
    local monitorLog = MakeScrollingFrame(container, UDim2.new(1, -10, 1, -140), UDim2.new(0, 5, 0, 120))
    local logContainer = monitorLog

    MakeButton(container, "▶ 开始监控", UDim2.new(0, 120, 0, 34), UDim2.new(0, 5, 0, 96), Color3.fromRGB(50, 80, 50),
        function()
            if monitorRunning then return end
            local path = pathBox.Text
            if path == "" then statusLabel.Text = "请输入路径" return end
            statusLabel.Text = "正在解析路径: " .. path
            local target = nil
            local ok = pcall(function()
                target = game
                for _, part in ipairs(SplitString(path, "/")) do
                    if part ~= "" then
                        target = target[part]
                    end
                end
            end)
            if not ok or not target then
                statusLabel.Text = "错误: 未找到对象"
                return
            end
            monitoredValue = target
            selectedMonitorPath = path
            monitorRunning = true
            statusLabel.Text = "监控中: " .. path .. " (值: " .. tostring(target.Value) .. ")"
            ClearScrollFrame(logContainer)
            local conn = RunService and RunService.Heartbeat:Connect(function()
                if not monitorRunning or not monitoredValue or not monitoredValue.Parent then
                    monitorRunning = false
                    statusLabel.Text = "监控已停止 (对象已销毁)"
                    if conn then conn:Disconnect() end
                    return
                end
                local ok2, val = pcall(function() return monitoredValue.Value end)
                if ok2 then
                    local ts = GetTimestamp()
                    local line = string.format("[%s] %s = %s", ts, path, tostring(val))
                    MakeLabel(logContainer, line, UDim2.new(1, -4, 0, 18), nil, Color3.fromRGB(180, 255, 180), 11)
                end
            end)
            if conn then
                table.insert(monitorConnections, conn)
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
                    MakeButton(row, "ℹ", UDim2.new(0, 24, 0, 22), UDim2.new(1, -28, 0, 2), Color3.fromRGB(60, 60, 80),
                        function()
                            ShowInstanceInfo(item)
                        end):SetAttribute("TextSize", 14)
                end
            end)
        end)

    MakeButton(container, "清空", UDim2.new(0, 80, 0, 36), UDim2.new(1, -110, 0, 90), Color3.fromRGB(60, 40, 40),
        function()
            resultLabel.Text = "等待搜索"
            local existing = container:FindFirstChildOfClass("ScrollingFrame")
            while existing do
                existing:Destroy()
                existing = container:FindFirstChildOfClass("ScrollingFrame")
            end
        end)
end

-- =========================== Tab 7: RSPY 数据包嗅探 ===========================
local function BuildRSPY(container)
    ClearScrollFrame(container)
    MakeLabel(container, "RSPY 数据包嗅探", UDim2.new(1, -10, 0, 24), UDim2.new(0, 5, 0, 4), Color3.fromRGB(255, 150, 255), 16)
    MakeLabel(container, "Hook Remote 并记录 FireServer/OnClientEvent 参数", UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 28), Color3.fromRGB(160, 160, 160), 12)
    local statusLabel = MakeLabel(container, "状态: 未启动", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 48), Color3.fromRGB(180, 180, 180), 13)
    local countLabel = MakeLabel(container, "记录: 0", UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 68), Color3.fromRGB(180, 180, 180), 13)

    local listY = 94
    local sf = MakeScrollingFrame(container, UDim2.new(1, -10, 1, -(listY + 10)), UDim2.new(0, 5, 0, listY))

    local function RefreshRSPYDisplay()
        ClearScrollFrame(sf)
        local startIdx = math.max(1, #rspyRecords - 49)
        for i = startIdx, #rspyRecords do
            local rec = rspyRecords[i]
            local row = MakeFrame(sf, UDim2.new(1, -4, 0, 0), nil, Color3.fromRGB(35, 35, 45), 0)
            row.AutomaticSize = Enum.AutomaticSize.Y
            local arrow = rec.direction == "C→S" and "⬆" or "⬇"
            local color = rec.direction == "C→S" and Color3.fromRGB(255, 200, 150) or Color3.fromRGB(150, 200, 255)
            local text = string.format("%s [%s] %s: %s", arrow, rec.time, rec.name, rec.params)
            local label = MakeLabel(row, text, UDim2.new(1, -10, 0, 0), UDim2.new(0, 5, 0, 3), color, 11)
            label.AutomaticSize = Enum.AutomaticSize.Y
            label.TextWrapped = true
            MakeButton(row, "📋", UDim2.new(0, 24, 0, 24), UDim2.new(1, -30, 0, 2), Color3.fromRGB(50, 50, 60),
                function()
                    pcall(function()
                        CopyToClipboard(text)
                        statusLabel.Text = "已复制到剪贴板"
                    end)
                end)
        end
    end

    local function HookAllRemotes()
        for _, hook in ipairs(rspyHooks) do
            pcall(function() hook:Disconnect() end)
        end
        rspyHooks = {}
        local remoteTypes = {"RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent"}
        local roots = {Workspace, Players, ReplicatedStorage, Lighting, game}
        for _, root in ipairs(roots) do
            if root then
                local remotes = GetAllChildren(root, 0, REMOTE_SCAN_DEPTH, remoteTypes)
                for _, remote in ipairs(remotes) do
                    if remote.ClassName == "RemoteEvent" or remote.ClassName == "UnreliableRemoteEvent" then
                        local oldFire = remote.FireServer
                        remote.FireServer = function(self, ...)
                            local args = {...}
                            local strArgs = ""
                            for i = 1, math.min(#args, 5) do
                                local v = args[i]
                                if type(v) == "userdata" then
                                    strArgs = strArgs .. tostring(v) .. ", "
                                elseif type(v) == "string" then
                                    strArgs = strArgs .. string.format("%q, ", v)
                                else
                                    strArgs = strArgs .. tostring(v) .. ", "
                                end
                            end
                            if #args > 5 then strArgs = strArgs .. "..." end
                            strArgs = strArgs:sub(1, -3)
                            rspyBatchId = rspyBatchId + 1
                            local now = GetTimestamp()
                            table.insert(rspyRecords, {
                                time = now,
                                name = remote.Name,
                                path = "",
                                direction = "C→S",
                                params = strArgs,
                                className = remote.ClassName,
                                batchId = rspyBatchId
                            })
                            if #rspyRecords > MAX_RSPY_RECORDS then
                                table.remove(rspyRecords, 1)
                            end
                            countLabel.Text = string.format("记录: %d (批次: %d)", #rspyRecords, rspyBatchId)
                            rspyRefreshNeeded = true
                            pcall(function()
                                oldFire(self, ...)
                            end)
                        end
                        table.insert(rspyHooks, {remote = remote, type = "FireServer"})
                    end

                    if remote.ClassName == "RemoteEvent" or remote.ClassName == "UnreliableRemoteEvent" then
                        local conn
                        conn = remote.OnClientEvent:Connect(function(...)
                            if not rspyRunning then
                                if conn then conn:Disconnect() end
                                return
                            end
                            local args = {...}
                            local strArgs = ""
                            for i = 1, math.min(#args, 5) do
                                local v = args[i]
                                if type(v) == "userdata" then
                                    strArgs = strArgs .. tostring(v) .. ", "
                                elseif type(v) == "string" then
                                    strArgs = strArgs .. string.format("%q, ", v)
                                else
                                    strArgs = strArgs .. tostring(v) .. ", "
                                end
                            end
                            if #args > 5 then strArgs = strArgs .. "..." end
                            strArgs = strArgs:sub(1, -3)
                            rspyBatchId = rspyBatchId + 1
                            local now = GetTimestamp()
                            table.insert(rspyRecords, {
                                time = now,
                                name = remote.Name,
                                path = "",
                                direction = "S→C",
                                params = strArgs,
                                className = remote.ClassName,
                                batchId = rspyBatchId
                            })
                            if #rspyRecords > MAX_RSPY_RECORDS then
                                table.remove(rspyRecords, 1)
                            end
                            countLabel.Text = string.format("记录: %d (批次: %d)", #rspyRecords, rspyBatchId)
                            rspyRefreshNeeded = true
                        end)
                        table.insert(rspyHooks, {remote = remote, type = "OnClientEvent", conn = conn})
                    end

                    if remote.ClassName == "RemoteFunction" then
                        local oldInvoke = remote.InvokeServer
                        remote.InvokeServer = function(self, ...)
                            local args = {...}
                            local strArgs = ""
                            for i = 1, math.min(#args, 5) do
                                local v = args[i]
                                if type(v) == "userdata" then
                                    strArgs = strArgs .. tostring(v) .. ", "
                                elseif type(v) == "string" then
                                    strArgs = strArgs .. string.format("%q, ", v)
                                else
                                    strArgs = strArgs .. tostring(v) .. ", "
                                end
                            end
                            if #args > 5 then strArgs = strArgs .. "..." end
                            strArgs = strArgs:sub(1, -3)
                            rspyBatchId = rspyBatchId + 1
                            local now = GetTimestamp()
                            table.insert(rspyRecords, {
                                time = now,
                                name = remote.Name,
                                path = "",
                                direction = "C→S",
                                params = "[Invoke] " .. strArgs,
                                className = remote.ClassName,
                                batchId = rspyBatchId
                            })
                            if #rspyRecords > MAX_RSPY_RECORDS then
                                table.remove(rspyRecords, 1)
                            end
                            countLabel.Text = string.format("记录: %d (批次: %d)", #rspyRecords, rspyBatchId)
                            rspyRefreshNeeded = true
                            pcall(function()
                                return oldInvoke(self, ...)
                            end)
                        end
                        table.insert(rspyHooks, {remote = remote, type = "InvokeServer"})
                    end
                end
            end
        end
        rspyRunning = true
        statusLabel.Text = string.format("状态: 运行中 (%d 个 Remote 已 Hook)", #rspyHooks)
    end

    local function UnhookAllRemotes()
        rspyRunning = false
        for _, hook in ipairs(rspyHooks) do
            if hook.type == "OnClientEvent" and hook.conn then
                pcall(function() hook.conn:Disconnect() end)
            end
        end
        rspyHooks = {}
        statusLabel.Text = "状态: 已停止"
    end

    MakeButton(container, "▶ 开始嗅探", UDim2.new(0, 120, 0, 34), UDim2.new(0, 5, 0, 90), Color3.fromRGB(50, 80, 50),
        function()
            if rspyRunning then return end
            statusLabel.Text = "正在 Hook..."
            task.delay(0.1, function()
                HookAllRemotes()
                ShowNotification("RSPY", "数据包嗅探已启动")
            end)
        end)

    MakeButton(container, "⏹ 停止嗅探", UDim2.new(0, 120, 0, 34), UDim2.new(0, 130, 0, 90), Color3.fromRGB(80, 40, 40),
        function()
            UnhookAllRemotes()
            ShowNotification("RSPY", "数据包嗅探已停止")
        end)

    MakeButton(container, "清空记录", UDim2.new(0, 100, 0, 34), UDim2.new(0, 255, 0, 90), Color3.fromRGB(60, 60, 40),
        function()
            rspyRecords = {}
            countLabel.Text = "记录: 0"
            rspyBatchId = 0
            ClearScrollFrame(sf)
        end)

    if rspyRefreshConn then rspyRefreshConn:Disconnect() end
    rspyRefreshConn = RunService and RunService.RenderStepped:Connect(function()
        if rspyRefreshNeeded then
            rspyRefreshNeeded = false
            RefreshRSPYDisplay()
        end
    end)
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

-- 复制到剪贴板（兼容多种注入器）
local function CopyToClipboard(text)
    local ok = false
    if setclipboard then
        ok = pcall(setclipboard, text)
    end
    if not ok and toclipboard then
        ok = pcall(toclipboard, text)
    end
end

local function BuildMainGUI()
    local guiParent = GetGUIParent()
    if not guiParent then
        if not Players or not Players.LocalPlayer then
            ShowNotification("DeltaExplorer", "GUI 挂载失败: 无可用父容器", 5)
            return false
        end
        guiParent = Players.LocalPlayer:FindFirstChild("PlayerGui")
        if not guiParent then
            ShowNotification("DeltaExplorer", "GUI 挂载失败: PlayerGui 不可用", 5)
            return false
        end
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "DeltaExplorer_v2"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 100

    local success = pcall(function()
        gui.Parent = guiParent
    end)
    if not success then
        ShowNotification("DeltaExplorer", "GUI 挂载失败: 无法设置父级", 5)
        return false
    end

    DE_GUI = gui

    local viewport = Workspace and Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
    local mainW = math.min(420, viewport.X - 20)
    local mainH = math.min(560, viewport.Y - 40)

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

    MakeLabel(titleBar, "🔍 " .. APP_NAME, UDim2.new(1, -50, 1, 0), UDim2.new(0, 12, 0, 0), Color3.fromRGB(255, 255, 255), 16, Enum.TextXAlignment.Left)

    -- 最小化
    MakeButton(titleBar, "—", UDim2.new(0, 30, 0, 28), UDim2.new(1, -68, 0, 5), Color3.fromRGB(50, 50, 60),
        function()
            gui.Enabled = false
        end)

    -- 关闭
    MakeButton(titleBar, "✕", UDim2.new(0, 30, 0, 28), UDim2.new(1, -34, 0, 5), Color3.fromRGB(80, 30, 30),
        function()
            for _, c in ipairs(monitorConnections) do
                pcall(function() c:Disconnect() end)
            end
            monitorConnections = {}
            if rspyRefreshConn then rspyRefreshConn:Disconnect() rspyRefreshConn = nil end
            if rspyRunning then UnhookAllRemotes() end
            if DE_GUI then DE_GUI:Destroy() end
            DE_GUI = nil
            DE_MainUI = nil
        end)

    -- 拖拽功能 (触摸兼容)
    local dragging = false
    local dragInput, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    titleBar.InputChanged:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) and dragging then
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
        {"📊", "元数据"},
        {"📁", "浏览器"},
        {"🔢", "值扫描"},
        {"📡", "Remote"},
        {"👁", "监控"},
        {"🔍", "搜索"},
        {"🎣", "RSPY"},
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
    local currentTabIndex = 1

    local function SwitchTab(idx)
        currentTabIndex = idx
        for i, btn in ipairs(tabButtons) do
            btn.BackgroundColor3 = (i == idx) and Color3.fromRGB(60, 80, 120) or Color3.fromRGB(35, 35, 45)
        end
        ClearScrollFrame(contentArea)
        local tabName = tabData[idx][2]
        if tabName == "元数据" then
            BuildMetadata(contentArea)
        elseif tabName == "浏览器" then
            browserState.currentRoot = browserState.currentRoot or Workspace
            BuildBrowserTree(contentArea, browserState.currentRoot, 1)
        elseif tabName == "值扫描" then
            BuildValueScanner(contentArea)
        elseif tabName == "Remote" then
            BuildRemoteDiscovery(contentArea)
        elseif tabName == "监控" then
            BuildMonitor(contentArea)
        elseif tabName == "搜索" then
            BuildSearch(contentArea)
        elseif tabName == "RSPY" then
            BuildRSPY(contentArea)
        end
    end

    for i, td in ipairs(tabData) do
        local btn = MakeButton(tabBar, td[1] .. " " .. td[2], UDim2.new(0, 0, 0, 30), nil, Color3.fromRGB(35, 35, 45),
            function()
                SwitchTab(i)
            end)
        btn.AutomaticSize = Enum.AutomaticSize.X
        btn.TextSize = 12
        table.insert(tabButtons, btn)
    end

    -- 底部状态栏
    MakeLabel(main, "DeltaExplorer " .. VERSION .. " | Delta Injector 专用", UDim2.new(1, -12, 0, 20), UDim2.new(0, 6, 1, -22), Color3.fromRGB(120, 120, 130), 11, Enum.TextXAlignment.Center)

    -- 默认显示第一个标签
    SwitchTab(1)
    return true
end

-- =========================== 启动 ===========================
ShowNotification("DeltaExplorer", "正在加载 " .. VERSION .. " ...", 2)

task.delay(0.5, function()
    pcall(BuildMainGUI)
end)

--[[
DeltaExplorer v4
GameId: 通用
功能: Info面板 / Instance浏览器 / Remote抓包
版本: v4.0
兼容: Delta Injector (标准 UNC)
结构: 纯顶层代码, 零外部依赖
--]]
local function svc(n) local s,e = pcall(game.GetService,game,n) return s and e or nil end
local Players = svc("Players")
local StarterGui = svc("StarterGui")
local CoreGui = svc("CoreGui")
local RunService = svc("RunService")
pcall(function()
    StarterGui:SetCore("SendNotification", {Title = "DeltaExplorer v4", Text = "Loading", Duration = 2})
end)
local lp = Players.LocalPlayer
if not lp then lp = Players:FindFirstChild("LocalPlayer") end
if not lp then return end
local pg = lp:FindFirstChild("PlayerGui")
if not pg then return end
local gui = Instance.new("ScreenGui")
gui.Name = "DeltaExplorerV4"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 100
local mountOk = pcall(function() gui.Parent = CoreGui end)
if not mountOk then
    local ok = pcall(function() gui.Parent = pg end)
    if not ok then gui:Destroy(); return end
end
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 400, 0, 480)
main.Position = UDim2.new(0.5, -200, 0.5, -240)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = main
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
titleBar.BorderSizePixel = 0
titleBar.Parent = main
local titleBarCorner = Instance.new("UICorner")
titleBarCorner.CornerRadius = UDim.new(0, 8)
titleBarCorner.Parent = titleBar
local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -40, 1, 0)
titleText.Position = UDim2.new(0, 10, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "DeltaExplorer v4"
titleText.TextColor3 = Color3.fromRGB(255, 200, 100)
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Font = Enum.Font.SourceSansBold
titleText.TextSize = 16
titleText.Parent = titleBar
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -28, 0, 3)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.AutoButtonColor = false
closeBtn.Parent = titleBar
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)
local dragging = false
local dragStart = nil
local frameStart = nil
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; frameStart = main.Position
    end
end)
titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X, frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
    end
end)
titleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 28)
tabBar.Position = UDim2.new(0, 0, 0, 30)
tabBar.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
tabBar.BorderSizePixel = 0
tabBar.Parent = main
local tabNames = {"Info", "Browser", "RSPY"}
local tabButtons = {}
local tabPanels = {}
local tabColors = {Color3.fromRGB(55, 55, 75), Color3.fromRGB(50, 60, 75), Color3.fromRGB(60, 50, 70)}
local tabActiveColor = Color3.fromRGB(70, 70, 95)
for i = 1, 3 do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 133, 1, 0)
    btn.Position = UDim2.new(0, (i - 1) * 134, 0, 0)
    btn.BackgroundColor3 = tabColors[i]
    btn.Text = tabNames[i]
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.TextSize = 14
    btn.Font = Enum.Font.SourceSans
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.Parent = tabBar
    tabButtons[i] = btn
    local panel = Instance.new("ScrollingFrame")
    panel.Size = UDim2.new(1, 0, 1, -58)
    panel.Position = UDim2.new(0, 0, 0, 58)
    panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    panel.BorderSizePixel = 0
    panel.ScrollBarThickness = 6
    panel.CanvasSize = UDim2.new(0, 0, 0, 0)
    panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
    panel.Visible = (i == 1)
    panel.Parent = main
    tabPanels[i] = panel
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.Parent = panel
end
tabButtons[1].BackgroundColor3 = tabActiveColor
for i = 1, 3 do
    local idx = i
    tabButtons[i].MouseButton1Click:Connect(function()
        for j = 1, 3 do
            tabPanels[j].Visible = (j == idx)
            tabButtons[j].BackgroundColor3 = (j == idx) and tabActiveColor or tabColors[j]
        end
    end)
end
local infoPanel = tabPanels[1]
local infoItems = {{"Player", lp.Name}, {"UserId", tostring(lp.UserId)}, {"AccountAge", tostring(lp.AccountAge)}, {"PlaceId", tostring(game.PlaceId)}, {"GameId", tostring(game.GameId)}}
for _, item in ipairs(infoItems) do
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 0, 22)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = item[1] .. ": " .. item[2]
    label.TextColor3 = Color3.fromRGB(255, 200, 100)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.SourceSans
    label.TextSize = 14
    label.Parent = infoPanel
end
local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(1, -10, 0, 22)
fpsLabel.Position = UDim2.new(0, 5, 0, 0)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Text = "FPS: 0 | Memory: 0 MB"
fpsLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
fpsLabel.Font = Enum.Font.SourceSans
fpsLabel.TextSize = 14
fpsLabel.Parent = infoPanel
local frameCount = 0
local elapsed = 0
RunService.RenderStepped:Connect(function(dt)
    frameCount = frameCount + 1
    elapsed = elapsed + dt
    if elapsed >= 1 then
        local fps = math.floor(frameCount / elapsed + 0.5)
        local mem = string.format("%.1f", stats().TotalMemory / 1e6)
        fpsLabel.Text = "FPS: " .. tostring(fps) .. " | Memory: " .. mem .. " MB"
        frameCount = 0; elapsed = 0
    end
end)
local browserPanel = tabPanels[2]
local expandState = {}
local function buildTree(parent, obj, depth, maxDepth)
    if depth > maxDepth then return end
    local indent = string.rep("  ", depth)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 20)
    btn.BackgroundColor3 = Color3.fromRGB(28 + depth * 6, 28 + depth * 6, 38 + depth * 6)
    btn.BorderSizePixel = 0
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Text = indent .. "[" .. obj.ClassName .. "] " .. obj.Name
    btn.TextColor3 = Color3.fromRGB(200, 200, 210)
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 12
    btn.AutoButtonColor = false
    btn.Parent = parent
    local key = obj
    expandState[key] = false
    local childButtons = {}
    local function refreshChildren()
        for _, cb in ipairs(childButtons) do cb:Destroy() end
        childButtons = {}
        if expandState[key] then
            for _, child in ipairs(obj:GetChildren()) do
                local cb = buildTree(parent, child, depth + 1, maxDepth)
                if cb then table.insert(childButtons, cb) end
            end
        end
    end
    btn.MouseButton1Click:Connect(function()
        expandState[key] = not expandState[key]
        refreshChildren()
    end)
    return btn
end
for _, child in ipairs(game:GetChildren()) do buildTree(browserPanel, child, 0, 2) end
local rspyPanel = tabPanels[3]
local rspyMaxLines = 80
local rspyCount = 0
local function logRemote(direction, className, name, args)
    local text = "[" .. direction .. "] " .. className .. " -> " .. name
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 0, 16)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.SourceSans
    label.TextSize = 11
    label.TextWrapped = true
    if direction == "S" then
        label.TextColor3 = Color3.fromRGB(100, 200, 255)
    else
        label.TextColor3 = Color3.fromRGB(255, 150, 100)
    end
    label.Parent = rspyPanel
    rspyCount = rspyCount + 1
    if rspyCount > rspyMaxLines then
        for _, c in ipairs(rspyPanel:GetChildren()) do
            if c:IsA("TextLabel") then c:Destroy(); rspyCount = rspyCount - 1; break end
        end
    end
end
local remoteTypes = {"RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent"}
local function hookRemote(obj)
    if obj.ClassName == "RemoteFunction" then
        local orig = obj.InvokeServer
        obj.InvokeServer = function(self, ...)
            logRemote("S", obj.ClassName, obj.Name, {...})
            if orig then return orig(self, ...) end
        end
    elseif obj.ClassName == "RemoteEvent" or obj.ClassName == "UnreliableRemoteEvent" then
        local orig = obj.FireServer
        obj.FireServer = function(self, ...)
            logRemote("S", obj.ClassName, obj.Name, {...})
            if orig then return orig(self, ...) end
        end
    end
end
for _, obj in ipairs(game:GetDescendants()) do
    pcall(function()
        for _, rt in ipairs(remoteTypes) do
            if obj.ClassName == rt then hookRemote(obj) end
        end
    end)
end
game.DescendantAdded:Connect(function(obj)
    pcall(function()
        for _, rt in ipairs(remoteTypes) do
            if obj.ClassName == rt then hookRemote(obj) end
        end
    end)
end)
pcall(function()
    StarterGui:SetCore("SendNotification", {Title = "DeltaExplorer v4", Text = "Loaded", Duration = 2})
end)

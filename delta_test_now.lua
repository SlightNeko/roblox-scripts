-- 精简版 Delta 测试 - 无 wrapper，直接执行

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

-- 通知
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "Delta Explorer",
        Text = "正在加载...",
        Duration = 2
    })
end)

-- 等待 LocalPlayer
local lp = Players.LocalPlayer
if not lp then
    lp = Players:FindFirstChild("LocalPlayer") or Players.PlayerAdded:Wait()
end

-- 创建 GUI
local gui = Instance.new("ScreenGui")
gui.Name = "DeltaExplorerMain"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 100
gui.Parent = lp:WaitForChild("PlayerGui")

-- 简单菜单
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 350, 0, 200)
frame.Position = UDim2.new(0.5, -175, 0.5, -100)
frame.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
title.Text = "Delta Explorer v1.0"
title.TextColor3 = Color3.fromRGB(255, 200, 100)
title.TextSize = 18
title.Font = Enum.Font.SourceSansBold
title.Parent = frame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = title
-- 只保留上圆角
local titlePadding = Instance.new("UIPadding")
titlePadding.Parent = title

-- 按钮
local function MakeBtn(text, pos, color, cb)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 32)
    btn.Position = UDim2.new(0.05, 0, 0, pos)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.Font = Enum.Font.SourceSans
    btn.BorderSizePixel = 0
    btn.Parent = frame
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn
    btn.MouseButton1Click:Connect(cb)
    return btn
end

MakeBtn("🌲 对象浏览器", 50, Color3.fromRGB(40, 80, 60), function()
    StarterGui:SetCore("SendNotification", {Title="提示", Text="对象浏览器功能开发中", Duration=2})
end)

MakeBtn("🔍 值扫描器", 90, Color3.fromRGB(80, 60, 30), function()
    StarterGui:SetCore("SendNotification", {Title="提示", Text="值扫描器功能开发中", Duration=2})
end)

MakeBtn("📡 Remote 发现", 130, Color3.fromRGB(40, 50, 90), function()
    StarterGui:SetCore("SendNotification", {Title="提示", Text="Remote 发现功能开发中", Duration=2})
end)

MakeBtn("🕵️ RSPY 抓包", 170, Color3.fromRGB(70, 30, 50), function()
    StarterGui:SetCore("SendNotification", {Title="提示", Text="RSPY 抓包功能开发中", Duration=2})
end)

-- 通知
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "✅ Delta Explorer",
        Text = "加载成功！",
        Duration = 2
    })
end)

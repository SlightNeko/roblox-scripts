-- Delta 兼容性测试 v1
-- 测试: 纯顶层代码，无 emoji，极小体积

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

StarterGui:SetCore("SendNotification", {
    Title = "测试1",
    Text = "启动通知正常",
    Duration = 2
})

local lp = Players.LocalPlayer
if not lp then
    lp = Players:FindFirstChild("LocalPlayer")
end
if not lp then return end

local pg = lp:FindFirstChild("PlayerGui")
if not pg then return end

local gui = Instance.new("ScreenGui")
gui.Name = "DeltaTestGUI"
gui.ResetOnSpawn = false
gui.Parent = pg

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 380, 0, 400)
main.Position = UDim2.new(0.5, -190, 0.5, -200)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
main.BackgroundTransparency = 0
main.BorderSizePixel = 0
main.Parent = gui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", main).Color = Color3.fromRGB(50, 50, 65)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
title.Text = "Delta Explorer v3"
title.TextColor3 = Color3.fromRGB(255, 200, 100)
title.TextSize = 18
title.Font = Enum.Font.SourceSansBold
title.Parent = main
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 26)
closeBtn.Position = UDim2.new(1, -34, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(70, 30, 30)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = title
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
closeBtn.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

local function MakeTab(name, y, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 30)
    btn.Position = UDim2.new(0.05, 0, 0, y)
    btn.BackgroundColor3 = color
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.Font = Enum.Font.SourceSans
    btn.BorderSizePixel = 0
    btn.Parent = main
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

MakeTab("元数据面板", 50, Color3.fromRGB(40, 50, 70)).MouseButton1Click:Connect(function()
    StarterGui:SetCore("SendNotification", {Title = "功能", Text = "元数据面板", Duration = 2})
end)

MakeTab("Instance 浏览器", 90, Color3.fromRGB(40, 70, 50)).MouseButton1Click:Connect(function()
    StarterGui:SetCore("SendNotification", {Title = "功能", Text = "Instance 浏览器", Duration = 2})
end)

MakeTab("Remote 发现", 130, Color3.fromRGB(50, 50, 80)).MouseButton1Click:Connect(function()
    StarterGui:SetCore("SendNotification", {Title = "功能", Text = "Remote 发现", Duration = 2})
end)

MakeTab("RSPY 抓包", 170, Color3.fromRGB(70, 40, 50)).MouseButton1Click:Connect(function()
    StarterGui:SetCore("SendNotification", {Title = "功能", Text = "RSPY 抓包", Duration = 2})
end)

MakeTab("实时监控", 210, Color3.fromRGB(50, 60, 60)).MouseButton1Click:Connect(function()
    StarterGui:SetCore("SendNotification", {Title = "功能", Text = "实时监控", Duration = 2})
end)

MakeTab("对象搜索", 250, Color3.fromRGB(60, 50, 40)).MouseButton1Click:Connect(function()
    StarterGui:SetCore("SendNotification", {Title = "功能", Text = "对象搜索", Duration = 2})
end)

StarterGui:SetCore("SendNotification", {
    Title = "测试通过",
    Text = "GUI 正常显示",
    Duration = 2
})

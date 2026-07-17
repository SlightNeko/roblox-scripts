--[[
    Death Ball - UI Menu Script
    Author: Chronix (rewritten by Hermes)
    Executor: Delta / Standard UNC
    Features:
      - Auto Parry toggle
      - Ball lock status
      - Ball distance display
      - Draggable menu
      - Minimize / restore
]]

if getgenv().DeathBallMenuLoaded then
    warn("Deathball Menu already loaded!")
    return
end
getgenv().DeathBallMenuLoaded = true

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local AutoParry = false
local MenuVisible = true

-- Helper: safe coregui parent
local function GetParent()
    local ok, CoreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok and CoreGui then
        return CoreGui
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeathBallMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = GetParent()
pcall(function() syn.protect_gui(ScreenGui) end)

-- Main window -----------------------------------------------------
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 210)
MainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
MainFrame.BorderSizePixel = 0
MainFrame.Active = false
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

-- Title bar (drag target) ----------------------------------------
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 32)
TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -70, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Death Ball Menu"
TitleLabel.TextColor3 = Color3.new(1, 1, 1)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 16
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

-- Minimize button
local MinButton = Instance.new("TextButton")
MinButton.Size = UDim2.new(0, 26, 0, 26)
MinButton.Position = UDim2.new(1, -56, 0.5, -13)
MinButton.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
MinButton.Text = "-"
MinButton.TextColor3 = Color3.new(1, 1, 1)
MinButton.Font = Enum.Font.GothamBold
MinButton.TextSize = 18
MinButton.Parent = TitleBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 8)
MinCorner.Parent = MinButton

-- Close / minimize button (mobile friendly)
local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 26, 0, 26)
CloseButton.Position = UDim2.new(1, -26, 0.5, -13)
CloseButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.new(1, 1, 1)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 14
CloseButton.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = CloseButton

-- Content area -----------------------------------------------
local ContentFrame = Instance.new("ScrollingFrame")
ContentFrame.Size = UDim2.new(1, 0, 1, -32)
ContentFrame.Position = UDim2.new(0, 0, 0, 32)
ContentFrame.BackgroundTransparency = 1
ContentFrame.BorderSizePixel = 0
ContentFrame.ScrollBarThickness = 3
ContentFrame.Parent = MainFrame

local ContentList = Instance.new("UIListLayout")
ContentList.Parent = ContentFrame
ContentList.Padding = UDim.new(0, 8)
ContentList.HorizontalAlignment = Enum.HorizontalAlignment.Center
ContentList.SortOrder = Enum.SortOrder.LayoutOrder

-- Helper: feature row with toggle ----------------------------
local function MakeFeatureRow(text, state, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -16, 0, 36)
    Row.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
    Row.BorderSizePixel = 0
    Row.Parent = ContentFrame

    local RowCorner = Instance.new("UICorner")
    RowCorner.CornerRadius = UDim.new(0, 8)
    RowCorner.Parent = Row

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.6, 0, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.new(1, 1, 1)
    Label.Font = Enum.Font.GothamSemibold
    Label.TextSize = 15
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.Parent = Row

    local Toggle = Instance.new("TextButton")
    Toggle.Size = UDim2.new(0, 54, 0, 28)
    Toggle.Position = UDim2.new(1, -64, 0.5, -14)
    Toggle.BackgroundColor3 = state and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(200, 80, 80)
    Toggle.Text = state and "ON" or "OFF"
    Toggle.TextColor3 = Color3.new(1, 1, 1)
    Toggle.Font = Enum.Font.GothamBold
    Toggle.TextSize = 14
    Toggle.Parent = Row

    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(0, 8)
    ToggleCorner.Parent = Toggle

    Toggle.MouseButton1Click:Connect(function()
        callback()
        if state() then
            Toggle.Text = "ON"
            Toggle.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
        else
            Toggle.Text = "OFF"
            Toggle.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
        end
    end)

    return Row
end

MakeFeatureRow("Auto Parry", function() return AutoParry end, function()
    AutoParry = not AutoParry
end)

-- Status display ---------------------------------------------
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -16, 0, 22)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Initializing..."
StatusLabel.TextColor3 = Color3.fromRGB(210, 210, 225)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 13
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Position = UDim2.new(0, 12, 0, 0)
StatusLabel.Parent = ContentFrame

local DistanceLabel = Instance.new("TextLabel")
DistanceLabel.Size = UDim2.new(1, -16, 0, 22)
DistanceLabel.BackgroundTransparency = 1
DistanceLabel.Text = "Distance: --"
DistanceLabel.TextColor3 = Color3.fromRGB(210, 210, 225)
DistanceLabel.Font = Enum.Font.Gotham
DistanceLabel.TextSize = 13
DistanceLabel.TextXAlignment = Enum.TextXAlignment.Left
DistanceLabel.Position = UDim2.new(0, 12, 0, 0)
DistanceLabel.Parent = ContentFrame

-- Unload button ---------------------------------------------
local UnloadButton = Instance.new("TextButton")
UnloadButton.Size = UDim2.new(1, -16, 0, 28)
UnloadButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
UnloadButton.Text = "Unload"
UnloadButton.TextColor3 = Color3.new(1, 1, 1)
UnloadButton.Font = Enum.Font.GothamBold
UnloadButton.TextSize = 14
UnloadButton.Parent = ContentFrame

local UnloadCorner = Instance.new("UICorner")
UnloadCorner.CornerRadius = UDim.new(0, 8)
UnloadCorner.Parent = UnloadButton

-- Restore button (shown when minimized) --------------------
local RestoreButton = Instance.new("TextButton")
RestoreButton.Size = UDim2.new(0, 90, 0, 32)
RestoreButton.Position = UDim2.new(0.5, -45, 1, -40)
RestoreButton.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
RestoreButton.Text = "Restore"
RestoreButton.TextColor3 = Color3.new(1, 1, 1)
RestoreButton.Font = Enum.Font.GothamBold
RestoreButton.TextSize = 14
RestoreButton.Visible = false
RestoreButton.Parent = ScreenGui

local RestoreCorner = Instance.new("UICorner")
RestoreCorner.CornerRadius = UDim.new(0, 8)
RestoreCorner.Parent = RestoreButton

-- Drag logic --------------------------------------------------
local Dragging = false
local DragStart = Vector2.new()
local StartPos = UDim2.new()

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if input.Object == TitleBar then
            Dragging = true
            DragStart = input.Position
            StartPos = MainFrame.Position
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if Dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - DragStart
        MainFrame.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + delta.X, StartPos.Y.Scale, StartPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        Dragging = false
    end
end)

-- Minimize / Restore ----------------------------------------
local function MinimizeMenu()
    MainFrame.Visible = false
    RestoreButton.Visible = true
    MenuVisible = false
end

local function RestoreMenu()
    MainFrame.Visible = true
    RestoreButton.Visible = false
    MenuVisible = true
end

MinButton.MouseButton1Click:Connect(MinimizeMenu)
CloseButton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    getgenv().DeathBallMenuLoaded = false
end)
RestoreButton.MouseButton1Click:Connect(RestoreMenu)

-- Unload -----------------------------------------------------
UnloadButton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    getgenv().DeathBallMenuLoaded = false
end)

-- Game logic -------------------------------------------------
local function FindBall()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj.Name == "Part" and obj:IsA("BasePart") then
            return obj
        end
    end
    return nil
end

task.spawn(function()
    while getgenv().DeathBallMenuLoaded do
        task.wait(0.1)
        local char = LocalPlayer.Character
        if not char then
            StatusLabel.Text = "Status: No Character"
            DistanceLabel.Text = "Distance: --"
        else
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then
                StatusLabel.Text = "Status: No HRP"
                DistanceLabel.Text = "Distance: --"
            else
                local ball = FindBall()
                if not ball then
                    StatusLabel.Text = "Status: Waiting"
                    DistanceLabel.Text = "Distance: --"
                else
                    local pos = hrp.CFrame.Position
                    local bpos = ball.CFrame.Position
                    local dx = bpos.X - pos.X
                    local dy = bpos.Y - pos.Y
                    local dz = bpos.Z - pos.Z
                    local dist = math.sqrt(dx*dx + dy*dy + dz*dz)

                    local isLocked = false
                    local hl = ball:FindFirstChild("Highlight")
                    if hl and hl:IsA("Highlight") then
                        isLocked = hl.FillColor == Color3.new(1, 0, 0)
                    end

                    StatusLabel.Text = isLocked and "Status: LOCKED" or "Status: Not Locked"
                    StatusLabel.TextColor3 = isLocked and Color3.fromRGB(238, 17, 17) or Color3.fromRGB(17, 238, 17)
                    DistanceLabel.Text = "Distance: " .. string.format("%.0f", dist)

                    if AutoParry and isLocked and dist < 15 then
                        VirtualInputManager:SendKeyEvent(true, "F", false, game)
                    end
                end
            end
        end
    end
end)

-- Startup feedback -------------------------------------------
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "Death Ball",
        Text = "Menu loaded",
        Duration = 2
    })
end)

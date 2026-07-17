--[[
DeltaExplorer v3 -- 微型注入脚本 (200行内)
GameId: 通用
功能: 元数据面板 / Instance浏览器 / RSPY抓包
版本: v3.0
兼容: 标准 UNC 注入器 (Delta / Ninja 等)
结构: 纯顶层代码，零外部依赖
--]]
local P,R,S,G = pcall(game.GetService,game,"Players")and game:GetService("Players"),pcall(game.GetService,game,"RunService")and game:GetService("RunService"),pcall(game.GetService,game,"StarterGui")and game:GetService("StarterGui"),game
local L = P.LocalPlayer
local g = Instance.new("ScreenGui")
g.Name,g.ResetOnSpawn,g.ZIndexBehavior,g.DisplayOrder = "DeltaExplorerV3",false,Enum.ZIndexBehavior.Sibling,100
g.Parent = L:WaitForChild("PlayerGui")
local m = Instance.new("Frame",g)
m.Size,m.Position,m.BackgroundColor3,m.BorderSizePixel = UDim2.new(0,380,0,500),UDim2.new(0.5,-190,0.5,-250),Color3.fromRGB(22,22,30),0
local tb = Instance.new("Frame",m)
tb.Size,tb.BackgroundColor3,tb.BorderSizePixel = UDim2.new(1,0,0,28),Color3.fromRGB(18,18,26),0
local tt = Instance.new("TextLabel",tb)
tt.Size,tt.Position,tt.BackgroundTransparency,tt.Text,tt.TextColor3,tt.TextXAlignment,tt.Font,tt.TextSize = UDim2.new(1,-10,1,0),UDim2.new(0,10,0,0),1,"DeltaExplorer v3",Color3.fromRGB(255,200,100),Enum.TextXAlignment.Left,Enum.Font.SourceSansBold,16
local d,ds,sp
tb.InputBegan:Connect(function(i)
if i.UserInputType==Enum.UserInputType.MouseButton1 then d=true ds=i.Position sp=m.Position
i.Changed:Connect(function()if i.UserInputState==Enum.UserInputState.End then d=false end end)end end)
tb.InputChanged:Connect(function(i)
if i.UserInputType==Enum.UserInputType.MouseMovement and d then m.Position=UDim2.new(sp.X.Scale,sp.X.Offset+i.X-ds.X,sp.Y.Scale,sp.Y.Offset+i.Y-ds.Y)end end)
local bt,bl,bn = {},{},{"Metadata","Browser","RSPY"}
local bb = Instance.new("Frame",m)
bb.Size,bb.Position,bb.BackgroundColor3,bb.BorderSizePixel = UDim2.new(1,0,0,26),UDim2.new(0,0,0,28),Color3.fromRGB(28,28,38),0
for i=1,3 do
local b = Instance.new("TextButton",bb)
b.Size,b.Position,b.BackgroundColor3,b.BorderSizePixel,b.Text,b.TextColor3,b.Font,b.TextSize = UDim2.new(0,126,1,0),UDim2.new(0,(i-1)*127,0,0),Color3.fromRGB(35,35,50),0,bn[i],Color3.fromRGB(200,200,200),Enum.Font.SourceSans,14
bt[i]=b end
for i=1,3 do
local p = Instance.new("Frame",m)
p.Size,p.Position,p.BackgroundColor3,p.BorderSizePixel,p.Visible = UDim2.new(1,0,1,-54),UDim2.new(0,0,0,54),Color3.fromRGB(22,22,30),0,i==1
bl[i]=p end
bt[1].BackgroundColor3 = Color3.fromRGB(50,50,70)
for i=1,3 do bt[i].MouseButton1Click:Connect(function()for j=1,3 do bl[j].Visible=i==j bt[j].BackgroundColor3=i==j and Color3.fromRGB(50,50,70)or Color3.fromRGB(35,35,50)end end)end
local mp = bl[1]
local mi = {{"Player",L.Name},{"UserId",tostring(L.UserId)},{"AccountAge",tostring(L.AccountAge)},{"PlaceId",tostring(game.PlaceId)},{"GameId",tostring(game.GameId)}}
for i,d in ipairs(mi)do
local l = Instance.new("TextLabel",mp)
l.Size,l.Position,l.BackgroundTransparency,l.Text,l.TextColor3,l.TextXAlignment,l.Font,l.TextSize = UDim2.new(1,-10,0,22),UDim2.new(0,5,0,5+(i-1)*24),1,d[1]..": "..d[2],Color3.fromRGB(255,200,100),Enum.TextXAlignment.Left,Enum.Font.SourceSans,14 end
local fl = Instance.new("TextLabel",mp)
fl.Size,fl.Position,fl.BackgroundTransparency,fl.Text,fl.TextColor3,fl.TextXAlignment,fl.Font,fl.TextSize = UDim2.new(1,-10,0,22),UDim2.new(0,5,0,5+#mi*24),1,"FPS: 0 | Memory: 0 MB",Color3.fromRGB(255,200,100),Enum.TextXAlignment.Left,Enum.Font.SourceSans,14
local fc,el = 0,0
R.RenderStepped:Connect(function(dt)fc=fc+1 el=el+dt if el>=1 then fl.Text="FPS: "..tostring(math.floor(fc/el+0.5)).." | Memory: "..string.format("%.1f",stats().TotalMemory/1e6).." MB" fc=0 el=0 end end)
local bp = bl[2]
local bs = Instance.new("ScrollingFrame",bp)
bs.Size,bs.BackgroundColor3,bs.BorderSizePixel,bs.ScrollBarThickness,bs.CanvasSize = UDim2.new(1,0,1,0),Color3.fromRGB(22,22,30),0,8,UDim2.new(0,0,0,0)
Instance.new("UIListLayout",bs).Padding = UDim.new(0,2)
local ex = {}
local function bw(p,o,id,d)
if d>2 then return end
local r = Instance.new("TextButton",bs)
r.Size,r.BackgroundColor3,r.BorderSizePixel,r.TextXAlignment,r.Text,r.TextColor3,r.Font,r.TextSize = UDim2.new(1,-10,0,20),Color3.fromRGB(30+d*8,30+d*8,40+d*8),0,Enum.TextXAlignment.Left,string.rep("  ",id).."["..o.ClassName.."] "..o.Name,Color3.fromRGB(200,200,210),Enum.Font.SourceSans,12
local k = o; ex[k]=false; local ks={}
local function rf()for _,x in ipairs(ks)do x:Destroy()end ks={}if ex[k]then for _,c in ipairs(o:GetChildren())do local kr=bw(p,c,id+1,d+1)if kr then table.insert(ks,kr)end end end end
r.MouseButton1Click:Connect(function()ex[k]=not ex[k]rf()end)
return r end
for _,c in ipairs(G:GetChildren())do bw(bs,c,0,1)end
local rp = bl[3]
local rs = Instance.new("ScrollingFrame",rp)
rs.Size,rs.BackgroundColor3,rs.BorderSizePixel,rs.ScrollBarThickness,rs.CanvasSize,rs.AutomaticCanvasSize = UDim2.new(1,0,1,0),Color3.fromRGB(22,22,30),0,8,UDim2.new(0,0,0,0),Enum.AutomaticSize.Y
Instance.new("UIListLayout",rs).Padding = UDim.new(0,1)
local function lp(d,c,n,a)
local s=tostring(a):sub(1,100)if #tostring(a)>100 then s=s.."..."end
local l = Instance.new("TextLabel",rs)
l.Size,l.BackgroundTransparency,l.Text,l.TextColor3,l.TextXAlignment,l.Font,l.TextSize,l.TextWrapped = UDim2.new(1,-10,0,16),1,"["..d.."] "..c.." -> "..n.." ("..s..")",d=="S"and Color3.fromRGB(100,200,255)or Color3.fromRGB(255,150,100),Enum.TextXAlignment.Left,Enum.Font.SourceSans,11,true
if #rs:GetChildren()>3 then for _,v in ipairs(rs:GetChildren())do if v:IsA("TextLabel")then v:Destroy()break end end end end
local rt = {"RemoteEvent","RemoteFunction","UnreliableRemoteEvent"}
for _,t in ipairs(rt)do
local function h(o)if o.ClassName~=t then return end
if o.ClassName=="RemoteFunction"then local f=o.InvokeServer o.InvokeServer=function(_,...)lp("S",o.ClassName,o.Name,{...})return f and f(o,...)end
else local f=o.FireServer o.FireServer=function(_,...)lp("S",o.ClassName,o.Name,{...})return f and f(o,...)end end end
for _,o in ipairs(G:GetDescendants())do pcall(h,o)end
G.DescendantAdded:Connect(function(o)pcall(h,o)end)end
S:SetCore("SendNotification",{Title="DeltaExplorer v3",Text="Loaded",Duration=2})

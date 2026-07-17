--[[DeltaExplorer v4.2
GameId: 通用
功能: 信息/浏览器/值扫描/监控/搜索/远程事件
版本: v4.2
兼容: Delta Injector (标准 UNC)
--]]
local S=function(n)local o,e=pcall(game.GetService,game,n);return o and e or nil end
local Pl=S("Players");local SG=S("StarterGui");local CG=S("CoreGui");local RS=S("RunService")
pcall(function()SG:SetCore("SendNotification",{Title="资源浏览器 v4.2",Text="加载中",Duration=2})end)
local lp=Pl.LocalPlayer;if not lp then lp=Pl:FindFirstChild("LocalPlayer")end;if not lp then return end
local pg=lp:FindFirstChild("PlayerGui");if not pg then return end
local gui=Instance.new("ScreenGui");gui.Name="DeltaExplorerV4";gui.ResetOnSpawn=false;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.DisplayOrder=100

local ok=pcall(function()gui.Parent=CG end)
if not ok then ok=pcall(function()gui.Parent=pg end);if not ok then gui:Destroy();return end end
local restoreBtn=nil
local function createRestore()
 if restoreBtn then return end
 restoreBtn=Instance.new("TextButton");restoreBtn.Size=UDim2.new(0,80,0,30);restoreBtn.Position=UDim2.new(0.5,-40,1,-45)
 restoreBtn.BackgroundColor3=Color3.fromRGB(40,40,55);restoreBtn.Text="还原";restoreBtn.TextColor3=Color3.fromRGB(255,255,255)
 restoreBtn.TextSize=14;restoreBtn.Font=Enum.Font.SourceSans;restoreBtn.AutoButtonColor=false;restoreBtn.Parent=gui
 local rc=Instance.new("UICorner",restoreBtn);rc.CornerRadius=UDim.new(0,6)
 restoreBtn.MouseButton1Click:Connect(function()
  gui.Visible=true
  if restoreBtn then restoreBtn:Destroy();restoreBtn=nil end
 end)
end
local m=Instance.new("Frame");m.Size=UDim2.new(0,400,0,500);m.Position=UDim2.new(0.5,-200,0.3,-150)
m.BackgroundColor3=Color3.fromRGB(20,20,28);m.BorderSizePixel=0;m.Active=true;m.Parent=gui
local mCorner=Instance.new("UICorner",m);mCorner.CornerRadius=UDim.new(0,8)
local tb=Instance.new("Frame",m);tb.Size=UDim2.new(1,0,0,30);tb.Position=UDim2.new(0,0,0,0)
tb.BackgroundColor3=Color3.fromRGB(14,14,20);tb.BorderSizePixel=0
local tbCorner=Instance.new("UICorner",tb);tbCorner.CornerRadius=UDim.new(0,8)

local tt=Instance.new("TextLabel",tb);tt.Size=UDim2.new(1,-40,1,0);tt.Position=UDim2.new(0,10,0,0)
tt.BackgroundTransparency=1;tt.Text="资源浏览器 v4.2";tt.TextColor3=Color3.fromRGB(255,200,100)
tt.TextXAlignment=Enum.TextXAlignment.Left;tt.Font=Enum.Font.SourceSansBold;tt.TextSize=16

local cx=Instance.new("TextButton",tb);cx.Size=UDim2.new(0,24,0,24);cx.Position=UDim2.new(1,-28,0,3)
cx.BackgroundColor3=Color3.fromRGB(180,40,40);cx.Text="X";cx.TextColor3=Color3.fromRGB(255,255,255)
cx.TextSize=14;cx.Font=Enum.Font.SourceSansBold;cx.AutoButtonColor=false;cx.BorderSizePixel=0
local cxCorner=Instance.new("UICorner",cx);cxCorner.CornerRadius=UDim.new(0,6)
cx.MouseButton1Click:Connect(function() gui.Visible=false;createRestore() end)

local drg=false;local ds;local fs
tb.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 then drg=true;ds=i.Position;fs=m.Position end end)
tb.InputChanged:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseMovement and drg then local d=i.Position-ds;m.Position=UDim2.new(fs.X.Scale,fs.X.Offset+d.X,fs.Y.Scale,fs.Y.Offset+d.Y)end end)
tb.InputEnded:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 then drg=false end end)

local bar=Instance.new("Frame",m);bar.Size=UDim2.new(1,0,0,28);bar.Position=UDim2.new(0,0,0,30)
bar.BackgroundColor3=Color3.fromRGB(26,26,36);bar.BorderSizePixel=0
local tns={"信息","浏览器","值扫描","监控","搜索","远程"};local tbs={};local tps={}
local tcs={Color3.fromRGB(55,55,75),Color3.fromRGB(50,60,75),Color3.fromRGB(55,70,55),Color3.fromRGB(70,55,55),Color3.fromRGB(65,55,70),Color3.fromRGB(55,55,70)};local tac=Color3.fromRGB(70,70,95)

for i=1,6 do
 local btn=Instance.new("TextButton",bar);btn.Size=UDim2.new(0,66,1,0);btn.Position=UDim2.new(0,(i-1)*66,0,0)
 btn.BackgroundColor3=tcs[i];btn.Text=tns[i];btn.TextColor3=Color3.fromRGB(200,200,200);btn.TextSize=11
 btn.Font=Enum.Font.SourceSans;btn.AutoButtonColor=false;btn.BorderSizePixel=0
 tbs[i]=btn
 local pan=Instance.new("ScrollingFrame",m);pan.Size=UDim2.new(1,0,1,-58);pan.Position=UDim2.new(0,0,0,58)
 pan.BackgroundColor3=Color3.fromRGB(20,20,28);pan.BorderSizePixel=0;pan.ScrollBarThickness=6
 pan.CanvasSize=UDim2.new(0,0,0,0);pan.AutomaticCanvasSize=Enum.AutomaticSize.Y;pan.Visible=(i==1)
 tps[i]=pan;local list=Instance.new("UIListLayout",pan);list.Padding=UDim.new(0,2)
end

tbs[1].BackgroundColor3=tac
for i=1,6 do local idx=i;tbs[i].MouseButton1Click:Connect(function()for j=1,6 do tps[j].Visible=(j==idx);tbs[j].BackgroundColor3=(j==idx)and tac or tcs[j]end end)end

local function L(pan,text,c)
 local lb=Instance.new("TextLabel",pan);lb.Size=UDim2.new(1,-10,0,22);lb.BackgroundTransparency=1
 lb.Text=text;lb.TextColor3=c or Color3.fromRGB(200,200,200);lb.TextXAlignment=Enum.TextXAlignment.Left
 lb.Font=Enum.Font.SourceSans;lb.TextSize=13;return lb
end

local ip=tps[1]
L(ip,"玩家: "..lp.Name,Color3.fromRGB(255,200,100))
L(ip,"用户ID: "..tostring(lp.UserId),Color3.fromRGB(255,200,100))
L(ip,"账号年龄: "..tostring(lp.AccountAge),Color3.fromRGB(255,200,100))
L(ip,"场所ID: "..tostring(game.PlaceId),Color3.fromRGB(255,200,100))
L(ip,"游戏ID: "..tostring(game.GameId),Color3.fromRGB(255,200,100))

local function roleInfo()
 local char=lp.Character;if char and char:FindFirstChild("Humanoid")then
  local hum=char:FindFirstChild("Humanoid")
  L(ip,"生命: "..tostring(math.floor(hum.Health)).."/"..tostring(hum.MaxHealth),Color3.fromRGB(100,255,100))
  L(ip,"速度: "..tostring(hum.WalkSpeed),Color3.fromRGB(100,255,100))
  L(ip,"跳跃: "..tostring(hum.JumpPower),Color3.fromRGB(100,255,100))
 else
  L(ip,"无角色",Color3.fromRGB(255,100,100))
 end
end

roleInfo()
lp.CharacterAdded:Connect(function()task.wait(1);roleInfo()end)

local fl=L(ip,"帧率: 0 | 内存: 0 MB",Color3.fromRGB(255,200,100));local fc=0;local el=0
RS.RenderStepped:Connect(function(dt)
 fc=fc+1;el=el+dt
 if el>=1 then
  local mem=0;pcall(function()mem=collectgarbage("count")or 0 end)
  fl.Text="帧率: "..tostring(math.floor(fc/el+0.5)).." | 内存: "..string.format("%.1f",mem/1024).." MB"
  fc=0;el=0
 end
end)

local bp=tps[2];local es={}
local function bt(pan,obj,depth,md)
 if depth>md then return end;local ind=string.rep("  ",depth)
 local btn=Instance.new("TextButton",pan);btn.Size=UDim2.new(1,-10,0,20);btn.BackgroundColor3=Color3.fromRGB(28+depth*6,28+depth*6,38+depth*6);btn.BorderSizePixel=0;btn.TextXAlignment=Enum.TextXAlignment.Left;btn.Text=ind.."["..obj.ClassName.."] "..obj.Name;btn.TextColor3=Color3.fromRGB(200,200,210);btn.Font=Enum.Font.SourceSans;btn.TextSize=12;btn.AutoButtonColor=false
 local k=obj;es[k]=false;local cbs={}
 local function rf()for _,cb in ipairs(cbs)do cb:Destroy()end;cbs={};if es[k]then for _,ch in ipairs(obj:GetChildren())do local cb=bt(pan,ch,depth+1,md)if cb then table.insert(cbs,cb)end end end end
 btn.MouseButton1Click:Connect(function()es[k]=not es[k];rf()end);return btn
end
for _,ch in ipairs(game:GetChildren())do bt(bp,ch,0,2)end
local vp=tps[3];local vcs={"NumberValue","IntValue","BoolValue","StringValue"}
local vh=L(vp,"按类扫描:",Color3.fromRGB(255,200,100))
local function doScan(cn)
 local kids={};for _,c in ipairs(vp:GetChildren())do if c:IsA("TextLabel")and c~=vh then table.insert(kids,c)end end
 for _,c in ipairs(kids)do c:Destroy()end;local n=0
 for _,ch in ipairs(game:GetDescendants())do
  if ch.ClassName==cn then local v=ch.Value;if type(v)=="boolean"then v=tostring(v)end;L(vp,"["..cn.."] "..ch.Name.." = "..tostring(v),Color3.fromRGB(100,200,255));n=n+1 end
 end
 if n==0 then L(vp,"未找到",Color3.fromRGB(255,150,100))else L(vp,"总计: "..tostring(n),Color3.fromRGB(255,200,100))end
end
for _,cn in ipairs(vcs)do
 local btn=Instance.new("TextButton",vp);btn.Size=UDim2.new(1,-10,0,24);btn.BackgroundColor3=Color3.fromRGB(45,55,70)
 btn.Text=cn;btn.TextColor3=Color3.fromRGB(200,200,200);btn.TextSize=12;btn.Font=Enum.Font.SourceSans
 btn.AutoButtonColor=false;btn.BorderSizePixel=0;local bCorner=Instance.new("UICorner",btn);bCorner.CornerRadius=UDim.new(0,6)
 btn.MouseButton1Click:Connect(function()doScan(cn)end)
end

local mp=tps[4]
local mh=L(mp,"自动监控角色状态:",Color3.fromRGB(255,200,100))
local sb=Instance.new("TextButton",mp);sb.Size=UDim2.new(1,-10,0,24);sb.BackgroundColor3=Color3.fromRGB(45,70,45)
sb.Text="开始自动监控角色";sb.TextColor3=Color3.fromRGB(200,200,200);sb.TextSize=13;sb.Font=Enum.Font.SourceSans
sb.AutoButtonColor=false;sb.BorderSizePixel=0;local sbCorner=Instance.new("UICorner",sb);sbCorner.CornerRadius=UDim.new(0,6)

local mc=nil;local charConn=nil;local childConn=nil;local monitoring=false

local function clearMonitor()
 for _,c in ipairs(mp:GetChildren())do if c:IsA("TextLabel") and c~=mh then c:Destroy()end end
end

local function stopMonitor(clear)
 monitoring=false
 if mc then mc:Disconnect();mc=nil end
 if charConn then charConn:Disconnect();charConn=nil end
 if childConn then childConn:Disconnect();childConn=nil end
 sb.Text="开始自动监控角色";sb.BackgroundColor3=Color3.fromRGB(45,70,45)
 if clear then clearMonitor() end
 L(mp,"已停止",Color3.fromRGB(255,200,100))
end

local function bindHumanoid(hum)
 if not monitoring then return end
 if mc then mc:Disconnect();mc=nil end
 L(mp,"监控中: Humanoid",Color3.fromRGB(100,255,100))
 sb.Text="停止";sb.BackgroundColor3=Color3.fromRGB(70,45,45)
 L(mp,"生命 = "..tostring(math.floor(hum.Health)),Color3.fromRGB(100,200,255))
 L(mp,"速度 = "..tostring(hum.WalkSpeed),Color3.fromRGB(100,200,255))
 L(mp,"跳跃 = "..tostring(hum.JumpPower),Color3.fromRGB(100,200,255))
 L(mp,"姿态 = "..tostring(hum.PlatformStand),Color3.fromRGB(100,200,255))
 mc=hum.Changed:Connect(function(prop)
  if not monitoring then return end
  local v=hum[prop];if type(v)=="boolean" then v=tostring(v)end
  L(mp,"["..tostring(prop).."] = "..tostring(v),Color3.fromRGB(100,200,255))
  if prop=="Health" then L(mp,"生命 = "..tostring(math.floor(v)),Color3.fromRGB(100,200,255))end
 end)
end

local function waitHumanoid(c)
 if not monitoring then return end
 L(mp,"等待 Humanoid 加载...",Color3.fromRGB(255,150,100))
 childConn=c.ChildAdded:Connect(function(ch)
  if not monitoring then return end
  if ch.ClassName=="Humanoid" then
   if childConn then childConn:Disconnect();childConn=nil end
   bindHumanoid(ch)
  end
 end)
 task.spawn(function()
  local w=c:WaitForChild("Humanoid",5)
  if w and w.ClassName=="Humanoid" and monitoring then
   if childConn then childConn:Disconnect();childConn=nil end
   bindHumanoid(w)
  elseif monitoring then
   stopMonitor(true)
  end
 end)
end

local function startMonitor()
 stopMonitor(false);monitoring=true
 sb.Text="停止";sb.BackgroundColor3=Color3.fromRGB(70,45,45)
 clearMonitor()
 local char=lp.Character
 if char then
  local hum=char:FindFirstChild("Humanoid")
  if hum then bindHumanoid(hum)else waitHumanoid(char)end
 else
  L(mp,"等待角色出现...",Color3.fromRGB(255,150,100))
  charConn=lp.CharacterAdded:Connect(function(c)
   if not monitoring then return end
   if charConn then charConn:Disconnect();charConn=nil end
   local hum=c:FindFirstChild("Humanoid")
   if hum then bindHumanoid(hum)else waitHumanoid(c)end
  end)
 end
end

sb.MouseButton1Click:Connect(function()
 if monitoring then stopMonitor(true)else startMonitor()end
end)
local sp=tps[5]
local sh=L(sp,"按名称或类搜索:",Color3.fromRGB(255,200,100))
local sb2=Instance.new("TextBox",sp);sb2.Size=UDim2.new(1,-10,0,24);sb2.BackgroundColor3=Color3.fromRGB(30,30,40)
sb2.TextColor3=Color3.fromRGB(200,200,200);sb2.PlaceholderText="搜索内容...";sb2.Text="";sb2.Font=Enum.Font.SourceSans;sb2.TextSize=13
local sb2Corner=Instance.new("UICorner",sb2);sb2Corner.CornerRadius=UDim.new(0,6)

local recentNames={"Humanoid","Part","Tool","RemoteEvent","RemoteFunction","BoolValue","IntValue","NumberValue","StringValue"}
local rec={}
local function makeRecChip(name)
 local btn=Instance.new("TextButton",sp);btn.Size=UDim2.new(1,-10,0,22);btn.BackgroundColor3=Color3.fromRGB(40,42,55)
 btn.Text=name;btn.TextColor3=Color3.fromRGB(220,220,230);btn.TextSize=12;btn.Font=Enum.Font.SourceSans
 btn.AutoButtonColor=false;btn.BorderSizePixel=0;local bc=Instance.new("UICorner",btn);bc.CornerRadius=UDim.new(0,6)
 btn.MouseButton1Click:Connect(function()sb2.Text=name;rec[name]=btn end)
 return btn
end

for _,name in ipairs(recentNames)do rec[name]=makeRecChip(name)end
L(sp,"推荐:",Color3.fromRGB(255,200,100))

local sbb=Instance.new("TextButton",sp);sbb.Size=UDim2.new(1,-10,0,24);sbb.BackgroundColor3=Color3.fromRGB(45,55,70)
sbb.Text="搜索";sbb.TextColor3=Color3.fromRGB(200,200,200);sbb.TextSize=13;sbb.Font=Enum.Font.SourceSans
sbb.AutoButtonColor=false;sbb.BorderSizePixel=0;local sbbCorner=Instance.new("UICorner",sbb);sbbCorner.CornerRadius=UDim.new(0,6)

sbb.MouseButton1Click:Connect(function()
 local q=sb2.Text:lower();if q==""then return end
 for _,c in ipairs(sp:GetChildren())do if c~=sh and c~=sb2 and c~=sbb and(c:IsA("TextButton")or c:IsA("TextLabel"))then c:Destroy()end end
 for _,name in ipairs(recentNames)do if rec[name] then rec[name]:Destroy();rec[name]=nil end end
 local res={};for _,obj in ipairs(game:GetDescendants())do if obj.Name:lower():find(q,1,true)or obj.ClassName:lower():find(q,1,true)then table.insert(res,obj);if #res>=50 then break end end end
 if #res==0 then L(sp,"无结果",Color3.fromRGB(255,100,100))return end
 L(sp,"找到: "..tostring(#res),Color3.fromRGB(255,200,100))
 for _,obj in ipairs(res)do
  local btn=Instance.new("TextButton",sp);btn.Size=UDim2.new(1,-10,0,20);btn.BackgroundColor3=Color3.fromRGB(35,35,50)
  btn.Text="["..obj.ClassName.."] "..obj.Name;btn.TextColor3=Color3.fromRGB(180,200,220);btn.TextSize=11
  btn.Font=Enum.Font.SourceSans;btn.TextXAlignment=Enum.TextXAlignment.Left;btn.AutoButtonColor=false;btn.BorderSizePixel=0
  local bCorner2=Instance.new("UICorner",btn);bCorner2.CornerRadius=UDim.new(0,4)
  local tgt=obj;btn.MouseButton1Click:Connect(function()
   for _,c in ipairs(sp:GetChildren())do if c:IsA("TextButton")and c~=sbb then c.BackgroundColor3=Color3.fromRGB(35,35,50)end end
   btn.BackgroundColor3=Color3.fromRGB(70,70,120)
   table.insert(recentNames,1,tostring(obj.Name));if #recentNames>12 then table.remove(recentNames)end
   for name,chip in pairs(rec)do chip:Destroy()end;table.clear(rec)
   for i=1,#recentNames do local n=recentNames[i];if not rec[n] then rec[n]=makeRecChip(n)end end
   pcall(function()SG:SetCore("SendNotification",{Title="已选择",Text=tgt:GetFullName(),Duration=2})end)
  end)
 end
end)

local remoteHooked=false
local function doRemoteHook()
 if remoteHooked then return end
 remoteHooked=true
 for _,obj in ipairs(game:GetDescendants())do pcall(function()local cn=obj.ClassName;if cn=="RemoteEvent"or cn=="RemoteFunction"or cn=="UnreliableRemoteEvent"then hookR(obj)end end)end
 game.DescendantAdded:Connect(function(obj)pcall(function()local cn=obj.ClassName;if cn=="RemoteEvent"or cn=="RemoteFunction"or cn=="UnreliableRemoteEvent"then hookR(obj)end end)end)
end

local rp=tps[6];local rml=80;local rc=0

local cl=Instance.new("TextButton",rp);cl.Size=UDim2.new(1,-10,0,22);cl.BackgroundColor3=Color3.fromRGB(70,45,45)
cl.Text="清空";cl.TextColor3=Color3.fromRGB(255,255,255);cl.TextSize=12;cl.Font=Enum.Font.SourceSans
cl.AutoButtonColor=false;cl.BorderSizePixel=0;local clCorner=Instance.new("UICorner",cl);clCorner.CornerRadius=UDim.new(0,6)
cl.MouseButton1Click:Connect(function()
 for _,c in ipairs(rp:GetChildren())do if c:IsA("TextLabel") then c:Destroy()end end
 rc=0;L(rp,"已清空",Color3.fromRGB(255,200,100))
end)

local function lr(dir,cn,nm)
 local lb=Instance.new("TextLabel",rp);lb.Size=UDim2.new(1,-10,0,16);lb.BackgroundTransparency=1
 local dd=(dir=="S") and "发送" or dir;lb.Text="["..dd.."] "..cn.." -> "..nm
 lb.TextXAlignment=Enum.TextXAlignment.Left;lb.Font=Enum.Font.SourceSans;lb.TextSize=11;lb.TextWrapped=true
 lb.TextColor3=(dir=="S")and Color3.fromRGB(100,200,255) or Color3.fromRGB(255,150,100)
 rc=rc+1;if rc>rml then for _,c in ipairs(rp:GetChildren())do if c:IsA("TextLabel")then c:Destroy();rc=rc-1;break end end end
end

local function hookR(obj)
 if obj.ClassName=="RemoteFunction"then local o=obj.InvokeServer;obj.InvokeServer=function(self,...)lr("S",obj.ClassName,obj.Name);return o and o(self,...)or nil end
 else local o=obj.FireServer;obj.FireServer=function(self,...)lr("S",obj.ClassName,obj.Name);return o and o(self,...)or nil end end
end

local lrInit=Instance.new("TextLabel",rp);lrInit.Size=UDim2.new(1,-10,0,20);lrInit.BackgroundTransparency=1
lrInit.Text="请先点击顶部「远程」标签页加载监听";lrInit.TextColor3=Color3.fromRGB(255,200,100)
lrInit.Font=Enum.Font.SourceSans;lrInit.TextSize=12;lrInit.TextWrapped=true

tbs[6].MouseButton1Click:Connect(function()
 if not remoteHooked then doRemoteHook() end
 if lrInit then lrInit:Destroy() end
end)


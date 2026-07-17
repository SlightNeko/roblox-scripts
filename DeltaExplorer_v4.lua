--[[DeltaExplorer v4
GameId: 通用
功能: Info+Role+FPS / Browser / ValueScan / Monitor / Search / RSPY
版本: v4.1
兼容: Delta Injector (标准 UNC)
--]]
local function S(n)local o,e=pcall(game.GetService,game,n);return o and e or nil end
local Pl=S("Players");local SG=S("StarterGui");local CG=S("CoreGui");local RS=S("RunService")
pcall(function()SG:SetCore("SendNotification",{Title="DeltaExplorer v4",Text="Loading",Duration=2})end)
local lp=Pl.LocalPlayer;if not lp then lp=Pl:FindFirstChild("LocalPlayer")end;if not lp then return end
local pg=lp:FindFirstChild("PlayerGui");if not pg then return end
local gui=Instance.new("ScreenGui")
gui.Name="DeltaExplorerV4";gui.ResetOnSpawn=false;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.DisplayOrder=100
local ok=pcall(function()gui.Parent=CG end)
if not ok then ok=pcall(function()gui.Parent=pg end);if not ok then gui:Destroy();return end end
-- Main frame
local m=Instance.new("Frame");m.Size=UDim2.new(0,400,0,500);m.Position=UDim2.new(0.5,-200,0.3,-150);m.BackgroundColor3=Color3.fromRGB(20,20,28);m.BorderSizePixel=0;m.Active=true;m.Parent=gui
Instance.new("UICorner",m).CornerRadius=UDim.new(0,8)
-- Title
local tb=Instance.new("Frame",m);tb.Size=UDim2.new(1,0,0,30);tb.BackgroundColor3=Color3.fromRGB(14,14,20);tb.BorderSizePixel=0
Instance.new("UICorner",tb).CornerRadius=UDim.new(0,8)
local tt=Instance.new("TextLabel",tb);tt.Size=UDim2.new(1,-40,1,0);tt.Position=UDim2.new(0,10,0,0);tt.BackgroundTransparency=1;tt.Text="DeltaExplorer v4";tt.TextColor3=Color3.fromRGB(255,200,100);tt.TextXAlignment=Enum.TextXAlignment.Left;tt.Font=Enum.Font.SourceSansBold;tt.TextSize=16
local cx=Instance.new("TextButton",tb);cx.Size=UDim2.new(0,24,0,24);cx.Position=UDim2.new(1,-28,0,3);cx.BackgroundColor3=Color3.fromRGB(180,40,40);cx.Text="X";cx.TextColor3=Color3.fromRGB(255,255,255);cx.TextSize=14;cx.Font=Enum.Font.SourceSansBold;cx.AutoButtonColor=false
Instance.new("UICorner",cx).CornerRadius=UDim.new(0,6)
cx.MouseButton1Click:Connect(function()gui:Destroy()end)
-- Drag
local drg=false;local ds;local fs
tb.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 then drg=true;ds=i.Position;fs=m.Position end end)
tb.InputChanged:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseMovement and drg then local d=i.Position-ds;m.Position=UDim2.new(fs.X.Scale,fs.X.Offset+d.X,fs.Y.Scale,fs.Y.Offset+d.Y)end end)
tb.InputEnded:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 then drg=false end end)
-- Tab bar 6
local bar=Instance.new("Frame",m);bar.Size=UDim2.new(1,0,0,28);bar.Position=UDim2.new(0,0,0,30);bar.BackgroundColor3=Color3.fromRGB(26,26,36);bar.BorderSizePixel=0
local tns={"Info","Browser","VScan","Monitor","Search","RSPY"};local tbs={};local tps={}
local tcs={Color3.fromRGB(55,55,75),Color3.fromRGB(50,60,75),Color3.fromRGB(55,70,55),Color3.fromRGB(70,55,55),Color3.fromRGB(65,55,70),Color3.fromRGB(55,55,70)};local tac=Color3.fromRGB(70,70,95)
for i=1,6 do
 local btn=Instance.new("TextButton",bar);btn.Size=UDim2.new(0,66,1,0);btn.Position=UDim2.new(0,(i-1)*66,0,0);btn.BackgroundColor3=tcs[i];btn.Text=tns[i];btn.TextColor3=Color3.fromRGB(200,200,200);btn.TextSize=11;btn.Font=Enum.Font.SourceSans;btn.AutoButtonColor=false;btn.BorderSizePixel=0;tbs[i]=btn
 local pan=Instance.new("ScrollingFrame",m);pan.Size=UDim2.new(1,0,1,-58);pan.Position=UDim2.new(0,0,0,58);pan.BackgroundColor3=Color3.fromRGB(20,20,28);pan.BorderSizePixel=0;pan.ScrollBarThickness=6;pan.CanvasSize=UDim2.new(0,0,0,0);pan.AutomaticCanvasSize=Enum.AutomaticSize.Y;pan.Visible=(i==1);tps[i]=pan
 Instance.new("UIListLayout",pan).Padding=UDim.new(0,2)
end
tbs[1].BackgroundColor3=tac
for i=1,6 do local idx=i;tbs[i].MouseButton1Click:Connect(function()for j=1,6 do tps[j].Visible=(j==idx);tbs[j].BackgroundColor3=(j==idx)and tac or tcs[j]end end)end
-- Label helper
local function L(pan,text,c)
 local lb=Instance.new("TextLabel",pan);lb.Size=UDim2.new(1,-10,0,22);lb.BackgroundTransparency=1;lb.Text=text;lb.TextColor3=c or Color3.fromRGB(200,200,200);lb.TextXAlignment=Enum.TextXAlignment.Left;lb.Font=Enum.Font.SourceSans;lb.TextSize=13;return lb
end
-- Info panel + Role Info
local ip=tps[1]
L(ip,"Player: "..lp.Name,Color3.fromRGB(255,200,100));L(ip,"UserId: "..tostring(lp.UserId),Color3.fromRGB(255,200,100));L(ip,"AccountAge: "..tostring(lp.AccountAge),Color3.fromRGB(255,200,100));L(ip,"PlaceId: "..tostring(game.PlaceId),Color3.fromRGB(255,200,100));L(ip,"GameId: "..tostring(game.GameId),Color3.fromRGB(255,200,100))
local function roleInfo()
 local char=lp.Character;if char and char:FindFirstChild("Humanoid")then
  local hum=char:FindFirstChild("Humanoid");L(ip,"Health: "..tostring(math.floor(hum.Health)).."/"..tostring(hum.MaxHealth),Color3.fromRGB(100,255,100));L(ip,"Speed: "..tostring(hum.WalkSpeed),Color3.fromRGB(100,255,100));L(ip,"Jump: "..tostring(hum.JumpPower),Color3.fromRGB(100,255,100))
 else L(ip,"No Character",Color3.fromRGB(255,100,100))end
end
roleInfo();lp.CharacterAdded:Connect(function()task.wait(1);roleInfo()end)
-- FPS without stats()
local fl=L(ip,"FPS: 0 | Mem: 0 MB",Color3.fromRGB(255,200,100));local fc=0;local el=0
RS.RenderStepped:Connect(function(dt)
 fc=fc+1;el=el+dt
 if el>=1 then
  local mem=0;pcall(function()mem=collectgarbage("count")or 0 end)
  fl.Text="FPS: "..tostring(math.floor(fc/el+0.5)).." | Mem: "..string.format("%.1f",mem/1024).." MB"
  fc=0;el=0
 end
end)
-- Browser
local bp=tps[2];local es={}
local function bt(pan,obj,depth,md)
 if depth>md then return end;local ind=string.rep("  ",depth)
 local btn=Instance.new("TextButton",pan);btn.Size=UDim2.new(1,-10,0,20);btn.BackgroundColor3=Color3.fromRGB(28+depth*6,28+depth*6,38+depth*6);btn.BorderSizePixel=0;btn.TextXAlignment=Enum.TextXAlignment.Left;btn.Text=ind.."["..obj.ClassName.."] "..obj.Name;btn.TextColor3=Color3.fromRGB(200,200,210);btn.Font=Enum.Font.SourceSans;btn.TextSize=12;btn.AutoButtonColor=false
 local k=obj;es[k]=false;local cbs={}
 local function rf()for _,cb in ipairs(cbs)do cb:Destroy()end;cbs={};if es[k]then for _,ch in ipairs(obj:GetChildren())do local cb=bt(pan,ch,depth+1,md)if cb then table.insert(cbs,cb)end end end end
 btn.MouseButton1Click:Connect(function()es[k]=not es[k];rf()end);return btn
end
for _,ch in ipairs(game:GetChildren())do bt(bp,ch,0,2)end
-- Value Scanner
local vp=tps[3];local vcs={"NumberValue","IntValue","BoolValue","StringValue"}
local vh=L(vp,"Scan by Class:",Color3.fromRGB(255,200,100))
local function doScan(cn)
 local kids={};for _,c in ipairs(vp:GetChildren())do if c:IsA("TextLabel")and c~=vh then table.insert(kids,c)end end
 for _,c in ipairs(kids)do c:Destroy()end;local n=0
 for _,ch in ipairs(game:GetDescendants())do
  if ch.ClassName==cn then local v=ch.Value;if type(v)=="boolean"then v=tostring(v)end;L(vp,"["..cn.."] "..ch.Name.." = "..tostring(v),Color3.fromRGB(100,200,255));n=n+1 end
 end
 if n==0 then L(vp,"None found",Color3.fromRGB(255,150,100))else L(vp,"Total: "..tostring(n),Color3.fromRGB(255,200,100))end
end
for _,cn in ipairs(vcs)do
 local btn=Instance.new("TextButton",vp);btn.Size=UDim2.new(1,-10,0,24);btn.BackgroundColor3=Color3.fromRGB(45,55,70);btn.Text=cn;btn.TextColor3=Color3.fromRGB(200,200,200);btn.TextSize=12;btn.Font=Enum.Font.SourceSans;btn.AutoButtonColor=false;btn.BorderSizePixel=0;Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
 btn.MouseButton1Click:Connect(function()doScan(cn)end)
end
-- Live Monitor
local mp=tps[4]
local mh=L(mp,"Instance path:",Color3.fromRGB(255,200,100))
local ib=Instance.new("TextBox",mp);ib.Size=UDim2.new(1,-10,0,24);ib.BackgroundColor3=Color3.fromRGB(30,30,40);ib.TextColor3=Color3.fromRGB(200,200,200);ib.PlaceholderText="workspace.Part";ib.Text="";ib.Font=Enum.Font.SourceSans;ib.TextSize=13;Instance.new("UICorner",ib).CornerRadius=UDim.new(0,6)
local sb=Instance.new("TextButton",mp);sb.Size=UDim2.new(1,-10,0,24);sb.BackgroundColor3=Color3.fromRGB(45,70,45);sb.Text="Start";sb.TextColor3=Color3.fromRGB(200,200,200);sb.TextSize=13;sb.Font=Enum.Font.SourceSans;sb.AutoButtonColor=false;sb.BorderSizePixel=0;Instance.new("UICorner",sb).CornerRadius=UDim.new(0,6)
local mc=nil
sb.MouseButton1Click:Connect(function()
 if mc then mc:Disconnect();mc=nil;sb.Text="Start";sb.BackgroundColor3=Color3.fromRGB(45,70,45);L(mp,"Stopped",Color3.fromRGB(255,200,100));return end
 local p=ib.Text;if p==""then L(mp,"Enter path first",Color3.fromRGB(255,100,100));return end
 local tgt=loadstring("return "..p)();if not tgt then L(mp,"Invalid path",Color3.fromRGB(255,100,100));return end
 for _,c in ipairs(mp:GetChildren())do if c:IsA("TextLabel")and c~=mh then c:Destroy()end end
 L(mp,"Watching: "..tgt:GetFullName(),Color3.fromRGB(100,255,100));sb.Text="Stop";sb.BackgroundColor3=Color3.fromRGB(70,45,45)
 mc=tgt.Changed:Connect(function(prop)local v=tgt[prop];if type(v)=="boolean"then v=tostring(v)end;L(mp,"["..tostring(prop).."] = "..tostring(v),Color3.fromRGB(100,200,255))end)
end)
-- Object Search
local sp=tps[5]
local sh=L(sp,"Search Name or Class:",Color3.fromRGB(255,200,100))
local sb2=Instance.new("TextBox",sp);sb2.Size=UDim2.new(1,-10,0,24);sb2.BackgroundColor3=Color3.fromRGB(30,30,40);sb2.TextColor3=Color3.fromRGB(200,200,200);sb2.PlaceholderText="Query...";sb2.Text="";sb2.Font=Enum.Font.SourceSans;sb2.TextSize=13;Instance.new("UICorner",sb2).CornerRadius=UDim.new(0,6)
local sbb=Instance.new("TextButton",sp);sbb.Size=UDim2.new(1,-10,0,24);sbb.BackgroundColor3=Color3.fromRGB(45,55,70);sbb.Text="Search";sbb.TextColor3=Color3.fromRGB(200,200,200);sbb.TextSize=13;sbb.Font=Enum.Font.SourceSans;sbb.AutoButtonColor=false;sbb.BorderSizePixel=0;Instance.new("UICorner",sbb).CornerRadius=UDim.new(0,6)
sbb.MouseButton1Click:Connect(function()
 local q=sb2.Text:lower();if q==""then return end
 for _,c in ipairs(sp:GetChildren())do if c~=sh and c~=sb2 and c~=sbb and(c:IsA("TextButton")or c:IsA("TextLabel"))then c:Destroy()end end
 local res={};for _,obj in ipairs(game:GetDescendants())do if obj.Name:lower():find(q,1,true)or obj.ClassName:lower():find(q,1,true)then table.insert(res,obj);if #res>=50 then break end end end
 if #res==0 then L(sp,"No results",Color3.fromRGB(255,100,100))return end
 L(sp,"Found: "..tostring(#res),Color3.fromRGB(255,200,100))
 for _,obj in ipairs(res)do
  local btn=Instance.new("TextButton",sp);btn.Size=UDim2.new(1,-10,0,20);btn.BackgroundColor3=Color3.fromRGB(35,35,50);btn.Text="["..obj.ClassName.."] "..obj.Name;btn.TextColor3=Color3.fromRGB(180,200,220);btn.TextSize=11;btn.Font=Enum.Font.SourceSans;btn.TextXAlignment=Enum.TextXAlignment.Left;btn.AutoButtonColor=false;btn.BorderSizePixel=0;Instance.new("UICorner",btn).CornerRadius=UDim.new(0,4)
  local tgt=obj;btn.MouseButton1Click:Connect(function()for _,c in ipairs(sp:GetChildren())do if c:IsA("TextButton")and c~=sbb then c.BackgroundColor3=Color3.fromRGB(35,35,50)end end;btn.BackgroundColor3=Color3.fromRGB(70,70,120);pcall(function()SG:SetCore("SendNotification",{Title="Selected",Text=tgt:GetFullName(),Duration=2})end)end)
 end
end)
-- RSPY
local rp=tps[6];local rml=80;local rc=0
local function lr(dir,cn,nm)
 local lb=Instance.new("TextLabel",rp);lb.Size=UDim2.new(1,-10,0,16);lb.BackgroundTransparency=1;lb.Text="["..dir.."] "..cn.." -> "..nm;lb.TextXAlignment=Enum.TextXAlignment.Left;lb.Font=Enum.Font.SourceSans;lb.TextSize=11;lb.TextWrapped=true;lb.TextColor3=(dir=="S")and Color3.fromRGB(100,200,255)or Color3.fromRGB(255,150,100)
 rc=rc+1;if rc>rml then for _,c in ipairs(rp:GetChildren())do if c:IsA("TextLabel")then c:Destroy();rc=rc-1;break end end end
end
local function hookR(obj)
 if obj.ClassName=="RemoteFunction"then local o=obj.InvokeServer;obj.InvokeServer=function(self,...)lr("S",obj.ClassName,obj.Name);return o and o(self,...)or nil end
 else local o=obj.FireServer;obj.FireServer=function(self,...)lr("S",obj.ClassName,obj.Name);return o and o(self,...)or nil end end
end
for _,obj in ipairs(game:GetDescendants())do pcall(function()local cn=obj.ClassName;if cn=="RemoteEvent"or cn=="RemoteFunction"or cn=="UnreliableRemoteEvent"then hookR(obj)end end)end
game.DescendantAdded:Connect(function(obj)pcall(function()local cn=obj.ClassName;if cn=="RemoteEvent"or cn=="RemoteFunction"or cn=="UnreliableRemoteEvent"then hookR(obj)end end)end)
-- Final
pcall(function()SG:SetCore("SendNotification",{Title="DeltaExplorer v4",Text="Loaded",Duration=2})end)

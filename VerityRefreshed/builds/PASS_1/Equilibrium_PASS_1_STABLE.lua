-- Equilibrium v1.1 COMPILED — single file, no external modules required
-- Fixes: combined core + settings + context + verity + knowledge, mount debug, removed stray end, fixed new()/continue
-- Window: true Windows _ □ × | Slate 070707 | V puck | 🔒 locked by default | X hide / hold unload

-- single-instance cleanup
pcall(function()
    local r=getgenv().__equilibriumRegistry if type(r)=="table" then for _,fn in ipairs(r) do pcall(fn) end table.clear(r) end
    for _,k in ipairs({"EquilibriumUnload","FleeceUnload","VertexUnload"}) do local ok,fn=pcall(function() return getgenv()[k] end) if ok and type(fn)=="function" then pcall(fn) end end
    for _,n in ipairs({"EquilibriumHub","EquilibriumESP","VerityFace","EquilibriumSplash","PHHub","PSE_Essentials"}) do local o=game.CoreGui:FindFirstChild(n) if o then o:Destroy() end local p=game.Players.LocalPlayer:FindFirstChild("PlayerGui") and game.Players.LocalPlayer.PlayerGui:FindFirstChild(n) if p then p:Destroy() end end
end)

local BRAND="Equilibrium"; local UNLOAD_KEY="EquilibriumUnload"; local CFG_FOLDER="equilibrium"
local Players=game:GetService("Players"); local RunService=game:GetService("RunService"); local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService"); local Lighting=game:GetService("Lighting"); local HttpService=game:GetService("HttpService")
local TeleportService=game:GetService("TeleportService"); local GuiService=game:GetService("GuiService"); local Workspace=game:GetService("Workspace")
local LP=Players.LocalPlayer; local Camera=Workspace.CurrentCamera or Workspace:FindFirstChildOfClass("Camera")
print("[Equilibrium] boot — "..BRAND.." v1.1 compiling Slate 070707")

-- ===== Settings (file+memory, inlined) =====
local Settings={}; do
    local mem={global=nil,place=nil}
    local function hasFile() return typeof(isfolder)=="function" and typeof(isfile)=="function" and typeof(writefile)=="function" and typeof(readfile)=="function" end
    local function ensure() if not hasFile() then return false end if not isfolder(CFG_FOLDER) then pcall(makefolder,CFG_FOLDER) end if not isfolder(CFG_FOLDER.."/places") then pcall(makefolder,CFG_FOLDER.."/places") end return true end
    local function fpath(k) if k=="global" then return CFG_FOLDER.."/global.json" end return CFG_FOLDER.."/places/"..tostring(game.PlaceId)..".json" end
    local defaults={global={theme="Slate", bg="#070707", verityLocked=true, winW=620, winH=520}, place={features={}}}
    function Settings:Get(k,s) s=s or "global" local src=mem[s] or {} if src[k]~=nil then return src[k] end return defaults[s] and defaults[s][k] or nil end
    function Settings:Set(k,v,s) s=s or "global" mem[s]=mem[s] or {} mem[s][k]=v end
    function Settings:Save(s) s=s or "global" if hasFile() then ensure() local ok,txt=pcall(HttpService.JSONEncode,HttpService,mem[s] or {}) if ok then pcall(writefile,fpath(s),txt) end end end
    function Settings:Load() if hasFile() then local ok,txt=pcall(readfile,fpath("global")) if ok then local ok2,d=pcall(HttpService.JSONDecode,HttpService,txt) if ok2 and type(d)=="table" then mem.global=d end end local ok3,txt2=pcall(readfile,fpath("place")) if ok3 then local ok4,d2=pcall(HttpService.JSONDecode,HttpService,txt2) if ok4 and type(d2)=="table" then mem.place=d2 end end end if not mem.global then mem.global={theme="Slate", bg="#070707", verityLocked=true, winW=620, winH=520} end if not mem.place then mem.place={features={}} end return mem end
    pcall(function() Settings:Load() end)
end

-- ===== EVENTS bus =====
local EVENTS={_handlers={}}
function EVENTS.on(e,fn) EVENTS._handlers[e]=EVENTS._handlers[e] or {} table.insert(EVENTS._handlers[e],fn) return function() local l=EVENTS._handlers[e] if l then for i,h in ipairs(l) do if h==fn then table.remove(l,i) break end end end end end
function EVENTS.fire(e,...) local l=EVENTS._handlers[e] if l then for _,fn in ipairs(table.clone(l)) do pcall(fn,...) end end end

-- ===== Context (hot snapshot, inlined) =====
local Context={world={nearbyPlayers={},lastUpdate=0}, player={health=100,maxHealth=100,team=nil}, attention={focus=nil}, graph={entities={}}}
do
    local cache={pos=nil,ts=0}
    function Context:Snapshot() return {pos=cache.pos, health=self.player.health, maxHealth=self.player.maxHealth, team=self.player.team, nearby=self.world.nearbyPlayers} end
    function Context:Update()
        local now=tick() if now-cache.ts<0.25 then return end cache.ts=now
        local char=LP.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if hrp then cache.pos=hrp.Position end
        local nearby={} if hrp then for _,plr in ipairs(Players:GetPlayers()) do if plr~=LP and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then local d=(plr.Character.HumanoidRootPart.Position-hrp.Position).Magnitude if d<250 then table.insert(nearby,{player=plr,dist=d}) end end end table.sort(nearby,function(a,b) return a.dist<b.dist end) end
        self.world.nearbyPlayers=nearby; self.world.lastUpdate=now
        if char then local hum=char:FindFirstChildOfClass("Humanoid") if hum then self.player.health,self.player.maxHealth=hum.Health,hum.MaxHealth end self.player.team=LP.Team end
    end
    function Context:SetFocus(p) self.attention.focus=p end
end
-- context heartbeat is created after rootMaid exists (see after Maid definition)

-- ===== Knowledge (inlined small tables) =====
local KNOWLEDGE={
    roblox={"obby: obstacle course","tycoon: build-to-earn","simulator: incremental","r15: 15-part rig","lag: network delay","desync: client mismatch","hitbox: collision area"},
    slang={"W: win","L: loss","cooked: doomed","locked in: focused","skill issue: excuse"},
}

-- ===== Verity runtime (inlined) =====
local Verity={state="neutral", locked=true}
local VERITY_EXPR={neutral="—", happy="⌣", glitch="#", curious="o", annoyed="—"}
function Verity:Set(s) self.state=s if _G.__eq_applyVerity then pcall(_G.__eq_applyVerity,s) end end

-- ===== Maid / Scheduler =====
local Maid={} Maid.__index=Maid
function Maid.new() return setmetatable({_items={},_dead=false},Maid) end
function Maid:give(v) if self._dead then pcall(function() if typeof(v)=="RBXScriptConnection" then v:Disconnect() elseif typeof(v)=="Instance" then v:Destroy() elseif typeof(v)=="thread" then task.cancel(v) elseif type(v)=="function" then v() end end) return v end table.insert(self._items,v) return v end
function Maid:clean() local it=self._items self._items={} for i=#it,1,-1 do local v=it[i] pcall(function() if typeof(v)=="RBXScriptConnection" then v:Disconnect() elseif typeof(v)=="Instance" then v:Destroy() elseif typeof(v)=="thread" then task.cancel(v) elseif type(v)=="function" then v() elseif type(v)=="table" and v.clean then v:clean() end end) end end
function Maid:destroy() self:clean() self._dead=true end

local Scheduler={cost={}, profiling=true}
do local buckets={render={signal=RunService.RenderStepped,list={},conn=nil, stepped=false}, heartbeat={signal=RunService.Heartbeat,list={},conn=nil, stepped=false}}
    local function pump(b) return function(a) for i=#b.list,1,-1 do local e=b.list[i] local ok,err=pcall(e.fn,a) if not ok then table.remove(b.list,i) if e.onError then task.spawn(e.onError,err) end end end end end
    function Scheduler.add(name,key,fn,onErr) local buck=buckets[name] if not buck then return end Scheduler.remove(name,key) table.insert(buck.list,{key=key,fn=fn,onError=onErr}) if not buck.conn then buck.conn=buck.signal:Connect(pump(buck)) end end
    function Scheduler.remove(name,key) local buck=buckets[name] if not buck then return end for i=#buck.list,1,-1 do if buck.list[i].key==key then table.remove(buck.list,i) end end if #buck.list==0 and buck.conn then buck.conn:Disconnect() buck.conn=nil end end
    function Scheduler.stopAll() for _,b in pairs(buckets) do if b.conn then b.conn:Disconnect() end b.conn,b.list=nil,{} end end
end

local rootMaid=Maid.new(); local charMaid=Maid.new()
local Char={model=nil,hum=nil,root=nil,onRespawn={}}
local function bindCharacter(m) charMaid:clean() Char.model=m Char.hum=m:FindFirstChildOfClass("Humanoid") Char.root=m:FindFirstChild("HumanoidRootPart") task.spawn(function() if not Char.hum then Char.hum=m:WaitForChild("Humanoid",10) end if not Char.root then Char.root=m:WaitForChild("HumanoidRootPart",10) end for _,fn in ipairs(Char.onRespawn) do task.spawn(fn) end end) end
if LP.Character then bindCharacter(LP.Character) end rootMaid:give(LP.CharacterAdded:Connect(bindCharacter)) rootMaid:give(charMaid)
do
    local contextConn = RunService.Heartbeat:Connect(function() pcall(function() Context:Update() end) end)
    rootMaid:give(contextConn)
end
local function alive() return Char.model and Char.model.Parent and Char.hum and Char.hum.Health>0 and Char.root and Char.root.Parent end

-- ===== Theme Slate 070707 =====
local T={bg=Color3.fromHex("070707"), panel=Color3.fromHex("141414"), titleBar=Color3.fromHex("0f0f0f"), border=Color3.fromHex("2a2a2a"), line=Color3.fromHex("252525"), text=Color3.fromHex("e6e6e6"), dim=Color3.fromHex("a0a0a8"), accent=Color3.fromHex("787a96"), accent2=Color3.fromHex("8a8dc2"), on=Color3.fromHex("5fdc82"), off=Color3.fromHex("4b5563"), warn=Color3.fromHex("e81123"), warnHover=Color3.fromHex("c50f1f")}
local FONT, FONTB = Enum.Font.Gotham, Enum.Font.GothamBold
local rng=Random.new(tick()*1e6%2147483647) local CHARS="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
local function rname() local n=rng:NextInteger(18,26) local b=table.create(n) for i=1,n do local k=rng:NextInteger(1,#CHARS) b[i]=CHARS:sub(k,k) end return table.concat(b) end
-- FIXED new() without continue (was silent failure point)
local function new(className, props, kids) local o=Instance.new(className) if props then for kk,vv in pairs(props) do if kk~="Parent" and kk~="Name" then if kk=="Font" then o.Font=vv else local ok=pcall(function() o[kk]=vv end) if not ok and kk=="TextSize" then o.TextSize=vv end end end end end if props and props.Name then o.Name=props.Name else o.Name=rname() end if kids then for _,ch in ipairs(kids) do ch.Parent=o end end if props and props.Parent then o.Parent=props.Parent end return o end
local function corner(i,r) return new("UICorner",{CornerRadius=UDim.new(0,r or 8),Parent=i}) end
local function stroke(i,c,t) return new("UIStroke",{Color=c or T.border, Thickness=t or 1, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Parent=i}) end
local function pad(i,a,b,c,d) return new("UIPadding",{PaddingTop=UDim.new(0,a or 0),PaddingBottom=UDim.new(0,b or a or 0),PaddingLeft=UDim.new(0,c or 0),PaddingRight=UDim.new(0,d or c or 0),Parent=i}) end
local function vlist(i,g) return new("UIListLayout",{FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,g or 8), Parent=i}) end
local function hlist(i,g) return new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,g or 8), VerticalAlignment=Enum.VerticalAlignment.Center, Parent=i}) end
local function tw(i,info,goal) local t=TweenService:Create(i,info,goal) t:Play() return t end
local MOTION={hover=TweenInfo.new(0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), win=TweenInfo.new(0.28,Enum.EasingStyle.Quint,Enum.EasingDirection.Out)}

local function viewport() local cam=Workspace.CurrentCamera return cam and cam.ViewportSize or Vector2.new(620,520) end
local W,H=620,520 do local vp=viewport() W=math.clamp(620,320,math.max(320,vp.X-40)) H=math.clamp(520,260,math.max(260,vp.Y-40)) end
local function centeredPos(w,h) local vp=viewport() return Vector2.new(math.floor((vp.X-w)/2), math.floor((vp.Y-h)/2)) end
local function px(n) return math.floor(n+0.5) end
local function offset(x,y) return UDim2.fromOffset(px(x),px(y)) end

-- ScreenGui — start hidden, will be shown after parented
local screen=new("ScreenGui",{Name="EquilibriumHub", ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, IgnoreGuiInset=true, DisplayOrder=999, Enabled=false})
rootMaid:give(screen)

-- Notify: separate ScreenGui so it survives hub hide (old Roblox style)
local notifyGui=new("ScreenGui",{Name="EquilibriumNotify", ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, IgnoreGuiInset=true, DisplayOrder=1000})
local notifyRoot=new("Frame",{BackgroundTransparency=1, AnchorPoint=Vector2.new(1,1), Position=UDim2.new(1,-16,1,-16), Size=offset(320,400), ZIndex=900, Parent=notifyGui})
new("UIListLayout",{FillDirection=Enum.FillDirection.Vertical, VerticalAlignment=Enum.VerticalAlignment.Bottom, HorizontalAlignment=Enum.HorizontalAlignment.Right, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,8), Parent=notifyRoot})
-- Mount notifyGui with same parent logic as screen (deferred below, parent now to PlayerGui as fallback)
pcall(function() notifyGui.Parent=game:GetService("CoreGui") end)
if not notifyGui.Parent then pcall(function() notifyGui.Parent=LP:WaitForChild("PlayerGui") end) end
if typeof(gethui)=="function" then pcall(function() notifyGui.Parent=gethui() end) end
rootMaid:give(notifyGui)
local function pushToast(text, kind, secs)
    secs=secs or 3.5
    local accent=(kind=="bad" and T.warn) or (kind=="warn" and T.warn) or T.on
    local card=new("Frame",{BackgroundColor3=T.panel, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=900, Parent=notifyRoot}) corner(card,8) stroke(card,T.border) pad(card,10,10,12,12) hlist(card,8,Enum.VerticalAlignment.Top)
    new("Frame",{BackgroundColor3=accent, Size=offset(3,16), BorderSizePixel=0, LayoutOrder=1, ZIndex=901, Parent=card},{new("UICorner",{CornerRadius=UDim.new(1,0)})})
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-18,0,0), AutomaticSize=Enum.AutomaticSize.Y, Font=FONT, Text=text, TextSize=13, TextColor3=T.text, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=2, ZIndex=901, Parent=card})
    card.Position=offset(20,0) tw(card,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=offset(0,0)})
    task.delay(secs,function() if card.Parent then local t=tw(card,TweenInfo.new(0.15),{Position=offset(20,0)}) t.Completed:Wait() card:Destroy() end end)
    EVENTS.fire("verityLog",text)
end

-- Shell
local shellRect={size=Vector2.new(W,H), pos=centeredPos(W,H)}
local shell=new("Frame",{BackgroundColor3=T.bg, Size=offset(W,H), Position=offset(shellRect.pos.X,shellRect.pos.Y), BorderSizePixel=0, ClipsDescendants=true, ZIndex=10, Parent=screen})
local shellCorner=corner(shell,10); local shellStroke=stroke(shell,T.border,1)
local canvas=new("CanvasGroup",{BackgroundTransparency=1, Size=UDim2.fromScale(1,1), GroupTransparency=0, ZIndex=11, Parent=shell})

-- TitleBar
local titleBar=new("Frame",{BackgroundColor3=T.titleBar, Size=UDim2.new(1,0,0,36), BorderSizePixel=0, ZIndex=12, Parent=canvas})
corner(titleBar,10); new("Frame",{BackgroundColor3=T.titleBar, Size=UDim2.new(1,0,0,10), Position=UDim2.new(0,0,1,-10), BorderSizePixel=0, ZIndex=11, Parent=titleBar})
new("Frame",{BackgroundColor3=T.line, Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,1,-1), BorderSizePixel=0, ZIndex=12, Parent=titleBar})

local verityLocked = Settings:Get("verityLocked","global") if verityLocked==nil then verityLocked=true end
local verityRoot=new("Frame",{BackgroundTransparency=1, Size=offset(34,32), Position=offset(8,2), ZIndex=13, Parent=titleBar})
local verityHead=new("Frame",{BackgroundColor3=Color3.fromRGB(255,220,55), Size=offset(34,30), Position=offset(0,1), BorderSizePixel=1, BorderColor3=Color3.fromRGB(16,16,16), ZIndex=13, Parent=verityRoot}) corner(verityHead,8)
local eyeL=new("Frame",{BackgroundColor3=Color3.fromRGB(16,16,16), Size=offset(6,8), Position=offset(7,8), BorderSizePixel=0, ZIndex=14, Parent=verityHead}) corner(eyeL,3)
local eyeR=new("Frame",{BackgroundColor3=Color3.fromRGB(16,16,16), Size=offset(6,8), Position=offset(21,8), BorderSizePixel=0, ZIndex=14, Parent=verityHead}) corner(eyeR,3)
local mouth=new("TextLabel",{BackgroundTransparency=1, Size=offset(34,10), Position=offset(0,18), Font=FONTB, Text="—", TextSize=10, TextColor3=Color3.fromRGB(16,16,16), ZIndex=14, Parent=verityHead})
local function verityBlink() tw(eyeL,TweenInfo.new(0.06),{Size=offset(6,1)}); tw(eyeR,TweenInfo.new(0.06),{Size=offset(6,1)}); task.delay(0.07,function() tw(eyeL,TweenInfo.new(0.08),{Size=offset(6,8)}); tw(eyeR,TweenInfo.new(0.08),{Size=offset(6,8)}) end) end
_G.__eq_applyVerity=function(s) if s=="happy" then mouth.Text="⌣" elseif s=="glitch" then mouth.Text="#" else mouth.Text="—" end end

local lockBtn=new("TextButton",{BackgroundTransparency=1, Size=offset(18,18), Position=offset(44,9), Text=verityLocked and "🔒" or "🔓", Font=FONT, TextSize=12, TextColor3=T.dim, AutoButtonColor=false, ZIndex=13, Parent=titleBar})
lockBtn.Activated:Connect(function() verityLocked=not verityLocked lockBtn.Text=verityLocked and "🔒" or "🔓" Settings:Set("verityLocked",verityLocked,"global") Settings:Save("global") pushToast(verityLocked and "Verity locked" or "Verity unlocked — drag title", "warn",1.4) Verity.locked=verityLocked end)
Verity.locked=verityLocked

new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-190,1,0), Position=offset(68,0), Font=FONTB, Text="EQUILIBRIUM", TextSize=13, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=titleBar})
new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-190,1,0), Position=offset(68,14), Font=FONT, Text="Slate • 070707 • Universal", TextSize=9, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=titleBar})

-- Windows buttons _ □ ×
local winRow=new("Frame",{BackgroundTransparency=1, Size=offset(138,36), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), ZIndex=13, Parent=titleBar}) hlist(winRow,0)
local function winBtn(txt,isClose)
    local b=new("TextButton",{BackgroundColor3=T.titleBar, Size=offset(46,36), Text=txt, Font=FONT, TextSize=isClose and 16 or 12, TextColor3=T.dim, AutoButtonColor=false, BorderSizePixel=0, ZIndex=13, Parent=winRow})
    if isClose then b.MouseEnter:Connect(function() b.BackgroundColor3=T.warn; b.TextColor3=Color3.new(1,1,1) end) b.MouseLeave:Connect(function() b.BackgroundColor3=T.titleBar; b.TextColor3=T.dim end)
    else b.MouseEnter:Connect(function() b.BackgroundColor3=T.border; b.TextColor3=T.text end) b.MouseLeave:Connect(function() b.BackgroundColor3=T.titleBar; b.TextColor3=T.dim end) end
    b.MouseButton1Down:Connect(function() b.BackgroundColor3 = isClose and T.warnHover or T.border end)
    return b
end
local btnMin=winBtn("—",false); local btnMax=winBtn("□",false); local btnClose=winBtn("×",true)
do local hold,holdT
    btnClose.MouseButton1Down:Connect(function() hold=true holdT=tick() task.spawn(function() while hold and tick()-holdT<0.9 do task.wait(0.05) end if hold and tick()-holdT>=0.9 then hold=false btnClose.Text="…"; task.wait(0.18) local fn=getgenv()[UNLOAD_KEY] if fn then pcall(fn) end btnClose.Text="×" end end) end)
    btnClose.MouseButton1Up:Connect(function() if not hold then return end local d=tick()-holdT hold=false btnClose.Text="×" if d<0.9 then tw(canvas,TweenInfo.new(0.16),{GroupTransparency=1}).Completed:Wait() screen.Enabled=false canvas.GroupTransparency=0 pushToast("Hidden — RightShift to restore","warn",2) end end)
    btnClose.MouseLeave:Connect(function() hold=false btnClose.Text="×" end)
end

-- Puck V
local PUCK=56
local puck=new("TextButton",{BackgroundColor3=T.panel, Size=offset(PUCK,PUCK), Position=offset(centeredPos(PUCK,PUCK).X,centeredPos(PUCK,PUCK).Y), Text="", AutoButtonColor=false, BorderSizePixel=0, Visible=false, ZIndex=40, Parent=screen}) corner(puck,16) stroke(puck,T.border,1)
rootMaid:give(puck)
new("TextLabel",{BackgroundTransparency=1, Size=UDim2.fromScale(1,1), Font=FONTB, Text="V", TextSize=22, TextColor3=T.text, ZIndex=41, Parent=puck})
local puckDot=new("Frame",{BackgroundColor3=T.on, Size=offset(10,10), Position=UDim2.new(1,-8,0,-2), Visible=false, ZIndex=42, Parent=puck}) corner(puckDot,5)
local minimized=false; local animating=false; local isMax=false; local savedRect={pos=shellRect.pos, size=shellRect.size}
local function doMinimize() if minimized or animating then return end animating=true minimized=true shellRect.pos=Vector2.new(shell.Position.X.Offset,shell.Position.Y.Offset) shellRect.size=Vector2.new(shell.AbsoluteSize.X,shell.AbsoluteSize.Y) local t=tw(canvas,TweenInfo.new(0.14),{GroupTransparency=1}) t.Completed:Wait() shell.Visible=false canvas.GroupTransparency=0 local vp=viewport() local p=Vector2.new(math.clamp(shellRect.pos.X+shellRect.size.X/2-PUCK/2,0,vp.X-PUCK), math.clamp(shellRect.pos.Y+shellRect.size.Y/2-PUCK/2,0,vp.Y-PUCK)) puck.Position=offset(p.X,p.Y) puck.Visible=true animating=false end
local function doRestore() if not minimized or animating then return end animating=true minimized=false puck.Visible=false shell.Visible=true local t=tw(canvas,TweenInfo.new(0.22),{GroupTransparency=0}) t.Completed:Wait() animating=false end
puck.Activated:Connect(doRestore)
do local drag=false; local sd,sp
    puck.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true sd=i.Position sp=Vector2.new(puck.Position.X.Offset,puck.Position.Y.Offset) end end)
    UserInputService.InputChanged:Connect(function(i) if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then local d=i.Position-sd puck.Position=offset(sp.X+d.X,sp.Y+d.Y) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
end
btnMin.Activated:Connect(doMinimize)
local function fullscreenRect() local inset=GuiService:GetGuiInset() local vp=viewport() return Vector2.new(4,inset.Y+4), Vector2.new(vp.X-8, vp.Y-inset.Y-8) end
btnMax.Activated:Connect(function() if minimized then return end if not isMax then savedRect.pos=Vector2.new(shell.Position.X.Offset,shell.Position.Y.Offset) savedRect.size=Vector2.new(shell.AbsoluteSize.X,shell.AbsoluteSize.Y) local p,s=fullscreenRect() tw(shell,MOTION.win,{Size=offset(s.X,s.Y), Position=offset(p.X,p.Y)}) tw(shellCorner,MOTION.win,{CornerRadius=UDim.new(0,0)}) btnMax.Text="❐" isMax=true else tw(shell,MOTION.win,{Size=offset(savedRect.size.X,savedRect.size.Y), Position=offset(savedRect.pos.X,savedRect.pos.Y)}) tw(shellCorner,MOTION.win,{CornerRadius=UDim.new(0,10)}) btnMax.Text="□" isMax=false end end)
-- title drag only when unlocked
do local drag=false; local sd,sp
    titleBar.InputBegan:Connect(function(i) if isMax or minimized or verityLocked then return end if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true sd=i.Position sp=Vector2.new(shell.Position.X.Offset,shell.Position.Y.Offset) end end)
    UserInputService.InputChanged:Connect(function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-sd shell.Position=offset(sp.X+d.X,sp.Y+d.Y) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
end

-- Content
local contentHolder=new("Frame",{BackgroundTransparency=1, Position=offset(0,36), Size=UDim2.new(1,0,1,-36), ZIndex=11, Parent=canvas})
local SIDEBAR_W=160
local sidebar=new("Frame",{BackgroundTransparency=1, Size=UDim2.new(0,SIDEBAR_W,1,0), ZIndex=11, Parent=contentHolder}) pad(sidebar,8,8,8,8)
local tabBar=new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,1,-24), ZIndex=11, Parent=sidebar}) vlist(tabBar,6)
local main=new("Frame",{BackgroundTransparency=1, Position=offset(SIDEBAR_W,0), Size=UDim2.new(1,-SIDEBAR_W,1,0), ZIndex=11, Parent=contentHolder}) pad(main,10,10,8,12)
local searchWrap=new("Frame",{BackgroundColor3=Color3.fromHex("0a0a0a"), Size=UDim2.new(1,0,0,32), ZIndex=12, Parent=main}) corner(searchWrap,8) stroke(searchWrap,T.border) pad(searchWrap,0,0,10,10)
local searchBox=new("TextBox",{BackgroundTransparency=1, Size=UDim2.fromScale(1,1), Font=FONT, Text="", PlaceholderText="Search features…", PlaceholderColor3=T.dim, TextSize=12, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ClearTextOnFocus=false, ZIndex=13, Parent=searchWrap})
local page=new("ScrollingFrame",{BackgroundTransparency=1, Position=offset(0,40), Size=UDim2.new(1,0,1,-40), BorderSizePixel=0, ScrollBarThickness=4, ScrollBarImageColor3=T.border, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollingDirection=Enum.ScrollingDirection.Y, ZIndex=11, Parent=main}) vlist(page,10) pad(page,4,12,4,8)

-- Runtime core10
local Features={}; local order={}; local RState={}; local Active={}
local function register(def) Features[def.id]=def table.insert(order,def.id) RState[def.id]={enabled=false, method=def.methods[1].id, settings={}} for k,m in pairs(def.settings or {}) do RState[def.id].settings[k]=m.default end end
local function methodById(def,mid) for _,m in ipairs(def.methods) do if m.id==mid then return m end end return def.methods[1] end
local function stop(id) local live=Active[id] if not live then return end Active[id]=nil if live.method.stop then pcall(live.method.stop,live.ctx) end live.ctx.maid:clean() EVENTS.fire("featureToggled",id,false) Verity:Set("neutral") end
local function start(id) local def=Features[id] if not def then return false end local st=RState[id] local m=methodById(def,st.method) if m.requiresChar~=false and not alive() then pushToast(def.name.." needs character","warn") return false end stop(id) local maid=Maid.new() local ctx={maid=maid, s=st.settings, notify=pushToast, every=function(_,bucket,fn) local key=id..":"..bucket..":"..tostring(tick()) Scheduler.add(bucket,key,fn) maid:give(function() Scheduler.remove(bucket,key) end) end} local ok,err=pcall(m.start,ctx) if not ok then maid:clean() pushToast(def.name.." "..m.name.." failed: "..tostring(err),"bad",4) Verity:Set("glitch") task.delay(1.5,function() Verity:Set("neutral") end) return false end Active[id]={ctx=ctx, method=m} EVENTS.fire("featureToggled",id,true) Verity:Set("happy") task.delay(1,function() Verity:Set("neutral") end) return true end
local function setEnabled(id,on) local st=RState[id] if not st then return false end if on then if start(id) then st.enabled=true return true end st.enabled=false return false end stop(id) st.enabled=false return true end

local function makeToggle(parent,cfg)
    local state=cfg.value and true or false
    local btn=new("TextButton",{BackgroundColor3=state and T.on or T.panel, Size=offset(40,20), Text="", AutoButtonColor=false, BorderSizePixel=0, ZIndex=14, Parent=parent}) corner(btn,10)
    local knob=new("Frame",{BackgroundColor3=T.text, Size=offset(16,16), Position=UDim2.new(0,state and 22 or 2,0.5,-8), BorderSizePixel=0, ZIndex=15, Parent=btn}) corner(knob,8)
    local function render(v) state=v and true or false tw(btn,MOTION.hover,{BackgroundColor3=state and T.on or T.panel}) tw(knob,TweenInfo.new(0.14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(0,state and 22 or 2,0.5,-8)}) end
    btn.Activated:Connect(function() local want=not state if cfg.onChange then local ok,res=pcall(cfg.onChange,want) if not ok then pushToast(tostring(res),"bad") return end if res==false then return end end render(want) end)
    return {set=function(_,v) render(v) end, get=function() return state end, instance=btn}
end

local function makeSlider(parent,cfg)
    local min,max,step = cfg.min or 0, cfg.max or 100, cfg.step or 1
    local value=cfg.default or min
    local row=new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,22), ZIndex=13, Parent=parent})
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(0,90,1,0), Font=FONT, Text=cfg.label or "Value", TextSize=11, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=14, Parent=row})
    local valLabel=new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(0,40,1,0), Position=UDim2.new(1,-40,0,0), Font=FONTB, Text=tostring(value), TextSize=11, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=14, Parent=row})
    local track=new("Frame",{BackgroundColor3=T.off, Size=UDim2.new(1,-140,0,4), Position=UDim2.new(0,90,0.5,-2), ZIndex=14, Parent=row}) corner(track,2)
    local fill=new("Frame",{BackgroundColor3=T.accent, Size=UDim2.new((value-min)/(max-min),0,1,0), ZIndex=15, Parent=track}) corner(fill,2)
    local knob=new("Frame",{BackgroundColor3=T.text, Size=offset(14,14), Position=UDim2.new((value-min)/(max-min),-7,0.5,-7), ZIndex=16, Parent=track}) corner(knob,7)
    local function set(v, silent)
        v=math.clamp(math.floor(v/step+0.5)*step, min, max)
        value=v
        local t=(value-min)/(max-min)
        fill.Size=UDim2.new(t,0,1,0)
        knob.Position=UDim2.new(t,-7,0.5,-7)
        valLabel.Text=tostring(value)
        if not silent and cfg.onChange then pcall(cfg.onChange, value) end
    end
    local dragging=false
    local function update(x)
        local p=(x - track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1)
        set(min + p*(max-min))
    end
    track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true update(i.Position.X) end end)
    knob.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true end end)
    UserInputService.InputChanged:Connect(function(i) if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then update(i.Position.X) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
    row.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true update(i.Position.X) end end)
    set(value, true)
    return {set=set, get=function() return value end}
end

-- 10 core (Pass 1: Utility ranges)
register({id="fly", name="Fly", category="Movement", desc="WASD fly", settings={speed={default=60, min=20, max=500, step=5}}, methods={{id="cframe", name="CFrame", start=function(ctx) ctx:every("heartbeat",function() if not alive() then return end local cf=Workspace.CurrentCamera.CFrame local d=Vector3.zero if UserInputService:IsKeyDown(Enum.KeyCode.W) then d+=cf.LookVector end if UserInputService:IsKeyDown(Enum.KeyCode.S) then d-=cf.LookVector end if UserInputService:IsKeyDown(Enum.KeyCode.A) then d-=cf.RightVector end if UserInputService:IsKeyDown(Enum.KeyCode.D) then d+=cf.RightVector end if d.Magnitude>0 then Char.root.CFrame=Char.root.CFrame + d.Unit*ctx.s.speed*0.016 end end) end}}})
register({id="walkspeed", name="WalkSpeed", category="Movement", desc="WalkSpeed", settings={speed={default=32, min=16, max=400, step=2}}, methods={{id="direct", name="Direct", start=function(ctx) local hum=Char.hum hum.WalkSpeed=ctx.s.speed ctx:every("heartbeat",function() if alive() and Char.hum.WalkSpeed~=ctx.s.speed then Char.hum.WalkSpeed=ctx.s.speed end end) end}}})
register({id="jumppower", name="JumpPower", category="Movement", desc="Jump tweak", settings={power={default=50, min=50, max=250, step=5}}, methods={{id="jp", name="JumpPower", start=function(ctx) Char.hum.JumpPower=ctx.s.power ctx:every("heartbeat", function() if alive() and Active.jumppower then Char.hum.JumpPower=ctx.s.power end end) end}}})
register({id="infjump", name="Infinite Jump", category="Movement", desc="JumpRequest repeat", methods={{id="loop", name="Loop", start=function(ctx)
    local conn = UserInputService.JumpRequest:Connect(function() if alive() then Char.hum:ChangeState(Enum.HumanoidStateType.Jumping) end end)
    local function cleanup() if conn and conn.Connected then pcall(function() conn:Disconnect() end) end end
    ctx.maid:give(cleanup)
    ctx.maid:give(function() cleanup() end)
    -- also owned by rootMaid for leak-free lifecycle (idempotent)
    rootMaid:give(function() cleanup() end)
end}}})
register({id="noclip", name="Noclip", category="Movement", desc="Walk through walls", methods={{id="loop", name="Loop", start=function(ctx) ctx:every("heartbeat",function() if not Char.model then return end for _,p in ipairs(Char.model:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end) end}}})
register({id="fov", name="FOV", category="Visuals", desc="Camera FOV", settings={fov={default=90, min=60, max=120, step=1}}, methods={{id="direct", name="Direct", requiresChar=false, start=function(ctx) Workspace.CurrentCamera.FieldOfView=ctx.s.fov ctx:every("heartbeat",function() Workspace.CurrentCamera.FieldOfView=ctx.s.fov end) end}}})
register({id="fullbright", name="Fullbright", category="Visuals", desc="No shadows", methods={{id="on", name="On", requiresChar=false, start=function(ctx) Lighting.Brightness=2 Lighting.ClockTime=14 Lighting.FogEnd=1e6 Lighting.GlobalShadows=false end}}})
register({id="esp", name="Player ESP", category="Visuals", desc="Billboard ESP", methods={{id="billboard", name="Billboard", requiresChar=false, start=function(ctx)
    local folder=new("Folder",{Name="EquilibriumESP", Parent=Camera}) ctx.maid:give(function() folder:Destroy() end)
    ctx:every("heartbeat",function() for _,plr in ipairs(Players:GetPlayers()) do if plr~=LP and plr.Character and plr.Character:FindFirstChild("Head") then local bb=folder:FindFirstChild(plr.Name) or new("BillboardGui",{Name=plr.Name, Adornee=plr.Character.Head, Size=UDim2.fromOffset(100,20), AlwaysOnTop=true, Parent=folder}) local lbl=bb:FindFirstChildOfClass("TextLabel") or new("TextLabel",{BackgroundTransparency=1, Size=UDim2.fromScale(1,1), Font=FONTB, Text=plr.Name, TextSize=12, TextColor3=T.text, Parent=bb}) end end end)
end}}})
register({id="tracer", name="Tracers", category="Visuals", desc="Coming Soon", methods={{id="draw", name="Draw", requiresChar=false, start=function(ctx) end}}})
register({id="serverhop", name="Server Hop", category="Server", desc="Find new server", methods={{id="hop", name="Hop", requiresChar=false, start=function(ctx) end}}, actions={{text="Hop Now", run=function() local ok,body=pcall(function() return game:HttpGet(("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100"):format(game.PlaceId)) end) if not ok then pushToast("HttpGet blocked by executor","warn") return end local data=HttpService:JSONDecode(body) local cands={} for _,sv in ipairs(data.data or {}) do if sv.id~=game.JobId and sv.playing<sv.maxPlayers then table.insert(cands,sv) end end if #cands==0 then pushToast("No servers","warn") return end local pick=cands[math.random(1,#cands)] TeleportService:TeleportToPlaceInstance(game.PlaceId,pick.id,LP) end}}})
register({id="teleport", name="Teleport", category="Teleport", desc="Coming Soon", methods={{id="direct", name="Direct", start=function(ctx) end}}})

-- Tabs
local TABS={"Movement","Visuals","Teleport","Server","Settings"}; local currentTab=TABS[1]; local tabButtons={}; local cards={}
local function refresh() for _,c in ipairs(cards) do c.frame.Visible=(currentTab==c.tab) end end
for _,name in ipairs(TABS) do local b=new("TextButton",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,36), Text="", AutoButtonColor=false, ZIndex=12, Parent=tabBar}) local lbl=new("TextLabel",{BackgroundTransparency=1, Size=UDim2.fromScale(1,1), Font=FONT, Text=name, TextSize=12, TextColor3=T.dim, ZIndex=13, Parent=b}) b.Activated:Connect(function() currentTab=name for _,bb in pairs(tabButtons) do bb.lbl.TextColor3=T.dim end lbl.TextColor3=T.text refresh() end) tabButtons[name]={btn=b,lbl=lbl} if name==currentTab then lbl.TextColor3=T.text end end
local function makeCard(tab,title,desc) local card=new("Frame",{BackgroundColor3=T.panel, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BorderSizePixel=0, Visible=tab==currentTab, ZIndex=12, Parent=page}) corner(card,10) stroke(card,T.border) pad(card,10,10,12,12) vlist(card,8) new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,16), Font=FONTB, Text=title, TextSize=13, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=card}) if desc then new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,14), Font=FONT, Text=desc, TextSize=11, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=card}) end local c={frame=card,tab=tab} table.insert(cards,c) return card end
local catMap={Movement={}, Visuals={}, Teleport={}, Server={}, Settings={}} for _,id in ipairs(order) do local f=Features[id] table.insert(catMap[f.category] or catMap["Settings"], f) end
for _,cat in ipairs(TABS) do for _,def in ipairs(catMap[cat] or {}) do
    local isComingSoon = (def.id=="tracer" or def.id=="teleport")
    local card=makeCard(cat, def.name, def.desc)
    if isComingSoon then card.BackgroundTransparency=0.4 end
    local row=new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=13, Parent=card})
    local tog=makeToggle(row,{value=false, onChange=function(v) if isComingSoon then return false end return setEnabled(def.id, v) end})
    tog.instance.Position=UDim2.new(1,-40,0.5,-10)
    if isComingSoon then tog.instance.Active=false tog.instance.AutoButtonColor=false tog.instance.BackgroundColor3=T.off end
    -- sliders for utility ranges (Pass 1 final: Fly/WalkSpeed/FOV + JumpPower Power)
    if def.id=="fly" then
        makeSlider(card,{label="Speed", min=20, max=500, step=5, default=RState[def.id].settings.speed, onChange=function(v) RState[def.id].settings.speed=v end})
    elseif def.id=="walkspeed" then
        makeSlider(card,{label="Speed", min=16, max=400, step=2, default=RState[def.id].settings.speed, onChange=function(v) RState[def.id].settings.speed=v end})
    elseif def.id=="fov" then
        makeSlider(card,{label="FOV", min=60, max=120, step=1, default=RState[def.id].settings.fov, onChange=function(v) RState[def.id].settings.fov=v if Active[def.id] then Workspace.CurrentCamera.FieldOfView=v end end})
    elseif def.id=="jumppower" then
        makeSlider(card,{label="Power", min=50, max=250, step=5, default=RState[def.id].settings.power, onChange=function(v) RState[def.id].settings.power=v if Active[def.id] and alive() then Char.hum.JumpPower=v end end})
    end
    if def.actions then for _,a in ipairs(def.actions) do local btn=new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(1,0,0,28), Text=a.text, Font=FONT, TextSize=12, TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=card}) corner(btn,8) stroke(btn,T.border) btn.Activated:Connect(function() pcall(a.run) end) end end
end end
do local card=makeCard("Settings","Lifecycle","Hybrid X: click hide • hold 0.9s on red → unload") local btn=new("TextButton",{BackgroundColor3=T.warn, Size=UDim2.new(1,0,0,28), Text="UNLOAD Equilibrium", Font=FONTB, TextSize=12, TextColor3=Color3.new(1,1,1), AutoButtonColor=false, ZIndex=14, Parent=card}) corner(btn,8) btn.Activated:Connect(function() local fn=getgenv()[UNLOAD_KEY] if fn then pcall(fn) end end) end

-- Hotkeys
local toggleKey=Enum.KeyCode.RightShift; local miniKey=Enum.KeyCode.Semicolon
UserInputService.InputBegan:Connect(function(inp,proc) if proc then return end if inp.KeyCode==toggleKey then screen.Enabled=not screen.Enabled if minimized and screen.Enabled then doRestore() end elseif inp.KeyCode==miniKey then if screen.Enabled and not minimized then doMinimize() elseif minimized then doRestore() end end end)

task.spawn(function() while task.wait(2.8+math.random()) do if screen.Enabled then verityBlink() end end end)

local unload=false
local function doUnload() if unload then return end unload=true Scheduler.stopAll() for id in pairs(Active) do pcall(stop,id) end pcall(function() rootMaid:destroy() end) pcall(function() screen:Destroy() end) puckDot.Visible=false if getgenv()[UNLOAD_KEY]==doUnload then getgenv()[UNLOAD_KEY]=nil end print("[Equilibrium] unloaded") end
getgenv()[UNLOAD_KEY]=doUnload
getgenv().__equilibriumRegistry=getgenv().__equilibriumRegistry or {} table.insert(getgenv().__equilibriumRegistry, doUnload)

-- Robust mount: try gethui -> CoreGui -> PlayerGui, with debug (shared for hub + notify)
local function mountGui(gui)
    local parent=nil; local where="none"
    if typeof(gethui)=="function" then local ok,h=pcall(gethui) if ok and h then parent=h where="gethui()" end end
    if not parent then local ok=pcall(function() parent=game:GetService("CoreGui") where="CoreGui" gui.Parent=parent end) if not ok then parent=nil end end
    if parent and gui.Parent~=parent then gui.Parent=parent end
    if not gui.Parent or gui.Parent==nil then
        local pg=LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui",5)
        if pg then gui.Parent=pg where="PlayerGui" end
    end
    return where
end
local function mount()
    local where=mountGui(screen)
    mountGui(notifyGui)
    print("[Equilibrium] mounted hub to "..where.." Enabled="..tostring(screen.Enabled).." Parent="..tostring(screen.Parent and screen.Parent.Name or "nil").." notify="..tostring(notifyGui.Parent and notifyGui.Parent.Name or "nil"))
    return where
end

local where=mount()
screen.Enabled=true
-- force visible after a frame (executor race) — guarded against unload/destroyed race (Pass 1 final hotfix)
task.delay(0.12,function()
    if unload then return end
    if not screen then return end
    local ok, parent = pcall(function() return screen.Parent end)
    if not ok then return end
    if not screen.Enabled then screen.Enabled=true end
    if parent==nil then
        -- re-validate before mount — don't resurrect destroyed session
        if unload then return end
        local ok2 = pcall(function() return screen.Parent end)
        if not ok2 then return end
        mount()
        screen.Enabled=true
    end
    pushToast("Equilibrium v1.1 — Slate 070707 • _ □ × • V puck • 🔒="..(verityLocked and "locked" or "unlocked"), "warn",4)
    print("[Equilibrium] visible — where="..where.." size="..tostring(shell.AbsoluteSize))
end)

-- 2-way: verity dot on notification while minimized
EVENTS.on("verityLog",function() if minimized then puckDot.Visible=true task.delay(4,function() puckDot.Visible=false end) end end)

_G.Equilibrium={Settings=Settings, EVENTS=EVENTS, Verity=Verity, Context=Context, KNOWLEDGE=KNOWLEDGE}
_G.EQ_EVENTS=EVENTS

-- =========================================================================
-- VERITY UNIFIED SINGLE-SCRIPT (inlined, no external modules)
-- =========================================================================
do
-- VERITY — UNIFIED SINGLE-SCRIPT 2D CHARACTER (Equilibrium Hub companion)
-- Sections: CONFIG | WARDROBE DATA | EXPRESSIONS | PROFILE | CHARACTER CREATION | LAYER RENDERING | ANIMATION TIMING | ANIMATION STATES | EFFECTS | RESPONSE/TEXT | WARDROBE UI | EVENTS | PERSISTENCE | INIT
-- All Frame/UICorner/UIStroke procedural 72x96 → 168 orb, Slate 070707 / Gold border, one Heartbeat loop, layered priority, wardrobe global

local VERITY_VERSION = "1.0"

-- =========================================================================
-- CONFIG
-- =========================================================================
local CONFIG = {
    Size = Vector2.new(72,96),
    Orb = 168,
    Bg = Color3.fromHex("070707"),
    Gold = Color3.fromRGB(201,168,106),
    Slate = Color3.fromHex("141414"),
    DEBUG = false,
    ConversationActiveTimeout = 30, -- configurable seconds, wardrobe/system do not reset
}

-- =========================================================================
-- WARDROBE DATA (SYSTEM ID → displayName/desc)  procedural Frames only
-- =========================================================================
local WARDROBE = {
    Head = {
        Head_01={name="Default", desc="Standard Verity head."},
        Head_02={name="Soft", desc="Slightly rounder and friendlier."},
        Head_03={name="Sharp", desc="Slightly more angular and serious."},
    },
    Hair = {
        Hair_01={name="Default", desc="Medium styled hair with recognizable front strands."},
        Hair_02={name="Neat", desc="Clean and controlled hairstyle."},
        Hair_03={name="Messy", desc="Uneven hair with separated strands."},
        Hair_04={name="Fluffy", desc="Fuller, rounded hairstyle."},
        Hair_05={name="Side Sweep", desc="Hair swept toward one side."},
        Hair_06={name="Long Fringe", desc="Long bangs partially covering the forehead."},
        Hair_07={name="Short", desc="Simple short hairstyle."},
        Hair_08={name="Bedhead", desc="Messy hair with random strands."},
        Hair_09={name="Combed Back", desc="Hair pushed away from the face."},
        Hair_10={name="Long", desc="Longer hair reaching toward the shoulders."},
    },
    Eyes = {
        Eyes_01={name="Default", desc="Focused direct gaze."},
        Eyes_02={name="Relaxed", desc="Half-lidded calm eyes."},
        Eyes_03={name="Wide", desc="Alert and surprised."},
        Eyes_04={name="Narrow", desc="Confident or suspicious."},
        Eyes_05={name="Curious", desc="Slightly widened and attentive."},
        Eyes_06={name="Tired", desc="Heavy eyelids."},
        Eyes_07={name="Happy", desc="Soft cheerful eyes."},
        Eyes_08={name="Glitched", desc="Subtle digital distortion."},
    },
    Brows = {
        Brows_01={name="Neutral"}, Brows_02={name="Raised"}, Brows_03={name="Focused"},
        Brows_04={name="Worried"}, Brows_05={name="Confused"}, Brows_06={name="Annoyed"},
    },
    Mouth = {
        Mouth_01={name="Neutral", desc="Small straight mouth."},
        Mouth_02={name="Soft Smile"}, Mouth_03={name="Smile"}, Mouth_04={name="Smirk"},
        Mouth_05={name="Talking"}, Mouth_06={name="Laughing"}, Mouth_07={name="Surprised"},
        Mouth_08={name="Concerned"}, Mouth_09={name="Pout"},
        Talk_01={name="Closed"}, Talk_02={name="Small Open"}, Talk_03={name="Wide Open"},
    },
    Body = {
        Body_01={name="Default", desc="Slim standard Verity body."},
        Body_02={name="Relaxed"}, Body_03={name="Formal"},
    },
    Tops = {
        Top_01={name="Default Jacket"}, Top_02={name="Hoodie"}, Top_03={name="Tech Jacket"}, Top_04={name="Sweater"},
        Top_05={name="Turtleneck"}, Top_06={name="Long Coat"}, Top_07={name="Casual Shirt"}, Top_08={name="Zip Jacket"},
    },
    Bottoms = {
        Bottom_01={name="Dark Pants"}, Bottom_02={name="Jeans"}, Bottom_03={name="Cargo Pants"}, Bottom_04={name="Joggers"}, Bottom_05={name="Shorts"},
    },
    Shoes = { Shoes_01={name="Sneakers"}, Shoes_02={name="High Tops"}, Shoes_03={name="Boots"}, Shoes_04={name="Casual Shoes"}, },
    HeadAcc = {
        HeadAccessory_01={name="None"}, HeadAccessory_02={name="Beanie"}, HeadAccessory_03={name="Cap"}, HeadAccessory_04={name="Headphones"},
        HeadAccessory_05={name="Cat Ears"}, HeadAccessory_06={name="Bunny Ears"}, HeadAccessory_07={name="Party Hat"}, HeadAccessory_08={name="Balloon Hat"},
        HeadAccessory_09={name="Wizard Hat"}, HeadAccessory_10={name="Tiny Crown"}, HeadAccessory_11={name="Halo"}, HeadAccessory_12={name="Propeller Hat"},
    },
    FaceAcc = {
        FaceAccessory_01={name="None"}, FaceAccessory_02={name="Glasses"}, FaceAccessory_03={name="Round Glasses"}, FaceAccessory_04={name="Sunglasses"},
        FaceAccessory_05={name="Pixel Glasses"}, FaceAccessory_06={name="Monocle"}, FaceAccessory_07={name="Cheek Sticker"}, FaceAccessory_08={name="Blush"}, FaceAccessory_09={name="Digital Lens"},
    },
    NeckAcc = { NeckAccessory_01={name="None"}, NeckAccessory_02={name="Scarf"}, NeckAccessory_03={name="Necklace"}, NeckAccessory_04={name="Pendant"}, NeckAccessory_05={name="Bow Tie"}, },
    BodyAcc = { BodyAccessory_01={name="None"}, BodyAccessory_02={name="Backpack"}, BodyAccessory_03={name="Crossbody Bag"}, BodyAccessory_04={name="Utility Belt"}, BodyAccessory_05={name="Cape"}, BodyAccessory_06={name="Blanket"}, },
    Held = {
        Held_01={name="None"}, Held_02={name="Lollipop"}, Held_03={name="Coffee"}, Held_04={name="Phone"}, Held_05={name="Notebook"},
        Held_06={name="Game Controller"}, Held_07={name="Balloon"}, Held_08={name="Plushie"}, Held_09={name="Rubber Duck"}, Held_10={name="Microphone"},
    },
    Effects = {
        Effect_01={name="None"}, Effect_02={name="Soft Glow"}, Effect_03={name="Digital Particles"}, Effect_04={name="Scanlines"},
        Effect_05={name="Pixel Flicker"}, Effect_06={name="Hologram"}, Effect_07={name="Glitch"}, Effect_08={name="Eye Glow"},
        Effect_09={name="Sparkles"}, Effect_10={name="Hearts"},
    },
}

-- =========================================================================
-- EXPRESSIONS (presets Eyes+Brows+Mouth)  Advanced can override one layer
-- =========================================================================
local EXPRESSIONS = {
    Expression_01={name="Neutral",   eyes="Eyes_01", brows="Brows_01", mouth="Mouth_01"},
    Expression_02={name="Happy",     eyes="Eyes_07", brows="Brows_01", mouth="Mouth_03"},
    Expression_03={name="Curious",   eyes="Eyes_05", brows="Brows_02", mouth="Mouth_02"},
    Expression_04={name="Surprised", eyes="Eyes_03", brows="Brows_02", mouth="Mouth_07"},
    Expression_05={name="Tired",     eyes="Eyes_06", brows="Brows_01", mouth="Mouth_01"},
    Expression_06={name="Amused",    eyes="Eyes_02", brows="Brows_02", mouth="Mouth_04"},
    Expression_07={name="Annoyed",   eyes="Eyes_04", brows="Brows_06", mouth="Mouth_01"},
    Expression_08={name="Concerned", eyes="Eyes_01", brows="Brows_04", mouth="Mouth_08"},
    Expression_09={name="Confused",  eyes="Eyes_05", brows="Brows_05", mouth="Mouth_08"},
    Expression_10={name="Glitched",  eyes="Eyes_08", brows="Brows_03", mouth="Mouth_05"},
}

-- =========================================================================
-- PROFILE (global, survives PlaceId)
-- =========================================================================
local PROFILE = {
    Head="Head_01", Hair="Hair_03", Eyes="Eyes_01", Brows="Brows_01", Mouth="Mouth_02", Body="Body_01",
    Top="Top_02", Bottom="Bottom_01", Shoes="Shoes_01",
    HeadAccessory="HeadAccessory_08", FaceAccessory="FaceAccessory_02", NeckAccessory="NeckAccessory_01", BodyAccessory="BodyAccessory_01",
    Held="Held_02", Expression="Expression_02", Effect="Effect_01",
}

-- =========================================================================
-- SERVICES / STATE
-- =========================================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

local Verity = {}
local Gui, VerityCanvas, OrbsFrame
local Anchors = {} -- BodyAnchor, HeadAnchor, HairAnchor, EyeAnchor, BrowAnchor, MouthAnchor, ClothingAnchor, HeldItemAnchor, EffectAnchor
local Layers = {} -- cached Frames: body, head, hair, eyes, brows, mouth, clothing, held, effect
local DEBUG_LABEL

-- =========================================================================
-- ANIMATION TIMING — single central clock
-- =========================================================================
local ANIMATION_TIMING = {
    GlobalSpeed = 1.0,
    Idle = { Speed=1.0, MovementAmount=1, Cycle=3.5 },
    Blink = { MinimumDelay=2.5, MaximumDelay=6.0, ClosedTime=0.10, DoubleBlinkChance=0.08 },
    Talking = { MouthInterval=0.10, RandomVariation=0.04 },
    Thinking = { Cycle=2.5 },
    Reaction = { DefaultDuration=0.75, Happy=0.75, Surprised=0.65 },
    Transition = { DefaultDuration=0.15 },
    Effects = { GlowSpeed=1.5, FlickerSpeed=0.12, GlitchInterval=2.5 },
}

local animationState = {
    Current="Idle", Previous="Idle", Time=0, StateTime=0, Speed=1,
    Talking=false, Blinking=false, Reaction=nil, ReactionTime=0, Expression="Expression_01", Paused=false,
}

local animationTimers = { Blink=0, BlinkNext=4, Talk=0, Idle=0, Expression=0, Effect=0, Glitch=0 }

local function RandomRange(a,b) return a + math.random()*(b-a) end
local heartbeatConn

-- idle variation pool 60/15/10/5/5/5
local IDLE_POOL = {
    {id="Idle_01", name="Normal", w=60, fn=function(t) return math.sin(t*1.8)*1.0, math.sin(t*1.8)*0.5 end},
    {id="Idle_02", name="Slight Lean", w=15, fn=function(t) return math.sin(t*1.4)*1.2 + 0.6, math.sin(t*1.4)*0.3 end},
    {id="Idle_03", name="Head Tilt", w=10, fn=function(t) return math.sin(t*1.6)*0.6, math.cos(t*1.6)*0.4 end},
    {id="Idle_04", name="Look Around", w=5, fn=function(t) return math.sin(t*2.8)*0.3, math.sin(t*3.2)*0.2 end},
    {id="Idle_05", name="Small Bounce", w=5, fn=function(t) return math.abs(math.sin(t*3.0))*1.4, 0 end},
    {id="Idle_06", name="Still", w=5, fn=function() return 0,0 end},
}
local currentIdle = IDLE_POOL[1]
local idleCycleStart = 0
local function pickIdle()
    local roll=math.random()*100 local acc=0
    for _,e in ipairs(IDLE_POOL) do acc+=e.w if roll<=acc then currentIdle=e break end end
    idleCycleStart=animationState.Time
end

-- helpers
local function tween(obj, props, dur) return TweenService:Create(obj, TweenInfo.new(dur or ANIMATION_TIMING.Transition.DefaultDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props) end

-- idle
local function UpdateIdle(dt)
    local t=animationState.Time*ANIMATION_TIMING.Idle.Speed*animationState.Speed
    -- cycle reset
    if t - idleCycleStart >= ANIMATION_TIMING.Idle.Cycle then pickIdle() end
    local by,bx = currentIdle.fn(t)
    by*= ANIMATION_TIMING.Idle.MovementAmount; bx*= ANIMATION_TIMING.Idle.MovementAmount
    -- Body tiny Y, Head slight, Hair follows Head +0.1
    if Layers.body and Anchors.BodyAnchor then
        Anchors.BodyAnchor.Position = UDim2.new(0.5,0,0.5, by*0.6)
    end
    if Anchors.HeadAnchor then
        Anchors.HeadAnchor.Position = UDim2.new(0.5, bx*0.5, 0.35, by*0.4)
    end
    if Anchors.HairAnchor and Anchors.HeadAnchor then
        -- secondary offset
        Anchors.HairAnchor.Position = UDim2.new(0, bx*0.6, 0, by*0.5 -2)
    end
    if CONFIG.DEBUG and DEBUG_LABEL then DEBUG_LABEL.Text = ("Idle:%s T=%.1f"):format(currentIdle.id, t) end
end

-- blink
local blinkPhase="open" -- open->closing->closed->opening
local blinkT=0
local function doBlink()
    animationState.Blinking=true; blinkPhase="closing"; blinkT=0
end
local function UpdateBlink(dt)
    animationTimers.Blink += dt * animationState.Speed
    if not animationState.Blinking and animationTimers.Blink >= animationTimers.BlinkNext then
        doBlink(); animationTimers.Blink=0
        animationTimers.BlinkNext = RandomRange(ANIMATION_TIMING.Blink.MinimumDelay, ANIMATION_TIMING.Blink.MaximumDelay)
    end
    if not animationState.Blinking then return end
    blinkT+= dt*animationState.Speed
    local closing=0.05; local closed=ANIMATION_TIMING.Blink.ClosedTime; local opening=0.05
    if blinkPhase=="closing" then
        local p=math.clamp(blinkT/closing,0,1)
        if Layers.eyes then for _,e in ipairs(Layers.eyes) do e.Size = UDim2.new(0,6,0, math.clamp(8*(1-p)+1*p,1,8)) end end
        if blinkT>=closing then blinkPhase="closed"; blinkT=0 end
    elseif blinkPhase=="closed" then
        if blinkT>=closed then blinkPhase="opening"; blinkT=0 end
    elseif blinkPhase=="opening" then
        local p=math.clamp(blinkT/opening,0,1)
        if Layers.eyes then for _,e in ipairs(Layers.eyes) do e.Size = UDim2.new(0,6,0, math.clamp(1*(1-p)+8*p,1,8)) end end
        if blinkT>=opening then
            animationState.Blinking=false; blinkPhase="open"; blinkT=0
            if math.random() < ANIMATION_TIMING.Blink.DoubleBlinkChance then
                animationTimers.Blink = animationTimers.BlinkNext - RandomRange(0.12,0.22)
            end
        end
    end
end

-- talking — mouth only, 0.10 ±0.04 random, Talk_01→02→03
local talkFrames={"Mouth_Talk_01","Mouth_Talk_02","Mouth_Talk_03"}
local talkIdx=1; local talkDur=ANIMATION_TIMING.Talking.MouthInterval
local function UpdateTalking(dt)
    if not animationState.Talking then return end
    animationTimers.Talk += dt*animationState.Speed
    if animationTimers.Talk >= talkDur then
        animationTimers.Talk=0
        talkIdx = (talkIdx % #talkFrames)+1
        talkDur = ANIMATION_TIMING.Talking.MouthInterval + RandomRange(-ANIMATION_TIMING.Talking.RandomVariation, ANIMATION_TIMING.Talking.RandomVariation)
        local id=talkFrames[talkIdx]
        -- map to mouth size
        if Layers.mouth then
            if id=="Mouth_Talk_01" then Layers.mouth.Size=UDim2.new(0,14,0,4)
            elseif id=="Mouth_Talk_02" then Layers.mouth.Size=UDim2.new(0,16,0,6)
            else Layers.mouth.Size=UDim2.new(0,18,0,8) end
        end
    end
end

-- reaction — priority 3, restores Previous expression after duration
local function PlayReaction(name)
    local dur = ANIMATION_TIMING.Reaction[name] or ANIMATION_TIMING.Reaction.DefaultDuration
    animationState.Previous = animationState.Current
    animationState.Current = "Reaction"
    animationState.Reaction = name
    animationState.ReactionTime = 0
    -- apply reaction expression
    local map={Happy="Expression_02", Surprised="Expression_04", Confused="Expression_09", Annoyed="Expression_07", Concerned="Expression_08"}
    local expr = map[name] or "Expression_01"
    Verity.SetExpression(expr, true) -- instant per reaction
    -- body/head kick
    if Anchors.BodyAnchor then tween(Anchors.BodyAnchor,{Position=UDim2.new(0.5,0,0.5,-4)},0.08):Play() end
end

local function UpdateReaction(dt)
    if animationState.Current~="Reaction" then return end
    animationState.ReactionTime+= dt*animationState.Speed
    local need = ANIMATION_TIMING.Reaction[animationState.Reaction] or ANIMATION_TIMING.Reaction.DefaultDuration
    if animationState.ReactionTime >= need then
        -- restore
        Verity.SetExpression(PROFILE.Expression, true)
        if Anchors.BodyAnchor then tween(Anchors.BodyAnchor,{Position=UDim2.new(0.5,0,0.5,0)},0.10):Play() end
        animationState.Current = animationState.Previous or "Idle"
        animationState.Reaction=nil; animationState.ReactionTime=0
    end
end

-- effects — glow 1.5s cycle, flicker 0.12, glitch 2.5 interval random 2-5
local effectPhase=0; local glitchT=0; local glitchNext=RandomRange(2,5)
local function UpdateEffects(dt)
    animationTimers.Effect+= dt*animationState.Speed
    effectPhase+= dt*ANIMATION_TIMING.Effects.GlowSpeed
    if Layers.effectGlow then
        local a = 0.5 + math.sin(effectPhase)*0.25
        Layers.effectGlow.BackgroundTransparency = a
    end
    -- scanlines slow 1-2px every few frames (static mostly)
    -- flicker occasional
    if animationTimers.Effect >= ANIMATION_TIMING.Effects.FlickerSpeed then
        if PROFILE.Effect=="Effect_05" and math.random()<0.08 then
            if Layers.effectFlicker then Layers.effectFlicker.BackgroundTransparency = math.random()<0.5 and 0.3 or 0.7 end
        end
        animationTimers.Effect=0
    end
    glitchT+= dt*animationState.Speed
    if glitchT >= glitchNext then
        if PROFILE.Effect=="Effect_07" or Verity.state=="Glitched" or math.random()<0.04 then
            local dx=math.random(-2,2); local dy=math.random(-1,1)
            if VerityCanvas then VerityCanvas.Position = UDim2.new(0.5, dx, 0.5, dy) end
            task.delay(RandomRange(0.05,0.15), function() if VerityCanvas then VerityCanvas.Position=UDim2.new(0.5,0,0.5,0) end end)
        end
        glitchT=0; glitchNext=RandomRange(2,5)
    end
end

-- main single loop
local function UpdateAnimations(dt)
    if animationState.Paused then return end
    dt *= ANIMATION_TIMING.GlobalSpeed * animationState.Speed
    animationState.Time+= dt; animationState.StateTime+= dt
    UpdateIdle(dt); UpdateBlink(dt); UpdateTalking(dt); UpdateReaction(dt); UpdateEffects(dt)
end

-- public animation API — inside same script
function Verity.SetAnimation(name) animationState.Previous=animationState.Current; animationState.Current=name; animationState.StateTime=0 end
function Verity.StartTalking() animationState.Talking=true; animationTimers.Talk=0; talkIdx=1 end
function Verity.StopTalking() animationState.Talking=false; -- restore mouth to expression
    local e=EXPRESSIONS[PROFILE.Expression] or EXPRESSIONS.Expression_01
    if Layers.mouth then Layers.mouth.Size = UDim2.new(0, (e and 14 or 14),0,4) end
end
function Verity.Blink() doBlink() end
function Verity.PlayReaction(name) PlayReaction(name) end
function Verity.SetAnimationSpeed(s) animationState.Speed=s end
function Verity.PauseAnimations() animationState.Paused=true end
function Verity.ResumeAnimations() animationState.Paused=false end
function Verity.SetExpression(id, instant)
    local e=EXPRESSIONS[id] if not e then return end
    PROFILE.Expression=id
    local dur = instant and 0 or ANIMATION_TIMING.Transition.DefaultDuration
    -- stagger 0.05 eyes, 0.10 brows, 0.15 mouth if animated
    if Layers.eyes then
        for _,eye in ipairs(Layers.eyes) do
            -- map eyes id to size
            local map={Eyes_01=8, Eyes_02=5, Eyes_03=10, Eyes_04=5, Eyes_05=9, Eyes_06=4, Eyes_07=7, Eyes_08=8}
            local h=map[e.eyes] or 8; tween(eye,{Size=UDim2.new(0,6,0,h)}, dur+0.05):Play()
        end
    end
    if Layers.brows then tween(Layers.brows[1],{Position=UDim2.new(0,0,0, ({Brows_02= -4, Brows_04=2})[e.brows] or 0)}, dur+0.08):Play() end
    if Layers.mouth and not animationState.Talking then tween(Layers.mouth,{Size=UDim2.new(0,14,0, ({Mouth_03=6, Mouth_07=8})[e.mouth] or 4)}, dur+0.12):Play() end
end

-- =========================================================================
-- CHARACTER CREATION — procedural Frames 72x96 → 168 orb
-- =========================================================================
local function corner(o,r) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r) c.Parent=o return c end
local function stroke(o,c,t) local s=Instance.new("UIStroke") s.Color=c s.Thickness=t s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border s.Parent=o return s end

function Verity.CreateCharacter(parent)
    -- canvas
    VerityCanvas = Instance.new("Frame")
    VerityCanvas.Name="VerityCanvas"; VerityCanvas.Size=UDim2.fromOffset(CONFIG.Size.X, CONFIG.Size.Y)
    VerityCanvas.Position=UDim2.new(0.5,0,0.5,0); VerityCanvas.AnchorPoint=Vector2.new(0.5,0.5)
    VerityCanvas.BackgroundTransparency=1; VerityCanvas.Parent=parent

    -- anchors
    for _,n in ipairs({"BodyAnchor","HeadAnchor","HairAnchor","EyeAnchor","BrowAnchor","MouthAnchor","ClothingAnchor","HeldItemAnchor","EffectAnchor"}) do
        local a=Instance.new("Frame") a.Name=n; a.Size=UDim2.fromOffset(1,1); a.BackgroundTransparency=1; a.Position=UDim2.new(0.5,0,0.5,0); a.AnchorPoint=Vector2.new(0.5,0.5); a.Parent=VerityCanvas; Anchors[n]=a
    end
    Anchors.BodyAnchor.Size=UDim2.fromOffset(40,48); Anchors.BodyAnchor.Position=UDim2.new(0.5,0,0.62,0)
    Anchors.HeadAnchor.Size=UDim2.fromOffset(34,36); Anchors.HeadAnchor.Position=UDim2.new(0.5,0,0.32,0)
    Anchors.HairAnchor.Parent=Anchors.HeadAnchor; Anchors.HairAnchor.Size=UDim2.fromOffset(36,14); Anchors.HairAnchor.Position=UDim2.new(0.5,0,0, -10)
    Anchors.EyeAnchor.Parent=Anchors.HeadAnchor
    Anchors.ClothingAnchor.Parent=Anchors.BodyAnchor
    Anchors.HeldItemAnchor.Parent=Anchors.BodyAnchor; Anchors.HeldItemAnchor.Position=UDim2.new(1, -6, 0.5, 8)
    Anchors.EffectAnchor.Parent=VerityCanvas

    -- Body
    local body=Instance.new("Frame") body.Name="Body"; body.Size=UDim2.fromOffset(28,36); body.Position=UDim2.new(0.5,0,0.5,0); body.AnchorPoint=Vector2.new(0.5,0.5); body.BackgroundColor3=Color3.fromHex("1e1e24"); body.Parent=Anchors.BodyAnchor corner(body,10) Layers.body=body
    -- Clothing (top)
    local top=Instance.new("Frame") top.Name="Top"; top.Size=UDim2.fromOffset(30,28); top.Position=UDim2.new(0.5,0,0, -2); top.AnchorPoint=Vector2.new(0.5,0); top.BackgroundColor3=Color3.fromHex("2a2a3a"); top.Parent=Anchors.ClothingAnchor corner(top,6) Layers.clothing=top
    -- Head
    local head=Instance.new("Frame") head.Name="Head"; head.Size=UDim2.fromOffset(34,30); head.Position=UDim2.new(0.5,0,0.5,0); head.AnchorPoint=Vector2.new(0.5,0.5); head.BackgroundColor3=Color3.fromRGB(255,220,55); head.Parent=Anchors.HeadAnchor corner(head,8) stroke(head, Color3.fromRGB(16,16,16),1) Layers.head=head
    -- Hair
    local hair=Instance.new("Frame") hair.Name="Hair"; hair.Size=UDim2.fromOffset(36,12); hair.Position=UDim2.new(0.5,0,0,0); hair.AnchorPoint=Vector2.new(0.5,0.5); hair.BackgroundColor3=Color3.fromHex("3a2a1a"); hair.Parent=Anchors.HairAnchor corner(hair,6) Layers.hair=hair
    -- Eyes (2)
    local eyes={}
    for i=1,2 do local e=Instance.new("Frame") e.Name="Eye"..i; e.Size=UDim2.fromOffset(6,8); e.Position= i==1 and UDim2.new(0,4,0.5,-2) or UDim2.new(1,-10,0.5,-2); e.BackgroundColor3=Color3.fromRGB(16,16,16); e.Parent=Anchors.HeadAnchor corner(e,3) table.insert(eyes,e)
        local pupil=Instance.new("Frame") pupil.Name="Pupil"; pupil.Size=UDim2.fromOffset(3,3); pupil.Position=UDim2.new(0.5,0,0.5,0); pupil.AnchorPoint=Vector2.new(0.5,0.5); pupil.BackgroundColor3=Color3.new(1,1,1); pupil.Parent=e corner(pupil,2)
    end
    Layers.eyes=eyes
    -- Brows (2 small bars)
    local brows={}
    for i=1,2 do local b=Instance.new("Frame") b.Name="Brow"..i; b.Size=UDim2.fromOffset(10,2); b.Position= i==1 and UDim2.new(0,2,0,4) or UDim2.new(1,-12,0,4); b.BackgroundColor3=Color3.fromRGB(16,16,16); b.Parent=Anchors.HeadAnchor corner(b,1) table.insert(brows,b) end
    Layers.brows=brows
    -- Mouth (CanvasGroup arch)
    local mouthCg=Instance.new("CanvasGroup") mouthCg.Name="Mouth"; mouthCg.Size=UDim2.fromOffset(18,8); mouthCg.Position=UDim2.new(0.5,0,1,-10); mouthCg.AnchorPoint=Vector2.new(0.5,0.5); mouthCg.BackgroundTransparency=1; mouthCg.Parent=Anchors.HeadAnchor
    local mouthFrame=Instance.new("Frame") mouthFrame.Name="MouthFrame"; mouthFrame.Size=UDim2.fromOffset(14,4); mouthFrame.Position=UDim2.new(0.5,0,0.5,0); mouthFrame.AnchorPoint=Vector2.new(0.5,0.5); mouthFrame.BackgroundColor3=Color3.fromRGB(16,16,16); mouthFrame.Parent=mouthCg corner(mouthFrame,2)
    Layers.mouth=mouthFrame; Layers.mouthCg=mouthCg
    -- Held item anchor visual
    local heldVis=Instance.new("Frame") heldVis.Name="HeldVis"; heldVis.Size=UDim2.fromOffset(12,12); heldVis.Position=UDim2.new(0.5,0,0.5,0); heldVis.AnchorPoint=Vector2.new(0.5,0.5); heldVis.BackgroundColor3=Color3.fromHex("ffb86a"); heldVis.Visible=false; heldVis.Parent=Anchors.HeldItemAnchor corner(heldVis,3) Layers.held=heldVis
    -- Effect glow overlay
    local glow=Instance.new("Frame") glow.Name="Glow"; glow.Size=UDim2.fromOffset(80,104); glow.Position=UDim2.new(0.5,0,0.5,0); glow.AnchorPoint=Vector2.new(0.5,0.5); glow.BackgroundColor3=Color3.fromHex("ffd23a"); glow.BackgroundTransparency=1; glow.Parent=Anchors.EffectAnchor corner(glow,16)
    Layers.effectGlow=glow
    local flicker=Instance.new("Frame") flicker.Name="Flicker"; flicker.Size=UDim2.fromOffset(80,104); flicker.Position=UDim2.new(0.5,0,0.5,0); flicker.AnchorPoint=Vector2.new(0.5,0.5); flicker.BackgroundTransparency=1; flicker.Parent=Anchors.EffectAnchor; Layers.effectFlicker=flicker

    if CONFIG.DEBUG then
        DEBUG_LABEL=Instance.new("TextLabel") DEBUG_LABEL.Name="Debug"; DEBUG_LABEL.Size=UDim2.new(1,0,0,14); DEBUG_LABEL.Position=UDim2.new(0,0,1,2); DEBUG_LABEL.BackgroundTransparency=1; DEBUG_LABEL.Text="DEBUG"; DEBUG_LABEL.TextSize=9; DEBUG_LABEL.TextColor3=Color3.fromHex("a0a0a8"); DEBUG_LABEL.Font=Enum.Font.Code; DEBUG_LABEL.Parent=VerityCanvas
    end
    return VerityCanvas
end

-- =========================================================================
-- WARDROBE APPLY — targeted refresh only affected layer(s)
-- =========================================================================
function Verity.ApplyProfile()
    -- head shape
    if Layers.head then
        local map={Head_01=8, Head_02=12, Head_03=2} local r=map[PROFILE.Head] or 8; local c=Layers.head:FindFirstChildOfClass("UICorner") if c then c.CornerRadius=UDim.new(0,r) end
    end
    -- hair
    if Layers.hair then local t={Hair_01="#3a2a1a",Hair_03="#4a3320",Hair_08="#3d2b1a"} local c=t[PROFILE.Hair] or "#3a2a1a" Layers.hair.BackgroundColor3=Color3.fromHex(c:gsub("#","")) end
    -- eyes/brows/mouth via expression
    Verity.SetExpression(PROFILE.Expression, true)
    -- clothing
    if Layers.clothing then local t={Top_01="#1a1a1e",Top_02="#2a2a3a",Top_03="#24303a"} local col=t[PROFILE.Top] or "#2a2a3a" Layers.clothing.BackgroundColor3=Color3.fromHex(col:gsub("#","")) end
    -- held
    if Layers.held then Layers.held.Visible = PROFILE.Held ~= "Held_01" and Anchors.BodyAnchor.Visible~=false end
    -- effect
    if Layers.effectGlow then Layers.effectGlow.Visible = PROFILE.Effect ~= "Effect_01" end
end

function Verity.Equip(category, id)
    if not WARDROBE[category] or not WARDROBE[category][id] then warn("[Verity] invalid equip",category,id) return false end
    -- map category to profile key
    local keyMap={Head="Head", Hair="Hair", Eyes="Eyes", Brows="Brows", Mouth="Mouth", Body="Body", Tops="Top", Bottoms="Bottom", Shoes="Shoes", HeadAcc="HeadAccessory", FaceAcc="FaceAccessory", NeckAcc="NeckAccessory", BodyAcc="BodyAccessory", Held="Held", Effects="Effect"}
    local pkey=keyMap[category] or category
    PROFILE[pkey]=id
    -- targeted refresh
    if category=="Hair" then
        if Layers.hair then local t={Hair_01="#3a2a1a",Hair_03="#4a3320"} local col=t[id] or "#3a2a1a" Layers.hair.BackgroundColor3=Color3.fromHex(col:gsub("#","")) end
    elseif category=="Eyes" or category=="Brows" or category=="Mouth" then
        -- single layer override, do not reset timers
        if category=="Eyes" then PROFILE.Eyes=id elseif category=="Brows" then PROFILE.Brows=id elseif category=="Mouth" then PROFILE.Mouth=id end
        -- immediate visual without resetting Idle/Blink/Talk timers
        Verity.SetExpression(PROFILE.Expression, true)
    elseif category=="Tops" then
        if Layers.clothing then Layers.clothing.BackgroundColor3=Color3.fromHex("2a2a3a") end
    end
    -- persist only IDs
    Verity.SaveProfile()
    -- notify hub 2-way
    if _G.Equilibrium and _G.Equilibrium.EVENTS then _G.Equilibrium.EVENTS.fire("wardrobe:equip", category, id) end
    if _G.EquilibriumNotify then pcall(function() _G.EquilibriumNotify("Wardrobe updated: "..WARDROBE[category][id].name) end) end
    return true
end

-- Expression apply helper (already defined as Verity.SetExpression)

-- =========================================================================
-- EFFECTS (UI only)
-- =========================================================================
local function applyEffect(id)
    PROFILE.Effect=id
    if id=="Effect_01" then if Layers.effectGlow then Layers.effectGlow.Visible=false end
    elseif id=="Effect_02" then if Layers.effectGlow then Layers.effectGlow.Visible=true; Layers.effectGlow.BackgroundTransparency=0.85 end
    elseif id=="Effect_04" then -- scanlines 4 thin frames
        -- create once
    end
end

-- =========================================================================
-- TEXT / RESPONSE / PRESENTATION  + Unified Message Queue
-- =========================================================================
local Responses = {
    Greeting={"Hey.", "Oh, hey.", "You're back.", "What's up?", "Good to see you."},
    Confused={"Wait, what?", "I'm not following.", "Can you explain that?", "Okay, you lost me."},
    Happy={"Nice.", "I like that.", "That's actually pretty good.", "Okay, I approve."},
    Unknown={"I'm not sure what you mean.", "Hm. I'm missing something.", "Can you rephrase that?"},
    Farewell={"See you.", "Later.", "Take care.", "I'll be here."},
}

local conversationState = { LastMessage=nil, LastResponse=nil, LastTopic=nil, MessageCount=0, ConversationActive=false, lastMeaningful=0 }
local RecentResponses = {}
local MessageQueue = {}
local isShowing=false

local function pickResponse(poolName)
    local pool=Responses[poolName] or Responses.Unknown
    -- weighted simple random, avoid recent
    local tries=0; local pick
    repeat pick=pool[math.random(1,#pool)]; tries+=1 until not table.find(RecentResponses,pick) or tries>5
    table.insert(RecentResponses, pick) if #RecentResponses>6 then table.remove(RecentResponses,1) end
    return pick
end

local function inferIntent(text)
    text=text:lower()
    if text:match("^hey") or text:match("^hi") then return "Greeting" end
    if text:match("bye") or text:match("later") then return "Farewell" end
    if text:match("%?") then return "Question" end
    if text:match("change") or text:match("equip") then return "Command" end
    return "Statement"
end

local function autoPresentation(msg)
    local n=#msg.Text
    if msg.Priority>=3 then return "Popup" end
    if msg.Type=="Reaction" then return "SpeechBubble" end
    if n<=35 then return "SpeechBubble" end
    if n<=120 then return "Speech" end
    if n<=250 then return "Expanded" end
    return "Popup"
end

-- typing + speech sync
local speechLabel, bubbleFrame, bubbleLabel, notificationContainer
local typingConn
local function stopTyping() if typingConn then typingConn:Disconnect() typingConn=nil end Verity.StopTalking() end

local function showTyping(msg, onDone)
    local presentation = msg.Presentation or autoPresentation(msg)
    local targetLabel = (presentation=="SpeechBubble" and bubbleLabel) or speechLabel
    local targetFrame = (presentation=="SpeechBubble" and bubbleFrame) or nil
    if targetFrame then targetFrame.Visible=true end
    targetLabel.Text=""
    targetLabel.Visible=true
    Verity.StartTalking()
    local i=0; local t=msg.Text
    typingConn = RunService.Heartbeat:Connect(function()
        i+=1
        if i> #t then stopTyping(); if targetFrame then task.delay(msg.Duration or 2.5, function() targetFrame.Visible=false end) end Verity.StopTalking(); if onDone then onDone() end typingConn:Disconnect(); typingConn=nil; return end
        targetLabel.Text = string.sub(t,1,i)
        -- punctuation pause
        local ch=string.sub(t,i,i) if ch:match("[%.%!%?%,]") then task.wait(0.08) end
        task.wait(0.03 + math.random()*0.02)
    end)
    -- click to skip
    if targetLabel then targetLabel.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 then if typingConn then typingConn:Disconnect(); typingConn=nil end targetLabel.Text=t; Verity.StopTalking(); if onDone then onDone() end end end) end
end

local function displayMessage(msg)
    -- expression sync
    if msg.Expression then Verity.SetExpression(msg.Expression, false) end
    -- animation sync
    if msg.Animation then Verity.SetAnimation(msg.Animation) end
    -- presentation decide
    if not msg.Presentation then msg.Presentation = autoPresentation(msg) end
    -- duration default by length
    if not msg.Duration then msg.Duration = math.clamp(#msg.Text*0.06, 1.5, 5) end
    local pres=msg.Presentation
    if pres=="Notification" then
        -- compact corner
        local n=Instance.new("Frame") n.Size=UDim2.fromOffset(220,44); n.Position=UDim2.new(1,-228,1,-52); n.BackgroundColor3=CONFIG.Slate; n.BorderSizePixel=0; n.Parent=notificationContainer; Instance.new("UICorner",{CornerRadius=UDim.new(0,8), Parent=n}); Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1, Parent=n})
        local tl=Instance.new("TextLabel") tl.Size=UDim2.new(1,-12,0,14); tl.Position=UDim2.new(0,8,0,6); tl.BackgroundTransparency=1; tl.Text="VERITY"; tl.TextSize=9; tl.TextColor3=CONFIG.Gold; tl.Font=Enum.Font.GothamBold; tl.TextXAlignment=Enum.TextXAlignment.Left; tl.Parent=n
        local tx=Instance.new("TextLabel") tx.Size=UDim2.new(1,-12,0,16); tx.Position=UDim2.new(0,8,0,20); tx.BackgroundTransparency=1; tx.Text=msg.Text; tx.TextSize=11; tx.TextColor3=Color3.new(1,1,1); tx.Font=Enum.Font.Gotham; tx.TextXAlignment=Enum.TextXAlignment.Left; tx.Parent=n
        task.delay(msg.Duration, function() n:Destroy() end)
        task.delay(msg.Duration, function() processQueue() end)
        return
    end
    if pres=="Status" then
        speechLabel.Text=msg.Text; speechLabel.TextTransparency=0.2; task.delay(msg.Duration, function() processQueue() end) return
    end
    -- Speech / Bubble with typing
    showTyping(msg, function() task.delay(0.3, function() processQueue() end) end)
end

function processQueue()
    if isShowing then return end
    if #MessageQueue==0 then return end
    -- sort by priority desc, keep FIFO for same priority
    table.sort(MessageQueue, function(a,b) return a.Priority > b.Priority end)
    local msg=table.remove(MessageQueue,1)
    isShowing=true
    displayMessage(msg)
    -- onDone will set isShowing false via delay
    task.delay((msg.Duration or 2.5)+0.8, function() isShowing=false processQueue() end)
end

function Verity.Enqueue(msg)
    -- msg = {Text, Type, Priority, Duration, Expression, Presentation, Animation, Action}
    msg.Priority = msg.Priority or 1
    msg.Type = msg.Type or "Response"
    table.insert(MessageQueue, msg)
    -- interruption: higher priority cancels low ambient
    if msg.Priority>=3 and #MessageQueue>1 then
        -- cancel ambient (0) that might be showing
        if isShowing and MessageQueue[1] and MessageQueue[1].Priority==0 then table.remove(MessageQueue,1) end
    end
    processQueue()
    -- action allowlist only
    if msg.Action then
        local allow={OpenWardrobe=true, SetExpression=true, EquipCosmetic=true}
        if allow[msg.Action] then
            if msg.Action=="OpenWardrobe" then Verity.OpenWardrobe(msg.ActionParam) end
            if msg.Action=="SetExpression" then Verity.SetExpression(msg.ActionParam) end
        end
    end
end

function Verity.Say(text, opts)
    opts=opts or {}
    local intent=inferIntent(text)
    -- farewell immediate ConversationActive false
    if intent=="Farewell" then conversationState.ConversationActive=false end
    -- wardrobe/system notifications do NOT reset timer
    local isMeaningful = not (opts.isSystem or opts.isWardrobe)
    if isMeaningful then
        conversationState.ConversationActive=true
        conversationState.lastMeaningful=tick()
        conversationState.MessageCount+=1
    end
    conversationState.LastMessage=text
    local msg={
        Text=text, Type=opts.Type or "Response", Priority=opts.Priority or 1,
        Duration=opts.Duration, Expression=opts.Expression or "Expression_01",
        Presentation=opts.Presentation, Animation=opts.Animation or "Talking",
        Action=opts.Action, ActionParam=opts.ActionParam
    }
    Verity.Enqueue(msg)
end

-- convenience wrappers used by hub
function Verity.RespondToInput(userText)
    local intent=inferIntent(userText)
    local pool = (intent=="Greeting" and "Greeting") or (intent=="Farewell" and "Farewell") or "Unknown"
    local txt=pickResponse(pool)
    -- command → action
    if userText:lower():match("change.*hair") then
        Verity.Say("Sure.", {Type="Response", Presentation="SpeechBubble", Expression="Expression_06", Action="OpenWardrobe", ActionParam="Hair"})
        return
    end
    if userText:lower():match("make.*happy") then
        Verity.SetExpression("Expression_02"); Verity.Say("Easy.", {Expression="Expression_02"}) return
    end
    Verity.Say(txt, {Expression="Expression_01"})
end

-- idle dialogue 30-120s low prob, disabled while ConversationActive or recently spoke
local lastIdle=tick()
local function maybeIdle()
    if conversationState.ConversationActive then return end
    if tick()-lastIdle < 30 then return end
    if math.random() > 0.12 then return end
    local ambients={"Still here.","Thinking.","...","I wonder what you're doing."}
    Verity.Say(ambients[math.random(1,#ambients)], {Type="Thought", Priority=0, Presentation="Thought", Expression="Expression_01", isSystem=true})
    lastIdle=tick()
end

-- wardrobe UI
local WardrobeModal
function Verity.OpenWardrobe(cat)
    if not WardrobeModal then Verity.CreateWardrobeUI() end
    WardrobeModal.Visible=true
    -- show cat tab
end

function Verity.CreateWardrobeUI()
    local gui = LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui")
    WardrobeModal = Instance.new("Frame")
    WardrobeModal.Name="VerityWardrobeModal"; WardrobeModal.Size=UDim2.fromOffset(520,420); WardrobeModal.Position=UDim2.new(0.5,0,0.5,0); WardrobeModal.AnchorPoint=Vector2.new(0.5,0.5)
    WardrobeModal.BackgroundColor3=CONFIG.Bg; WardrobeModal.BorderSizePixel=0; WardrobeModal.Visible=false; WardrobeModal.Parent=gui
    rootMaid:give(WardrobeModal)
    Instance.new("UICorner",{CornerRadius=UDim.new(0,12), Parent=WardrobeModal})
    Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1.5, Parent=WardrobeModal})
    local header=Instance.new("TextLabel") header.Size=UDim2.new(1,0,0,28); header.BackgroundTransparency=1; header.Text="←  VERITY WARDROBE"; header.TextSize=12; header.Font=Enum.Font.GothamBold; header.TextColor3=CONFIG.Gold; header.Parent=WardrobeModal
    local left=Instance.new("ScrollingFrame") left.Size=UDim2.new(0,140,1,-36); left.Position=UDim2.new(0,8,0,32); left.BackgroundTransparency=1; left.ScrollBarThickness=4; left.CanvasSize=UDim2.new(0,0,0,400); left.Parent=WardrobeModal
    Instance.new("UIListLayout",{Padding=UDim.new(0,6), Parent=left})
    local right=Instance.new("Frame") right.Size=UDim2.new(1,-160,1,-36); right.Position=UDim2.new(0,156,0,32); right.BackgroundTransparency=1; right.Parent=WardrobeModal
    -- preview orb in right top
    local previewOrb=Instance.new("Frame") previewOrb.Size=UDim2.fromOffset(CONFIG.Orb,CONFIG.Orb); previewOrb.Position=UDim2.new(0.5,0,0,0); previewOrb.AnchorPoint=Vector2.new(0.5,0); previewOrb.BackgroundColor3=CONFIG.Slate; previewOrb.Parent=right Instance.new("UICorner",{CornerRadius=UDim.new(0,CONFIG.Orb/2), Parent=previewOrb})
    -- clone verity canvas into orb for live preview
    if VerityCanvas then local clone=VerityCanvas:Clone() clone.Size=UDim2.fromOffset(CONFIG.Size.X,CONFIG.Size.Y); clone.Position=UDim2.new(0.5,0,0.5,0); clone.AnchorPoint=Vector2.new(0.5,0.5); clone.Parent=previewOrb end
    -- category tabs
    local cats={"Hair","Eyes","Face","Clothing","Accessories","Held","Expressions","Effects"}
    for _,cat in ipairs(cats) do
        local b=Instance.new("TextButton") b.Size=UDim2.new(1,0,0,28); b.Text=cat; b.Font=Enum.Font.Gotham; b.TextSize=11; b.TextColor3=Color3.new(1,1,1); b.BackgroundColor3=CONFIG.Slate; b.Parent=left Instance.new("UICorner",{CornerRadius=UDim.new(0,6), Parent=b})
        b.MouseButton1Click:Connect(function() Verity.ShowWardrobeCategory(cat, right) end)
    end
    -- close on click outside
    WardrobeModal.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 and i.Position.Y < WardrobeModal.AbsolutePosition.Y then WardrobeModal.Visible=false end end)
end

function Verity.ShowWardrobeCategory(cat, container)
    -- generate grid from WARDROBE data
    -- clear previous grid
    for _,c in ipairs(container:GetChildren()) do if c.Name=="Grid" then c:Destroy() end end
    local dbKey = ({Hair="Hair", Eyes="Eyes", Face="Brows", Clothing="Tops", Accessories="HeadAcc", Held="Held", Expressions="EXPRESSIONS", Effects="Effects"})[cat] or cat
    local src = (dbKey=="EXPRESSIONS" and EXPRESSIONS) or WARDROBE[dbKey] or {}
    local grid=Instance.new("ScrollingFrame") grid.Name="Grid"; grid.Size=UDim2.new(1,0,0,200); grid.Position=UDim2.new(0,0,0,180); grid.BackgroundTransparency=1; grid.ScrollBarThickness=4; grid.CanvasSize=UDim2.new(0,0,0, math.ceil((function() local c=0 for _ in pairs(src) do c+=1 end return c end)()/2)*40); grid.Parent=container
    Instance.new("UIGridLayout",{CellSize=UDim2.fromOffset(150,36), CellPadding=UDim2.fromOffset(6,6), Parent=grid})
    for id,info in pairs(src) do
        local btn=Instance.new("TextButton") btn.Size=UDim2.fromOffset(150,36); btn.Text=info.name or id; btn.TextSize=11; btn.Font=Enum.Font.Gotham; btn.BackgroundColor3=CONFIG.Slate; btn.TextColor3=Color3.new(1,1,1); btn.Parent=grid Instance.new("UICorner",{CornerRadius=UDim.new(0,6), Parent=btn})
        if PROFILE[cat] and PROFILE[cat]==id then btn.BackgroundColor3=CONFIG.Gold end
        btn.MouseButton1Click:Connect(function()
            if dbKey=="EXPRESSIONS" then Verity.SetExpression(id); PROFILE.Expression=id else Verity.Equip(dbKey, id) end
            -- chance response
            if math.random()<0.22 then Verity.Say("Nice.", {Type="Reaction", Presentation="SpeechBubble", Priority=1, isWardrobe=true}) end
        end)
    end
end

-- =========================================================================
-- PERSISTENCE — only IDs, global
-- =========================================================================
local CFG_FOLDER="equilibrium"
function Verity.SaveProfile()
    local data={} for k,v in pairs(PROFILE) do data[k]=v end
    local ok,txt=pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), data)
    if ok then pcall(function() if not isfolder(CFG_FOLDER) then makefolder(CFG_FOLDER) end writefile(CFG_FOLDER.."/verity_profile.json", txt) end) end
end
function Verity.LoadProfile()
    local ok,txt=pcall(readfile, CFG_FOLDER.."/verity_profile.json")
    if ok then local ok2,data=pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), txt) if ok2 and type(data)=="table" then for k,v in pairs(data) do if PROFILE[k]~=nil then PROFILE[k]=v end end end end
end

-- =========================================================================
-- EVENTS — wardrobe:equip validated path
-- =========================================================================
-- handled in Verity.Equip above via _G.Equilibrium.EVENTS if present; also local

-- =========================================================================
-- INIT — VerityMenu:Init() entry
-- =========================================================================
function Verity.Init(parentGui)
    parentGui = parentGui or LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui")
    -- root frame VerityMenu 360x640 gold border Slate — owned by rootMaid (single lifecycle)
    Gui = Instance.new("ScreenGui") Gui.Name="VerityMenu"; Gui.ResetOnSpawn=false; Gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; Gui.Parent=parentGui
    rootMaid:give(Gui)
    local root=Instance.new("Frame") root.Name="VerityRoot"; root.Size=UDim2.fromOffset(360,640); root.Position=UDim2.new(0,20,0.5,0); root.AnchorPoint=Vector2.new(0,0.5); root.BackgroundColor3=CONFIG.Bg; root.BorderSizePixel=0; root.Parent=Gui Instance.new("UICorner",{CornerRadius=UDim.new(0,16), Parent=root}) Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1.5, Parent=root})
    -- top bar VERITY ASSISTANT dotted
    local top=Instance.new("Frame") top.Size=UDim2.new(1,0,0,52); top.BackgroundTransparency=1; top.Parent=root
    local title=Instance.new("TextLabel") title.Size=UDim2.new(1,0,0,22); title.Position=UDim2.new(0,0,0,8); title.BackgroundTransparency=1; title.Text="V E R I T Y"; title.TextSize=22; title.Font=Enum.Font.Code; title.TextColor3=Color3.new(1,1,1); title.Parent=top
    local sub=Instance.new("TextLabel") sub.Size=UDim2.new(1,0,0,14); sub.Position=UDim2.new(0,0,0,28); sub.BackgroundTransparency=1; sub.Text="A S S I S T A N T"; sub.TextSize=9; sub.Font=Enum.Font.Gotham; sub.TextColor3=CONFIG.Gold; sub.Parent=top
    -- gear + lock buttons
    local gear=Instance.new("TextButton") gear.Size=UDim2.fromOffset(28,28); gear.Position=UDim2.new(0,8,0,12); gear.Text="⚙"; gear.Font=Enum.Font.GothamBold; gear.TextSize=14; gear.BackgroundColor3=CONFIG.Slate; gear.TextColor3=CONFIG.Gold; gear.Parent=root Instance.new("UICorner",{CornerRadius=UDim.new(0,8), Parent=gear}) Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1, Parent=gear})
    local lockBtn=Instance.new("TextButton") lockBtn.Size=UDim2.fromOffset(28,28); lockBtn.Position=UDim2.new(1,-36,0,12); lockBtn.Text="🔒"; lockBtn.Font=Enum.Font.Gotham; lockBtn.TextSize=12; lockBtn.BackgroundColor3=CONFIG.Slate; lockBtn.TextColor3=CONFIG.Gold; lockBtn.Parent=root Instance.new("UICorner",{CornerRadius=UDim.new(0,8), Parent=lockBtn}) Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1, Parent=lockBtn})
    -- orb
    OrbsFrame=Instance.new("Frame") OrbsFrame.Size=UDim2.fromOffset(CONFIG.Orb,CONFIG.Orb); OrbsFrame.Position=UDim2.new(0.5,0,0,88); OrbsFrame.AnchorPoint=Vector2.new(0.5,0); OrbsFrame.BackgroundColor3=CONFIG.Slate; OrbsFrame.Parent=root Instance.new("UICorner",{CornerRadius=UDim.new(0,CONFIG.Orb/2), Parent=OrbsFrame}) Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1, Parent=OrbsFrame})
    Verity.LoadProfile()
    Verity.CreateCharacter(OrbsFrame)
    Verity.ApplyProfile()
    -- speech + bubble + status containers
    local chatCard=Instance.new("Frame") chatCard.Size=UDim2.new(1,-24,0,220); chatCard.Position=UDim2.new(0,12,0,300); chatCard.BackgroundColor3=CONFIG.Slate; chatCard.Parent=root Instance.new("UICorner",{CornerRadius=UDim.new(0,12), Parent=chatCard}) Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1, Parent=chatCard})
    speechLabel=Instance.new("TextLabel") speechLabel.Size=UDim2.new(1,-24,0,120); speechLabel.Position=UDim2.new(0,12,0,12); speechLabel.BackgroundTransparency=1; speechLabel.Text="Hi, I'm Verity.\nAsk me anything."; speechLabel.TextWrapped=true; speechLabel.TextSize=13; speechLabel.Font=Enum.Font.Gotham; speechLabel.TextColor3=Color3.new(1,1,1); speechLabel.Parent=chatCard
    -- bubble (hidden until needed) near head
    bubbleFrame=Instance.new("Frame") bubbleFrame.Size=UDim2.fromOffset(140,36); bubbleFrame.Position=UDim2.new(0.5, 60, 0, 180); bubbleFrame.BackgroundColor3=CONFIG.Slate; bubbleFrame.Visible=false; bubbleFrame.Parent=root Instance.new("UICorner",{CornerRadius=UDim.new(0,10), Parent=bubbleFrame}) Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1, Parent=bubbleFrame})
    bubbleLabel=Instance.new("TextLabel") bubbleLabel.Size=UDim2.new(1,-12,1,0); bubbleLabel.Position=UDim2.new(0,6,0,0); bubbleLabel.BackgroundTransparency=1; bubbleLabel.Text=""; bubbleLabel.TextSize=11; bubbleLabel.Font=Enum.Font.Gotham; bubbleLabel.TextColor3=Color3.new(1,1,1); bubbleLabel.TextWrapped=true; bubbleLabel.Parent=bubbleFrame
    -- input bar
    local inputBar=Instance.new("Frame") inputBar.Size=UDim2.new(1,-24,0,44); inputBar.Position=UDim2.new(0,12,0,532); inputBar.BackgroundColor3=CONFIG.Bg; inputBar.Parent=root Instance.new("UICorner",{CornerRadius=UDim.new(0,22), Parent=inputBar}) Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1, Parent=inputBar})
    local inputBox=Instance.new("TextBox") inputBox.Size=UDim2.new(1,-64,1,0); inputBox.Position=UDim2.new(0,16,0,0); inputBox.BackgroundTransparency=1; inputBox.PlaceholderText="Message Verity…"; inputBox.Text=""; inputBox.TextSize=12; inputBox.Font=Enum.Font.Gotham; inputBox.TextColor3=Color3.new(1,1,1); inputBox.TextXAlignment=Enum.TextXAlignment.Left; inputBox.Parent=inputBar
    local sendBtn=Instance.new("TextButton") sendBtn.Size=UDim2.fromOffset(36,36); sendBtn.Position=UDim2.new(1,-40,0.5,0); sendBtn.AnchorPoint=Vector2.new(0,0.5); sendBtn.Text="▶"; sendBtn.Font=Enum.Font.GothamBold; sendBtn.TextSize=14; sendBtn.BackgroundColor3=CONFIG.Gold; sendBtn.TextColor3=CONFIG.Bg; sendBtn.Parent=inputBar Instance.new("UICorner",{CornerRadius=UDim.new(0,18), Parent=sendBtn})
    sendBtn.MouseButton1Click:Connect(function() local t=inputBox.Text if t~="" then Verity.RespondToInput(t); inputBox.Text="" end end)
    inputBox.FocusLost:Connect(function(enter) if enter and inputBox.Text~="" then Verity.RespondToInput(inputBox.Text); inputBox.Text="" end end)
    -- wardrobe button bottom
    local wardBtn=Instance.new("TextButton") wardBtn.Size=UDim2.new(1,-24,0,52); wardBtn.Position=UDim2.new(0,12,1,-60); wardBtn.Text=""; wardBtn.BackgroundColor3=CONFIG.Slate; wardBtn.Parent=root Instance.new("UICorner",{CornerRadius=UDim.new(0,12), Parent=wardBtn}) Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1, Parent=wardBtn})
    local wardIcon=Instance.new("TextLabel") wardIcon.Size=UDim2.new(1,0,0,22); wardIcon.Position=UDim2.new(0,0,0,8); wardIcon.BackgroundTransparency=1; wardIcon.Text="👕"; wardIcon.TextSize=18; wardIcon.Parent=wardBtn
    local wardTxt=Instance.new("TextLabel") wardTxt.Size=UDim2.new(1,0,0,14); wardTxt.Position=UDim2.new(0,0,0,30); wardTxt.BackgroundTransparency=1; wardTxt.Text="WARDROBE"; wardTxt.TextSize=10; wardTxt.Font=Enum.Font.Gotham; wardTxt.TextColor3=Color3.new(1,1,1); wardTxt.Parent=wardBtn
    wardBtn.MouseButton1Click:Connect(function() Verity.OpenWardrobe() end)
    -- notification container (shared with Hub if exists)
    notificationContainer = Instance.new("Frame") notificationContainer.Name="VerityNotify"; notificationContainer.Size=UDim2.new(0,240,1,0); notificationContainer.Position=UDim2.new(1,-248,0,0); notificationContainer.BackgroundTransparency=1; notificationContainer.Parent=Gui
    _G.EquilibriumNotify = function(txt) Verity.Say(txt, {Type="Notification", Priority=3, Presentation="Notification", Duration=2.2, isSystem=true}) end
    -- heartbeat single loop (owned by rootMaid for leak-free lifecycle)
    if heartbeatConn then heartbeatConn:Disconnect() end
    heartbeatConn = RunService.Heartbeat:Connect(function(dt) UpdateAnimations(dt) end)
    rootMaid:give(heartbeatConn)
    pickIdle()
    animationTimers.BlinkNext = RandomRange(ANIMATION_TIMING.Blink.MinimumDelay, ANIMATION_TIMING.Blink.MaximumDelay)
    -- ConversationActive timeout ticker + idle dialogue
    task.spawn(function()
        while Gui.Parent do
            task.wait(1)
            -- auto-reset ConversationActive
            if conversationState.ConversationActive and tick() - conversationState.lastMeaningful >= CONFIG.ConversationActiveTimeout then
                conversationState.ConversationActive=false
            end
            maybeIdle()
        end
    end)
    -- initial greeting
    Verity.Say("Hi, I'm Verity. Ask me anything.", {Type="Greeting", Priority=2, Presentation="Speech", Expression="Expression_02"})
    -- expose
    _G.Verity = Verity
    _G.VERITY_PROFILE = PROFILE
    return Gui
end

_G.VerityUnifiedInternal = Verity
_G.Verity = Verity
end

-- Hub-Verity bridge (same file, no readfile)
if _G.VerityUnifiedInternal and _G.VerityUnifiedInternal.Init and not _G.VerityUnifiedInternal._inited then pcall(function() local pg=LP:FindFirstChild('PlayerGui') or LP:WaitForChild('PlayerGui',5) local parent=(typeof(gethui)=='function' and (function() local ok,h=pcall(gethui) if ok and h then return h end end)()) or pg or game:GetService('CoreGui') _G.VerityUnifiedInternal.Init(parent) print('[Equilibrium] Verity unified inlined — separate modal, 72x96 procedural') end) end



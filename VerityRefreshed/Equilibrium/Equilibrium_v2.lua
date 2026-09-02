-- Equilibrium v2.1 COMPILED — single file, no external modules required
-- Major updates: TP Bank file explorer, About tab layout fix, Font changer, Size presets, Text resolution fixes
-- v2.1 patches: Cleaner load notification, = puck symbol, theme-compatible puck, RBX asset backgrounds, window button polish

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
print("[Equilibrium] boot — "..BRAND.." v2.1 initializing")

-- ===== Settings (file+memory, inlined) =====
local Settings={}; do
    local mem={global=nil,place=nil}
    local function hasFile() return typeof(isfolder)=="function" and typeof(isfile)=="function" and typeof(writefile)=="function" and typeof(readfile)=="function" end
    local function ensure() if not hasFile() then return false end if not isfolder(CFG_FOLDER) then pcall(makefolder,CFG_FOLDER) end if not isfolder(CFG_FOLDER.."/places") then pcall(makefolder,CFG_FOLDER.."/places") end return true end
    local function fpath(k) if k=="global" then return CFG_FOLDER.."/global.json" end return CFG_FOLDER.."/places/"..tostring(game.PlaceId)..".json" end
    local defaults={global={theme="Default", bg="#070707", verityLocked=true, winW=620, winH=520, fontSize=12, fontPreset="Default", bgPreset="Slate"}, place={features={}}}
    function Settings:Get(k,s) s=s or "global" local src=mem[s] or {} if src[k]~=nil then return src[k] end return defaults[s] and defaults[s][k] or nil end
    function Settings:Set(k,v,s) s=s or "global" mem[s]=mem[s] or {} mem[s][k]=v end
    function Settings:Save(s) s=s or "global" if hasFile() then ensure() local ok,txt=pcall(HttpService.JSONEncode,HttpService,mem[s] or {}) if ok then pcall(writefile,fpath(s),txt) end end end
    function Settings:Load() if hasFile() then local ok,txt=pcall(readfile,fpath("global")) if ok then local ok2,d=pcall(HttpService.JSONDecode,HttpService,txt) if ok2 and type(d)=="table" then mem.global=d end end local ok3,txt2=pcall(readfile,fpath("place")) if ok3 then local ok4,d2=pcall(HttpService.JSONDecode,HttpService,txt2) if ok4 and type(d2)=="table" then mem.place=d2 end end end if not mem.global then mem.global={theme="Default", bg="#070707", verityLocked=true, winW=620, winH=520, fontSize=12, fontPreset="Default", bgPreset="Slate"} end if not mem.place then mem.place={features={}} end return mem end
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
    function Context:SetFocus(p) self.attention.focus=p end end
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

-- ===== Theme (configurable background) =====
local T={bg=Color3.fromHex("070707"), panel=Color3.fromHex("141414"), titleBar=Color3.fromHex("0f0f0f"), border=Color3.fromHex("2a2a2a"), line=Color3.fromHex("252525"), text=Color3.fromHex("e6e6e6"), dim=Color3.fromHex("a0a0a8"), accent=Color3.fromHex("787a96"), accent2=Color3.fromHex("8a8dc2"), on=Color3.fromHex("5fdc82"), off=Color3.fromHex("4b5563"), warn=Color3.fromHex("e81123"), warnHover=Color3.fromHex("c50f1f")}
-- RBX Asset backgrounds for puck mode
local RBX_BACKGROUNDS={
    {name="Slate", assetId="", color="#070707"},
    {name="Midnight", assetId="rbxassetid://15299118685", color="#0a0f1a"},
    {name="Ocean", assetId="rbxassetid://15299118892", color="#0d1a24"},
    {name="Forest", assetId="rbxassetid://15299119103", color="#0f1a12"},
    {name="Dusk", assetId="rbxassetid://15299119344", color="#1a1420"},
    {name="Crimson", assetId="rbxassetid://15299119587", color="#1a0f0f"},
    {name="Nebula", assetId="rbxassetid://15299119821", color="#1a0f1a"},
    {name="Aurora", assetId="rbxassetid://15299120065", color="#0f1a1a"},
}
local FONT_PRESETS={
    Default=Enum.Font.Gotham,
    Gotham=Enum.Font.Gotham,
    GothamBold=Enum.Font.GothamBold,
    SourceSans=Enum.Font.SourceSans,
    SourceSansPro=Enum.Font.SourceSansPro,
    Code=Enum.Font.Code,
    Garamond=Enum.Font.Garamond,
    Cartoon=Enum.Font.Cartoon,
    Scifi=Enum.Font.SciFi,
    Fantasy=Enum.Font.Fantasy,
    Antique=Enum.Font.Antique,
    Arcadia=Enum.Font.Arcadia,
    BuilderSans=Enum.Font.BuilderSans,
    Highrise=Enum.Font.Highrise,
    Italic=Enum.Font.Italic,
    Legacy=Enum.Font.Legacy,
    Merriweather=Enum.Font.Merriweather,
    Monospace=Enum.Font.Monospace,
    Nunito=Enum.Font.Nunito,
    Roboto=Enum.Font.Roboto,
    RobotoMono=Enum.Font.RobotoMono,
    Sarpanch=Enum.Font.Sarpanch,
    SpecialGotham=Enum.Font.SpecialGotham,
    System=Enum.Font.System,
    Typewriter=Enum.Font.Typewriter,
    Ubuntu=Enum.Font.Ubuntu,
}
local FONT_OPTIONS={}
for name,_ in pairs(FONT_PRESETS) do table.insert(FONT_OPTIONS,name) end
table.sort(FONT_OPTIONS)
local CURRENT_FONT=Settings:Get("fontPreset","global") or "Default"
local CURRENT_FONT_SIZE=Settings:Get("fontSize","global") or 12
local FONT=FONT_PRESETS[CURRENT_FONT] or Enum.Font.Gotham
local FONTB=Enum.Font.GothamBold

-- Size presets
local SIZE_PRESETS={
    Compact={w=520,h=420},
    Standard={w=620,h=520},
    Large={w=720,h=600},
    XLarge={w=820,h=680},
}
local SIZE_PRESET_NAMES={}
for name,_ in pairs(SIZE_PRESETS) do table.insert(SIZE_PRESET_NAMES,name) end
table.sort(SIZE_PRESET_NAMES)

local rng=Random.new(tick()*1e6%2147483647) local CHARS="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
local function rname() local n=rng:NextInteger(18,26) local b=table.create(n) for i=1,n do local k=rng:NextInteger(1,#CHARS) b[i]=CHARS:sub(k,k) end return table.concat(b) end
local function new(className, props, kids) local o=Instance.new(className) if props then for kk,vv in pairs(props) do if kk~="Parent" and kk~="Name" then if kk=="Font" then o.Font=vv else local ok=pcall(function() o[kk]=vv end) if not ok and kk=="TextSize" then o.TextSize=vv end end end end end if props and props.Name then o.Name=props.Name else o.Name=rname() end if kids then for _,ch in ipairs(kids) do ch.Parent=o end end if props and props.Parent then o.Parent=props.Parent end return o end
local function corner(i,r) return new("UICorner",{CornerRadius=UDim.new(0,r or 8),Parent=i}) end
local function stroke(i,c,t) return new("UIStroke",{Color=c or T.border, Thickness=t or 1, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Parent=i}) end
local function pad(i,a,b,c,d) return new("UIPadding",{PaddingTop=UDim.new(0,a or 0),PaddingBottom=UDim.new(0,b or a or 0),PaddingLeft=UDim.new(0,c or 0),PaddingRight=UDim.new(0,d or c or 0),Parent=i}) end
local function vlist(i,g) return new("UIListLayout",{FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,g or 8), Parent=i}) end
local function hlist(i,g) return new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,g or 8), VerticalAlignment=Enum.VerticalAlignment.Center, Parent=i}) end
local function tw(i,info,goal) local t=TweenService:Create(i,info,goal) t:Play() return t end
local MOTION={hover=TweenInfo.new(0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), win=TweenInfo.new(0.28,Enum.EasingStyle.Quint,Enum.EasingDirection.Out)}

local function viewport() local cam=Workspace.CurrentCamera return cam and cam.ViewportSize or Vector2.new(620,520) end
local W,H=Settings:Get("winW","global") or 620, Settings:Get("winH","global") or 520
do local vp=viewport() W=math.clamp(W,320,math.max(320,vp.X-40)) H=math.clamp(H,260,math.max(260,vp.Y-40)) end
local function centeredPos(w,h) local vp=viewport() return Vector2.new(math.floor((vp.X-w)/2), math.floor((vp.Y-h)/2)) end
local function px(n) return math.floor(n+0.5) end
local function offset(x,y) return UDim2.fromOffset(px(x),px(y)) end

-- Helper for dynamic font size based on hub scale
local function getFontSize(base)
    base = base or CURRENT_FONT_SIZE
    local scale = W / 620
    return math.clamp(math.floor(base * scale + 0.5), 10, 18)
end

-- ScreenGui — start hidden, will be shown after parented
local screen=new("ScreenGui",{Name="EquilibriumHub", ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, IgnoreGuiInset=true, DisplayOrder=999, Enabled=false})
rootMaid:give(screen)

-- Notify: separate ScreenGui so it survives hub hide (old Roblox style)
local notifyGui=new("ScreenGui",{Name="EquilibriumNotify", ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, IgnoreGuiInset=true, DisplayOrder=1000})
local notifyRoot=new("Frame",{BackgroundTransparency=1, AnchorPoint=Vector2.new(1,1), Position=UDim2.new(1,-16,1,-16), Size=offset(320,400), ZIndex=900, Parent=notifyGui})
new("UIListLayout",{FillDirection=Enum.FillDirection.Vertical, VerticalAlignment=Enum.VerticalAlignment.Bottom, HorizontalAlignment=Enum.HorizontalAlignment.Right, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,8), Parent=notifyRoot})
pcall(function() notifyGui.Parent=game:GetService("CoreGui") end)
if not notifyGui.Parent then pcall(function() notifyGui.Parent=LP:WaitForChild("PlayerGui") end) end
if typeof(gethui)=="function" then pcall(function() notifyGui.Parent=gethui() end) end
rootMaid:give(notifyGui)
local function pushToast(text, kind, secs)
    secs=secs or 3.5
    local accent=(kind=="bad" and T.warn) or (kind=="warn" and T.warn) or T.on
    local card=new("Frame",{BackgroundColor3=T.panel, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=900, Parent=notifyRoot}) corner(card,8) stroke(card,T.border) pad(card,10,10,12,12) hlist(card,8,Enum.VerticalAlignment.Top)
    new("Frame",{BackgroundColor3=accent, Size=offset(3,16), BorderSizePixel=0, LayoutOrder=1, ZIndex=901, Parent=card},{new("UICorner",{CornerRadius=UDim.new(1,0)})})
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-18,0,0), AutomaticSize=Enum.AutomaticSize.Y, Font=FONT, Text=text, TextSize=getFontSize(13), TextColor3=T.text, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=2, ZIndex=901, Parent=card})
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
local mouth=new("TextLabel",{BackgroundTransparency=1, Size=offset(34,10), Position=offset(0,18), Font=FONTB, Text="—", TextSize=getFontSize(10), TextColor3=Color3.fromRGB(16,16,16), ZIndex=14, Parent=verityHead})
local function verityBlink() tw(eyeL,TweenInfo.new(0.06),{Size=offset(6,1)}); tw(eyeR,TweenInfo.new(0.06),{Size=offset(6,1)}); task.delay(0.07,function() tw(eyeL,TweenInfo.new(0.08),{Size=offset(6,8)}); tw(eyeR,TweenInfo.new(0.08),{Size=offset(6,8)}) end) end
_G.__eq_applyVerity=function(s) if s=="happy" then mouth.Text="⌣" elseif s=="glitch" then mouth.Text="#" else mouth.Text="—" end end

local lockBtn=new("TextButton",{BackgroundTransparency=1, Size=offset(18,18), Position=offset(44,9), Text=verityLocked and "🔒" or "🔓", Font=FONT, TextSize=getFontSize(12), TextColor3=T.dim, AutoButtonColor=false, ZIndex=13, Parent=titleBar})
lockBtn.Activated:Connect(function() verityLocked=not verityLocked lockBtn.Text=verityLocked and "🔒" or "🔓" Settings:Set("verityLocked",verityLocked,"global") Settings:Save("global") pushToast(verityLocked and "Verity locked" or "Verity unlocked — drag title", "warn",1.4) Verity.locked=verityLocked end)
Verity.locked=verityLocked

new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-190,1,0), Position=offset(68,0), Font=FONTB, Text="EQUILIBRIUM", TextSize=getFontSize(13), TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=titleBar})
new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-190,1,0), Position=offset(68,14), Font=FONT, Text="v2.1 • Universal Hub", TextSize=getFontSize(9), TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=titleBar})

-- Windows buttons _ □ ×
local winRow=new("Frame",{BackgroundTransparency=1, Size=offset(138,36), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), ZIndex=13, Parent=titleBar}) hlist(winRow,0)
local function winBtn(txt,isClose)
    local b=new("TextButton",{BackgroundColor3=T.titleBar, Size=offset(46,36), Text=txt, Font=FONTB, TextSize=isClose and getFontSize(18) or getFontSize(14), TextColor3=T.dim, AutoButtonColor=false, BorderSizePixel=0, ZIndex=13, Parent=winRow})
    if isClose then b.MouseEnter:Connect(function() b.BackgroundColor3=T.warn; b.TextColor3=Color3.new(1,1,1) end) b.MouseLeave:Connect(function() b.BackgroundColor3=T.titleBar; b.TextColor3=T.dim end)
    else b.MouseEnter:Connect(function() b.BackgroundColor3=T.border; b.TextColor3=T.text end) b.MouseLeave:Connect(function() b.BackgroundColor3=T.titleBar; b.TextColor3=T.dim end) end
    b.MouseButton1Down:Connect(function() b.BackgroundColor3 = isClose and T.warnHover or T.border end)
    return b
end
local btnMin=winBtn("_",false); local btnMax=winBtn("□",false); local btnClose=winBtn("×",true)
do local hold,holdT
    btnClose.MouseButton1Down:Connect(function() hold=true holdT=tick() task.spawn(function() while hold and tick()-holdT<0.9 do task.wait(0.05) end if hold and tick()-holdT>=0.9 then hold=false btnClose.Text="…"; task.wait(0.18) local fn=getgenv()[UNLOAD_KEY] if fn then pcall(fn) end btnClose.Text="×" end end) end)
    btnClose.MouseButton1Up:Connect(function() if not hold then return end local d=tick()-holdT hold=false btnClose.Text="×" if d<0.9 then tw(canvas,TweenInfo.new(0.16),{GroupTransparency=1}).Completed:Wait() screen.Enabled=false canvas.GroupTransparency=0 pushToast("Hidden — RightShift to restore","warn",2) end end)
    btnClose.MouseLeave:Connect(function() hold=false btnClose.Text="×" end)
end

-- Puck (= sign, theme-compatible)
local PUCK=56
local puck=new("TextButton",{BackgroundColor3=T.panel, Size=offset(PUCK,PUCK), Position=offset(centeredPos(PUCK,PUCK).X,centeredPos(PUCK,PUCK).Y), Text="", AutoButtonColor=false, BorderSizePixel=0, Visible=false, ZIndex=40, Parent=screen}) corner(puck,16) stroke(puck,T.border,1)
rootMaid:give(puck)
local puckLabel=new("TextLabel",{BackgroundTransparency=1, Size=UDim2.fromScale(1,1), Font=FONTB, Text="=", TextSize=getFontSize(22), TextColor3=T.text, ZIndex=41, Parent=puck})
local puckDot=new("Frame",{BackgroundColor3=T.on, Size=offset(10,10), Position=UDim2.new(1,-8,0,-2), Visible=false, ZIndex=42, Parent=puck}) corner(puckDot,5)
-- Puck mode: image background option
local puckMode="symbol" -- "symbol" or "image"
local currentBgPreset=Settings:Get("bgPreset","global") or "Slate"
local function applyPuckTheme()
    local bgInfo=RBX_BACKGROUNDS[1]
    for _,bg in ipairs(RBX_BACKGROUNDS) do if bg.name==currentBgPreset then bgInfo=bg break end end
    puck.BackgroundColor3=Color3.fromHex(bgInfo.color)
    puckLabel.TextColor3=T.text
    if puckMode=="image" and bgInfo.assetId~="" then
        -- Try to load image (will fail gracefully in most executors)
        pcall(function()
            local img=new("ImageLabel",{Image=bgInfo.assetId, Size=UDim2.fromScale(1,1), ScaleType=Enum.ScaleType.Crop, TileSize=UDim2.fromOffset(128,128), BackgroundTransparency=1, ZIndex=40, Parent=puck})
            new("UICorner",{CornerRadius=UDim.new(0,16), Parent=img})
        end)
    end
end
applyPuckTheme()
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
local searchBox=new("TextBox",{BackgroundTransparency=1, Size=UDim2.fromScale(1,1), Font=FONT, Text="", PlaceholderText="Search features…", PlaceholderColor3=T.dim, TextSize=getFontSize(12), TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ClearTextOnFocus=false, ZIndex=13, Parent=searchWrap})
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
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(0,90,1,0), Font=FONT, Text=cfg.label or "Value", TextSize=getFontSize(11), TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=14, Parent=row})
    local valLabel=new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(0,40,1,0), Position=UDim2.new(1,-40,0,0), Font=FONTB, Text=tostring(value), TextSize=getFontSize(11), TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=14, Parent=row})
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
    rootMaid:give(function() cleanup() end)
end}}})
register({id="noclip", name="Noclip", category="Movement", desc="Walk through walls", methods={{id="loop", name="Loop", start=function(ctx) ctx:every("heartbeat",function() if not Char.model then return end for _,p in ipairs(Char.model:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end) end}}})
register({id="fov", name="FOV", category="Visuals", desc="Camera FOV", settings={fov={default=90, min=60, max=120, step=1}}, methods={{id="direct", name="Direct", requiresChar=false, start=function(ctx) Workspace.CurrentCamera.FieldOfView=ctx.s.fov ctx:every("heartbeat",function() Workspace.CurrentCamera.FieldOfView=ctx.s.fov end) end}}})
register({id="fullbright", name="Fullbright", category="Visuals", desc="No shadows", methods={{id="on", name="On", requiresChar=false, start=function(ctx) Lighting.Brightness=2 Lighting.ClockTime=14 Lighting.FogEnd=1e6 Lighting.GlobalShadows=false end}}})
register({id="esp", name="Player ESP", category="Visuals", desc="Billboard ESP", methods={{id="billboard", name="Billboard", requiresChar=false, start=function(ctx)
    local folder=new("Folder",{Name="EquilibriumESP", Parent=Camera}) ctx.maid:give(function() folder:Destroy() end)
    ctx:every("heartbeat",function() for _,plr in ipairs(Players:GetPlayers()) do if plr~=LP and plr.Character and plr.Character:FindFirstChild("Head") then local bb=folder:FindFirstChild(plr.Name) or new("BillboardGui",{Name=plr.Name, Adornee=plr.Character.Head, Size=UDim2.fromOffset(100,20), AlwaysOnTop=true, Parent=folder}) local lbl=bb:FindFirstChildOfClass("TextLabel") or new("TextLabel",{BackgroundTransparency=1, Size=UDim2.fromScale(1,1), Font=FONTB, Text=plr.Name, TextSize=getFontSize(12), TextColor3=T.text, Parent=bb}) end end end)
end}}})
register({id="tracer", name="Tracers", category="Visuals", desc="Coming Soon", methods={{id="draw", name="Draw", requiresChar=false, start=function(ctx) end}}})
register({id="serverhop", name="Server Hop", category="Server", desc="Find new server", methods={{id="hop", name="Hop", requiresChar=false, start=function(ctx) end}}, actions={{text="Hop Now", run=function() local ok,body=pcall(function() return game:HttpGet(("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100"):format(game.PlaceId)) end) if not ok then pushToast("HttpGet blocked by executor","warn") return end local data=HttpService:JSONDecode(body) local cands={} for _,sv in ipairs(data.data or {}) do if sv.id~=game.JobId and sv.playing<sv.maxPlayers then table.insert(cands,sv) end end if #cands==0 then pushToast("No servers","warn") return end local pick=cands[math.random(1,#cands)] TeleportService:TeleportToPlaceInstance(game.PlaceId,pick.id,LP) end}}})
register({id="teleport", name="Teleport to Player", category="Teleport", desc="Coming Soon", methods={{id="direct", name="Direct", start=function(ctx) end}}})

-- Tabs
local TABS={"Movement","Visuals","Teleport","Server","Settings","About"}; local currentTab=TABS[1]; local tabButtons={}; local cards={}
local function refresh() for _,c in ipairs(cards) do c.frame.Visible=(currentTab==c.tab) end end
for _,name in ipairs(TABS) do local b=new("TextButton",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,36), Text="", AutoButtonColor=false, ZIndex=12, Parent=tabBar}) local lbl=new("TextLabel",{BackgroundTransparency=1, Size=UDim2.fromScale(1,1), Font=FONT, Text=name, TextSize=getFontSize(12), TextColor3=T.dim, ZIndex=13, Parent=b}) b.Activated:Connect(function() currentTab=name for _,bb in pairs(tabButtons) do bb.lbl.TextColor3=T.dim end lbl.TextColor3=T.text refresh() end) tabButtons[name]={btn=b,lbl=lbl} if name==currentTab then lbl.TextColor3=T.text end end
local function makeCard(tab,title,desc) local card=new("Frame",{BackgroundColor3=T.panel, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BorderSizePixel=0, Visible=tab==currentTab, ZIndex=12, Parent=page}) corner(card,10) stroke(card,T.border) pad(card,10,10,12,12) vlist(card,8) new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,getFontSize(16)), Font=FONTB, Text=title, TextSize=getFontSize(13), TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=card}) if desc then new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,getFontSize(14)), Font=FONT, Text=desc, TextSize=getFontSize(11), TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=card}) end local c={frame=card,tab=tab} table.insert(cards,c) return card end
local catMap={Movement={}, Visuals={}, Teleport={}, Server={}, Settings={}, About={}} for _,id in ipairs(order) do local f=Features[id] table.insert(catMap[f.category] or catMap["Settings"], f) end
for _,cat in ipairs(TABS) do for _,def in ipairs(catMap[cat] or {}) do
    local isComingSoon = (def.id=="tracer" or def.id=="teleport")
    local card=makeCard(cat, def.name, def.desc)
    if isComingSoon then card.BackgroundTransparency=0.4 end
    local row=new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=13, Parent=card})
    local tog=makeToggle(row,{value=false, onChange=function(v) if isComingSoon then return false end return setEnabled(def.id, v) end})
    tog.instance.Position=UDim2.new(1,-40,0.5,-10)
    if isComingSoon then tog.instance.Active=false tog.instance.AutoButtonColor=false tog.instance.BackgroundColor3=T.off end
    if def.id=="fly" then
        makeSlider(card,{label="Speed", min=20, max=500, step=5, default=RState[def.id].settings.speed, onChange=function(v) RState[def.id].settings.speed=v end})
    elseif def.id=="walkspeed" then
        makeSlider(card,{label="Speed", min=16, max=400, step=2, default=RState[def.id].settings.speed, onChange=function(v) RState[def.id].settings.speed=v end})
    elseif def.id=="fov" then
        makeSlider(card,{label="FOV", min=60, max=120, step=1, default=RState[def.id].settings.fov, onChange=function(v) RState[def.id].settings.fov=v if Active[def.id] then Workspace.CurrentCamera.FieldOfView=v end end})
    elseif def.id=="jumppower" then
        makeSlider(card,{label="Power", min=50, max=250, step=5, default=RState[def.id].settings.power, onChange=function(v) RState[def.id].settings.power=v if Active[def.id] and alive() then Char.hum.JumpPower=v end end})
    end
    if def.actions then for _,a in ipairs(def.actions) do local btn=new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(1,0,0,28), Text=a.text, Font=FONT, TextSize=getFontSize(12), TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=card}) corner(btn,8) stroke(btn,T.border) btn.Activated:Connect(function() pcall(a.run) end) end end
end end

-- ===== ABOUT TAB (Fixed layout - vertical document flow) =====
do
    local aboutCard = makeCard("About", "Equilibrium", "UI assets, credits, and build information")
    
    -- Build Info Section
    local buildSection = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=13, Parent=aboutCard})
    vlist(buildSection, 8)
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,getFontSize(14)), Font=FONTB, Text="BUILD INFO", TextSize=getFontSize(12), TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=14, Parent=buildSection})
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,getFontSize(28)), Font=FONT, Text="Version 2.1 · Build Equilibrium\nRuntime Signature: Heartbeats-2", TextSize=getFontSize(11), TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Center, TextWrapped=true, ZIndex=14, Parent=buildSection})
    
    -- Identity Section
    local identityCard = new("Frame",{BackgroundColor3=T.bg, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BorderSizePixel=0, ZIndex=13, Parent=aboutCard})
    corner(identityCard, 12) stroke(identityCard, T.border) pad(identityCard, 16, 16, 16, 16) vlist(identityCard, 12)
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,getFontSize(14)), Font=FONTB, Text="IDENTITY", TextSize=getFontSize(12), TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=14, Parent=identityCard})
    
    -- Profile ID Row
    local idRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=14, Parent=identityCard})
    vlist(idRow, 6)
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,getFontSize(16)), Font=FONT, Text="Profile ID", TextSize=getFontSize(11), TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=15, Parent=idRow})
    local idInputRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,32), ZIndex=15, Parent=idRow})
    hlist(idInputRow, 8)
    local profileIdBox = new("TextBox",{BackgroundColor3=T.bg, Size=UDim2.new(1,-100,1,0), Font=FONT, Text="070707", PlaceholderText="Enter ID", PlaceholderColor3=T.dim, TextSize=getFontSize(12), TextColor3=T.text, ClearTextOnFocus=false, ZIndex=16, Parent=idInputRow})
    corner(profileIdBox, 8) stroke(profileIdBox, T.border) pad(profileIdBox, 0, 0, 10, 10)
    local insertIdBtn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0,92,1,0), Text="Insert ID", Font=FONT, TextSize=getFontSize(11), TextColor3=T.text, AutoButtonColor=false, ZIndex=16, Parent=idInputRow})
    corner(insertIdBtn, 8) stroke(insertIdBtn, T.border)
    insertIdBtn.Activated:Connect(function() pushToast("ID inserted: "..profileIdBox.Text, "warn", 1.5) end)
    
    -- Preset Row
    local presetRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=15, Parent=identityCard})
    vlist(presetRow, 6)
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,getFontSize(16)), Font=FONT, Text="Preset", TextSize=getFontSize(11), TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=16, Parent=presetRow})
    local presetBtnRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,32), ZIndex=16, Parent=presetRow})
    hlist(presetBtnRow, 8)
    local customBtn = new("TextButton",{BackgroundColor3=T.accent, Size=UDim2.new(0,70,1,0), Text="Custom", Font=FONT, TextSize=getFontSize(10), TextColor3=T.text, AutoButtonColor=false, ZIndex=17, Parent=presetBtnRow})
    corner(customBtn, 6)
    local p5Btn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0,50,1,0), Text="P5", Font=FONT, TextSize=getFontSize(10), TextColor3=T.text, AutoButtonColor=false, ZIndex=17, Parent=presetBtnRow})
    corner(p5Btn, 6) stroke(p5Btn, T.border)
    local p6Btn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0,50,1,0), Text="P6", Font=FONT, TextSize=getFontSize(10), TextColor3=T.text, AutoButtonColor=false, ZIndex=17, Parent=presetBtnRow})
    corner(p6Btn, 6) stroke(p6Btn, T.border)
    
    -- Special Thanks Section
    local thanksSection = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=13, Parent=aboutCard})
    vlist(thanksSection, 8)
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,getFontSize(14)), Font=FONTB, Text="SPECIAL THANKS", TextSize=getFontSize(12), TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=14, Parent=thanksSection})
    local thanksTags = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=14, Parent=thanksSection})
    local thanksLayout = new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal, HorizontalAlignment=Enum.HorizontalAlignment.Center, VerticalAlignment=Enum.VerticalAlignment.Center, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6), Parent=thanksTags})
    local thanksWrapping = new("UIPadding",{PaddingTop=UDim.new(0,4), PaddingBottom=UDim.new(0,4), Parent=thanksTags})
    local thanksItems = {"Verity team", "Fleece Utility", "SchizHub v7", "Base_Rework", "DarkHub", "TokkuHub", "Contributors"}
    for i,item in ipairs(thanksItems) do
        local tag = new("TextLabel",{BackgroundColor3=T.bg, Size=UDim2.new(0,0,0,26), AutomaticSize=Enum.AutomaticSize.X, Font=FONT, Text=item, TextSize=getFontSize(10), TextColor3=T.dim, ZIndex=15, Parent=thanksTags})
        corner(tag, 6) stroke(tag, T.border) pad(tag, 4, 4, 8, 8)
    end
    
    -- Favorite Games Section
    local gamesSection = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=13, Parent=aboutCard})
    vlist(gamesSection, 8)
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,getFontSize(14)), Font=FONTB, Text="FAVORITE GAMES", TextSize=getFontSize(12), TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=14, Parent=gamesSection})
    local gameList = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=14, Parent=gamesSection})
    vlist(gameList, 6)
    local games = {
        {"Ninja Legends", "Scriptbloxian Studios"},
        {"Phantom Forces", "StyLiS Studios"},
        {"Arsenal", "ROLVe Community"},
        {"Jailbreak", "Badimo"},
        {"BedWars", "Easy.gg"},
        {"Adopt Me!", "DreamCraft"},
    }
    for _,game in ipairs(games) do
        local gameCard = new("Frame",{BackgroundColor3=T.bg, Size=UDim2.new(1,0,0,44), BorderSizePixel=0, ZIndex=15, Parent=gameList})
        corner(gameCard, 10) stroke(gameCard, T.border) pad(gameCard, 0, 0, 14, 14)
        new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(0.6,0,1,0), Font=FONTB, Text=game[1], TextSize=getFontSize(11), TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=16, Parent=gameCard})
        new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(0.4,0,1,0), Position=UDim2.new(0.6,0,0,0), Font=FONT, Text=game[2], TextSize=getFontSize(10), TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Right, TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=16, Parent=gameCard})
    end
end

-- ===== SETTINGS TAB (Size presets, Font changer) =====
do
    local settingsCard = makeCard("Settings", "Appearance & Lifecycle", "Customize hub size, font, and more")
    
    -- Hub Size Section
    local sizeSection = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=13, Parent=settingsCard})
    vlist(sizeSection, 8)
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,getFontSize(16)), Font=FONTB, Text="Hub Size", TextSize=getFontSize(12), TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=14, Parent=sizeSection})
    
    -- Size Preset Buttons
    local presetRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=14, Parent=sizeSection})
    vlist(presetRow, 6)
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,getFontSize(14)), Font=FONT, Text="Preset", TextSize=getFontSize(10), TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=15, Parent=presetRow})
    local presetBtnContainer = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,36), ZIndex=15, Parent=presetRow})
    hlist(presetBtnContainer, 6)
    local activePresetBtn = nil
    local sizePresetButtons = {}
    for _,presetName in ipairs(SIZE_PRESET_NAMES) do
        local btn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0,0,1,0), AutomaticSize=Enum.AutomaticSize.X, Text=presetName, Font=FONT, TextSize=getFontSize(10), TextColor3=T.text, AutoButtonColor=false, ZIndex=16, Parent=presetBtnContainer})
        corner(btn, 6) stroke(btn, T.border) pad(btn, 6, 6, 10, 10)
        btn.Activated:Connect(function()
            local preset = SIZE_PRESETS[presetName]
            W = preset.w
            H = preset.h
            shell.Size = offset(W, H)
            shell.Position = offset(centeredPos(W, H).X, centeredPos(W, H).Y)
            Settings:Set("winW", W, "global")
            Settings:Set("winH", H, "global")
            Settings:Save("global")
            -- Update slider to match
            local sliderVal = (W - 320) / (820 - 320) * 100
            sizeSlider.set(sliderVal)
            -- Highlight this button
            if activePresetBtn then
                activePresetBtn.BackgroundColor3 = T.panel
                activePresetBtn.TextColor3 = T.text
            end
            btn.BackgroundColor3 = T.accent
            btn.TextColor3 = T.text
            activePresetBtn = btn
            pushToast("Size: "..presetName.." ("..W.."x"..H..")", "warn", 1.2)
        end)
        table.insert(sizePresetButtons, btn)
    end
    
    -- Size Slider
    local sizeSliderRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=14, Parent=sizeSection})
    vlist(sizeSliderRow, 6)
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,getFontSize(14)), Font=FONT, Text="Custom Size", TextSize=getFontSize(10), TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=15, Parent=sizeSliderRow})
    local sizeSliderLabel = new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,getFontSize(16)), Font=FONTB, Text=W.." x "..H, TextSize=getFontSize(11), TextColor3=T.accent, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=15, Parent=sizeSliderRow})
    local sizeSlider = makeSlider(sizeSliderRow,{label="", min=0, max=100, step=1, default=((W-320)/(820-320))*100, onChange=function(v)
        local newW = math.floor(320 + (v/100) * (820-320))
        local newH = math.floor(420 + (v/100) * (680-420))
        W = newW
        H = newH
        shell.Size = offset(W, H)
        shell.Position = offset(centeredPos(W, H).X, centeredPos(W, H).Y)
        sizeSliderLabel.Text = W.." x "..H
        Settings:Set("winW", W, "global")
        Settings:Set("winH", H, "global")
        Settings:Save("global")
        -- Unhighlight preset buttons
        if activePresetBtn then
            activePresetBtn.BackgroundColor3 = T.panel
            activePresetBtn.TextColor3 = T.text
            activePresetBtn = nil
        end
    end})
    
    -- Font Section
    local fontSection = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=13, Parent=settingsCard})
    vlist(fontSection, 8)
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,getFontSize(16)), Font=FONTB, Text="Font", TextSize=getFontSize(12), TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=14, Parent=fontSection})
    
    -- Font Dropdown
    local fontDropdownRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=14, Parent=fontSection})
    vlist(fontDropdownRow, 6)
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,getFontSize(14)), Font=FONT, Text="Select Font", TextSize=getFontSize(10), TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=15, Parent=fontDropdownRow})
    local fontDropdownBtn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(1,0,0,36), Text="Current: "..CURRENT_FONT, Font=FONT, TextSize=getFontSize(11), TextColor3=T.text, AutoButtonColor=false, ZIndex=15, Parent=fontDropdownRow})
    corner(fontDropdownBtn, 8) stroke(fontDropdownBtn, T.border) pad(fontDropdownBtn, 0, 0, 10, 10)
    local fontDropdownOpen = false
    local fontDropdownList = nil
    fontDropdownBtn.Activated:Connect(function()
        fontDropdownOpen = not fontDropdownOpen
        if fontDropdownOpen then
            -- Create dropdown list
            if not fontDropdownList then
                fontDropdownList = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=16, Parent=fontDropdownRow})
                vlist(fontDropdownList, 4)
                pad(fontDropdownList, 4, 4, 0, 0)
                for _,fontName in ipairs(FONT_OPTIONS) do
                    local fontBtn = new("TextButton",{BackgroundColor3=T.bg, Size=UDim2.new(1,0,0,32), Text=fontName, Font=FONT_PRESETS[fontName], TextSize=getFontSize(11), TextColor3=T.text, AutoButtonColor=false, ZIndex=17, Parent=fontDropdownList})
                    corner(fontBtn, 6)
                    fontBtn.Activated:Connect(function()
                        CURRENT_FONT = fontName
                        FONT = FONT_PRESETS[fontName] or Enum.Font.Gotham
                        Settings:Set("fontPreset", CURRENT_FONT, "global")
                        Settings:Save("global")
                        fontDropdownBtn.Text = "Current: "..CURRENT_FONT
                        fontDropdownBtn.Font = FONT
                        fontDropdownOpen = false
                        if fontDropdownList then
                            fontDropdownList:Destroy()
                            fontDropdownList = nil
                        end
                        pushToast("Font: "..CURRENT_FONT, "warn", 1.2)
                    end)
                end
            end
            fontDropdownList.Visible = true
        else
            if fontDropdownList then
                fontDropdownList.Visible = false
            end
        end
    end)
    
    -- Font Size Slider
    local fontSizeSliderRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=14, Parent=fontSection})
    vlist(fontSizeSliderRow, 6)
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,getFontSize(14)), Font=FONT, Text="Font Size", TextSize=getFontSize(10), TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=15, Parent=fontSizeSliderRow})
    local fontSizeLabel = new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,getFontSize(16)), Font=FONTB, Text=tostring(CURRENT_FONT_SIZE), TextSize=getFontSize(11), TextColor3=T.accent, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=15, Parent=fontSizeSliderRow})
    makeSlider(fontSizeSliderRow,{label="", min=10, max=18, step=1, default=CURRENT_FONT_SIZE, onChange=function(v)
        CURRENT_FONT_SIZE = v
        Settings:Set("fontSize", CURRENT_FONT_SIZE, "global")
        Settings:Save("global")
        fontSizeLabel.Text = tostring(v)
        pushToast("Font Size: "..v, "warn", 1.2)
    end})
    
    -- Lifecycle Section
    local lifecycleSection = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=13, Parent=settingsCard})
    vlist(lifecycleSection, 8)
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,getFontSize(16)), Font=FONTB, Text="Lifecycle", TextSize=getFontSize(12), TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=14, Parent=lifecycleSection})
    local unloadBtn = new("TextButton",{BackgroundColor3=T.warn, Size=UDim2.new(1,0,0,36), Text="UNLOAD Equilibrium", Font=FONTB, TextSize=getFontSize(12), TextColor3=Color3.new(1,1,1), AutoButtonColor=false, ZIndex=14, Parent=lifecycleSection})
    corner(unloadBtn, 8)
    unloadBtn.Activated:Connect(function() local fn=getgenv()[UNLOAD_KEY] if fn then pcall(fn) end end)
end

-- Hotkeys
local toggleKey=Enum.KeyCode.RightShift; local miniKey=Enum.KeyCode.Semicolon
UserInputService.InputBegan:Connect(function(inp,proc) if proc then return end if inp.KeyCode==toggleKey then screen.Enabled=not screen.Enabled if minimized and screen.Enabled then doRestore() end elseif inp.KeyCode==miniKey then if screen.Enabled and not minimized then doMinimize() elseif minimized then doRestore() end end end)

task.spawn(function() while task.wait(2.8+math.random()) do if screen.Enabled then verityBlink() end end end)

local unload=false
local function doUnload() if unload then return end unload=true Scheduler.stopAll() for id in pairs(Active) do pcall(stop,id) end pcall(function() rootMaid:destroy() end) pcall(function() screen:Destroy() end) puckDot.Visible=false if getgenv()[UNLOAD_KEY]==doUnload then getgenv()[UNLOAD_KEY]=nil end print("[Equilibrium] unloaded") end
getgenv()[UNLOAD_KEY]=doUnload
getgenv().__equilibriumRegistry=getgenv().__equilibriumRegistry or {} table.insert(getgenv().__equilibriumRegistry, doUnload)

-- Robust mount
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
task.delay(0.12,function()
    if unload then return end
    if not screen then return end
    local ok, parent = pcall(function() return screen.Parent end)
    if not ok then return end
    if not screen.Enabled then screen.Enabled=true end
    if parent==nil then
        if unload then return end
        local ok2 = pcall(function() return screen.Parent end)
        if not ok2 then return end
        mount()
        screen.Enabled=true
    end
    pushToast("Equilibrium v2.1 — Universal Hub • _ □ × • = puck • 🔒="..(verityLocked and "locked" or "unlocked"), "warn",4)
    print("[Equilibrium] visible — where="..where.." size="..tostring(shell.AbsoluteSize))
end)

-- 2-way: verity dot on notification while minimized
EVENTS.on("verityLog",function() if minimized then puckDot.Visible=true task.delay(4,function() puckDot.Visible=false end) end end)


-- ===== TP BANK (File Explorer Style with Folders) =====
do
    local tpCard = makeCard("Teleport", "TP Bank", "12 slots • Position + LookVector • Instant")
    
    -- Data model
    local MAX_SLOTS = 12
    local positions = {}
    local folders = {}
    
    local function saveData()
        local data = {positions = positions, folders = folders}
        local ok, json = pcall(HttpService.JSONEncode, HttpService, data)
        if ok and typeof(writefile) == "function" then
            pcall(writefile, CFG_FOLDER .. "/tpbank.json", json)
        end
    end
    
    local function loadData()
        if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(CFG_FOLDER .. "/tpbank.json") then
            local ok, json = pcall(readfile, CFG_FOLDER .. "/tpbank.json")
            if ok then
                local ok2, data = pcall(HttpService.JSONDecode, HttpService, json)
                if ok2 and type(data) == "table" then
                    positions = data.positions or {}
                    folders = data.folders or {}
                end
            end
        end
    end
    loadData()
    
    local function serialize(cf)
        local p = cf.Position
        local l = cf.LookVector
        return {x = p.X, y = p.Y, z = p.Z, lx = l.X, ly = l.Y, lz = l.Z}
    end
    
    local function deserialize(d)
        local p = Vector3.new(d.x or 0, d.y or 0, d.z or 0)
        local l = Vector3.new(d.lx or 0, d.ly or 0, d.lz or 1)
        return CFrame.new(p, p + l)
    end
    
    -- Export button in header area
    local exportBtn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0,60,0,24), Text="Export", Font=FONT, TextSize=getFontSize(10), TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=tpCard})
    corner(exportBtn, 7) pad(exportBtn, 0, 0, 8, 8)
    exportBtn.Position = UDim2.new(1, -70, 0, 8)
    exportBtn.Activated:Connect(function()
        local data = {version = 1, exportedAt = os.time(), folders = folders, positions = positions}
        local ok, json = pcall(HttpService.JSONEncode, HttpService, data)
        if ok then
            local out = "-- TP Bank Export\n-- PlaceId: " .. tostring(game.PlaceId) .. "\nreturn " .. json
            if typeof(setclipboard) == "function" then
                pcall(setclipboard, out)
                pushToast("Exported " .. #positions .. " positions to clipboard", "warn", 1.6)
            else
                print(out)
                pushToast("Exported to console (F9)", "warn", 1.6)
            end
        end
    end)
    
    -- Coordinate input row
    local coordRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,32), ZIndex=13, Parent=tpCard})
    hlist(coordRow, 6)
    local xBox = new("TextBox",{BackgroundColor3=T.bg, Size=UDim2.new(0.25,-4,1,0), Font=FONT, Text="", PlaceholderText="X", PlaceholderColor3=T.dim, TextSize=getFontSize(11), TextColor3=T.text, ClearTextOnFocus=false, ZIndex=14, Parent=coordRow})
    corner(xBox, 8) stroke(xBox, T.border) pad(xBox, 0, 0, 8, 8)
    local yBox = new("TextBox",{BackgroundColor3=T.bg, Size=UDim2.new(0.25,-4,1,0), Font=FONT, Text="", PlaceholderText="Y", PlaceholderColor3=T.dim, TextSize=getFontSize(11), TextColor3=T.text, ClearTextOnFocus=false, ZIndex=14, Parent=coordRow})
    corner(yBox, 8) stroke(yBox, T.border) pad(yBox, 0, 0, 8, 8)
    local zBox = new("TextBox",{BackgroundColor3=T.bg, Size=UDim2.new(0.25,-4,1,0), Font=FONT, Text="", PlaceholderText="Z", PlaceholderColor3=T.dim, TextSize=getFontSize(11), TextColor3=T.text, ClearTextOnFocus=false, ZIndex=14, Parent=coordRow})
    corner(zBox, 8) stroke(zBox, T.border) pad(zBox, 0, 0, 8, 8)
    local goBtn = new("TextButton",{BackgroundColor3=T.accent, Size=UDim2.new(0.25,-2,1,0), Text="Go", Font=FONTB, TextSize=getFontSize(11), TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=coordRow})
    corner(goBtn, 8)
    goBtn.Activated:Connect(function()
        if not alive() then pushToast("No character", "warn") return end
        local x = tonumber(xBox.Text) or Char.root.Position.X
        local y = tonumber(yBox.Text) or Char.root.Position.Y
        local z = tonumber(zBox.Text) or Char.root.Position.Z
        Char.root.CFrame = CFrame.new(Vector3.new(x, y, z))
        pushToast("Teleported to " .. x .. ", " .. y .. ", " .. z, "warn", 1.4)
    end)
    
    -- Import row
    local importRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,32), ZIndex=13, Parent=tpCard})
    hlist(importRow, 6)
    local importBox = new("TextBox",{BackgroundColor3=T.bg, Size=UDim2.new(1,-70,1,0), Font=FONT, Text="", PlaceholderText="Paste JSON here", PlaceholderColor3=T.dim, TextSize=getFontSize(11), TextColor3=T.text, ClearTextOnFocus=false, ZIndex=14, Parent=importRow})
    corner(importBox, 8) stroke(importBox, T.border) pad(importBox, 0, 0, 8, 8)
    local importBtn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0,64,1,0), Text="Import", Font=FONT, TextSize=getFontSize(11), TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=importRow})
    corner(importBtn, 8) stroke(importBtn, T.border)
    importBtn.Activated:Connect(function()
        local ok, data = pcall(HttpService.JSONDecode, HttpService, importBox.Text)
        if not ok then pushToast("Invalid JSON", "bad") return end
        local importedPositions = data.positions or {}
        local importedFolders = data.folders or {}
        for _,f in ipairs(importedFolders) do
            local exists = false
            for _,ef in ipairs(folders) do if ef.id == f.id then exists = true break end end
            if not exists then table.insert(folders, f) end
        end
        for _,p in ipairs(importedPositions) do
            if #positions >= MAX_SLOTS then break end
            local validFolderId = nil
            if p.folderId then
                for _,f in ipairs(folders) do if f.id == p.folderId then validFolderId = p.folderId break end end
            end
            table.insert(positions, {id = p.id or ("pos-" .. tostring(tick())), name = p.name or "Imported", x = p.x or 0, y = p.y or 0, z = p.z or 0, folderId = validFolderId, createdAt = p.createdAt or os.time(), updatedAt = os.time()})
        end
        saveData()
        refreshTree()
        pushToast("Imported " .. #importedPositions .. " positions", "warn", 1.4)
    end)
    
    -- Current coordinates display
    local currentCoordFrame = new("Frame",{BackgroundColor3=T.bg, Size=UDim2.new(1,0,0,40), ZIndex=13, Parent=tpCard})
    corner(currentCoordFrame, 8) stroke(currentCoordFrame, T.border) pad(currentCoordFrame, 8, 8, 10, 10)
    local currentCoordLabel = new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-60,1,0), Font=FONT, Text="Current: 0, 0, 0", TextSize=getFontSize(11), TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=14, Parent=currentCoordFrame})
    local saveCurrentBtn = new("TextButton",{BackgroundColor3=T.accent, Size=offset(50,24), Position=UDim2.new(1,-55,0.5,-12), Text="Save", Font=FONTB, TextSize=getFontSize(10), TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=currentCoordFrame})
    corner(saveCurrentBtn, 6)
    
    -- Update current coords periodically
    local function updateCurrentCoords()
        if alive() then
            local p = Char.root.Position
            currentCoordLabel.Text = string.format("Current: %.2f, %.2f, %.2f", p.X, p.Y, p.Z)
        end
    end
    rootMaid:give(RunService.Heartbeat:Connect(updateCurrentCoords))
    
    -- Save dialog
    local saveDialogVisible = false
    local function showSaveDialog()
        if saveDialogVisible then return end
        if not alive() then pushToast("No character", "warn") return end
        if #positions >= MAX_SLOTS then pushToast("TP Bank full (12 max)", "warn") return end
        saveDialogVisible = true
        
        local overlay = new("Frame",{BackgroundColor3=Color3.fromRGB(0,0,0), BackgroundTransparency=0.5, Size=UDim2.fromScale(1,1), Visible=true, ZIndex=50, Parent=screen})
        local dialog = new("Frame",{BackgroundColor3=T.panel, Size=offset(280,140), Position=UDim2.new(0.5,0,0.5,0), AnchorPoint=Vector2.new(0.5,0.5), ZIndex=51, Parent=overlay})
        corner(dialog, 12) stroke(dialog, T.border) pad(dialog, 12, 12, 12, 12) vlist(dialog, 8)
        
        new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,16), Font=FONTB, Text="Save Current Position", TextSize=getFontSize(12), TextColor3=T.text, ZIndex=52, Parent=dialog})
        
        local nameBox = new("TextBox",{BackgroundColor3=T.bg, Size=UDim2.new(1,0,0,28), Font=FONT, Text="Position " .. (#positions + 1), PlaceholderText="Name", PlaceholderColor3=T.dim, TextSize=getFontSize(11), TextColor3=T.text, ClearTextOnFocus=false, ZIndex=52, Parent=dialog})
        corner(nameBox, 8) stroke(nameBox, T.border) pad(nameBox, 0, 0, 8, 8)
        
        local folderSelect = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=52, Parent=dialog})
        vlist(folderSelect, 4)
        new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,14), Font=FONT, Text="Folder (optional)", TextSize=getFontSize(9), TextColor3=T.dim, ZIndex=53, Parent=folderSelect})
        local folderDropdown = new("TextButton",{BackgroundColor3=T.bg, Size=UDim2.new(1,0,1,0), Text="Root", Font=FONT, TextSize=getFontSize(10), TextColor3=T.text, AutoButtonColor=false, ZIndex=53, Parent=folderSelect})
        corner(folderDropdown, 6) stroke(folderDropdown, T.border) pad(folderDropdown, 0, 0, 8, 8)
        
        local btnRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=52, Parent=dialog})
        hlist(btnRow, 6)
        local cancelBtn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0.5,-3,1,0), Text="Cancel", Font=FONT, TextSize=getFontSize(11), TextColor3=T.text, AutoButtonColor=false, ZIndex=53, Parent=btnRow})
        corner(cancelBtn, 6) stroke(cancelBtn, T.border)
        local confirmBtn = new("TextButton",{BackgroundColor3=T.accent, Size=UDim2.new(0.5,-3,1,0), Text="Save Position", Font=FONTB, TextSize=getFontSize(11), TextColor3=T.text, AutoButtonColor=false, ZIndex=53, Parent=btnRow})
        corner(confirmBtn, 6)
        
        local selectedFolderId = nil
        folderDropdown.Activated:Connect(function()
            -- Toggle folder selection (simplified)
            local opts = {"Root"}
            for _,f in ipairs(folders) do table.insert(opts, f.name) end
            local idx = table.find(opts, folderDropdown.Text) or 1
            idx = (idx % #opts) + 1
            if idx == 1 then
                folderDropdown.Text = "Root"
                selectedFolderId = nil
            else
                folderDropdown.Text = opts[idx]
                selectedFolderId = folders[idx-1].id
            end
        end)
        
        local function close()
            saveDialogVisible = false
            overlay:Destroy()
        end
        
        cancelBtn.Activated:Connect(close)
        confirmBtn.Activated:Connect(function()
            local p = Char.root.Position
            local newPos = {
                id = "pos-" .. tostring(tick()),
                name = nameBox.Text ~= "" and nameBox.Text or ("Position " .. (#positions + 1)),
                x = Number(p.X.toFixed(2)),
                y = Number(p.Y.toFixed(2)),
                z = Number(p.Z.toFixed(2)),
                folderId = selectedFolderId,
                createdAt = os.time(),
                updatedAt = os.time()
            }
            table.insert(positions, newPos)
            saveData()
            refreshTree()
            pushToast("Saved " .. newPos.name, "warn", 1.2)
            close()
        end)
        
        nameBox:CaptureFocus()
    end
    
    saveCurrentBtn.Activated:Connect(showSaveDialog)
    
    -- Tree view container
    local treeHolder = new("ScrollingFrame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,180), BorderSizePixel=0, ScrollBarThickness=4, ScrollBarImageColor3=T.border, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollingDirection=Enum.ScrollingDirection.Y, ZIndex=13, Parent=tpCard})
    local treeLayout = new("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4), Parent=treeHolder})
    pad(treeHolder, 4, 4, 4, 4)
    
    local expandedFolders = {}
    
    local function refreshTree()
        for _,c in ipairs(treeHolder:GetChildren()) do if c:IsA("GuiObject") and c.Name~=treeLayout.Name and c.Name~="UIPadding" then c:Destroy() end end
        
        local usageLabel = new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,16), Font=FONTB, Text="SAVED POSITIONS  " .. #positions .. " / " .. MAX_SLOTS .. " used", TextSize=getFontSize(10), TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=13, Parent=tpCard})
        usageLabel.Position = UDim2.new(0, 10, 0, treeHolder.Position.Y.Offset - 20)
        
        -- Root positions section
        local rootSection = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=14, Parent=treeHolder})
        vlist(rootSection, 2)
        local rootHeader = new("Frame",{BackgroundColor3=T.bg, Size=UDim2.new(1,0,0,26), ZIndex=15, Parent=rootSection})
        corner(rootHeader, 6) stroke(rootHeader, T.border) pad(rootHeader, 0, 0, 8, 8)
        hlist(rootHeader, 6, Enum.VerticalAlignment.Center)
        new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-30,1,0), Font=FONTB, Text="⠿  Root positions", TextSize=getFontSize(10), TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=16, Parent=rootHeader})
        local addBtn = new("TextButton",{BackgroundColor3=T.panel, Size=offset(22,22), Text="+", Font=FONTB, TextSize=getFontSize(12), TextColor3=T.text, AutoButtonColor=false, ZIndex=16, Parent=rootHeader})
        corner(addBtn, 5)
        addBtn.Activated:Connect(showSaveDialog)
        
        local rootPositions = {}
        for _,p in ipairs(positions) do if p.folderId == nil then table.insert(rootPositions, p) end end
        
        for i,p in ipairs(rootPositions) do
            local posCard = new("Frame",{BackgroundColor3=T.bg, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=15, Parent=rootSection})
            corner(posCard, 6) stroke(posCard, T.border) pad(posCard, 6, 6, 8, 8)
            local posHeader = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,20), ZIndex=16, Parent=posCard})
            hlist(posHeader, 4, Enum.VerticalAlignment.Center)
            new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-50,1,0), Font=FONTB, Text="⠿  " .. p.name, TextSize=getFontSize(10), TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=17, Parent=posHeader})
            local delBtn = new("TextButton",{BackgroundColor3=T.panel, Size=offset(20,20), Text="×", Font=FONTB, TextSize=getFontSize(11), TextColor3=T.dim, AutoButtonColor=false, ZIndex=17, Parent=posHeader})
            corner(delBtn, 4)
            delBtn.Activated:Connect(function()
                table.remove(positions, table.find(positions, p))
                saveData()
                refreshTree()
                pushToast("Deleted " .. p.name, "warn", 1.2)
            end)
            new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,16), Font=FONT, Text=string.format("    X %.2f · Y %.2f · Z %.2f", p.x, p.y, p.z), TextSize=getFontSize(9), TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=16, Parent=posCard})
            local goPosBtn = new("TextButton",{BackgroundColor3=T.accent, Size=offset(40,18), Position=UDim2.new(1,-45,0,2), Text="Go", Font=FONTB, TextSize=getFontSize(9), TextColor3=T.text, AutoButtonColor=false, ZIndex=17, Parent=posCard})
            corner(goPosBtn, 4)
            goPosBtn.Activated:Connect(function()
                if not alive() then pushToast("No character", "warn") return end
                Char.root.CFrame = CFrame.new(Vector3.new(p.x, p.y, p.z))
                pushToast("Teleported to " .. p.name, "warn", 1.4)
            end)
        end
        
        -- Folders section
        for _,f in ipairs(folders) do
            local folderFrame = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=14, Parent=treeHolder})
            vlist(folderFrame, 2)
            
            local folderHeader = new("Frame",{BackgroundColor3=T.bg, Size=UDim2.new(1,0,0,28), ZIndex=15, Parent=folderFrame})
            corner(folderHeader, 6) stroke(folderHeader, T.border) pad(folderHeader, 0, 0, 8, 8)
            hlist(folderHeader, 6, Enum.VerticalAlignment.Center)
            
            local expandBtn = new("TextButton",{BackgroundTransparency=1, Size=offset(18,18), Text=expandedFolders[f.id] and "▾" or "▸", Font=FONTB, TextSize=getFontSize(11), TextColor3=T.text, AutoButtonColor=false, ZIndex=16, Parent=folderHeader})
            expandBtn.Activated:Connect(function()
                expandedFolders[f.id] = not expandedFolders[f.id]
                refreshTree()
            end)
            
            new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-60,1,0), Font=FONTB, Text="📁 " .. f.name, TextSize=getFontSize(10), TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=16, Parent=folderHeader})
            
            local folderDelBtn = new("TextButton",{BackgroundColor3=T.panel, Size=offset(22,22), Text="[⋮]", Font=FONT, TextSize=getFontSize(10), TextColor3=T.dim, AutoButtonColor=false, ZIndex=16, Parent=folderHeader})
            corner(folderDelBtn, 5)
            folderDelBtn.Activated:Connect(function()
                -- Delete folder, move contents to root
                for _,p in ipairs(positions) do if p.folderId == f.id then p.folderId = nil end end
                table.remove(folders, table.find(folders, f))
                saveData()
                refreshTree()
                pushToast("Deleted folder " .. f.name, "warn", 1.2)
            end)
            
            if expandedFolders[f.id] then
                local folderPositions = {}
                for _,p in ipairs(positions) do if p.folderId == f.id then table.insert(folderPositions, p) end end
                
                for _,p in ipairs(folderPositions) do
                    local posCard = new("Frame",{BackgroundColor3=T.panel, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=15, Parent=folderFrame})
                    corner(posCard, 6) stroke(posCard, T.border) pad(posCard, 6, 6, 8, 8)
                    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-40,1,0), Font=FONTB, Text="    ⠿ " .. p.name, TextSize=getFontSize(10), TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=16, Parent=posCard})
                    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,16), Font=FONT, Text=string.format("        X %.2f · Y %.2f · Z %.2f", p.x, p.y, p.z), TextSize=getFontSize(9), TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=16, Parent=posCard})
                    local goPosBtn = new("TextButton",{BackgroundColor3=T.accent, Size=offset(36,16), Position=UDim2.new(1,-40,0,2), Text="Go", Font=FONTB, TextSize=getFontSize(8), TextColor3=T.text, AutoButtonColor=false, ZIndex=17, Parent=posCard})
                    corner(goPosBtn, 4)
                    goPosBtn.Activated:Connect(function()
                        if not alive() then pushToast("No character", "warn") return end
                        Char.root.CFrame = CFrame.new(Vector3.new(p.x, p.y, p.z))
                        pushToast("Teleported to " .. p.name, "warn", 1.4)
                    end)
                end
            end
        end
        
        if #positions == 0 then
            new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,32), Font=FONT, Text="No saved positions yet.\nSave your current coordinates to create your first position.", TextSize=getFontSize(10), TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Center, TextWrapped=true, ZIndex=14, Parent=treeHolder})
        end
    end
    
    -- Create folder button
    local createFolderBtn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0.5,-4,0,28), Text="Create folder", Font=FONT, TextSize=getFontSize(10), TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=tpCard})
    corner(createFolderBtn, 8) stroke(createFolderBtn, T.border)
    createFolderBtn.Activated:Connect(function()
        table.insert(folders, {id = "folder-" .. tostring(tick()), name = "Folder " .. (#folders + 1), parentId = nil, expanded = false, createdAt = os.time()})
        saveData()
        refreshTree()
        pushToast("Created folder", "warn", 1.2)
    end)
    
    local resetBtn = new("TextButton",{BackgroundColor3=T.warn, Size=UDim2.new(0.5,-4,0,28), Text="Reset TP Bank", Font=FONT, TextSize=getFontSize(10), TextColor3=Color3.new(1,1,1), AutoButtonColor=false, ZIndex=14, Parent=tpCard})
    corner(resetBtn, 8)
    resetBtn.Position = UDim2.new(0.5, 2, 0, createFolderBtn.Position.Y.Offset)
    resetBtn.Activated:Connect(function()
        positions = {}
        folders = {}
        saveData()
        refreshTree()
        pushToast("TP Bank reset", "warn", 1.2)
    end)
    
    refreshTree()
end

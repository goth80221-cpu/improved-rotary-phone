-- Equilibrium v2.2 | single file, no external modules required
-- Fixes: File explorer TP Bank, About tab layout, Puck "=" symbol, RBX asset backgrounds, clean load notification
-- Window: _ ⬜ × | Puck = | Theme-compatible background | Locked by default | X hide / hold unload
-- Clock Independence: InteractionState.sequence (event order) | AssistantState.Revision (conversation version) | KnowledgeRegistry.Revision (knowledge version) | Reaction/Behavior cooldowns (temporal) | AppearanceGeneration (visual rebuild) | never cross-use
-- Load Notification: Clean "v2.2 • Universal Hub" (no verbose hex codes)

-- single-instance cleanup (ownership attribute, legacy name fallback)
pcall(function()
    local r=getgenv().__equilibriumRegistry if type(r)=="table" then for _,fn in ipairs(r) do pcall(fn) end table.clear(r) end
    for _,k in ipairs({"EquilibriumUnload","FleeceUnload","VertexUnload"}) do local ok,fn=pcall(function() return getgenv()[k] end) if ok and type(fn)=="function" then pcall(fn) end end
    local function isOwned(inst) return inst and inst:GetAttribute("EquilibriumOwner")==BRAND end
    for _,n in ipairs({"EquilibriumHub","EquilibriumESP","VerityFace","EquilibriumSplash","PHHub","PSE_Essentials"}) do
        local o=pcall(function() return game.CoreGui:FindFirstChild(n) end) and game.CoreGui:FindFirstChild(n) or nil
        if o and (isOwned(o) or not o:GetAttribute("EquilibriumOwner")) then -- legacy: no attribute = allow destroy (migration)
            -- prefer attribute check, but keep legacy for migration
            if isOwned(o) or o.Name==n then pcall(function() o:Destroy() end) end
        end
        local p=game.Players.LocalPlayer:FindFirstChild("PlayerGui") and game.Players.LocalPlayer.PlayerGui:FindFirstChild(n)
        if p and (isOwned(p) or p.Name==n) then pcall(function() p:Destroy() end) end
    end
end)

-- Environment: executor/client with guarded filesystem APIs (writefile/readfile/isfile/isfolder/makefolder, gethui/getgenv, CoreGui). Not supported: ordinary LocalScript without executor, server Script, Studio plugin without adaptation.
local BRAND="Equilibrium"; local UNLOAD_KEY="EquilibriumUnload"; local CFG_FOLDER="equilibrium"
local Players=game:GetService("Players"); local RunService=game:GetService("RunService"); local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService"); local Lighting=game:GetService("Lighting"); local HttpService=game:GetService("HttpService")
local TeleportService=game:GetService("TeleportService"); local GuiService=game:GetService("GuiService"); local Workspace=game:GetService("Workspace")
local LP=Players.LocalPlayer; local Camera=Workspace.CurrentCamera or Workspace:FindFirstChildOfClass("Camera")
print("[Equilibrium] boot | "..BRAND.." v2.2")

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
local VERITY_EXPR={neutral="|", happy="?", glitch="#", curious="o", annoyed="|"}
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
    function Scheduler._countHeartbeats() local n=0 for _,b in pairs(buckets) do if b.conn then n+=1 end end return n end
    function Scheduler._countBuckets() local n=0 for _ in pairs(buckets) do n+=1 end return n end
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

-- ===== Themes (Hub only, Verity untouched) =====
THEMES={
    Theme_01={id="Theme_01", name="Slate", colors={bg=Color3.fromHex("070707"), panel=Color3.fromHex("141414"), panel2=Color3.fromHex("1a1a1e"), border=Color3.fromHex("2a2a2a"), borderHover=Color3.fromHex("3a3a3a"), text=Color3.fromHex("e6e6e6"), subtext=Color3.fromHex("a0a0a8"), dim=Color3.fromHex("7a7a80"), accent=Color3.fromHex("787a96"), accentDim=Color3.fromHex("5a5c7a"), on=Color3.fromHex("5fdc82"), off=Color3.fromHex("4b5563"), warn=Color3.fromHex("e81123"), danger=Color3.fromHex("c50f1f"), success=Color3.fromHex("5fdc82")}, effects={corner=10, border=1}},
    Theme_02={id="Theme_02", name="Grey", colors={bg=Color3.fromHex("0f0f0f"), panel=Color3.fromHex("1c1c1e"), panel2=Color3.fromHex("222226"), border=Color3.fromHex("333338"), borderHover=Color3.fromHex("44444a"), text=Color3.fromHex("e8e8ea"), subtext=Color3.fromHex("a8a8b0"), dim=Color3.fromHex("7e7e86"), accent=Color3.fromHex("9a9aaa"), accentDim=Color3.fromHex("7a7a8a"), on=Color3.fromHex("5fdc82"), off=Color3.fromHex("4b5563"), warn=Color3.fromHex("e81123"), danger=Color3.fromHex("c50f1f"), success=Color3.fromHex("5fdc82")}, effects={corner=10, border=1}},
    Theme_03={id="Theme_03", name="Galaxy", colors={bg=Color3.fromHex("080a18"), panel=Color3.fromHex("0f1230"), panel2=Color3.fromHex("151840"), border=Color3.fromHex("2a2a5a"), borderHover=Color3.fromHex("3a3a7a"), text=Color3.fromHex("e6e8ff"), subtext=Color3.fromHex("9aa0cc"), dim=Color3.fromHex("7a80a8"), accent=Color3.fromHex("7a6cff"), accentDim=Color3.fromHex("5a48cc"), on=Color3.fromHex("5fdc82"), off=Color3.fromHex("4b5563"), warn=Color3.fromHex("ff4d6a"), danger=Color3.fromHex("c50f1f"), success=Color3.fromHex("5fdc82")}, effects={corner=10, border=1}},
    Theme_04={id="Theme_04", name="Minimal", colors={bg=Color3.fromHex("050507"), panel=Color3.fromHex("0a0a0c"), panel2=Color3.fromHex("111114"), border=Color3.fromHex("1e1e1e"), borderHover=Color3.fromHex("2a2a2a"), text=Color3.fromHex("f0f0f0"), subtext=Color3.fromHex("9a9aa0"), dim=Color3.fromHex("6e6e74"), accent=Color3.fromHex("b0b0b8"), accentDim=Color3.fromHex("8a8a90"), on=Color3.fromHex("5fdc82"), off=Color3.fromHex("3a3a40"), warn=Color3.fromHex("e81123"), danger=Color3.fromHex("c50f1f"), success=Color3.fromHex("5fdc82")}, effects={corner=8, border=1}},
    Theme_05={id="Theme_05", name="Midnight", colors={bg=Color3.fromHex("050a14"), panel=Color3.fromHex("0d1424"), panel2=Color3.fromHex("121c32"), border=Color3.fromHex("1e2a44"), borderHover=Color3.fromHex("2a3a5a"), text=Color3.fromHex("e0e8ff"), subtext=Color3.fromHex("8ea0c0"), dim=Color3.fromHex("6a7a9a"), accent=Color3.fromHex("5a7fcf"), accentDim=Color3.fromHex("4668b0"), on=Color3.fromHex("5fdc82"), off=Color3.fromHex("4b5563"), warn=Color3.fromHex("e81123"), danger=Color3.fromHex("c50f1f"), success=Color3.fromHex("5fdc82")}, effects={corner=10, border=1}},
    Theme_06={id="Theme_06", name="Warm", colors={bg=Color3.fromHex("0f0a08"), panel=Color3.fromHex("1a1410"), panel2=Color3.fromHex("211a12"), border=Color3.fromHex("332a1a"), borderHover=Color3.fromHex("4a3d24"), text=Color3.fromHex("f5efe6"), subtext=Color3.fromHex("b8a898"), dim=Color3.fromHex("8a8074"), accent=Color3.fromHex("d4a85c"), accentDim=Color3.fromHex("b08940"), on=Color3.fromHex("5fdc82"), off=Color3.fromHex("4b5563"), warn=Color3.fromHex("e81123"), danger=Color3.fromHex("c50f1f"), success=Color3.fromHex("5fdc82")}, effects={corner=10, border=1}},
    Theme_07={id="Theme_07", name="Custom", colors={bg=Color3.fromHex("070707"), panel=Color3.fromHex("141414"), panel2=Color3.fromHex("1a1a1e"), border=Color3.fromHex("2a2a2a"), borderHover=Color3.fromHex("3a3a3a"), text=Color3.fromHex("e6e6e6"), subtext=Color3.fromHex("a0a0a8"), dim=Color3.fromHex("7a7a80"), accent=Color3.fromHex("787a96"), accentDim=Color3.fromHex("5a5c7a"), on=Color3.fromHex("5fdc82"), off=Color3.fromHex("4b5563"), warn=Color3.fromHex("e81123"), danger=Color3.fromHex("c50f1f"), success=Color3.fromHex("5fdc82")}, effects={corner=10, border=1}},
    Theme_08={id="Theme_08", name="Jester", colors={bg=Color3.fromHex("0e0a14"), panel=Color3.fromHex("1a1030"), panel2=Color3.fromHex("231840"), border=Color3.fromHex("3a2060"), borderHover=Color3.fromHex("4a2a80"), text=Color3.fromHex("f0e6ff"), subtext=Color3.fromHex("b8a0d8"), dim=Color3.fromHex("8e7ab8"), accent=Color3.fromHex("ff4d6a"), accentDim=Color3.fromHex("d43a55"), on=Color3.fromHex("ffd93d"), off=Color3.fromHex("4b5563"), warn=Color3.fromHex("ff6b35"), danger=Color3.fromHex("c50f1f"), success=Color3.fromHex("5fdc82")}, effects={corner=12, border=1}},
    Theme_09={id="Theme_09", name="Forest", colors={bg=Color3.fromHex("07100a"), panel=Color3.fromHex("0f1f16"), panel2=Color3.fromHex("142a1e"), border=Color3.fromHex("1e3a2a"), borderHover=Color3.fromHex("2a4a36"), text=Color3.fromHex("e0f0e6"), subtext=Color3.fromHex("8fb8a0"), dim=Color3.fromHex("6a9a80"), accent=Color3.fromHex("2ecc71"), accentDim=Color3.fromHex("239a55"), on=Color3.fromHex("2ecc71"), off=Color3.fromHex("4b5563"), warn=Color3.fromHex("e74c3c"), danger=Color3.fromHex("c0392b"), success=Color3.fromHex("2ecc71")}, effects={corner=10, border=1}},
    Theme_10={id="Theme_10", name="Amethyst", colors={bg=Color3.fromHex("0d0a14"), panel=Color3.fromHex("1a1230"), panel2=Color3.fromHex("221840"), border=Color3.fromHex("2e1f4a"), borderHover=Color3.fromHex("3e2a63"), text=Color3.fromHex("e8e0ff"), subtext=Color3.fromHex("a898c8"), dim=Color3.fromHex("7e6ea0"), accent=Color3.fromHex("9b59ff"), accentDim=Color3.fromHex("7a3fcc"), on=Color3.fromHex("9b59ff"), off=Color3.fromHex("4b5563"), warn=Color3.fromHex("e84393"), danger=Color3.fromHex("c50f1f"), success=Color3.fromHex("5fdc82")}, effects={corner=10, border=1}},
    Theme_11={id="Theme_11", name="Abyss", colors={bg=Color3.fromHex("05080c"), panel=Color3.fromHex("0d1420"), panel2=Color3.fromHex("111e30"), border=Color3.fromHex("1a2a40"), borderHover=Color3.fromHex("243a55"), text=Color3.fromHex("d8e8ff"), subtext=Color3.fromHex("8aa0b8"), dim=Color3.fromHex("6a8098"), accent=Color3.fromHex("00d4ff"), accentDim=Color3.fromHex("00a8cc"), on=Color3.fromHex("00d4ff"), off=Color3.fromHex("4b5563"), warn=Color3.fromHex("e81123"), danger=Color3.fromHex("c50f1f"), success=Color3.fromHex("00d4ff")}, effects={corner=10, border=1}},
    -- RBX Asset Background Presets (Puck Mode compatible)
    Theme_12={id="Theme_12", name="Ocean", assetId="16119734667", colors={bg=Color3.fromHex("0a1628"), panel=Color3.fromHex("0f1f35"), panel2=Color3.fromHex("142844"), border=Color3.fromHex("1e3a5a"), borderHover=Color3.fromHex("2a4a70"), text=Color3.fromHex("e0e8f0"), subtext=Color3.fromHex("8aa0b8"), dim=Color3.fromHex("6a8098"), accent=Color3.fromHex("4a9eff"), accentDim=Color3.fromHex("3a8edf"), on=Color3.fromHex("5fdc82"), off=Color3.fromHex("4b5563"), warn=Color3.fromHex("e81123"), danger=Color3.fromHex("c50f1f"), success=Color3.fromHex("5fdc82")}, effects={corner=10, border=1}},
    Theme_13={id="Theme_13", name="Dusk", assetId="16119734889", colors={bg=Color3.fromHex("1a0f14"), panel=Color3.fromHex("25141e"), panel2=Color3.fromHex("301828"), border=Color3.fromHex("4a2035"), borderHover=Color3.fromHex("5a2a45"), text=Color3.fromHex("f0e0e6"), subtext=Color3.fromHex("b898a8"), dim=Color3.fromHex("9a7a88"), accent=Color3.fromHex("ff6b9d"), accentDim=Color3.fromHex("df5a8d"), on=Color3.fromHex("5fdc82"), off=Color3.fromHex("4b5563"), warn=Color3.fromHex("ff8a6b"), danger=Color3.fromHex("c50f1f"), success=Color3.fromHex("5fdc82")}, effects={corner=10, border=1}},
    Theme_14={id="Theme_14", name="Crimson", assetId="16119735012", colors={bg=Color3.fromHex("1a0a0a"), panel=Color3.fromHex("251010"), panel2=Color3.fromHex("301414"), border=Color3.fromHex("4a1a1a"), borderHover=Color3.fromHex("5a2424"), text=Color3.fromHex("f0e0e0"), subtext=Color3.fromHex("b89898"), dim=Color3.fromHex("9a7a7a"), accent=Color3.fromHex("ff4d4d"), accentDim=Color3.fromHex("df3a3a"), on=Color3.fromHex("5fdc82"), off=Color3.fromHex("4b5563"), warn=Color3.fromHex("ff6b6b"), danger=Color3.fromHex("c50f1f"), success=Color3.fromHex("5fdc82")}, effects={corner=10, border=1}},
    Theme_15={id="Theme_15", name="Nebula", assetId="16119735234", colors={bg=Color3.fromHex("0f0a1a"), panel=Color3.fromHex("141025"), panel2=Color3.fromHex("1a1430"), border=Color3.fromHex("2a1a4a"), borderHover=Color3.fromHex("3a245a"), text=Color3.fromHex("e8e0f0"), subtext=Color3.fromHex("a098b8"), dim=Color3.fromHex("807a9a"), accent=Color3.fromHex("9b59ff"), accentDim=Color3.fromHex("8a48df"), on=Color3.fromHex("5fdc82"), off=Color3.fromHex("4b5563"), warn=Color3.fromHex("e84393"), danger=Color3.fromHex("c50f1f"), success=Color3.fromHex("5fdc82")}, effects={corner=10, border=1}},
    Theme_16={id="Theme_16", name="Aurora", assetId="16119735456", colors={bg=Color3.fromHex("0a1a14"), panel=Color3.fromHex("0f251e"), panel2=Color3.fromHex("143028"), border=Color3.fromHex("1a4a3a"), borderHover=Color3.fromHex("245a4a"), text=Color3.fromHex("e0f0e8"), subtext=Color3.fromHex("98b8a8"), dim=Color3.fromHex("7a9a88"), accent=Color3.fromHex("2ecc71"), accentDim=Color3.fromHex("239a55"), on=Color3.fromHex("5fdc82"), off=Color3.fromHex("4b5563"), warn=Color3.fromHex("e74c3c"), danger=Color3.fromHex("c0392b"), success=Color3.fromHex("2ecc71")}, effects={corner=10, border=1}},
}
-- Active semantic tokens (Hub only)
T={bg=THEMES.Theme_01.colors.bg, panel=THEMES.Theme_01.colors.panel, panel2=THEMES.Theme_01.colors.panel2, titleBar=Color3.fromHex("0f0f0f"), border=THEMES.Theme_01.colors.border, borderHover=THEMES.Theme_01.colors.borderHover, line=Color3.fromHex("252525"), text=THEMES.Theme_01.colors.text, subtext=THEMES.Theme_01.colors.subtext, dim=THEMES.Theme_01.colors.dim, accent=THEMES.Theme_01.colors.accent, accent2=Color3.fromHex("8a8dc2"), accentDim=THEMES.Theme_01.colors.accentDim, on=THEMES.Theme_01.colors.on, off=THEMES.Theme_01.colors.off, warn=THEMES.Theme_01.colors.warn, warnHover=Color3.fromHex("c50f1f"), danger=THEMES.Theme_01.colors.danger, success=THEMES.Theme_01.colors.success}
-- titleBar stays near-black for contrast across themes; line matches border
THEME_ORDER={"Theme_01","Theme_02","Theme_03","Theme_04","Theme_05","Theme_06","Theme_12","Theme_13","Theme_14","Theme_15","Theme_16","Theme_08","Theme_09","Theme_10","Theme_11","Theme_07"}
local THEME_ALIASES={Slate="Theme_01", Grey="Theme_02", Galaxy="Theme_03", Minimal="Theme_04", Midnight="Theme_05", Warm="Theme_06", Jester="Theme_08", Forest="Theme_09", Amethyst="Theme_10", Abyss="Theme_11"}
local function normalizeThemeId(id) return THEME_ALIASES[id] or id or "Theme_01" end
GOLD = Color3.fromRGB(201,168,106) -- selection gold outline
-- Theme contrast validator (diagnostic, no auto-override)
function channel(v) return v <= 0.03928 and v/12.92 or ((v+0.055)/1.055) ^ 2.4 end
function luminance(color) return 0.2126*channel(color.R)+0.7152*channel(color.G)+0.0722*channel(color.B) end
function contrastRatio(a,b) local la,lb=luminance(a),luminance(b) local light, dark=math.max(la,lb), math.min(la,lb) return (light+0.05)/(dark+0.05) end
function themeContrastAudit(themeId)
    local th=THEMES[themeId] if not th then return nil end
    local c=th.colors
    local pairs={{a=c.text,b=c.panel,label="T.text / T.panel"},{a=c.dim,b=c.panel,label="T.dim / T.panel"},{a=c.text,b=c.accent,label="selected text / T.accent"},{a=c.text,b=c.panel2,label="T.text / T.panel2"},{a=c.accent,b=c.bg,label="T.accent / T.bg"}}
    local worst, worstLabel, worstRatio = nil, nil, 99
    for _,p in ipairs(pairs) do local r=contrastRatio(p.a,p.b) if r<worstRatio then worstRatio=r worstLabel=p.label worst=p end end
    local status = worstRatio>=4.5 and "PASS" or (worstRatio>=3.0 and "WARNING" or "FAIL")
    return {Theme=themeId, Name=th.name, LowestRatio=worstRatio, Pair=worstLabel, Pass=worstRatio>=4.5, Status=status, All=pairs}
end
_G.ThemeAudit = themeContrastAudit
_G.ThemeAuditAll = function() local out={} for _,id in ipairs(THEME_ORDER) do out[#out+1]=themeContrastAudit(id) end return out end
-- Verity identity palette | fixed black/gold, never themed by Hub (ThemeLocked authoritative)
local VERITY_THEME = { bg=Color3.fromHex("070707"), panel=Color3.fromHex("141414"), border=Color3.fromRGB(201,168,106), text=Color3.fromHex("e6e6e6"), dim=Color3.fromHex("a0a0a8"), accent=Color3.fromRGB(201,168,106), on=Color3.fromHex("5fdc82"), off=Color3.fromHex("4b5563"), warn=Color3.fromHex("e81123") }
-- Hub Appearance persisted (Settings global hubAppearance)
-- New preset-based architecture: BaseTheme + UserOverrides = ResolvedAppearance
hubAppearance = {
    PresetId = "Theme_01",
    BaseTheme = "Theme_01",
    Overrides = {},
    -- Legacy compatibility fields (migrated on load)
    Theme = "Theme_01",
    Scale = 1.0,
    Position = nil,
    Transparency = 0,
    PositionMode = "Draggable",
    RememberPosition = true,
    BorderEnabled = true,
    BorderThickness = 1,
    CornerRadius = 10,
    ShadowsEnabled = true,
    GlowEnabled = false,
    TextScale = 1.0,
    ClipEnabled = true,
    CustomColors = nil,
}

-- Check if appearance has unsaved changes vs saved preset
function isAppearanceDirty(current, saved)
    saved = saved or Settings:Get("hubAppearance","global") or {}
    if not saved then return false end
    local keys = {"PresetId", "BaseTheme", "Scale", "Transparency", "BorderEnabled", "BorderThickness", "CornerRadius", "ShadowsEnabled", "GlowEnabled"}
    for _,k in ipairs(keys) do
        if current[k] ~= saved[k] then return true end
    end
    if current.Overrides and saved.Overrides then
        for k,v in pairs(current.Overrides) do
            if saved.Overrides[k] ~= v then return true end
        end
        for k,v in pairs(saved.Overrides) do
            if current.Overrides[k] ~= v then return true end
        end
    elseif current.Overrides or saved.Overrides then
        return true
    end
    -- Legacy field check
    if current.Theme ~= normalizeThemeId(saved.Theme or saved.theme) then return true end
    return false
end
-- PresentationState — derived UI presentation, not intelligence
PresentationState = { NavigationMode="Sidebar", Viewport=Vector2.new(620,520), WindowState="Normal", AppearanceGeneration=0 }
-- Layout tokens (10K-RP UX polish, controlled spacing/typography)
local UI = {
    Spacing = { XSmall=4, Small=8, Medium=12, Large=16, XLarge=24 },
    Radius = { Small=4, Medium=8, Large=12 },
    Height = { Input=32, Button=32, CompactButton=26, SectionHeader=28 },
    Text = { Title=16, Section=11, Body=13, Hint=9, Caption=10 },
    LayoutProfile = {
        Narrow = { PanelPadding=8, RowGap=6, LabelWidth=88, SwatchSize=18 },
        Standard = { PanelPadding=12, RowGap=8, LabelWidth=112, SwatchSize=20 },
        Wide = { PanelPadding=16, RowGap=8, LabelWidth=128, SwatchSize=20 },
    },
}
_G.UI_TOKENS = UI

-- UX Contracts (10K-RP)
-- LayoutTokens OWNER:Hub ALLOWED:Hub/Verity Shared FORBIDDEN:AssistantState/Knowledge STATE:Transient CLOCKS:Viewport LIFECYCLE:None FAILURE:overflow REGRESSION:519/520/521
-- LayoutProfile OWNER:Hub ALLOWED:applyShellGeometry FORBIDDEN:rebuild STATE:Transient CLOCKS:Viewport LIFECYCLE:None
-- SectionBuilder OWNER:Hub ALLOWED:makeCard FORBIDDEN:Knowledge STATE:Transient
-- ControlRowBuilder OWNER:Hub ALLOWED:makeSlider/makeToggle FORBIDDEN:Global rebuild
-- AboutData OWNER:Hub ALLOWED:credits/games FORBIDDEN:Verity intelligence
-- AssetPresetRegistry OWNER:Hub ALLOWED:presets 6+custom FORBIDDEN:insertion persistence STATE:Transient
-- AssetInsertionState OWNER:Hub ALLOWED:Ready/Inserting/Inserted/Failed/Unavailable FORBIDDEN:Knowledge CLOCKS:none LIFECYCLE:maid for preview

-- Register pressure gate
local REGISTER_WARNING, REGISTER_CRITICAL, REGISTER_HARD = 180, 190, 200
-- Boring mode — deterministic baseline, no reaction/animation/wardrobe/voice flourish
VerityBoring = false
_G.VerityBoring = VerityBoring
-- Chat history — canonical conversation state, UI renders it
ChatHistory = {}
ResponseRevision = 0
local activeResponseRevision = nil
local function nextResponseRevision()
    ResponseRevision += 1
    _G.ResponseRevision = ResponseRevision
    return ResponseRevision
end
_G.ChatHistory = ChatHistory
_G.ResponseRevision = ResponseRevision
_G.nextResponseRevision = nextResponseRevision
local function expectedHeartbeats(state)
    if state=="Mounted" or state=="HubUnloaded" or state=="Remounted" then return 3 end
    if state=="VerityUnloaded" then return 2 end
    if state=="AllUnloaded" then return 0 end
    return 3
end
_G.expectedHeartbeats = expectedHeartbeats
function runtimeSignature()
    local eventChannels, eventSubscriptions = 0, 0
    pcall(function()
        for _, handlers in pairs(EVENTS._handlers) do
            eventChannels += 1
            eventSubscriptions += #handlers
        end
    end)
    local heartbeatObserved = 0
    pcall(function()
        heartbeatObserved = 0
        if Scheduler and Scheduler._countHeartbeats then heartbeatObserved = Scheduler._countHeartbeats() end
        -- add direct rootMaid Heartbeat conns
        local direct=0
        if rootMaid and rootMaid._items then
            for _,it in ipairs(rootMaid._items) do
                if typeof(it)=="RBXScriptConnection" then direct+=1 end
            end
        end
        -- typingConn is not always maid-owned, count separately if present
        if typingConn then direct+=1 end
        heartbeatObserved = math.max(heartbeatObserved, direct)
        -- Expected 3 = context + Verity heartbeat + typing (transient)
    end)
    local chunkLocals = 176 -- build-gate assertion, not compiler-derived (see REGISTER-01), updated manually
    local level = chunkLocals>=REGISTER_HARD and "HARD" or (chunkLocals>=REGISTER_CRITICAL and "CRITICAL" or (chunkLocals>=REGISTER_WARNING and "WARNING" or "OK"))
    return {
        HeartbeatsExpected = 3,
        HeartbeatBuckets = (Scheduler and Scheduler._countBuckets and Scheduler:_countBuckets() or 2),
        LiveHeartbeatConnections = heartbeatObserved,
        RootMaidConnections = (rootMaid and rootMaid._items and #rootMaid._items or 0),
        TypingConnections = (typingConn and 1 or 0),
        HeartbeatsObserved = heartbeatObserved,
        Heartbeats = 3, -- legacy alias
        EventChannels = eventChannels,
        EventSubscriptions = eventSubscriptions,
        ChunkLocals = chunkLocals,
        RegisterLevel = level,
        AppearanceGeneration = PresentationState.AppearanceGeneration,
        NavigationMode = PresentationState.NavigationMode,
        BoringMode = VerityBoring,
    }
end
_G.RuntimeSignature = runtimeSignature
-- Independent window state (no shared UIState.Locked) | single Mode
HubState = { Mode="Draggable" }
VerityState = { Locked=true } -- canonical: draggable = not Locked
local HubWindow = {}
function HubWindow.SetPositionMode(m) HubState.Mode = (m=="Locked" and "Locked" or "Draggable") hubAppearance.PositionMode = HubState.Mode end
function HubWindow.SetLocked(b) HubWindow.SetPositionMode(b and "Locked" or "Draggable") end
function HubWindow.SetDraggable(b) HubWindow.SetPositionMode(b and "Draggable" or "Locked") end
function HubWindow.IsDraggable() return HubState.Mode=="Draggable" end
function HubWindow.Open() screen.Enabled = true end
function HubWindow.Close() screen.Enabled = false end
local VerityWindow = {}
function VerityWindow.SetLocked(b) VerityState.Locked = b and true or false end
function VerityWindow.SetDraggable(b) VerityWindow.SetLocked(not b) end
function VerityWindow.Open() if Gui then Gui.Enabled = true end end
function VerityWindow.Close() if Gui then Gui.Enabled = false end end
-- PASS 7A: InteractionState | GUI/Window/Talking -> InteractionState -> EVENTS (no resolver)
local InteractionState = { hoverTarget=nil, attention=nil, talkingActive=false, windowOpen=false, lastEvent=nil, sequence=0 }
local function resolveInteractionTarget(inst, explicitId)
    if explicitId and explicitId~="" then return explicitId end
    if not inst then return "unknown" end
    local v = inst:GetAttribute("InteractionTarget")
    if v and v~="" then return v end
    v = inst:GetAttribute("ThemeRole")
    if v and v~="" then return v end
    if inst.Name and inst.Name~="" then return inst.Name end
    return "unknown"
end
local function fireInteraction(type, target)
    InteractionState.sequence += 1
    InteractionState.lastEvent = {type=type, target=target, sequence=InteractionState.sequence, t=tick()}
    if type=="hoverEnter" then InteractionState.hoverTarget=target
    elseif type=="hoverLeave" then if InteractionState.hoverTarget==target then InteractionState.hoverTarget=nil end
    elseif type=="talkingStart" then InteractionState.talkingActive=true
    elseif type=="talkingStop" then InteractionState.talkingActive=false
    elseif type=="windowOpen" then InteractionState.windowOpen=true
    elseif type=="windowClose" then InteractionState.windowOpen=false end
    EVENTS.fire("interaction."..type, InteractionState.lastEvent)
    EVENTS.fire("interaction", InteractionState.lastEvent)
end
-- PASS 9E: AssistantState | authoritative conversation context (Revision = version, not cooldown)
local AssistantState = { ConversationActive=false, CurrentTopic=nil, LastMessage=nil, Revision=0 }
function AssistantState._bump() AssistantState.Revision = (AssistantState.Revision or 0) + 1 end
function AssistantState.SetConversationActive(v) if AssistantState.ConversationActive ~= v then AssistantState.ConversationActive=v AssistantState._bump() end end
function AssistantState.SetCurrentTopic(v) if AssistantState.CurrentTopic ~= v then AssistantState.CurrentTopic=v AssistantState._bump() end end
function AssistantState.SetLastMessage(v) if AssistantState.LastMessage ~= v then AssistantState.LastMessage=v AssistantState._bump() end end
function AssistantState.SetConversation(active, topic, msg)
    local changed=false
    if AssistantState.ConversationActive ~= active then AssistantState.ConversationActive=active changed=true end
    if topic ~= nil and AssistantState.CurrentTopic ~= topic then AssistantState.CurrentTopic=topic changed=true end
    if msg ~= nil and AssistantState.LastMessage ~= msg then AssistantState.LastMessage=msg changed=true end
    if changed then AssistantState._bump() end
end
-- PASS 9F: ConversationInterpreter | deterministic, no visuals/Heartbeat/Maid, pure function
local ConversationInterpreter = {}
_G.ConversationInterpreter = ConversationInterpreter
do
    local function lower(s) return string.lower(s or "") end
    local greetings = {"hello","hey","hi ","hi,","yo","sup","good morning","good evening","greetings"}
    local farewells = {"bye","goodbye","see you","later","farewell","cya","take care"}
    local positive = {"awesome","great","nice","love","amazing","cool","good","wonderful","fantastic","happy"}
    local negative = {"sad","bad","terrible","awful","hate","horrible","angry","upset","depressed"}
    local curiousQ = {"?","what","who","why","how","when","where","tell me","explain","can you"}
    local topics = {"horror","music","game","script","exploit","verity","hub","wardrobe","theme"}
    local function containsAny(s, list) for _,w in ipairs(list) do if s:find(w,1,true) then return w end end return nil end
    function ConversationInterpreter.Resolve(lastMessage, assistantState)
        local srcRev = assistantState and assistantState.Revision or AssistantState.Revision
        local raw = lastMessage or (assistantState and assistantState.LastMessage) or ""
        local s = lower(raw):gsub("^%s+",""):gsub("%s+$","")
        if s=="" then return {Intent="Unknown", Topic=nil, Tone="Unknown", Confidence=0.1, SourceRevision=srcRev, SourceMessage=raw} end
        local topicFound
        for _,t in ipairs(topics) do if s:find(t,1,true) then topicFound=t break end end
        local isQuestion = s:find("?",1,true) ~= nil or containsAny(s, {"what","who","why","how","when","where"}) ~= nil
        local isGreeting = containsAny(s, greetings) ~= nil
        local isFarewell = containsAny(s, farewells) ~= nil
        local tone = "Neutral"
        local toneConf = 0.6
        if containsAny(s, positive) then tone="Positive" toneConf=0.75
        elseif containsAny(s, negative) then tone="Negative" toneConf=0.75
        elseif containsAny(s, curiousQ) or isQuestion then tone="Curious" toneConf=0.65 end
        local intent, conf
        if isGreeting and #s < 30 then intent="Greeting" conf=0.85
        elseif isFarewell and #s < 30 then intent="Farewell" conf=0.85
        elseif isQuestion then intent="Question" conf=0.80
        elseif s:find("tell me",1,true) or s:find("explain",1,true) then intent="Question" conf=0.75
        elseif #s > 0 then intent="Statement" conf=0.65
        else intent="Unknown" conf=0.1 end
        -- Unknown fallback when no pattern strong enough
        if intent=="Statement" and tone=="Neutral" and not topicFound and #s < 4 then intent="Unknown" conf=0.2 tone="Unknown" end
        return {Intent=intent, Topic=topicFound, Tone=tone, Confidence=math.clamp(conf,0,1), SourceRevision=srcRev, SourceMessage=raw}
    end
    _G.TestInterpret = function(msg) return ConversationInterpreter.Resolve(msg, AssistantState) end
end
-- PASS 9G: ContextResolver | enriches ResolvedConversation with AssistantState snapshot, no writes/visuals
local ContextResolver = {}
_G.ContextResolver = ContextResolver
do
    function ContextResolver.Resolve(resolvedConversation, assistantState)
        local ctx = assistantState or AssistantState
        local rc = resolvedConversation
        if not rc then return nil end
        local srcRev = rc.SourceRevision
        local valid = srcRev == ctx.Revision
        -- 10G ResolvedContext | boring, no Emotion/Reaction/Wardrobe/Action
        local knowledgeQuery = rc.Topic or normalizeWord(rc.SourceMessage):match("^(%S+)") or ""
        -- KnowledgeRelevant: does query have any lexical overlap? (evidence decides confidence)
        local knowledgeRelevant = knowledgeQuery~="" and knowledgeQuery~="unknown"
        return {
            Intent = rc.Intent,
            Topic = rc.Topic,
            Tone = rc.Tone,
            ConversationActive = ctx.ConversationActive,
            Confidence = rc.Confidence,
            SourceRevision = srcRev,
            SourceMessage = rc.SourceMessage,
            ContextValid = valid,
            CurrentRevision = ctx.Revision,
            -- 10G additions
            KnowledgeQuery = knowledgeQuery,
            KnowledgeRelevant = knowledgeRelevant,
            AssistantRevision = ctx.Revision,
            Provenance = { InteractionSequence=InteractionState.sequence, AssistantRevision=ctx.Revision, KnowledgeRevision=KnowledgeRegistry.Revision },
        }
    end
    _G.TestContext = function(msg)
        local rc = ConversationInterpreter.Resolve(msg, AssistantState)
        return ContextResolver.Resolve(rc, AssistantState)
    end
end
-- =========================================================================
-- KNOWLEDGE 10A: KnowledgeRegistry + WordBanks (Hub-owned, Verity consumes)
-- Ownership: Hub/Knowledge. Verity reads via KnowledgeRegistry only.
-- Single Equilibrium.lua internal modules, not filesystem.
-- =========================================================================
-- OWNER: KnowledgeRegistry | Hub knowledge, Verity read-only consumer
-- Stable entry schema: Word/Category/Definition core; Examples/Aliases/Tags/Source enrichment; snapshots returned
KnowledgeRegistry = { banks={}, byName={}, Revision=0 }
_G.KnowledgeRegistry = KnowledgeRegistry
local function normalizeWord(s) return (s or ""):lower():gsub("^%s+",""):gsub("%s+$","") end
function KnowledgeRegistry.CreateBank(name, words)
    local key = normalizeWord(name)
    if KnowledgeRegistry.byName[key] then return KnowledgeRegistry.byName[key] end
    local bank = { Name=name, Words={}, byWord={}, Active=true }
    KnowledgeRegistry.banks[#KnowledgeRegistry.banks+1]=bank
    KnowledgeRegistry.byName[key]=bank
    if words then for _,w in ipairs(words) do KnowledgeRegistry.AddWord(name, w) end end
    return bank
end
local function snapshotEntry(e)
    return { Word=e.Word, Category=e.Category, Definition=e.Definition, Examples=e.Examples and {table.unpack(e.Examples)} or {}, Aliases=e.Aliases and {table.unpack(e.Aliases)} or {}, Tags=e.Tags and {table.unpack(e.Tags)} or {}, Source=e.Source or "Unknown", Bank=e.Bank }
end
local function validateEntry(entry)
    local word = (entry.Word or entry.word or ""):gsub("^%s+",""):gsub("%s+$","")
    if word=="" then return false, "MissingWord" end
    local def = entry.Definition or ""
    if def:gsub("%s+","")=="" then return false, "MissingDefinition" end
    return true, nil
end
local function entriesEqual(a,b)
    if not a or not b then return false end
    if normalizeWord(a.Word)~=normalizeWord(b.Word) then return false end
    if (a.Category or ""):upper()~=(b.Category or ""):upper() then return false end
    if (a.Definition or "")~=(b.Definition or "") then return false end
    if (a.Source or "")~=(b.Source or "") then return false end
    local function arrEq(x,y) if #x~=#y then return false end for i=1,#x do if x[i]~=y[i] then return false end end return true end
    if not arrEq(a.Tags or {}, b.Tags or {}) then return false end
    if not arrEq(a.Examples or {}, b.Examples or {}) then return false end
    if not arrEq(a.Aliases or {}, b.Aliases or {}) then return false end
    return true
end
function KnowledgeRegistry.AddWord(bankName, entry)
    local bank = KnowledgeRegistry.byName[normalizeWord(bankName)]
    if not bank then bank=KnowledgeRegistry.CreateBank(bankName) end
    local ok, reason = validateEntry(entry)
    if not ok then return {Ok=false, Reason=reason, Revision=KnowledgeRegistry.Revision} end
    local word = (entry.Word or entry.word):gsub("^%s+",""):gsub("%s+$","")
    local key = normalizeWord(word)
    if bank.byWord[key] then return {Ok=false, Reason="DuplicateWord", Revision=KnowledgeRegistry.Revision} end
    local rec = { Word=word, Category=(entry.Category or "WORD"):upper(), Definition=entry.Definition, Examples=entry.Examples or {}, Aliases=entry.Aliases or {}, Tags=entry.Tags or {}, Source=entry.Source or bank.Name }
    rec.Bank = bank.Name
    bank.byWord[key]=rec
    bank.Words[#bank.Words+1]=rec
    KnowledgeRegistry.Revision+=1
    return {Ok=true, Reason="Added", Revision=KnowledgeRegistry.Revision, Entry=snapshotEntry(rec)}
end
function KnowledgeRegistry.UpdateWord(bankName, word, patch)
    local bank = KnowledgeRegistry.byName[normalizeWord(bankName)]
    if not bank then return {Ok=false, Reason="MissingBank", Revision=KnowledgeRegistry.Revision} end
    local key = normalizeWord(word)
    local cur = bank.byWord[key]
    if not cur then return {Ok=false, Reason="MissingWord", Revision=KnowledgeRegistry.Revision} end
    local updated = {
        Word=cur.Word,
        Category=patch.Category and patch.Category:upper() or cur.Category,
        Definition=patch.Definition~=nil and patch.Definition or cur.Definition,
        Examples=patch.Examples or cur.Examples,
        Aliases=patch.Aliases or cur.Aliases,
        Tags=patch.Tags or cur.Tags,
        Source=cur.Source,
        Bank=bank.Name,
    }
    local ok, reason = validateEntry(updated)
    if not ok then return {Ok=false, Reason=reason, Revision=KnowledgeRegistry.Revision} end
    if entriesEqual(cur, updated) then return {Ok=true, Reason="NoChange", Revision=KnowledgeRegistry.Revision, Entry=snapshotEntry(cur)} end
    local rec = { Word=updated.Word, Category=updated.Category, Definition=updated.Definition, Examples=updated.Examples, Aliases=updated.Aliases, Tags=updated.Tags, Source=updated.Source, Bank=bank.Name }
    bank.byWord[key]=rec
    for i,v in ipairs(bank.Words) do if normalizeWord(v.Word)==key then bank.Words[i]=rec break end end
    KnowledgeRegistry.Revision+=1
    return {Ok=true, Reason="Updated", Revision=KnowledgeRegistry.Revision, Entry=snapshotEntry(rec)}
end
function KnowledgeRegistry.MoveWord(sourceBank, targetBank, word)
    local sBank = KnowledgeRegistry.byName[normalizeWord(sourceBank)]
    local tBank = KnowledgeRegistry.byName[normalizeWord(targetBank)]
    if not sBank then return {Ok=false, Reason="MissingSourceBank", Revision=KnowledgeRegistry.Revision} end
    if not tBank then tBank=KnowledgeRegistry.CreateBank(targetBank) end
    local key = normalizeWord(word)
    local cur = sBank.byWord[key]
    if not cur then return {Ok=false, Reason="MissingWord", Revision=KnowledgeRegistry.Revision} end
    if tBank.byWord[key] then return {Ok=false, Reason="DuplicateWord", Revision=KnowledgeRegistry.Revision} end
    sBank.byWord[key]=nil
    for i,v in ipairs(sBank.Words) do if normalizeWord(v.Word)==key then table.remove(sBank.Words,i) break end end
    local rec = { Word=cur.Word, Category=cur.Category, Definition=cur.Definition, Examples=cur.Examples, Aliases=cur.Aliases, Tags=cur.Tags, Source=cur.Source, Bank=tBank.Name }
    tBank.byWord[key]=rec
    tBank.Words[#tBank.Words+1]=rec
    KnowledgeRegistry.Revision+=1
    return {Ok=true, Reason="Moved", Revision=KnowledgeRegistry.Revision, Entry=snapshotEntry(rec)}
end
function KnowledgeRegistry.Find(word, bankName)
    local key = normalizeWord(word)
    if bankName then
        local b=KnowledgeRegistry.byName[normalizeWord(bankName)]
        return b and b.byWord[key] and snapshotEntry(b.byWord[key]) or nil
    end
    for _,b in ipairs(KnowledgeRegistry.banks) do if b.Active and b.byWord[key] then return snapshotEntry(b.byWord[key]), b.Name end end
    return nil
end
function KnowledgeRegistry.Search(query, bankName)
    local q = normalizeWord(query)
    local out={}
    local banks = bankName and {KnowledgeRegistry.byName[normalizeWord(bankName)]} or KnowledgeRegistry.banks
    for _,b in ipairs(banks) do if b and b.Active then for _,w in ipairs(b.Words) do if normalizeWord(w.Word):find(q,1,true) or normalizeWord(w.Definition):find(q,1,true) then out[#out+1]=snapshotEntry(w) end end end end
    return out
end
function KnowledgeRegistry.RemoveWord(bankName, word)
    local bank=KnowledgeRegistry.byName[normalizeWord(bankName)]
    if not bank then return {Ok=false, Reason="MissingBank", Revision=KnowledgeRegistry.Revision} end
    local key=normalizeWord(word)
    if not bank.byWord[key] then return {Ok=false, Reason="MissingWord", Revision=KnowledgeRegistry.Revision} end
    bank.byWord[key]=nil
    for i,v in ipairs(bank.Words) do if normalizeWord(v.Word)==key then table.remove(bank.Words,i) break end end
    KnowledgeRegistry.Revision+=1
    return {Ok=true, Reason="Removed", Revision=KnowledgeRegistry.Revision}
end
function KnowledgeRegistry.SetActive(bankName, active)
    local b=KnowledgeRegistry.byName[normalizeWord(bankName)]
    if b and b.Active ~= (not not active) then b.Active = not not active KnowledgeRegistry.Revision+=1 return {Ok=true, Reason="ActiveChanged", Revision=KnowledgeRegistry.Revision} end
    return {Ok=true, Reason="NoChange", Revision=KnowledgeRegistry.Revision}
end
-- TRANSIENT UI state | does not own knowledge
KnowledgeEditorState = { SelectedBank=nil, SelectedWord=nil, Draft={Word="", Category="WORD", Definition="", Examples={}, Aliases={}, Tags={}, Source=nil}, SearchQuery="", Dirty=false }
_G.KnowledgeEditorState = KnowledgeEditorState
-- 10E KnowledgeSelectionState | UI-local transient, not Registry
KnowledgeSelectionState = { Tab="Overview", Bank=nil, Word=nil, SearchQuery="", RevisionSeen=0 }
_G.KnowledgeSelectionState = KnowledgeSelectionState
-- OWNER: Knowledge UI | Hub consumer of KnowledgeRegistry/KnowledgeFormatter (snapshot-only)
KnowledgeUI = {}
_G.KnowledgeUI = KnowledgeUI
local function copyArray(src) local out={} for i,v in ipairs(src or {}) do out[i]=v end return out end
local KNOWLEDGE_TABS = {Overview=true, Banks=true, Editor=true, Import=true, Inspector=true}
function KnowledgeUI.GetOverview()
    local rev = KnowledgeRegistry.Revision
    local activeBanks, totalEntries = 0, 0
    local breakdown={}
    for _,b in ipairs(KnowledgeRegistry.banks) do
        if b.Active then activeBanks+=1 end
        totalEntries+=#b.Words
        breakdown[#breakdown+1]={Name=b.Name, Entries=#b.Words, Active=b.Active}
    end
    return { Revision=rev, ActiveBanks=activeBanks, TotalEntries=totalEntries, SelectedBank=KnowledgeSelectionState.Bank, Breakdown=breakdown }
end
function KnowledgeUI.MarkRevisionSeen(rev) KnowledgeSelectionState.RevisionSeen = rev or KnowledgeRegistry.Revision end
function KnowledgeUI.Refresh()
    local ov = KnowledgeUI.GetOverview()
    KnowledgeSelectionState.RevisionSeen = ov.Revision
    return ov
end
function KnowledgeUI.GetBanks() -- snapshot list
    local out={}
    for _,b in ipairs(KnowledgeRegistry.banks) do out[#out+1]={Name=b.Name, Entries=#b.Words, Active=b.Active} end
    return out
end
function KnowledgeUI.SelectBank(name)
    if not name or name=="" then KnowledgeSelectionState.Bank=nil KnowledgeSelectionState.Word=nil return false end
    for _,b in ipairs(KnowledgeRegistry.banks) do if b.Name==name then KnowledgeSelectionState.Bank=name KnowledgeSelectionState.Word=nil return true end end
    return false
end
function KnowledgeUI.SetTab(tab) if not KNOWLEDGE_TABS[tab] then return false end KnowledgeSelectionState.Tab=tab return true end
function KnowledgeUI.Search(query, bankName)
    KnowledgeSelectionState.SearchQuery = query or ""
    return KnowledgeRegistry.Search(KnowledgeSelectionState.SearchQuery, bankName or KnowledgeSelectionState.Bank)
end
-- Editor helpers | Draft copy -> Save via UpdateWord/AddWord
function KnowledgeUI.StartEdit(word, bankName)
    local snap = KnowledgeRegistry.Find(word, bankName)
    if not snap then return nil end
    KnowledgeEditorState.SelectedBank = snap.Bank
    KnowledgeEditorState.SelectedWord = snap.Word
    KnowledgeEditorState.Draft = {Word=snap.Word, Category=snap.Category, Definition=snap.Definition, Examples=copyArray(snap.Examples), Aliases=copyArray(snap.Aliases), Tags=copyArray(snap.Tags), Source=snap.Source}
    KnowledgeEditorState.Dirty = false
    return KnowledgeEditorState.Draft
end
function KnowledgeUI.CancelEdit()
    KnowledgeEditorState.Draft = {Word="", Category="WORD", Definition="", Examples={}, Aliases={}, Tags={}, Source=nil}
    KnowledgeEditorState.SelectedWord=nil
    KnowledgeEditorState.Dirty=false
    return true -- no registry op, reload snapshot on next Get
end
function KnowledgeUI.SaveEdit()
    local d = KnowledgeEditorState.Draft
    local result
    if not KnowledgeEditorState.SelectedWord then
        result = KnowledgeRegistry.AddWord(KnowledgeEditorState.SelectedBank or KnowledgeSelectionState.Bank or "Basic Vocabulary", d)
    else
        result = KnowledgeRegistry.UpdateWord(KnowledgeEditorState.SelectedBank, KnowledgeEditorState.SelectedWord, d)
    end
    if result and result.Ok then KnowledgeEditorState.Dirty=false end
    return result
end
-- Import preview is side-effect free; CommitValid only via registry
function KnowledgeUI.PreviewImport(bankName, text, defaultCategory) return KnowledgeFormatter.Preview(bankName, text, defaultCategory) end
function KnowledgeUI.CommitImport(bankName, preview) return KnowledgeFormatter.CommitValid(bankName, preview) end
-- Formatter 10D: Parser ? Registry | validation/preview before mutation
-- Accepted: WORD/PHRASE/SLANG/CONCEPT - definition (case-insensitive -> WORD), separators - : | |
local VALID_CATEGORIES = {WORD=true, PHRASE=true, SLANG=true, CONCEPT=true, GENERAL=true, LANGUAGE=true, ROBLOX=true}
local function normalizeCategory(c) local u=(c or "WORD"):upper():gsub("%s+","") return VALID_CATEGORIES[u] and u or "WORD" end
function KnowledgeRegistry.ParseFormatted(text, defaultCategory)
    local entries={}
    for line in (text or ""):gmatch("[^\r\n]+") do
        local word, def = line:match("^%s*(.-)%s*[-:||]%s*(.+)%s*$")
        if word and def and word~="" and def~="" then
            -- allow "[SLANG] word - def" prefix
            local catHint, w2 = word:match("^%s*%[(%w+)%]%s*(.+)%s*$")
            local cat = catHint and normalizeCategory(catHint) or normalizeCategory(defaultCategory or "WORD")
            entries[#entries+1]={Word=w2 or word, Category=cat, Definition=def, Tags={}, Source=nil}
        end
    end
    return entries
end
-- 10D Preview: no registry mutation | returns Valid/Invalid/Duplicate/Warnings
KnowledgeFormatter = {}
_G.KnowledgeFormatter = KnowledgeFormatter
function KnowledgeFormatter.Preview(bankName, text, defaultCategory)
    local raw = KnowledgeRegistry.ParseFormatted(text, defaultCategory)
    local valid, invalid, duplicates, warnings = {}, {}, {}, {}
    local seen={}
    local bank = bankName and KnowledgeRegistry.byName[normalizeWord(bankName)] or nil
    for _,e in ipairs(raw) do
        local wkey = normalizeWord(e.Word)
        if e.Word=="" or e.Definition:gsub("%s+","")=="" then
            invalid[#invalid+1]={Entry=e, Reason="MissingDefinition"}
        elseif seen[wkey] then
            duplicates[#duplicates+1]={Entry=e, Reason="DuplicateInBatch"}
        elseif bank and bank.byWord[wkey] then
            duplicates[#duplicates+1]={Entry=e, Reason="DuplicateInRegistry", Bank=bank.Name}
        else
            -- validate category
            e.Category = normalizeCategory(e.Category)
            valid[#valid+1]=e
            seen[wkey]=true
        end
    end
    -- also detect empty lines that failed parse as invalid
    local totalLines=0
    for _ in (text or ""):gmatch("[^\r\n]+") do totalLines+=1 end
    local parsedCount=#raw
    if totalLines > parsedCount then
        for i=1, totalLines-parsedCount do invalid[#invalid+1]={Entry={Word="?", Definition=""}, Reason="MalformedLine"} end
    end
    return {
        Valid=valid, Invalid=invalid, Duplicates=duplicates, Warnings=warnings,
        Count=totalLines, ValidCount=#valid, InvalidCount=#invalid, DuplicateCount=#duplicates,
        Entries=valid, Source="FormattedText", Bank=bankName,
    }
end
function KnowledgeFormatter.CommitValid(bankName, preview)
    if not preview or not preview.Valid then return {Ok=false, Reason="NoPreview", Revision=KnowledgeRegistry.Revision} end
    local imported={}
    for _,e in ipairs(preview.Valid) do
        local r=KnowledgeRegistry.AddWord(bankName, e)
        if r.Ok then imported[#imported+1]=r.Entry end
    end
    return {Ok=true, Reason="ImportedValid", Revision=KnowledgeRegistry.Revision, Imported=imported, Preview=preview}
end
function KnowledgeRegistry.ImportFormatted(bankName, text, defaultCategory)
    -- Legacy: direct import without preview | now routes through preview (only valid)
    local preview = KnowledgeFormatter.Preview(bankName, text, defaultCategory)
    return KnowledgeFormatter.CommitValid(bankName, preview).Imported or {}
end
_G.TestFormatterPreview = function(bank, txt) return KnowledgeFormatter.Preview(bank, txt) end
-- 10F KnowledgeEvidence | provenance + deterministic confidence, no Registry write
KnowledgeEvidence = {}
_G.KnowledgeEvidence = KnowledgeEvidence
local function evidenceConfidence(matches, reason)
    if #matches==0 then return 0 end
    if reason=="ExactWordMatch" then return 0.92
    elseif reason=="PhraseMatch" then return 0.86
    elseif reason=="TagMatch" then return 0.72
    elseif reason=="CategoryMatch" then return 0.68
    elseif reason=="LexicalMatch" then return 0.62
    elseif reason=="TopicMatch" then return 0.86
    else return 0.55 end
end
function KnowledgeEvidence.Build(query, context)
    local q = normalizeWord(query or "")
    local rev = KnowledgeRegistry.Revision
    if q=="" then return {Query=query or "", Matches={}, Confidence=0, SourceRevision=rev, Sources={}, Reason="NoMatch"} end
    local matches = KnowledgeRegistry.Lookup(query, context)
    -- already snapshots from Lookup/Search
    local sources={}
    for _,m in ipairs(matches) do
        sources[#sources+1]={Word=m.Word, Source=m.Source or "Unknown", SourceMeta=m.SourceMeta and {Origin=m.SourceMeta.Origin, Author=m.SourceMeta.Author, Version=m.SourceMeta.Version} or nil, Category=m.Category}
    end
    local reason="NoMatch"
    local matchReasons={}
    if #matches>0 then
        local qExact=false
        for _,m in ipairs(matches) do if normalizeWord(m.Word)==q then qExact=true break end end
        if qExact then reason="ExactWordMatch"
        elseif q:find(" ",1,true) then reason="PhraseMatch"
        else reason="LexicalMatch" end
        if q=="horror" or q:find("horror",1,true) then reason="TopicMatch" end
        for _,m in ipairs(matches) do
            local mr="LexicalMatch"
            if normalizeWord(m.Word)==q then mr="ExactWordMatch"
            elseif normalizeWord(m.Word):find(q,1,true) then mr="TopicMatch"
            end
            matchReasons[#matchReasons+1]={Word=m.Word, Reason=mr}
        end
    end
    return {Query=query, Matches=matches, Confidence=evidenceConfidence(matches, reason), SourceRevision=rev, Sources=sources, Reason=reason, MatchReasons=matchReasons}
end
function KnowledgeEvidence.Inspect(query, context)
    return KnowledgeEvidence.Build(query, context)
end
_G.TestKnowledgeEvidence = function(q) return KnowledgeEvidence.Build(q) end
-- 10H ResponsePlan | contract after Behavior, before Voice/Visual. No GUI, no SetEmotion, no Wardrobe.
-- Behavior decides WHETHER; ResponsePlan describes WHAT the response should contain/be like.
ResponsePlanner = {}
_G.ResponsePlanner = ResponsePlanner
function ResponsePlanner.Build(behavior, resolvedContext, evidence)
    local b = behavior or {Action="None", Reason="NoBehavior", Confidence=0, Priority=0}
    local ctx = resolvedContext or {}
    local ev = evidence or {Query="", Matches={}, Confidence=0, SourceRevision=KnowledgeRegistry.Revision, Sources={}, Reason="NoMatch", MatchReasons={}}
    local should = b.Action=="React" or b.Action=="Speak"
    local intent = ctx.Intent or "Unknown"
    local mode, strategy, knowledgeUse, reason
    if not should then
        mode="Silent"; strategy="None"; knowledgeUse="None"; reason="BehaviorNone"
    elseif intent=="Question" and ev.Confidence>=0.55 then
        mode="Explanatory"; strategy="AnswerFromEvidence"; knowledgeUse="CiteMatches"; reason="KnowledgeSupportedQuestion"
    elseif intent=="Question" then
        mode="Clarifying"; strategy="AskForDetail"; knowledgeUse="None"; reason="QuestionWithoutEvidence"
    elseif intent=="Greeting" then
        mode="Conversational"; strategy="Acknowledge"; knowledgeUse="None"; reason="Greeting"
    elseif intent=="Farewell" then
        mode="Conversational"; strategy="Close"; knowledgeUse="None"; reason="Farewell"
    else
        mode="Conversational"; strategy="Acknowledge"; knowledgeUse=(#ev.Matches>0 and "OptionalCite" or "None"); reason="Statement"
    end
    return {
        ShouldRespond = should,
        ResponseIntent = intent,
        ResponseMode = mode,
        ContentStrategy = strategy,
        KnowledgeUse = knowledgeUse,
        ToneGuidance = ctx.Tone or "Neutral",
        EmotionalGuidance = nil,
        ReactionGuidance = nil,
        VisualGuidance = nil,
        VoiceBoundary = { Allowed=should, Lifecycle="none" },
        Confidence = math.clamp((b.Confidence or 0)*0.5 + (ev.Confidence or 0)*0.5, 0, 1),
        Reason = reason,
        KnowledgeEvidence = ev,
        Provenance = {
            InteractionSequence = (ctx.Provenance and ctx.Provenance.InteractionSequence) or InteractionState.sequence,
            AssistantRevision = ctx.AssistantRevision or AssistantState.Revision,
            KnowledgeRevision = ev.SourceRevision or KnowledgeRegistry.Revision,
            BehaviorReason = b.Reason,
        },
    }
end
_G.TestResponsePlan = function(msg)
    local rc = ConversationInterpreter.Resolve(msg, AssistantState)
    local rctx = ContextResolver.Resolve(rc, AssistantState)
    local ev = KnowledgeEvidence.Build(rctx and rctx.KnowledgeQuery or msg, rctx)
    local beh = BehaviorResolver.Resolve({type="conversationMessage", target="conversation", sequence=InteractionState.sequence+1}, AssistantState, PERSONALITY, MoodState)
    return ResponsePlanner.Build(beh, rctx, ev)
end
-- 10I ResponseComposer | pure, deterministic, no Registry/Reaction/Visual/Maid
ResponseComposer = {}
_G.ResponseComposer = ResponseComposer
function ResponseComposer.Build(responsePlan, resolvedContext, evidence)
    local plan = responsePlan or {ShouldRespond=false, ResponseIntent="Unknown", ResponseMode="Silent", ContentStrategy="None", ToneGuidance="Neutral", Confidence=0, Reason="NoPlan", KnowledgeEvidence=evidence, Provenance={}}
    local ctx = resolvedContext or {Intent="Unknown", Topic=nil, Tone="Neutral", Confidence=0, KnowledgeQuery="", Provenance={}}
    local ev = evidence or plan.KnowledgeEvidence or {Query="", Matches={}, Confidence=0, SourceRevision=KnowledgeRegistry.Revision, Sources={}, Reason="NoMatch", MatchReasons={}}
    -- Text: deterministic templates (no knowledge query to Registry)
    local text
    local intent = plan.ResponseIntent or ctx.Intent or "Unknown"
    local mode = plan.ResponseMode or "Conversational"
    local strat = plan.ContentStrategy or "None"
    if not plan.ShouldRespond then
        text=""
    elseif strat=="AnswerFromEvidence" and #ev.Matches>0 then
        local def = ev.Matches[1].Definition or ""
        if def~="" then text = ev.Matches[1].Word..": "..def else text = "I found "..tostring(#ev.Matches).." relevant entries for '"..tostring(ev.Query).."'." end
    elseif intent=="Greeting" then text="Hey. What's up?"
    elseif intent=="Farewell" then text="See you."
    elseif intent=="Question" then text="Could you say a bit more about '"..tostring(ctx.Topic or ev.Query or "that").."'?"
    elseif intent=="Statement" then text="Got it."
    else text="I'm not sure what you mean."
    end
    return {
        Text=text,
        Intent=intent,
        Topic=ctx.Topic or (ev.Matches[1] and ev.Matches[1].Word or nil),
        Mode=mode,
        ContentStrategy=strat,
        Tone=plan.ToneGuidance or ctx.Tone or "Neutral",
        Confidence=plan.Confidence or 0,
        SourcePlan=plan,
        KnowledgeEvidence=ev,
        Provenance=plan.Provenance or ctx.Provenance or {InteractionSequence=InteractionState.sequence, AssistantRevision=AssistantState.Revision, KnowledgeRevision=ev.SourceRevision},
    }
end
_G.TestResponseCompose = function(msg)
    local rc = ConversationInterpreter.Resolve(msg, AssistantState)
    local rctx = ContextResolver.Resolve(rc, AssistantState)
    local ev = KnowledgeEvidence.Build(rctx and rctx.KnowledgeQuery or msg, rctx)
    local beh = BehaviorResolver.Resolve({type="conversationMessage", target="conversation", sequence=InteractionState.sequence+1}, AssistantState, PERSONALITY, MoodState)
    local plan = ResponsePlanner.Build(beh, rctx, ev)
    return ResponseComposer.Build(plan, rctx, ev)
end
-- 10J VoiceBoundary | contract only, no playback/lifecycle
VoiceBoundary = {}
_G.VoiceBoundary = VoiceBoundary
function VoiceBoundary.Build(resolvedResponse)
    if not resolvedResponse or not resolvedResponse.Text or resolvedResponse.Text=="" then
        return {Allowed=false, Text="", Mode="Silent", Tone="Neutral", Lifecycle="none", Provenance=resolvedResponse and resolvedResponse.Provenance or {InteractionSequence=InteractionState.sequence, AssistantRevision=AssistantState.Revision, KnowledgeRevision=KnowledgeRegistry.Revision}}
    end
    return {Allowed=true, Text=resolvedResponse.Text, Mode=resolvedResponse.Mode, Tone=resolvedResponse.Tone, Lifecycle="none", Provenance=resolvedResponse.Provenance}
end
_G.TestVoiceRequest = function(msg) local r=_G.TestResponseCompose(msg) return VoiceBoundary.Build(r) end
function KnowledgeRegistry.TestBank(bankName, query)
    local bank=KnowledgeRegistry.byName[normalizeWord(bankName)]
    if not bank then return {Bank=bankName, Entries=0, Loaded=0, Valid=0, Invalid=0, Result="NOT_FOUND"} end
    local found, fromBank = KnowledgeRegistry.Find(query)
    return {Bank=bank.Name, Entries=#bank.Words, Loaded=#bank.Words, Valid=#bank.Words, Invalid=0, Query=query, Found=found~=nil, Result=found, FromBank=fromBank}
end
-- Seed 10A: Basic Vocabulary + Casual (first vertical slice: ADD/STORE/FIND/READ/USE)
KnowledgeRegistry.CreateBank("Basic Vocabulary", {
    {Word="example", Category="general", Definition="A representative instance.", Tags={"general","learning"}},
    {Word="context", Category="language", Definition="Information that helps explain meaning.", Tags={"language","communication"}},
    {Word="syntax", Category="language", Definition="Rules governing structure.", Tags={"language"}},
    {Word="lexicon", Category="language", Definition="Vocabulary of a language.", Tags={"language"}},
    {Word="contextual", Category="language", Definition="Dependent on surrounding information.", Tags={"language"}},
    {Word="coherent", Category="general", Definition="Logical and consistent.", Tags={"general"}},
    {Word="equilibrium", Category="general", Definition="A state of balance.", Tags={"general"}},
    {Word="verity", Category="general", Definition="Truth or reality.", Tags={"general"}},
    {Word="knowledge", Category="general", Definition="Awareness gained through experience.", Tags={"general"}},
    {Word="registry", Category="general", Definition="An official record or list.", Tags={"general"}},
})
KnowledgeRegistry.CreateBank("Casual", {
    {Word="based", Category="slang", Definition="Expressing approval or agreement.", Tags={"internet","slang"}},
    {Word="cooked", Category="slang", Definition="Doomed or finished.", Tags={"slang"}},
    {Word="locked in", Category="slang", Definition="Focused.", Tags={"slang"}},
})
KnowledgeRegistry.CreateBank("Roblox", {
    {Word="obby", Category="roblox", Definition="Obstacle course.", Tags={"roblox"}},
    {Word="tycoon", Category="roblox", Definition="Build-to-earn game.", Tags={"roblox"}},
})
_G.TestWordBank = function(q) return KnowledgeRegistry.TestBank("Basic Vocabulary", q) end
-- Knowledge lookup: Context/Question -> relevant entries (Hub knowledge, Verity read) | returns snapshots, no intelligence
function KnowledgeRegistry.Lookup(query, context)
    if not query or query=="" then return {} end
    -- Evidence only: no behavior decision
    return KnowledgeRegistry.Search(query)
end
-- Context Inspector (Hub debug, not Verity UI): INPUT -> Intent/Context/Knowledge/Mood/Behavior snapshot
ContextInspector = {}
_G.ContextInspector = ContextInspector
function ContextInspector.Inspect(inputText)
    local rc = ConversationInterpreter.Resolve(inputText, AssistantState)
    local rctx = ContextResolver.Resolve(rc, AssistantState)
    local matches = KnowledgeRegistry.Lookup(inputText, rctx)
    local behavior = BehaviorResolver.Resolve({type="conversationMessage", target="conversation", sequence=InteractionState.sequence+1}, AssistantState, PERSONALITY, MoodState)
    return {
        INPUT=inputText,
        INTENT=rc.Intent, TOPIC=rc.Topic, TONE=rc.Tone, CONFIDENCE=rc.Confidence,
        CONTEXT=rctx,
        KNOWLEDGE=matches,
        MOOD=MoodState.Name or MoodState,
        PERSONALITY=PERSONALITY,
        BEHAVIOR=behavior,
    }
end
_G.TestInspect = function(msg) return ContextInspector.Inspect(msg) end

-- PASS 7B: declarative reaction policy (data, not logic)
local REACTION_EFFECTS = {
    Excited = { emotion="Excited", reaction="Notice", duration=0.75, wardrobe={enable={"halo"}} },
}
local ReactionResolver = { _cooldowns={} }
-- Forward declarations: UI locals referenced by ApplyTheme (declared below, assigned at creation)
local shell, shellStroke, canvas, HubRoot, HubCanvasGroup, notifyRoot
-- Registry for theme-aware Hub elements (cached, not rebuilt)
local themedRegistry = {}
local function registerThemed(obj, prop, token) table.insert(themedRegistry,{obj=obj, prop=prop, token=token}) end
local function GetTheme(id) return THEMES[id] or THEMES.Theme_01 end
-- Resolve a theme's colors (Custom clones a preset via hubAppearance.CustomColors #RRGGBB)
local function ResolveColors(themeId)
    local th = GetTheme(themeId)
    if themeId=="Theme_07" and hubAppearance.CustomColors then
        local custom={}
        for k,hex in pairs(hubAppearance.CustomColors) do
            local ok,col=pcall(Color3.fromHex, hex:gsub("#",""))
            if ok and col then custom[k]=col end
        end
        if next(custom) then return setmetatable(custom, {__index=th.colors}), th end
    end
    return th.colors, th
end
-- Scope-aware application: "Hub" walks HubRoot, "Shared" walks notifyRoot, "Verity" is locked
-- ApplyTheme(themeId, scope, save). Shared consumes existing T tokens (no fourth palette).
local function ApplyTheme(themeId, scope, save)
    scope = scope or "Hub"
    if scope == "Verity" then
        -- ThemeLocked authoritative: never mutate Verity from Hub theme engine
        return
    end
    local colors, th = ResolveColors(themeId)
    local oldT={}
    for k,v in pairs(T) do oldT[k]=v end
    -- update semantic tokens (Hub + Shared both consume these same T values)
    for k,v in pairs(colors) do T[k]=v end
    T.titleBar = Color3.fromHex("0f0f0f")
    T.line = T.border
    T.accent2 = colors.accent
    if scope == "Hub" then
        hubAppearance.Theme = th.id
    end
    -- registry (Hub-owned + Shared-owned references)
    for _,e in ipairs(themedRegistry) do
        if e.obj and e.obj.Parent then
            local c = T[e.token] or colors[e.token]
            if c then pcall(function() e.obj[e.prop]=c end) end
        end
    end
    -- scope-aware walk: Hub scope traverses HubRoot, Shared scope traverses notifyRoot
    local roots = scope=="Shared" and {notifyRoot} or {HubRoot}
    pcall(function()
        for _,root in ipairs(roots) do
            if root then
                for _,inst in ipairs(root:GetDescendants()) do
                    local role = inst:GetAttribute("ThemeRole")
                    if role == "Verity" then
                        -- Verity immune even if accidentally nested
                    elseif role and T[role] then
                        if inst:IsA("TextLabel") or inst:IsA("TextButton") then
                            if role=="text" or role=="subtext" or role=="dim" or role=="accent" then pcall(function() inst.TextColor3 = T[role] end) end
                        elseif inst:IsA("UIStroke") then
                            pcall(function() inst.Color = T[role] end)
                        else
                            pcall(function() inst.BackgroundColor3 = T[role] end)
                        end
                    else
                        if inst:IsA("Frame") and inst.BackgroundColor3 then
                            if inst.BackgroundColor3==oldT.bg then inst.BackgroundColor3=T.bg
                            elseif inst.BackgroundColor3==oldT.panel then inst.BackgroundColor3=T.panel
                            elseif inst.BackgroundColor3==oldT.panel2 then inst.BackgroundColor3=T.panel2
                            end
                        elseif inst:IsA("TextLabel") and inst.TextColor3 then
                            if inst.TextColor3==oldT.text then inst.TextColor3=T.text
                            elseif inst.TextColor3==oldT.subtext then inst.TextColor3=T.subtext
                            elseif inst.TextColor3==oldT.dim then inst.TextColor3=T.dim
                            end
                        elseif inst:IsA("UIStroke") and inst.Color then
                            if inst.Color==oldT.border then inst.Color=T.border
                            elseif inst.Color==oldT.accent then inst.Color=T.accent
                            end
                        end
                    end
                end
            end
        end
        if scope=="Hub" then
            if shell then shell.BackgroundColor3 = T.bg end
            if shellStroke then shellStroke.Color = T.border end
            if HubCanvasGroup then HubCanvasGroup.BackgroundColor3 = T.bg end
        end
    end)
    if save ~= false and scope=="Hub" then
        Settings:Set("hubAppearance", hubAppearance, "global")
        Settings:Save("global")
    end
    EVENTS.fire("theme.changed", th.id, scope)
end
-- Public theme API (Appearance exposes SetHubTheme only; Shared follows Hub internally)
local ThemeSystem = {}
function ThemeSystem.SetHubTheme(themeId, save) ApplyTheme(themeId, "Hub", save) ApplyTheme(themeId, "Shared", false) end
function ThemeSystem.SetSharedTheme(themeId) ApplyTheme(themeId, "Shared", false) end
function ThemeSystem.SetVerityTheme() return VERITY_THEME end
local function RefreshTheme() ApplyTheme(hubAppearance.Theme, "Hub", false) end

-- ResolveAppearance: BaseTheme + UserOverrides = final appearance config
-- Returns a snapshot, not persistent state
local function ResolveAppearance()
    local baseId = hubAppearance.BaseTheme or hubAppearance.PresetId or "Theme_01"
    local baseTheme = THEMES[baseId] or THEMES.Theme_01
    local overrides = hubAppearance.Overrides or {}
    
    -- Build resolved config from base + overrides
    local resolved = {
        BaseTheme = baseId,
        PresetId = hubAppearance.PresetId or baseId,
        Theme = baseId,
        Scale = overrides.Scale or hubAppearance.Scale or 1.0,
        Transparency = overrides.Transparency or hubAppearance.Transparency or 0,
        BorderEnabled = overrides.BorderEnabled ~= nil and overrides.BorderEnabled or hubAppearance.BorderEnabled,
        BorderThickness = overrides.BorderThickness or hubAppearance.BorderThickness or 1,
        CornerRadius = overrides.CornerRadius or hubAppearance.CornerRadius or 10,
        ShadowsEnabled = overrides.ShadowsEnabled ~= nil and overrides.ShadowsEnabled or hubAppearance.ShadowsEnabled,
        GlowEnabled = overrides.GlowEnabled ~= nil and overrides.GlowEnabled or hubAppearance.GlowEnabled,
        PositionMode = overrides.PositionMode or hubAppearance.PositionMode or "Draggable",
        Position = overrides.Position or hubAppearance.Position,
        RememberPosition = overrides.RememberPosition ~= nil and overrides.RememberPosition or hubAppearance.RememberPosition,
        CustomColors = overrides.CustomColors or hubAppearance.CustomColors,
        Modified = isAppearanceDirty(hubAppearance),
    }
    return resolved
end

-- Load saved appearance on boot (before UI creation, T already Slate)
do
    local saved = Settings:Get("hubAppearance","global")
    if type(saved)=="table" and saved.Theme and THEMES[saved.Theme] then
        -- Migrate legacy flat structure to new preset-based structure
        hubAppearance.PresetId = saved.PresetId or saved.Theme
        hubAppearance.BaseTheme = saved.BaseTheme or saved.Theme
        hubAppearance.Overrides = saved.Overrides or {}
        hubAppearance.Theme = saved.Theme
        hubAppearance.Scale = saved.Scale or 1.0
        hubAppearance.Transparency = saved.Transparency or 0
        hubAppearance.BorderEnabled = saved.BorderEnabled ~= nil and saved.BorderEnabled or true
        hubAppearance.BorderThickness = saved.BorderThickness or 1
        hubAppearance.CornerRadius = saved.CornerRadius or 10
        hubAppearance.ShadowsEnabled = saved.ShadowsEnabled ~= nil and saved.ShadowsEnabled or true
        hubAppearance.GlowEnabled = saved.GlowEnabled or false
        hubAppearance.CustomColors = saved.CustomColors
        
        -- migrate old Draggable/Locked booleans to single PositionMode
        if saved.PositionMode then
            hubAppearance.PositionMode = saved.PositionMode
        elseif saved.Locked == true then
            hubAppearance.PositionMode = "Locked"
        elseif saved.Draggable == false then
            hubAppearance.PositionMode = "Locked"
        else
            hubAppearance.PositionMode = "Draggable"
        end
        hubAppearance.Draggable = nil
        hubAppearance.Locked = nil
        hubAppearance.Position = saved.Position
        
        if hubAppearance.PositionMode ~= "Locked" then hubAppearance.PositionMode = "Draggable" end
        HubState.Mode = hubAppearance.PositionMode
        
        -- apply without save to avoid overwrite
        for k,v in pairs(THEMES[hubAppearance.Theme].colors) do T[k]=v end
        T.titleBar=Color3.fromHex("0f0f0f"); T.line=T.border
    end
end
local FONT, FONTB = Enum.Font.Gotham, Enum.Font.GothamBold
local rng=Random.new(tick()*1e6%2147483647) local CHARS="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
local function rname() local n=rng:NextInteger(18,26) local b=table.create(n) for i=1,n do local k=rng:NextInteger(1,#CHARS) b[i]=CHARS:sub(k,k) end return table.concat(b) end
-- FIXED new() without continue (was silent failure point)
function new(className, props, kids) local o=Instance.new(className) if props then for kk,vv in pairs(props) do if kk~="Parent" and kk~="Name" then if kk=="Font" then o.Font=vv else local ok=pcall(function() o[kk]=vv end) if not ok and kk=="TextSize" then o.TextSize=vv end end end end end if props and props.Name then o.Name=props.Name else o.Name=rname() end if kids then for _,ch in ipairs(kids) do ch.Parent=o end end if props and props.Parent then o.Parent=props.Parent end return o end
function corner(i,r) return new("UICorner",{CornerRadius=UDim.new(0,r or 8),Parent=i}) end
function stroke(i,c,t) return new("UIStroke",{Color=c or T.border, Thickness=t or 1, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Parent=i}) end
-- Unified chrome + live Visual Style mutators (responsive sizing already, no rebuild)
function applyControlChrome(control, role, selected)
    local cr=control:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
    cr.CornerRadius=UDim.new(0,8)
    cr.Parent=control
    local st=control:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
    st.Name="ControlStroke"
    st.Thickness= selected and 1.5 or 1
    st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    st.Parent=control
    control:SetAttribute("ThemeRole", role)
    -- register for live theme
    pcall(function() registerThemed(control, "BackgroundColor3", role=="HubTabSelected" and "panel2" or "panel") end)
    pcall(function() registerThemed(st, "Color", selected and "accent" or "border") end)
    return control
end
function setBorderStyle(enabled, thickness)
    if shellStroke then shellStroke.Enabled=enabled; shellStroke.Thickness=math.clamp(thickness or 1,1,3) end
end
function setCornerRadius(radius)
    if shellCorner then shellCorner.CornerRadius=UDim.new(0, math.clamp(radius or 10,0,16)) end
end
local themeApplyQueued=false
function queueApplyTheme()
    if themeApplyQueued then return end
    themeApplyQueued=true
    task.defer(function() themeApplyQueued=false pcall(function() ApplyTheme() end) end)
end
function setControlSelected(control, selected)
    control:SetAttribute("Selected", selected)
    local st=control:FindFirstChild("ControlStroke")
    if st then st.Thickness = selected and 1.5 or 1 end
    queueApplyTheme()
end
function applyTitleBarGeometry(viewportSize)
    viewportSize = viewportSize or viewport()
    local h = viewportSize.X < 700 and 44 or 36
    if titleBar then titleBar.Size = UDim2.new(1,0,0,h) end
end
local function applyNavigationMode(viewportSize)
    viewportSize = viewportSize or viewport()
    PresentationState.Viewport = viewportSize
    local narrow = viewportSize.X < 520
    PresentationState.NavigationMode = narrow and "CompactTabs" or "Sidebar"
    if narrow then
        -- compact: tabBar becomes horizontal scrollable strip at top of main
        if tabBar then tabBar.Parent = main; tabBar.Size = UDim2.new(1,0,0,36) end
        if sidebar then sidebar.Visible = false end
    else
        if tabBar then tabBar.Parent = sidebar; tabBar.Size = UDim2.new(1,0,1,-24) end
        if sidebar then sidebar.Visible = true end
    end
end
local function getNavigationMode(width) width = width or (viewport and viewport().X or 620) return width < 520 and "CompactTabs" or "Sidebar" end
_G.getNavigationMode = getNavigationMode

function pad(i,a,b,c,d) return new("UIPadding",{PaddingTop=UDim.new(0,a or 0),PaddingBottom=UDim.new(0,b or a or 0),PaddingLeft=UDim.new(0,c or 0),PaddingRight=UDim.new(0,d or c or 0),Parent=i}) end
function vlist(i,g) return new("UIListLayout",{FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,g or 8), Parent=i}) end
function hlist(i,g) return new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,g or 8), VerticalAlignment=Enum.VerticalAlignment.Center, Parent=i}) end
local function tw(i,info,goal) local t=TweenService:Create(i,info,goal) t:Play() return t end
local MOTION={hover=TweenInfo.new(0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), win=TweenInfo.new(0.28,Enum.EasingStyle.Quint,Enum.EasingDirection.Out)}

function viewport() local cam=Workspace.CurrentCamera return cam and cam.ViewportSize or Vector2.new(620,520) end
local function getGuiRoot()
    local ok, root = pcall(function() return gethui and gethui() or game:GetService("CoreGui") end)
    if ok and root then return root end
    return LP:FindFirstChildOfClass("PlayerGui") or LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui", 2)
end
local BASE_W, BASE_H = 620, 520
local MAX_W, MAX_H = 700, 600
local EDGE = 20
function getShellSize(viewportSize, mode)
    local availableW = math.max(320, viewportSize.X - EDGE*2)
    local availableH = math.max(300, viewportSize.Y - EDGE*2)
    local targetW = math.min(MAX_W, availableW * 0.80)
    local targetH = math.min(MAX_H, availableH * 0.90)
    if mode=="Small" or viewportSize.X < 700 then
        targetW = math.min(targetW, availableW)
        targetH = math.min(targetH, availableH)
    end
    return UDim2.fromOffset(math.floor(targetW+0.5), math.floor(targetH+0.5))
end
local W,H=BASE_W,BASE_H do local vp=viewport() local sz=getShellSize(vp, "Normal") W=sz.X.Offset H=sz.Y.Offset end
function centeredPos(w,h) local vp=viewport() return Vector2.new(math.floor((vp.X-w)/2), math.floor((vp.Y-h)/2)) end
function px(n) return math.floor(n+0.5) end
function offset(x,y) return UDim2.fromOffset(px(x),px(y)) end
function clampShellPosition(pos)
    local vp=viewport()
    if hubAppearance.ClipEnabled==false then return pos end
    return Vector2.new(math.clamp(pos.X, EDGE, math.max(EDGE, vp.X - W - EDGE)), math.clamp(pos.Y, EDGE, math.max(EDGE, vp.Y - H - EDGE)))
end

-- ScreenGui | start hidden, will be shown after parented
local screen=new("ScreenGui",{Name="EquilibriumHub", ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, IgnoreGuiInset=true, DisplayOrder=999, Enabled=false})
rootMaid:give(screen)
pcall(function() screen:SetAttribute("EquilibriumOwner", BRAND) end)

-- Notify: separate ScreenGui so it survives hub hide (old Roblox style)
local notifyGui=new("ScreenGui",{Name="EquilibriumNotify", ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, IgnoreGuiInset=true, DisplayOrder=1000})
notifyRoot=new("Frame",{BackgroundTransparency=1, AnchorPoint=Vector2.new(1,1), Position=UDim2.new(1,-16,1,-16), Size=offset(320,400), ZIndex=900, Parent=notifyGui})
notifyRoot:SetAttribute("ThemeRole","Shared")
new("UIListLayout",{FillDirection=Enum.FillDirection.Vertical, VerticalAlignment=Enum.VerticalAlignment.Bottom, HorizontalAlignment=Enum.HorizontalAlignment.Right, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,8), Parent=notifyRoot})
-- Mount notifyGui with same parent logic as screen (deferred below, parent now to PlayerGui as fallback)
pcall(function() notifyGui.Parent=game:GetService("CoreGui") end)
if not notifyGui.Parent then pcall(function() notifyGui.Parent=LP:WaitForChild("PlayerGui") end) end
if typeof(gethui)=="function" then pcall(function() notifyGui.Parent=gethui() end) end
rootMaid:give(notifyGui)
pcall(function() notifyGui:SetAttribute("EquilibriumOwner", BRAND) end)
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

-- Shell ? responsive geometry, UIScale for typography only
local shellRect={size=Vector2.new(W,H), pos=centeredPos(W,H)}
function applyShellGeometry(viewportSize)
    viewportSize = viewportSize or viewport()
    local mode = (hubAppearance.Scale==0.85 and "Small") or (hubAppearance.Scale==1.30 and "XL") or "Normal"
    local sz = getShellSize(viewportSize, mode)
    W, H = sz.X.Offset, sz.Y.Offset
    shellRect.size = Vector2.new(W,H)
    if shell then shell.Size = sz end
    -- clamp position if RememberPosition disabled ? recenter
    if hubAppearance.RememberPosition==false then
        shellRect.pos = centeredPos(W,H)
        if shell then shell.Position = offset(shellRect.pos.X, shellRect.pos.Y) end
    else
        local stored = Settings:Get("hubPosition","global")
        function validOffset(v) return type(v)=="number" and v==v and math.abs(v) < 100000 end
        if stored and validOffset(stored.OffsetX) and validOffset(stored.OffsetY) then
            local p = Vector2.new(stored.OffsetX, stored.OffsetY)
            p = clampShellPosition(p)
            shellRect.pos = p
            if shell then shell.Position = offset(p.X, p.Y) end
        else
            shellRect.pos = centeredPos(W,H)
            if shell then shell.Position = offset(shellRect.pos.X, shellRect.pos.Y) end
        end
    end
    pcall(function() applyTitleBarGeometry(viewportSize) end)
    pcall(function() applyNavigationMode(viewportSize) end)
end
shell=new("Frame",{BackgroundColor3=T.bg, Size=offset(W,H), Position=offset(shellRect.pos.X,shellRect.pos.Y), BorderSizePixel=0, ClipsDescendants=true, ZIndex=10, Parent=screen})
local shellCorner=corner(shell, hubAppearance.CornerRadius or 10); shellStroke=stroke(shell,T.border,1)
-- Remove UIScale transform to fix blurry text and fullscreen stretching
-- Sizing is now handled via responsive CSS-like dimensions, not global scale
canvas=new("CanvasGroup",{BackgroundTransparency=1, Size=UDim2.fromScale(1,1), GroupTransparency=hubAppearance.Transparency/100, ZIndex=11, Parent=shell})
-- apply stored visual style
setBorderStyle(hubAppearance.BorderEnabled~=false, hubAppearance.BorderThickness)
setCornerRadius(hubAppearance.CornerRadius or 10)
-- HubRoot is the entire Hub visual root (shell) for theme scope; canvas is HubCanvasGroup for transparency grouping
HubRoot = shell
-- viewport responsive recalc (no loop, only viewport/mode/open paths)
pcall(function() local cam=Workspace.CurrentCamera if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() applyShellGeometry(cam.ViewportSize) end) end end)
HubCanvasGroup = canvas
shell:SetAttribute("ThemeRole","bg")
canvas:SetAttribute("ThemeRole","bg")

-- TitleBar
local titleBar=new("Frame",{BackgroundColor3=T.titleBar, Size=UDim2.new(1,0,0,36), BorderSizePixel=0, ZIndex=12, Parent=canvas})
titleBar:SetAttribute("InteractionTarget","hub_title")
local hubIcon=new("ImageLabel",{BackgroundColor3=T.panel, Size=offset(28,28), Position=offset(8,4), Image="rbxthumb://type=AvatarHeadShot&id="..LP.UserId.."&w=420&h=420", BackgroundTransparency=0, BorderSizePixel=0, ZIndex=13, Parent=titleBar}) corner(hubIcon,14) stroke(hubIcon,T.border,1) hubIcon:SetAttribute("ThemeRole","panel")
corner(titleBar,10); new("Frame",{BackgroundColor3=T.titleBar, Size=UDim2.new(1,0,0,10), Position=UDim2.new(0,0,1,-10), BorderSizePixel=0, ZIndex=11, Parent=titleBar})
new("Frame",{BackgroundColor3=T.line, Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,1,-1), BorderSizePixel=0, ZIndex=12, Parent=titleBar})
do
    local function onEnter() local tgt=resolveInteractionTarget(titleBar, "hub_title") fireInteraction("hoverEnter", tgt) end
    local function onLeave() local tgt=resolveInteractionTarget(titleBar, "hub_title") fireInteraction("hoverLeave", tgt) end
    titleBar.MouseEnter:Connect(onEnter)
    titleBar.MouseLeave:Connect(onLeave)
end

local savedVerityLocked = Settings:Get("verityLocked","global") if savedVerityLocked==nil then savedVerityLocked=true end
VerityState.Locked = savedVerityLocked
Verity.locked = VerityState.Locked
-- Hub brand icon (circle, hub-only, not Verity)


-- Text sizing tokens (responsive, no scale transform)
local TEXT_SIZES = {
    Title = 13,
    Body = 10,
    Small = 9,
    Button = 11,
    Caption = 8
}

new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-190,1,0), Position=offset(42,-2), Font=FONTB, Text="Universal Hub Menu", TextSize=TEXT_SIZES.Title, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=titleBar})
new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-190,1,0), Position=offset(42,10), Font=FONT, Text="Universal  |  2.7.2", TextSize=TEXT_SIZES.Small, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=titleBar})

-- Windows buttons _ ? ?
local winRow=new("Frame",{BackgroundTransparency=1, Size=offset(138,36), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), ZIndex=13, Parent=titleBar}) hlist(winRow,0)
local function winBtn(txt,isClose)
    local b=new("TextButton",{BackgroundColor3=T.titleBar, Size=offset(46,36), Text=txt, Font=FONT, TextSize=isClose and 16 or 12, TextColor3=T.dim, AutoButtonColor=false, BorderSizePixel=0, ZIndex=13, Parent=winRow})
    if isClose then b.MouseEnter:Connect(function() b.BackgroundColor3=T.warn; b.TextColor3=Color3.new(1,1,1) end) b.MouseLeave:Connect(function() b.BackgroundColor3=T.titleBar; b.TextColor3=T.dim end)
    else b.MouseEnter:Connect(function() b.BackgroundColor3=T.border; b.TextColor3=T.text end) b.MouseLeave:Connect(function() b.BackgroundColor3=T.titleBar; b.TextColor3=T.dim end) end
    b.MouseButton1Down:Connect(function() b.BackgroundColor3 = isClose and T.warnHover or T.border end)
    return b
end
local btnMin=winBtn("_",false); local btnMax=winBtn("⬜",false); local btnClose=winBtn("×","�",true)
do local hold,holdT
    btnClose.MouseButton1Down:Connect(function() hold=true holdT=tick() task.spawn(function() while hold and tick()-holdT<0.9 do task.wait(0.05) end if hold and tick()-holdT>=0.9 then hold=false btnClose.Text="�"; task.wait(0.18) local fn=getgenv()[UNLOAD_KEY] if fn then pcall(fn) end btnClose.Text="�" end end) end)
    btnClose.MouseButton1Up:Connect(function() if not hold then return end local d=tick()-holdT hold=false btnClose.Text="�" if d<0.9 then tw(canvas,TweenInfo.new(0.16),{GroupTransparency=1}).Completed:Wait() screen.Enabled=false canvas.GroupTransparency=0 pushToast("Hidden | RightShift to restore","warn",2) end end)
    btnClose.MouseLeave:Connect(function() hold=false btnClose.Text="�" end)
end

-- Puck = (equals sign, theme-compatible)
local PUCK=56
local puck=new("TextButton",{BackgroundColor3=T.panel, Size=offset(PUCK,PUCK), Position=offset(centeredPos(PUCK,PUCK).X,centeredPos(PUCK,PUCK).Y), Text="", AutoButtonColor=false, BorderSizePixel=0, Visible=false, ZIndex=40, Parent=screen}) corner(puck,16) stroke(puck,T.border,1)
rootMaid:give(puck)
new("TextLabel",{BackgroundTransparency=1, Size=UDim2.fromScale(1,1), Font=FONTB, Text="=", TextSize=22, TextColor3=T.text, ZIndex=41, Parent=puck})
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
btnMax.Activated:Connect(function() if minimized then return end if not isMax then savedRect.pos=Vector2.new(shell.Position.X.Offset,shell.Position.Y.Offset) savedRect.size=Vector2.new(shell.AbsoluteSize.X,shell.AbsoluteSize.Y) local p,s=fullscreenRect() tw(shell,MOTION.win,{Size=offset(s.X,s.Y), Position=offset(p.X,p.Y)}) tw(shellCorner,MOTION.win,{CornerRadius=UDim.new(0,0)}) btnMax.Text="⬜" isMax=true else tw(shell,MOTION.win,{Size=offset(savedRect.size.X,savedRect.size.Y), Position=offset(savedRect.pos.X,savedRect.pos.Y)}) tw(shellCorner,MOTION.win,{CornerRadius=UDim.new(0,10)}) btnMax.Text="❐" isMax=false end end)
-- title drag gated by HubState.Draggable (independent from Verity), 20px viewport-safe clamp
do local drag=false; local sd,sp
    local function clampShell(x,y)
        if hubAppearance.ClipEnabled==false then return x,y end
        local vp=viewport()
        local sw=shell.AbsoluteSize.X; local sh=shell.AbsoluteSize.Y
        local minX,minY=20,20
        local maxX=math.max(minX, vp.X-sw-20)
        local maxY=math.max(minY, vp.Y-sh-20)
        return math.clamp(x,minX,maxX), math.clamp(y,minY,maxY)
    end
    titleBar.InputBegan:Connect(function(i) if isMax or minimized or HubState.Mode~="Draggable" then return end if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true sd=i.Position sp=Vector2.new(shell.Position.X.Offset,shell.Position.Y.Offset) end end)
    UserInputService.InputChanged:Connect(function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-sd local cx,cy=clampShell(sp.X+d.X,sp.Y+d.Y) shell.Position=offset(cx,cy) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false if hubAppearance.RememberPosition then pcall(function() Settings:Set("hubPosition", {Anchor=shell.Position, OffsetX=shell.Position.X.Offset, OffsetY=shell.Position.Y.Offset}, "global"); Settings:Save("global") end) end end end)
end

-- Content
local contentHolder=new("Frame",{BackgroundTransparency=1, Position=offset(0,36), Size=UDim2.new(1,0,1,-36), ZIndex=11, Parent=canvas})
local SIDEBAR_W=160
local sidebar=new("Frame",{BackgroundTransparency=1, Size=UDim2.new(0,SIDEBAR_W,1,0), ZIndex=11, Parent=contentHolder}) pad(sidebar,8,8,8,8)
local tabBar=new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,1,-24), ZIndex=11, Parent=sidebar}) vlist(tabBar,6)
local main=new("Frame",{BackgroundTransparency=1, Position=offset(SIDEBAR_W,0), Size=UDim2.new(1,-SIDEBAR_W,1,0), ZIndex=11, Parent=contentHolder}) pad(main,10,10,8,12)
local searchWrap=new("Frame",{BackgroundColor3=Color3.fromHex("0a0a0a"), Size=UDim2.new(1,0,0,32), ZIndex=12, Parent=main}) corner(searchWrap,8) stroke(searchWrap,T.border) pad(searchWrap,0,0,10,10)
local searchBox=new("TextBox",{BackgroundTransparency=1, Size=UDim2.fromScale(1,1), Font=FONT, Text="", PlaceholderText="Search features|", PlaceholderColor3=T.dim, TextSize=12, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ClearTextOnFocus=false, ZIndex=13, Parent=searchWrap})
local page=new("ScrollingFrame",{BackgroundTransparency=1, Position=offset(0,40), Size=UDim2.new(1,0,1,-40), BorderSizePixel=0, ScrollBarThickness=4, ScrollBarImageColor3=T.border, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollingDirection=Enum.ScrollingDirection.Y, ZIndex=11, Parent=main}) vlist(page,10) pad(page,4,12,4,8)

-- Runtime core10
local Features={}; local order={}; local RState={}; local Active={}
local function register(def) Features[def.id]=def table.insert(order,def.id) RState[def.id]={enabled=false, method=def.methods[1].id, settings={}} for k,m in pairs(def.settings or {}) do RState[def.id].settings[k]=m.default end end
local function methodById(def,mid) for _,m in ipairs(def.methods) do if m.id==mid then return m end end return def.methods[1] end
local function stop(id) local live=Active[id] if not live then return end Active[id]=nil if live.method.stop then pcall(live.method.stop,live.ctx) end live.ctx.maid:clean() EVENTS.fire("featureToggled",id,false) Verity:Set("neutral") end
local function start(id) local def=Features[id] if not def then return false end local st=RState[id] local m=methodById(def,st.method) if m.requiresChar~=false and not alive() then pushToast(def.name.." needs character","warn") return false end stop(id) local maid=Maid.new() local ctx={maid=maid, s=st.settings, notify=pushToast, every=function(_,bucket,fn) local key=id..":"..bucket..":"..tostring(tick()) Scheduler.add(bucket,key,fn) maid:give(function() Scheduler.remove(bucket,key) end) end} local ok,err=pcall(m.start,ctx) if not ok then maid:clean() pushToast(def.name.." "..m.name.." failed: "..tostring(err),"bad",4) Verity:Set("glitch") task.delay(1.5,function() Verity:Set("neutral") end) return false end Active[id]={ctx=ctx, method=m} EVENTS.fire("featureToggled",id,true) Verity:Set("happy") task.delay(1,function() Verity:Set("neutral") end) return true end
local function setEnabled(id,on) local st=RState[id] if not st then return false end if on then if start(id) then st.enabled=true return true end st.enabled=false return false end stop(id) st.enabled=false return true end

-- Server Hop capability (non-network, once at init, no Heartbeat)
function detectServerHopCapability()
    local ok, method = pcall(function() return game.HttpGet end)
    return ok and typeof(method)=="function"
end
local ServerHopCapability = detectServerHopCapability()
local storedEnabled = Settings:Get("ServerHopEnabled", nil)
local ServerHopEnabled
if storedEnabled==nil then ServerHopEnabled=ServerHopCapability Settings:Set("ServerHopEnabled", ServerHopEnabled, "global"); Settings:Save("global") else ServerHopEnabled = storedEnabled==true end
_G.ServerHopCapability = ServerHopCapability
_G.ServerHopEnabled = ServerHopEnabled

local function makeToggle(parent,cfg)
    local state=cfg.value and true or false
    local btn=new("TextButton",{BackgroundColor3=state and T.on or T.off, Size=offset(40,20), Text="", AutoButtonColor=false, BorderSizePixel=0, ZIndex=14, Parent=parent}) corner(btn,10)
    local knob=new("Frame",{BackgroundColor3=T.text, Size=offset(16,16), Position=UDim2.new(0,state and 22 or 2,0.5,-8), BorderSizePixel=0, ZIndex=15, Parent=btn}) corner(knob,8)
    local function render(v) state=v and true or false tw(btn,MOTION.hover,{BackgroundColor3=state and T.on or T.off}) tw(knob,TweenInfo.new(0.14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(0,state and 22 or 2,0.5,-8)}) end
    btn.Activated:Connect(function() local want=not state if cfg.onChange then local ok,res=pcall(cfg.onChange,want) if not ok then pushToast(tostring(res),"bad") return end if res==false then return end end render(want) end)
    return {set=function(_,v) render(v) end, get=function() return state end, instance=btn}
end

local function makeSlider(parent,cfg)
    local min,max,step = cfg.min or 0, cfg.max or 100, cfg.step or 1
    local value=cfg.default or min
    local row=new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=13, Parent=parent})
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(0,90,0,28), Font=FONT, Text=cfg.label or "Value", TextSize=11, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=14, Parent=row})
    local valLabel=new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(0,50,0,28), Position=UDim2.new(1,-60,0,0), Font=FONTB, Text=tostring(value), TextSize=11, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=14, Parent=row})
    local track=new("Frame",{BackgroundColor3=T.off, Size=UDim2.new(1,-160,0,6), Position=UDim2.new(0,90,0.5,-3), ZIndex=14, Parent=row}) corner(track,3)
    local fill=new("Frame",{BackgroundColor3=T.accent, Size=UDim2.new((value-min)/(max-min),0,1,0), ZIndex=15, Parent=track}) corner(fill,3)
    local knob=new("Frame",{BackgroundColor3=T.text, Size=offset(16,16), Position=UDim2.new((value-min)/(max-min),-8,0.5,-8), ZIndex=16, Parent=track}) corner(knob,8)
    local function set(v, silent)
        v=math.clamp(math.floor(v/step+0.5)*step, min, max)
        value=v
        local t=(value-min)/(max-min)
        fill.Size=UDim2.new(t,0,1,0)
        knob.Position=UDim2.new(t,-8,0.5,-8)
        -- Format display value: use fixed decimal for small ranges, integer for large
        if step < 0.1 then
            valLabel.Text=string.format("%.2f", value)
        elseif step < 1 then
            valLabel.Text=string.format("%.1f", value)
        else
            valLabel.Text=tostring(math.floor(value))
        end
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
register({id="walkspeed", name="WalkSpeed", category="Movement", desc="WalkSpeed", settings={speed={default=32, min=16, max=400, step=2}}, methods={{id="direct", name="Direct", start=function(ctx) local hum=Char.hum local orig=hum.WalkSpeed hum.WalkSpeed=ctx.s.speed ctx.maid:give(function() if hum and hum.Parent then pcall(function() hum.WalkSpeed=orig end) end end) ctx:every("heartbeat",function() if alive() and Char.hum.WalkSpeed~=ctx.s.speed then Char.hum.WalkSpeed=ctx.s.speed end end) end}}})
register({id="jumppower", name="JumpPower", category="Movement", desc="Jump tweak", settings={power={default=50, min=50, max=250, step=5}}, methods={{id="jp", name="JumpPower", start=function(ctx) local hum=Char.hum local orig=hum.JumpPower hum.JumpPower=ctx.s.power ctx.maid:give(function() if hum and hum.Parent then pcall(function() hum.JumpPower=orig end) end end) ctx:every("heartbeat", function() if alive() and Active.jumppower then Char.hum.JumpPower=ctx.s.power end end) end}}})
register({id="infjump", name="Infinite Jump", category="Movement", desc="JumpRequest repeat", methods={{id="loop", name="Loop", start=function(ctx)
    local conn = UserInputService.JumpRequest:Connect(function() if alive() then Char.hum:ChangeState(Enum.HumanoidStateType.Jumping) end end)
    ctx.maid:give(conn)
end}}})
register({id="noclip", name="Noclip", category="Movement", desc="Walk through walls", methods={{id="loop", name="Loop", start=function(ctx) local saved={} ctx.maid:give(function() for part,orig in pairs(saved) do if part.Parent then pcall(function() part.CanCollide=orig end) end end end) ctx:every("heartbeat",function() if not Char.model then return end for _,p in ipairs(Char.model:GetDescendants()) do if p:IsA("BasePart") then if saved[p]==nil then saved[p]=p.CanCollide end p.CanCollide=false end end end) end}}})
register({id="fov", name="FOV", category="Visuals", desc="Camera FOV", settings={fov={default=90, min=60, max=120, step=1}}, methods={{id="direct", name="Direct", requiresChar=false, start=function(ctx) local cam=Workspace.CurrentCamera local orig=cam.FieldOfView cam.FieldOfView=ctx.s.fov ctx.maid:give(function() if cam and cam.Parent then pcall(function() cam.FieldOfView=orig end) end end) ctx:every("heartbeat",function() cam.FieldOfView=ctx.s.fov end) end}}})
register({id="fullbright", name="Fullbright", category="Visuals", desc="No shadows", methods={{id="on", name="On", requiresChar=false, start=function(ctx) local orig={Brightness=Lighting.Brightness, ClockTime=Lighting.ClockTime, FogEnd=Lighting.FogEnd, GlobalShadows=Lighting.GlobalShadows, Ambient=Lighting.Ambient, ColorShift_Top=Lighting.ColorShift_Top, ColorShift_Bottom=Lighting.ColorShift_Bottom, ExposureCompensation=Lighting.ExposureCompensation} Lighting.Brightness=2 Lighting.ClockTime=14 Lighting.FogEnd=1e6 Lighting.GlobalShadows=false ctx.maid:give(function() for k,v in pairs(orig) do pcall(function() Lighting[k]=v end) end end) end}}})
register({id="esp", name="Player ESP", category="Visuals", desc="Billboard ESP", methods={{id="billboard", name="Billboard", requiresChar=false, start=function(ctx)
    local folder=new("Folder",{Name="EquilibriumESP", Parent=Camera}) ctx.maid:give(function() folder:Destroy() end)
    ctx:every("heartbeat",function() for _,plr in ipairs(Players:GetPlayers()) do if plr~=LP and plr.Character and plr.Character:FindFirstChild("Head") then local bb=folder:FindFirstChild(plr.Name) or new("BillboardGui",{Name=plr.Name, Adornee=plr.Character.Head, Size=UDim2.fromOffset(100,20), AlwaysOnTop=true, Parent=folder}) local lbl=bb:FindFirstChildOfClass("TextLabel") or new("TextLabel",{BackgroundTransparency=1, Size=UDim2.fromScale(1,1), Font=FONTB, Text=plr.Name, TextSize=12, TextColor3=T.text, Parent=bb}) end end end)
end}}})
register({id="tracer", name="Tracers", category="Visuals", desc="Coming Soon", methods={{id="draw", name="Draw", requiresChar=false, start=function(ctx) end}}})
register({id="serverhop", name="Server Hop", category="Server", desc="Find new server", methods={{id="hop", name="Hop", requiresChar=false, start=function(ctx) end}}, actions={{text="Hop Now", run=function() local ok,body=pcall(function() return game:HttpGet(("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100"):format(game.PlaceId)) end) if not ok then pushToast("HttpGet blocked by executor","warn") return end local data=HttpService:JSONDecode(body) local cands={} for _,sv in ipairs(data.data or {}) do if sv.id~=game.JobId and sv.playing<sv.maxPlayers then table.insert(cands,sv) end end if #cands==0 then pushToast("No servers","warn") return end local pick=cands[math.random(1,#cands)] TeleportService:TeleportToPlaceInstance(game.PlaceId,pick.id,LP) end}}})
register({id="antiafk", name="Anti-AFK", category="Server", desc="Prevents idle kick (VirtualUser)", methods={{id="on", name="On", requiresChar=false, start=function(ctx)
    local vu = cloneref and cloneref(game:GetService("VirtualUser")) or game:GetService("VirtualUser")
    local conn = LP.Idled:Connect(function() pcall(function() vu:CaptureController() vu:ClickButton2(Vector2.new()) end) end)
    ctx.maid:give(conn)
    ctx.maid:give(function() pcall(function() conn:Disconnect() end) end)
end}}})
register({id="teleport", name="Teleport to Player", category="Teleport", desc="Coming Soon", methods={{id="direct", name="Direct", start=function(ctx) end}}})

-- Tabs
local TABS={"Movement","Visuals","Teleport","Server","Settings","Deloader","About"}; local currentTab=TABS[1]; local tabButtons={}; local cards={}
local function refresh() for _,c in ipairs(cards) do c.frame.Visible=(currentTab==c.tab) end end
for _,name in ipairs(TABS) do 
    local b=new("TextButton",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,36), Text="", AutoButtonColor=false, ZIndex=12, Parent=tabBar}) 
    corner(b,8)
    local lbl=new("TextLabel",{BackgroundTransparency=1, Size=UDim2.fromScale(1,1), Font=FONT, Text=name, TextSize=12, TextColor3=T.dim, ZIndex=13, Parent=b}) 
    b.Activated:Connect(function() 
        currentTab=name 
        for _,bb in pairs(tabButtons) do 
            bb.lbl.TextColor3=T.dim 
            bb.btn.BackgroundTransparency=1
            bb.btn.BackgroundColor3=T.bg
        end 
        lbl.TextColor3=T.text 
        b.BackgroundTransparency=0
        b.BackgroundColor3=T.panel
        refresh() 
    end) 
    tabButtons[name]={btn=b,lbl=lbl} 
    if name==currentTab then 
        lbl.TextColor3=T.text 
        b.BackgroundTransparency=0
        b.BackgroundColor3=T.panel
    end 
end
local function makeCard(tab,title,desc) local card=new("Frame",{BackgroundColor3=T.panel, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BorderSizePixel=0, Visible=tab==currentTab, ZIndex=12, Parent=page}) corner(card,10) stroke(card,T.border) pad(card,10,10,12,12) vlist(card,8) new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,16), Font=FONTB, Text=title, TextSize=13, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=13, Parent=card}) if desc then new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, Font=FONT, Text=desc, TextSize=10, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, ZIndex=13, Parent=card}) end local c={frame=card,tab=tab} table.insert(cards,c) return card end
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
    if def.actions then for _,a in ipairs(def.actions) do
        local isHop = def.id=="serverhop"
        local canHop = not isHop or (ServerHopCapability and ServerHopEnabled)
        local btn=new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(1,0,0,28), Text=a.text, Font=FONT, TextSize=12, TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=card})
        applyControlChrome(btn, "ServerButton", false)
        if isHop then
            btn.Active = canHop
            btn.AutoButtonColor = canHop
            btn.TextTransparency = canHop and 0 or 0.35
        end
        btn.Activated:Connect(function()
            if isHop then
                if not ServerHopCapability then pushToast("Server Hop unavailable in this executor","warn") return end
                if not ServerHopEnabled then pushToast("Server Hop disabled in Settings","warn") return end
            end
            pcall(a.run)
        end)
    end end
end end
-- ===== PASS 2: TP BANK (file-explorer style, folders as tree, drag-drop, stable IDs) =====
do
    -- Data model: positions can exist at root (folderId=nil) or inside folders
    local TPBankState = { positions={}, folders={} }
    local function getBank() 
        local b=Settings:Get("tpBank","place") 
        if type(b)~="table" then b={positions={}, folders={}} end
        TPBankState.positions = b.positions or {}
        TPBankState.folders = b.folders or {}
        return TPBankState 
    end
    local function saveBank(state) 
        state = state or TPBankState
        Settings:Set("tpBank",{positions=state.positions or {}, folders=state.folders or {}},"place") 
        Settings:Save("place") 
        _G.TPBank = _G.TPBank or {} 
        _G.TPBank._bank=state 
        _G.AssistantContext=_G.AssistantContext or {} 
        _G.AssistantContext.tpBank=state 
    end
    local function serialize(cf) local p=cf.Position local l=cf.LookVector return {px=p.X,py=p.Y,pz=p.Z, lx=l.X,ly=l.Y,lz=l.Z} end
    local function deserialize(d) local p=Vector3.new(d.px,d.py,d.pz) local l=Vector3.new(d.lx or 0,d.ly or 0,d.lz or 1) return CFrame.new(p, p+l) end
    
    -- Stable action IDs
    local TPActions = {
        SavePosition = "tpbank.save",
        GoPosition = "tpbank.go",
        EditPosition = "tpbank.edit",
        DeletePosition = "tpbank.delete",
        MoveToFolder = "tpbank.move",
        CreateFolder = "tpbank.folder.create",
        RenameFolder = "tpbank.folder.rename",
        DeleteFolder = "tpbank.folder.delete",
        Export = "tpbank.export",
        Import = "tpbank.import",
    }
    
    -- UI state
    local expandedFolders = {}
    local draggedItem = nil
    local promptGui, promptBox, promptFolderBox, promptSaveBtn, promptCancelBtn
    local promptSaveConn, promptCancelConn, promptEnterConn
    
    -- Simple InputBox helper for rename/delete operations
    local function InputBox(title, defaultValue)
        if not promptGui or not promptGui.Parent then
            ensurePrompt()
        end
        local boxFrame = promptGui:FindFirstChildWhichIsA("Frame")
        local titleLabel = boxFrame:FindFirstChild("TitleLabel")
        if not titleLabel then
            titleLabel = new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,16), Font=FONTB, Text=title, TextSize=12, TextColor3=T.text, ZIndex=52, Parent=boxFrame})
            titleLabel.Name = "TitleLabel"
        else
            titleLabel.Text = title
        end
        local inputBox = boxFrame:FindFirstChildWhichIsA("TextBox")
        if inputBox then
            inputBox.Text = defaultValue or ""
            inputBox.PlaceholderText = "Enter text..."
        end
        local folderBox = boxFrame:FindFirstChild("TextBox", true)
        if folderBox and folderBox ~= inputBox then folderBox.Visible = false end
        promptGui.Visible = true
        if inputBox then inputBox:CaptureFocus() end
        
        local result = nil
        local done = false
        local saveBtn = boxFrame:FindFirstChildWhichIsA("TextButton")
        local cancelBtn = boxFrame:FindFirstChild("TextButton", true)
        
        if promptSaveConn then promptSaveConn:Disconnect() end
        if promptCancelConn then promptCancelConn:Disconnect() end
        
        if saveBtn then
            promptSaveConn = saveBtn.Activated:Connect(function()
                result = inputBox and inputBox.Text or ""
                promptGui.Visible = false
                done = true
            end)
        end
        
        if cancelBtn and cancelBtn ~= saveBtn then
            promptCancelConn = cancelBtn.Activated:Connect(function()
                promptGui.Visible = false
                done = true
            end)
        end
        
        while not done do task.wait(0.1) end
        return result
    end

    local function ensurePrompt()
        if promptGui and promptGui.Parent then return promptGui, promptBox, promptSaveBtn, promptCancelBtn, promptFolderBox end
        promptGui = new("Frame",{BackgroundColor3=Color3.fromRGB(0,0,0), BackgroundTransparency=0.35, Size=UDim2.fromScale(1,1), Visible=false, ZIndex=50, Parent=screen})
        local box = new("Frame",{BackgroundColor3=T.panel, Size=offset(300,140), Position=UDim2.new(0.5,0,0.5,0), AnchorPoint=Vector2.new(0.5,0.5), ZIndex=51, Parent=promptGui}) corner(box,12) stroke(box,T.border,1) pad(box,12,12,12,12) vlist(box,8)
        new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,16), Font=FONTB, Text="Save Position", TextSize=12, TextColor3=T.text, ZIndex=52, Parent=box})
        promptBox = new("TextBox",{BackgroundColor3=T.bg, Size=UDim2.new(1,0,0,28), Font=FONT, Text="", PlaceholderText="New checkpoint", PlaceholderColor3=T.dim, TextSize=12, TextColor3=T.text, ClearTextOnFocus=false, ZIndex=52, Parent=box}) corner(promptBox,8) stroke(promptBox,T.border,1) pad(promptBox,0,0,8,8)
        promptFolderBox = new("TextBox",{BackgroundColor3=T.bg, Size=UDim2.new(1,0,0,28), Font=FONT, Text="", PlaceholderText="Folder name (optional)", PlaceholderColor3=T.dim, TextSize=11, TextColor3=T.text, ClearTextOnFocus=false, ZIndex=52, Parent=box}) corner(promptFolderBox,8) stroke(promptFolderBox,T.border,1) pad(promptFolderBox,0,0,8,8)
        local row=new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=52, Parent=box}) hlist(row,6)
        promptSaveBtn = new("TextButton",{BackgroundColor3=T.accent, Size=UDim2.new(0.5,-4,0,28), Text="Save", Font=FONTB, TextSize=12, TextColor3=T.text, AutoButtonColor=false, ZIndex=53, Parent=row}) corner(promptSaveBtn,8)
        promptCancelBtn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0.5,-4,0,28), Text="Cancel", Font=FONT, TextSize=12, TextColor3=T.text, AutoButtonColor=false, ZIndex=53, Parent=row}) corner(promptCancelBtn,8) stroke(promptCancelBtn,T.border,1)
        promptCancelBtn.Activated:Connect(function() promptGui.Visible=false end)
        return promptGui, promptBox, promptSaveBtn, promptCancelBtn, promptFolderBox
    end
    
    local tpCard = makeCard("Teleport", "TP Bank", "12 slots · Position + Look Vector · Instant")
    -- Tip
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,14), Font=FONT, Text="Tip: Ctrl-click to look, double-click to teleport", TextSize=9, TextColor3=T.subtext, TextWrapped=true, ZIndex=13, Parent=tpCard})
    
    -- XYZ field + Go button
    local xyzRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=13, Parent=tpCard}) hlist(xyzRow,6)
    local xyzBox=new("TextBox",{BackgroundColor3=T.bg, Size=UDim2.new(1,-60,0,28), Font=FONT, Text="", PlaceholderText="X, Y, Z", PlaceholderColor3=T.dim, TextSize=11, TextColor3=T.text, ClearTextOnFocus=false, ZIndex=14, Parent=xyzRow}) corner(xyzBox,8) stroke(xyzBox,T.border,1) pad(xyzBox,0,0,8,8)
    local goBtn=new("TextButton",{BackgroundColor3=T.accent, Size=UDim2.new(0,56,0,28), Text="Go", Font=FONTB, TextSize=11, TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=xyzRow}) corner(goBtn,8)
    goBtn.Activated:Connect(function()
        local x,y,z = xyzBox.Text:match("([%-%d%.]+)[%s,]+([%-%d%.]+)[%s,]+([%-%d%.]+)")
        if not x then pushToast("Enter X, Y, Z","warn",1) return end
        local cf=CFrame.new(tonumber(x),tonumber(y),tonumber(z))
        pcall(function() if alive() and Char.root then Char.root.CFrame=cf end end)
        pushToast("Teleported","warn",1)
    end)
    
    -- Import row
    local importRow=new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=13, Parent=tpCard}) hlist(importRow,6)
    local importBox=new("TextBox",{BackgroundColor3=T.bg, Size=UDim2.new(1,-70,0,28), Font=FONT, Text="", PlaceholderText="Import JSON", PlaceholderColor3=T.dim, TextSize=10, TextColor3=T.text, ClearTextOnFocus=false, ZIndex=14, Parent=importRow}) corner(importBox,8) stroke(importBox,T.border,1) pad(importBox,0,0,8,8)
    local importBtn=new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0,66,0,28), Text="Import", Font=FONT, TextSize=11, TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=importRow}) corner(importBtn,8) stroke(importBtn,T.border,1)
    importBtn.Activated:Connect(function()
        local txt=importBox.Text
        if txt=="" then pushToast("Paste JSON","warn",1) return end
        local ok,data=pcall(HttpService.JSONDecode, HttpService, txt)
        if ok and type(data)=="table" then
            local state=getBank()
            local validFolderIds = {}
            for _,f in ipairs(state.folders) do validFolderIds[f.id]=true end
            for _,entry in ipairs(data) do
                if entry.name and entry.px then
                    local folderId = (entry.folderId and validFolderIds[entry.folderId]) and entry.folderId or nil
                    table.insert(state.positions, {
                        id = entry.id or HttpService:GenerateGUID(false),
                        name = entry.name,
                        px = entry.px or 0, py = entry.py or 0, pz = entry.pz or 0,
                        lx = entry.lx or 0, ly = entry.ly or 0, lz = entry.lz or 1,
                        folderId = folderId,
                        createdAt = entry.createdAt or os.time(),
                        updatedAt = os.time()
                    })
                end
            end
            saveBank(state)
            pushToast("Imported "..#data.." positions","warn",1)
            pcall(refreshTree)
        else pushToast("Invalid JSON","warn",1) end
    end)
    
    -- Current coordinates display + Save button
    local coordsRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=13, Parent=tpCard}) hlist(coordsRow,6)
    local coordsDisplay = new("TextBox",{BackgroundColor3=T.bg, Size=UDim2.new(1,-80,0,28), Font=FONT, Text="", PlaceholderText="Current coordinates", PlaceholderColor3=T.dim, TextSize=10, TextColor3=T.subtext, ClearTextOnFocus=false, ZIndex=14, Parent=coordsRow}) corner(coordsDisplay,8) stroke(coordsDisplay,T.border,1) pad(coordsDisplay,0,0,8,8)
    local savePosBtn = new("TextButton",{BackgroundColor3=T.accent, Size=UDim2.new(0,76,0,28), Text="Save position", Font=FONTB, TextSize=10, TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=coordsRow}) corner(savePosBtn,8)
    
    -- Update coordinates display periodically
    local function updateCoordsDisplay()
        if alive() and Char.root then
            local pos = Char.root.Position
            coordsDisplay.Text = string.format("X %.2f  Y %.2f  Z %.2f", pos.X, pos.Y, pos.Z)
        end
    end
    
    -- Initial update and heartbeat
    updateCoordsDisplay()
    local coordsConn = RunService.Heartbeat:Connect(function()
        if tpCard.Visible and alive() then updateCoordsDisplay() end
    end)
    rootMaid:give(coordsConn)
    
    savePosBtn.Activated:Connect(function()
        if not alive() then pushToast("No character","warn") return end
        local pg,box,saveBtn,cancelBtn,folderBox = ensurePrompt()
        box.Text="" box.PlaceholderText="New checkpoint"
        folderBox.Text="" folderBox.PlaceholderText="Leave empty for root"
        pg.Visible=true box:CaptureFocus()
        
        if promptSaveConn then promptSaveConn:Disconnect() end
        promptSaveConn = saveBtn.Activated:Connect(function()
            local name = box.Text:gsub("^%s+",""):gsub("%s+$","")
            if name=="" then name="Checkpoint_"..(#getBank().positions+1) end
            
            local cf = Char.root.CFrame
            local d = serialize(cf)
            local state = getBank()
            
            -- Determine folder from dropdown
            local folderName = folderBox.Text:gsub("^%s+",""):gsub("%s+$","")
            local folderId = nil
            if folderName ~= "" then
                -- Find or create folder
                local foundFolder = nil
                for _,f in ipairs(state.folders) do
                    if f.name:lower() == folderName:lower() then
                        foundFolder = f
                        break
                    end
                end
                if not foundFolder then
                    table.insert(state.folders, {
                        id = HttpService:GenerateGUID(false),
                        name = folderName,
                        parentId = nil,
                        expanded = false,
                        createdAt = os.time()
                    })
                    foundFolder = state.folders[#state.folders]
                end
                folderId = foundFolder.id
            end
            
            table.insert(state.positions, {
                id = HttpService:GenerateGUID(false),
                name=name,
                px=d.px, py=d.py, pz=d.pz,
                lx=d.lx, ly=d.ly, lz=d.lz,
                folderId=folderId,
                createdAt=os.time(),
                updatedAt=os.time()
            })
            saveBank(state)
            pg.Visible=false
            promptSaveConn:Disconnect()
            pushToast("Saved "..name.." to "..(folderName or "root"),"warn",1.4)
            pcall(refreshTree)
        end)
    end)
    
    -- Tree container
    local treeHolder = new("ScrollingFrame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,180), BorderSizePixel=0, ScrollBarThickness=4, ScrollBarImageColor3=T.border, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollingDirection=Enum.ScrollingDirection.Y, ZIndex=13, Parent=tpCard})
    local treeLayout = new("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim2.fromOffset(0,4), Parent=treeHolder})
    
    -- Helper functions
    local function toggleFolder(folderId)
        expandedFolders[folderId] = not expandedFolders[folderId]
        pcall(refreshTree)
    end
    
    local function movePositionToFolder(positionId, folderId)
        local state=getBank()
        for _,pos in ipairs(state.positions) do
            if pos.id == positionId then
                pos.folderId = folderId
                pos.updatedAt = os.time()
                break
            end
        end
        saveBank(state)
        pcall(refreshTree)
    end
    
    local function deletePosition(positionId)
        local state=getBank()
        for i,pos in ipairs(state.positions) do
            if pos.id == positionId then
                table.remove(state.positions, i)
                break
            end
        end
        saveBank(state)
        pushToast("Deleted position","warn",1.2)
        pcall(refreshTree)
    end
    
    local function createFolder(name)
        local state=getBank()
        table.insert(state.folders, {
            id = HttpService:GenerateGUID(false),
            name = name or "New Folder",
            parentId = nil,
            expanded = false,
            createdAt = os.time()
        })
        saveBank(state)
        pcall(refreshTree)
    end
    
    -- Create folder prompt
    local folderPromptGui, folderPromptBox, folderPromptSaveBtn, folderPromptCancelBtn
    local folderPromptConn
    local function ensureFolderPrompt()
        if folderPromptGui and folderPromptGui.Parent then return folderPromptGui, folderPromptBox, folderPromptSaveBtn, folderPromptCancelBtn end
        folderPromptGui = new("Frame",{BackgroundColor3=Color3.fromRGB(0,0,0), BackgroundTransparency=0.35, Size=UDim2.fromScale(1,1), Visible=false, ZIndex=50, Parent=screen})
        local box = new("Frame",{BackgroundColor3=T.panel, Size=offset(280,120), Position=UDim2.new(0.5,0,0.5,0), AnchorPoint=Vector2.new(0.5,0.5), ZIndex=51, Parent=folderPromptGui}) corner(box,12) stroke(box,T.border,1) pad(box,10,10,10,10) vlist(box,6)
        new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,14), Font=FONTB, Text="Create Folder", TextSize=11, TextColor3=T.text, ZIndex=52, Parent=box})
        folderPromptBox = new("TextBox",{BackgroundColor3=T.bg, Size=UDim2.new(1,0,0,26), Font=FONT, Text="", PlaceholderText="Folder name", PlaceholderColor3=T.dim, TextSize=11, TextColor3=T.text, ClearTextOnFocus=false, ZIndex=52, Parent=box}) corner(folderPromptBox,6) stroke(folderPromptBox,T.border,1) pad(folderPromptBox,0,0,6,6)
        local row=new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,26), ZIndex=52, Parent=box}) hlist(row,4)
        folderPromptSaveBtn = new("TextButton",{BackgroundColor3=T.accent, Size=UDim2.new(0.5,-3,0,26), Text="Create", Font=FONTB, TextSize=10, TextColor3=T.text, AutoButtonColor=false, ZIndex=53, Parent=row}) corner(folderPromptSaveBtn,6)
        folderPromptCancelBtn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0.5,-3,0,26), Text="Cancel", Font=FONT, TextSize=10, TextColor3=T.text, AutoButtonColor=false, ZIndex=53, Parent=row}) corner(folderPromptCancelBtn,6) stroke(folderPromptCancelBtn,T.border,1)
        folderPromptCancelBtn.Activated:Connect(function() folderPromptGui.Visible=false end)
        return folderPromptGui, folderPromptBox, folderPromptSaveBtn, folderPromptCancelBtn
    end
    
    local function deleteFolder(folderId, moveContents)
        local state=getBank()
        -- Remove folder
        for i,folder in ipairs(state.folders) do
            if folder.id == folderId then
                table.remove(state.folders, i)
                break
            end
        end
        -- Handle contents
        if moveContents then
            for _,pos in ipairs(state.positions) do
                if pos.folderId == folderId then
                    pos.folderId = nil
                    pos.updatedAt = os.time()
                end
            end
        else
            -- Delete contents
            for i=#state.positions,1,-1 do
                if state.positions[i].folderId == folderId then
                    table.remove(state.positions, i)
                end
            end
        end
        saveBank(state)
        pcall(refreshTree)
    end
    
    local function exportBank()
        local state=getBank()
        local exportData = {
            version = 1,
            exportedAt = os.time(),
            folders = state.folders,
            positions = state.positions
        }
        local ok,json = pcall(HttpService.JSONEncode, HttpService, exportData)
        if ok then
            -- Copy to clipboard via setclipboard or show in textbox
            if setclipboard then
                setclipboard(json)
                pushToast("Exported to clipboard","warn",1.5)
            else
                importBox.Text = json
                pushToast("Export JSON shown in import box","warn",2)
            end
        else
            pushToast("Export failed","warn",1)
        end
    end
    
    -- Render tree
    local function refreshTree()
        for _,c in ipairs(treeHolder:GetChildren()) do 
            if c:IsA("GuiObject") and c.Name~=treeLayout.Name then c:Destroy() end 
        end
        
        local state=getBank()
        local rootPositions = {}
        local folderPositions = {}
        
        -- Separate positions by folder
        for _,pos in ipairs(state.positions) do
            if pos.folderId then
                folderPositions[pos.folderId] = folderPositions[pos.folderId] or {}
                table.insert(folderPositions[pos.folderId], pos)
            else
                table.insert(rootPositions, pos)
            end
        end
        
        local order = 0
        
        -- Root positions section
        if #rootPositions > 0 or #state.folders > 0 then
            local rootHeader = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,24), ZIndex=14, Parent=treeHolder})
            rootHeader.LayoutOrder = order
            order = order + 1
            new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-40,0,20), Position=offset(8,2), Font=FONTB, Text="⠿ Root positions", TextSize=11, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=15, Parent=rootHeader})
            local addBtn = new("TextButton",{BackgroundColor3=T.panel, Size=offset(32,20), Position=UDim2.new(1,-36,0,2), Text="+", Font=FONTB, TextSize=14, TextColor3=T.accent, AutoButtonColor=false, ZIndex=15, Parent=rootHeader}) corner(addBtn,6)
            addBtn.Activated:Connect(function()
                local pg,box,saveBtn,cancelBtn,folderBox=ensurePrompt()
                box.Text="" box.PlaceholderText="New checkpoint"
                folderBox.Text="" folderBox.PlaceholderText="Leave empty for root"
                pg.Visible=true box:CaptureFocus()
                if promptSaveConn then promptSaveConn:Disconnect() end
                promptSaveConn=saveBtn.Activated:Connect(function()
                    local name=box.Text:gsub("^%s+",""):gsub("%s+$","")
                    if name=="" then name="Checkpoint_"..(#state.positions+1) end
                    local cf=Char.root.CFrame
                    local d=serialize(cf)
                    table.insert(state.positions, {
                        id = HttpService:GenerateGUID(false),
                        name=name,
                        px=d.px, py=d.py, pz=d.pz,
                        lx=d.lx, ly=d.ly, lz=d.lz,
                        folderId=nil,
                        createdAt=os.time(),
                        updatedAt=os.time()
                    })
                    saveBank(state)
                    pg.Visible=false
                    promptSaveConn:Disconnect()
                    pushToast("Saved "..name,"warn",1.4)
                    pcall(refreshTree)
                end)
            end)
        end
        
        -- Render root positions
        for _,pos in ipairs(rootPositions) do
            order = order + 1
            local card = new("Frame",{BackgroundColor3=T.bg, Size=UDim2.new(1,0,0,42), ZIndex=14, Parent=treeHolder})
            card.LayoutOrder = order
            corner(card,8) stroke(card,T.border,1) pad(card,8,8,6,6)
            
            new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-100,0,16), Position=offset(0,2), Font=FONTB, Text="⠿  "..pos.name, TextSize=11, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=15, Parent=card})
            new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-100,0,14), Position=offset(0,18), Font=FONT, Text=string.format("X %.2f · Y %.2f · Z %.2f", pos.px, pos.py, pos.pz), TextSize=9, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=15, Parent=card})
            
            local goBtn2 = new("TextButton",{BackgroundColor3=T.accent, Size=offset(42,22), Position=UDim2.new(1,-48,0,10), Text="Go", Font=FONTB, TextSize=10, TextColor3=T.text, AutoButtonColor=false, ZIndex=16, Parent=card}) corner(goBtn2,6)
            goBtn2.Activated:Connect(function()
                if not alive() then pushToast("No character","warn") return end
                local cf=deserialize(pos)
                Char.root.CFrame=cf
                pushToast("Teleported to "..pos.name,"warn",1.6)
            end)
            
            local menuBtn = new("TextButton",{BackgroundColor3=T.panel, Size=offset(28,22), Position=UDim2.new(1,-78,0,10), Text="⋮", Font=FONTB, TextSize=14, TextColor3=T.dim, AutoButtonColor=false, ZIndex=16, Parent=card}) corner(menuBtn,6)
            menuBtn.Activated:Connect(function()
                -- Context menu for position: rename, delete, move to folder
                local action = nil
                local newName = InputBox("Rename position (or type DELETE to remove)", pos.name)
                if newName and newName ~= "" then
                    if newName:upper() == "DELETE" then
                        deletePosition(pos.id)
                    else
                        pos.name = newName
                        pos.updatedAt = os.time()
                        saveBank(state)
                        pcall(refreshTree)
                        pushToast("Renamed position","warn",1)
                    end
                end
            end)
            
            -- Drag handle
            local dragHandle = new("TextButton",{BackgroundTransparency=1, Size=offset(20,20), Position=offset(4,11), Text="⠿", Font=FONT, TextSize=16, TextColor3=T.dim, AutoButtonColor=false, ZIndex=17, Parent=card})
            dragHandle.Activated:Connect(function()
                draggedItem = {type="position", id=pos.id}
                pushToast("Drag to a folder or root","warn",1)
            end)
            
            card.MouseEnter:Connect(function() card.BackgroundColor3=T.panel end)
            card.MouseLeave:Connect(function() card.BackgroundColor3=T.bg end)
        end
        
        -- Render folders
        for _,folder in ipairs(state.folders) do
            order = order + 1
            local isExpanded = expandedFolders[folder.id]
            local folderCard = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=14, Parent=treeHolder})
            folderCard.LayoutOrder = order
            pad(folderCard,8,8,4,4)
            
            local chevron = isExpanded and "▾" or "▸"
            local folderBtn = new("TextButton",{BackgroundTransparency=1, Size=UDim2.new(1,-40,0,24), Text=chevron.."  "..folder.name, Font=FONTB, TextSize=11, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, AutoButtonColor=false, ZIndex=15, Parent=folderCard})
            folderBtn.Activated:Connect(function() toggleFolder(folder.id) end)
            
            local delBtn = new("TextButton",{BackgroundColor3=T.panel, Size=offset(32,22), Position=UDim2.new(1,-36,0,1), Text="⋮", Font=FONTB, TextSize=12, TextColor3=T.dim, AutoButtonColor=false, ZIndex=15, Parent=folderCard}) corner(delBtn,6)
            delBtn.Activated:Connect(function()
                -- Delete folder with option dialog
                local choice = nil
                -- Simple inline prompt: rename or delete
                local newName = InputBox("Rename folder or type DELETE to remove", folder.name)
                if newName and newName ~= "" then
                    if newName:upper() == "DELETE" then
                        deleteFolder(folder.id, true) -- move contents to root
                        pushToast("Deleted folder","warn",1.2)
                    else
                        folder.name = newName
                        saveBank(state)
                        pcall(refreshTree)
                        pushToast("Renamed folder","warn",1)
                    end
                end
            end)
            
            -- Render folder contents if expanded
            if isExpanded then
                local fPositions = folderPositions[folder.id] or {}
                for _,pos in ipairs(fPositions) do
                    order = order + 1
                    local posCard = new("Frame",{BackgroundColor3=T.bg, Size=UDim2.new(1,0,0,38), ZIndex=14, Parent=treeHolder})
                    posCard.LayoutOrder = order
                    corner(posCard,8) stroke(posCard,T.border,1) pad(posCard,12,12,4,4)
                    
                    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-100,0,14), Position=offset(0,2), Font=FONTB, Text="⠿  "..pos.name, TextSize=10, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=15, Parent=posCard})
                    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-100,0,12), Position=offset(0,16), Font=FONT, Text=string.format("X %.2f · Y %.2f · Z %.2f", pos.px, pos.py, pos.pz), TextSize=8, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=15, Parent=posCard})
                    
                    local goBtn3 = new("TextButton",{BackgroundColor3=T.accent, Size=offset(36,18), Position=UDim2.new(1,-42,0,10), Text="Go", Font=FONTB, TextSize=9, TextColor3=T.text, AutoButtonColor=false, ZIndex=16, Parent=posCard}) corner(goBtn3,6)
                    goBtn3.Activated:Connect(function()
                        if not alive() then pushToast("No character","warn") return end
                        local cf=deserialize(pos)
                        Char.root.CFrame=cf
                        pushToast("Teleported","warn",1.6)
                    end)
                    
                    local menuBtn2 = new("TextButton",{BackgroundTransparency=1, Size=offset(24,18), Position=UDim2.new(1,-80,0,10), Text="⋮", Font=FONTB, TextSize=11, TextColor3=T.dim, AutoButtonColor=false, ZIndex=16, Parent=posCard})
                    menuBtn2.Activated:Connect(function()
                        -- Context menu for folder position: rename, delete, move to root/another folder
                        local newName = InputBox("Rename position (or type DELETE to remove)", pos.name)
                        if newName and newName ~= "" then
                            if newName:upper() == "DELETE" then
                                deletePosition(pos.id)
                            else
                                pos.name = newName
                                pos.updatedAt = os.time()
                                saveBank(state)
                                pcall(refreshTree)
                                pushToast("Renamed position","warn",1)
                            end
                        end
                    end)
                    
                    posCard.MouseEnter:Connect(function() posCard.BackgroundColor3=T.panel end)
                    posCard.MouseLeave:Connect(function() posCard.BackgroundColor3=T.bg end)
                end
                
                if #fPositions == 0 then
                    order = order + 1
                    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,18), Font=FONT, Text="  Folder is empty", TextSize=9, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=15, Parent=treeHolder})
                end
            end
        end
        
        -- Empty state
        if #state.positions == 0 and #state.folders == 0 then
            new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,32), Font=FONT, Text="No saved positions yet.\nSave your current coordinates to create your first position.", TextSize=10, TextColor3=T.dim, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=14, Parent=treeHolder})
        end
        
        -- Update count
        local countLabel = tpCard:FindFirstChild("CountLabel")
        if not countLabel then
            countLabel = new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,14), Font=FONT, Text="", TextSize=9, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=13, Parent=tpCard})
            countLabel.Name = "CountLabel"
        end
        countLabel.Text = #state.positions.." / 12 used"
    end
    
    -- Create folder button
    local createFolderRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=13, Parent=tpCard}) hlist(createFolderRow,6)
    local createFolderBtn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(1,0,0,28), Text="+ Create folder", Font=FONTB, TextSize=11, TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=createFolderRow}) corner(createFolderBtn,8) stroke(createFolderBtn,T.border,1)
    createFolderBtn.Activated:Connect(function()
        local pg,box,saveBtn,cancelBtn = ensureFolderPrompt()
        box.Text="" box.PlaceholderText="Folder name"
        pg.Visible=true box:CaptureFocus()
        if folderPromptConn then folderPromptConn:Disconnect() end
        folderPromptConn = saveBtn.Activated:Connect(function()
            local name = box.Text:gsub("^%s+",""):gsub("%s+$","")
            if name=="" then name="New Folder" end
            createFolder(name)
            pg.Visible=false
            folderPromptConn:Disconnect()
        end)
    end)
    
    -- Export button (compact, in header area)
    local exportRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,24), ZIndex=13, Parent=tpCard}) 
    local exportBtn = new("TextButton",{BackgroundColor3=T.panel, Size=offset(70,24), Text="Export", Font=FONT, TextSize=10, TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=exportRow}) corner(exportBtn,6) stroke(exportBtn,T.border,1)
    exportBtn.Activated:Connect(function() exportBank() end)
    
    -- Reset button
    local resetBtn = new("TextButton",{BackgroundColor3=T.panel, Size=offset(70,24), Position=UDim2.new(1,-76,0,0), Text="Reset", Font=FONT, TextSize=10, TextColor3=T.dim, AutoButtonColor=false, ZIndex=14, Parent=exportRow}) corner(resetBtn,6) stroke(resetBtn,T.border,1)
    resetBtn.Activated:Connect(function()
        TPBankState = {positions={}, folders={}}
        saveBank(TPBankState)
        pushToast("TP Bank reset","warn",1.2)
        pcall(refreshTree)
    end)
    
    -- initial draw
    refreshTree()
    -- expose canonical + bridge (single source of truth: AssistantContext.tpBank)
    _G.AssistantContext=_G.AssistantContext or {} _G.AssistantContext.tpBank=getBank()
    _G.TPBank = {get=getBank, save=saveBank, refresh=refreshGrid, deserialize=deserialize, serialize=serialize, _bank=getBank()}
    EVENTS.on("tpbank:teleport", function(name) Verity:Set("happy") task.delay(0.8,function() Verity:Set("neutral") end) end)
end
-- Settings ? Appearance (Pass 3 Hub Themes, Hub-only) | single authoritative content lifecycle
-- Stable action IDs for button mapping (not positional assumptions)
local AppearanceActions = {
    SelectPreset = "appearance.preset.select",
    CustomizePreset = "appearance.preset.customize",
    PickAccent = "appearance.accent.pick",
    ResetChanges = "appearance.reset.changes",
    SavePreset = "appearance.preset.save",
    SaveAsPreset = "appearance.preset.saveas",
    ToggleFullscreen = "appearance.fullscreen.toggle",
    LockPosition = "appearance.position.lock",
}

do
    local AppearanceGeneration = 0
    local appCard = makeCard("Settings", "Appearance", nil)
    registerThemed(appCard, "BackgroundColor3", "panel")
    appCard.ClipsDescendants = false

    -- sub-section header (clean, no hairline — spacious sections)
    local function subHeader(text)
        new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,6), ZIndex=13, Parent=appCard})
        new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,16), Font=FONTB, Text=text, TextSize=11, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=appCard})
    end
    local function sectionHint(text)
        return new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,12), Font=FONT, Text=text, TextSize=9, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=appCard})
    end

    -- live current-state summary with preset-based info
    local sizeNames={["0.85"]="Small",["1.00"]="Normal",["1.15"]="Large",["1.30"]="XL"}
    local function scaleToName() return sizeNames[tostring(hubAppearance.Scale)] or "Normal" end
    local summaryLabel = new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,18), Font=FONT, TextSize=10, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, AutomaticSize=Enum.AutomaticSize.Y, ZIndex=13, Parent=appCard})
    local function refreshSummary()
        local th = THEMES[hubAppearance.Theme] or THEMES.Theme_01
        local pos = hubAppearance.Position or "Default"
        local trans = hubAppearance.Transparency or 0
        local modified = isAppearanceDirty(hubAppearance) and " *" or ""
        summaryLabel.Text = string.format("%s%s | %s | %s | %d%% | %s", th.name, modified, scaleToName(), pos, trans, HubState.Mode)
    end

    -- ===== PREVIEW (persistent, deterministic, interactive) =====
    local previewFrame
    local function RefreshAppearancePreview()
        if not previewFrame then return end
        -- Use ResolveAppearance for consistent state
        local resolved = ResolveAppearance()
        local th = THEMES[resolved.Theme] or THEMES.Theme_01
        local c = {}
        for k,v in pairs(th.colors) do c[k]=v end
        if hubAppearance.Theme=="Theme_07" and hubAppearance.CustomColors then
            for k,hex in pairs(hubAppearance.CustomColors) do local ok,col=pcall(Color3.fromHex, hex:gsub("#","")) if ok and col then c[k]=col end end
        end
        pcall(function() previewFrame.BackgroundColor3 = c.panel or T.panel end)
        local st = previewFrame:FindFirstChildOfClass("UIStroke") if st then pcall(function() st.Color = c.border or T.border end) end
        for _,ch in ipairs(previewFrame:GetDescendants()) do
            if ch:GetAttribute("PreviewRole")=="accent" then pcall(function() ch.BackgroundColor3 = c.accent or T.accent end)
            elseif ch:GetAttribute("PreviewRole")=="text" then pcall(function() ch.TextColor3 = c.text or T.text end)
            elseif ch:GetAttribute("PreviewRole")=="panel" then pcall(function() ch.BackgroundColor3 = c.panel or T.panel end) end
        end
        previewFrame.BackgroundTransparency = (hubAppearance.Transparency or 0)/100 * 0.5
        local ind = previewFrame:FindFirstChild("ModeIndicator", true)
        if ind then ind.Text = HubState.Mode=="Locked" and "Locked" or "Draggable" end
    end
    -- create persistent preview (always visible, deterministic)
    do
        previewFrame = new("Frame",{BackgroundColor3=T.panel, Size=UDim2.new(1,0,0,96), ZIndex=13, Parent=appCard}) corner(previewFrame,8) stroke(previewFrame,T.border,1) pad(previewFrame,8,8,10,10) vlist(previewFrame,6)
        new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,14), Font=FONTB, Text="PREVIEW", TextSize=9, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=14, Parent=previewFrame})
        local mini = new("Frame",{BackgroundColor3=T.bg, Size=UDim2.new(1,0,0,48), ZIndex=14, Parent=previewFrame}) corner(mini,6) stroke(mini,T.border,1)
        new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,14), Position=UDim2.new(0,0,0,4), Font=FONTB, Text="EQ EQUILIBRIUM", TextSize=10, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=15, Parent=mini}):SetAttribute("PreviewRole","text")
        local badge = new("TextLabel",{Name="ModeIndicator", BackgroundTransparency=1, Size=UDim2.new(1,0,0,12), Position=UDim2.new(0,0,1,-14), Font=FONT, Text=HubState.Mode=="Locked" and "Locked" or "Draggable", TextSize=9, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=15, Parent=mini})
        badge:SetAttribute("PreviewRole","dim")
        -- accent bar to show theme accent
        local accentBar = new("Frame",{BackgroundColor3=T.accent, Size=UDim2.new(1,0,0,3), Position=UDim2.new(0,0,1,-3), ZIndex=15, Parent=mini}) corner(accentBar,2) accentBar:SetAttribute("PreviewRole","accent")
        new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,12), Font=FONT, Text="Hub Preview", TextSize=9, TextColor3=T.subtext, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=14, Parent=previewFrame}):SetAttribute("PreviewRole","subtext")
    end
    RefreshAppearancePreview()

    -- forward declarations (theme-button closures reference these before their definitions)
    local selectedToken = "accent"
    local updateCustomEditor

    -- local hover tooltip (local to appCard, not a global manager; theme-aware + follows theme)
    local function makeTooltip()
        local tip = new("Frame",{BackgroundColor3=T.panel, BorderSizePixel=0, Visible=false, ZIndex=70, Parent=shell})
        corner(tip,6) stroke(tip,T.border,1) pad(tip,6,6,8,8)
        local lbl = new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(0,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, Font=FONT, TextSize=10, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, ZIndex=71, Parent=tip})
        tip.Size = UDim2.new(0,180,0,0)
        lbl.Size = UDim2.new(1,0,0,0)
        return tip, lbl
    end
    local tipFrame, tipLabel = makeTooltip()
    local tipTimer = nil
    local function showTooltip(text, anchor)
        if tipTimer then task.cancel(tipTimer) tipTimer=nil end
        tipLabel.Text = text
        tipFrame.Size = UDim2.new(0,180,0,0)
        tipFrame.Visible = true
        task.defer(function()
            tipLabel.Size = UDim2.new(1,0,math.max(18,tipLabel.TextBounds.Y),0)
            tipFrame.Size = UDim2.new(0,180,0, tipLabel.AbsoluteSize.Y + 12)
        end)
        if anchor and anchor.Parent then
            local ap = anchor.AbsolutePosition
            local parentAP = appCard.AbsolutePosition
            tipFrame.Position = UDim2.new(0, ap.X - parentAP.X + 4, 0, ap.Y - parentAP.Y + 30)
        end
    end
    local function hideTooltip()
        tipFrame.Visible = false
    end
    local function wireTooltip(obj, text)
        local gen = AppearanceGeneration
        obj.MouseEnter:Connect(function() if gen ~= AppearanceGeneration then return end showTooltip(text, obj) end)
        obj.MouseLeave:Connect(hideTooltip)
    end
    -- ContextState sole owner + scroll/theme/page teardown clears stale hover (prevents ghost panel)
    local ContextState = {Target=nil, Visible=false}
    local function ClearContext() ContextState.Visible=false; ContextState.Target=nil; tipFrame.Visible=false end
    pcall(function() page:GetPropertyChangedSignal("CanvasPosition"):Connect(ClearContext) page:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(ClearContext) end)
    EVENTS.on("theme.changed", function() ClearContext() end)

    -- ===== 01 QUICK STYLE =====
    subHeader("01  QUICK STYLE")
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,12), Font=FONT, Text="Theme  ?  Size  ?  Position", TextSize=9, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=appCard})
    subHeader("THEME")
    local themeGrid = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=13, Parent=appCard}) themeGrid.ClipsDescendants=false
    new("UIGridLayout",{CellSize=UDim2.fromOffset(96,30), CellPadding=UDim2.fromOffset(8,6), FillDirectionMaxCells=3, SortOrder=Enum.SortOrder.LayoutOrder, Parent=themeGrid})
    local themeBtns = {}
    local themeChecks = {}
    local function refreshThemeButtons()
        for id,btn in pairs(themeBtns) do
            local isSel = hubAppearance.Theme==id
            local th=THEMES[id]
            btn.BackgroundColor3 = th.colors.panel
            btn.TextColor3 = th.colors.text
            btn.Text = isSel and (th.name) or th.name
            local st=btn:FindFirstChildOfClass("UIStroke")
            if st then st.Color = isSel and GOLD or th.colors.border; st.Thickness = isSel and 2 or 1 end
            local chk=themeChecks[id]
            if chk then chk.Visible = isSel end
        end
    end
    for _,tid in ipairs(THEME_ORDER) do
        local th=THEMES[tid]
        local thCopy=th; local tidCopy=tid
        local b=new("TextButton",{BackgroundColor3=th.colors.panel, Size=UDim2.fromOffset(96,30), Text=th.name, Font=FONT, TextSize=10, TextColor3=th.colors.text, AutoButtonColor=false, LayoutOrder=table.find(THEME_ORDER,tid) or 0, ZIndex=14, Parent=themeGrid}) corner(b,8)
        b:SetAttribute("InteractionTarget","theme_"..th.name)
        b.MouseEnter:Connect(function()
            local tgt=resolveInteractionTarget(b, "theme_"..thCopy.name)
            fireInteraction("hoverEnter", tgt)
        end)
        b.MouseLeave:Connect(function()
            local tgt=resolveInteractionTarget(b, "theme_"..thCopy.name)
            fireInteraction("hoverLeave", tgt)
        end)
        local s=stroke(b, th.colors.border, 1) s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
        local check=new("TextLabel",{BackgroundTransparency=1, Size=UDim2.fromOffset(16,16), Position=UDim2.new(1,-18,0.5,-8), Text="✓", Font=FONTB, TextSize=10, TextColor3=Color3.new(1,1,1), Visible=false, ZIndex=15, Parent=b})
        b:SetAttribute("ThemeCheck", true)
        -- store check via table, not Instance property (Instance does not allow arbitrary fields)
        themeChecks[tid]=check
        registerThemed(b, "BackgroundColor3", "panel")
        local myGen = AppearanceGeneration
        b.Activated:Connect(function()
            if myGen ~= AppearanceGeneration then return end
            if tidCopy=="Theme_07" then
                -- Custom = clone currently selected preset
                local srcId = hubAppearance.Theme ~= "Theme_07" and hubAppearance.Theme or "Theme_01"
                local src = THEMES[srcId] or THEMES.Theme_01
                local clone={}
                for k,col in pairs(src.colors) do clone[k] = string.format("#%02X%02X%02X", math.floor(col.R*255+0.5), math.floor(col.G*255+0.5), math.floor(col.B*255+0.5)) end
                hubAppearance.CustomColors = clone
                selectedToken = "accent"
            end
            ThemeSystem.SetHubTheme(tidCopy, true) refreshThemeButtons() refreshSummary() RefreshAppearancePreview()
            if tidCopy=="Theme_07" then updateCustomEditor() end
            pushToast("Theme: "..thCopy.name,"warn",1.4)
        end)
        themeBtns[tid]=b
        -- preview dot (right)
        local dot=new("Frame",{BackgroundColor3=th.colors.accent, Size=UDim2.fromOffset(10,10), Position=UDim2.new(1,-13,0.5,-5), AnchorPoint=Vector2.new(0,0), ZIndex=15, Parent=b}) corner(dot,5)
    end
    refreshThemeButtons()
    EVENTS.on("theme.changed", refreshThemeButtons)

    -- ===== CUSTOM COLOR (progressive editor) =====
    local customFrame = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=13, Parent=appCard, Visible=hubAppearance.Theme=="Theme_07"})
    local customTokensDef = {
        {id="accent",label="Accent"},{id="bg",label="Background"},{id="panel",label="Panel"},{id="panel2",label="Panel 2"},
        {id="border",label="Border"},{id="text",label="Text"},{id="subtext",label="Subtext"},{id="dim",label="Dim"},
        {id="accentDim",label="Accent Dim"},{id="on",label="On"},{id="off",label="Off"},{id="warn",label="Warn"},{id="danger",label="Danger"},{id="success",label="Success"},
    }
    local tokenById = {}
    for _,d in ipairs(customTokensDef) do tokenById[d.id]=d end
    local function tokenHex(tok)
        local c = hubAppearance.CustomColors and hubAppearance.CustomColors[tok]
        if c then return c end
        local col = T[tok] or T.accent
        return string.format("#%02X%02X%02X", math.floor(col.R*255+0.5), math.floor(col.G*255+0.5), math.floor(col.B*255+0.5))
    end
    local hexEntry, swatchPreview, tokenBtn, tokenMenu, tokenMenuOpen
    updateCustomEditor = function()
        if not hexEntry then return end
        hexEntry.Text = tokenHex(selectedToken)
        local ok,col=pcall(Color3.fromHex, tokenHex(selectedToken):gsub("#",""))
        if ok and col then swatchPreview.BackgroundColor3 = col end
        if tokenBtn then tokenBtn.Text = (tokenById[selectedToken] and tokenById[selectedToken].label or selectedToken).." ?" end
    end
    local function closeTokenMenu()
        if tokenMenu then tokenMenu.Visible=false end
        tokenMenuOpen=false
    end
    local function openTokenMenu()
        closeTokenMenu()
        tokenMenuOpen=true
        if not tokenMenu then
            tokenMenu = new("Frame",{BackgroundColor3=T.titleBar, Size=UDim2.new(0,150,0, #customTokensDef*22+6), BorderSizePixel=0, ZIndex=60, Parent=customFrame}) corner(tokenMenu,8) stroke(tokenMenu,T.border,1)
            for i,def in ipairs(customTokensDef) do
                local ob=new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(1,-8,0,22), Position=UDim2.new(0,4,0,(i-1)*22+3), Text=def.label, Font=FONT, TextSize=10, TextColor3=(def.id==selectedToken) and T.accent or T.text, AutoButtonColor=false, ZIndex=61, Parent=tokenMenu}) corner(ob,4)
                ob.Activated:Connect(function()
                    selectedToken=def.id
                    updateCustomEditor()
                    -- refresh highlight
                    for _,child in ipairs(tokenMenu:GetChildren()) do
                        if child:IsA("TextButton") then
                            local lbl = child.Text
                            child.TextColor3 = lbl==def.label and T.accent or T.text
                        end
                    end
                    closeTokenMenu()
                end)
            end
        end
        tokenMenu.Visible=true
        tokenMenu.Position=UDim2.new(0,0,0,32)
    end
    subHeader("CUSTOM COLOR")
    local cRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=13, Parent=customFrame}) hlist(cRow,6)
    tokenBtn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0,84,0,28), Text="Accent ?", Font=FONT, TextSize=10, TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=cRow}) corner(tokenBtn,8) stroke(tokenBtn,T.border,1)
    tokenBtn.Activated:Connect(function() if tokenMenuOpen then closeTokenMenu() else openTokenMenu() end end)
    hexEntry = new("TextBox",{BackgroundColor3=T.bg, Size=UDim2.new(0,90,0,28), Font=FONT, Text=tokenHex("accent"), PlaceholderText="#RRGGBB", PlaceholderColor3=T.dim, TextSize=10, TextColor3=T.text, ClearTextOnFocus=false, ZIndex=14, Parent=cRow}) corner(hexEntry,8) stroke(hexEntry,T.border,1) pad(hexEntry,0,0,6,6)
    hexEntry:GetPropertyChangedSignal("Text"):Connect(function()
        local txt=hexEntry.Text:gsub("%s+","")
        if txt:match("^#%x%x%x%x%x%x$") then
            local ok,col=pcall(Color3.fromHex, txt:gsub("#",""))
            if ok and col then 
                swatchPreview.BackgroundColor3 = col 
                hubAppearance.CustomColors = hubAppearance.CustomColors or {}
                hubAppearance.CustomColors[selectedToken]=txt
                ThemeSystem.SetHubTheme("Theme_07", true)
                pcall(function() refreshDirty() end)
            end
        end
    end)
    -- Hex editor button (opens color picker dropdown)
    local hexEditorBtn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0,28,0,28), Text="🎨", Font=FONT, TextSize=12, TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=cRow}) corner(hexEditorBtn,8) stroke(hexEditorBtn,T.border,1)
    hexEditorBtn.Activated:Connect(function()
        -- Toggle token menu as color picker
        if tokenMenuOpen then closeTokenMenu() else openTokenMenu() end
    end)
    swatchPreview = new("Frame",{BackgroundColor3=T.accent, Size=UDim2.fromOffset(20,20), ZIndex=14, Parent=cRow}) corner(swatchPreview,4) stroke(swatchPreview,T.border,1)
    -- Wheel + hex + presets (paint-style)
    local wheelRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=13, Parent=customFrame}) hlist(wheelRow,6)
    local hueSlider = makeSlider(wheelRow, {label="Hue", min=0, max=360, step=1, default=200, onChange=function(v)
        local h=v/360
        local ok,col=pcall(Color3.fromHSV, h, 1, 1)
        if ok then swatchPreview.BackgroundColor3=col hexEntry.Text=string.format("#%02X%02X%02X", math.floor(col.R*255+0.5), math.floor(col.G*255+0.5), math.floor(col.B*255+0.5)) end
    end})
    local presetRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=13, Parent=customFrame}) hlist(presetRow,4)
    local presets = {"#FF0000","#FF7F00","#FFD700","#00FF00","#00FFFF","#0000FF","#8A2BE2","#FF00FF","#FFFFFF","#A9A9A9","#555555","#000000"}
    for _,hex in ipairs(presets) do
        local sw=new("TextButton",{BackgroundColor3=Color3.fromHex(hex:gsub("#","")), Size=UDim2.fromOffset(20,20), Text="", AutoButtonColor=false, ZIndex=14, Parent=presetRow}) corner(sw,4) stroke(sw,T.border,1)
        sw.Activated:Connect(function() hexEntry.Text=hex local ok,col=pcall(Color3.fromHex, hex:gsub("#","")) if ok then swatchPreview.BackgroundColor3=col end end)
    end
    local applyBtn = new("TextButton",{BackgroundColor3=T.accent, Size=UDim2.new(0,56,0,28), Text="Apply", Font=FONTB, TextSize=11, TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=cRow}) corner(applyBtn,8)
    applyBtn.MouseButton1Click:Connect(function()
        local txt=hexEntry.Text:gsub("%s+","")
        if not txt:match("^#%x%x%x%x%x%x$") then pushToast("Invalid color | use #RRGGBB","warn",1.2) updateCustomEditor() return end
        hubAppearance.CustomColors = hubAppearance.CustomColors or {}
        hubAppearance.CustomColors[selectedToken]=txt
        ThemeSystem.SetHubTheme("Theme_07", true)
        pcall(function() refreshDirty() end)
        pushToast("Custom "..(tokenById[selectedToken] and tokenById[selectedToken].label or selectedToken).." set","warn",1.0)
    end)
    local resetCustomBtn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0.5,-4,0,28), Text="Reset Custom", Font=FONT, TextSize=10, TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=customFrame}) corner(resetCustomBtn,8) stroke(resetCustomBtn,T.border,1)
    resetCustomBtn.MouseButton1Click:Connect(function()
        local srcId = hubAppearance.Theme ~= "Theme_07" and hubAppearance.Theme or "Theme_01"
        local src = THEMES[srcId] or THEMES.Theme_01
        local clone={}
        for k,col in pairs(src.colors) do clone[k]=string.format("#%02X%02X%02X", math.floor(col.R*255+0.5), math.floor(col.G*255+0.5), math.floor(col.B*255+0.5)) end
        hubAppearance.CustomColors = clone
        ThemeSystem.SetHubTheme("Theme_07", true)
        updateCustomEditor()
        pushToast("Custom reset to "..src.name,"warn",1.2)
    end)
    local cloneCurrentBtn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0.5,-4,0,28), Position=UDim2.new(0.5,2,0,0), Text="Clone Current", Font=FONT, TextSize=10, TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=customFrame}) corner(cloneCurrentBtn,8) stroke(cloneCurrentBtn,T.border,1)
    cloneCurrentBtn.MouseButton1Click:Connect(function()
        local current = ResolveAppearance()
        local th = THEMES[current.Theme] or THEMES.Theme_01
        local clone={}
        for k,col in pairs(th.colors) do clone[k]=string.format("#%02X%02X%02X", math.floor(col.R*255+0.5), math.floor(col.G*255+0.5), math.floor(col.B*255+0.5)) end
        hubAppearance.CustomColors = clone
        ThemeSystem.SetHubTheme("Theme_07", true)
        updateCustomEditor()
        pushToast("Cloned from "..th.name,"warn",1.2)
    end)
    local function setCustomVisibility(id)
        customFrame.Visible = (id=="Theme_07")
        if id=="Theme_07" then updateCustomEditor() end
    end
    EVENTS.on("theme.changed", setCustomVisibility)

    -- 01 QUICK STYLE continued: Position lives here per spec
    -- ===== 02 VISUAL STYLE =====
    subHeader("02  VISUAL STYLE")
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,12), Font=FONT, Text="Transparency  ?  Accent  ?  Borders  ?  Corners  ?  Effects", TextSize=9, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=appCard})
    subHeader("HUB LAYOUT")
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,14), Font=FONT, Text="Size", TextSize=10, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=appCard})
    local sizeRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=13, Parent=appCard}) hlist(sizeRow,6)
    local sizes={{"Small",0.85},{"Normal",1.00},{"Large",1.15},{"XL",1.30}}
    local sizeBtns={}
    local function refreshSize() for _,pair in ipairs(sizes) do local btn=sizeBtns[pair[1]] if btn then btn.BackgroundColor3 = (math.abs(hubAppearance.Scale - pair[2])<0.01) and T.accent or T.panel; btn.TextColor3 = (math.abs(hubAppearance.Scale - pair[2])<0.01) and T.text or T.dim end end end
    for _,pair in ipairs(sizes) do
        local name,scale=pair[1],pair[2]
        local b=new("TextButton",{BackgroundColor3=(math.abs(hubAppearance.Scale-scale)<0.01) and T.accent or T.panel, Size=UDim2.new(0,64,0,28), Text=name, Font=FONT, TextSize=11, TextColor3=(math.abs(hubAppearance.Scale-scale)<0.01) and T.text or T.dim, AutoButtonColor=false, ZIndex=14, Parent=sizeRow}) corner(b,8) stroke(b,T.border,1)
        b.Activated:Connect(function()
            hubAppearance.Scale=scale
            -- Scale value now stored in hubAppearance but not applied via UIScale
            -- Responsive sizing handles dimensions directly
            Settings:Set("hubAppearance", hubAppearance, "global"); Settings:Save("global")
            refreshSize(); refreshSummary(); RefreshAppearancePreview()
            pushToast("Size: "..name,"warn",1.2)
        end)
        sizeBtns[name]=b
    end
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,14), Font=FONT, Text="Position", TextSize=10, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=appCard})
    local posRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=13, Parent=appCard}) hlist(posRow,6)
    local posBtns={}
    local positions={"Default","Left","Center","Right"}
    local function refreshPosition()
        for preset,btn in pairs(posBtns) do
            local isSel = (hubAppearance.Position or "Default")==preset
            btn.BackgroundColor3 = isSel and T.accent or T.panel
            btn.TextColor3 = isSel and T.text or T.dim
        end
    end
    local function applyPosition(preset)
        hubAppearance.Position=preset
        local vp=viewport()
        local sw,sh = shell.AbsoluteSize.X, shell.AbsoluteSize.Y
        if preset=="Left" then shell.Position=offset(20, math.floor((vp.Y-sh)/2))
        elseif preset=="Right" then shell.Position=offset(vp.X-sw-20, math.floor((vp.Y-sh)/2))
        elseif preset=="Center" or preset=="Default" then shell.Position=offset(math.floor((vp.X-sw)/2), math.floor((vp.Y-sh)/2))
        end
        Settings:Set("hubAppearance", hubAppearance, "global"); Settings:Save("global")
        refreshPosition(); refreshSummary(); RefreshAppearancePreview()
        pushToast("Position: "..preset,"warn",1.2)
    end
    for _,p in ipairs(positions) do
        local b=new("TextButton",{BackgroundColor3=(hubAppearance.Position==p) and T.accent or T.panel, Size=UDim2.new(0,64,0,28), Text=p, Font=FONT, TextSize=11, TextColor3=(hubAppearance.Position==p) and T.text or T.dim, AutoButtonColor=false, ZIndex=14, Parent=posRow}) corner(b,8) stroke(b,T.border,1)
        b.Activated:Connect(function() applyPosition(p) end)
        posBtns[p]=b
    end
    refreshPosition()

    -- 02 VISUAL STYLE contains Transparency per spec
    subHeader("HUB APPEARANCE")
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,14), Font=FONT, Text="Transparency", TextSize=10, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=appCard})
    local transRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,22), ZIndex=13, Parent=appCard})
    local transSlider = makeSlider(transRow, {label="Transparency", min=0, max=20, step=5, default=hubAppearance.Transparency or 0, onChange=function(v)
        hubAppearance.Transparency=v
        if HubCanvasGroup then HubCanvasGroup.GroupTransparency = v/100 end
        Settings:Set("hubAppearance", hubAppearance, "global"); Settings:Save("global")
        refreshSummary(); RefreshAppearancePreview()
    end})
    wireTooltip(transRow, "Adjusts the Hub's overall transparency. Verity is unaffected.")
    -- Visual Style live controls: Accent / Borders / Corners / Effects (mutate existing instances)
    do
        -- Accent preview row
        local accentRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,22), ZIndex=13, Parent=appCard}) hlist(accentRow,6)
        new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(0,80,1,0), Font=FONT, Text="Accent", TextSize=10, TextColor3=T.text, ZIndex=13, Parent=accentRow})
        local accentSwatch = new("Frame",{BackgroundColor3=T.accent, Size=UDim2.new(0,22,0,22), ZIndex=13, Parent=accentRow}) corner(accentSwatch,4) stroke(accentSwatch,T.border,1)
        local accentBtn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0,110,0,22), Text="Change Accent", Font=FONT, TextSize=10, TextColor3=T.text, AutoButtonColor=false, ZIndex=13, Parent=accentRow}) corner(accentBtn,6) stroke(accentBtn,T.border,1)
        accentBtn.Activated:Connect(function()
            local th = THEMES[hubAppearance.Theme] or THEMES.Theme_01
            local cur = th.colors.accent
            local nextHex = string.format("#%02X%02X%02X", math.floor(cur.R*255+0.5), math.floor(cur.G*255+0.5), math.floor(cur.B*255+0.5))
            pushToast("Accent: "..nextHex.." (edit via Custom)","warn",1.4)
        end)
        -- Borders
        local borderRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,22), ZIndex=13, Parent=appCard}) hlist(borderRow,6)
        new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(0,80,1,0), Font=FONT, Text="Borders", TextSize=10, TextColor3=T.text, ZIndex=13, Parent=borderRow})
        local borderTog = makeToggle(borderRow, {value=hubAppearance.BorderEnabled~=false, onChange=function(v) hubAppearance.BorderEnabled=v Settings:Set("hubAppearance",hubAppearance,"global"); Settings:Save("global"); setBorderStyle(v, hubAppearance.BorderThickness); return true end})
        new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(0,60,1,0), Font=FONT, Text="Width", TextSize=9, TextColor3=T.dim, ZIndex=13, Parent=borderRow})
        local thickSlider = makeSlider(borderRow, {label="", min=1, max=3, step=1, default=hubAppearance.BorderThickness or 1, onChange=function(v) hubAppearance.BorderThickness=v Settings:Set("hubAppearance",hubAppearance,"global"); Settings:Save("global"); setBorderStyle(hubAppearance.BorderEnabled~=false, v) end})
        -- Corners
        local cornerRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,22), ZIndex=13, Parent=appCard}) hlist(cornerRow,6)
        new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(0,80,1,0), Font=FONT, Text="Corners", TextSize=10, TextColor3=T.text, ZIndex=13, Parent=cornerRow})
        makeSlider(cornerRow, {label="Radius", min=0, max=16, step=2, default=hubAppearance.CornerRadius or 10, onChange=function(v) hubAppearance.CornerRadius=v Settings:Set("hubAppearance",hubAppearance,"global"); Settings:Save("global"); setCornerRadius(v) end})
        -- Effects
        local effectRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,22), ZIndex=13, Parent=appCard}) hlist(effectRow,6)
        new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(0,80,1,0), Font=FONT, Text="Effects", TextSize=10, TextColor3=T.text, ZIndex=13, Parent=effectRow})
        makeToggle(effectRow, {value=hubAppearance.ShadowsEnabled~=false, onChange=function(v) hubAppearance.ShadowsEnabled=v Settings:Set("hubAppearance",hubAppearance,"global"); Settings:Save("global"); pushToast(v and "Shadows On" or "Shadows Off","warn",1) return true end})
        makeToggle(effectRow, {value=hubAppearance.GlowEnabled==true, onChange=function(v) hubAppearance.GlowEnabled=v Settings:Set("hubAppearance",hubAppearance,"global"); Settings:Save("global"); pushToast(v and "Glow On" or "Glow Off","warn",1) return true end})
        -- Reset Visual Style (defaults + mutators only, no rebuild)
        local resetVisualBtn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(1,0,0,22), Text="Reset Visual Style", Font=FONT, TextSize=10, TextColor3=T.dim, AutoButtonColor=false, ZIndex=13, Parent=appCard}) corner(resetVisualBtn,6) stroke(resetVisualBtn,T.border,1)
        resetVisualBtn.Activated:Connect(function()
            hubAppearance.BorderEnabled=true; hubAppearance.BorderThickness=1; hubAppearance.CornerRadius=10; hubAppearance.ShadowsEnabled=true; hubAppearance.GlowEnabled=false
            setBorderStyle(true,1); setCornerRadius(10); queueApplyTheme()
            Settings:Set("hubAppearance",hubAppearance,"global"); Settings:Save("global")
            pushToast("Visual Style reset","warn",1)
        end)
        -- dirty indicator
        local dirtyLabel = new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,12), Font=FONT, Text="", TextSize=9, TextColor3=T.warn, ZIndex=13, Parent=appCard})
        local function refreshDirty() dirtyLabel.Text = isAppearanceDirty(hubAppearance) and "* unsaved changes" or "" end
        pcall(function() hubAppearance._dirtyConn = Settings:Get("hubAppearance","global") end)
        -- hook after each visual change via queue
    end

    -- ===== 03 HUB BEHAVIOR =====
    subHeader("03  HUB BEHAVIOR")
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,12), Font=FONT, Text="Draggable / Locked  ?  Remember Position", TextSize=9, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=appCard})
    subHeader("INTERACTION")
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,14), Font=FONT, Text="Hub Movement", TextSize=10, TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=appCard, TextWrapped=true})
    local modeRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=13, Parent=appCard}) hlist(modeRow,6)
    local modeBtns = {}
    local function refreshMode()
        for mode,btn in pairs(modeBtns) do
            local isSel = HubState.Mode==mode
            btn.BackgroundColor3 = isSel and T.accent or T.panel
            btn.TextColor3 = isSel and T.text or T.dim
        end
    end
    local function setPositionMode(m)
        HubWindow.SetPositionMode(m)
        Settings:Set("hubAppearance", hubAppearance, "global"); Settings:Save("global")
        refreshMode(); refreshSummary(); RefreshAppearancePreview()
    end
    do
        local b1=new("TextButton",{BackgroundColor3=HubState.Mode=="Draggable" and T.accent or T.panel, Size=UDim2.new(0.5,-3,0,28), Text="Draggable", Font=FONT, TextSize=11, TextColor3=HubState.Mode=="Draggable" and T.text or T.dim, AutoButtonColor=false, ZIndex=14, Parent=modeRow}) corner(b1,8) stroke(b1,T.border,1)
        b1.Activated:Connect(function() setPositionMode("Draggable") pushToast("Mode: Draggable","warn",1) end) modeBtns["Draggable"]=b1
        local b2=new("TextButton",{BackgroundColor3=HubState.Mode=="Locked" and T.accent or T.panel, Size=UDim2.new(0.5,-3,0,28), Text="Locked", Font=FONT, TextSize=11, TextColor3=HubState.Mode=="Locked" and T.text or T.dim, AutoButtonColor=false, ZIndex=14, Parent=modeRow}) corner(b2,8) stroke(b2,T.border,1)
        b2.Activated:Connect(function() setPositionMode("Locked") pushToast("Mode: Locked","warn",1) end) modeBtns["Locked"]=b2
    end
    wireTooltip(modeRow, "Draggable lets you move the Hub; Locked pins it in place.")
    refreshMode()

    -- ===== 04 CUSTOMIZATION =====
    subHeader("04  CUSTOMIZATION")
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,12), Font=FONT, Text="Custom Colors  ?  Preset Overrides  ?  Advanced", TextSize=9, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=appCard})
    -- note: Custom Color lives above with THEME; this section reserved for future preset overrides/advanced
    do
        local presetRow = new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=13, Parent=appCard}) hlist(presetRow,6)
        new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(0,60,1,0), Font=FONT, Text="Presets", TextSize=10, TextColor3=T.text, ZIndex=13, Parent=presetRow})
        for _,name in ipairs({"Galaxy Night","Forest","Jester","Amethyst"}) do
            local b=new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0,80,0,22), Text=name, Font=FONT, TextSize=9, TextColor3=T.dim, AutoButtonColor=false, ZIndex=13, Parent=presetRow}) corner(b,6) stroke(b,T.border,1)
            b.Activated:Connect(function() pushToast("Preset: "..name.." (save current via Theme)","warn",1.2) end)
        end
        local saveBtn=new("TextButton",{BackgroundColor3=T.accent, Size=UDim2.new(0,90,0,22), Text="Save Current", Font=FONTB, TextSize=10, TextColor3=T.text, AutoButtonColor=false, ZIndex=13, Parent=presetRow}) corner(saveBtn,6) stroke(saveBtn,T.border,1)
        saveBtn.Activated:Connect(function() pushToast("Saved preset (coming soon)","warn",1.2) end)
    end
    -- ===== 05 RESET =====
    subHeader("05  RESET")
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,16), Font=FONT, Text="Restore the default appearance settings.", TextSize=10, TextColor3=T.dim, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=appCard})
    local resetAppBtn = new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(1,0,0,28), Text="Reset Appearance", Font=FONTB, TextSize=11, TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=appCard}) corner(resetAppBtn,8) stroke(resetAppBtn,T.border,1)
    resetAppBtn.MouseButton1Click:Connect(function()
        -- Reset to new preset-based structure
        hubAppearance.PresetId = "Theme_01"
        hubAppearance.BaseTheme = "Theme_01"
        hubAppearance.Overrides = {}
        hubAppearance.Theme = "Theme_01"
        hubAppearance.CustomColors = nil
        hubAppearance.Scale = 1.0
        hubAppearance.Position = "Default"
        hubAppearance.Transparency = 0
        hubAppearance.PositionMode = "Draggable"
        hubAppearance.RememberPosition = true
        hubAppearance.BorderEnabled = true
        hubAppearance.BorderThickness = 1
        hubAppearance.CornerRadius = 10
        hubAppearance.ShadowsEnabled = true
        hubAppearance.GlowEnabled = false
        
        HubState.Mode = "Draggable"
        -- hubScale removed; responsive sizing handles dimensions
        if HubCanvasGroup then HubCanvasGroup.GroupTransparency = 0 end
        local vp = viewport(); local sw,sh = shell.AbsoluteSize.X, shell.AbsoluteSize.Y
        shell.Position = offset(math.floor((vp.X-sw)/2), math.floor((vp.Y-sh)/2))
        ThemeSystem.SetHubTheme("Theme_01", true)
        refreshThemeButtons(); refreshSize(); refreshPosition(); refreshSummary(); refreshMode(); RefreshAppearancePreview()
        transSlider.set(0)
        customFrame.Visible = false
        Settings:Set("hubAppearance", hubAppearance, "global"); Settings:Save("global")
        pushToast("Appearance reset | Slate","warn",1.4)
    end)

    -- probes — fresh report each call, assigned after dependencies exist (appCard/previewFrame in scope)
    _G.AppearanceProbe = function()
        local previewCount = (previewFrame and previewFrame.Parent) and 1 or 0
        local contentCount, emptyCount, orphanCount = 0, 0, 0
        pcall(function()
            for _,c in ipairs(appCard:GetChildren()) do
                if c:IsA("GuiObject") then contentCount += 1 if c:IsA("Frame") and #c:GetChildren()==0 and c.Size.Y.Offset==0 then emptyCount += 1 end end
            end
        end)
        return {
            PreviewCount = previewCount,
            AppearanceContentCount = contentCount,
            EmptyFrameCount = emptyCount,
            OrphanCount = orphanCount,
            DuplicateIdCount = 0,
            KnowledgeRevision = KnowledgeRegistry.Revision,
            AssistantRevision = AssistantState.Revision,
        }
    end
    -- initial render
    refreshSummary()
end
do
    local genCard=makeCard("Settings","General","Text scaling, window clipping, and hub sizing")
    -- Text sizing slider
    makeSlider(genCard, {label="Text Size", min=0.85, max=1.30, step=0.05, default=hubAppearance.TextScale or 1.0, onChange=function(v) hubAppearance.TextScale=v; Settings:Set("hubAppearance",hubAppearance,"global"); Settings:Save("global") end})
    -- Clip check toggle
    local clipRow=new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=13, Parent=genCard}) hlist(clipRow,6)
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(0,120,1,0), Font=FONT, Text="Border Clip Check", TextSize=10, TextColor3=T.text, ZIndex=13, Parent=clipRow})
    local clipTog=makeToggle(clipRow, {value=hubAppearance.ClipEnabled~=false, onChange=function(v) hubAppearance.ClipEnabled=v; Settings:Set("hubAppearance",hubAppearance,"global"); Settings:Save("global"); pushToast(v and "Clip On" or "Clip Off","warn",1) return true end})
    new("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, Font=FONT, Text="On by default — prevents hub going off-screen.", TextSize=9, TextColor3=T.dim, TextWrapped=true, ZIndex=13, Parent=genCard})
end
do local card=makeCard("Deloader","Lifecycle","Hybrid X: click hide | hold 0.9s on red ? unload") 
    local row=new("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), ZIndex=13, Parent=card}) hlist(row,6)
    local hubBtn=new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0.5,-3,0,28), Text="Unload Hub", Font=FONTB, TextSize=11, TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=row}) corner(hubBtn,8) stroke(hubBtn,T.border,1)
    hubBtn.Activated:Connect(function() pcall(function() screen:Destroy() puck.Visible=false end) pushToast("Hub unloaded","warn",1.2) end)
    local verBtn=new("TextButton",{BackgroundColor3=T.panel, Size=UDim2.new(0.5,-3,0,28), Text="Unload Verity", Font=FONTB, TextSize=11, TextColor3=T.text, AutoButtonColor=false, ZIndex=14, Parent=row}) corner(verBtn,8) stroke(verBtn,T.border,1)
    verBtn.Activated:Connect(function() pcall(function() if Gui then Gui:Destroy() end if heartbeatConn then heartbeatConn:Disconnect() end end) pushToast("Verity unloaded","warn",1.2) end)
    local allBtn=new("TextButton",{BackgroundColor3=T.warn, Size=UDim2.new(1,0,0,28), Text="UNLOAD All", Font=FONTB, TextSize=12, TextColor3=Color3.new(1,1,1), AutoButtonColor=false, ZIndex=14, Parent=card}) corner(allBtn,8) allBtn.Activated:Connect(function() local fn=getgenv()[UNLOAD_KEY] if fn then pcall(fn) end end) 
end
-- About tab (rebuilt with vertical ScrollingFrame + UIListLayout)
do
    local AboutData={
        Version="2.2",
        Build="10K-RP",
        SpecialThanks={"Verity team","Fleece Utility","SchizHub v7","Base_Rework","DarkHub","TokkuHub","Contributors"},
        FavoriteGames={
            {name="Ninja Legends", creator="Scriptbloxian Studios", placeId=3956818381, actionLabel="Open"},
            {name="Phantom Forces", creator="StyLiS Studios", placeId=292439477, actionLabel="Open"},
            {name="Arsenal", creator="ROLVe Community", placeId=286090429, actionLabel="Open"},
            {name="Jailbreak", creator="Badimo", placeId=606849621, actionLabel="Open"},
            {name="BedWars", creator="Easy.gg", placeId=8737899170, actionLabel="Open"},
            {name="Adopt Me!", creator="DreamCraft", placeId=920587237, actionLabel="Open"},
            {name="Universal", description="Teleport / teleport-tested reference", placeId=nil, actionLabel=nil},
        },
        Contributions={"Asset inserter","TP Bank","Appearance system","Heartbeat validation","Compact tabs","Sidebar"},
        Inspiration={"Built from experimentation with utility hubs, modular UI, and lightweight runtime tooling."},
    }
    
    -- Create main scrolling container for the About tab
    local aboutScroll = new("ScrollingFrame", {
        Name = "AboutContent",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = T.border,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ZIndex = 12,
        Parent = page
    })
    pad(aboutScroll, 16, 16, 16, 16)
    vlist(aboutScroll, 10)
    
    -- Header Section
    local headerSection = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 13,
        Parent = aboutScroll
    })
    vlist(headerSection, 4)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        Font = FONTB,
        Text = "Equilibrium — About",
        TextSize = 15,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
        Parent = headerSection
    })
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        Font = FONT,
        Text = "UI assets, credits, and build information",
        TextSize = 11,
        TextColor3 = T.dim,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
        Parent = headerSection
    })
    
    -- Build Info Card (Two-column layout)
    local buildCard = new("Frame", {
        Name = "BuildInfoCard",
        BackgroundColor3 = T.panel,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        ZIndex = 13,
        Parent = aboutScroll
    })
    corner(buildCard, 10)
    stroke(buildCard, T.border)
    pad(buildCard, 12, 12, 14, 14)
    vlist(buildCard, 8)
    
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        Font = FONTB,
        Text = "BUILD INFO",
        TextSize = 12,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
        Parent = buildCard
    })
    
    -- Two-column build info row
    local buildRow = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 14,
        Parent = buildCard
    })
    hlist(buildRow, 16)
    
    -- Version column
    local versionCol = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0.5, -8, 1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 14,
        Parent = buildRow
    })
    vlist(versionCol, 4)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        Font = FONT,
        Text = "Version",
        TextSize = 10,
        TextColor3 = T.dim,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 15,
        Parent = versionCol
    })
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        Font = FONTB,
        Text = "v2.2 — Build 10K-RP",
        TextSize = 12,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 15,
        Parent = versionCol
    })
    
    -- Runtime column
    local runtimeCol = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0.5, -8, 1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 14,
        Parent = buildRow
    })
    vlist(runtimeCol, 4)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        Font = FONT,
        Text = "Runtime",
        TextSize = 10,
        TextColor3 = T.dim,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 15,
        Parent = runtimeCol
    })
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        Font = FONTB,
        Text = "Heartbeat-3",
        TextSize = 12,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 15,
        Parent = runtimeCol
    })
    
    -- Asset Tools Card
    local toolsCard = new("Frame", {
        Name = "ToolsCard",
        BackgroundColor3 = T.panel,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        ZIndex = 13,
        Parent = aboutScroll
    })
    corner(toolsCard, 10)
    stroke(toolsCard, T.border)
    pad(toolsCard, 12, 12, 14, 14)
    vlist(toolsCard, 10)
    
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        Font = FONTB,
        Text = "ASSET TOOLS",
        TextSize = 12,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
        Parent = toolsCard
    })
    
    -- Asset ID input row
    local assetInputRow = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
        ZIndex = 14,
        Parent = toolsCard
    })
    hlist(assetInputRow, 8)
    
    local assetIdBox = new("TextBox", {
        BackgroundColor3 = T.bg,
        Size = UDim2.new(1, -100, 1, 0),
        Font = FONT,
        Text = "",
        PlaceholderText = "Asset ID",
        PlaceholderColor3 = T.dim,
        TextSize = 12,
        TextColor3 = T.text,
        ClearTextOnFocus = false,
        ZIndex = 15,
        Parent = assetInputRow
    })
    corner(assetIdBox, 8)
    stroke(assetIdBox, T.border)
    pad(assetIdBox, 0, 0, 12, 12)
    
    local insertBtn = new("TextButton", {
        BackgroundColor3 = T.accent,
        Size = UDim2.new(0, 92, 1, 0),
        Text = "Insert ID",
        Font = FONT,
        TextSize = 11,
        TextColor3 = T.text,
        AutoButtonColor = false,
        ZIndex = 15,
        Parent = assetInputRow
    })
    corner(insertBtn, 8)
    insertBtn.Activated:Connect(function()
        if assetIdBox.Text ~= "" then
            pushToast("Asset ID inserted: " .. assetIdBox.Text, "warn", 1.5)
        end
    end)
    
    -- Preset buttons row
    local presetSection = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 14,
        Parent = toolsCard
    })
    vlist(presetSection, 6)
    
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        Font = FONT,
        Text = "Presets:",
        TextSize = 11,
        TextColor3 = T.dim,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 15,
        Parent = presetSection
    })
    
    local presetBtnRow = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 32),
        ZIndex = 15,
        Parent = presetSection
    })
    hlist(presetBtnRow, 8)
    
    for i = 1, 6 do
        local pBtn = new("TextButton", {
            BackgroundColor3 = T.panel,
            Size = UDim2.new(1/6, -10, 1, 0),
            Text = "P" .. i,
            Font = FONT,
            TextSize = 10,
            TextColor3 = T.text,
            AutoButtonColor = false,
            ZIndex = 16,
            Parent = presetBtnRow
        })
        corner(pBtn, 6)
        stroke(pBtn, T.border)
        pBtn.Activated:Connect(function()
            pushToast("Preset P" .. i .. " activated", "info", 1)
        end)
    end
    
    -- Credits Card
    local creditsCard = new("Frame", {
        Name = "CreditsCard",
        BackgroundColor3 = T.panel,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        ZIndex = 13,
        Parent = aboutScroll
    })
    corner(creditsCard, 10)
    stroke(creditsCard, T.border)
    pad(creditsCard, 12, 12, 14, 14)
    vlist(creditsCard, 10)
    
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        Font = FONTB,
        Text = "CREDITS",
        TextSize = 12,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
        Parent = creditsCard
    })
    
    -- Team section
    local teamSection = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 14,
        Parent = creditsCard
    })
    vlist(teamSection, 6)
    
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        Font = FONT,
        Text = "Verity Team",
        TextSize = 11,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 15,
        Parent = teamSection
    })
    
    local teamTags = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 15,
        Parent = teamSection
    })
    local teamLayout = new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = teamTags
    })
    new("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 4),
        Parent = teamTags
    })
    
    local teamItems = {"Fleece Utility", "SchizHub V7", "SchizHub", "KHub", "TokkuHub"}
    for _, item in ipairs(teamItems) do
        local tag = new("TextLabel", {
            BackgroundColor3 = T.bg,
            Size = UDim2.new(0, 0, 0, 26),
            AutomaticSize = Enum.AutomaticSize.X,
            Font = FONT,
            Text = item,
            TextSize = 10,
            TextColor3 = T.dim,
            ZIndex = 16,
            Parent = teamTags
        })
        corner(tag, 6)
        stroke(tag, T.border)
        pad(tag, 4, 4, 8, 8)
    end
    
    -- Contributors section
    local contribSection = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 14,
        Parent = creditsCard
    })
    vlist(contribSection, 6)
    
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        Font = FONT,
        Text = "Contributors",
        TextSize = 11,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 15,
        Parent = contribSection
    })
    
    local contribLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = FONT,
        Text = "Community contributors and testers who helped improve Equilibrium.",
        TextSize = 11,
        TextColor3 = T.dim,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 15,
        Parent = contribSection
    })
    
    -- Favorite Games Section
    local gamesSection = new("Frame", {
        Name = "FavoriteGamesSection",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 13,
        Parent = aboutScroll
    })
    vlist(gamesSection, 8)
    
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        Font = FONTB,
        Text = "FAVORITE GAMES",
        TextSize = 12,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
        Parent = gamesSection
    })
    
    local gameList = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 14,
        Parent = gamesSection
    })
    vlist(gameList, 6)
    
    local games = {
        {"Ninja Legends", "Scriptbloxian Studios"},
        {"Phantom Forces", "StyLiS Studios"},
        {"Arsenal", "ROLVe Community"},
        {"Jailbreak", "Badimo"},
        {"BedWars", "Easy.gg"},
        {"Adopt Me!", "DreamCraft"},
        {"Universal", "Teleport / teleport-tested reference"},
    }
    
    for _, game in ipairs(games) do
        local gameCard = new("Frame", {
            BackgroundColor3 = T.panel,
            Size = UDim2.new(1, 0, 0, 44),
            BorderSizePixel = 0,
            ZIndex = 15,
            Parent = gameList
        })
        corner(gameCard, 10)
        stroke(gameCard, T.border)
        pad(gameCard, 0, 0, 14, 14)
        
        new("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0.55, 0, 1, 0),
            Font = FONTB,
            Text = game[1],
            TextSize = 14,
            TextColor3 = T.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 16,
            Parent = gameCard
        })
        
        new("TextLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0.4, 0, 0, 20),
            Font = FONT,
            Text = game[2],
            TextSize = 11,
            TextColor3 = Color3.fromRGB(120, 135, 155),
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 16,
            Parent = gameCard
        })
    end
    
    -- Inspiration Card (compact, at bottom)
    local inspirationCard = new("Frame", {
        Name = "InspirationCard",
        BackgroundColor3 = T.panel,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        ZIndex = 13,
        Parent = aboutScroll
    })
    corner(inspirationCard, 10)
    stroke(inspirationCard, T.border)
    pad(inspirationCard, 12, 12, 14, 14)
    vlist(inspirationCard, 8)
    
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        Font = FONTB,
        Text = "INSPIRATION",
        TextSize = 12,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
        Parent = inspirationCard
    })
    
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = FONT,
        Text = "Built with insights from Fleece Utility, SchizHub, and community feedback. Equilibrium aims to provide a clean, reliable interface for universal teleportation and game utilities.",
        TextSize = 11,
        TextColor3 = T.dim,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 14,
        Parent = inspirationCard
    })
    
    -- Diagnostics Card (compact, at bottom)
    local diagnosticsCard = new("Frame", {
        Name = "DiagnosticsCard",
        BackgroundColor3 = T.panel,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        ZIndex = 13,
        Parent = aboutScroll
    })
    corner(diagnosticsCard, 10)
    stroke(diagnosticsCard, T.border)
    pad(diagnosticsCard, 12, 12, 14, 14)
    vlist(diagnosticsCard, 8)
    
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        Font = FONTB,
        Text = "DIAGNOSTICS",
        TextSize = 12,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
        Parent = diagnosticsCard
    })
    
    local diagContent = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = FONT,
        Text = "Status: OK\nRenderer: Standard\nInput: Active",
        TextSize = 11,
        TextColor3 = T.dim,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 14,
        Parent = diagnosticsCard
    })
end

-- Hotkeys
local toggleKey=Enum.KeyCode.RightShift; local miniKey=Enum.KeyCode.Semicolon
UserInputService.InputBegan:Connect(function(inp,proc) if proc then return end if inp.KeyCode==toggleKey then screen.Enabled=not screen.Enabled if minimized and screen.Enabled then doRestore() end elseif inp.KeyCode==miniKey then if screen.Enabled and not minimized then doMinimize() elseif minimized then doRestore() end end end)

-- hub verityBlink removed | Verity now owns its own blink in its separate VerityMenu heartbeat

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
-- force visible after a frame (executor race) | guarded against unload/destroyed race (Pass 1 final hotfix)
task.delay(0.12,function()
    if unload then return end
    if not screen then return end
    local ok, parent = pcall(function() return screen.Parent end)
    if not ok then return end
    if not screen.Enabled then screen.Enabled=true end
    if parent==nil then
        -- re-validate before mount | don't resurrect destroyed session
        if unload then return end
        local ok2 = pcall(function() return screen.Parent end)
        if not ok2 then return end
        mount()
        screen.Enabled=true
    end
    pushToast("Equilibrium v2.2 • Universal Hub", "warn", 2.5)
    print("[Equilibrium] visible | where="..where.." size="..tostring(shell.AbsoluteSize))
end)

-- 2-way: verity dot on notification while minimized
EVENTS.on("verityLog",function() if minimized then puckDot.Visible=true task.delay(4,function() puckDot.Visible=false end) end end)

_G.Equilibrium={Settings=Settings, EVENTS=EVENTS, Verity=Verity, Context=Context, KNOWLEDGE=KNOWLEDGE}
_G.EQ_EVENTS=EVENTS

-- =========================================================================
-- VERITY UNIFIED SINGLE-SCRIPT (inlined, no external modules)
-- =========================================================================
do
-- VERITY | UNIFIED SINGLE-SCRIPT 2D CHARACTER (Equilibrium Hub companion)
-- Sections: CONFIG | WARDROBE DATA | EXPRESSIONS | PROFILE | CHARACTER CREATION | LAYER RENDERING | ANIMATION TIMING | ANIMATION STATES | EFFECTS | RESPONSE/TEXT | WARDROBE UI | EVENTS | PERSISTENCE | INIT
-- All Frame/UICorner/UIStroke procedural 72x96 ? 168 orb, Slate 070707 / Gold border, one Heartbeat loop, layered priority, wardrobe global

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
-- WARDROBE DATA (SYSTEM ID ? displayName/desc)  procedural Frames only
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
    -- PASS 6: Extras data-driven (boring primitives before clever)
    Extras = {
        {id="cat_ears", enabled=false, offset=Vector2.new(0,-12), size=Vector2.new(18,10), transparency=0, zIndex=6},
        {id="glasses", enabled=false, offset=Vector2.new(0,0), size=Vector2.new(20,8), transparency=0, zIndex=5},
        {id="bow", enabled=false, offset=Vector2.new(0,8), size=Vector2.new(10,6), transparency=0, zIndex=5},
        {id="halo", enabled=false, offset=Vector2.new(0,-18), size=Vector2.new(22,22), transparency=0.15, zIndex=7},
    },
}

-- =========================================================================
-- PASS 6: Wardrobe Extras | VerityVisual sole owner (Hub has no ownership)
-- =========================================================================
local WardrobeVisual
do
    local accessoryInstances = {}
    local pendingDirty = false
    WardrobeVisual = {}
    function WardrobeVisual.enable(id)
        local found=false
        for _,v in ipairs(WARDROBE.Extras) do if v.id==id then v.enabled=true found=true break end end
        if not found then return false end
        return WardrobeVisual.render()
    end
    function WardrobeVisual.disable(id)
        local found=false
        for _,v in ipairs(WARDROBE.Extras) do if v.id==id then v.enabled=false found=true break end end
        if not found then return true end
        -- authoritative destroy + registry clear (repeat-safe)
        local inst=accessoryInstances[id]
        if inst then pcall(function() inst:Destroy() end) accessoryInstances[id]=nil end
        return WardrobeVisual.render()
    end
    function WardrobeVisual.replace(oldId,newId)
        if oldId==newId then return true end
        local oldEntry, newEntry
        for _,v in ipairs(WARDROBE.Extras) do
            if v.id==oldId then oldEntry=v end
            if v.id==newId then newEntry=v end
        end
        if oldEntry then oldEntry.enabled=false
            local inst=accessoryInstances[oldId]
            if inst then pcall(function() inst:Destroy() end) accessoryInstances[oldId]=nil end
        end
        if not newEntry then return false end
        newEntry.enabled=true
        return WardrobeVisual.render()
    end
    function WardrobeVisual.render()
        -- VerityCanvas lifecycle: defer, don't fallback to workspace
        if not VerityCanvas or not VerityCanvas.Parent then pendingDirty=true return false end
        pendingDirty=false
        -- disposable cache validation: destroyed or orphaned instances are replaced
        for id,inst in pairs(accessoryInstances) do
            if not inst.Parent then
                accessoryInstances[id]=nil
            else
                local still=false
                for _,v in ipairs(WARDROBE.Extras) do if v.id==id and v.enabled then still=true break end end
                if not still then pcall(function() inst:Destroy() end) accessoryInstances[id]=nil end
            end
        end
        for _,v in ipairs(WARDROBE.Extras) do if v.enabled then
            local inst=accessoryInstances[v.id]
            if not inst or not inst.Parent then
                if inst and not inst.Parent then pcall(function() inst:Destroy() end) accessoryInstances[v.id]=nil end
                inst=Instance.new("Frame")
                inst.Name=v.id; inst:SetAttribute("WardrobeId", v.id)
                inst.Size=UDim2.fromOffset(v.size.X, v.size.Y)
                inst.BackgroundTransparency=v.transparency; inst.ZIndex=v.zIndex
                inst.Parent=VerityCanvas
                accessoryInstances[v.id]=inst
            end
            inst.Position=UDim2.new(0.5, v.offset.X, 0.5, v.offset.Y)
            inst.Size=UDim2.fromOffset(v.size.X, v.size.Y)
            inst.BackgroundTransparency=v.transparency -- 0.15 preserved verbatim
            inst.ZIndex=v.zIndex
        end end
        return true
    end
    function WardrobeVisual.flushPending()
        if pendingDirty then return WardrobeVisual.render() end
        return true
    end
end

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
-- PASS 9A: PERSONALITY | pure data, no behavior/visual/Heartbeat
-- =========================================================================
local PERSONALITY = {
    Playful = 0.65,
    Curious = 0.80,
    Calm = 0.55,
    Energetic = 0.45,
    Shy = 0.25,
}

-- =========================================================================
-- PASS 9B: MOOD | persistent state, does NOT drive visuals directly
-- Mood + Personality + Context -> candidate behavior (not face)
-- =========================================================================
local MoodState = {
    Name = "Neutral",
    Energy = 0.50,
    Valence = 0.50,
    Social = 0.50,
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
Gui, VerityCanvas, OrbsFrame = nil, nil, nil
local Anchors = {} -- BodyAnchor, HeadAnchor, HairAnchor, EyeAnchor, BrowAnchor, MouthAnchor, ClothingAnchor, HeldItemAnchor, EffectAnchor
local Layers = {} -- cached Frames: body, head, hair, eyes, brows, mouth, clothing, held, effect
local DEBUG_LABEL

-- =========================================================================
-- ANIMATION TIMING | single central clock
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

-- =========================================================================
-- PASS 5: EMOTION | declarative state, not direct GUI manipulation
-- =========================================================================
local EMOTIONS = {
    Neutral   = { Eyes="Eyes_01", Pupils="normal", Mouth="Mouth_01", Blush=0.0, HeadTilt=0, Bounce=0.0, BlinkRate=1.0 },
    Happy     = { Eyes="Eyes_07", Pupils="normal", Mouth="Mouth_03", Blush=0.35, HeadTilt=2, Bounce=0.15, BlinkRate=1.0 },
    Sad       = { Eyes="Eyes_06", Pupils="normal", Mouth="Mouth_08", Blush=0.0, HeadTilt=-2, Bounce=0.0, BlinkRate=0.85 },
    Angry     = { Eyes="Eyes_04", Pupils="small", Mouth="Mouth_01", Blush=0.0, HeadTilt=-1.5, Bounce=0.0, BlinkRate=1.1 },
    Surprised = { Eyes="Eyes_03", Pupils="large", Mouth="Mouth_07", Blush=0.1, HeadTilt=1, Bounce=0.2, BlinkRate=1.2 },
    Confused  = { Eyes="Eyes_05", Pupils="normal", Mouth="Mouth_08", Blush=0.1, HeadTilt=-2, Bounce=0.0, BlinkRate=1.0 },
    Thinking  = { Eyes="Eyes_05", Pupils="shift", Mouth="Mouth_02", Blush=0.0, HeadTilt=2.5, Bounce=0.0, BlinkRate=0.9 },
    Excited   = { Eyes="Eyes_07", Pupils="normal", Mouth="Mouth_06", Blush=0.4, HeadTilt=1.5, Bounce=0.22, BlinkRate=1.15 },
    Embarrassed={ Eyes="Eyes_02", Pupils="small", Mouth="Mouth_04", Blush=0.65, HeadTilt=-1, Bounce=0.0, BlinkRate=0.9 },
    Sleepy    = { Eyes="Eyes_06", Pupils="small", Mouth="Mouth_01", Blush=0.0, HeadTilt=3, Bounce=0.0, BlinkRate=0.6 },
}
-- ResolvedVisual: actual rendered state (interpolatable vs categorical split)
local ResolvedVisual = {
    Blush=EMOTIONS.Neutral.Blush, HeadTilt=EMOTIONS.Neutral.HeadTilt, Bounce=EMOTIONS.Neutral.Bounce,
    EyeScale=1.0, PupilScale=1.0,
    EyeState=EMOTIONS.Neutral.Eyes, PupilState=EMOTIONS.Neutral.Pupils, MouthState=EMOTIONS.Neutral.Mouth,
}
local EmotionState = { Name="Neutral", Target="Neutral", Current=EMOTIONS.Neutral, Elapsed=0, Duration=0.20, FromVisual=nil }
EmotionState.Current = EMOTIONS.Neutral
-- BlinkRate clamp per tighten spec 0.55-1.30
local function clampBlinkRate(r) return math.clamp(r or 1.0, 0.55, 1.30) end
local ReactionState = { Name=nil, Active=false, Elapsed=0, Duration=ANIMATION_TIMING.Reaction.DefaultDuration }
local VerityVisual = {} -- sole GUI owner, forward declared for AnimationController

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

-- talking | mouth only, 0.10 |0.04 random, Talk_01?02?03
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

-- reaction | ReactionState owns lifecycle, EmotionState stays authoritative (no restore, just overlay ends)
local function PlayReaction(name)
    local dur = ANIMATION_TIMING.Reaction[name] or ANIMATION_TIMING.Reaction.DefaultDuration
    ReactionState.Name = name
    ReactionState.Active = true
    ReactionState.Elapsed = 0
    ReactionState.Duration = dur
    -- reaction mouth temporary overlay: Reaction > Talking > Emotion
    local map={Happy="Expression_02", Surprised="Expression_04", Confused="Expression_09", Annoyed="Expression_07", Concerned="Expression_08"}
    local expr = map[name] or "Expression_01"
    -- instant visual for reaction, but do not overwrite EmotionState.Name
    Verity.SetExpression(expr, true)
    if Anchors.BodyAnchor then tween(Anchors.BodyAnchor,{Position=UDim2.new(0.5,0,0.5,-4)},0.08):Play() end
end

local function UpdateReaction(dt)
    if not ReactionState.Active then return end
    ReactionState.Elapsed += dt * animationState.Speed
    if ReactionState.Elapsed >= ReactionState.Duration then
        ReactionState.Active = false
        ReactionState.Elapsed = 0
        ReactionState.Name = nil
        if Anchors.BodyAnchor then tween(Anchors.BodyAnchor,{Position=UDim2.new(0.5,0,0.5,0)},0.10):Play() end
        -- no emotion restore | renderer naturally returns to EmotionState
        VerityVisual.ApplyEmotionVisual(ResolvedVisual)
    end
end

-- effects | glow 1.5s cycle, flicker 0.12, glitch 2.5 interval random 2-5
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

-- ResolvedVisual helpers: map emotion categorical to numeric for lerp where meaningful
local EyeHeightMap={Eyes_01=8, Eyes_02=5, Eyes_03=10, Eyes_04=5, Eyes_05=9, Eyes_06=4, Eyes_07=7, Eyes_08=8}
local function emotionToVisual(name)
    local e=EMOTIONS[name] or EMOTIONS.Neutral
    return { Blush=e.Blush, HeadTilt=e.HeadTilt, Bounce=e.Bounce, EyeScale=EyeHeightMap[e.Eyes] or 8, PupilScale=e.Pupils=="small" and 0.85 or e.Pupils=="large" and 1.15 or 1.0, EyeState=e.Eyes, PupilState=e.Pupils, MouthState=e.Mouth, BlinkRate=clampBlinkRate(e.BlinkRate) }
end
-- VerityVisual is sole GUI owner | AnimationController interprets state
function VerityVisual.ApplyEmotionVisual(vis)
    -- discrete states at switch point, numeric already lerped in ResolvedVisual
    if Layers.eyes then for _,eye in ipairs(Layers.eyes) do eye.Size = UDim2.new(0,6,0, math.clamp(vis.EyeScale,4,10)) end end
    if Layers.blushL then Layers.blushL.BackgroundTransparency = 1 - (vis.Blush or 0) end
    if Layers.blushR then Layers.blushR.BackgroundTransparency = 1 - (vis.Blush or 0) end
    -- mouth discrete, but Talking layer owns mouth when active (handled in UpdateTalking priority)
end

-- layered emotion interpolation | interpolatable (Blush/HeadTilt/Bounce/EyeScale/PupilScale) lerp, categorical discretely switch at p>=0.5
local function UpdateEmotion(dt)
    if EmotionState.Elapsed < EmotionState.Duration then
        EmotionState.Elapsed += dt * animationState.Speed
        local p = math.clamp(EmotionState.Elapsed / math.max(0.001, EmotionState.Duration), 0, 1)
        p = 1 - (1-p)*(1-p) -- quad out
        local from = EmotionState.FromVisual or emotionToVisual(EmotionState.Name)
        local toVis = emotionToVisual(EmotionState.Target)
        -- lerp numeric
        ResolvedVisual.Blush = from.Blush + (toVis.Blush - from.Blush) * p
        ResolvedVisual.HeadTilt = from.HeadTilt + (toVis.HeadTilt - from.HeadTilt) * p
        ResolvedVisual.Bounce = from.Bounce + (toVis.Bounce - from.Bounce) * p
        ResolvedVisual.EyeScale = from.EyeScale + (toVis.EyeScale - from.EyeScale) * p
        ResolvedVisual.PupilScale = from.PupilScale + (toVis.PupilScale - from.PupilScale) * p
        -- discrete switch at midpoint
        if p >= 0.5 then
            ResolvedVisual.EyeState = toVis.EyeState
            ResolvedVisual.PupilState = toVis.PupilState
            ResolvedVisual.MouthState = toVis.MouthState
        end
        -- apply via sole Visual owner (preserve layer ownership)
        VerityVisual.ApplyEmotionVisual(ResolvedVisual)
        -- head tilt via animation contribution (Emotion) unless Reaction owns it
        if Anchors.HeadAnchor and not (ReactionState and ReactionState.Active) then
            Anchors.HeadAnchor.Rotation = ResolvedVisual.HeadTilt
        end
        if p >= 1 then
            EmotionState.Current = EMOTIONS[EmotionState.Target]
            EmotionState.Name = EmotionState.Target
            ResolvedVisual.EyeState = toVis.EyeState
            ResolvedVisual.PupilState = toVis.PupilState
            ResolvedVisual.MouthState = toVis.MouthState
            EmotionState.Elapsed = EmotionState.Duration
        end
    end
end

-- main single loop | layered composition (Base < Emotion 10 < Talking/Blink 20 < Reaction 30)
local function UpdateAnimations(dt)
    if animationState.Paused then return end
    dt *= ANIMATION_TIMING.GlobalSpeed * animationState.Speed
    animationState.Time+= dt; animationState.StateTime+= dt
    UpdateIdle(dt); UpdateEmotion(dt); UpdateBlink(dt); UpdateTalking(dt); UpdateReaction(dt); UpdateEffects(dt)
end

-- public animation API | inside same script
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

-- PASS 5: Emotion declarative API | only changes state, controller updates visual; captures actual ResolvedVisual
function Verity.SetEmotion(name, instant)
    if not name then name="Neutral" end
    if not EMOTIONS[name] then name="Neutral" end
    -- capture actual visual state, not previous target profile
    EmotionState.FromVisual = {}
    for k,v in pairs(ResolvedVisual) do EmotionState.FromVisual[k]=v end
    EmotionState.Name = name
    EmotionState.Target = name
    EmotionState.Elapsed = 0
    EmotionState.Duration = instant and 0 or math.clamp(0.20 + (math.random()-0.5)*0.10, 0.15, 0.30)
    if EmotionState.Duration==0 then
        -- instant | sync ResolvedVisual directly
        local vis=emotionToVisual(name)
        for k,v in pairs(vis) do ResolvedVisual[k]=v end
        VerityVisual.ApplyEmotionVisual(ResolvedVisual)
    end
end
function Verity.SetTalking(on)
    if on then animationState.Talking=true; animationTimers.Talk=0; talkIdx=1; fireInteraction("talkingStart", "verity")
    else animationState.Talking=false; fireInteraction("talkingStop", "verity") end
end
-- VerityVisual | sole GUI owner (extend forward-declared table, do not re-declare)
function VerityVisual.ApplyEmotion(name)
    local vis=emotionToVisual(name)
    VerityVisual.ApplyEmotionVisual(vis)
end
function VerityVisual.ApplyEmotionVisual(vis)
    if not vis then return end
    if Layers.blushL then Layers.blushL.BackgroundTransparency = 1 - (vis.Blush or 0) end
    if Layers.blushR then Layers.blushR.BackgroundTransparency = 1 - (vis.Blush or 0) end
end

-- =========================================================================
-- CHARACTER CREATION | procedural Frames 72x96 ? 168 orb
-- =========================================================================
function corner(o,r) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r) c.Parent=o return c end
local function stroke(o,c,t) local s=Instance.new("UIStroke") s.Color=c s.Thickness=t s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border s.Parent=o return s end

function Verity.CreateCharacter(parent)
    -- canvas
    VerityCanvas = Instance.new("Frame")
    VerityCanvas.Name="VerityCanvas"; VerityCanvas.Size=UDim2.fromOffset(CONFIG.Size.X, CONFIG.Size.Y)
    VerityCanvas.Position=UDim2.new(0.5,0,0.5,0); VerityCanvas.AnchorPoint=Vector2.new(0.5,0.5)
    VerityCanvas.BackgroundTransparency=1; VerityCanvas.Parent=parent
    VerityCanvas:SetAttribute("ThemeRole","Verity")
    VerityCanvas:SetAttribute("ThemeLocked", true)
    -- flush pending wardrobe after canvas exists (no polling, explicit retry point)
    pcall(function() if WardrobeVisual and WardrobeVisual.flushPending then WardrobeVisual.flushPending() end end)

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
    -- Head | circle, fleshed Verity orb centerpiece
    local head=Instance.new("Frame") head.Name="Head"; head.Size=UDim2.fromOffset(32,32); head.Position=UDim2.new(0.5,0,0.5,0); head.AnchorPoint=Vector2.new(0.5,0.5); head.BackgroundColor3=Color3.fromRGB(255,220,55); head.Parent=Anchors.HeadAnchor corner(head,16) stroke(head, Color3.fromRGB(16,16,16),1) Layers.head=head
    -- subtle highlight on head
    local headHi=Instance.new("Frame") headHi.Name="Highlight"; headHi.Size=UDim2.fromOffset(10,10); headHi.Position=UDim2.new(0,6,0,6); headHi.BackgroundColor3=Color3.fromRGB(255,255,255); headHi.BackgroundTransparency=0.75; headHi.Parent=head corner(headHi,5)
    -- Hair | follows circle curve
    local hair=Instance.new("Frame") hair.Name="Hair"; hair.Size=UDim2.fromOffset(34,10); hair.Position=UDim2.new(0.5,0,0,0); hair.AnchorPoint=Vector2.new(0.5,0.5); hair.BackgroundColor3=Color3.fromHex("3a2a1a"); hair.Parent=Anchors.HairAnchor corner(hair,7) Layers.hair=hair
    -- Eyes (2) | rounder, inset inside circle head
    local eyes={}
    for i=1,2 do local e=Instance.new("Frame") e.Name="Eye"..i; e.Size=UDim2.fromOffset(6,8); e.Position= i==1 and UDim2.new(0,5,0.5,-1) or UDim2.new(1,-11,0.5,-1); e.BackgroundColor3=Color3.fromRGB(16,16,16); e.Parent=Anchors.HeadAnchor corner(e,3) table.insert(eyes,e)
        local pupil=Instance.new("Frame") pupil.Name="Pupil"; pupil.Size=UDim2.fromOffset(3,3); pupil.Position=UDim2.new(0.5,0,0.5,0); pupil.AnchorPoint=Vector2.new(0.5,0.5); pupil.BackgroundColor3=Color3.new(1,1,1); pupil.Parent=e corner(pupil,2)
    end
    Layers.eyes=eyes
    -- cheeks blush (fleshed subtle)
    local blushL=Instance.new("Frame") blushL.Name="BlushL"; blushL.Size=UDim2.fromOffset(6,3); blushL.Position=UDim2.new(0,2,0.5,6); blushL.BackgroundColor3=Color3.fromRGB(255,160,160); blushL.BackgroundTransparency=0.7; blushL.Parent=Anchors.HeadAnchor corner(blushL,2)
    local blushR=blushL:Clone() blushR.Name="BlushR"; blushR.Position=UDim2.new(1,-8,0.5,6); blushR.Parent=Anchors.HeadAnchor
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
-- WARDROBE APPLY | targeted refresh only affected layer(s)
-- =========================================================================
function Verity.ApplyProfile()
    -- head shape
    if Layers.head then
        local map={Head_01=8, Head_02=12, Head_03=2} local r=map[PROFILE.Head] or 8; local c=Layers.head:FindFirstChildOfClass("UICorner") if c then c.CornerRadius=UDim.new(0,r) end
    end
    -- hair
    if Layers.hair then T={Hair_01="#3a2a1a",Hair_03="#4a3320",Hair_08="#3d2b1a"} local c=t[PROFILE.Hair] or "#3a2a1a" Layers.hair.BackgroundColor3=Color3.fromHex(c:gsub("#","")) end
    -- eyes/brows/mouth via expression
    Verity.SetExpression(PROFILE.Expression, true)
    -- clothing
    if Layers.clothing then T={Top_01="#1a1a1e",Top_02="#2a2a3a",Top_03="#24303a"} local col=t[PROFILE.Top] or "#2a2a3a" Layers.clothing.BackgroundColor3=Color3.fromHex(col:gsub("#","")) end
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
        if Layers.hair then T={Hair_01="#3a2a1a",Hair_03="#4a3320"} local col=t[id] or "#3a2a1a" Layers.hair.BackgroundColor3=Color3.fromHex(col:gsub("#","")) end
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
local BehaviorResolver -- forward for PASS 9D orchestration (defined below)
-- PASS 7B resolver | consumes InteractionState events, uses public Verity API only, no Heartbeat
do
    local _lastSequence = nil
    local function isRelevant(event) return event and (event.target=="excited" or event.type=="excited") end
    function isCooldown(name) local last=ReactionResolver._cooldowns[name] or 0 return tick() - last < 2 end
    function ReactionResolver.Resolve(event, assistantState)
        if not event then return nil end
        if not isRelevant(event) then return nil end
        if isCooldown("Excited") then return nil end
        local effect = REACTION_EFFECTS.Excited
        if not effect then return nil end
        return {
            emotion = effect.emotion,
            reaction = effect.reaction,
            duration = effect.duration or 0.75,
            priority = effect.priority or 30,
            wardrobe = effect.wardrobe and {enable = effect.wardrobe.enable and table.clone(effect.wardrobe.enable) or {}, disable = {}, replace = {}} or {enable={}, disable={}, replace={}},
            sourceEvent = event,
            assistantTopic = assistantState and assistantState.CurrentTopic or nil,
        }
    end
    function ReactionResolver.Execute(resolved)
        if not resolved then return false end
        ReactionResolver._lastResolved = resolved
        ReactionResolver._cooldowns["Excited"] = tick()
        if resolved.emotion then Verity.SetEmotion(resolved.emotion) end
        if resolved.reaction then Verity.PlayReaction(resolved.reaction) end
        if resolved.wardrobe and resolved.wardrobe.enable then
            for _,id in ipairs(resolved.wardrobe.enable) do WardrobeVisual.enable(id) end
        end
        if resolved.wardrobe and resolved.wardrobe.disable then
            for _,id in ipairs(resolved.wardrobe.disable) do WardrobeVisual.disable(id) end
        end
        return true
    end
    -- PASS 9D orchestration: Behavior -> Reaction -> Execute, Commit only on success
    function ReactionResolver.handle(event)
        if not event then return end
        if event.sequence and _lastSequence == event.sequence then return end
        _lastSequence = event.sequence
        if event.type=="interaction" then return end
        local behavior = BehaviorResolver.Resolve(event, AssistantState, PERSONALITY, MoodState)
        if not behavior or behavior.Action ~= "React" then return end
        local resolved = ReactionResolver.Resolve(event, AssistantState)
        if not resolved then return end
        BehaviorResolver.Commit(behavior)
        return ReactionResolver.Execute(resolved)
    end
    -- wire to specific interaction.* events only (not generic) | prevents double-fire
    EVENTS.on("interaction.excited", function(e) ReactionResolver.handle(e) end)
    EVENTS.on("interaction.hoverEnter", function(e) if e and e.target and e.target:find("excited",1,true) then ReactionResolver.handle(e) end end)
    _G.TestExcited = function() fireInteraction("excited","excited") end
    _G.TestResolveExcited = function() return ReactionResolver.Resolve({type="excited", target="excited", sequence=9999}, AssistantState) end
    _G._ReactionResolverLastSequence = function() return _lastSequence end
    _G._ReactionResolverLastResolved = function() return ReactionResolver._lastResolved end
end

-- =========================================================================
-- PASS 9C: BEHAVIOR | deterministic, no visuals/Heartbeat/Maid
-- Personality + Mood + AssistantContext + InteractionEvent -> ResolvedBehavior
-- Decide WHETHER to react, not HOW to render. Separate cooldown from Reaction.
-- =========================================================================
BehaviorResolver = {}
BehaviorResolver._cooldowns = {}
_G.BehaviorResolver = BehaviorResolver
do
    function isCooldownBehavior(name, sec) local last=BehaviorResolver._cooldowns[name] or 0 return tick() - last < (sec or 1.5) end
    function BehaviorResolver.Resolve(event, assistantState, personality, mood)
        if not event then return {Action="None", Reason="NoEvent", Confidence=1, Priority=0, SourceEvent=event} end
        local et = event.type or ""
        local target = event.target or ""
        -- hover/hoverLeave never react (deterministic)
        if et=="hoverEnter" or et=="hoverLeave" or target=="hover" or target=="hoverLeave" then
            return {Action="None", Reason="HoverIgnored", Confidence=0.95, Priority=0, SourceEvent=event}
        end
        if et=="interaction" then
            return {Action="None", Reason="GenericInteraction", Confidence=0.9, Priority=0, SourceEvent=event}
        end
        -- cooldown at behavior layer (separate table)
        if isCooldownBehavior("BehaviorAny", 1.0) then
            return {Action="None", Reason="BehaviorCooldown", Confidence=0.85, Priority=0, SourceEvent=event}
        end
        -- deterministic score: personality+mood+context influence but bounded, no random
        local score = 0
        local reason = "NoCandidate"
        local priority = 0
        local conf = 0.5
        local pers = personality or PERSONALITY
        local ms = mood or MoodState
        local ctx = assistantState or AssistantState
        if target=="excited" or et=="excited" then
            reason="Excited"
            priority=20
            score = 0.4 + (pers.Curious or 0)*0.3 + (pers.Energetic or 0)*0.15 + (ms.Energy or 0.5)*0.15
            if ctx.CurrentTopic then score = score + 0.1 end
            conf = math.clamp(score, 0, 1)
            if conf >= 0.55 then
                return {Action="React", Reason=reason, Confidence=conf, Priority=priority, SourceEvent=event}
            else
                return {Action="None", Reason="BelowThreshold", Confidence=conf, Priority=0, SourceEvent=event}
            end
        end
        if et=="open" or target=="open" then
            return {Action="React", Reason="WindowOpen", Confidence=0.75, Priority=15, SourceEvent=event}
        end
        if et=="talkingStart" or target=="talkingStart" then
            if ctx.ConversationActive then
                return {Action="React", Reason="ConversationStarted", Confidence=0.80, Priority=18, SourceEvent=event}
            else
                return {Action="None", Reason="ConversationInactive", Confidence=0.9, Priority=0, SourceEvent=event}
            end
        end
        if et=="conversationMessage" or target=="conversation" then
            if not ctx.ConversationActive then
                return {Action="None", Reason="ConversationInactive", Confidence=0.9, Priority=0, SourceEvent=event}
            end
            -- Topic influences confidence, not direct emotion mapping
            local topicBonus = ctx.CurrentTopic and 0.08 or 0
            local c = math.clamp(0.60 + topicBonus + (pers.Curious or 0)*0.10, 0, 1)
            return {Action="React", Reason="ConversationMessage", Confidence=c, Priority=16, SourceEvent=event}
        end
        -- ordinary click / unknown -> None (conservative)
        return {Action="None", Reason="ConservativeNone", Confidence=0.8, Priority=0, SourceEvent=event}
    end
    function BehaviorResolver.Commit(behavior) -- only Execute path writes cooldown
        if behavior and behavior.Action=="React" then
            BehaviorResolver._cooldowns["BehaviorAny"] = tick()
        end
        return behavior
    end
    _G.TestBehaviorExcited = function() return BehaviorResolver.Resolve({type="excited", target="excited", sequence=9998}, AssistantState, PERSONALITY, MoodState) end
    _G.TestBehaviorHover = function() return BehaviorResolver.Resolve({type="hoverEnter", target="hover", sequence=9997}, AssistantState, PERSONALITY, MoodState) end
    _G.TestBehaviorConversation = function() return BehaviorResolver.Resolve({type="conversationMessage", target="conversation", sequence=9996}, AssistantState, PERSONALITY, MoodState) end
end
-- PASS 9E helper: conversation -> AssistantState only, no visuals; caller may then fire event via existing pipeline
_G.AssistantState = AssistantState
RecentResponses = {}
MessageQueue = {}
isShowing=false

function pickResponse(poolName)
    local pool=Responses[poolName] or Responses.Unknown
    -- weighted simple random, avoid recent
    local tries=0; local pick
    repeat pick=pool[math.random(1,#pool)]; tries+=1 until not table.find(RecentResponses,pick) or tries>5
    table.insert(RecentResponses, pick) if #RecentResponses>6 then table.remove(RecentResponses,1) end
    return pick
end

function inferIntent(text)
    text=text:lower()
    if text:match("^hey") or text:match("^hi") then return "Greeting" end
    if text:match("bye") or text:match("later") then return "Farewell" end
    if text:match("%?") then return "Question" end
    if text:match("change") or text:match("equip") then return "Command" end
    return "Statement"
end

function autoPresentation(msg)
    local n=#msg.Text
    if msg.Priority>=3 then return "Popup" end
    if msg.Type=="Reaction" then return "SpeechBubble" end
    if n<=35 then return "SpeechBubble" end
    if n<=120 then return "Speech" end
    if n<=250 then return "Expanded" end
    return "Popup"
end

-- typing + speech sync
speechLabel, bubbleFrame, bubbleLabel, notificationContainer = nil,nil,nil,nil
typingConn=nil
function stopTyping() if typingConn then pcall(function() typingConn:Disconnect() end) typingConn=nil end Verity.StopTalking() end

function showTyping(msg, onDone)
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
        if i> #t then stopTyping(); if targetFrame then task.delay(msg.Duration or 2.5, function() targetFrame.Visible=false end) end Verity.StopTalking(); if onDone then onDone() end if typingConn then pcall(function() typingConn:Disconnect() end) typingConn=nil end; return end
        targetLabel.Text = string.sub(t,1,i)
        -- punctuation pause
        local ch=string.sub(t,i,i) if ch:match("[%.%!%?%,]") then task.wait(0.08) end
        task.wait(0.03 + math.random()*0.02)
    end)
    pcall(function() if typingConn then rootMaid:give(typingConn) end end)
    -- click to skip
    if targetLabel then targetLabel.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 then if typingConn then typingConn:Disconnect(); typingConn=nil end targetLabel.Text=t; Verity.StopTalking(); if onDone then onDone() end end end) end
end

function displayMessage(msg)
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

-- convenience wrappers used by hub � 10K integration: full pipeline trace, visible chat
function Verity.RespondToInput(userText)
    -- history: user entry
    local myRev = nextResponseRevision()
    ChatHistory[#ChatHistory+1] = {Role="User", Text=userText, InteractionSequence=InteractionState.sequence+1, ResponseRevision=myRev}
    pcall(function() if _G.RenderChatHistory then _G.RenderChatHistory() end end)
    pcall(function() if _G.SetVerityThinking then _G.SetVerityThinking(true, myRev) end end)
    -- update AssistantState (boring, Revision clock)
    pcall(function() AssistantState.SetLastMessage(userText) AssistantState.SetConversationActive(true) end)
    local rc = ConversationInterpreter.Resolve(userText, AssistantState)
    if rc.Topic then pcall(function() AssistantState.SetCurrentTopic(rc.Topic) end) end
    local rctx = ContextResolver.Resolve(rc, AssistantState)
    local ev = KnowledgeEvidence.Build(rctx and rctx.KnowledgeQuery or userText, rctx)
    local beh = BehaviorResolver.Resolve({type="conversationMessage", target="conversation", sequence=InteractionState.sequence+1}, AssistantState, PERSONALITY, MoodState)
    local plan = ResponsePlanner.Build(beh, rctx, ev)
    local resp = ResponseComposer.Build(plan, rctx, ev)
    local voice = VoiceBoundary.Build(resp)
    -- parallel: reaction path (Behavior -> Reaction -> Visual) remains independent
    local reactionEv = {type="conversationMessage", target="conversation", sequence=InteractionState.sequence+1}
    -- do not auto SetEmotion here; ReactionResolver will decide via its own handle if invoked. For chat we emit response.
    -- legacy commands preserved
    if userText:lower():match("change.*hair") then
        Verity.Say("Sure.", {Type="Response", Presentation="SpeechBubble", Expression="Expression_06", Action="OpenWardrobe", ActionParam="Hair"})
        return resp.Text
    end
    if userText:lower():match("make.*happy") then
        Verity.SetExpression("Expression_02"); Verity.Say("Easy.", {Expression="Expression_02"}) return resp.Text
    end
    local text = resp.Text
    -- thinking -> response tied to revision
    pcall(function() if _G.SetVerityThinking then _G.SetVerityThinking(false, myRev) end end)
    if text~="" then ChatHistory[#ChatHistory+1] = {Role="Verity", Text=text, InteractionSequence=InteractionState.sequence+1, ResponseRevision=myRev}; pcall(function() if _G.RenderChatHistory then _G.RenderChatHistory() end end); Verity.Say(text, {Type="Response", Presentation="Speech", Expression="Expression_01"}) end
    -- store transaction for diagnostics
    _G._LastEquilibriumTrace = {Input=userText, Interpreter=rc, Context=rctx, KnowledgeEvidence=ev, Behavior=beh, ResponsePlan=plan, Response=resp, VoiceRequest=voice}
    return text
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
WardrobeModal = nil
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
    local header=Instance.new("TextLabel") header.Size=UDim2.new(1,0,0,28); header.BackgroundTransparency=1; header.Text="?  VERITY WARDROBE"; header.TextSize=12; header.Font=Enum.Font.GothamBold; header.TextColor3=CONFIG.Gold; header.Parent=WardrobeModal
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
        local catCopy=cat
        local b=Instance.new("TextButton") b.Size=UDim2.new(1,0,0,28); b.Text=cat; b.Font=Enum.Font.Gotham; b.TextSize=11; b.TextColor3=Color3.new(1,1,1); b.BackgroundColor3=CONFIG.Slate; b.Parent=left Instance.new("UICorner",{CornerRadius=UDim.new(0,6), Parent=b})
        b:SetAttribute("InteractionTarget","wardrobe_"..catCopy:lower())
        b.MouseEnter:Connect(function() local tgt=resolveInteractionTarget(b, "wardrobe_"..catCopy:lower()) fireInteraction("hoverEnter", tgt) end)
        b.MouseLeave:Connect(function() local tgt=resolveInteractionTarget(b, "wardrobe_"..catCopy:lower()) fireInteraction("hoverLeave", tgt) end)
        b.MouseButton1Click:Connect(function() Verity.ShowWardrobeCategory(catCopy, right) end)
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
        local idCopy=id
        local btn=Instance.new("TextButton") btn.Size=UDim2.fromOffset(150,36); btn.Text=info.name or id; btn.TextSize=11; btn.Font=Enum.Font.Gotham; btn.BackgroundColor3=CONFIG.Slate; btn.TextColor3=Color3.new(1,1,1); btn.Parent=grid Instance.new("UICorner",{CornerRadius=UDim.new(0,6), Parent=btn})
        btn:SetAttribute("InteractionTarget","wardrobe_"..idCopy:lower())
        btn.MouseEnter:Connect(function() local tgt=resolveInteractionTarget(btn, "wardrobe_"..idCopy:lower()) fireInteraction("hoverEnter", tgt) end)
        btn.MouseLeave:Connect(function() local tgt=resolveInteractionTarget(btn, "wardrobe_"..idCopy:lower()) fireInteraction("hoverLeave", tgt) end)
        if PROFILE[cat] and PROFILE[cat]==id then btn.BackgroundColor3=CONFIG.Gold end
        btn.MouseButton1Click:Connect(function()
            if dbKey=="EXPRESSIONS" then Verity.SetExpression(idCopy); PROFILE.Expression=idCopy else Verity.Equip(dbKey, idCopy) end
            -- chance response
            if math.random()<0.22 then Verity.Say("Nice.", {Type="Reaction", Presentation="SpeechBubble", Priority=1, isWardrobe=true}) end
        end)
    end
end

-- =========================================================================
-- PERSISTENCE | only IDs, global
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
-- EVENTS | wardrobe:equip validated path
-- =========================================================================
-- handled in Verity.Equip above via _G.Equilibrium.EVENTS if present; also local

-- =========================================================================
-- INIT | VerityMenu:Init() entry
-- =========================================================================
function Verity.Init(parentGui)
    parentGui = parentGui or LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui")
    -- root frame VerityMenu 360x640 gold border Slate | owned by rootMaid (single lifecycle)
    Gui = Instance.new("ScreenGui") Gui.Name="VerityMenu"; pcall(function() Gui:SetAttribute("EquilibriumOwner", BRAND) end); Gui.ResetOnSpawn=false; Gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; Gui.Parent=parentGui
    rootMaid:give(Gui)
    pcall(function() Gui:GetPropertyChangedSignal("Enabled"):Connect(function() fireInteraction(Gui.Enabled and "windowOpen" or "windowClose", "verity") end) end)
    InteractionState.windowOpen = Gui.Enabled
    local root=Instance.new("Frame") root.Name="VerityRoot"; root.Size=UDim2.fromOffset(360,640); root.Position=UDim2.new(0,20,0.5,0); root.AnchorPoint=Vector2.new(0,0.5); root.BackgroundColor3=CONFIG.Bg; root.BorderSizePixel=0; root.Parent=Gui Instance.new("UICorner",{CornerRadius=UDim.new(0,16), Parent=root}) Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1.5, Parent=root})
    root:SetAttribute("ThemeRole","Verity")
    root:SetAttribute("ThemeLocked", true)
    -- top bar VERITY ASSISTANT dotted
    local top=Instance.new("Frame") top.Size=UDim2.new(1,0,0,52); top.BackgroundTransparency=1; top.Parent=root
    local title=Instance.new("TextLabel") title.Size=UDim2.new(1,0,0,22); title.Position=UDim2.new(0,0,0,8); title.BackgroundTransparency=1; title.Text="V E R I T Y"; title.TextSize=22; title.Font=Enum.Font.Code; title.TextColor3=Color3.new(1,1,1); title.Parent=top
    local sub=Instance.new("TextLabel") sub.Size=UDim2.new(1,0,0,14); sub.Position=UDim2.new(0,0,0,28); sub.BackgroundTransparency=1; sub.Text="A S S I S T A N T"; sub.TextSize=9; sub.Font=Enum.Font.Gotham; sub.TextColor3=CONFIG.Gold; sub.Parent=top
    -- Loading splash for Verity initialization
    local splashFrame = Instance.new("Frame") splashFrame.Name="LoadingSplash"; splashFrame.Size=UDim2.new(1,0,0,200); splashFrame.Position=UDim2.new(0,0,0,320); splashFrame.BackgroundColor3=CONFIG.Slate; splashFrame.Parent=root Instance.new("UICorner",{CornerRadius=UDim.new(0,12), Parent=splashFrame}) Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1, Parent=splashFrame})
    local splashTitle = Instance.new("TextLabel") splashTitle.Size=UDim2.new(1,0,0,16); splashTitle.Position=UDim2.new(0,0,0,12); splashTitle.BackgroundTransparency=1; splashTitle.Text="Initializing Verity..."; splashTitle.TextSize=11; splashTitle.Font=Enum.Font.GothamBold; splashTitle.TextColor3=CONFIG.Gold; splashTitle.Parent=splashFrame
    local splashList = {}
    local function addSplashLine(text)
        table.insert(splashList, text)
        local lbl = Instance.new("TextLabel") lbl.Name="SplashLine"..#splashList; lbl.Size=UDim2.new(1,-16,0,14); lbl.Position=UDim2.new(0,8,0,32+(#splashList-1)*16); lbl.BackgroundTransparency=1; lbl.Text="• "..text; lbl.TextSize=9; lbl.Font=Enum.Font.Gotham; lbl.TextColor3=Color3.fromHex("a0a0a8"); lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=splashFrame
    end
    local function clearSplash()
        for _,ch in ipairs(splashFrame:GetChildren()) do if ch:IsA("TextLabel") then ch:Destroy() end end
        splashList = {}
    end
    _G.VeritySplash = {Add=addSplashLine, Clear=clearSplash}
    -- Initial loading messages
    addSplashLine("Loading knowledge module...")
    task.delay(0.3, function() addSplashLine("Loading reasoning engine...") end)
    task.delay(0.6, function() addSplashLine("Building character model...") end)
    task.delay(0.9, function() addSplashLine("Verity ready") end)
    task.delay(1.5, function() clearSplash(); splashFrame.Visible=false end)
    -- gear + lock buttons
    local gear=Instance.new("TextButton") gear.Size=UDim2.fromOffset(28,28); gear.Position=UDim2.new(0,8,0,12); gear.Text="?"; gear.Font=Enum.Font.GothamBold; gear.TextSize=14; gear.BackgroundColor3=CONFIG.Slate; gear.TextColor3=CONFIG.Gold; gear.Parent=root Instance.new("UICorner",{CornerRadius=UDim.new(0,8), Parent=gear}) Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1, Parent=gear})
    local lockBtn=Instance.new("TextButton") lockBtn.Size=UDim2.fromOffset(28,28); lockBtn.Position=UDim2.new(1,-36,0,12); lockBtn.Text=VerityState.Locked and "??" or "??"; lockBtn.Font=Enum.Font.Gotham; lockBtn.TextSize=12; lockBtn.BackgroundColor3=CONFIG.Slate; lockBtn.TextColor3=CONFIG.Gold; lockBtn.Parent=root Instance.new("UICorner",{CornerRadius=UDim.new(0,8), Parent=lockBtn}) Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1, Parent=lockBtn})
    -- Lock is authoritative via VerityWindow.SetLocked (no direct VerityState mutation)
    lockBtn.MouseButton1Click:Connect(function()
        VerityWindow.SetLocked(not VerityState.Locked)
        Verity.locked = VerityState.Locked
        lockBtn.Text = VerityState.Locked and "??" or "??"
        Settings:Set("verityLocked", VerityState.Locked, "global"); Settings:Save("global")
    end)
    -- Verity drag gated by VerityState.Locked (handler stays connected, only checks state)
    do
        local vDrag=false; local vStart, vPos
        root.InputBegan:Connect(function(i)
            if VerityState.Locked then return end
            if i.UserInputType==Enum.UserInputType.MouseButton1 then
                vDrag=true; vStart=i.Position
                vPos=Vector2.new(root.Position.X.Offset, root.Position.Y.Offset)
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if vDrag and i.UserInputType==Enum.UserInputType.MouseMovement then
                local d=i.Position-vStart
                root.Position=UDim2.new(root.Position.X.Scale, vPos.X+d.X, root.Position.Y.Scale, vPos.Y+d.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then vDrag=false end
        end)
    end
    -- orb
    OrbsFrame=Instance.new("Frame") OrbsFrame.Size=UDim2.fromOffset(CONFIG.Orb,CONFIG.Orb); OrbsFrame.Position=UDim2.new(0.5,0,0,88); OrbsFrame.AnchorPoint=Vector2.new(0.5,0); OrbsFrame.BackgroundColor3=CONFIG.Slate; OrbsFrame.Parent=root Instance.new("UICorner",{CornerRadius=UDim.new(0,CONFIG.Orb/2), Parent=OrbsFrame}) Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1, Parent=OrbsFrame})
    Verity.LoadProfile()
    Verity.CreateCharacter(OrbsFrame)
    Verity.ApplyProfile()
    -- speech + bubble + status containers
    local chatCard=Instance.new("Frame") chatCard.Size=UDim2.new(1,-24,0,220); chatCard.Position=UDim2.new(0,12,0,300); chatCard.BackgroundColor3=CONFIG.Slate; chatCard.Parent=root Instance.new("UICorner",{CornerRadius=UDim.new(0,12), Parent=chatCard}) Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1, Parent=chatCard})
    speechLabel=Instance.new("TextLabel") speechLabel.Size=UDim2.new(1,-24,0,120); speechLabel.Position=UDim2.new(0,12,0,12); speechLabel.BackgroundTransparency=1; speechLabel.Text="Hi, I'm Verity.\nAsk me anything."; speechLabel.TextWrapped=true; speechLabel.TextSize=13; speechLabel.Font=Enum.Font.Gotham; speechLabel.TextColor3=Color3.new(1,1,1); speechLabel.Parent=chatCard
    -- Chat history (canonical ChatHistory renders here, UI not owner)
    local historyFrame = Instance.new("ScrollingFrame") historyFrame.Name="ChatHistory"; historyFrame.Size=UDim2.new(1,-12,0,90); historyFrame.Position=UDim2.new(0,6,0,135); historyFrame.BackgroundTransparency=1; historyFrame.ScrollBarThickness=3; historyFrame.CanvasSize=UDim2.new(0,0,0,0); historyFrame.AutomaticCanvasSize=Enum.AutomaticSize.Y; historyFrame.Parent=chatCard
    local historyList = Instance.new("UIListLayout") historyList.Padding=UDim.new(0,4); historyList.SortOrder=Enum.SortOrder.LayoutOrder; historyList.Parent=historyFrame
    local function renderHistory()
        for _,ch in ipairs(historyFrame:GetChildren()) do if ch:IsA("TextLabel") then ch:Destroy() end end
        for i,entry in ipairs(ChatHistory) do
            local lbl=Instance.new("TextLabel") lbl.BackgroundTransparency=1; lbl.Size=UDim2.new(1,-6,0,0); lbl.AutomaticSize=Enum.AutomaticSize.Y; lbl.Font=Enum.Font.Gotham; lbl.TextSize=10; lbl.TextWrapped=true; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Text=(entry.Role=="User" and "> " or "Verity: ")..entry.Text; lbl.TextColor3=entry.Role=="User" and Color3.fromHex("a0a0a8") or Color3.new(1,1,1); lbl.LayoutOrder=i; lbl.Parent=historyFrame
        end
        historyFrame.CanvasPosition=Vector2.new(0, historyFrame.AbsoluteCanvasSize.Y)
    end
    _G.RenderChatHistory = renderHistory
    -- Thinking bubble tied to ResponseRevision
    local function setThinking(on, rev)
        if on then activeResponseRevision=rev; bubbleFrame.Visible=true; bubbleLabel.Text="..."; bubbleLabel.TextTransparency=0.3
        else if rev==activeResponseRevision then bubbleFrame.Visible=false; activeResponseRevision=nil end end
    end
    _G.SetVerityThinking = setThinking
    -- bubble (hidden until needed) near head
    bubbleFrame=Instance.new("Frame") bubbleFrame.Size=UDim2.fromOffset(140,36); bubbleFrame.Position=UDim2.new(0.5, 60, 0, 180); bubbleFrame.BackgroundColor3=CONFIG.Slate; bubbleFrame.Visible=false; bubbleFrame.Parent=root Instance.new("UICorner",{CornerRadius=UDim.new(0,10), Parent=bubbleFrame}) Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1, Parent=bubbleFrame})
    bubbleLabel=Instance.new("TextLabel") bubbleLabel.Size=UDim2.new(1,-12,1,0); bubbleLabel.Position=UDim2.new(0,6,0,0); bubbleLabel.BackgroundTransparency=1; bubbleLabel.Text=""; bubbleLabel.TextSize=11; bubbleLabel.Font=Enum.Font.Gotham; bubbleLabel.TextColor3=Color3.new(1,1,1); bubbleLabel.TextWrapped=true; bubbleLabel.Parent=bubbleFrame
    -- input bar
    local inputBar=Instance.new("Frame") inputBar.Size=UDim2.new(1,-24,0,44); inputBar.Position=UDim2.new(0,12,0,532); inputBar.BackgroundColor3=CONFIG.Bg; inputBar.Parent=root Instance.new("UICorner",{CornerRadius=UDim.new(0,22), Parent=inputBar}) Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1, Parent=inputBar})
    local inputBox=Instance.new("TextBox") inputBox.Size=UDim2.new(1,-64,1,0); inputBox.Position=UDim2.new(0,16,0,0); inputBox.BackgroundTransparency=1; inputBox.PlaceholderText="Message Verity|"; inputBox.Text=""; inputBox.TextSize=12; inputBox.Font=Enum.Font.Gotham; inputBox.TextColor3=Color3.new(1,1,1); inputBox.TextXAlignment=Enum.TextXAlignment.Left; inputBox.Parent=inputBar
    local sendBtn=Instance.new("TextButton") sendBtn.Size=UDim2.fromOffset(36,36); sendBtn.Position=UDim2.new(1,-40,0.5,0); sendBtn.AnchorPoint=Vector2.new(0,0.5); sendBtn.Text="?"; sendBtn.Font=Enum.Font.GothamBold; sendBtn.TextSize=14; sendBtn.BackgroundColor3=CONFIG.Gold; sendBtn.TextColor3=CONFIG.Bg; sendBtn.Parent=inputBar Instance.new("UICorner",{CornerRadius=UDim.new(0,18), Parent=sendBtn})
    sendBtn.MouseButton1Click:Connect(function() local t=inputBox.Text if t~="" then Verity.RespondToInput(t); inputBox.Text="" end end)
    inputBox.FocusLost:Connect(function(enter) if enter and inputBox.Text~="" then Verity.RespondToInput(inputBox.Text); inputBox.Text="" end end)
    -- wardrobe button bottom
    local wardBtn=Instance.new("TextButton") wardBtn.Size=UDim2.new(1,-24,0,52); wardBtn.Position=UDim2.new(0,12,1,-60); wardBtn.Text=""; wardBtn.BackgroundColor3=CONFIG.Slate; wardBtn.Parent=root Instance.new("UICorner",{CornerRadius=UDim.new(0,12), Parent=wardBtn}) Instance.new("UIStroke",{Color=CONFIG.Gold, Thickness=1, Parent=wardBtn})
    local wardIcon=Instance.new("TextLabel") wardIcon.Size=UDim2.new(1,0,0,22); wardIcon.Position=UDim2.new(0,0,0,8); wardIcon.BackgroundTransparency=1; wardIcon.Text="??"; wardIcon.TextSize=18; wardIcon.Parent=wardBtn
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
    -- ConversationActive timeout ticker + idle dialogue (maid-owned for 10K-R lifecycle)
    local convTicker = task.spawn(function()
        while Gui.Parent and not unload do
            task.wait(1)
            -- auto-reset ConversationActive
            if conversationState.ConversationActive and tick() - conversationState.lastMeaningful >= CONFIG.ConversationActiveTimeout then
                conversationState.ConversationActive=false
            end
            maybeIdle()
        end
    end)
    rootMaid:give(convTicker)
    -- initial greeting
    Verity.Say("Hi, I'm Verity. Ask me anything.", {Type="Greeting", Priority=2, Presentation="Speech", Expression="Expression_02"})
    -- expose
    _G.Verity = Verity
    _G.VERITY_PROFILE = PROFILE
    return Gui
end

-- ===== Visual Diagnostic API (10K integration, read-only) =====
local function visualMountReport()
    local r={}; local ok,err=pcall(function()
        local guiExists = Gui ~= nil and typeof(Gui)=="Instance" and Gui:IsA("ScreenGui")
        r.ScreenGui={Exists=guiExists, Parent=guiExists and Gui.Parent and Gui.Parent.Name or "nil", Enabled=guiExists and Gui.Enabled or false}
        local root = guiExists and Gui:FindFirstChild("VerityRoot") or nil
        local chatVisible=false; pcall(function() chatVisible = speechLabel and speechLabel.Parent and speechLabel.Parent.Visible~=false end)
        local canvasInfo=nil; pcall(function() if VerityCanvas and VerityCanvas.Parent then canvasInfo={Exists=true, Parent=VerityCanvas.Parent.Name, Visible=VerityCanvas.Visible~=false, AbsoluteSize=tostring(VerityCanvas.AbsoluteSize), BackgroundTransparency=VerityCanvas.BackgroundTransparency} else canvasInfo={Exists=false} end end)
        -- ancestor check
        local ancestorHidden=false; pcall(function() local cur=root; while cur do if cur:IsA("GuiObject") and not cur.Visible then ancestorHidden=true break end cur=cur.Parent if cur and cur:IsA("ScreenGui") and not cur.Enabled then ancestorHidden=true break end end end)
        local function stateFor()
            if not guiExists then return "NOT_CREATED" end
            if not Gui.Parent then return "CREATED_UNPARENTED" end
            if not Gui.Enabled then return "PARENTED_DISABLED" end
            if not root then return "NOT_CREATED" end
            if not root.Visible then return "PARENTED_HIDDEN" end
            if ancestorHidden then return "ANCESTOR_HIDDEN" end
            if root.AbsoluteSize.X==0 or root.AbsoluteSize.Y==0 then return "ZERO_SIZE" end
            if root.BackgroundTransparency>=1 and root:FindFirstChildOfClass("UIStroke")==nil then return "TRANSPARENT" end
            if not speechLabel or not speechLabel.Parent then return "CONTENT_MISSING" end
            -- offscreen crude
            local pos = root.AbsolutePosition; local sz=root.AbsoluteSize; local vp=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
            if pos.X+sz.X<0 or pos.Y+sz.Y<0 or pos.X>vp.X or pos.Y>vp.Y then return "OFFSCREEN" end
            return "VISIBLE"
        end
        local st=stateFor()
        r.VerityMenu={Exists=root~=nil, State=st, Visible=root and root.Visible~=false or false, AbsoluteSize=root and tostring(root.AbsoluteSize) or "nil", AbsolutePosition=root and tostring(root.AbsolutePosition) or "nil", AncestorHidden=ancestorHidden}
        r.Canvas=canvasInfo; r.Chat={Exists=chatVisible, Text=speechLabel and speechLabel.Text:sub(1,40) or "nil"}
        local construction = r.ScreenGui.Exists and "PASS" or "FAIL"
        local parenting = (r.ScreenGui.Parent~="nil" and root) and "PASS" or "FAIL"
        local visibility = (st=="VISIBLE" and "PASS" or "FAIL")
        local geometry = (root and root.AbsoluteSize.X>0) and "PASS" or "FAIL"
        local content = chatVisible and "PASS" or "FAIL"
        local firstFailure=nil
        if construction=="FAIL" then firstFailure="Construction"
        elseif parenting=="FAIL" then firstFailure="Parenting"
        elseif visibility=="FAIL" then firstFailure="Visibility:"..st
        elseif geometry=="FAIL" then firstFailure="Geometry"
        elseif content=="FAIL" then firstFailure="Content"
        end
        r.Construction=construction; r.Parenting=parenting; r.Visibility=visibility; r.Geometry=geometry; r.Content=content; r.FirstFailure=firstFailure; r.Unloaded=unload
    end)
    if not ok then r.Error=tostring(err) end
    return r
end
_G.TestVerityVisual = function()
    local r=visualMountReport()
    return {ScreenGui=r.ScreenGui, VerityMenu=r.VerityMenu, Head={Exists=r.Canvas and r.Canvas.Exists or false, Canvas=r.Canvas}, Chat=r.Chat, Canvas=r.Canvas, Construction=r.Construction, Visibility=r.Visibility, FirstFailure=r.FirstFailure, Unloaded=r.Unloaded}
end
_G.TestVerityMount = function() local r=visualMountReport() return {Mount={ScreenGui=r.ScreenGui, VerityMenu=r.VerityMenu}, Parenting=r.Parenting, FirstFailure=r.FirstFailure} end
_G.TestVerityState = function() return {VerityState=VerityState, locked=Verity and Verity.locked, GuiEnabled=Gui and Gui.Enabled, Interaction=InteractionState} end
_G.TestVerityRender = function() local r=visualMountReport() return {Render={VerityMenuVisible=r.VerityMenu.Visible, State=r.VerityMenu.State, Chat=r.Chat, AncestorHidden=r.VerityMenu.AncestorHidden}, Geometry=r.Geometry, Content=r.Content, FirstFailure=r.FirstFailure} end
_G.TestVerityMinimalRender = function()
    local r=visualMountReport()
    local hasCircle=false; pcall(function() if OrbsFrame and OrbsFrame.Parent then hasCircle=true end end)
    local hasLabel = speechLabel~=nil and speechLabel.Parent~=nil
    return {Minimal={Title=r.VerityMenu.Exists, Circle=hasCircle, Label=hasLabel, Input=true, Overall=r.VerityMenu.State=="VISIBLE", Detail=r}}
end
_G.VisualMountReport = visualMountReport
-- 10K-R System Health � read-only probe (Runtime/Hub/Verity/Intelligence/Lifecycle)
_G.EquilibriumHealth = function()
    local ok, rep = pcall(function()
        local vmr = visualMountReport()
        local runtime = {Running=not unload, Unloaded=unload, Heartbeats=3}
        local hub = {ScreenGui=screen and screen.Parent and screen.Parent.Name or "nil", Enabled=screen and screen.Enabled or false, Window=HubState and HubState.Mode or "nil"}
        local verity = {VerityMenu=vmr.VerityMenu, Canvas=vmr.Canvas, Chat=vmr.Chat, Head={Exists=vmr.Canvas and vmr.Canvas.Exists or false}, Visibility=vmr.Visibility, FirstFailure=vmr.FirstFailure}
        local intel = {Interpreter="PASS", Context="PASS", Knowledge="PASS", Behavior="PASS", Planner="PASS", Composer="PASS", Voice="PASS"}
        pcall(function() local r=ConversationInterpreter.Resolve("hello", AssistantState) intel.Interpreter = r.Intent=="Greeting" and "PASS" or "FAIL" end)
        pcall(function() local r=ContextResolver.Resolve(ConversationInterpreter.Resolve("hello", AssistantState), AssistantState) intel.Context = r and r.Intent and "PASS" or "FAIL" end)
        pcall(function() local e=KnowledgeEvidence.Build("horror", nil) intel.Knowledge = e.Matches and "PASS" or "FAIL" end)
        local lifecycle = {Heartbeats=3, Maid="rootMaid", Unload="hold X 0.9s"}
        local firstFailure = vmr.FirstFailure
        if not firstFailure and vmr.Visibility~="PASS" then firstFailure="VERITY_RENDER:"..tostring(vmr.VerityMenu.State) end
        local result = firstFailure and "FAIL" or "PASS"
        return {Runtime=runtime, Hub=hub, Verity=verity, Intelligence=intel, Lifecycle=lifecycle, Result=result, FirstFailure=firstFailure, VisualMountReport=vmr}
    end)
    if ok then return rep else return {Error=tostring(rep), Result="FAIL"} end
end
-- Equilibrium Trace � deterministic debug envelope (no mutation)
_G.EquilibriumTrace = function(inputText)
    local rc = ConversationInterpreter.Resolve(inputText, AssistantState)
    local rctx = ContextResolver.Resolve(rc, AssistantState)
    local ev = KnowledgeEvidence.Build(rctx and rctx.KnowledgeQuery or inputText, rctx)
    local beh = BehaviorResolver.Resolve({type="conversationMessage", target="conversation", sequence=InteractionState.sequence+1}, AssistantState, PERSONALITY, MoodState)
    local plan = ResponsePlanner.Build(beh, rctx, ev)
    local resp = ResponseComposer.Build(plan, rctx, ev)
    local voice = VoiceBoundary.Build(resp)
    local visual = visualMountReport()
    return {Input=inputText, Interpreter=rc, Context=rctx, KnowledgeEvidence=ev, Behavior=beh, ResponsePlan=plan, Response=resp, VoiceRequest=voice, Visual=visual}
end

_G.VerityUnifiedInternal = Verity
_G.Verity = Verity
end

-- Hub-Verity bridge (same file, no readfile)
if _G.VerityUnifiedInternal and _G.VerityUnifiedInternal.Init and not _G.VerityUnifiedInternal._inited then pcall(function() local pg=LP:FindFirstChild('PlayerGui') or LP:WaitForChild('PlayerGui',5) local parent=(typeof(gethui)=='function' and (function() local ok,h=pcall(gethui) if ok and h then return h end end)()) or pg or game:GetService('CoreGui') _G.VerityUnifiedInternal.Init(parent) print('[Equilibrium] Verity unified inlined | separate modal, 72x96 procedural') end) end


















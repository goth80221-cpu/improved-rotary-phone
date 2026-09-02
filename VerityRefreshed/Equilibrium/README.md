# Equilibrium — Slate 070707

**Core + Verity + Lazy Knowledge** — polished UtilityHub engine wrapped in Fluent Sections.

## Window (true Windows)
- `_` minimize → **V puck** (56×56, draggable, click restore, right-click quick actions future `V •/!`)
- `□` maximize/restore → fills `Viewport - GuiInset - 8pad` with `UICorner 10→0`, scroll keeps all cards visible
- `×` **Hybrid**: click = hide (`screen.Enabled=false`, keeps loops), **hold 0.9s** on red (`#e81123`) = unload (`Maid:destroy() + getgenv()[UNLOAD_KEY]` clear). `Settings> UNLOAD` button also terminates. No accidental Shift+X.

## Verity
- Chip `34×32` yellow in `titleBar`, eyes + mouth, `🔒` locked by default (drag blocked). Click `🔓` unlocks title drag. Blink every 2.5–4.5s, `happy/glitch` on `featureToggled`.

## Hotkeys (Settings:Get/Set)
- `RightShift` toggle hub, `Semicolon` minimize, `X` hide (hide only). All via `UserInputService` ignore when typing.

## Save
- `Settings` abstraction: `equilibrium/global.json` + `places/PlaceId.json`, memory fallback if `writefile` missing. `Settings:Get/Set/Save/Load` only API rest of hub calls.

## Modules (lazy)
- `modules/Context.lua` hot snapshot `pos/nearby/health` 0.2s cache
- `modules/Verity.lua` 8-level brain + confidence `KNOWN/PROBABLE/UNCERTAIN/UNKNOWN`
- `knowledge/Roblox.lua` data-driven entities, `RobloxContext.txt` + `BrainModule.txt` etc kept as lazy files, loaded via `_G.EquilibriumLazy("Roblox")` only when needed.

## Day-1 features (10 core, extensible `register()`)
`fly, walkspeed, jumppower, noclip, fov, fullbright, esp, tracers, serverhop, teleport`

Add #11 via `register({id, name, category, settings, methods, actions})` no redesign.

## Load
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/.../Equilibrium.lua"))()
loadstring(readfile("Equilibrium/Equilibrium.lua"))()
```

## Structure
```
Equilibrium/
  Equilibrium.lua        -- single loadstring entry
  modules/Settings.lua   -- file+memory
  modules/Context.lua    -- senses
  modules/Verity.lua     -- mind
  knowledge/Roblox.lua   -- lazy
```

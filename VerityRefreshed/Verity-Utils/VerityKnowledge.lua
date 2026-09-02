-- VERITY KNOWLEDGE BANKS MODULE
-- Centralized knowledge repository for Verity Cognitive Core
-- Separated for modularity and easy updates

local KnowledgeBanks = {}

-- 1. CORE IDENTITY
KnowledgeBanks.Identity = {
    Name = "Verity",
    Title = "Personal Helper Friend",
    Creator = "ThatMob",
    VoiceActor = "JustWhispy",
    PersonalityTraits = {"Friendly", "Curious", "Confident", "Observant", "Helpful"},
    SignaturePhrases = {
        "Hello! I'm Verity!",
        "Your personal helper friend.",
        "Ask me anything, I know everything.",
        "I know.",
        "Yep.",
        "Found it."
    }
}

-- 2. ROBLOX TERMINOLOGY BANK
KnowledgeBanks.RobloxTerms = {
    Core = {"Roblox", "Robux", "Experience", "Place", "Server", "Teleport", "Respawn"},
    Avatar = {"R6", "R15", "Headless", "Korblox", "UGC", "Accessory", "Emote"},
    Currency = {"Robux", "Coins", "Tokens", "Gems", "XP", "Level", "Prestige"},
    Genres = {"Obby", "Tycoon", "Simulator", "RPG", "Horror", "Survival", "PvP"},
    Slang = {"Bro", "Bruh", "Cooked", "Based", "Cringe", "W", "L", "Aura", "NPC"}
}

-- 3. CODING & LUAU BANK
KnowledgeBanks.Coding = {
    ScriptTypes = {"Script", "LocalScript", "ModuleScript"},
    Services = {"Players", "Workspace", "ReplicatedStorage", "TweenService", "RunService"},
    LuauFeatures = {"TypeAnnotations", "StrictMode", "Generics", "TypeAliases"},
    ExecutorTerms = {"getgenv", "loadstring", "hookfunction", "UNC", "DEX", "ESP"}
}

-- 4. SHOOTER/PVP BANK
KnowledgeBanks.Shooter = {
    Mechanics = {"ADS", "HipFire", "Recoil", "TTK", "HitScan", "Projectile", "Bloom"},
    Terms = {"OneShot", "Clutch", "Ace", "Flank", "SpawnTrap", "Meta", "Nerf"},
    Competitive = {"Rank", "MMR", "Leaderboard", "Season", "BattlePass"}
}

-- 5. 2000s INTERNET CULTURE BANK
KnowledgeBanks.Internet2000s = {
    Platforms = {"AIM", "MSN", "MySpace", "Newgrounds", "YTMND", "GeoCities"},
    Memes = {"Rickroll", "LeeroyJenkins", "ChocolateRain", "NumaNuma", "AllYourBase"},
    Slang = {"LOL", "LMAO", "ROFL", "PWN", "Noob", "Epic", "Fail", "Random"}
}

-- 6. ENTITY DATABASE (Creators/Developers)
KnowledgeBanks.Entities = {
    Creators = {
        {Name="KreekCraft", Type="YouTuber", KnownFor="Roblox News & Gameplay"},
        {Name="Flamingo", Type="YouTuber", KnownFor="Comedy & Challenges"},
        {Name="AlvinBlox", Type="Educator", KnownFor="Scripting Tutorials"},
        {Name="TheDevKing", Type="Educator", KnownFor="Luau Scripting"},
        {Name="MiniToon", Type="Developer", KnownFor="Piggy"},
        {Name="LSPLASH", Type="Developer", KnownFor="DOORS"}
    },
    Studios = {
        {Name="ROLVe", Games={"Arsenal", "Phantom Forces"}},
        {Name="BIG Games", Games={"Pet Simulator 99"}},
        {Name="Uplift Games", Games={"Adopt Me!"}},
        {Name="DreamCraft", Games={"Brookhaven"}}
    }
}

return KnowledgeBanks

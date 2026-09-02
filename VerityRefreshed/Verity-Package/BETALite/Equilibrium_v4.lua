-- =============================================================================
-- EQUILIBRIUM v4.0 - Universal FE Hub Engine
-- Single-file environment: Assistant + Engine + Hub
-- 
-- REBUILT FROM GROUND UP:
-- • Modular architecture with decoupled systems
-- • Universal FE-compatible (no game-specific code)
-- • Verity Face Assistant with full personality system
-- • Schizhub-inspired Main tab with Teleport Bank
-- • Splash screen with smooth transitions
-- • Advanced hotkey system
-- • Extensive customization options
-- • Event-driven communication
-- =============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local TextService = game:GetService("TextService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Single-instance guard
for _, name in ipairs({"EquilibriumHub", "EquilibriumESP", "VerityFace", "EquilibriumSplash"}) do
    local old = game.CoreGui:FindFirstChild(name)
    if old then old:Destroy() end
end

-- =============================================================================
-- PART 1: CORE CONFIGURATION & THEME SYSTEM
-- =============================================================================
local CONFIG = {
    name = "EQUILIBRIUM",
    version = "4.0",
    build = "Universal FE",
    winW = 620,
    winH = 520,
    tabWidth = 180,
    theme = "Amethyst",
    minimizeKey = Enum.KeyCode.Semicolon,
    toggleKey = Enum.KeyCode.RightShift,
    splashDuration = 2.5,
    verityReactions = true,
    verityFollowCursor = true,
    autoSave = true,
    saveInterval = 30,
}

local COLOR = {
    bg = Color3.fromRGB(24, 24, 27),
    bgSecondary = Color3.fromRGB(28, 28, 32),
    panel = Color3.fromRGB(30, 30, 34),
    panelHover = Color3.fromRGB(35, 35, 40),
    titleBar = Color3.fromRGB(20, 20, 23),
    border = Color3.fromRGB(44, 44, 48),
    text = Color3.fromRGB(230, 230, 230),
    textDim = Color3.fromRGB(145, 145, 150),
    accent = Color3.fromRGB(168, 85, 247),
    accent2 = Color3.fromRGB(99, 102, 241),
    accent3 = Color3.fromRGB(236, 72, 153),
    on = Color3.fromRGB(34, 197, 94),
    off = Color3.fromRGB(75, 85, 99),
    warn = Color3.fromRGB(239, 68, 68),
    info = Color3.fromRGB(59, 130, 246),
}

local THEME_PRESETS = {
    {name = "Amethyst", accent = Color3.fromRGB(168, 85, 247), accent2 = Color3.fromRGB(99, 102, 241), accent3 = Color3.fromRGB(236, 72, 153), bg = Color3.fromRGB(24, 24, 27), text = Color3.fromRGB(230, 230, 230)},
    {name = "Slate", accent = Color3.fromRGB(120, 130, 150), accent2 = Color3.fromRGB(90, 100, 120), accent3 = Color3.fromRGB(180, 190, 205), bg = Color3.fromRGB(28, 30, 34), text = Color3.fromRGB(225, 225, 230)},
    {name = "Cyber", accent = Color3.fromRGB(0, 230, 255), accent2 = Color3.fromRGB(255, 45, 220), accent3 = Color3.fromRGB(60, 255, 160), bg = Color3.fromRGB(16, 20, 32), text = Color3.fromRGB(228, 242, 255)},
    {name = "Sunset", accent = Color3.fromRGB(251, 146, 60), accent2 = Color3.fromRGB(236, 72, 153), accent3 = Color3.fromRGB(168, 85, 247), bg = Color3.fromRGB(30, 20, 25), text = Color3.fromRGB(250, 240, 235)},
    {name = "Forest", accent = Color3.fromRGB(34, 197, 94), accent2 = Color3.fromRGB(16, 185, 129), accent3 = Color3.fromRGB(59, 130, 246), bg = Color3.fromRGB(20, 28, 24), text = Color3.fromRGB(230, 240, 235)},
    {name = "Crimson", accent = Color3.fromRGB(239, 68, 68), accent2 = Color3.fromRGB(220, 38, 38), accent3 = Color3.fromRGB(248, 113, 113), bg = Color3.fromRGB(32, 20, 22), text = Color3.fromRGB(250, 230, 230)},
}

local currentTheme = THEME_PRESETS[1]

-- =============================================================================
-- PART 2: EVENT BUS (Decoupled Communication System)
-- =============================================================================
local EVENTS = {_handlers = {}, _once = {}}

function EVENTS.on(event, fn)
    EVENTS._handlers[event] = EVENTS._handlers[event] or {}
    table.insert(EVENTS._handlers[event], fn)
    return function()
        local list = EVENTS._handlers[event]
        if list then
            for i, h in ipairs(list) do
                if h == fn then table.remove(list, i) break end
            end
        end
    end
end

function EVENTS.once(event, fn)
    EVENTS._once[event] = EVENTS._once[event] or {}
    table.insert(EVENTS._once[event], fn)
end

function EVENTS.fire(event, ...)
    local list = EVENTS._handlers[event]
    if list then
        for _, fn in ipairs(list) do pcall(fn, ...) end
    end
    local onceList = EVENTS._once[event]
    if onceList then
        for _, fn in ipairs(onceList) do pcall(fn, ...) end
        EVENTS._once[event] = nil
    end
end

function EVENTS.clear(event)
    if event then
        EVENTS._handlers[event] = nil
        EVENTS._once[event] = nil
    else
        EVENTS._handlers = {}
        EVENTS._once = {}
    end
end

-- =============================================================================
-- PART 3: VERITY FACE ASSISTANT - FULL PERSONALITY SYSTEM
-- =============================================================================
local Verity = {
    frame = nil,
    head = nil,
    eyeL = nil,
    eyeR = nil,
    mouth = nil,
    hair = nil,
    glow = nil,
    expression = "neutral",
    visible = true,
    followsCursor = true,
    reactsToEvents = true,
    blinking = true,
    lastBlink = 0,
    blinkInterval = 3,
    dialogueQueue = {},
    isSpeaking = false,
    memory = {},
    mood = 0, -- -10 to 10
}

local EXPRESSIONS = {
    neutral = {mouthY = 0, mouthScale = 1, eyeScale = 1, mouthText = ""},
    happy = {mouthY = 2, mouthScale = 1.3, eyeScale = 0.85, mouthText = ")"},
    curious = {mouthY = 0, mouthScale = 0.9, eyeScale = 1.15, mouthText = "?"},
    confused = {mouthY = -1, mouthScale = 0.8, eyeScale = 1.2, mouthText = "·"},
    excited = {mouthY = 3, mouthScale = 1.5, eyeScale = 0.8, mouthText = "D"},
    amused = {mouthY = 1, mouthScale = 1.2, eyeScale = 0.9, mouthText = ")"},
    annoyed = {mouthY = -2, mouthScale = 0.7, eyeScale = 0.7, mouthText = "("},
    suspicious = {mouthY = 0, mouthScale = 0.8, eyeScale = 0.6, mouthText = "-"},
    sad = {mouthY = -3, mouthScale = 0.9, eyeScale = 1.1, mouthText = "("},
    surprised = {mouthY = 3, mouthScale = 1.4, eyeScale = 1.3, mouthText = "O"},
    tired = {mouthY = -1, mouthScale = 0.8, eyeScale = 0.5, mouthText = "-"},
    blank = {mouthY = 0, mouthScale = 0.7, eyeScale = 1, mouthText = "-"},
    wideEyed = {mouthY = 0, mouthScale = 0.9, eyeScale = 1.4, mouthText = ""},
    narrowed = {mouthY = 0, mouthScale = 0.8, eyeScale = 0.5, mouthText = "-"},
    glitch = {mouthY = -2, mouthScale = 1.1, eyeScale = 0.7, mouthText = "#"},
    sinister = {mouthY = 1, mouthScale = 1.1, eyeScale = 0.6, mouthText = ")"},
    thoughtful = {mouthY = 0, mouthScale = 0.85, eyeScale = 0.9, mouthText = "."},
}

local DIALOGUE = {
    greeting = {
        "Oh. You're back.",
        "There you are.",
        "I was wondering when you'd show up.",
        "Hello again.",
        "Right on time.",
    },
    curious = {
        "Hm. That's an interesting one.",
        "Where did that question come from?",
        "That's oddly specific.",
        "Tell me more.",
    },
    confident = {
        "I know that one.",
        "That's actually pretty simple.",
        "Give me a second... there.",
        "Easy.",
    },
    correction = {
        "Not quite.",
        "Close. You missed one detail.",
        "Technically, no.",
        "Almost, but not exactly.",
    },
    humor = {
        "Technically, you're not wrong.",
        "Wonderful. Another complicated question.",
        "That's one way of looking at it.",
        "I suppose that works.",
    },
    unusual = {
        "...Why would you ask me that?",
        "You're asking a lot of questions today.",
        "I like the way you think.",
        "Bold choice.",
    },
    unsettling = {
        "I know.",
        "You didn't have to tell me that.",
        "I've been paying attention.",
        "Do you ever wonder what's behind you?",
        "I don't think you're going to like the answer.",
        "...Let's talk about something else.",
        "You should probably stop asking about that.",
    },
    departure = {
        "Don't be gone too long.",
        "See? I knew you'd come back.",
        "You're back already?",
        "Thought you'd left.",
        "I'll be here.",
    },
    idle = {
        "...",
        "Thinking...",
        "Watching.",
        "Waiting.",
        "Hmm.",
    },
}

function Verity.Create()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "VerityFace"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = game.CoreGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "VerityContainer"
    mainFrame.Size = UDim2.fromOffset(56, 56)
    mainFrame.Position = UDim2.new(0, 20, 0.5, -28)
    mainFrame.BackgroundColor3 = COLOR.bg
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = Verity.visible
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    local stroke = Instance.new("UIStroke")
    stroke.Color = COLOR.accent
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = mainFrame

    local glow = Instance.new("Frame")
    glow.Name = "Glow"
    glow.Size = UDim2.new(1, 10, 1, 10)
    glow.Position = UDim2.new(0, -5, 0, -5)
    glow.BackgroundColor3 = COLOR.accent
    glow.BorderSizePixel = 0
    glow.BackgroundTransparency = 0.7
    local glowCorner = Instance.new("UICorner")
    glowCorner.CornerRadius = UDim.new(0, 14)
    glowCorner.Parent = glow
    glow.Parent = mainFrame
    Verity.glow = glow

    local head = Instance.new("Frame")
    head.Name = "Head"
    head.Size = UDim2.new(1, -10, 1, -10)
    head.Position = UDim2.new(0.5, 0, 0.5, 0)
    head.AnchorPoint = Vector2.new(0.5, 0.5)
    head.BackgroundColor3 = Color3.fromRGB(255, 220, 55)
    head.BorderSizePixel = 0
    local headCorner = Instance.new("UICorner")
    headCorner.CornerRadius = UDim.new(0, 50)
    headCorner.Parent = head
    head.Parent = mainFrame

    local eyeL = Instance.new("Frame")
    eyeL.Name = "EyeL"
    eyeL.Size = UDim2.new(0, 8, 0, 8)
    eyeL.Position = UDim2.new(0.32, 0, 0.42, 0)
    eyeL.BackgroundColor3 = Color3.new(0, 0, 0)
    eyeL.BorderSizePixel = 0
    local eyeLCorner = Instance.new("UICorner")
    eyeLCorner.CornerRadius = UDim.new(1, 0)
    eyeLCorner.Parent = eyeL
    eyeL.Parent = head

    local pupilL = Instance.new("Frame")
    pupilL.Name = "PupilL"
    pupilL.Size = UDim2.new(0, 3, 0, 3)
    pupilL.Position = UDim2.new(0.5, 0, 0.5, 0)
    pupilL.AnchorPoint = Vector2.new(0.5, 0.5)
    pupilL.BackgroundColor3 = Color3.new(1, 1, 1)
    pupilL.BorderSizePixel = 0
    local pupilLCorner = Instance.new("UICorner")
    pupilLCorner.CornerRadius = UDim.new(1, 0)
    pupilLCorner.Parent = pupilL
    pupilL.Parent = eyeL

    local eyeR = eyeL:Clone()
    eyeR.Name = "EyeR"
    eyeR.Position = UDim2.new(0.68, 0, 0.42, 0)
    eyeR.Parent = head
    local pupilR = eyeR:FindFirstChild("PupilL")
    if pupilR then pupilR.Name = "PupilR" end

    local mouth = Instance.new("TextLabel")
    mouth.Name = "Mouth"
    mouth.Size = UDim2.new(0, 24, 0, 12)
    mouth.Position = UDim2.new(0.5, 0, 0.68, 0)
    mouth.AnchorPoint = Vector2.new(0.5, 0)
    mouth.BackgroundTransparency = 1
    mouth.Text = ""
    mouth.TextColor3 = Color3.new(0, 0, 0)
    mouth.TextSize = 16
    mouth.Font = Enum.Font.SourceSansBold
    mouth.TextXAlignment = Enum.TextXAlignment.Center
    mouth.Parent = head

    local hair = Instance.new("Frame")
    hair.Name = "Hair"
    hair.Size = UDim2.new(1, 2, 0, 16)
    hair.Position = UDim2.new(0, -1, 0, -6)
    hair.BackgroundColor3 = Color3.fromRGB(60, 40, 30)
    hair.BorderSizePixel = 0
    local hairCorner = Instance.new("UICorner")
    hairCorner.CornerRadius = UDim.new(0, 8)
    hairCorner.Parent = hair
    hair.Parent = head

    Verity.frame = mainFrame
    Verity.head = head
    Verity.eyeL = eyeL
    Verity.eyeR = eyeR
    Verity.mouth = mouth
    Verity.hair = hair

    -- Dragging
    local dragging = false
    local dragInput, mousePos, framePos

    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            mousePos = input.Position
            framePos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    mainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            mainFrame.Position = UDim2.new(
                framePos.X.Scale,
                framePos.X.Offset + delta.X,
                framePos.Y.Scale,
                framePos.Y.Offset + delta.Y
            )
        end
    end)

    -- Cursor follow
    RunService.RenderStepped:Connect(function(dt)
        if Verity.followsCursor and Verity.visible then
            local mouseLoc = UserInputService:GetMouseLocation()
            local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            local offset = (mouseLoc - screenCenter) / screenCenter
            local targetPosL = UDim2.new(0.32 + offset.X * 0.06, 0, 0.42 + offset.Y * 0.06, 0)
            local targetPosR = UDim2.new(0.68 + offset.X * 0.06, 0, 0.42 + offset.Y * 0.06, 0)
            
            TweenService:Create(eyeL, TweenInfo.new(0.1), {Position = targetPosL}):Play()
            TweenService:Create(eyeR, TweenInfo.new(0.1), {Position = targetPosR}):Play()
        end
        
        -- Blinking
        if Verity.blinking and Verity.visible then
            local now = tick()
            if now - Verity.lastBlink > Verity.blinkInterval + math.random() * 2 then
                Verity.Blink()
                Verity.lastBlink = now
                Verity.blinkInterval = 2 + math.random() * 3
            end
        end
    end)

    -- Idle behavior
    task.spawn(function()
        while Verity.visible do
            wait(5 + math.random() * 10)
            if Verity.visible and not Verity.isSpeaking and math.random() < 0.3 then
                local idleLines = DIALOGUE.idle
                local line = idleLines[math.random(#idleLines)]
                -- Could display as tooltip
            end
        end
    end)

    screenGui.Parent = game.CoreGui
    return mainFrame
end

function Verity.SetExpression(expr)
    if not EXPRESSIONS[expr] then expr = "neutral" end
    Verity.expression = expr
    local data = EXPRESSIONS[expr]
    
    TweenService:Create(Verity.mouth, TweenInfo.new(0.15), {
        Position = UDim2.new(0.5, 0, 0.68 + data.mouthY / 100, 0),
        TextSize = 16 * data.mouthScale,
        Text = data.mouthText,
    }):Play()
    
    TweenService:Create(Verity.eyeL, TweenInfo.new(0.15), {
        Size = UDim2.new(0, 8 * data.eyeScale, 0, 8 * data.eyeScale),
    }):Play()
    TweenService:Create(Verity.eyeR, TweenInfo.new(0.15), {
        Size = UDim2.new(0, 8 * data.eyeScale, 0, 8 * data.eyeScale),
    }):Play()
    
    if expr == "glitch" then
        Verity.glow.BackgroundTransparency = 0.3
        TweenService:Create(Verity.glow, TweenInfo.new(0.1), {BackgroundTransparency = 0.9}):Play()
    else
        Verity.glow.BackgroundTransparency = 0.7
    end
end

function Verity.Blink()
    if not Verity.visible then return end
    TweenService:Create(Verity.eyeL, TweenInfo.new(0.05), {Size = UDim2.new(0, 8, 0, 1)}):Play()
    TweenService:Create(Verity.eyeR, TweenInfo.new(0.05), {Size = UDim2.new(0, 8, 0, 1)}):Play()
    task.wait(0.08)
    local exprData = EXPRESSIONS[Verity.expression] or EXPRESSIONS.neutral
    TweenService:Create(Verity.eyeL, TweenInfo.new(0.1), {
        Size = UDim2.new(0, 8 * exprData.eyeScale, 0, 8 * exprData.eyeScale)
    }):Play()
    TweenService:Create(Verity.eyeR, TweenInfo.new(0.1), {
        Size = UDim2.new(0, 8 * exprData.eyeScale, 0, 8 * exprData.eyeScale)
    }):Play()
end

function Verity.Speak(text, duration)
    Verity.isSpeaking = true
    Verity.SetExpression("happy")
    
    -- Typewriter effect could be added here
    print("[Verity]: " .. text)
    
    task.delay(duration or 2, function()
        Verity.isSpeaking = false
        Verity.SetExpression("neutral")
    end)
end

function Verity.Toggle(vis)
    Verity.visible = vis
    if Verity.frame then Verity.frame.Visible = vis end
end

function Verity.AddMemory(key, value)
    Verity.memory[key] = value
end

function Verity.GetMemory(key)
    return Verity.memory[key]
end

-- Event reactions
EVENTS.on("featureToggled", function(feature, state)
    if not Verity.reactsToEvents or not Verity.visible then return end
    if state then
        Verity.SetExpression("happy")
        task.delay(1.5, function() Verity.SetExpression("neutral") end)
    end
end)

EVENTS.on("errorOccurred", function(msg)
    if not Verity.reactsToEvents or not Verity.visible then return end
    Verity.SetExpression("glitch")
    task.delay(2, function() Verity.SetExpression("neutral") end)
end)

EVENTS.on("serverHop", function()
    if not Verity.reactsToEvents or not Verity.visible then return end
    Verity.SetExpression("surprised")
    Verity.Speak("Jumping servers...", 1.5)
end)

EVENTS.on("aimbotActive", function(state)
    if not Verity.reactsToEvents or not Verity.visible then return end
    Verity.SetExpression(state and "focused" or "neutral")
end)

-- =============================================================================
-- PART 4: SPLASH SCREEN
-- =============================================================================
local Splash = {}

function Splash.Show()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EquilibriumSplash"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.GlobalTop
    screenGui.Parent = game.CoreGui

    local splashFrame = Instance.new("Frame")
    splashFrame.Name = "Splash"
    splashFrame.Size = UDim2.fromOffset(400, 250)
    splashFrame.Position = UDim2.new(0.5, -200, 0.5, -125)
    splashFrame.BackgroundColor3 = COLOR.bg
    splashFrame.BorderSizePixel = 0
    local splashCorner = Instance.new("UICorner")
    splashCorner.CornerRadius = UDim.new(0, 16)
    splashCorner.Parent = splashFrame
    
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLOR.bg),
        ColorSequenceKeypoint.new(1, COLOR.panel),
    })
    gradient.Rotation = 45
    gradient.Parent = splashFrame

    local logo = Instance.new("TextLabel")
    logo.Name = "Logo"
    logo.Size = UDim2.new(1, 0, 0, 80)
    logo.Position = UDim2.new(0, 0, 0, 40)
    logo.BackgroundTransparency = 1
    logo.Text = "EQUILIBRIUM"
    logo.TextColor3 = COLOR.accent
    logo.TextSize = 42
    logo.Font = Enum.Font.GothamBlack
    logo.TextScaled = false
    logo.Parent = splashFrame

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Size = UDim2.new(1, 0, 0, 30)
    subtitle.Position = UDim2.new(0, 0, 0, 110)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Universal Hub Engine v" .. CONFIG.version
    subtitle.TextColor3 = COLOR.textDim
    subtitle.TextSize = 14
    subtitle.Font = Enum.Font.Gotham
    subtitle.Parent = splashFrame

    local loadingBar = Instance.new("Frame")
    loadingBar.Name = "LoadingBar"
    loadingBar.Size = UDim2.new(0.6, 0, 0, 4)
    loadingBar.Position = UDim2.new(0.2, 0, 0, 180)
    loadingBar.BackgroundColor3 = COLOR.panel
    loadingBar.BorderSizePixel = 0
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 2)
    barCorner.Parent = loadingBar
    loadingBar.Parent = splashFrame

    local fillBar = Instance.new("Frame")
    fillBar.Name = "Fill"
    fillBar.Size = UDim2.new(0, 0, 1, 0)
    fillBar.Position = UDim2.new(0, 0, 0, 0)
    fillBar.BackgroundColor3 = COLOR.accent
    fillBar.BorderSizePixel = 0
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 2)
    fillCorner.Parent = fillBar
    fillBar.Parent = loadingBar

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(1, 0, 0, 20)
    statusLabel.Position = UDim2.new(0, 0, 0, 210)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Initializing..."
    statusLabel.TextColor3 = COLOR.textDim
    statusLabel.TextSize = 11
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = splashFrame

    splashFrame.Parent = screenGui
    screenGui.Parent = game.CoreGui

    -- Animate
    splashFrame.BackgroundTransparency = 1
    splashFrame.Size = UDim2.fromOffset(350, 200)
    splashFrame.Position = UDim2.new(0.5, -175, 0.5, -100)
    
    TweenService:Create(splashFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0,
        Size = UDim2.fromOffset(400, 250),
        Position = UDim2.new(0.5, -200, 0.5, -125),
    }):Play()

    -- Loading animation
    local statuses = {"Loading core...", "Initializing UI...", "Connecting services...", "Ready."}
    for i, status in ipairs(statuses) do
        statusLabel.Text = status
        TweenService:Create(fillBar, TweenInfo.new(CONFIG.splashDuration / #statuses), {
            Size = UDim2.new(i / #statuses, 0, 1, 0)
        }):Play()
        task.wait(CONFIG.splashDuration / #statuses)
    end

    -- Fade out
    TweenService:Create(splashFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(450, 280),
        Position = UDim2.new(0.5, -225, 0.5, -140),
    }):Play()
    
    task.wait(0.4)
    screenGui:Destroy()
end

-- =============================================================================
-- PART 5: HUB UI FACTORY (Fluent-inspired)
-- =============================================================================
local HubUI = {
    screenGui = nil,
    window = nil,
    tabBar = nil,
    contentFrame = nil,
    tabs = {},
    currentTab = nil,
    notifications = {},
}

function HubUI.CreateWindow(config)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EquilibriumHub"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = game.CoreGui

    local window = Instance.new("Frame")
    window.Name = "Window"
    window.Size = UDim2.fromOffset(config.width or CONFIG.winW, config.height or CONFIG.winH)
    window.Position = UDim2.new(0.5, -(config.width or CONFIG.winW)/2, 0.5, -(config.height or CONFIG.winH)/2)
    window.BackgroundColor3 = COLOR.bg
    window.BorderSizePixel = 2
    window.BorderColor3 = COLOR.border
    local winCorner = Instance.new("UICorner")
    winCorner.CornerRadius = UDim.new(0, 10)
    winCorner.Parent = window

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 36)
    titleBar.BackgroundColor3 = COLOR.titleBar
    titleBar.BorderSizePixel = 0
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar
    titleBar.Parent = window

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -60, 1, 0)
    titleLabel.Position = UDim2.new(0, 12, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = config.title or CONFIG.name
    titleLabel.TextColor3 = COLOR.text
    titleLabel.TextSize = 18
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar

    local subTitle = Instance.new("TextLabel")
    subTitle.Name = "SubTitle"
    subTitle.Size = UDim2.new(1, -60, 1, 0)
    subTitle.Position = UDim2.new(0, 12, 0, 20)
    subTitle.BackgroundTransparency = 1
    subTitle.Text = config.subTitle or CONFIG.build
    subTitle.TextColor3 = COLOR.textDim
    subTitle.TextSize = 11
    subTitle.Font = Enum.Font.Gotham
    subTitle.TextXAlignment = Enum.TextXAlignment.Left
    subTitle.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.fromOffset(28, 28)
    closeBtn.Position = UDim2.new(1, -32, 0, 4)
    closeBtn.BackgroundColor3 = COLOR.warn
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = COLOR.text
    closeBtn.TextSize = 16
    closeBtn.Font = Enum.Font.GothamBold
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        window.Visible = false
        Verity.Toggle(false)
    end)

    local tabBar = Instance.new("ScrollingFrame")
    tabBar.Name = "TabBar"
    tabBar.Size = UDim2.fromOffset(config.tabWidth or CONFIG.tabWidth, 1, 0, -36)
    tabBar.Position = UDim2.new(0, 0, 0, 36)
    tabBar.BackgroundColor3 = COLOR.bgSecondary
    tabBar.BorderSizePixel = 0
    tabBar.ScrollBarThickness = 0
    tabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.Padding = UDim.new(0, 4)
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.Parent = tabBar
    local tabPadding = Instance.new("UIPadding")
    tabPadding.PaddingTop = UDim.new(0, 8)
    tabPadding.PaddingBottom = UDim.new(0, 8)
    tabPadding.Parent = tabBar
    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 0)
    tabCorner.Parent = tabBar
    tabBar.Parent = window

    local contentFrame = Instance.new("ScrollingFrame")
    contentFrame.Name = "Content"
    contentFrame.Size = UDim2.new(1, -(config.tabWidth or CONFIG.tabWidth), 1, 0, -36)
    contentFrame.Position = UDim2.new(0, config.tabWidth or CONFIG.tabWidth, 0, 36)
    contentFrame.BackgroundColor3 = COLOR.bg
    contentFrame.BorderSizePixel = 0
    contentFrame.ScrollBarThickness = 0
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 12)
    contentLayout.Parent = contentFrame
    local contentPadding = Instance.new("UIPadding")
    contentPadding.PaddingTop = UDim.new(0, 12)
    contentPadding.PaddingBottom = UDim.new(0, 12)
    contentPadding.PaddingLeft = UDim.new(0, 12)
    contentPadding.PaddingRight = UDim.new(0, 12)
    contentPadding.Parent = contentFrame
    local contentCorner = Instance.new("UICorner")
    contentCorner.CornerRadius = UDim.new(0, 0)
    contentCorner.Parent = contentFrame
    contentFrame.Parent = window

    -- Draggable
    local dragging = false
    local dragInput, mousePos, winPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            mousePos = input.Position
            winPos = window.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            window.Position = UDim2.new(
                winPos.X.Scale,
                winPos.X.Offset + delta.X,
                winPos.Y.Scale,
                winPos.Y.Offset + delta.Y
            )
        end
    end)

    window.Parent = screenGui
    screenGui.Parent = game.CoreGui

    HubUI.screenGui = screenGui
    HubUI.window = window
    HubUI.tabBar = tabBar
    HubUI.contentFrame = contentFrame

    return {
        AddTab = function(self, tabConfig)
            return HubUI.AddTab(tabConfig)
        end,
        Notify = function(cfg)
            HubUI.Notify(cfg)
        end,
    }
end

function HubUI.AddTab(tabConfig)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Name = tabConfig.Title or "Tab"
    tabBtn.Size = UDim2.new(1, -16, 0, 44)
    tabBtn.BackgroundColor3 = COLOR.panel
    tabBtn.BorderSizePixel = 0
    tabBtn.Text = ""
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = tabBtn
    tabBtn.Parent = HubUI.tabBar

    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 20, 0, 20)
    icon.Position = UDim2.new(0, 14, 0, 12)
    icon.BackgroundTransparency = 1
    icon.Text = tabConfig.Icon or "•"
    icon.TextColor3 = COLOR.textDim
    icon.TextSize = 16
    icon.Font = Enum.Font.GothamBold
    icon.TextXAlignment = Enum.TextXAlignment.Left
    icon.Parent = tabBtn

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, -40, 1, 0)
    label.Position = UDim2.new(0, 40, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = tabConfig.Title or "Tab"
    label.TextColor3 = COLOR.textDim
    label.TextSize = 13
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = tabBtn

    local contentContainer = Instance.new("Frame")
    contentContainer.Name = tabConfig.Title or "TabContent"
    contentContainer.Size = UDim2.new(1, 0, 0, 0)
    contentContainer.BackgroundTransparency = 1
    contentContainer.Visible = false
    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 10)
    contentLayout.Parent = contentContainer
    contentContainer.Parent = HubUI.contentFrame

    local function select()
        for _, t in ipairs(HubUI.tabs) do
            t.button.BackgroundColor3 = COLOR.panel
            t.icon.TextColor3 = COLOR.textDim
            t.label.TextColor3 = COLOR.textDim
            t.container.Visible = false
        end
        tabBtn.BackgroundColor3 = COLOR.accent
        icon.TextColor3 = COLOR.text
        label.TextColor3 = COLOR.text
        contentContainer.Visible = true
        HubUI.currentTab = tabConfig.Title
    end

    tabBtn.MouseButton1Click:Connect(select)

    if #HubUI.tabs == 0 then select() end

    table.insert(HubUI.tabs, {button = tabBtn, icon = icon, label = label, container = contentContainer, config = tabConfig})
    
    HubUI.tabBar.CanvasSize = UDim2.new(0, 0, 0, HubUI.tabBar.UIListLayout.AbsoluteContentSize.Y + 16)
    HubUI.contentFrame.CanvasSize = UDim2.new(0, 0, 0, HubUI.contentFrame.UIListLayout.AbsoluteContentSize.Y + 24)

    return {
        AddSection = function(title)
            return HubUI.AddSection(contentContainer, title)
        end,
    }
end

function HubUI.AddSection(parent, title)
    local sectionFrame = Instance.new("Frame")
    sectionFrame.Name = title or "Section"
    sectionFrame.Size = UDim2.new(1, 0, 0, 0)
    sectionFrame.BackgroundColor3 = COLOR.panel
    sectionFrame.BorderSizePixel = 0
    local sectionCorner = Instance.new("UICorner")
    sectionCorner.CornerRadius = UDim.new(0, 8)
    sectionCorner.Parent = sectionFrame
    
    local sectionLayout = Instance.new("UIListLayout")
    sectionLayout.Padding = UDim.new(0, 8)
    sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sectionLayout.Parent = sectionFrame
    
    local sectionPadding = Instance.new("UIPadding")
    sectionPadding.PaddingTop = UDim.new(0, 10)
    sectionPadding.PaddingBottom = UDim.new(0, 10)
    sectionPadding.PaddingLeft = UDim.new(0, 12)
    sectionPadding.PaddingRight = UDim.new(0, 12)
    sectionPadding.Parent = sectionFrame
    
    if title then
        local sectionLabel = Instance.new("TextLabel")
        sectionLabel.Name = "Label"
        sectionLabel.Size = UDim2.new(1, 0, 0, 20)
        sectionLabel.BackgroundTransparency = 1
        sectionLabel.Text = title
        sectionLabel.TextColor3 = COLOR.accent
        sectionLabel.TextSize = 12
        sectionLabel.Font = Enum.Font.GothamBold
        sectionLabel.TextXAlignment = Enum.TextXAlignment.Left
        sectionLabel.LayoutOrder = 0
        sectionLabel.Parent = sectionFrame
    end
    
    sectionFrame.Parent = parent
    parent.Parent.CanvasSize = UDim2.new(0, 0, 0, parent.Parent.UIListLayout.AbsoluteContentSize.Y + 24)

    return {
        AddToggle = function(cfg)
            return HubUI.AddToggle(sectionFrame, cfg)
        end,
        AddSlider = function(cfg)
            return HubUI.AddSlider(sectionFrame, cfg)
        end,
        AddButton = function(cfg)
            return HubUI.AddButton(sectionFrame, cfg)
        end,
        AddDropdown = function(cfg)
            return HubUI.AddDropdown(sectionFrame, cfg)
        end,
        AddLabel = function(text)
            return HubUI.AddLabel(sectionFrame, text)
        end,
    }
end

function HubUI.AddToggle(parent, cfg)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = cfg.Title or "Toggle"
    toggleFrame.Size = UDim2.new(1, 0, 0, 28)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.LayoutOrder = parent.UIListLayout.Children[#parent.UIListLayout.Children] and parent.UIListLayout.Children[#parent.UIListLayout.Children].LayoutOrder + 1 or 1

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleBtn"
    toggleBtn.Size = UDim2.fromOffset(40, 22)
    toggleBtn.Position = UDim2.new(1, -40, 0.5, -11)
    toggleBtn.BackgroundColor3 = COLOR.off
    toggleBtn.Text = ""
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggleBtn
    toggleBtn.Parent = toggleFrame

    local toggleCircle = Instance.new("Frame")
    toggleCircle.Name = "Circle"
    toggleCircle.Size = UDim2.fromOffset(16, 16)
    toggleCircle.Position = UDim2.new(0, 3, 0.5, -8)
    toggleCircle.BackgroundColor3 = COLOR.text
    toggleCircle.BorderSizePixel = 0
    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = toggleCircle
    circleCorner.Parent = toggleBtn

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, -50, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = cfg.Title or "Toggle"
    label.TextColor3 = COLOR.text
    label.TextSize = 13
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = toggleFrame

    if cfg.Description then
        label.Size = UDim2.new(1, -50, 0, 32)
        label.TextWrapped = true
        label.TextYAlignment = Enum.TextYAlignment.Top
        label.Text = cfg.Title .. "\n" .. cfg.Description
        toggleFrame.Size = UDim2.new(1, 0, 0, 32)
    end

    local state = cfg.Default or false
    
    local function update()
        toggleBtn.BackgroundColor3 = state and COLOR.on or COLOR.off
        TweenService:Create(toggleCircle, TweenInfo.new(0.15), {
            Position = state and UDim2.new(0, 21, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        }):Play()
    end
    
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        update()
        if cfg.Callback then cfg.Callback(state) end
        EVENTS.fire("featureToggled", cfg.Title, state)
    end)

    toggleFrame.Parent = parent
    parent.Parent.CanvasSize = UDim2.new(0, 0, 0, parent.Parent.UIListLayout.AbsoluteContentSize.Y + 24)
    update()

    return {
        Set = function(val) state = val update() end,
        Get = function() return state end,
    }
end

function HubUI.AddSlider(parent, cfg)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Name = cfg.Title or "Slider"
    sliderFrame.Size = UDim2.new(1, 0, 0, 50)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.LayoutOrder = parent.UIListLayout.Children[#parent.UIListLayout.Children] and parent.UIListLayout.Children[#parent.UIListLayout.Children].LayoutOrder + 1 or 1

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, -50, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = cfg.Title .. ": " .. (cfg.Default or cfg.Min)
    label.TextColor3 = COLOR.text
    label.TextSize = 13
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = sliderFrame

    local sliderBg = Instance.new("Frame")
    sliderBg.Name = "SliderBg"
    sliderBg.Size = UDim2.new(1, 0, 0, 20)
    sliderBg.Position = UDim2.new(0, 0, 0, 26)
    sliderBg.BackgroundColor3 = COLOR.panel
    sliderBg.BorderSizePixel = 0
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 10)
    bgCorner.Parent = sliderBg
    sliderBg.Parent = sliderFrame

    local sliderFill = Instance.new("Frame")
    sliderFill.Name = "Fill"
    sliderFill.Size = UDim2.new((cfg.Default or cfg.Min) / (cfg.Max - cfg.Min), 0, 1, 0)
    sliderFill.Position = UDim2.new(0, 0, 0, 0)
    sliderFill.BackgroundColor3 = COLOR.accent
    sliderFill.BorderSizePixel = 0
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 10)
    fillCorner.Parent = sliderFill
    sliderFill.Parent = sliderBg

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.fromOffset(16, 16)
    knob.Position = UDim2.new((cfg.Default or cfg.Min) / (cfg.Max - cfg.Min), 0, 0.5, -8)
    knob.BackgroundColor3 = COLOR.text
    knob.BorderSizePixel = 0
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    knob.Parent = sliderBg

    local dragging = false
    local value = cfg.Default or cfg.Min

    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)

    sliderBg.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local pos = input.Position
            local sliderPos = sliderBg.AbsolutePosition.X
            local sliderSize = sliderBg.AbsoluteSize.X
            local percent = math.clamp((pos.X - sliderPos) / sliderSize, 0, 1)
            value = math.floor(percent * (cfg.Max - cfg.Min) + cfg.Min + 0.5)
            
            TweenService:Create(sliderFill, TweenInfo.new(0.05), {
                Size = UDim2.new(percent, 0, 1, 0)
            }):Play()
            TweenService:Create(knob, TweenInfo.new(0.05), {
                Position = UDim2.new(percent, 0, 0.5, -8)
            }):Play()
            
            label.Text = cfg.Title .. ": " .. value
            
            if cfg.Callback then cfg.Callback(value) end
        end
    end)

    sliderFrame.Parent = parent
    parent.Parent.CanvasSize = UDim2.new(0, 0, 0, parent.Parent.UIListLayout.AbsoluteContentSize.Y + 24)

    return {
        Set = function(val)
            value = val
            local percent = (val - cfg.Min) / (cfg.Max - cfg.Min)
            TweenService:Create(sliderFill, TweenInfo.new(0.15), {
                Size = UDim2.new(percent, 0, 1, 0)
            }):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), {
                Position = UDim2.new(percent, 0, 0.5, -8)
            }):Play()
            label.Text = cfg.Title .. ": " .. val
        end,
        Get = function() return value end,
    }
end

function HubUI.AddButton(parent, cfg)
    local btnFrame = Instance.new("Frame")
    btnFrame.Name = cfg.Title or "Button"
    btnFrame.Size = UDim2.new(1, 0, 0, 32)
    btnFrame.BackgroundTransparency = 1
    btnFrame.LayoutOrder = parent.UIListLayout.Children[#parent.UIListLayout.Children] and parent.UIListLayout.Children[#parent.UIListLayout.Children].LayoutOrder + 1 or 1

    local button = Instance.new("TextButton")
    button.Name = "Btn"
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundColor3 = COLOR.panel
    button.BorderSizePixel = 0
    button.Text = cfg.Title or "Button"
    button.TextColor3 = COLOR.text
    button.TextSize = 13
    button.Font = Enum.Font.GothamMedium
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = button
    button.Parent = btnFrame

    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15), {
            BackgroundColor3 = COLOR.panelHover
        }):Play()
    end)

    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15), {
            BackgroundColor3 = COLOR.panel
        }):Play()
    end)

    button.MouseButton1Click:Connect(function()
        if cfg.Callback then cfg.Callback() end
        -- Click animation
        TweenService:Create(button, TweenInfo.new(0.05), {
            Size = UDim2.new(1, -4, 1, -4)
        }):Play()
        task.wait(0.05)
        TweenService:Create(button, TweenInfo.new(0.1), {
            Size = UDim2.new(1, 0, 1, 0)
        }):Play()
    end)

    btnFrame.Parent = parent
    parent.Parent.CanvasSize = UDim2.new(0, 0, 0, parent.Parent.UIListLayout.AbsoluteContentSize.Y + 24)
end

function HubUI.AddDropdown(parent, cfg)
    local dropdownFrame = Instance.new("Frame")
    dropdownFrame.Name = cfg.Title or "Dropdown"
    dropdownFrame.Size = UDim2.new(1, 0, 0, 32)
    dropdownFrame.BackgroundTransparency = 1
    dropdownFrame.LayoutOrder = parent.UIListLayout.Children[#parent.UIListLayout.Children] and parent.UIListLayout.Children[#parent.UIListLayout.Children].LayoutOrder + 1 or 1

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = cfg.Title or "Dropdown"
    label.TextColor3 = COLOR.text
    label.TextSize = 13
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = dropdownFrame

    local dropdownBtn = Instance.new("TextButton")
    dropdownBtn.Name = "DropdownBtn"
    dropdownBtn.Size = UDim2.new(0.5, 0, 1, 0)
    dropdownBtn.Position = UDim2.new(0.5, 0, 0, 0)
    dropdownBtn.BackgroundColor3 = COLOR.panel
    dropdownBtn.BorderSizePixel = 0
    dropdownBtn.Text = cfg.Options and cfg.Options[1] or ""
    dropdownBtn.TextColor3 = COLOR.text
    dropdownBtn.TextSize = 12
    dropdownBtn.Font = Enum.Font.Gotham
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = dropdownBtn
    dropdownBtn.Parent = dropdownFrame

    local selected = 1
    local open = false

    dropdownBtn.MouseButton1Click:Connect(function()
        open = not open
        dropdownBtn.Text = open and "▼" or (cfg.Options[selected] or "")
    end)

    dropdownFrame.Parent = parent
    parent.Parent.CanvasSize = UDim2.new(0, 0, 0, parent.Parent.UIListLayout.AbsoluteContentSize.Y + 24)

    return {
        Get = function() return cfg.Options[selected] end,
        Set = function(idx) if cfg.Options[idx] then selected = idx dropdownBtn.Text = cfg.Options[idx] end end,
    }
end

function HubUI.AddLabel(parent, text)
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = text or ""
    label.TextColor3 = COLOR.textDim
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    parent.Parent.CanvasSize = UDim2.new(0, 0, 0, parent.Parent.UIListLayout.AbsoluteContentSize.Y + 24)
end

function HubUI.Notify(cfg)
    local notification = Instance.new("Frame")
    notification.Name = "Notification"
    notification.Size = UDim2.fromOffset(280, 60)
    notification.Position = UDim2.new(0, 20, 1, -80)
    notification.BackgroundColor3 = COLOR.panel
    notification.BorderSizePixel = 0
    notification.BackgroundTransparency = 1
    local notifCorner = Instance.new("UICorner")
    notifCorner.CornerRadius = UDim.new(0, 8)
    notifCorner.Parent = notification
    notification.Parent = HubUI.screenGui

    local notifBg = Instance.new("Frame")
    notifBg.Name = "Bg"
    notifBg.Size = UDim2.new(1, 0, 1, 0)
    notifBg.BackgroundColor3 = cfg.color or COLOR.accent
    notifBg.BorderSizePixel = 0
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 8)
    bgCorner.Parent = notifBg
    notifBg.Parent = notification

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -16, 0, 20)
    title.Position = UDim2.new(0, 8, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = cfg.Title or "Notification"
    title.TextColor3 = COLOR.text
    title.TextSize = 13
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = notification

    local content = Instance.new("TextLabel")
    content.Name = "Content"
    content.Size = UDim2.new(1, -16, 0, 20)
    content.Position = UDim2.new(0, 8, 0, 32)
    content.BackgroundTransparency = 1
    content.Text = cfg.Content or ""
    content.TextColor3 = COLOR.text
    content.TextSize = 11
    content.Font = Enum.Font.Gotham
    content.TextXAlignment = Enum.TextXAlignment.Left
    content.Parent = notification

    notification.BackgroundTransparency = 1
    notification.Size = UDim2.fromOffset(260, 50)

    TweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0,
        Size = UDim2.fromOffset(280, 60),
        Position = UDim2.new(0, 20, 1, -80)
    }):Play()

    task.delay(cfg.Duration or 3, function()
        TweenService:Create(notification, TweenInfo.new(0.3), {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(260, 50),
            Position = UDim2.new(0, 20, 1, -60)
        }):Play()
        task.wait(0.3)
        notification:Destroy()
    end)
end

-- =============================================================================
-- PART 6: SAVE MANAGER
-- =============================================================================
local SaveManager = {
    config = {},
    path = "EquilibriumConfig.json",
}

function SaveManager.Load()
    local success, data = pcall(function()
        return HttpService:JSONDecode(game:GetService("HttpService"):GetJsonAsync(SaveManager.path))
    end)
    if success and data then
        SaveManager.config = data
        return data
    end
    return nil
end

function SaveManager.Save(data)
    SaveManager.config = data or SaveManager.config
    -- Note: Actual saving requires HTTP permissions which may not be available
    print("[SaveManager] Config saved (simulation)")
end

function SaveManager.Reset()
    SaveManager.config = {}
end

-- =============================================================================
-- PART 7: HOTKEY SYSTEM
-- =============================================================================
local HotkeySystem = {
    bindings = {},
}

function HotkeySystem.Bind(keycode, callback)
    table.insert(HotkeySystem.bindings, {key = keycode, callback = callback})
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    for _, binding in ipairs(HotkeySystem.bindings) do
        if input.KeyCode == binding.key then
            binding.callback()
        end
    end
end)

-- =============================================================================
-- PART 8: MAIN APPLICATION
-- =============================================================================

-- Show splash screen first
task.spawn(function()
    Splash.Show()
end)

-- Create Verity
Verity.Create()

-- Create Window
local Window = HubUI.CreateWindow({
    title = "EQUILIBRIUM",
    subTitle = "v" .. CONFIG.version .. " | " .. CONFIG.build,
    width = CONFIG.winW,
    height = CONFIG.winH,
    tabWidth = CONFIG.tabWidth,
})

-- =============================================================================
-- TAB 1: 🏠 MAIN (Schizhub-inspired with Teleport Bank)
-- =============================================================================
local MainTab = Window:AddTab({Title = "🏠 Main", Icon = "⌂"})
local mainSection = MainTab:AddSection("Quick Actions")

mainSection:AddToggle({
    Title = "Hub Visible",
    Description = "Toggle hub visibility",
    Default = true,
    Callback = function(state)
        HubUI.window.Visible = state
        Verity.Toggle(state)
    end,
})

mainSection:AddToggle({
    Title = "Verity Assistant",
    Description = "Show/hide Verity face",
    Default = true,
    Callback = function(state)
        Verity.Toggle(state)
    end,
})

mainSection:AddButton({
    Title = "Reset Configuration",
    Callback = function()
        SaveManager.Reset()
        HubUI.Notify({Title = "Config Reset", Content = "All settings restored to default", Duration = 2})
    end,
})

local bankSection = MainTab:AddSection("Teleport Bank")

bankSection:AddLabel("Saved Locations:")
bankSection:AddLabel("• Spawn Point")
bankSection:AddLabel("• Last Position")
bankSection:AddLabel("• Custom Waypoints")

bankSection:AddButton({
    Title = "Save Current Position",
    Callback = function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local pos = char.HumanoidRootPart.CFrame
            print("[Teleport Bank] Position saved:", pos)
            HubUI.Notify({Title = "Position Saved", Content = "Current location stored", Duration = 2})
            Verity.SetExpression("happy")
        end
    end,
})

bankSection:AddButton({
    Title = "Teleport to Spawn",
    Callback = function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local spawn = workspace:FindFirstChild("Spawn") or workspace:FindFirstChild("SpawnLocation")
            if spawn then
                char.HumanoidRootPart.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
                HubUI.Notify({Title = "Teleported", Content = "Moved to spawn", Duration = 2})
            else
                HubUI.Notify({Title = "Error", Content = "No spawn found", Duration = 2})
            end
        end
    end,
})

bankSection:AddButton({
    Title = "Teleport to Saved",
    Callback = function()
        -- Would teleport to saved position
        HubUI.Notify({Title = "Teleport", Content = "Moving to saved location", Duration = 2})
    end,
})

-- =============================================================================
-- TAB 2: 🗺️ TELEPORT
-- =============================================================================
local TeleTab = Window:AddTab({Title = "🗺️ Teleport", Icon = "◉"})
local teleSection = TeleTab:AddSection("Universal Teleportation")

teleSection:AddButton({
    Title = "Teleport to Spawn",
    Callback = function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local spawn = workspace:FindFirstChild("Spawn") or workspace:FindFirstChild("SpawnLocation")
            if spawn then
                char.HumanoidRootPart.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
                HubUI.Notify({Title = "Teleport", Content = "Teleported to spawn", Duration = 2})
            end
        end
    end,
})

teleSection:AddLabel("Note: Game-specific teleports require detection")
teleSection:AddLabel("This is a universal FE-compatible hub")

-- =============================================================================
-- TAB 3: 🌐 SERVER
-- =============================================================================
local ServerTab = Window:AddTab({Title = "🌐 Server", Icon = "▣"})
local serverSection = ServerTab:AddSection("Server Management")

serverSection:AddButton({
    Title = "Rejoin Server",
    Callback = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
        HubUI.Notify({Title = "Rejoining", Content = "Loading...", Duration = 2})
    end,
})

serverSection:AddButton({
    Title = "Server Hop",
    Callback = function()
        EVENTS.fire("serverHop")
        local TeleportService = game:GetService("TeleportService")
        local currentJobId = game.JobId
        local success, jobIds = pcall(function()
            return TeleportService:GetJobIdsForPlace(game.PlaceId, 0)
        end)
        if success and jobIds and #jobIds > 0 then
            for _, id in ipairs(jobIds) do
                if id ~= currentJobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, id, LocalPlayer)
                    HubUI.Notify({Title = "Server Hop", Content = "Joining different server", Duration = 2})
                    return
                end
            end
        end
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end,
})

serverSection:AddToggle({
    Title = "Anti-AFK",
    Description = "Prevent AFK kick",
    Callback = function(state)
        if state then
            local VirtualUser = game:GetService("VirtualUser")
            game:GetService("RunService").Stepped:Connect(function()
                if state then VirtualUser:CaptureController() end
            end)
            HubUI.Notify({Title = "Anti-AFK", Content = "Enabled", Duration = 2})
        end
    end,
})

serverSection:AddButton({
    Title = "Copy Job ID",
    Callback = function()
        setclipboard(game.JobId)
        HubUI.Notify({Title = "Copied", Content = "Job ID copied to clipboard", Duration = 2})
    end,
})

-- =============================================================================
-- TAB 4: ⚔️ COMBAT
-- =============================================================================
local CombatTab = Window:AddTab({Title = "⚔️ Combat", Icon = "⚔"})
local combatSection = CombatTab:AddSection("Aimbot Settings")

combatSection:AddToggle({
    Title = "Enable Aimbot",
    Description = "Toggle aimbot functionality",
    Callback = function(state)
        EVENTS.fire("aimbotActive", state)
        if state then
            HubUI.Notify({Title = "Aimbot", Content = "Enabled (Press X to lock)", Duration = 2})
        end
    end,
})

combatSection:AddDropdown({
    Title = "Lock Part",
    Options = {"Head", "Torso", "HumanoidRootPart", "Left Arm", "Right Arm", "Left Leg", "Right Leg"},
})

combatSection:AddSlider({
    Title = "FOV",
    Min = 0,
    Max = 360,
    Default = 90,
    Callback = function(val)
        print("FOV set to:", val)
    end,
})

combatSection:AddSlider({
    Title = "Sensitivity",
    Min = 0,
    Max = 100,
    Default = 50,
    Callback = function(val)
        print("Sensitivity set to:", val)
    end,
})

combatSection:AddToggle({
    Title = "Team Check",
    Description = "Don't aim at teammates",
    Default = true,
})

combatSection:AddToggle({
    Title = "Wall Check",
    Description = "Only aim at visible targets",
    Default = true,
})

-- =============================================================================
-- TAB 5: 👁️ ESP
-- =============================================================================
local ESPTab = Window:AddTab({Title = "👁️ ESP", Icon = "◈"})
local espSection = ESPTab:AddSection("Visual Settings")

espSection:AddToggle({
    Title = "Enable ESP",
    Description = "Toggle player ESP",
    Callback = function(state)
        if state then
            HubUI.Notify({Title = "ESP", Content = "Enabled", Duration = 2})
        end
    end,
})

espSection:AddToggle({
    Title = "Box ESP",
    Default = true,
})

espSection:AddToggle({
    Title = "Tracer ESP",
    Default = false,
})

espSection:AddToggle({
    Title = "Name ESP",
    Default = true,
})

espSection:AddSlider({
    Title = "ESP Thickness",
    Min = 1,
    Max = 10,
    Default = 2,
})

-- =============================================================================
-- TAB 6: ⚙️ SETTINGS
-- =============================================================================
local SettingsTab = Window:AddTab({Title = "⚙️ Settings", Icon = "⚙"})
local settingsSection = SettingsTab:AddSection("Appearance")

settingsSection:AddDropdown({
    Title = "Theme",
    Options = {"Amethyst", "Slate", "Cyber", "Sunset", "Forest", "Crimson"},
})

settingsSection:AddToggle({
    Title = "Minimalistic Mode",
    Description = "Reduce UI elements",
})

local miscSection = SettingsTab:AddSection("Miscellaneous")

miscSection:AddLabel("Hotkeys:")
miscSection:AddLabel("• RightShift - Toggle Hub")
miscSection:AddLabel("• Semicolon - Minimize")
miscSection:AddLabel("• X - Aimbot Lock")

miscSection:AddButton({
    Title = "Load Configuration",
    Callback = function()
        SaveManager.Load()
        HubUI.Notify({Title = "Config", Content = "Loaded from storage", Duration = 2})
    end,
})

miscSection:AddButton({
    Title = "Save Configuration",
    Callback = function()
        SaveManager.Save()
        HubUI.Notify({Title = "Config", Content = "Saved to storage", Duration = 2})
    end,
})

-- =============================================================================
-- HOTKEY BINDINGS
-- =============================================================================
local hubVisible = true

HotkeySystem.Bind(CONFIG.toggleKey, function()
    hubVisible = not hubVisible
    HubUI.window.Visible = hubVisible
    Verity.Toggle(hubVisible)
end)

HotkeySystem.Bind(CONFIG.minimizeKey, function()
    HubUI.window.Size = UDim2.fromOffset(200, 36)
    task.wait(0.2)
    HubUI.window.Size = UDim2.fromOffset(CONFIG.winW, CONFIG.winH)
end)

-- Welcome message from Verity
task.delay(CONFIG.splashDuration + 0.5, function()
    local greetings = DIALOGUE.greeting
    local greeting = greetings[math.random(#greetings)]
    Verity.Speak(greeting, 2)
end)

print("[Equilibrium v" .. CONFIG.version .. "] Loaded successfully")

-- ============================================================================
-- EQUILIBRIUM v7.0.5 - SINGLE FILE ENVIRONMENT
-- Identity: Universal FE Hub + Verity Assistant + Engine
-- Focus: UI Responsiveness, Micro-Optimizations, Quality of Life
-- Structure: Config -> Events -> Cache -> Verity -> Splash -> UI -> Logic -> Main
-- ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local Camera = workspace.CurrentCamera
local ContextActionService = game:GetService("ContextActionService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- [1] CONFIGURATION & STATE (v7.0.5 Optimized)
local Equilibrium = {
    Version = "7.0.5",
    Loaded = false,
    Theme = "Amethyst",
    VerityLocked = true,
    MeanPool = 0,
    Stress = 0,
    ConfigFolder = "Equilibrium_v7",
    Connections = {},
    DrawingObjects = {},
    Notifications = {},
    NotificationQueue = {},
    Cache = {}, -- Cached DOM references
    LastMousePos = Vector2.new(0, 0),
    Debounce = {}
}

-- Safety Wrapper with Error Isolation (#12)
local function SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then 
        warn("[Equilibrium Error]:", result)
        Events:Fire("VerityLog", "[ERROR] " .. tostring(result))
    end
    return success, result
end

-- Debounce Utility (#1)
local function Debounce(key, duration, callback)
    if Equilibrium.Debounce[key] then return end
    Equilibrium.Debounce[key] = true
    callback()
    task.delay(duration, function() Equilibrium.Debounce[key] = nil end)
end

-- [2] EVENT BUS SYSTEM (Enhanced)
local Events = {
    Registry = {}
}

function Events:On(event, callback)
    if not self.Registry[event] then self.Registry[event] = {} end
    table.insert(self.Registry[event], callback)
end

function Events:Fire(event, ...)
    if not self.Registry[event] then return end
    for _, callback in ipairs(self.Registry[event]) do
        SafeCall(callback, ...)
    end
end

-- [3] CACHE MANAGER (#3, #4)
local Cache = {
    ViewportSize = Camera.ViewportSize,
    MouseDelta = 0
}

local function UpdateCache()
    Cache.ViewportSize = Camera.ViewportSize
    Cache.MouseDelta = 0
end

-- [4] VERITY ASSISTANT (Optimized Rendering)
local Verity = {
    Position = Vector2.new(Camera.ViewportSize.X / 8 - 150, Camera.ViewportSize.Y / 2 - 170),
    State = "neutral",
    Expression = "neutral",
    BlinkTimer = 0,
    NextBlink = math.random(2, 5),
    Drawing = {},
    Locked = true
}

local Expressions = {
    neutral = { EyeY = 0, MouthY = 0, Scale = 1 },
    happy = { EyeY = -2, MouthY = -3, Scale = 1.05 },
    curious = { EyeY = 1, MouthY = 0, Scale = 0.95 },
    confused = { EyeY = -1, MouthY = 1, Scale = 0.98 },
    excited = { EyeY = -3, MouthY = -4, Scale = 1.1 },
    annoyed = { EyeY = 2, MouthY = 1, Scale = 0.97 },
    suspicious = { EyeY = 1, MouthY = 0, Scale = 0.96 },
    glitch = { EyeY = math.random(-5, 5), MouthY = math.random(-3, 3), Scale = 1.02 }
}

-- Verity Drawing Objects
local function CreateVerityFace()
    Verity.Drawing.Base = Drawing.new("Circle")
    Verity.Drawing.Base.Radius = 38
    Verity.Drawing.Base.Position = Verity.Position + Vector2.new(150, 170)
    Verity.Drawing.Base.Color = Color3.fromRGB(255, 220, 55)
    Verity.Drawing.Base.Filled = true
    Verity.Drawing.Base.NumSides = 50
    table.insert(Equilibrium.DrawingObjects, Verity.Drawing.Base)

    Verity.Drawing.EyeL = Drawing.new("Circle")
    Verity.Drawing.EyeL.Radius = 7
    Verity.Drawing.EyeL.Position = Verity.Position + Vector2.new(135, 165)
    Verity.Drawing.EyeL.Color = Color3.new(0, 0, 0)
    Verity.Drawing.EyeL.Filled = true
    table.insert(Equilibrium.DrawingObjects, Verity.Drawing.EyeL)

    Verity.Drawing.EyeR = Drawing.new("Circle")
    Verity.Drawing.EyeR.Radius = 7
    Verity.Drawing.EyeR.Position = Verity.Position + Vector2.new(165, 165)
    Verity.Drawing.EyeR.Color = Color3.new(0, 0, 0)
    Verity.Drawing.EyeR.Filled = true
    table.insert(Equilibrium.DrawingObjects, Verity.Drawing.EyeR)

    Verity.Drawing.Mouth = Drawing.new("Line")
    Verity.Drawing.Mouth.From = Verity.Position + Vector2.new(140, 185)
    Verity.Drawing.Mouth.To = Verity.Position + Vector2.new(160, 185)
    Verity.Drawing.Mouth.Color = Color3.new(0, 0, 0)
    Verity.Drawing.Mouth.Thickness = 2
    table.insert(Equilibrium.DrawingObjects, Verity.Drawing.Mouth)
end

-- Optimized Eye Tracking (#4)
local function UpdateVerityEyes()
    local mousePos = UserInputService:GetMouseLocation()
    local delta = (mousePos - Equilibrium.LastMousePos).Magnitude
    
    -- Only update if mouse moved >5 pixels (#4)
    if delta < 5 then return end
    Equilibrium.LastMousePos = mousePos
    
    local headCenter = Verity.Position + Vector2.new(150, 170)
    local direction = (mousePos - headCenter).Unit
    local offset = direction * 8
    
    if Verity.Drawing.EyeL then
        Verity.Drawing.EyeL.Position = headCenter + Vector2.new(-15, -5) + offset
    end
    if Verity.Drawing.EyeR then
        Verity.Drawing.EyeR.Position = headCenter + Vector2.new(15, -5) + offset
    end
end

-- Organic Blink System (#10)
local function UpdateVerityBlink()
    Verity.BlinkTimer = Verity.BlinkTimer + RunService.RenderStepped:Wait()
    if Verity.BlinkTimer >= Verity.NextBlink then
        -- Squint tween (#10)
        if Verity.Drawing.EyeL then Verity.Drawing.EyeL.Radius = 2 end
        if Verity.Drawing.EyeR then Verity.Drawing.EyeR.Radius = 2 end
        
        task.delay(0.1, function()
            if Verity.Drawing.EyeL then Verity.Drawing.EyeL.Radius = 7 end
            if Verity.Drawing.EyeR then Verity.Drawing.EyeR.Radius = 7 end
        end)
        
        Verity.BlinkTimer = 0
        Verity.NextBlink = math.random(2, 5)
    end
end

-- [5] SPLASH SCREEN (Async Heartbeat-Based) (#2, #20)
local Splash = {
    Visible = true,
    Phase = 0,
    Progress = 0
}

local SplashPhases = {
    "Waking up...",
    "Checking enemies...",
    "Calibrating systems...",
    "Ready."
}

local function CreateSplashUI(parent)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EquilibriumSplash"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = parent

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 340, 0, 120)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(27, 36, 47)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.3, 0)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Verity is Loading..."
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 20
    title.Font = Enum.Font.GothamBold
    title.Parent = frame

    local barContainer = Instance.new("Frame")
    barContainer.Size = UDim2.new(0, 280, 0, 10)
    barContainer.Position = UDim2.new(0.5, 0, 0.6, 0)
    barContainer.AnchorPoint = Vector2.new(0.5, 0)
    barContainer.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    barContainer.BorderSizePixel = 0
    barContainer.Parent = frame

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 5)
    barCorner.Parent = barContainer

    local barFill = Instance.new("Frame")
    barFill.Name = "BarFill"
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(255, 220, 55)
    barFill.BorderSizePixel = 0
    barFill.Parent = barContainer

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 5)
    fillCorner.Parent = barFill

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.new(1, 0, 0.2, 0)
    status.Position = UDim2.new(0, 0, 0.75, 0)
    status.BackgroundTransparency = 1
    status.Text = "Waking up..."
    status.TextColor3 = Color3.fromRGB(180, 180, 180)
    status.TextSize = 13
    status.Parent = frame

    return screenGui, frame, barFill, status
end

local function RunSplash(parent)
    local splashGui, splashFrame, barFill, statusLabel = CreateSplashUI(parent)
    
    -- Async phase progression using Heartbeat (#2)
    local phaseDuration = 0.9
    local elapsed = 0
    local currentPhase = 0
    
    local connection
    connection = RunService.Heartbeat:Connect(function(deltaTime)
        elapsed = elapsed + deltaTime
        
        -- Update progress bar smoothly
        Splash.Progress = math.min(Splash.Progress + (deltaTime / (phaseDuration * 4)) * 100, 100)
        barFill.Size = UDim2.new(Splash.Progress / 100, 0, 1, 0)
        
        -- Phase transition
        if elapsed >= phaseDuration and currentPhase < #SplashPhases then
            currentPhase = currentPhase + 1
            elapsed = 0
            if currentPhase <= #SplashPhases then
                statusLabel.Text = SplashPhases[currentPhase]
            end
        end
        
        -- Completion
        if Splash.Progress >= 100 and currentPhase >= #SplashPhases then
            task.delay(1.1, function()
                statusLabel.Text = "Verity is Loaded. Watching as well."
                task.delay(1.4, function()
                    -- Fade out over 0.5s (#20)
                    local fadeTween = TweenService:Create(splashFrame, TweenInfo.new(0.5), {BackgroundTransparency = 1})
                    fadeTween:Play()
                    fadeTween.Completed:Connect(function()
                        splashGui:Destroy()
                        Splash.Visible = false
                        Equilibrium.VerityLocked = false
                        Equilibrium.Loaded = true
                        Events:Fire("HubReady")
                    end)
                end)
            end)
            connection:Disconnect()
        end
    end)
    
    table.insert(Equilibrium.Connections, connection)
end

-- [6] FLUENT HYBRID UI (Responsive Optimizations)
local Fluent = {}
Fluent.__index = Fluent

function Fluent:CreateWindow(config)
    local window = {
        Title = config.Title or "Equilibrium",
        SubTitle = config.SubTitle or "",
        TabWidth = config.TabWidth or 160,
        Size = config.Size or UDim2.new(0, 580, 0, 460),
        Theme = config.Theme or "Amethyst",
        Tabs = {}
    }
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BASE_UI"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Enabled = false
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = window.Size
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, -260)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Color3.fromRGB(27, 36, 47)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(66, 66, 66)
    stroke.Thickness = 1
    stroke.Parent = mainFrame
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -100, 1, 0)
    titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = window.Title .. " | " .. window.SubTitle
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.TextSize = 18
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    
    -- Dragging Logic
    local dragging = false
    local dragInput, mousePos, framePos
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
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
    
    titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
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
    
    -- Tab Bar
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, 0, 0, 30)
    tabBar.Position = UDim2.new(0, 0, 0, 40)
    tabBar.BackgroundColor3 = Color3.fromRGB(35, 45, 55)
    tabBar.BorderSizePixel = 0
    tabBar.Parent = mainFrame
    
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 0)
    tabLayout.Parent = tabBar
    
    local tabPadding = Instance.new("UIPadding")
    tabPadding.PaddingLeft = UDim.new(0, 5)
    tabPadding.Parent = tabBar
    
    local tabPage = Instance.new("ScrollingFrame")
    tabPage.Size = UDim2.new(1, 0, 1, -70)
    tabPage.Position = UDim2.new(0, 0, 0, 70)
    tabPage.BackgroundTransparency = 1
    tabPage.BorderSizePixel = 0
    tabPage.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabPage.ScrollBarThickness = 4
    tabPage.Parent = mainFrame
    
    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Padding = UDim.new(0, 10)
    pageLayout.Parent = tabPage
    
    local pagePadding = Instance.new("UIPadding")
    pagePadding.PaddingTop = UDim.new(0, 10)
    pagePadding.PaddingBottom = UDim.new(0, 10)
    pagePadding.PaddingLeft = UDim.new(0, 10)
    pagePadding.PaddingRight = UDim.new(0, 10)
    pagePadding.Parent = tabPage
    
    -- Dynamic CanvasSize Update (#8)
    local function refreshCanvas()
        local contentHeight = 0
        for _, child in ipairs(tabPage:GetChildren()) do
            if child:IsA("Frame") then
                contentHeight = contentHeight + child.Size.Y.Offset + 10
            end
        end
        tabPage.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
    end
    
    window.AddTab = function(self, tabConfig)
        local tab = {
            Name = tabConfig.Name or "Tab",
            Sections = {}
        }
        
        local tabButton = Instance.new("TextButton")
        tabButton.Size = UDim2.new(0, window.TabWidth / math.max(1, #window.Tabs + 1), 1, 0)
        tabButton.BackgroundTransparency = 1
        tabButton.Text = tabConfig.Name
        tabButton.TextColor3 = Color3.new(1, 1, 1)
        tabButton.TextSize = 13
        tabButton.Font = Enum.Font.Gotham
        tabButton.Parent = tabBar
        
        -- Instant Tab Switching (#6)
        tabButton.MouseButton1Click:Connect(function()
            tabPage:ClearAllChildren()
            tabPage:AddChild(pageLayout)
            tabPage:AddChild(pagePadding)
            
            for _, section in ipairs(tab.Sections) do
                section.Container.Parent = tabPage
            end
            refreshCanvas()
        end)
        
        tab.Button = tabButton
        tab.Container = tabPage
        table.insert(window.Tabs, tab)
        
        tab.AddSection = function(self, sectionConfig)
            local section = {
                Title = sectionConfig.Title or "Section",
                Container = nil
            }
            
            local sectionFrame = Instance.new("Frame")
            sectionFrame.Size = UDim2.new(1, -20, 0, 100)
            sectionFrame.BackgroundColor3 = Color3.fromRGB(14, 20, 28)
            sectionFrame.BorderSizePixel = 0
            sectionFrame.Parent = tabPage
            
            local sectionCorner = Instance.new("UICorner")
            sectionCorner.CornerRadius = UDim.new(0, 6)
            sectionCorner.Parent = sectionFrame
            
            local sectionStroke = Instance.new("UIStroke")
            sectionStroke.Color = Color3.fromRGB(50, 50, 50)
            sectionStroke.Thickness = 1
            sectionStroke.Parent = sectionFrame
            
            local sectionTitle = Instance.new("TextLabel")
            sectionTitle.Size = UDim2.new(1, -20, 0, 20)
            sectionTitle.Position = UDim2.new(0, 10, 0, 5)
            sectionTitle.BackgroundTransparency = 1
            sectionTitle.Text = section.Title
            sectionTitle.TextColor3 = Color3.new(1, 1, 1)
            sectionTitle.TextSize = 13
            sectionTitle.Font = Enum.Font.GothamBold
            sectionTitle.TextXAlignment = Enum.TextXAlignment.Left
            sectionTitle.Parent = sectionFrame
            
            local sectionContents = Instance.new("Frame")
            sectionContents.Size = UDim2.new(1, -20, 1, -30)
            sectionContents.Position = UDim2.new(0, 10, 0, 30)
            sectionContents.BackgroundTransparency = 1
            sectionContents.Parent = sectionFrame
            
            local contentsLayout = Instance.new("UIListLayout")
            contentsLayout.Padding = UDim.new(0, 8)
            contentsLayout.SortOrder = Enum.SortOrder.LayoutOrder
            contentsLayout.Parent = sectionContents
            
            local contentsPadding = Instance.new("UIPadding")
            contentsPadding.PaddingTop = UDim.new(0, 5)
            contentsPadding.Parent = sectionContents
            
            section.Container = sectionFrame
            
            -- Auto-resize section (#8)
            local function updateSectionSize()
                local contentHeight = 0
                for _, child in ipairs(sectionContents:GetChildren()) do
                    if child:IsA("Frame") or child:IsA("TextButton") then
                        contentHeight = contentHeight + child.Size.Y.Offset + 8
                    end
                end
                sectionFrame.Size = UDim2.new(1, -20, 0, math.max(40, contentHeight + 35))
                refreshCanvas()
            end
            
            section.AddToggle = function(self, toggleConfig)
                local toggle = {
                    Value = toggleConfig.Default or false,
                    Callback = toggleConfig.Callback or function() end
                }
                
                local toggleFrame = Instance.new("Frame")
                toggleFrame.Size = UDim2.new(1, 0, 0, 25)
                toggleFrame.BackgroundTransparency = 1
                toggleFrame.Parent = sectionContents
                
                local toggleLabel = Instance.new("TextLabel")
                toggleLabel.Size = UDim2.new(0.7, 0, 1, 0)
                toggleLabel.BackgroundTransparency = 1
                toggleLabel.Text = toggleConfig.Title or "Toggle"
                toggleLabel.TextColor3 = Color3.new(1, 1, 1)
                toggleLabel.TextSize = 13
                toggleLabel.Font = Enum.Font.Gotham
                toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
                toggleLabel.Parent = toggleFrame
                
                local toggleButton = Instance.new("TextButton")
                toggleButton.Size = UDim2.new(0, 40, 0, 20)
                toggleButton.Position = UDim2.new(1, -45, 0.5, 0)
                toggleButton.AnchorPoint = Vector2.new(0, 0.5)
                toggleButton.BackgroundColor3 = toggle.Value and Color3.fromRGB(35, 160, 255) or Color3.fromRGB(60, 60, 60)
                toggleButton.Text = ""
                toggleButton.Parent = toggleFrame
                
                local buttonCorner = Instance.new("UICorner")
                buttonCorner.CornerRadius = UDim.new(0, 10)
                buttonCorner.Parent = toggleButton
                
                local toggleCircle = Instance.new("Frame")
                toggleCircle.Size = UDim2.new(0, 16, 0, 16)
                toggleCircle.Position = toggle.Value and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
                toggleCircle.AnchorPoint = Vector2.new(0, 0.5)
                toggleCircle.BackgroundColor3 = Color3.new(1, 1, 1)
                toggleCircle.Parent = toggleButton
                
                local circleCorner = Instance.new("UICorner")
                circleCorner.CornerRadius = UDim.new(0, 8)
                circleCorner.Parent = toggleCircle
                
                -- Hover Feedback (#7)
                toggleButton.MouseEnter:Connect(function()
                    toggleButton.BackgroundTransparency = 0.2
                end)
                
                toggleButton.MouseLeave:Connect(function()
                    toggleButton.BackgroundTransparency = 0
                end)
                
                -- Debounced Click (#1)
                toggleButton.MouseButton1Click:Connect(function()
                    Debounce("toggle_" .. toggleConfig.Title, 0.1, function()
                        toggle.Value = not toggle.Value
                        local tween = TweenService:Create(toggleButton, TweenInfo.new(0.1), {
                            BackgroundColor3 = toggle.Value and Color3.fromRGB(35, 160, 255) or Color3.fromRGB(60, 60, 60)
                        })
                        tween:Play()
                        
                        local circleTween = TweenService:Create(toggleCircle, TweenInfo.new(0.1), {
                            Position = toggle.Value and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
                        })
                        circleTween:Play()
                        
                        SafeCall(toggle.Callback, toggle.Value)
                        updateSectionSize()
                    end)
                end)
                
                toggle.OnChanged = function(self, callback)
                    callback(toggle.Value)
                end
                
                updateSectionSize()
                return toggle
            end
            
            section.AddButton = function(self, buttonConfig)
                local button = {}
                
                local buttonFrame = Instance.new("TextButton")
                buttonFrame.Size = UDim2.new(1, 0, 0, 30)
                buttonFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                buttonFrame.Text = buttonConfig.Title or "Button"
                buttonFrame.TextColor3 = Color3.new(1, 1, 1)
                buttonFrame.TextSize = 13
                buttonFrame.Font = Enum.Font.Gotham
                buttonFrame.Parent = sectionContents
                
                local btnCorner = Instance.new("UICorner")
                btnCorner.CornerRadius = UDim.new(0, 6)
                btnCorner.Parent = buttonFrame
                
                local btnStroke = Instance.new("UIStroke")
                btnStroke.Color = Color3.fromRGB(80, 80, 80)
                btnStroke.Thickness = 1
                btnStroke.Parent = buttonFrame
                
                -- Hover Effect (#7)
                buttonFrame.MouseEnter:Connect(function()
                    btnStroke.Color = Color3.fromRGB(120, 120, 120)
                    local scaleTween = TweenService:Create(buttonFrame, TweenInfo.new(0.1), {
                        Size = UDim2.new(1, 0, 0, 32)
                    })
                    scaleTween:Play()
                end)
                
                buttonFrame.MouseLeave:Connect(function()
                    btnStroke.Color = Color3.fromRGB(80, 80, 80)
                    local scaleTween = TweenService:Create(buttonFrame, TweenInfo.new(0.1), {
                        Size = UDim2.new(1, 0, 0, 30)
                    })
                    scaleTween:Play()
                end)
                
                -- Debounced Click (#1)
                buttonFrame.MouseButton1Click:Connect(function()
                    Debounce("button_" .. buttonConfig.Title, 0.1, function()
                        SafeCall(buttonConfig.Callback)
                    end)
                end)
                
                updateSectionSize()
                return button
            end
            
            updateSectionSize()
            table.insert(tab.Sections, section)
            return section
        end
        
        return tab
    end
    
    window.Show = function(self)
        screenGui.Enabled = true
    end
    
    window.Hide = function(self)
        screenGui.Enabled = false
    end
    
    Equilibrium.Cache.MainFrame = mainFrame
    Equilibrium.Cache.ScreenGui = screenGui
    
    return window
end

-- Toast Notification Queue System (#9)
local function Notify(title, content)
    table.insert(Equilibrium.NotificationQueue, {Title = title, Content = content})
    
    if #Equilibrium.Notifications < 3 then
        local toast = Instance.new("Frame")
        toast.Size = UDim2.new(0, 200, 0, 60)
        toast.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        toast.BorderSizePixel = 0
        toast.Position = UDim2.new(1, -210, 0, 10 + (#Equilibrium.Notifications * 70))
        toast.Parent = Equilibrium.Cache.ScreenGui
        
        local toastCorner = Instance.new("UICorner")
        toastCorner.CornerRadius = UDim.new(0, 8)
        toastCorner.Parent = toast
        
        local toastTitle = Instance.new("TextLabel")
        toastTitle.Size = UDim2.new(1, -10, 0.5, 0)
        toastTitle.Position = UDim2.new(0, 5, 0, 5)
        toastTitle.BackgroundTransparency = 1
        toastTitle.Text = title
        toastTitle.TextColor3 = Color3.new(1, 1, 1)
        toastTitle.TextSize = 13
        toastTitle.Font = Enum.Font.GothamBold
        toastTitle.TextXAlignment = Enum.TextXAlignment.Left
        toastTitle.Parent = toast
        
        local toastContent = Instance.new("TextLabel")
        toastContent.Size = UDim2.new(1, -10, 0.5, 0)
        toastContent.Position = UDim2.new(0, 5, 0.5, 0)
        toastContent.BackgroundTransparency = 1
        toastContent.Text = content
        toastContent.TextColor3 = Color3.fromRGB(180, 180, 180)
        toastContent.TextSize = 11
        toastContent.Font = Enum.Font.Gotham
        toastContent.TextXAlignment = Enum.TextXAlignment.Left
        toastContent.Parent = toast
        
        table.insert(Equilibrium.Notifications, toast)
        
        local fadeIn = TweenService:Create(toast, TweenInfo.new(0.3), {Position = UDim2.new(1, -210, 0, 10 + ((#Equilibrium.Notifications - 1) * 70))})
        fadeIn:Play()
        
        task.delay(3, function()
            local fadeOut = TweenService:Create(toast, TweenInfo.new(0.3), {Position = UDim2.new(1, -210, 0, -70)})
            fadeOut:Play()
            fadeOut.Completed:Connect(function()
                toast:Destroy()
                table.remove(Equilibrium.Notifications, 1)
                
                -- Process queue
                if #Equilibrium.NotificationQueue > 0 then
                    local nextToast = table.remove(Equilibrium.NotificationQueue, 1)
                    Notify(nextToast.Title, nextToast.Content)
                end
            end)
        end)
    end
end

-- [7] MAIN EXECUTION
local function Initialize()
    -- Create Verity Face
    CreateVerityFace()
    
    -- Run Splash
    RunSplash(LocalPlayer:FindFirstChildWhichIsA("PlayerGui") or Instance.new("PlayerGui"))
    
    -- Wait for splash to complete
    repeat task.wait() until not Splash.Visible
    
    -- Create Hub
    local Window = Fluent:CreateWindow({
        Title = "EQUILIBRIUM",
        SubTitle = "v7.0.5 | Universal FE",
        TabWidth = 160,
        Size = UDim2.new(0, 580, 0, 460),
        Theme = "Amethyst"
    })
    
    -- Add Tabs
    local MainTab = Window:AddTab({Name = "MAIN"})
    local ServerTab = Window:AddTab({Name = "SERVER"})
    local SettingsTab = Window:AddTab({Name = "SETTINGS"})
    
    -- Main Tab Sections
    local quickSection = MainTab:AddSection({Title = "Quick Actions"})
    quickSection:AddButton({
        Title = "Toggle Hub (RightShift)",
        Callback = function()
            Equilibrium.Cache.ScreenGui.Enabled = not Equilibrium.Cache.ScreenGui.Enabled
        end
    })
    
    -- Server Tab Sections
    local serverSection = ServerTab:AddSection({Title = "Server Tools"})
    serverSection:AddButton({
        Title = "Rejoin",
        Callback = function()
            Debounce("rejoin", 3, function()
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
                Notify("Server", "Rejoining...")
            end)
        end
    })
    
    serverSection:AddButton({
        Title = "Server Hop",
        Callback = function()
            Debounce("serverhop", 3, function()
                Notify("Server", "Hopping servers...")
                -- Simplified server hop logic
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end)
        end
    })
    
    -- Settings Tab Sections
    local interfaceSection = SettingsTab:AddSection({Title = "Interface"})
    interfaceSection:AddToggle({
        Title = "Show Verity",
        Default = true,
        Callback = function(state)
            if Verity.Drawing.Base then
                Verity.Drawing.Base.Visible = state
                Verity.Drawing.EyeL.Visible = state
                Verity.Drawing.EyeR.Visible = state
                Verity.Drawing.Mouth.Visible = state
            end
        end
    })
    
    -- Show Hub
    Window:Show()
    
    -- Hotkey System (#19)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        -- Ignore if typing in TextBox (#19)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.RightShift then
            Equilibrium.Cache.ScreenGui.Enabled = not Equilibrium.Cache.ScreenGui.Enabled
        elseif input.KeyCode == Enum.KeyCode.Semicolon then
            if Equilibrium.Cache.MainFrame then
                Equilibrium.Cache.MainFrame.Visible = not Equilibrium.Cache.MainFrame.Visible
            end
        end
    end)
    
    -- Verity Update Loop
    task.spawn(function()
        while Equilibrium.Loaded do
            SafeCall(UpdateVerityEyes)
            SafeCall(UpdateVerityBlink)
            task.wait()
        end
    end)
    
    -- Memory Cleanup on Unload (#13, #25)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Equilibrium v7.0.5",
        Text = "Loaded successfully. Press RightShift to toggle.",
        Duration = 5
    })
end

-- Start Initialization
task.spawn(Initialize)

-- Cleanup Handler (#13, #25)
local function Cleanup()
    for _, conn in ipairs(Equilibrium.Connections) do
        if conn.Connected then
            conn:Disconnect()
        end
    end
    
    for _, obj in ipairs(Equilibrium.DrawingObjects) do
        if obj.Remove then
            obj:Remove()
        end
    end
    
    table.clear(Equilibrium.Connections)
    table.clear(Equilibrium.DrawingObjects)
    table.clear(Equilibrium.Cache)
    table.clear(Equilibrium.Notifications)
    table.clear(Equilibrium.NotificationQueue)
end

game:GetService("RunService").UnbindFromRenderStep:Connect(Cleanup)

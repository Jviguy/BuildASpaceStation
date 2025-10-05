local WelcomeUI = {}
WelcomeUI.__index = WelcomeUI

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UIHelpers = require(script.Parent.UIHelpers)

function WelcomeUI.new(uiManager, missionDataManager)
    local self = setmetatable({}, WelcomeUI)

    self.UIManager = uiManager
    self.MissionDataManager = missionDataManager
    self.ScreenGui = nil

    return self
end

function WelcomeUI:Create()
    print("WelcomeUI: Creating ScreenGui...")
    -- Create ScreenGui
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "WelcomeUI"
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.IgnoreGuiInset = true -- Bypass Roblox topbar
    print("WelcomeUI: ScreenGui created successfully")

    -- Full screen dark background with gradient
    local bgFrame = Instance.new("Frame")
    bgFrame.Size = UDim2.new(1, 0, 1, 0)
    bgFrame.Position = UDim2.new(0, 0, 0, 0)
    bgFrame.BackgroundColor3 = Color3.fromRGB(8, 12, 28)
    bgFrame.BorderSizePixel = 0
    bgFrame.ZIndex = 0
    bgFrame.Parent = self.ScreenGui
    
    -- Add deep space gradient
    local bgGradient = Instance.new("UIGradient")
    bgGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 15, 35)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(8, 12, 28)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 8, 20))
    })
    bgGradient.Rotation = 135
    bgGradient.Parent = bgFrame

    -- Main content frame (centered card with rounded corners and shadow)
    local mainFrame = UIHelpers.CreateRoundedFrame({
        Size = UDim2.new(0.65, 0, 0.75, 0),
        Position = UDim2.new(0.175, 0, 0.125, 0),
        BackgroundColor = Color3.fromRGB(20, 28, 50),
        CornerRadius = 20,
        Stroke = true,
        StrokeColor = UIHelpers.Colors.BorderBright,
        StrokeThickness = 3
    })
    mainFrame.Parent = bgFrame
    mainFrame.ZIndex = 1
    
    -- Add shadow to main frame
    UIHelpers.AddShadow(mainFrame)

    -- NASA-style Header
    local headerBar = UIHelpers.CreateNASAHeader({
        Size = UDim2.new(1, 0, 0.16, 0),
        Position = UDim2.new(0, 0, 0, 0)
    })
    headerBar.Parent = mainFrame
    headerBar.ZIndex = 2
    headerBar.ClipsDescendants = true
    
    -- Add rounded top corners to header (will clip the blue stripe at corners)
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 20)
    headerCorner.Parent = headerBar

    -- NASA Logo/Badge (left side)
    local logoFrame = Instance.new("Frame")
    logoFrame.Size = UDim2.new(0.12, 0, 0.7, 0)
    logoFrame.Position = UDim2.new(0.03, 0, 0.15, 0)
    logoFrame.BackgroundColor3 = UIHelpers.Colors.Accent
    logoFrame.BorderSizePixel = 0
    logoFrame.ZIndex = 3
    logoFrame.Parent = headerBar
    
    local logoCorner = Instance.new("UICorner")
    logoCorner.CornerRadius = UDim.new(0.5, 0)
    logoCorner.Parent = logoFrame
    
    local logoText = Instance.new("TextLabel")
    logoText.Size = UDim2.new(1, 0, 1, 0)
    logoText.BackgroundTransparency = 1
    logoText.Text = "NASA"
    logoText.TextColor3 = Color3.fromRGB(255, 255, 255)
    logoText.TextScaled = false
    logoText.TextSize = 20
    logoText.Font = Enum.Font.SourceSansBold
    logoText.ZIndex = 3
    logoText.Parent = logoFrame

    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.75, 0, 0.6, 0)
    titleLabel.Position = UDim2.new(0.18, 0, 0.2, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "HABITAT ARCHITECT"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextScaled = false
    titleLabel.TextSize = 42
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 3
    titleLabel.Parent = headerBar
    
    -- Subtitle in header
    local headerSubtitle = Instance.new("TextLabel")
    headerSubtitle.Size = UDim2.new(0.75, 0, 0.25, 0)
    headerSubtitle.Position = UDim2.new(0.18, 0, 0.7, 0)
    headerSubtitle.BackgroundTransparency = 1
    headerSubtitle.Text = "MISSION PLANNING SYSTEM v2.0"
    headerSubtitle.TextColor3 = UIHelpers.Colors.AccentBright
    headerSubtitle.TextScaled = false
    headerSubtitle.TextSize = 14
    headerSubtitle.Font = Enum.Font.Gotham
    headerSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    headerSubtitle.ZIndex = 3
    headerSubtitle.Parent = headerBar

    -- Content container
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(0.9, 0, 0.75, 0)
    contentFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
    contentFrame.BackgroundTransparency = 1
    contentFrame.ZIndex = 2
    contentFrame.Parent = mainFrame

    -- Subtitle/Description
    local subtitleLabel = Instance.new("TextLabel")
    subtitleLabel.Size = UDim2.new(1, 0, 0.15, 0)
    subtitleLabel.Position = UDim2.new(0, 0, 0.05, 0)
    subtitleLabel.BackgroundTransparency = 1
    subtitleLabel.Text = "Design and validate space habitats for NASA missions"
    subtitleLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
    subtitleLabel.TextScaled = false
    subtitleLabel.TextSize = 20
    subtitleLabel.Font = Enum.Font.SourceSans
    subtitleLabel.TextXAlignment = Enum.TextXAlignment.Center
    subtitleLabel.TextWrapped = true
    subtitleLabel.ZIndex = 3
    subtitleLabel.Parent = contentFrame

    -- Mission info box (NASA-style)
    local infoBox = UIHelpers.CreateRoundedFrame({
        Size = UDim2.new(0.92, 0, 0.38, 0),
        Position = UDim2.new(0.04, 0, 0.22, 0),
        BackgroundColor = Color3.fromRGB(18, 26, 45),
        CornerRadius = 12,
        Stroke = true,
        StrokeColor = Color3.fromRGB(60, 100, 180),
        StrokeThickness = 2
    })
    infoBox.ZIndex = 3
    infoBox.Parent = contentFrame
    
    -- Info title bar
    local infoTitle = Instance.new("TextLabel")
    infoTitle.Size = UDim2.new(1, 0, 0.18, 0)
    infoTitle.Position = UDim2.new(0, 0, 0, 0)
    infoTitle.BackgroundColor3 = Color3.fromRGB(30, 45, 75)
    infoTitle.BorderSizePixel = 0
    infoTitle.Text = "▶ MISSION OBJECTIVES"
    infoTitle.TextColor3 = UIHelpers.Colors.AccentBright
    infoTitle.TextScaled = false
    infoTitle.TextSize = 16
    infoTitle.Font = Enum.Font.GothamBold
    infoTitle.TextXAlignment = Enum.TextXAlignment.Left
    infoTitle.ZIndex = 4
    infoTitle.Parent = infoBox
    
    local infoTitlePadding = Instance.new("UIPadding")
    infoTitlePadding.PaddingLeft = UDim.new(0, 15)
    infoTitlePadding.Parent = infoTitle
    
    local infoTitleCorner = Instance.new("UICorner")
    infoTitleCorner.CornerRadius = UDim.new(0, 12)
    infoTitleCorner.Parent = infoTitle

    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(0.9, 0, 0.75, 0)
    infoText.Position = UDim2.new(0.05, 0, 0.22, 0)
    infoText.BackgroundTransparency = 1
    infoText.Text = "✓  Design modular space habitat architectures\n✓  Configure mission parameters and crew requirements\n✓  Validate designs against NASA safety standards\n✓  Test habitat functionality in real-time simulation\n✓  Optimize for resource efficiency and crew comfort"
    infoText.TextColor3 = Color3.fromRGB(200, 210, 230)
    infoText.TextScaled = false
    infoText.TextSize = 16
    infoText.Font = Enum.Font.Gotham
    infoText.TextXAlignment = Enum.TextXAlignment.Left
    infoText.TextYAlignment = Enum.TextYAlignment.Top
    infoText.TextWrapped = true
    infoText.LineHeight = 1.3
    infoText.ZIndex = 4
    infoText.Parent = infoBox

    -- Button container
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(0.9, 0, 0.25, 0)
    buttonFrame.Position = UDim2.new(0.05, 0, 0.7, 0)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.ZIndex = 3
    buttonFrame.Parent = contentFrame

    -- Check if player has existing mission data
    local missionData = self.MissionDataManager:GetMissionData()
    local hasExistingMission = missionData and (#missionData.ModulesPlaced > 0 or missionData.CurrentState ~= "Welcome")

    if hasExistingMission then
        -- Show Continue + Restart buttons for existing missions
        local continueButton = UIHelpers.CreateRoundedButton({
            Size = UDim2.new(0.47, 0, 0.65, 0),
            Position = UDim2.new(0.02, 0, 0.2, 0),
            Text = "▶ CONTINUE MISSION",
            TextSize = 22,
            Font = Enum.Font.GothamBold,
            BackgroundColor = Color3.fromRGB(60, 150, 100),
            StrokeColor = Color3.fromRGB(80, 180, 120),
            HoverColor = Color3.fromRGB(80, 170, 120),
            HoverStrokeColor = Color3.fromRGB(100, 200, 140),
            CornerRadius = 14
        })
        continueButton.Parent = buttonFrame
        continueButton.MouseButton1Click:Connect(function()
            self:ContinueMission()
        end)

        local restartButton = UIHelpers.CreateRoundedButton({
            Size = UDim2.new(0.47, 0, 0.65, 0),
            Position = UDim2.new(0.51, 0, 0.2, 0),
            Text = "↻ RESTART MISSION",
            TextSize = 22,
            Font = Enum.Font.GothamBold,
            BackgroundColor = Color3.fromRGB(180, 70, 70),
            StrokeColor = Color3.fromRGB(200, 90, 90),
            HoverColor = Color3.fromRGB(200, 90, 90),
            HoverStrokeColor = Color3.fromRGB(220, 110, 110),
            CornerRadius = 14
        })
        restartButton.Parent = buttonFrame
        restartButton.MouseButton1Click:Connect(function()
            self:StartNewMission()
        end)
    else
        -- Show single "Start Playing" button for new players
        local startButton = UIHelpers.CreateRoundedButton({
            Size = UDim2.new(0.7, 0, 0.65, 0),
            Position = UDim2.new(0.15, 0, 0.2, 0),
            Text = "▶ INITIATE MISSION",
            TextSize = 26,
            Font = Enum.Font.GothamBold,
            BackgroundColor = Color3.fromRGB(60, 140, 220),
            StrokeColor = Color3.fromRGB(80, 160, 240),
            HoverColor = Color3.fromRGB(80, 160, 240),
            HoverStrokeColor = Color3.fromRGB(100, 180, 255),
            CornerRadius = 14
        })
        startButton.Parent = buttonFrame
        startButton.MouseButton1Click:Connect(function()
            self:StartNewMission()
        end)
    end

    return self.ScreenGui
end

function WelcomeUI:Show(gui)
    if LocalPlayer.PlayerGui then
        gui.Parent = LocalPlayer.PlayerGui
        print("WelcomeUI: Welcome screen displayed")
    else
        print("WelcomeUI: PlayerGui not available yet, will retry...")
        -- Retry after a short delay
        delay(0.1, function()
            if LocalPlayer.PlayerGui then
                gui.Parent = LocalPlayer.PlayerGui
                print("WelcomeUI: Welcome screen displayed (delayed)")
            else
                print("WelcomeUI: PlayerGui still not available")
            end
        end)
    end
end

function WelcomeUI:Hide(gui)
    gui.Parent = nil
    print("WelcomeUI: Welcome screen hidden")
end

function WelcomeUI:ContinueMission()
    -- Try to load existing mission data
    local missionData = self.MissionDataManager:GetMissionData()
    if missionData and missionData.CurrentState ~= "Welcome" then
        print("WelcomeUI: Continuing existing mission")
        print("- Crew Size: " .. missionData.CrewSize)
        print("- Duration: " .. missionData.Duration .. " days")
        print("- Mission Type: " .. missionData.MissionType)
        print("- Current State: " .. missionData.CurrentState)

        -- Update game state to match saved state
        if missionData.CurrentState == "MissionSetup" then
            self.UIManager.GameState:EnterMissionSetup()
        elseif missionData.CurrentState == "Building" then
            self.UIManager.GameState:EnterBuildingMode()
        elseif missionData.CurrentState == "Play" then
            self.UIManager.GameState:EnterPlayMode()
        end
    else
        print("WelcomeUI: No existing mission found or mission is in welcome state, starting new mission")
        self:StartNewMission()
    end
end

function WelcomeUI:StartNewMission()
    print("WelcomeUI: Starting new mission")
    -- Clear any existing mission data
    self.MissionDataManager:ClearMissionData()
    self.UIManager.GameState:EnterMissionSetup()
end

function WelcomeUI:Destroy()
    if self.ScreenGui then
        self.ScreenGui:Destroy()
        self.ScreenGui = nil
    end
end

return WelcomeUI

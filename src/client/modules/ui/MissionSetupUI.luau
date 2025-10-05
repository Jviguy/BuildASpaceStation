local MissionSetupUI = {}
MissionSetupUI.__index = MissionSetupUI

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UIHelpers = require(script.Parent.UIHelpers)

function MissionSetupUI.new(uiManager, missionDataManager)
    local self = setmetatable({}, MissionSetupUI)

    self.UIManager = uiManager
    self.MissionDataManager = missionDataManager
    self.ScreenGui = nil

    -- Get mission data from manager
    self.MissionData = missionDataManager:GetMissionData()

    -- Determine if this is a new mission by checking if data looks like defaults
    -- If all values are at defaults and no modules placed, it's likely new
    self.IsNewMission = (self.MissionData.CrewSize == 4 and
                        self.MissionData.Duration == 30 and
                        self.MissionData.MissionType == "Lunar Base" and
                        #self.MissionData.ModulesPlaced == 0)

    return self
end

function MissionSetupUI:Create()
    -- Create ScreenGui
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "MissionSetupUI"
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.IgnoreGuiInset = true -- Bypass Roblox topbar

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

    -- Main content card (centered, rounded)
    local mainFrame = UIHelpers.CreateRoundedFrame({
        Size = UDim2.new(0.7, 0, 0.85, 0),
        Position = UDim2.new(0.15, 0, 0.075, 0),
        BackgroundColor = Color3.fromRGB(20, 28, 50),
        CornerRadius = 20,
        Stroke = true,
        StrokeColor = UIHelpers.Colors.BorderBright,
        StrokeThickness = 3
    })
    mainFrame.Parent = bgFrame
    mainFrame.ZIndex = 1
    
    -- Add shadow
    UIHelpers.AddShadow(mainFrame)

    -- NASA-style Header
    local headerBar = UIHelpers.CreateNASAHeader({
        Size = UDim2.new(1, 0, 0.12, 0),
        Position = UDim2.new(0, 0, 0, 0)
    })
    headerBar.Parent = mainFrame
    headerBar.ZIndex = 2
    headerBar.ClipsDescendants = true
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 20)
    headerCorner.Parent = headerBar
    
    -- NASA Logo
    local logoFrame = Instance.new("Frame")
    logoFrame.Size = UDim2.new(0.08, 0, 0.65, 0)
    logoFrame.Position = UDim2.new(0.02, 0, 0.175, 0)
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
    logoText.TextSize = 16
    logoText.Font = Enum.Font.SourceSansBold
    logoText.ZIndex = 3
    logoText.Parent = logoFrame

    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.85, 0, 0.5, 0)
    titleLabel.Position = UDim2.new(0.12, 0, 0.25, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "MISSION CONFIGURATION"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 32
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 3
    titleLabel.Parent = headerBar
    
    local headerSubtitle = Instance.new("TextLabel")
    headerSubtitle.Size = UDim2.new(0.85, 0, 0.25, 0)
    headerSubtitle.Position = UDim2.new(0.12, 0, 0.7, 0)
    headerSubtitle.BackgroundTransparency = 1
    headerSubtitle.Text = "DEFINE MISSION PARAMETERS"
    headerSubtitle.TextColor3 = UIHelpers.Colors.AccentBright
    headerSubtitle.TextSize = 12
    headerSubtitle.Font = Enum.Font.Gotham
    headerSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    headerSubtitle.ZIndex = 3
    headerSubtitle.Parent = headerBar

    -- Content container below header
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, 0, 0.88, 0)
    contentFrame.Position = UDim2.new(0, 0, 0.12, 0)
    contentFrame.BackgroundTransparency = 1
    contentFrame.ZIndex = 2
    contentFrame.Parent = mainFrame
    
    -- Form container with padding
    local formFrame = Instance.new("Frame")
    formFrame.Size = UDim2.new(0.9, 0, 0.75, 0)
    formFrame.Position = UDim2.new(0.05, 0, 0.05, 0)
    formFrame.BackgroundTransparency = 1
    formFrame.ZIndex = 3
    formFrame.Parent = contentFrame

    -- Mission info label
    local missionInfoLabel = Instance.new("TextLabel")
    missionInfoLabel.Size = UDim2.new(1, 0, 0.15, 0)
    missionInfoLabel.Position = UDim2.new(0, 0, 0, 0)
    missionInfoLabel.BackgroundTransparency = 1
    missionInfoLabel.Text = "Configure your orbital space station mission parameters"
    missionInfoLabel.TextColor3 = UIHelpers.Colors.TextDim
    missionInfoLabel.TextSize = 16
    missionInfoLabel.Font = Enum.Font.Gotham
    missionInfoLabel.TextXAlignment = Enum.TextXAlignment.Center
    missionInfoLabel.ZIndex = 3
    missionInfoLabel.Parent = formFrame
    
    -- Crew size input
    self:CreateFormField(formFrame, "Crew Size:", "Number", 1, 0, 20, self.MissionData.CrewSize)
    -- Duration input
    self:CreateFormField(formFrame, "Mission Duration (days):", "Number", 2, 7, 1000, self.MissionData.Duration)

    -- Button container at bottom
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(0.9, 0, 0.15, 0)
    buttonFrame.Position = UDim2.new(0.05, 0, 0.83, 0)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.ZIndex = 3
    buttonFrame.Parent = contentFrame

    -- Start Building button (prominent)
    local startButton = UIHelpers.CreateRoundedButton({
        Size = UDim2.new(0.45, 0, 0.7, 0),
        Position = UDim2.new(0.52, 0, 0.15, 0),
        Text = "▶ START BUILDING",
        TextSize = 20,
        BackgroundColor = Color3.fromRGB(80, 200, 100),
        StrokeColor = Color3.fromRGB(100, 220, 120),
        HoverColor = Color3.fromRGB(100, 220, 120),
        HoverStrokeColor = Color3.fromRGB(120, 240, 140),
        CornerRadius = 12
    })
    startButton.Font = Enum.Font.GothamBold
    startButton.Parent = buttonFrame

    -- Back button
    local backButton = UIHelpers.CreateRoundedButton({
        Size = UDim2.new(0.45, 0, 0.7, 0),
        Position = UDim2.new(0.03, 0, 0.15, 0),
        Text = "← BACK",
        TextSize = 20,
        BackgroundColor = Color3.fromRGB(100, 110, 130),
        StrokeColor = Color3.fromRGB(120, 130, 150),
        HoverColor = Color3.fromRGB(120, 130, 150),
        HoverStrokeColor = Color3.fromRGB(140, 150, 170),
        CornerRadius = 12
    })
    backButton.Font = Enum.Font.GothamBold
    backButton.Parent = buttonFrame

    -- Button click handlers
    startButton.MouseButton1Click:Connect(function()
        self:OnStartBuilding()
    end)

    backButton.MouseButton1Click:Connect(function()
        self.UIManager.GameState:EnterWelcome()
    end)

    return self.ScreenGui
end

function MissionSetupUI:CreateFormField(parent, labelText, fieldType, row, minValue, maxValue, defaultValue)
    local rowHeight = 0.25
    local startY = (row - 1) * rowHeight
    
    -- Field container with rounded background
    local fieldContainer = Instance.new("Frame")
    fieldContainer.Size = UDim2.new(1, 0, 0.2, 0)
    fieldContainer.Position = UDim2.new(0, 0, startY + 0.02, 0)
    fieldContainer.BackgroundColor3 = Color3.fromRGB(28, 38, 65)
    fieldContainer.BorderSizePixel = 0
    fieldContainer.ZIndex = 3
    fieldContainer.Parent = parent
    
    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 12)
    containerCorner.Parent = fieldContainer
    
    local containerStroke = Instance.new("UIStroke")
    containerStroke.Color = Color3.fromRGB(70, 90, 130)
    containerStroke.Thickness = 2
    containerStroke.Parent = fieldContainer

    -- Label
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.45, 0, 0.8, 0)
    label.Position = UDim2.new(0.05, 0, 0.1, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = UIHelpers.Colors.AccentBright
    label.TextScaled = false
    label.TextSize = 18
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.GothamMedium
    label.ZIndex = 4
    label.Parent = fieldContainer

    -- Input field
    local input
    if fieldType == "Number" then
        input = Instance.new("TextBox")
        input.PlaceholderText = tostring(defaultValue)
        input.Text = tostring(defaultValue)
        input.ClearTextOnFocus = false
    elseif fieldType == "Dropdown" then
        input = Instance.new("TextButton")
        input.Text = "Lunar Base"
        input.BackgroundColor3 = Color3.fromRGB(40, 52, 85)
    end

    input.Size = UDim2.new(0.42, 0, 0.65, 0)
    input.Position = UDim2.new(0.53, 0, 0.175, 0)
    input.BackgroundColor3 = Color3.fromRGB(15, 22, 45)
    input.BorderSizePixel = 0
    input.TextColor3 = Color3.fromRGB(255, 255, 255)
    input.TextScaled = false
    input.TextSize = 18
    input.Font = Enum.Font.Gotham
    input.ZIndex = 4
    input.Parent = fieldContainer

    -- Add rounded corners to input
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = input
    
    -- Add stroke to input
    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color = Color3.fromRGB(80, 110, 150)
    inputStroke.Thickness = 2
    inputStroke.Parent = input

    -- Store reference for data collection
    if row == 1 then
        self.CrewSizeInput = input
        -- Validate crew size input
        input:GetPropertyChangedSignal("Text"):Connect(function()
            local val = tonumber(input.Text)
            if val and (val < minValue or val > maxValue) then
                inputStroke.Color = Color3.fromRGB(255, 100, 100)
            else
                inputStroke.Color = Color3.fromRGB(80, 110, 150)
            end
        end)
    elseif row == 2 then
        self.DurationInput = input
        -- Validate duration input
        input:GetPropertyChangedSignal("Text"):Connect(function()
            local val = tonumber(input.Text)
            if val and (val < minValue or val > maxValue) then
                inputStroke.Color = Color3.fromRGB(255, 100, 100)
            else
                inputStroke.Color = Color3.fromRGB(80, 110, 150)
            end
        end)
    end
end

function MissionSetupUI:OnStartBuilding()
    -- Collect form data
    local crewSize = tonumber(self.CrewSizeInput.Text) or self.MissionData.CrewSize
    local duration = tonumber(self.DurationInput.Text) or self.MissionData.Duration

    -- Validate inputs
    if crewSize < 1 or crewSize > 20 then
        warn("Invalid crew size: " .. crewSize)
        return
    end

    if duration < 7 or duration > 1000 then
        warn("Invalid duration: " .. duration)
        return
    end

    -- Update mission data through manager
    self.MissionDataManager:UpdateMissionData({
        CrewSize = crewSize,
        Duration = duration,
        MissionType = "Earth Orbit", -- Fixed mission type for now
        CurrentState = "Building"
    })

    print("Mission Setup Complete:")
    print("- Crew Size: " .. crewSize)
    print("- Duration: " .. duration .. " days")
    print("- Mission Type: Earth Orbit")

    -- Transition to building mode
    self.UIManager.GameState:EnterBuildingMode()
end

function MissionSetupUI:Show(gui)
    if LocalPlayer.PlayerGui then
        gui.Parent = LocalPlayer.PlayerGui
        print("MissionSetupUI: Mission setup form displayed")
    else
        print("MissionSetupUI: PlayerGui not available yet, will retry...")
        delay(0.1, function()
            if LocalPlayer.PlayerGui then
                gui.Parent = LocalPlayer.PlayerGui
                print("MissionSetupUI: Mission setup form displayed (delayed)")
            else
                print("MissionSetupUI: PlayerGui still not available")
            end
        end)
    end
end

function MissionSetupUI:Hide(gui)
    gui.Parent = nil
    print("MissionSetupUI: Mission setup form hidden")
end

function MissionSetupUI:Destroy()
    if self.ScreenGui then
        self.ScreenGui:Destroy()
        self.ScreenGui = nil
    end
end

return MissionSetupUI

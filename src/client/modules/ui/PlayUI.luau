local PlayUI = {}
PlayUI.__index = PlayUI

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

function PlayUI.new(uiManager, missionDataManager)
    local self = setmetatable({}, PlayUI)

    self.UIManager = uiManager
    self.MissionDataManager = missionDataManager
    self.ScreenGui = nil

    -- Get mission data from manager
    self.MissionData = missionDataManager:GetMissionData()

    return self
end

function PlayUI:Create()
    -- Create ScreenGui
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "PlayUI"
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.IgnoreGuiInset = true -- Bypass Roblox topbar

    -- Main container
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 25, 35)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = self.ScreenGui

    -- Top bar
    self:CreateTopBar(mainFrame)

    -- Left panel (mission status)
    self:CreateMissionStatus(mainFrame)

    -- Right panel (habitat validation)
    self:CreateHabitatValidation(mainFrame)

    -- Bottom bar (controls)
    self:CreateBottomBar(mainFrame)

    return self.ScreenGui
end

function PlayUI:CreateTopBar(parent)
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0.08, 0)
    topBar.Position = UDim2.new(0, 0, 0, 0)
    topBar.BackgroundColor3 = Color3.fromRGB(35, 45, 55)
    topBar.BorderSizePixel = 0
    topBar.Parent = parent

    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.3, 0, 1, 0)
    titleLabel.Position = UDim2.new(0.02, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Play Mode - Testing Habitat"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.Parent = topBar

    -- Mission info
    local missionLabel = Instance.new("TextLabel")
    missionLabel.Size = UDim2.new(0.4, 0, 1, 0)
    missionLabel.Position = UDim2.new(0.35, 0, 0, 0)
    missionLabel.BackgroundTransparency = 1
    missionLabel.Text = "Crew: 4 | Duration: 30 days"
    missionLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    missionLabel.TextScaled = true
    missionLabel.Font = Enum.Font.SourceSans
    missionLabel.Parent = topBar
end

function PlayUI:CreateMissionStatus(parent)
    local statusFrame = Instance.new("Frame")
    statusFrame.Size = UDim2.new(0.4, 0, 0.92, 0)
    statusFrame.Position = UDim2.new(0.05, 0, 0.08, 0)
    statusFrame.BackgroundColor3 = Color3.fromRGB(25, 35, 45)
    statusFrame.BorderSizePixel = 0
    statusFrame.Parent = parent

    -- Status title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0.08, 0)
    titleLabel.BackgroundColor3 = Color3.fromRGB(45, 55, 65)
    titleLabel.BorderSizePixel = 0
    titleLabel.Text = "Mission Status"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.Parent = statusFrame

    -- Status items (would be calculated based on placed modules)
    self.StatusLabels = {}

    local statusItems = {
        {name = "Sleep Quarters", current = 0, required = 24, unit = "m²"},
        {name = "Exercise Area", current = 0, required = 12, unit = "m²"},
        {name = "Galley/Food Prep", current = 0, required = 8, unit = "m²"},
        {name = "Laboratory", current = 0, required = 16, unit = "m²"}
    }

    local startY = 0.12
    for i, item in ipairs(statusItems) do
        local itemFrame = Instance.new("Frame")
        itemFrame.Size = UDim2.new(0.9, 0, 0.15, 0)
        itemFrame.Position = UDim2.new(0.05, 0, startY, 0)
        itemFrame.BackgroundTransparency = 1
        itemFrame.Parent = statusFrame

        -- Item name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0.6, 0, 0.6, 0)
        nameLabel.Position = UDim2.new(0, 0, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = item.name
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextScaled = true
        nameLabel.Font = Enum.Font.SourceSans
        nameLabel.Parent = itemFrame

        -- Progress bar background
        local progressBg = Instance.new("Frame")
        progressBg.Size = UDim2.new(0.35, 0, 0.3, 0)
        progressBg.Position = UDim2.new(0.65, 0, 0.35, 0)
        progressBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        progressBg.BorderSizePixel = 0
        progressBg.Parent = itemFrame

        -- Progress bar fill
        local progressFill = Instance.new("Frame")
        progressFill.Size = UDim2.new(0, 0, 1, 0) -- Will be updated
        progressFill.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
        progressFill.BorderSizePixel = 0
        progressFill.Parent = progressBg

        -- Progress text
        local progressText = Instance.new("TextLabel")
        progressText.Size = UDim2.new(1, 0, 1, 0)
        progressText.BackgroundTransparency = 1
        progressText.Text = "0 / " .. item.required .. " " .. item.unit
        progressText.TextColor3 = Color3.fromRGB(255, 255, 255)
        progressText.TextScaled = true
        progressText.Font = Enum.Font.SourceSans
        progressText.Parent = progressBg

        self.StatusLabels[i] = {
            progressFill = progressFill,
            progressText = progressText,
            required = item.required
        }

        startY = startY + 0.18
    end
end

function PlayUI:CreateHabitatValidation(parent)
    local validationFrame = Instance.new("Frame")
    validationFrame.Size = UDim2.new(0.4, 0, 0.92, 0)
    validationFrame.Position = UDim2.new(0.55, 0, 0.08, 0)
    validationFrame.BackgroundColor3 = Color3.fromRGB(25, 35, 45)
    validationFrame.BorderSizePixel = 0
    validationFrame.Parent = parent

    -- Validation title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0.08, 0)
    titleLabel.BackgroundColor3 = Color3.fromRGB(45, 55, 65)
    titleLabel.BorderSizePixel = 0
    titleLabel.Text = "Habitat Validation"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.Parent = validationFrame

    -- Validation status
    self.ValidationStatusLabel = Instance.new("TextLabel")
    self.ValidationStatusLabel.Size = UDim2.new(0.9, 0, 0.2, 0)
    self.ValidationStatusLabel.Position = UDim2.new(0.05, 0, 0.12, 0)
    self.ValidationStatusLabel.BackgroundTransparency = 1
    self.ValidationStatusLabel.Text = "Place modules to meet requirements"
    self.ValidationStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    self.ValidationStatusLabel.TextScaled = true
    self.ValidationStatusLabel.TextWrapped = true
    self.ValidationStatusLabel.Font = Enum.Font.SourceSans
    self.ValidationStatusLabel.Parent = validationFrame

    -- Validation checklist
    self:CreateValidationChecklist(validationFrame)
end

function PlayUI:CreateValidationChecklist(parent)
    local checklistFrame = Instance.new("Frame")
    checklistFrame.Size = UDim2.new(0.9, 0, 0.6, 0)
    checklistFrame.Position = UDim2.new(0.05, 0, 0.35, 0)
    checklistFrame.BackgroundTransparency = 1
    checklistFrame.Parent = parent

    local requirements = {
        "All crew members have sleep quarters",
        "Exercise area meets requirements",
        "Food preparation area adequate",
        "Laboratory space sufficient",
        "Emergency egress routes clear"
    }

    local startY = 0
    for i, requirement in ipairs(requirements) do
        local itemFrame = Instance.new("Frame")
        itemFrame.Size = UDim2.new(1, 0, 0.15, 0)
        itemFrame.Position = UDim2.new(0, 0, startY, 0)
        itemFrame.BackgroundTransparency = 1
        itemFrame.Parent = checklistFrame

        -- Status indicator (circle)
        local statusCircle = Instance.new("Frame")
        statusCircle.Size = UDim2.new(0.05, 0, 0.6, 0)
        statusCircle.Position = UDim2.new(0, 0, 0.2, 0)
        statusCircle.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- Red for incomplete
        statusCircle.BorderSizePixel = 0
        statusCircle.Parent = itemFrame

        -- Requirement text
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(0.85, 0, 1, 0)
        textLabel.Position = UDim2.new(0.1, 0, 0, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = requirement
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.TextScaled = true
        textLabel.TextWrapped = true
        textLabel.Font = Enum.Font.SourceSans
        textLabel.Parent = itemFrame

        startY = startY + 0.18
    end
end

function PlayUI:CreateBottomBar(parent)
    local bottomBar = Instance.new("Frame")
    bottomBar.Size = UDim2.new(1, 0, 0.08, 0)
    bottomBar.Position = UDim2.new(0, 0, 0.92, 0)
    bottomBar.BackgroundColor3 = Color3.fromRGB(35, 45, 55)
    bottomBar.BorderSizePixel = 0
    bottomBar.Parent = parent

    -- Back to building button
    local backButton = Instance.new("TextButton")
    backButton.Size = UDim2.new(0.2, 0, 0.8, 0)
    backButton.Position = UDim2.new(0.1, 0, 0.1, 0)
    backButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
    backButton.BorderSizePixel = 0
    backButton.Text = "Back to Building"
    backButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    backButton.TextScaled = true
    backButton.Font = Enum.Font.SourceSansBold
    backButton.Parent = bottomBar

    -- Complete mission button
    local completeButton = Instance.new("TextButton")
    completeButton.Size = UDim2.new(0.2, 0, 0.8, 0)
    completeButton.Position = UDim2.new(0.7, 0, 0.1, 0)
    completeButton.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
    completeButton.BorderSizePixel = 0
    completeButton.Text = "Complete Mission"
    completeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    completeButton.TextScaled = true
    completeButton.Font = Enum.Font.SourceSansBold
    completeButton.Parent = bottomBar

    -- Button hover effects
    local function onBackHover()
        backButton.BackgroundColor3 = Color3.fromRGB(170, 170, 170)
    end

    local function onBackLeave()
        backButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
    end

    local function onCompleteHover()
        completeButton.BackgroundColor3 = Color3.fromRGB(120, 220, 120)
    end

    local function onCompleteLeave()
        completeButton.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
    end

    backButton.MouseEnter:Connect(onBackHover)
    backButton.MouseLeave:Connect(onBackLeave)
    completeButton.MouseEnter:Connect(onCompleteHover)
    completeButton.MouseLeave:Connect(onCompleteLeave)

    -- Button click handlers
    backButton.MouseButton1Click:Connect(function()
        self.UIManager.GameState:EnterBuildingMode()
    end)

    completeButton.MouseButton1Click:Connect(function()
        self:OnMissionComplete()
        self.UIManager.GameState:EnterGameOver()
    end)
end

function PlayUI:UpdateValidationStatus()
    -- This would be called to update the UI based on current habitat state
    -- For now, just update the status text
    self.ValidationStatusLabel.Text = "Validating habitat configuration..."
end

function PlayUI:OnMissionComplete()
    -- Update mission state to game over
    self.MissionDataManager:UpdateMissionData({
        CurrentState = "GameOver"
    })
    print("PlayUI: Mission completed, state updated to GameOver")
end

function PlayUI:Show(gui)
    if LocalPlayer.PlayerGui then
        gui.Parent = LocalPlayer.PlayerGui
        print("PlayUI: Play interface displayed")
    else
        print("PlayUI: PlayerGui not available yet, will retry...")
        delay(0.1, function()
            if LocalPlayer.PlayerGui then
                gui.Parent = LocalPlayer.PlayerGui
                print("PlayUI: Play interface displayed (delayed)")
            else
                print("PlayUI: PlayerGui still not available")
            end
        end)
    end
end

function PlayUI:Hide(gui)
    gui.Parent = nil
    print("PlayUI: Play interface hidden")
end

function PlayUI:Destroy()
    if self.ScreenGui then
        self.ScreenGui:Destroy()
        self.ScreenGui = nil
    end
end

return PlayUI

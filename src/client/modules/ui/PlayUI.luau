local PlayUI = {}
PlayUI.__index = PlayUI

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local LocalPlayer = Players.LocalPlayer

function PlayUI.new(uiManager, missionDataManager, cameraController)
    local self = setmetatable({}, PlayUI)

    self.UIManager = uiManager
    self.MissionDataManager = missionDataManager
    self.CameraController = cameraController
    self.ScreenGui = nil
    
    -- Money system
    self.Money = 0
    self.MoneyLabel = nil
    self.MoneyConnection = nil
    
    -- Visual effects
    self.EffectsContainer = nil
    
    -- Get mission data from manager
    self.MissionData = missionDataManager:GetMissionData()

    return self
end

function PlayUI:Create()
    -- Create ScreenGui
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "PlayUI"
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.IgnoreGuiInset = true
    self.ScreenGui.DisplayOrder = 10

    -- Create space background
    self:CreateSpaceBackground()
    
    -- Create money UI
    self:CreateMoneyUI()
    
    -- Create effects container
    self:CreateEffectsContainer()
    
    -- Create mission info UI
    self:CreateMissionInfoUI()
    
    -- Create back button
    self:CreateBackButton()

    return self.ScreenGui
end

function PlayUI:CreateSpaceBackground()
    -- Create a space-like background
    local background = Instance.new("Frame")
    background.Size = UDim2.fromScale(1, 1)
    background.Position = UDim2.fromScale(0, 0)
    background.BackgroundColor3 = Color3.fromRGB(5, 10, 25) -- Dark space color
    background.BorderSizePixel = 0
    background.Parent = self.ScreenGui
    
    -- Add some stars
    for i = 1, 50 do
        local star = Instance.new("Frame")
        star.Size = UDim2.fromOffset(math.random(1, 3), math.random(1, 3))
        star.Position = UDim2.fromScale(math.random(), math.random())
        star.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        star.BorderSizePixel = 0
        star.Parent = background
        
        -- Make some stars twinkle
        if math.random() > 0.7 then
            local tween = TweenService:Create(star, 
                TweenInfo.new(math.random(1, 3), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                {BackgroundTransparency = 0.8}
            )
            tween:Play()
        end
    end
end

function PlayUI:CreateMoneyUI()
    -- Money display frame
    local moneyFrame = Instance.new("Frame")
    moneyFrame.Size = UDim2.fromOffset(300, 80)
    moneyFrame.Position = UDim2.new(0, 20, 0, 20)
    moneyFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
    moneyFrame.BorderSizePixel = 0
    moneyFrame.Parent = self.ScreenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = moneyFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 200, 100)
    stroke.Thickness = 2
    stroke.Parent = moneyFrame
    
    -- Money icon
    local moneyIcon = Instance.new("TextLabel")
    moneyIcon.Size = UDim2.fromOffset(40, 40)
    moneyIcon.Position = UDim2.fromOffset(10, 20)
    moneyIcon.BackgroundTransparency = 1
    moneyIcon.Text = "💰"
    moneyIcon.TextSize = 32
    moneyIcon.Font = Enum.Font.GothamBold
    moneyIcon.Parent = moneyFrame
    
    -- Money label
    self.MoneyLabel = Instance.new("TextLabel")
    self.MoneyLabel.Size = UDim2.new(1, -60, 1, 0)
    self.MoneyLabel.Position = UDim2.fromOffset(60, 0)
    self.MoneyLabel.BackgroundTransparency = 1
    self.MoneyLabel.Text = "$0"
    self.MoneyLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    self.MoneyLabel.TextSize = 24
    self.MoneyLabel.Font = Enum.Font.GothamBold
    self.MoneyLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.MoneyLabel.Parent = moneyFrame
end

function PlayUI:CreateEffectsContainer()
    -- Container for money gain effects
    self.EffectsContainer = Instance.new("Frame")
    self.EffectsContainer.Size = UDim2.fromScale(1, 1)
    self.EffectsContainer.Position = UDim2.fromScale(0, 0)
    self.EffectsContainer.BackgroundTransparency = 1
    self.EffectsContainer.Parent = self.ScreenGui
end

function PlayUI:CreateMissionInfoUI()
    -- Mission info frame
    local infoFrame = Instance.new("Frame")
    infoFrame.Size = UDim2.fromOffset(250, 120)
    infoFrame.Position = UDim2.new(1, -270, 0, 20)
    infoFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
    infoFrame.BorderSizePixel = 0
    infoFrame.Parent = self.ScreenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = infoFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 150, 255)
    stroke.Thickness = 2
    stroke.Parent = infoFrame
    
    -- Mission title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -20, 0, 30)
    titleLabel.Position = UDim2.fromOffset(10, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🚀 MISSION ACTIVE"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = infoFrame
    
    -- Mission details
    local detailsLabel = Instance.new("TextLabel")
    detailsLabel.Size = UDim2.new(1, -20, 0, 70)
    detailsLabel.Position = UDim2.fromOffset(10, 40)
    detailsLabel.BackgroundTransparency = 1
    detailsLabel.Text = string.format("Type: %s\nCrew: %d\nDuration: %d days", 
        self.MissionData.MissionType, self.MissionData.CrewSize, self.MissionData.Duration)
    detailsLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
    detailsLabel.TextSize = 14
    detailsLabel.Font = Enum.Font.Gotham
    detailsLabel.TextXAlignment = Enum.TextXAlignment.Left
    detailsLabel.TextYAlignment = Enum.TextYAlignment.Top
    detailsLabel.Parent = infoFrame
end

function PlayUI:CreateBackButton()
    -- Back button
    local backButton = Instance.new("TextButton")
    backButton.Size = UDim2.fromOffset(120, 50)
    backButton.Position = UDim2.new(0.5, -60, 1, -70)
    backButton.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
    backButton.BorderSizePixel = 0
    backButton.Text = "← Back to Building"
    backButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    backButton.TextSize = 14
    backButton.Font = Enum.Font.GothamBold
    backButton.Parent = self.ScreenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = backButton
    
    -- Hover effects
    backButton.MouseEnter:Connect(function()
        backButton.BackgroundColor3 = Color3.fromRGB(220, 120, 120)
    end)
    
    backButton.MouseLeave:Connect(function()
        backButton.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
    end)
    
    -- Click handler
    backButton.MouseButton1Click:Connect(function()
        self:StopMission()
        self.UIManager.GameState:EnterBuildingMode()
    end)
end

function PlayUI:StartMission()
    print("PlayUI: Starting mission simulation")
    
    -- Set camera to top-down view of the space station
    if self.CameraController then
        self.CameraController:SetTopDownView()
    end
    
    -- Start money generation
    self:StartMoneyGeneration()
end

function PlayUI:StartMoneyGeneration()
    -- Generate money randomly every 1-3 seconds
    local function generateMoney()
        if not self.MoneyConnection then return end
        
        local amount = math.random(50, 200)
        self:AddMoney(amount)
        
        -- Schedule next money generation
        task.wait(math.random(1, 3))
        generateMoney()
    end
    
    -- Start the money generation loop
    self.MoneyConnection = task.spawn(generateMoney)
end

function PlayUI:AddMoney(amount)
    self.Money = self.Money + amount
    self.MoneyLabel.Text = "$" .. tostring(self.Money)
    
    -- Create visual effect
    self:CreateMoneyEffect(amount)
    
    -- Play sound effect
    self:PlayCashSound()
    
    -- Animate money counter
    self:AnimateMoneyCounter()
end

function PlayUI:CreateMoneyEffect(amount)
    -- Create floating money text
    local effectLabel = Instance.new("TextLabel")
    effectLabel.Size = UDim2.fromOffset(100, 40)
    effectLabel.Position = UDim2.new(math.random(20, 80) / 100, 0, math.random(20, 80) / 100, 0)
    effectLabel.BackgroundTransparency = 1
    effectLabel.Text = "+$" .. tostring(amount)
    effectLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    effectLabel.TextSize = 20
    effectLabel.Font = Enum.Font.GothamBold
    effectLabel.TextStrokeTransparency = 0
    effectLabel.TextStrokeColor3 = Color3.fromRGB(0, 100, 0)
    effectLabel.Rotation = math.random(-15, 15)
    effectLabel.Parent = self.EffectsContainer
    
    -- Animate the effect
    local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(effectLabel, tweenInfo, {
        Position = UDim2.new(effectLabel.Position.X.Scale, 0, effectLabel.Position.Y.Scale - 0.2, 0),
        TextTransparency = 1,
        TextStrokeTransparency = 1
    })
    
    tween:Play()
    tween.Completed:Connect(function()
        effectLabel:Destroy()
    end)
end

function PlayUI:PlayCashSound()
    -- Create a simple cash register sound effect
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxasset://sounds/electronicpingshort.wav" -- Built-in Roblox sound
    sound.Volume = 0.3
    sound.Pitch = math.random(80, 120) / 100 -- Vary pitch slightly
    sound.Parent = self.ScreenGui
    
    sound:Play()
    sound.Ended:Connect(function()
        sound:Destroy()
    end)
end

function PlayUI:AnimateMoneyCounter()
    -- Scale animation for money counter
    local originalSize = self.MoneyLabel.Size
    local scaleUp = TweenService:Create(self.MoneyLabel, 
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(originalSize.X.Scale * 1.1, originalSize.X.Offset, originalSize.Y.Scale * 1.1, originalSize.Y.Offset)}
    )
    
    local scaleDown = TweenService:Create(self.MoneyLabel,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = originalSize}
    )
    
    scaleUp:Play()
    scaleUp.Completed:Connect(function()
        scaleDown:Play()
    end)
end

function PlayUI:StopMission()
    print("PlayUI: Stopping mission simulation")
    
    -- Stop money generation
    if self.MoneyConnection then
        task.cancel(self.MoneyConnection)
        self.MoneyConnection = nil
    end
    
    -- Reset camera
    if self.CameraController then
        self.CameraController:ResetCamera()
    end
end

function PlayUI:Show(gui)
    if LocalPlayer.PlayerGui then
        gui.Parent = LocalPlayer.PlayerGui
        self:StartMission()
        print("PlayUI: Play mode started with top-down view")
    else
        warn("PlayUI: PlayerGui not available")
    end
end

function PlayUI:Hide(gui)
    self:StopMission()
    gui.Parent = nil
    print("PlayUI: Play mode stopped")
end

function PlayUI:Destroy()
    self:StopMission()
    if self.ScreenGui then
        self.ScreenGui:Destroy()
        self.ScreenGui = nil
    end
end

return PlayUI

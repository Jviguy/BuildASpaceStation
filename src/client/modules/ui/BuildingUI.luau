local BuildingUI = {}
BuildingUI.__index = BuildingUI

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Require UIHelpers for consistent styling
local UIHelpers = require(script.Parent.UIHelpers)

function BuildingUI.new(uiManager, missionDataManager, buildingSystem)
	local self = setmetatable({}, BuildingUI)

	self.UIManager = uiManager
	self.MissionDataManager = missionDataManager
	self.BuildingSystem = buildingSystem
	self.ScreenGui = nil

	-- UI state
	self.SelectedModule = nil
	self.SelectedModuleData = nil
	self.ModuleButtons = {}

	-- UI elements
	self.CatalogFrame = nil
	self.ConfirmCancelFrame = nil

	return self
end

-- Module catalog data (BS data as requested)
local MODULE_CATALOG = {
	{
		id = "hab_module_a",
		name = "Habitat Module A",
		category = "Living Quarters",
		size = "4x3x2",
		capacity = "4 crew",
		description = "Standard living quarters with bunks, storage, and life support systems.",
		cost = 5000,
		power = 150,
		icon = "🏠",
	},
	{
		id = "lab_module_alpha",
		name = "Research Lab Alpha",
		category = "Science",
		size = "5x3x2",
		capacity = "2 crew",
		description = "Equipped with microscopes, spectrometers, and experiment racks.",
		cost = 8000,
		power = 300,
		icon = "🔬",
	},
	{
		id = "corridor_straight",
		name = "Corridor Segment",
		category = "Connectors",
		size = "4x1x1",
		capacity = "Transit",
		description = "Standard connecting corridor for linking modules together.",
		cost = 1500,
		power = 50,
		icon = "➡️",
	},
	{
		id = "junction_cross",
		name = "Cross Junction",
		category = "Connectors",
		size = "2x2x2",
		capacity = "Transit",
		description = "Four-way junction node for complex station layouts.",
		cost = 2500,
		power = 75,
		icon = "✚",
	},
	{
		id = "airlock_standard",
		name = "Airlock Module",
		category = "EVA",
		size = "3x2x2",
		capacity = "2 crew",
		description = "Pressurized airlock for extravehicular activities and docking.",
		cost = 6000,
		power = 200,
		icon = "🚪",
	},
	{
		id = "solar_array",
		name = "Solar Panel Array",
		category = "Power",
		size = "6x4x1",
		capacity = "N/A",
		description = "High-efficiency photovoltaic arrays generating 1000W peak power.",
		cost = 10000,
		power = -1000,
		icon = "☀️",
	},
	{
		id = "cupola_observation",
		name = "Cupola Module",
		category = "Observation",
		size = "3x3x2",
		capacity = "3 crew",
		description = "360° panoramic windows for Earth observation and operations.",
		cost = 12000,
		power = 100,
		icon = "🔭",
	},
	{
		id = "storage_bay",
		name = "Cargo Storage Bay",
		category = "Storage",
		size = "4x3x3",
		capacity = "500 kg",
		description = "Secure storage for supplies, equipment, and experiments.",
		cost = 4000,
		power = 80,
		icon = "📦",
	},
	{
		id = "greenhouse_module",
		name = "Botanical Lab",
		category = "Science",
		size = "5x3x2",
		capacity = "1 crew",
		description = "Controlled environment for growing plants and food production.",
		cost = 9500,
		power = 400,
		icon = "🌱",
	},
	{
		id = "command_center",
		name = "Command Module",
		category = "Operations",
		size = "4x4x2",
		capacity = "3 crew",
		description = "Mission control center with communications and monitoring systems.",
		cost = 15000,
		power = 500,
		icon = "🎛️",
	},
}

function BuildingUI:Create()
	-- Create ScreenGui
	self.ScreenGui = Instance.new("ScreenGui")
	self.ScreenGui.Name = "BuildingUI"
	self.ScreenGui.ResetOnSpawn = false
	self.ScreenGui.IgnoreGuiInset = true

	-- Create bottom catalog (starts visible)
	self:CreateModuleCatalog()

	-- Create confirm/cancel UI (starts hidden)
	self:CreateConfirmCancelUI()

	return self.ScreenGui
end

function BuildingUI:CreateModuleCatalog()
	-- Main catalog container at bottom (25% of screen)
	self.CatalogFrame = Instance.new("Frame")
	self.CatalogFrame.Size = UDim2.new(1, 0, 0.28, 0)
	self.CatalogFrame.Position = UDim2.new(0, 0, 0.72, 0)
	self.CatalogFrame.BackgroundColor3 = Color3.fromRGB(15, 22, 40)
	self.CatalogFrame.BorderSizePixel = 0
	self.CatalogFrame.ZIndex = 100
	self.CatalogFrame.Parent = self.ScreenGui

	-- Top border stripe
	local topStripe = Instance.new("Frame")
	topStripe.Size = UDim2.new(1, 0, 0, 3)
	topStripe.Position = UDim2.new(0, 0, 0, 0)
	topStripe.BackgroundColor3 = UIHelpers.Colors.Accent
	topStripe.BorderSizePixel = 0
	topStripe.ZIndex = 101
	topStripe.Parent = self.CatalogFrame

	-- Header section
	local headerFrame = Instance.new("Frame")
	headerFrame.Size = UDim2.new(1, 0, 0.22, 0)
	headerFrame.Position = UDim2.new(0, 0, 0.02, 0)
	headerFrame.BackgroundTransparency = 1
	headerFrame.ZIndex = 101
	headerFrame.Parent = self.CatalogFrame

	-- Catalog title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(0.3, 0, 1, 0)
	titleLabel.Position = UDim2.new(0.02, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "MODULE CATALOG"
	titleLabel.TextColor3 = UIHelpers.Colors.Text
	titleLabel.TextSize = 24
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 101
	titleLabel.Parent = headerFrame

	-- Subtitle
	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Size = UDim2.new(0.4, 0, 0.5, 0)
	subtitleLabel.Position = UDim2.new(0.35, 0, 0.5, 0)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = "Select a module to place on the station"
	subtitleLabel.TextColor3 = UIHelpers.Colors.TextDim
	subtitleLabel.TextSize = 14
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.ZIndex = 101
	subtitleLabel.Parent = headerFrame

	-- "Complete Building" button in header
	local completeButton = UIHelpers.CreateRoundedButton({
		Size = UDim2.new(0, 160, 0.18, 0),
		Position = UDim2.new(1, -170, 0.03, 0),
		Text = "▶ START MISSION",
		TextSize = 13,
		BackgroundColor = UIHelpers.Colors.Success,
		StrokeColor = Color3.fromRGB(100, 220, 140),
		HoverColor = Color3.fromRGB(100, 220, 140),
		HoverStrokeColor = Color3.fromRGB(120, 240, 160),
		CornerRadius = 8,
		ZIndex = 102,
	})
	completeButton.Font = Enum.Font.GothamBold
	completeButton.Parent = headerFrame

	completeButton.MouseButton1Click:Connect(function()
		self:OnTransitionToPlay()
		self.UIManager.GameState:EnterPlayMode()
	end)

	-- Scrolling frame for module cards
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Size = UDim2.new(0.96, 0, 0.7, 0)
	scrollFrame.Position = UDim2.new(0.02, 0, 0.28, 0)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.ScrollBarImageColor3 = UIHelpers.Colors.Accent
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.ZIndex = 101
	scrollFrame.Parent = self.CatalogFrame

	-- Add UIListLayout for automatic horizontal scrolling
	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	listLayout.Padding = UDim.new(0, 12)
	listLayout.Parent = scrollFrame

	-- Create module cards
	for i, moduleData in ipairs(MODULE_CATALOG) do
		local card = self:CreateModuleCard(moduleData, i)
		card.Parent = scrollFrame
		self.ModuleButtons[i] = card
	end

	-- Update canvas size after adding all cards
	local contentSize = listLayout.AbsoluteContentSize
	scrollFrame.CanvasSize = UDim2.new(0, contentSize.X + 20, 0, 0)

	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollFrame.CanvasSize = UDim2.new(0, listLayout.AbsoluteContentSize.X + 20, 0, 0)
	end)
end

function BuildingUI:CreateModuleCard(moduleData, index)
	-- Card container (wider and better proportions)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 280, 1, -10)
	card.BackgroundColor3 = Color3.fromRGB(25, 35, 60)
	card.BorderSizePixel = 0
	card.ZIndex = 102

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 10)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(60, 80, 120)
	cardStroke.Thickness = 2
	cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cardStroke.Parent = card

	-- Icon/Category badge
	local iconFrame = Instance.new("Frame")
	iconFrame.Size = UDim2.new(1, 0, 0.28, 0)
	iconFrame.Position = UDim2.new(0, 0, 0, 0)
	iconFrame.BackgroundColor3 = Color3.fromRGB(40, 55, 90)
	iconFrame.BorderSizePixel = 0
	iconFrame.ZIndex = 103
	iconFrame.Parent = card

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 8)
	iconCorner.Parent = iconFrame

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(1, 0, 1, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = moduleData.icon
	iconLabel.TextSize = 40
	iconLabel.ZIndex = 104
	iconLabel.Parent = iconFrame

	-- Module name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.9, 0, 0.16, 0)
	nameLabel.Position = UDim2.new(0.05, 0, 0.31, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = moduleData.name
	nameLabel.TextColor3 = UIHelpers.Colors.Text
	nameLabel.TextSize = 16
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = false
	nameLabel.TextWrapped = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 103
	nameLabel.Parent = card

	-- Category
	local categoryLabel = Instance.new("TextLabel")
	categoryLabel.Size = UDim2.new(0.9, 0, 0.11, 0)
	categoryLabel.Position = UDim2.new(0.05, 0, 0.48, 0)
	categoryLabel.BackgroundTransparency = 1
	categoryLabel.Text = "📂 " .. moduleData.category
	categoryLabel.TextColor3 = UIHelpers.Colors.AccentBright
	categoryLabel.TextSize = 12
	categoryLabel.Font = Enum.Font.Gotham
	categoryLabel.TextXAlignment = Enum.TextXAlignment.Left
	categoryLabel.ZIndex = 103
	categoryLabel.Parent = card

	-- Stats container with better spacing
	local statsFrame = Instance.new("Frame")
	statsFrame.Size = UDim2.new(0.9, 0, 0.2, 0)
	statsFrame.Position = UDim2.new(0.05, 0, 0.62, 0)
	statsFrame.BackgroundTransparency = 1
	statsFrame.ZIndex = 103
	statsFrame.Parent = card

	-- Size stat
	local sizeLabel = Instance.new("TextLabel")
	sizeLabel.Size = UDim2.new(1, 0, 0.45, 0)
	sizeLabel.Position = UDim2.new(0, 0, 0, 0)
	sizeLabel.BackgroundTransparency = 1
	sizeLabel.Text = "📏 Size: " .. moduleData.size
	sizeLabel.TextColor3 = UIHelpers.Colors.TextDim
	sizeLabel.TextSize = 11
	sizeLabel.Font = Enum.Font.Gotham
	sizeLabel.TextXAlignment = Enum.TextXAlignment.Left
	sizeLabel.ZIndex = 103
	sizeLabel.Parent = statsFrame

	-- Power stat
	local powerLabel = Instance.new("TextLabel")
	powerLabel.Size = UDim2.new(1, 0, 0.45, 0)
	powerLabel.Position = UDim2.new(0, 0, 0.55, 0)
	powerLabel.BackgroundTransparency = 1
	local powerText = moduleData.power > 0 and "+" .. moduleData.power .. "W" or moduleData.power .. "W"
	local powerIcon = moduleData.power > 0 and "⚡" or "🔋"
	powerLabel.Text = powerIcon .. " Power: " .. powerText
	powerLabel.TextColor3 = moduleData.power > 0 and Color3.fromRGB(255, 200, 100) or Color3.fromRGB(100, 220, 140)
	powerLabel.TextSize = 11
	powerLabel.Font = Enum.Font.Gotham
	powerLabel.TextXAlignment = Enum.TextXAlignment.Left
	powerLabel.ZIndex = 103
	powerLabel.Parent = statsFrame

	-- Select button (bigger and more prominent)
	local selectButton = Instance.new("TextButton")
	selectButton.Size = UDim2.new(0.9, 0, 0.14, 0)
	selectButton.Position = UDim2.new(0.05, 0, 0.84, 0)
	selectButton.BackgroundColor3 = UIHelpers.Colors.Accent
	selectButton.BorderSizePixel = 0
	selectButton.Text = "SELECT"
	selectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	selectButton.TextSize = 14
	selectButton.Font = Enum.Font.GothamBold
	selectButton.ZIndex = 104
	selectButton.Parent = card

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = selectButton

	-- Hover effects
	selectButton.MouseEnter:Connect(function()
		selectButton.BackgroundColor3 = UIHelpers.Colors.AccentBright
		cardStroke.Color = UIHelpers.Colors.Accent
		cardStroke.Thickness = 3
	end)

	selectButton.MouseLeave:Connect(function()
		if self.SelectedModuleData ~= moduleData then
			selectButton.BackgroundColor3 = UIHelpers.Colors.Accent
			cardStroke.Color = Color3.fromRGB(60, 80, 120)
			cardStroke.Thickness = 2
		end
	end)

	-- Click handler
	selectButton.MouseButton1Click:Connect(function()
		self:SelectModule(moduleData, index)
	end)

	return card
end

function BuildingUI:CreateConfirmCancelUI()
	-- Small UI in bottom right corner (hidden initially)
	self.ConfirmCancelFrame = Instance.new("Frame")
	self.ConfirmCancelFrame.Size = UDim2.new(0, 260, 0, 100)
	self.ConfirmCancelFrame.Position = UDim2.new(1, -280, 1, -120)
	self.ConfirmCancelFrame.BackgroundColor3 = Color3.fromRGB(20, 28, 50)
	self.ConfirmCancelFrame.BorderSizePixel = 0
	self.ConfirmCancelFrame.Visible = false
	self.ConfirmCancelFrame.ZIndex = 200
	self.ConfirmCancelFrame.Parent = self.ScreenGui

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 12)
	frameCorner.Parent = self.ConfirmCancelFrame

	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = UIHelpers.Colors.BorderBright
	frameStroke.Thickness = 3
	frameStroke.Parent = self.ConfirmCancelFrame

	-- Add shadow
	UIHelpers.AddShadow(self.ConfirmCancelFrame)

	-- Header label
	local headerLabel = Instance.new("TextLabel")
	headerLabel.Size = UDim2.new(0.9, 0, 0.18, 0)
	headerLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = "PLACEMENT MODE"
	headerLabel.TextColor3 = UIHelpers.Colors.AccentBright
	headerLabel.TextSize = 11
	headerLabel.Font = Enum.Font.GothamBold
	headerLabel.TextXAlignment = Enum.TextXAlignment.Center
	headerLabel.ZIndex = 201
	headerLabel.Parent = self.ConfirmCancelFrame

	-- Selected module name
	self.PlacementLabel = Instance.new("TextLabel")
	self.PlacementLabel.Size = UDim2.new(0.9, 0, 0.15, 0)
	self.PlacementLabel.Position = UDim2.new(0.05, 0, 0.20, 0)
	self.PlacementLabel.BackgroundTransparency = 1
	self.PlacementLabel.Text = "Placing Module..."
	self.PlacementLabel.TextColor3 = UIHelpers.Colors.Text
	self.PlacementLabel.TextSize = 13
	self.PlacementLabel.Font = Enum.Font.GothamBold
	self.PlacementLabel.TextXAlignment = Enum.TextXAlignment.Center
	self.PlacementLabel.TextWrapped = true
	self.PlacementLabel.ZIndex = 201
	self.PlacementLabel.Parent = self.ConfirmCancelFrame

	-- Instruction label
	self.InstructionLabel = Instance.new("TextLabel")
	self.InstructionLabel.Size = UDim2.new(0.9, 0, 0.18, 0)
	self.InstructionLabel.Position = UDim2.new(0.05, 0, 0.36, 0)
	self.InstructionLabel.BackgroundTransparency = 1
	self.InstructionLabel.Text = "Double-click to place • R to rotate • Right-click to cancel"
	self.InstructionLabel.TextColor3 = UIHelpers.Colors.TextDim
	self.InstructionLabel.TextSize = 9
	self.InstructionLabel.Font = Enum.Font.Gotham
	self.InstructionLabel.TextXAlignment = Enum.TextXAlignment.Center
	self.InstructionLabel.TextWrapped = true
	self.InstructionLabel.ZIndex = 201
	self.InstructionLabel.Parent = self.ConfirmCancelFrame

	-- Button container
	local buttonContainer = Instance.new("Frame")
	buttonContainer.Size = UDim2.new(0.9, 0, 0.38, 0)
	buttonContainer.Position = UDim2.new(0.05, 0, 0.55, 0)
	buttonContainer.BackgroundTransparency = 1
	buttonContainer.ZIndex = 201
	buttonContainer.Parent = self.ConfirmCancelFrame

	-- Confirm button (larger, green)
	local confirmButton = UIHelpers.CreateRoundedButton({
		Size = UDim2.new(0.48, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Text = "✓ PLACE",
		TextSize = 14,
		BackgroundColor = UIHelpers.Colors.Success,
		StrokeColor = Color3.fromRGB(100, 220, 140),
		HoverColor = Color3.fromRGB(100, 220, 140),
		HoverStrokeColor = Color3.fromRGB(120, 240, 160),
		CornerRadius = 8,
		ZIndex = 202,
	})
	confirmButton.Font = Enum.Font.GothamBold
	confirmButton.Parent = buttonContainer

	confirmButton.MouseButton1Click:Connect(function()
		self:ConfirmPlacement()
	end)

	-- Cancel button (red)
	local cancelButton = UIHelpers.CreateRoundedButton({
		Size = UDim2.new(0.48, 0, 1, 0),
		Position = UDim2.new(0.52, 0, 0, 0),
		Text = "✗ CANCEL",
		TextSize = 14,
		BackgroundColor = UIHelpers.Colors.Danger,
		StrokeColor = Color3.fromRGB(255, 120, 120),
		HoverColor = Color3.fromRGB(255, 120, 120),
		HoverStrokeColor = Color3.fromRGB(255, 140, 140),
		CornerRadius = 8,
		ZIndex = 202,
	})
	cancelButton.Font = Enum.Font.GothamBold
	cancelButton.Parent = buttonContainer

	cancelButton.MouseButton1Click:Connect(function()
		self:CancelPlacement()
	end)
end

function BuildingUI:SelectModule(moduleData, index)
	self.SelectedModuleData = moduleData

	print("BuildingUI: Selected module: " .. moduleData.name)

	-- Update all card visuals
	for i, card in ipairs(self.ModuleButtons) do
		local stroke = card:FindFirstChildOfClass("UIStroke")
		local selectBtn = card:FindFirstChild("TextButton")

		if i == index then
			-- Highlight selected
			if stroke then
				stroke.Color = UIHelpers.Colors.Success
				stroke.Thickness = 3
			end
			if selectBtn then
				selectBtn.BackgroundColor3 = UIHelpers.Colors.Success
				selectBtn.Text = "SELECTED"
			end
		else
			-- Reset others
			if stroke then
				stroke.Color = Color3.fromRGB(60, 80, 120)
				stroke.Thickness = 2
			end
			if selectBtn then
				selectBtn.BackgroundColor3 = UIHelpers.Colors.Accent
				selectBtn.Text = "SELECT"
			end
		end
	end

	-- Tell BuildingSystem to start placing this module
	if self.BuildingSystem then
		self.BuildingSystem:SelectModule(moduleData.id, moduleData)
	end

	-- Hide catalog and show confirm/cancel UI
	self:AnimateCatalogDown()
	self:ShowConfirmCancelUI()
end

function BuildingUI:AnimateCatalogDown()
	-- Simple tween to slide catalog down
	self.CatalogFrame:TweenPosition(UDim2.new(0, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
end

function BuildingUI:AnimateCatalogUp()
	-- Slide catalog back up
	self.CatalogFrame:TweenPosition(
		UDim2.new(0, 0, 0.72, 0),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Quad,
		0.3,
		true
	)
end

function BuildingUI:ShowConfirmCancelUI()
	if self.SelectedModuleData then
		self.PlacementLabel.Text = self.SelectedModuleData.name
	end
	self.ConfirmCancelFrame.Visible = true

	-- Slide in from right animation
	self.ConfirmCancelFrame.Position = UDim2.new(1, 20, 1, -120)
	self.ConfirmCancelFrame:TweenPosition(
		UDim2.new(1, -280, 1, -120),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Back,
		0.3,
		true
	)
end

function BuildingUI:HideConfirmCancelUI()
	-- Slide out to right
	self.ConfirmCancelFrame:TweenPosition(
		UDim2.new(1, 20, 1, -120),
		Enum.EasingDirection.In,
		Enum.EasingStyle.Quad,
		0.2,
		true,
		function()
			self.ConfirmCancelFrame.Visible = false
		end
	)
end

function BuildingUI:ConfirmPlacement()
	if not self.SelectedModuleData then
		return
	end

	print("BuildingUI: Confirmed placement of " .. self.SelectedModuleData.name)

	-- Ask BuildingSystem to place the module (works with PlaceModule wrapper)
	if self.BuildingSystem then
		local success = self.BuildingSystem:PlaceModule()
		if not success then
			warn("BuildingUI: Placement failed - invalid position")
			return
		end

		-- Get all placed modules data for saving
		local placedModulesData = self.BuildingSystem:GetPlacedModulesData()

		-- Record all placements in mission data
		for _, moduleData in ipairs(placedModulesData) do
			self:RecordModulePlacement(moduleData)
		end
	end

	-- Hide confirm/cancel UI
	self:HideConfirmCancelUI()

	-- Show catalog again
	self:AnimateCatalogUp()

	-- Clear selection
	self.SelectedModuleData = nil

	-- Reset all card visuals
	for i, card in ipairs(self.ModuleButtons) do
		local stroke = card:FindFirstChildOfClass("UIStroke")
		local selectBtn = card:FindFirstChild("TextButton")

		if stroke then
			stroke.Color = Color3.fromRGB(60, 80, 120)
			stroke.Thickness = 2
		end
		if selectBtn then
			selectBtn.BackgroundColor3 = UIHelpers.Colors.Accent
			selectBtn.Text = "SELECT"
		end
	end
end

function BuildingUI:CancelPlacement()
	print("BuildingUI: Cancelled placement")

	-- Tell BuildingSystem to cancel
	if self.BuildingSystem then
		self.BuildingSystem:CancelPlacement()
	end

	-- Hide confirm/cancel UI
	self:HideConfirmCancelUI()

	-- Show catalog again
	self:AnimateCatalogUp()

	-- Clear selection
	self.SelectedModuleData = nil

	-- Reset all card visuals
	for i, card in ipairs(self.ModuleButtons) do
		local stroke = card:FindFirstChildOfClass("UIStroke")
		local selectBtn = card:FindFirstChild("TextButton")

		if stroke then
			stroke.Color = Color3.fromRGB(60, 80, 120)
			stroke.Thickness = 2
		end
		if selectBtn then
			selectBtn.BackgroundColor3 = UIHelpers.Colors.Accent
			selectBtn.Text = "SELECT"
		end
	end
end

function BuildingUI:RecordModulePlacement(moduleData)
	-- Record module placement in mission data
	self.MissionDataManager:RecordModulePlacement(moduleData)
	print("BuildingUI: Recorded module placement: " .. moduleData.name)
end

function BuildingUI:OnTransitionToPlay()
	-- Update mission state when transitioning to play mode
	self.MissionDataManager:UpdateMissionData({
		CurrentState = "Play",
	})
	print("BuildingUI: Transitioning to play mode, mission state updated")
end

function BuildingUI:Show(gui)
	local attempts = 0
	local maxAttempts = 10

	local function tryShow()
		attempts = attempts + 1
		if LocalPlayer.PlayerGui then
			gui.Parent = LocalPlayer.PlayerGui
			print("BuildingUI: Building interface displayed")
			return true
		elseif attempts < maxAttempts then
			task.wait(0.1)
			return tryShow()
		else
			warn("BuildingUI: Failed to display after " .. maxAttempts .. " attempts")
			return false
		end
	end

	tryShow()
end

function BuildingUI:Hide(gui)
	gui.Parent = nil
	print("BuildingUI: Building interface hidden")
end

function BuildingUI:Destroy()
	if self.ScreenGui then
		self.ScreenGui:Destroy()
		self.ScreenGui = nil
	end
end

return BuildingUI

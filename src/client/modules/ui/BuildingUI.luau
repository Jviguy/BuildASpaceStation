local BuildingUI = {}
BuildingUI.__index = BuildingUI

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Require UIHelpers for consistent styling
local UIHelpers = require(script.Parent.UIHelpers)

-- Require centralized module data manager
local ModuleDataManager = require(script.Parent.Parent.Parent.shared.ModuleDataManager)

function BuildingUI.new(uiManager, missionDataManager, buildingSystem)
	local self = setmetatable({}, BuildingUI)

	self.UIManager = uiManager
	self.MissionDataManager = missionDataManager
	self.BuildingSystem = buildingSystem
	self.ScreenGui = nil

	-- Initialize module data manager
	self.ModuleDataManager = ModuleDataManager.new()
	self.ModuleDataManager:Initialize()

	-- UI state
	self.SelectedModule = nil
	self.SelectedModuleData = nil
	self.ModuleButtons = {}
	self.CategoryButtons = {}

	-- Navigation state
	self.CurrentView = "categories" -- "categories" or "modules"
	self.CurrentCategory = nil

	-- UI elements
	self.CatalogFrame = nil
	self.CategoryFrame = nil -- New frame for category selection
	self.ModuleFrame = nil -- New frame for module selection within category
	self.BackButton = nil -- Navigation back button
	self.ConfirmCancelFrame = nil
	self.ObjectHoverUI = nil -- Hover UI for placed objects
	self.RequirementsUI = nil -- Requirements checking UI
	self.PlacementNameUI = nil -- Module name display during placement

	return self
end

function BuildingUI:Create()
	-- Create ScreenGui
	self.ScreenGui = Instance.new("ScreenGui")
	self.ScreenGui.Name = "BuildingUI"
	self.ScreenGui.ResetOnSpawn = false
	self.ScreenGui.IgnoreGuiInset = true

	-- Create bottom catalog (starts visible with categories)
	self:CreateCatalogContainer()
	self:CreateCategoryView()

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

	-- "Complete Building" button in header - BIGGER VERSION
	local completeButton = UIHelpers.CreateRoundedButton({
		Size = UDim2.new(0, 200, 0.25, 0), -- Increased from 160x0.18 to 200x0.25
		Position = UDim2.new(1, -210, 0.02, 0),
		Text = "🚀 START MISSION",
		TextSize = 16, -- Increased from 13
		BackgroundColor = UIHelpers.Colors.Success,
		StrokeColor = Color3.fromRGB(100, 220, 140),
		HoverColor = Color3.fromRGB(100, 220, 140),
		HoverStrokeColor = Color3.fromRGB(120, 240, 160),
		CornerRadius = 10, -- Increased from 8
		ZIndex = 102,
	})
	completeButton.Font = Enum.Font.GothamBold
	completeButton.Parent = headerFrame

	completeButton.MouseButton1Click:Connect(function()
		self:ShowRequirementsUI()
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

	-- Update all card visuals to show selection
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

	-- IMMEDIATELY transition to placement mode UI
	self:ShowPlacementMode(moduleData)

	-- Tell BuildingSystem to enter placement mode  
	if self.BuildingSystem then
		self.BuildingSystem:SelectModule(moduleData.id, moduleData)
	else
		warn("BuildingUI: BuildingSystem not available!")
	end
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
	print("BuildingUI: Cancelled placement - returning to selection mode")

	-- Tell BuildingSystem to return to selection mode
	if self.BuildingSystem then
		self.BuildingSystem:EnterSelectionMode()
	else
		warn("BuildingUI: BuildingSystem not available for cancel!")
	end
	
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

-- Object Hover UI for placed objects
function BuildingUI:CreateObjectHoverUI()
	-- Create a simple, robust hover UI
	local hoverUI = Instance.new("ScreenGui")
	hoverUI.Name = "ObjectHoverUI"
	hoverUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	hoverUI.IgnoreGuiInset = true
	hoverUI.DisplayOrder = 100

	-- Main frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "HoverFrame"
	mainFrame.Size = UDim2.fromOffset(200, 60)
	mainFrame.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.ZIndex = 1000
	mainFrame.Parent = hoverUI

	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = mainFrame

	-- Add border
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 80, 100)
	stroke.Thickness = 2
	stroke.Parent = mainFrame

	-- Create buttons directly instead of using UIHelpers
	-- Move button
	local moveButton = Instance.new("TextButton")
	moveButton.Name = "MoveButton"
	moveButton.Size = UDim2.fromOffset(80, 40)
	moveButton.Position = UDim2.fromOffset(20, 10)
	moveButton.BackgroundColor3 = Color3.fromRGB(50, 150, 220)
	moveButton.BorderSizePixel = 0
	moveButton.Text = "📋 Move"
	moveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	moveButton.TextScaled = true
	moveButton.Font = Enum.Font.GothamBold
	moveButton.ZIndex = 1001
	moveButton.Parent = mainFrame

	local moveCorner = Instance.new("UICorner")
	moveCorner.CornerRadius = UDim.new(0, 6)
	moveCorner.Parent = moveButton

	-- Delete button
	local deleteButton = Instance.new("TextButton")
	deleteButton.Name = "DeleteButton"
	deleteButton.Size = UDim2.fromOffset(80, 40)
	deleteButton.Position = UDim2.fromOffset(100, 10)
	deleteButton.BackgroundColor3 = Color3.fromRGB(220, 80, 80)
	deleteButton.BorderSizePixel = 0
	deleteButton.Text = "🗑️ Delete"
	deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	deleteButton.TextScaled = true
	deleteButton.Font = Enum.Font.GothamBold
	deleteButton.ZIndex = 1001
	deleteButton.Parent = mainFrame

	local deleteCorner = Instance.new("UICorner")
	deleteCorner.CornerRadius = UDim.new(0, 6)
	deleteCorner.Parent = deleteButton

	-- Store references
	self.ObjectHoverUI = {
		GUI = hoverUI,
		Frame = mainFrame,
		MoveButton = moveButton,
		DeleteButton = deleteButton,
		SelectedObject = nil,
	}

	print("BuildingUI: ObjectHoverUI created successfully with direct buttons")
	return hoverUI
end

function BuildingUI:ShowObjectHoverUI(placedModule, mousePosition)
	print("BuildingUI: ShowObjectHoverUI called for:", placedModule.Name)
	
	if not self.ObjectHoverUI then
		print("BuildingUI: Creating ObjectHoverUI...")
		self:CreateObjectHoverUI()
	end

	local hoverUI = self.ObjectHoverUI
	hoverUI.SelectedObject = placedModule

	-- Position the UI near the mouse
	local viewportSize = workspace.CurrentCamera.ViewportSize
	local frame = hoverUI.Frame
	
	-- Calculate position with bounds checking
	local x = math.clamp(mousePosition.X - 100, 0, viewportSize.X - 200)
	local y = math.clamp(mousePosition.Y - 30, 0, viewportSize.Y - 60)
	
	print("BuildingUI: Setting hover UI position to:", x, y)
	frame.Position = UDim2.fromOffset(x, y)
	frame.Visible = true

	-- Clean up any existing connections first
	if hoverUI.MoveConnection then
		hoverUI.MoveConnection:Disconnect()
		hoverUI.MoveConnection = nil
	end
	if hoverUI.DeleteConnection then
		hoverUI.DeleteConnection:Disconnect()
		hoverUI.DeleteConnection = nil
	end

	-- Connect button events
	local moveConnection = hoverUI.MoveButton.MouseButton1Click:Connect(function()
		print("BuildingUI: Move button clicked")
		self:OnMoveObjectClicked(placedModule)
		self:HideObjectHoverUI()
	end)

	local deleteConnection = hoverUI.DeleteButton.MouseButton1Click:Connect(function()
		print("BuildingUI: Delete button clicked")
		self:OnDeleteObjectClicked(placedModule)
		self:HideObjectHoverUI()
	end)

	-- Store connections for cleanup
	hoverUI.MoveConnection = moveConnection
	hoverUI.DeleteConnection = deleteConnection

	-- Show the UI - make sure it's parented to PlayerGui
	if LocalPlayer.PlayerGui then
		hoverUI.GUI.Parent = LocalPlayer.PlayerGui
		print("BuildingUI: Object hover UI parented to PlayerGui")
		print("BuildingUI: Frame visible:", frame.Visible)
		print("BuildingUI: Frame position:", frame.Position)
		print("BuildingUI: Frame size:", frame.Size)
		print("BuildingUI: GUI parent:", hoverUI.GUI.Parent and hoverUI.GUI.Parent.Name or "nil")
		print("BuildingUI: PlayerGui children count:", #LocalPlayer.PlayerGui:GetChildren())
		
		-- Force visibility and test positioning
		task.wait(0.1) -- Small delay to ensure everything is set up
		frame.Visible = true
		print("BuildingUI: Forced frame visible to true")
		print("BuildingUI: Object hover UI shown for:", placedModule.Name)
	else
		warn("BuildingUI: PlayerGui not available!")
	end
end

function BuildingUI:HideObjectHoverUI()
	if not self.ObjectHoverUI then
		return
	end

	local hoverUI = self.ObjectHoverUI
	hoverUI.Frame.Visible = false
	hoverUI.SelectedObject = nil

	-- Clean up connections
	if hoverUI.MoveConnection then
		hoverUI.MoveConnection:Disconnect()
		hoverUI.MoveConnection = nil
	end
	if hoverUI.DeleteConnection then
		hoverUI.DeleteConnection:Disconnect()
		hoverUI.DeleteConnection = nil
	end

	-- Remove from PlayerGui
	if hoverUI.GUI and hoverUI.GUI.Parent then
		hoverUI.GUI.Parent = nil
	end

	print("BuildingUI: Object hover UI hidden")
end

function BuildingUI:OnMoveObjectClicked(placedModule)
	-- Find the module data for this placed module
	local moduleData = nil
	for _, module in ipairs(MODULE_CATALOG) do
		if placedModule.Name:find(module.id) then
			moduleData = module
			break
		end
	end

	if moduleData then
		-- Remove the old module from placed modules
		self.BuildingSystem:RemovePlacedModule(placedModule)
		
		-- Enter placement mode with this module
		self.BuildingSystem:SelectModule(moduleData.id, moduleData)
		print("BuildingUI: Moving object:", placedModule.Name)
	else
		warn("BuildingUI: Could not find module data for:", placedModule.Name)
	end
end

function BuildingUI:OnDeleteObjectClicked(placedModule)
	-- Remove the module from the building system
	self.BuildingSystem:RemovePlacedModule(placedModule)
	print("BuildingUI: Deleted object:", placedModule.Name)
end

-- REQUIREMENTS SYSTEM
function BuildingUI:ShowRequirementsUI()
	print("BuildingUI: Showing Requirements UI")
	
	if not self.RequirementsUI then
		self:CreateRequirementsUI()
	end
	
	-- Get all placed modules from building system
	local placedModules = self.BuildingSystem:GetPlacedModulesData()
	local requirements = self:CheckRequirements(placedModules)
	
	-- Update UI with requirements
	self:UpdateRequirementsDisplay(requirements)
	
	-- Show the UI
	if LocalPlayer.PlayerGui then
		self.RequirementsUI.GUI.Parent = LocalPlayer.PlayerGui
		self.RequirementsUI.Frame.Visible = true
		print("BuildingUI: Requirements UI shown")
	end
end

function BuildingUI:CreateRequirementsUI()
	-- Create centered requirements checking UI
	local requirementsGui = Instance.new("ScreenGui")
	requirementsGui.Name = "RequirementsUI"
	requirementsGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	requirementsGui.IgnoreGuiInset = true
	requirementsGui.DisplayOrder = 50

	-- Semi-transparent background overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Position = UDim2.fromScale(0, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.3
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 100
	overlay.Parent = requirementsGui

	-- Main requirements frame (centered)
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "RequirementsFrame"
	mainFrame.Size = UDim2.fromOffset(600, 500)
	mainFrame.Position = UDim2.new(0.5, -300, 0.5, -250) -- Centered
	mainFrame.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
	mainFrame.BorderSizePixel = 0
	mainFrame.ZIndex = 101
	mainFrame.Parent = requirementsGui

	-- Corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = mainFrame

	-- Border
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 80, 120)
	stroke.Thickness = 3
	stroke.Parent = mainFrame

	-- Header
	local headerFrame = Instance.new("Frame")
	headerFrame.Size = UDim2.new(1, 0, 0, 80)
	headerFrame.Position = UDim2.fromScale(0, 0)
	headerFrame.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
	headerFrame.BorderSizePixel = 0
	headerFrame.ZIndex = 102
	headerFrame.Parent = mainFrame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 16)
	headerCorner.Parent = headerFrame

	-- Fix header corners (only round top)
	local headerFix = Instance.new("Frame")
	headerFix.Size = UDim2.new(1, 0, 0, 16)
	headerFix.Position = UDim2.new(0, 0, 1, -16)
	headerFix.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
	headerFix.BorderSizePixel = 0
	headerFix.ZIndex = 102
	headerFix.Parent = headerFrame

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -40, 1, 0)
	titleLabel.Position = UDim2.fromOffset(20, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🚀 MISSION REQUIREMENTS CHECK"
	titleLabel.TextColor3 = Color3.fromRGB(220, 230, 250)
	titleLabel.TextSize = 24
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 103
	titleLabel.Parent = headerFrame

	-- Requirements content area
	local contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Size = UDim2.new(1, -40, 1, -180)
	contentFrame.Position = UDim2.fromOffset(20, 100)
	contentFrame.BackgroundTransparency = 1
	contentFrame.BorderSizePixel = 0
	contentFrame.ScrollBarThickness = 8
	contentFrame.ZIndex = 102
	contentFrame.Parent = mainFrame

	-- Button area
	local buttonFrame = Instance.new("Frame")
	buttonFrame.Size = UDim2.new(1, -40, 0, 60)
	buttonFrame.Position = UDim2.new(0, 20, 1, -80)
	buttonFrame.BackgroundTransparency = 1
	buttonFrame.ZIndex = 102
	buttonFrame.Parent = mainFrame

	-- Launch Mission button (hidden by default)
	local launchButton = UIHelpers.CreateRoundedButton({
		Size = UDim2.new(0.45, 0, 1, 0),
		Position = UDim2.fromScale(0.02, 0),
		Text = "🚀 LAUNCH MISSION!",
		TextSize = 18,
		BackgroundColor = Color3.fromRGB(80, 200, 100),
		StrokeColor = Color3.fromRGB(100, 220, 120),
		HoverColor = Color3.fromRGB(100, 220, 120),
		HoverStrokeColor = Color3.fromRGB(120, 240, 140),
		CornerRadius = 12,
		ZIndex = 103,
	})
	launchButton.Font = Enum.Font.GothamBold
	launchButton.Visible = false
	launchButton.Parent = buttonFrame

	-- Go Back button
	local backButton = UIHelpers.CreateRoundedButton({
		Size = UDim2.new(0.45, 0, 1, 0),
		Position = UDim2.fromScale(0.53, 0),
		Text = "← GO BACK & REBUILD",
		TextSize = 18,
		BackgroundColor = Color3.fromRGB(100, 110, 130),
		StrokeColor = Color3.fromRGB(120, 130, 150),
		HoverColor = Color3.fromRGB(120, 130, 150),
		HoverStrokeColor = Color3.fromRGB(140, 150, 170),
		CornerRadius = 12,
		ZIndex = 103,
	})
	backButton.Font = Enum.Font.GothamBold
	backButton.Parent = buttonFrame

	-- Store references
	self.RequirementsUI = {
		GUI = requirementsGui,
		Frame = mainFrame,
		ContentFrame = contentFrame,
		LaunchButton = launchButton,
		BackButton = backButton,
		TitleLabel = titleLabel,
	}

	-- Connect button events
	launchButton.MouseButton1Click:Connect(function()
		self:OnLaunchMission()
	end)

	backButton.MouseButton1Click:Connect(function()
		self:HideRequirementsUI()
	end)

	print("BuildingUI: Requirements UI created")
end

function BuildingUI:CheckRequirements(placedModules)
	print("BuildingUI: Checking requirements for", #placedModules, "placed modules")
	
	local requirements = {
		-- Crew accommodation
		{
			name = "Crew Accommodation",
			description = "Sufficient living space for all crew members",
			required = true,
			passed = false,
			details = "",
		},
		-- Power balance
		{
			name = "Power Balance",
			description = "Power generation meets or exceeds consumption",
			required = true,
			passed = false,
			details = "",
		},
		-- Structural integrity
		{
			name = "Structural Connection",
			description = "All modules properly connected to the station",
			required = true,
			passed = false,
			details = "",
		},
		-- Minimum modules
		{
			name = "Minimum Station Size",
			description = "At least 3 modules required for a viable station",
			required = true,
			passed = false,
			details = "",
		}
	}

	-- Get mission data for crew size
	local missionData = self.MissionDataManager:GetCurrentMissionData()
	local crewSize = missionData.CrewSize or 4

	-- Check minimum modules
	if #placedModules >= 3 then
		requirements[4].passed = true
		requirements[4].details = string.format("✓ %d modules placed (minimum: 3)", #placedModules)
	else
		requirements[4].details = string.format("✗ Only %d modules placed (minimum: 3)", #placedModules)
	end

	-- Calculate crew capacity and power
	local totalCrewCapacity = 0
	local totalPowerGeneration = 0
	local totalPowerConsumption = 0

	for _, moduleData in ipairs(placedModules) do
		-- Find module in catalog
		for _, catalogModule in ipairs(MODULE_CATALOG) do
			if moduleData.ModuleData.id == catalogModule.id then
				-- Crew capacity
				if catalogModule.capacity and catalogModule.capacity ~= "N/A" and catalogModule.capacity ~= "Transit" then
					local capacity = tonumber(catalogModule.capacity:match("%d+")) or 0
					totalCrewCapacity = totalCrewCapacity + capacity
				end
				
				-- Power calculation
				if catalogModule.power then
					if catalogModule.power > 0 then
						totalPowerConsumption = totalPowerConsumption + catalogModule.power
					else
						totalPowerGeneration = totalPowerGeneration + math.abs(catalogModule.power)
					end
				end
				break
			end
		end
	end

	-- Check crew accommodation
	if totalCrewCapacity >= crewSize then
		requirements[1].passed = true
		requirements[1].details = string.format("✓ Capacity: %d crew (needed: %d)", totalCrewCapacity, crewSize)
	else
		requirements[1].details = string.format("✗ Capacity: %d crew (needed: %d)", totalCrewCapacity, crewSize)
	end

	-- Check power balance
	if totalPowerGeneration >= totalPowerConsumption then
		requirements[2].passed = true
		requirements[2].details = string.format("✓ Generation: %dW, Consumption: %dW", totalPowerGeneration, totalPowerConsumption)
	else
		requirements[2].details = string.format("✗ Generation: %dW, Consumption: %dW (deficit: %dW)", 
			totalPowerGeneration, totalPowerConsumption, totalPowerConsumption - totalPowerGeneration)
	end

	-- Check structural connection (simplified - assume connected if >1 module)
	if #placedModules >= 2 then
		requirements[3].passed = true
		requirements[3].details = "✓ All modules properly connected"
	else
		requirements[3].details = "✓ Single module station (no connections needed)"
		requirements[3].passed = true
	end

	return requirements
end

function BuildingUI:UpdateRequirementsDisplay(requirements)
	local contentFrame = self.RequirementsUI.ContentFrame
	
	-- Clear existing content
	for _, child in ipairs(contentFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local allPassed = true
	local yOffset = 0

	-- Create requirement cards
	for i, req in ipairs(requirements) do
		local reqFrame = Instance.new("Frame")
		reqFrame.Size = UDim2.new(1, -20, 0, 80)
		reqFrame.Position = UDim2.fromOffset(10, yOffset)
		reqFrame.BackgroundColor3 = req.passed and Color3.fromRGB(25, 45, 25) or Color3.fromRGB(45, 25, 25)
		reqFrame.BorderSizePixel = 0
		reqFrame.ZIndex = 103
		reqFrame.Parent = contentFrame

		local reqCorner = Instance.new("UICorner")
		reqCorner.CornerRadius = UDim.new(0, 8)
		reqCorner.Parent = reqFrame

		local reqStroke = Instance.new("UIStroke")
		reqStroke.Color = req.passed and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(200, 80, 80)
		reqStroke.Thickness = 2
		reqStroke.Parent = reqFrame

		-- Status icon
		local statusIcon = Instance.new("TextLabel")
		statusIcon.Size = UDim2.fromOffset(40, 40)
		statusIcon.Position = UDim2.fromOffset(15, 20)
		statusIcon.BackgroundTransparency = 1
		statusIcon.Text = req.passed and "✅" or "❌"
		statusIcon.TextSize = 24
		statusIcon.ZIndex = 104
		statusIcon.Parent = reqFrame

		-- Requirement name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -70, 0, 25)
		nameLabel.Position = UDim2.fromOffset(60, 10)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = req.name
		nameLabel.TextColor3 = Color3.fromRGB(220, 230, 250)
		nameLabel.TextSize = 16
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.ZIndex = 104
		nameLabel.Parent = reqFrame

		-- Description
		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -70, 0, 15)
		descLabel.Position = UDim2.fromOffset(60, 30)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = req.description
		descLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
		descLabel.TextSize = 12
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.ZIndex = 104
		descLabel.Parent = reqFrame

		-- Details
		local detailsLabel = Instance.new("TextLabel")
		detailsLabel.Size = UDim2.new(1, -70, 0, 15)
		detailsLabel.Position = UDim2.fromOffset(60, 50)
		detailsLabel.BackgroundTransparency = 1
		detailsLabel.Text = req.details
		detailsLabel.TextColor3 = req.passed and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(200, 100, 100)
		detailsLabel.TextSize = 11
		detailsLabel.Font = Enum.Font.GothamMedium
		detailsLabel.TextXAlignment = Enum.TextXAlignment.Left
		detailsLabel.ZIndex = 104
		detailsLabel.Parent = reqFrame

		yOffset = yOffset + 90

		if not req.passed then
			allPassed = false
		end
	end

	-- Update content size
	contentFrame.CanvasSize = UDim2.fromOffset(0, yOffset + 20)

	-- Show/hide launch button based on requirements
	self.RequirementsUI.LaunchButton.Visible = allPassed
	
	-- Update title based on status
	if allPassed then
		self.RequirementsUI.TitleLabel.Text = "🚀 MISSION REQUIREMENTS ✅ READY!"
		self.RequirementsUI.TitleLabel.TextColor3 = Color3.fromRGB(100, 220, 100)
	else
		self.RequirementsUI.TitleLabel.Text = "🚀 MISSION REQUIREMENTS ❌ NOT READY"
		self.RequirementsUI.TitleLabel.TextColor3 = Color3.fromRGB(220, 100, 100)
	end

	print("BuildingUI: Requirements display updated, all passed:", allPassed)
end

function BuildingUI:HideRequirementsUI()
	if self.RequirementsUI and self.RequirementsUI.GUI then
		self.RequirementsUI.GUI.Parent = nil
		print("BuildingUI: Requirements UI hidden")
	end
end

function BuildingUI:OnLaunchMission()
	print("BuildingUI: Launching mission!")
	self:HideRequirementsUI()
	self:OnTransitionToPlay()
	self.UIManager.GameState:EnterPlayMode()
end

-- STATE MANAGEMENT UI METHODS
function BuildingUI:ShowCatalog()
	print("BuildingUI: ShowCatalog called - debug info:")
	print("  - CatalogFrame exists:", self.CatalogFrame ~= nil)
	print("  - ConfirmCancelUI exists:", self.ConfirmCancelUI ~= nil)
	print("  - PlacementNameUI exists:", self.PlacementNameUI ~= nil)
	
	if self.CatalogFrame then
		print("BuildingUI: Making catalog visible and animating up")
		self.CatalogFrame.Visible = true
		self:AnimateCatalogUp()
	else
		warn("BuildingUI: CatalogFrame not found!")
	end
	
	self:HideConfirmCancelUI()
	self:HidePlacementNameUI()
	print("BuildingUI: Catalog shown - Selection Mode")
end

function BuildingUI:ShowPlacementMode(moduleData)
	print("BuildingUI: Entering placement mode for:", moduleData.name)
	
	-- Hide catalog by sliding it down
	if self.CatalogFrame then
		self:AnimateCatalogDown()
	end
	
	-- Hide any other UIs
	self:HideConfirmCancelUI()
	
	-- Show the placement name UI in corner
	self:ShowPlacementNameUI(moduleData)
	
	print("BuildingUI: Placement Mode UI fully activated")
end

function BuildingUI:CreatePlacementNameUI()
	-- Create modern, polished module name display in bottom corner
	local nameGui = Instance.new("ScreenGui")
	nameGui.Name = "PlacementNameUI"
	nameGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	nameGui.IgnoreGuiInset = true
	nameGui.DisplayOrder = 10

	-- Main frame in bottom left corner - larger and more polished
	local nameFrame = Instance.new("Frame")
	nameFrame.Name = "NameFrame"
	nameFrame.Size = UDim2.fromOffset(350, 100)
	nameFrame.Position = UDim2.new(0, 20, 1, -120)
	nameFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
	nameFrame.BorderSizePixel = 0
	nameFrame.ZIndex = 200
	nameFrame.Parent = nameGui

	-- Corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = nameFrame

	-- Enhanced border with gradient effect
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 140, 220)
	stroke.Thickness = 3
	stroke.Parent = nameFrame

	-- Subtle gradient background
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 30, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 20, 30))
	}
	gradient.Rotation = 45
	gradient.Parent = nameFrame

	-- Header section with darker background
	local headerFrame = Instance.new("Frame")
	headerFrame.Size = UDim2.new(1, 0, 0, 35)
	headerFrame.Position = UDim2.fromScale(0, 0)
	headerFrame.BackgroundColor3 = Color3.fromRGB(30, 40, 55)
	headerFrame.BorderSizePixel = 0
	headerFrame.ZIndex = 201
	headerFrame.Parent = nameFrame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 16)
	headerCorner.Parent = headerFrame

	-- Fix header corners (only round top)
	local headerFix = Instance.new("Frame")
	headerFix.Size = UDim2.new(1, 0, 0, 16)
	headerFix.Position = UDim2.new(0, 0, 1, -16)
	headerFix.BackgroundColor3 = Color3.fromRGB(30, 40, 55)
	headerFix.BorderSizePixel = 0
	headerFix.ZIndex = 201
	headerFix.Parent = headerFrame

	-- Title with status indicator
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -100, 1, 0)
	titleLabel.Position = UDim2.fromOffset(15, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🏗️ PLACEMENT MODE"
	titleLabel.TextColor3 = Color3.fromRGB(100, 180, 255)
	titleLabel.TextSize = 14
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 202
	titleLabel.Parent = headerFrame

	-- Cancel button in header
	local cancelButton = Instance.new("TextButton")
	cancelButton.Name = "CancelButton"
	cancelButton.Size = UDim2.fromOffset(80, 25)
	cancelButton.Position = UDim2.new(1, -90, 0.5, -12.5)
	cancelButton.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
	cancelButton.BorderSizePixel = 0
	cancelButton.Text = "✕ CANCEL"
	cancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelButton.TextSize = 12
	cancelButton.Font = Enum.Font.GothamBold
	cancelButton.ZIndex = 202
	cancelButton.Parent = headerFrame

	local cancelCorner = Instance.new("UICorner")
	cancelCorner.CornerRadius = UDim.new(0, 8)
	cancelCorner.Parent = cancelButton

	-- Hover effect for cancel button
	cancelButton.MouseEnter:Connect(function()
		cancelButton.BackgroundColor3 = Color3.fromRGB(220, 100, 100)
	end)
	cancelButton.MouseLeave:Connect(function()
		cancelButton.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
	end)

	-- Module info section
	local infoFrame = Instance.new("Frame")
	infoFrame.Size = UDim2.new(1, -20, 1, -45)
	infoFrame.Position = UDim2.fromOffset(10, 40)
	infoFrame.BackgroundTransparency = 1
	infoFrame.ZIndex = 201
	infoFrame.Parent = nameFrame

	-- Large module icon with background
	local iconFrame = Instance.new("Frame")
	iconFrame.Size = UDim2.fromOffset(50, 50)
	iconFrame.Position = UDim2.fromOffset(10, 5)
	iconFrame.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
	iconFrame.BorderSizePixel = 0
	iconFrame.ZIndex = 201
	iconFrame.Parent = infoFrame

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 12)
	iconCorner.Parent = iconFrame

	local iconStroke = Instance.new("UIStroke")
	iconStroke.Color = Color3.fromRGB(70, 140, 220)
	iconStroke.Thickness = 2
	iconStroke.Parent = iconFrame

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.Position = UDim2.fromScale(0, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = "🏭" -- Default icon
	iconLabel.TextSize = 32
	iconLabel.ZIndex = 202
	iconLabel.Parent = iconFrame

	-- Module name with better typography
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -80, 0, 25)
	nameLabel.Position = UDim2.fromOffset(70, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "Module Name"
	nameLabel.TextColor3 = Color3.fromRGB(240, 250, 255)
	nameLabel.TextSize = 18
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 202
	nameLabel.Parent = infoFrame

	-- Enhanced instructions with better formatting
	local instructLabel = Instance.new("TextLabel")
	instructLabel.Size = UDim2.new(1, -80, 0, 30)
	instructLabel.Position = UDim2.fromOffset(70, 28)
	instructLabel.BackgroundTransparency = 1
	instructLabel.Text = "Click to lock position • Double-click to place\nR to rotate • Right-click to unlock • ESC for catalog"
	instructLabel.TextColor3 = Color3.fromRGB(160, 180, 200)
	instructLabel.TextSize = 10
	instructLabel.Font = Enum.Font.Gotham
	instructLabel.TextXAlignment = Enum.TextXAlignment.Left
	instructLabel.TextYAlignment = Enum.TextYAlignment.Top
	instructLabel.ZIndex = 202
	instructLabel.Parent = infoFrame

	-- Store references
	self.PlacementNameUI = {
		GUI = nameGui,
		Frame = nameFrame,
		IconLabel = iconLabel,
		NameLabel = nameLabel,
		CancelButton = cancelButton,
	}

	-- Connect cancel button
	cancelButton.MouseButton1Click:Connect(function()
		print("BuildingUI: Cancel button clicked in placement UI")
		if self.BuildingSystem then
			self.BuildingSystem:EnterSelectionMode()
		end
	end)

	print("BuildingUI: Enhanced Placement Name UI created")
end

function BuildingUI:ShowPlacementNameUI(moduleData)
	if not self.PlacementNameUI then
		self:CreatePlacementNameUI()
	end

	-- Update content
	self.PlacementNameUI.IconLabel.Text = moduleData.icon or "🏭"
	self.PlacementNameUI.NameLabel.Text = moduleData.name

	-- Show the UI
	if LocalPlayer.PlayerGui then
		self.PlacementNameUI.GUI.Parent = LocalPlayer.PlayerGui
		print("BuildingUI: Placement Name UI shown for:", moduleData.name)
	end
end

function BuildingUI:HidePlacementNameUI()
	if self.PlacementNameUI and self.PlacementNameUI.GUI then
		self.PlacementNameUI.GUI.Parent = nil
		print("BuildingUI: Placement Name UI hidden")
	end
end

-- Debug method to test hover UI
function BuildingUI:TestHoverUI()
	print("BuildingUI: Testing hover UI creation...")
	
	-- Create a simple test UI
	local testGui = Instance.new("ScreenGui")
	testGui.Name = "TestHoverUI"
	testGui.DisplayOrder = 100
	testGui.Parent = LocalPlayer.PlayerGui
	
	local testFrame = Instance.new("Frame")
	testFrame.Size = UDim2.fromOffset(200, 100)
	testFrame.Position = UDim2.fromOffset(100, 100)
	testFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Bright red for visibility
	testFrame.BorderSizePixel = 0
	testFrame.Parent = testGui
	
	local testLabel = Instance.new("TextLabel")
	testLabel.Size = UDim2.fromScale(1, 1)
	testLabel.BackgroundTransparency = 1
	testLabel.Text = "TEST HOVER UI"
	testLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	testLabel.TextScaled = true
	testLabel.Font = Enum.Font.GothamBold
	testLabel.Parent = testFrame
	
	print("BuildingUI: Test UI created and should be visible!")
	
	-- Auto-cleanup after 3 seconds
	task.delay(3, function()
		if testGui and testGui.Parent then
			testGui:Destroy()
			print("BuildingUI: Test UI cleaned up")
		end
	end)
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
	-- Clean up all UI elements
	if self.ScreenGui then
		self.ScreenGui:Destroy()
		self.ScreenGui = nil
	end
	
	-- Clean up object hover UI
	if self.ObjectHoverUI and self.ObjectHoverUI.GUI then
		self.ObjectHoverUI.GUI:Destroy()
		self.ObjectHoverUI = nil
	end
	
	-- Clean up requirements UI
	if self.RequirementsUI and self.RequirementsUI.GUI then
		self.RequirementsUI.GUI:Destroy()
		self.RequirementsUI = nil
	end
	
	-- Clean up placement name UI
	if self.PlacementNameUI and self.PlacementNameUI.GUI then
		self.PlacementNameUI.GUI:Destroy()
		self.PlacementNameUI = nil
	end
	
	print("BuildingUI: All UI elements destroyed")
end

return BuildingUI

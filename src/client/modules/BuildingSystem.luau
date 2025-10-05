local BuildingSystem = {}
BuildingSystem.__index = BuildingSystem

-- Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

-- Building zone configuration (will be overridden by server-assigned lane)
local BUILDING_ZONE = {
	-- Each player gets a lane assigned by the server
	Size = Vector3.new(200, 200, 200), -- Enlarged: 200x200 studs horizontal, 200 studs vertical
	StartPosition = Vector3.new(0, 30, 0), -- Will be set by server
	GridSize = 4, -- Snap to 4-stud grid
	MaxHeight = 230, -- Maximum build height (StartY + Height)
	MinHeight = 0, -- Minimum build height
	LaneId = -1, -- Assigned by server
}

-- Port snapping configuration
local PORT_SNAP_DISTANCE = 8 -- Maximum distance to snap to a port

-- Visual feedback colors
local COLORS = {
	VALID = Color3.fromRGB(100, 255, 150), -- Bright green
	INVALID = Color3.fromRGB(255, 80, 80), -- Bright red
	SNAPPING = Color3.fromRGB(150, 220, 255), -- Bright cyan/blue
	ZONE_BOUNDARY = Color3.fromRGB(100, 150, 255),
	GRID = Color3.fromRGB(150, 150, 200),
	STARTING_PLATFORM = Color3.fromRGB(80, 200, 120),
}

-- Helper function for sign
local function sign(x)
	if x > 0 then
		return 1
	elseif x < 0 then
		return -1
	else
		return 0
	end
end

function BuildingSystem.new(cameraController, uiManager, toastNotification)
	local self = setmetatable({}, BuildingSystem)

	self.CameraController = cameraController
	self.UIManager = uiManager
	self.ToastNotification = toastNotification

	-- Building state
	self.IsActive = false
	self.SelectedModuleId = nil
	self.SelectedModuleData = nil
	self.PreviewModel = nil
	self.PlacedModules = {} -- Track all placed modules

	-- Building zone visualization
	self.BuildingZone = nil
	self.BuildingZonePart = nil

	-- Lane assignment (from server)
	self.LaneAssigned = false
	self.LaneData = nil

	-- Port snapping
	self.NearestPort = nil
	self.SnapIndicator = nil

	-- Input connections
	self.RenderConnection = nil
	self.RotateConnection = nil

	-- Current rotation (in 90-degree increments)
	self.CurrentRotation = 0

	-- Ghost pulsing effect
	self.GhostPulseTime = 0
	self.PulseSpeed = 2

	-- Collision tracking
	self.IsColliding = false

	-- Placement hints
	self.PlacementHints = {}

	-- Click-to-lock placement state
	self.PlacementLocked = false -- When true, preview stays at locked position
	self.LockedPosition = nil
	self.LockedRotation = 0
	self.ClickConnection = nil

	-- Double-click detection
	self.LastClickTime = 0
	self.DoubleClickThreshold = 0.3 -- 300ms window for double-click

	-- Edit mode state
	self.EditMode = false
	self.SelectedPlacedModule = nil -- The module being edited
	self.EditModeConnection = nil

	-- Snap hint timing (to avoid spam)
	self.LastSnapHintTime = 0

	return self
end

function BuildingSystem:Initialize()
	print("BuildingSystem: Initializing...")

	-- Create snap indicator
	self:CreateSnapIndicator()

	-- Note: Building zone will be created after receiving lane assignment from server
	-- BUT if it doesn't happen within 2 seconds, create a default one for testing

	task.delay(2, function()
		if not self.LaneAssigned then
			warn("BuildingSystem: Lane not assigned after 2 seconds! Creating DEFAULT test lane...")
			-- Create a default test lane (matches server configuration)
			self:SetLaneData(
				0, -- Lane ID 0
				Vector3.new(0, 100, 1024), -- Center position
				Vector3.new(400, 200, 2048), -- Size (WIDER now - 400 studs)
				Vector3.new(0, 100, 50) -- Spawn position
			)
		end
	end)

	print("BuildingSystem: Initialized successfully, waiting for lane assignment...")
end

function BuildingSystem:SetLaneData(laneId, position, size, spawnPosition)
	-- Called when server assigns a lane to this player
	print("========================================")
	print("BuildingSystem: LANE ASSIGNMENT RECEIVED")
	print(string.format("  Lane ID: %d", laneId))
	print(string.format("  Position: X=%.1f, Y=%.1f, Z=%.1f", position.X, position.Y, position.Z))
	print(string.format("  Size: X=%.1f, Y=%.1f, Z=%.1f (WIDTH x HEIGHT x LENGTH)", size.X, size.Y, size.Z))
	if spawnPosition then
		print(string.format("  Spawn: X=%.1f, Y=%.1f, Z=%.1f", spawnPosition.X, spawnPosition.Y, spawnPosition.Z))
	end
	print("========================================")

	self.LaneAssigned = true
	self.LaneData = {
		LaneId = laneId,
		Position = position,
		Size = size,
		SpawnPosition = spawnPosition,
	}

	-- Update BUILDING_ZONE configuration
	BUILDING_ZONE.LaneId = laneId
	BUILDING_ZONE.StartPosition = position
	BUILDING_ZONE.Size = size
	BUILDING_ZONE.MaxHeight = position.Y + size.Y / 2
	BUILDING_ZONE.MinHeight = position.Y - size.Y / 2

	print("BuildingSystem: Calling CreateBuildingZone()...")

	-- Create the building zone visualization
	self:CreateBuildingZone()

	print("BuildingSystem: ✓ Lane assigned and building zone created successfully!")
	print("========================================")
end

function BuildingSystem:CreateBuildingZone()
	-- Create a folder to hold the building zone (client-side only)
	local buildFolder = Instance.new("Folder")
	buildFolder.Name = "BuildingZone_" .. LocalPlayer.Name
	buildFolder.Parent = workspace
	self.BuildingZone = buildFolder

	local lanePosition = BUILDING_ZONE.StartPosition
	local laneSize = BUILDING_ZONE.Size

	print(
		string.format(
			"BuildingSystem: Creating building zone at lane %d, position %s, size %s",
			BUILDING_ZONE.LaneId,
			tostring(lanePosition),
			tostring(laneSize)
		)
	)

	-- Create a massive floor plate for the highway with better aesthetics
	local floorPlate = Instance.new("Part")
	floorPlate.Name = "HighwayFloor"
	floorPlate.Size = Vector3.new(laneSize.X, 1, laneSize.Z) -- Full highway size
	floorPlate.Position = lanePosition - Vector3.new(0, laneSize.Y / 2, 0) -- At the bottom of the lane
	floorPlate.Anchored = true
	floorPlate.CanCollide = false
	floorPlate.Transparency = 0.85 -- More transparent, more subtle
	floorPlate.Color = Color3.fromRGB(30, 60, 100) -- Darker, more subtle
	floorPlate.Material = Enum.Material.SmoothPlastic -- Less glowy
	floorPlate.CastShadow = false
	floorPlate.Parent = buildFolder

	-- Add a subtle glow effect to the floor
	local floorGlow = Instance.new("SurfaceLight")
	floorGlow.Brightness = 0.5
	floorGlow.Range = 30
	floorGlow.Color = Color3.fromRGB(100, 150, 255)
	floorGlow.Face = Enum.NormalId.Top
	floorGlow.Parent = floorPlate

	print(
		string.format(
			"BuildingSystem: Created highway floor at Y=%.1f, size %s",
			floorPlate.Position.Y,
			tostring(floorPlate.Size)
		)
	)

	-- Create the zone boundary visualization (semi-transparent box)
	local zonePart = Instance.new("Part")
	zonePart.Name = "ZoneBoundary"
	zonePart.Size = laneSize
	zonePart.Position = lanePosition
	zonePart.Anchored = true
	zonePart.CanCollide = false
	zonePart.Transparency = 0.95
	zonePart.Color = COLORS.ZONE_BOUNDARY
	zonePart.Material = Enum.Material.ForceField
	zonePart.CastShadow = false
	zonePart.Parent = buildFolder
	self.BuildingZonePart = zonePart

	-- Add animated border effect
	local zoneBorder = Instance.new("SelectionBox")
	zoneBorder.LineThickness = 0.1
	zoneBorder.Color3 = COLORS.ZONE_BOUNDARY
	zoneBorder.Transparency = 0.3
	zoneBorder.Adornee = zonePart
	zoneBorder.Parent = zonePart

	-- Add grid lines for visual reference (positioned at the lane)
	self:CreateGridLines(buildFolder)

	-- Add lane label at the top with better design
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(400, 80)
	billboard.StudsOffset = Vector3.new(0, laneSize.Y / 2 + 20, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = zonePart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = string.format("BUILDING LANE %d", BUILDING_ZONE.LaneId)
	label.TextColor3 = Color3.fromRGB(150, 220, 255)
	label.TextStrokeTransparency = 0.3
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	-- Add corner pillars for better visibility at the START of the lane
	local cornerSize = 6
	local halfSizeLocal = laneSize / 2
	local startZ = lanePosition.Z - halfSizeLocal.Z + 100 -- Near the start

	local corners = {
		Vector3.new(halfSizeLocal.X, -halfSizeLocal.Y, startZ - lanePosition.Z),
		Vector3.new(-halfSizeLocal.X, -halfSizeLocal.Y, startZ - lanePosition.Z),
	}

	for i, cornerOffset in ipairs(corners) do
		local corner = Instance.new("Part")
		corner.Name = "StartPillar" .. i
		corner.Size = Vector3.new(cornerSize, cornerSize * 8, cornerSize)
		corner.Position = lanePosition + cornerOffset + Vector3.new(0, cornerSize * 4, 0)
		corner.Anchored = true
		corner.CanCollide = false
		corner.Transparency = 0.3
		corner.Color = Color3.fromRGB(150, 220, 255)
		corner.Material = Enum.Material.Neon
		corner.CastShadow = false
		corner.Parent = buildFolder
	end

	print("BuildingSystem: Building zone created at " .. tostring(lanePosition))
end

function BuildingSystem:CreateGridLines(parent)
	-- Create grid lines for snapping visualization at the player's assigned lane
	if not self.LaneAssigned then
		warn("BuildingSystem: Cannot create grid lines - lane not assigned yet")
		return
	end

	local gridFolder = Instance.new("Folder")
	gridFolder.Name = "GridLines"
	gridFolder.Parent = parent

	local gridSize = BUILDING_ZONE.GridSize
	local halfSize = BUILDING_ZONE.Size / 2
	local laneCenter = BUILDING_ZONE.StartPosition

	-- Position grid at the FLOOR level (bottom of building zone)
	local gridY = laneCenter.Y - halfSize.Y + 2

	print(
		string.format(
			"BuildingSystem: Creating HIGHWAY grid at lane %d, center %s, floor Y=%.1f",
			BUILDING_ZONE.LaneId,
			tostring(laneCenter),
			gridY
		)
	)
	print(
		string.format(
			"  Lane dimensions: Width=%.1f, Height=%.1f, Length=%.1f",
			BUILDING_ZONE.Size.X,
			BUILDING_ZONE.Size.Y,
			BUILDING_ZONE.Size.Z
		)
	)

	local lineCount = 0
	local majorGridSize = gridSize * 16 -- Every 64 studs for major lines (wider spacing for cleaner look)

	-- Create MAJOR grid lines across width (X direction) - running along Z axis (length of highway)
	-- Clean, subtle lines for better aesthetics
	for x = -halfSize.X, halfSize.X, majorGridSize do
		local line = Instance.new("Part")
		line.Name = "GridLineX_" .. x
		line.Size = Vector3.new(0.8, 0.8, BUILDING_ZONE.Size.Z) -- Thinner, cleaner lines
		line.Position = Vector3.new(laneCenter.X + x, gridY, laneCenter.Z)
		line.Anchored = true
		line.CanCollide = false
		line.Transparency = 0.6 -- More subtle
		line.Color = Color3.fromRGB(100, 180, 255) -- Softer blue
		line.Material = Enum.Material.Neon
		line.CastShadow = false
		line.Parent = gridFolder
		lineCount = lineCount + 1
	end

	-- Create MAJOR grid lines along length (Z direction) - running along X axis (width of highway)
	-- Fewer lines since the highway is very long
	for z = -halfSize.Z, halfSize.Z, majorGridSize * 8 do -- Every 512 studs along length
		local line = Instance.new("Part")
		line.Name = "GridLineZ_" .. z
		line.Size = Vector3.new(BUILDING_ZONE.Size.X, 0.8, 0.8) -- Thinner, cleaner lines
		line.Position = Vector3.new(laneCenter.X, gridY, laneCenter.Z + z)
		line.Anchored = true
		line.CanCollide = false
		line.Transparency = 0.6 -- More subtle
		line.Color = Color3.fromRGB(100, 180, 255) -- Softer blue
		line.Material = Enum.Material.Neon
		line.CastShadow = false
		line.Parent = gridFolder
		lineCount = lineCount + 1
	end

	-- Create VERTICAL grid lines (going upward - Y direction) for 3D cube effect
	-- These create the "walls" of the building zone, going from floor to ceiling
	local verticalHeight = BUILDING_ZONE.Size.Y
	local verticalY = laneCenter.Y -- Center Y of the lane

	-- Vertical lines at major grid intersections (creates 3D grid cube)
	for x = -halfSize.X, halfSize.X, majorGridSize * 2 do -- Every 128 studs on X
		for z = -halfSize.Z, halfSize.Z, majorGridSize * 8 do -- Every 512 studs on Z
			local vLine = Instance.new("Part")
			vLine.Name = string.format("VerticalLine_X%d_Z%d", x, z)
			vLine.Size = Vector3.new(0.8, verticalHeight, 0.8)
			vLine.Position = Vector3.new(laneCenter.X + x, verticalY, laneCenter.Z + z)
			vLine.Anchored = true
			vLine.CanCollide = false
			vLine.Transparency = 0.7 -- Slightly more transparent than horizontal lines
			vLine.Color = Color3.fromRGB(100, 180, 255) -- Same soft blue
			vLine.Material = Enum.Material.Neon
			vLine.CastShadow = false
			vLine.Parent = gridFolder
			lineCount = lineCount + 1
		end
	end

	-- Add EDGE markers on the sides of the highway for better visibility
	local edgeMarkerCount = 8 -- Number of markers along each edge
	local edgeSpacing = BUILDING_ZONE.Size.Z / (edgeMarkerCount - 1)

	for i = 0, edgeMarkerCount - 1 do
		local zPos = laneCenter.Z - halfSize.Z + (i * edgeSpacing)

		-- Left edge markers
		local leftMarker = Instance.new("Part")
		leftMarker.Name = "EdgeMarkerLeft_" .. i
		leftMarker.Size = Vector3.new(4, 4, 4)
		leftMarker.Position = Vector3.new(laneCenter.X - halfSize.X, gridY + 2, zPos)
		leftMarker.Anchored = true
		leftMarker.CanCollide = false
		leftMarker.Transparency = 0.5
		leftMarker.Color = Color3.fromRGB(255, 150, 50) -- Orange
		leftMarker.Material = Enum.Material.Neon
		leftMarker.Shape = Enum.PartType.Cylinder
		leftMarker.Orientation = Vector3.new(0, 0, 90)
		leftMarker.CastShadow = false
		leftMarker.Parent = gridFolder

		-- Right edge markers
		local rightMarker = Instance.new("Part")
		rightMarker.Name = "EdgeMarkerRight_" .. i
		rightMarker.Size = Vector3.new(4, 4, 4)
		rightMarker.Position = Vector3.new(laneCenter.X + halfSize.X, gridY + 2, zPos)
		rightMarker.Anchored = true
		rightMarker.CanCollide = false
		rightMarker.Transparency = 0.5
		rightMarker.Color = Color3.fromRGB(255, 150, 50) -- Orange
		rightMarker.Material = Enum.Material.Neon
		rightMarker.Shape = Enum.PartType.Cylinder
		rightMarker.Orientation = Vector3.new(0, 0, 90)
		rightMarker.CastShadow = false
		rightMarker.Parent = gridFolder
	end

	print(
		string.format(
			"BuildingSystem: ✓ Created %d grid lines + markers for HIGHWAY LANE %d at Y=%.1f",
			lineCount,
			BUILDING_ZONE.LaneId,
			gridY
		)
	)
end

function BuildingSystem:CreateSnapIndicator()
	-- Visual indicator for port snapping
	self.SnapIndicator = Instance.new("Part")
	self.SnapIndicator.Name = "SnapIndicator"
	self.SnapIndicator.Size = Vector3.new(2, 2, 2)
	self.SnapIndicator.Shape = Enum.PartType.Ball
	self.SnapIndicator.Anchored = true
	self.SnapIndicator.CanCollide = false
	self.SnapIndicator.Transparency = 1 -- Start hidden (1 = fully transparent)
	self.SnapIndicator.Color = Color3.fromRGB(100, 255, 100)
	self.SnapIndicator.Material = Enum.Material.Neon
	self.SnapIndicator.Parent = workspace

	-- Add pulsing effect
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(100, 255, 100)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.Enabled = false -- Start disabled
	highlight.Parent = self.SnapIndicator
end

function BuildingSystem:SelectModule(moduleId, moduleData)
	print("BuildingSystem: Module selected: " .. moduleData.name)

	-- Clean up any existing building state
	if self.IsActive then
		self:StopBuilding()
	end

	-- Reset rotation and lock state
	self.CurrentRotation = 0
	self.PlacementLocked = false
	self.LockedPosition = nil
	self.LockedRotation = 0

	self.SelectedModuleId = moduleId
	self.SelectedModuleData = moduleData

	-- Create preview model
	self:CreatePreviewModel(moduleData)

	-- Start building mode
	self:StartBuilding()
end

function BuildingSystem:CreatePreviewModel(moduleData)
	-- Clean up existing preview
	if self.PreviewModel then
		self.PreviewModel:Destroy()
		self.PreviewModel = nil
	end

	-- Create a simple preview model (placeholder)
	-- In production, this would load from ReplicatedStorage
	local model = Instance.new("Model")
	model.Name = "PreviewModel_" .. moduleData.id

	-- Create main body based on size string (e.g., "4x3x2")
	local sizeStr = moduleData.size
	local dimensions = self:ParseSizeString(sizeStr)

	local mainPart = Instance.new("Part")
	mainPart.Name = "MainBody"
	mainPart.Size = dimensions
	mainPart.Anchored = true
	mainPart.CanCollide = false
	mainPart.Transparency = 0.6 -- Fixed: More transparent for better ghost effect
	mainPart.Color = Color3.fromRGB(100, 150, 255)
	mainPart.Material = Enum.Material.ForceField
	mainPart.Parent = model

	-- Add outline with improved colors
	local highlight = Instance.new("Highlight")
	highlight.FillColor = COLORS.SNAPPING -- Bright cyan/blue
	highlight.OutlineColor = Color3.fromRGB(200, 240, 255) -- Bright outline
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0.1 -- More visible outline
	highlight.Parent = mainPart

	-- Add attachment points (ports) based on module type
	self:AddModulePorts(model, mainPart, moduleData)

	-- Set PrimaryPart
	model.PrimaryPart = mainPart
	model.Parent = workspace

	self.PreviewModel = model

	print("BuildingSystem: Preview model created")
end

function BuildingSystem:ParseSizeString(sizeStr)
	-- Parse "4x3x2" into Vector3(4, 3, 2) * 4 (grid size)
	local parts = string.split(sizeStr, "x")
	if #parts == 3 then
		local x = tonumber(parts[1]) or 4
		local y = tonumber(parts[2]) or 3
		local z = tonumber(parts[3]) or 2
		return Vector3.new(x * 4, y * 4, z * 4) -- Multiply by grid size
	end
	return Vector3.new(16, 12, 8) -- Default size
end

function BuildingSystem:AddModulePorts(model, mainPart, moduleData)
	-- Add attachment points (ports) to the module
	-- Ports are where modules can connect to each other

	local size = mainPart.Size
	local portPositions = {}

	-- Determine port locations based on module type
	if moduleData.category == "Connectors" then
		-- Corridors have ports on both ends
		table.insert(portPositions, { pos = Vector3.new(0, 0, size.Z / 2), name = "FrontPort" })
		table.insert(portPositions, { pos = Vector3.new(0, 0, -size.Z / 2), name = "BackPort" })

		if moduleData.id == "junction_cross" then
			-- Cross junction has 4 ports
			table.insert(portPositions, { pos = Vector3.new(size.X / 2, 0, 0), name = "RightPort" })
			table.insert(portPositions, { pos = Vector3.new(-size.X / 2, 0, 0), name = "LeftPort" })
		end
	else
		-- Standard modules have ports on all sides
		table.insert(portPositions, { pos = Vector3.new(0, 0, size.Z / 2), name = "FrontPort" })
		table.insert(portPositions, { pos = Vector3.new(0, 0, -size.Z / 2), name = "BackPort" })
		table.insert(portPositions, { pos = Vector3.new(size.X / 2, 0, 0), name = "RightPort" })
		table.insert(portPositions, { pos = Vector3.new(-size.X / 2, 0, 0), name = "LeftPort" })
	end

	-- Create port attachments
	for _, portData in ipairs(portPositions) do
		local attachment = Instance.new("Attachment")
		attachment.Name = portData.name
		attachment.Position = portData.pos
		attachment.Parent = mainPart

		-- Visual indicator for port
		local portIndicator = Instance.new("Part")
		portIndicator.Name = "Port_" .. portData.name
		portIndicator.Size = Vector3.new(1, 1, 1)
		portIndicator.Shape = Enum.PartType.Cylinder
		portIndicator.Position = mainPart.Position + portData.pos
		portIndicator.Anchored = true
		portIndicator.CanCollide = false
		portIndicator.Transparency = 0.7
		portIndicator.Color = Color3.fromRGB(255, 200, 100)
		portIndicator.Material = Enum.Material.Neon
		portIndicator.Parent = model

		-- Orient cylinder to point outward
		local direction = portData.pos.Unit
		if math.abs(direction.X) > 0.5 then
			portIndicator.Orientation = Vector3.new(0, 0, 90)
		elseif math.abs(direction.Z) > 0.5 then
			portIndicator.Orientation = Vector3.new(90, 0, 0)
		end
	end
end

function BuildingSystem:StartBuilding()
	if self.IsActive then
		return
	end

	-- Check if lane is assigned
	if not self.LaneAssigned then
		warn("BuildingSystem: Cannot start building - lane not assigned yet")
		return
	end

	self.IsActive = true
	self.PlacementLocked = false

	-- Position preview model at lane center
	if self.PreviewModel and self.PreviewModel.PrimaryPart then
		local startPos = BUILDING_ZONE.StartPosition

		if #self.PlacedModules > 0 then
			-- Position next to last module at the same Y level
			local lastModule = self.PlacedModules[#self.PlacedModules]

			if lastModule and lastModule.Position then
				-- Get the size of the last module to calculate offset
				local lastSize = Vector3.new(16, 12, 8)
				if lastModule.Model and lastModule.Model.PrimaryPart then
					lastSize = lastModule.Model.PrimaryPart.Size
				end

				-- Get size of preview module
				local previewSize = self.PreviewModel.PrimaryPart.Size

				-- Position next to last module horizontally, using the same Y position
				local offset = (lastSize.X / 2) + (previewSize.X / 2) + 4
				startPos = Vector3.new(
					lastModule.Position.X + offset,
					lastModule.Position.Y, -- Use the actual Y position from the last module
					lastModule.Position.Z
				)
			end
		end

		self.PreviewModel:SetPrimaryPartCFrame(
			CFrame.new(startPos) * CFrame.Angles(0, math.rad(self.CurrentRotation), 0)
		)
	end

	-- Start render loop for preview positioning
	self.RenderConnection = RunService.RenderStepped:Connect(function()
		self:UpdatePreview()
	end)

	-- Set up keyboard shortcuts
	self.RotateConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		-- R key - Rotate preview
		if input.KeyCode == Enum.KeyCode.R then
			self:RotatePreview()
		end

		-- Ctrl+Z - Undo last placement
		if input.KeyCode == Enum.KeyCode.Z and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			self:UndoLastPlacement()
		end
	end)

	-- Set up mouse click handling
	self.ClickConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		-- Left click: Lock position on first click, place on double-click
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local currentTime = tick()
			local timeSinceLastClick = currentTime - self.LastClickTime

			-- Check for double-click
			if timeSinceLastClick <= self.DoubleClickThreshold and self.PlacementLocked then
				-- DOUBLE-CLICK: Place the module immediately
				print("BuildingSystem: Double-click detected - placing module!")
				self:PlaceModule()
			else
				-- SINGLE-CLICK: Lock the position
				self:LockPlacement()
			end

			self.LastClickTime = currentTime
		end

		-- Right click: Cancel placement and return to catalog
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			print("BuildingSystem: Right-click - canceling placement and returning to catalog")
			self:CancelPlacement()
		end
	end)

	print("BuildingSystem: Building mode started")
end

function BuildingSystem:UpdatePreview()
	if not self.PreviewModel or not self.PreviewModel.PrimaryPart then
		return
	end

	-- Update ghost pulse effect
	self.GhostPulseTime = self.GhostPulseTime + (1 / 60) * self.PulseSpeed
	local pulseAlpha = (math.sin(self.GhostPulseTime) + 1) / 2

	-- If placement is locked, just update visual effects and return
	if self.PlacementLocked and self.LockedPosition then
		self.PreviewModel:SetPrimaryPartCFrame(
			CFrame.new(self.LockedPosition) * CFrame.Angles(0, math.rad(self.CurrentRotation), 0)
		)

		local isColliding = self:CheckCollision()
		if isColliding then
			self:SetPreviewColor(COLORS.INVALID, pulseAlpha)
		else
			self:SetPreviewColor(COLORS.SNAPPING, pulseAlpha)
		end
		return
	end

	-- Determine correct Y level
	local correctY
	if #self.PlacedModules == 0 then
		-- First module: use lane starting Y position (CENTER Y of lane)
		correctY = BUILDING_ZONE.StartPosition.Y
	else
		-- Use Y position of last placed module
		correctY = self.PlacedModules[#self.PlacedModules].Position.Y
	end

	-- Get mouse hit position at the correct Y plane
	local mouse = LocalPlayer:GetMouse()
	local camera = workspace.CurrentCamera
	local mouseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)

	-- Calculate where ray intersects with the Y plane
	local rayOrigin = mouseRay.Origin
	local rayDirection = mouseRay.Direction

	-- Ray equation: P = Origin + t * Direction
	-- We want P.Y = correctY, so: correctY = Origin.Y + t * Direction.Y
	-- Solve for t: t = (correctY - Origin.Y) / Direction.Y

	local t = (correctY - rayOrigin.Y) / rayDirection.Y
	local hitPosition = rayOrigin + (rayDirection * t)
	hitPosition = Vector3.new(hitPosition.X, correctY, hitPosition.Z)

	-- Find all valid snap positions
	local validSnapPositions = self:FindAllValidSnapPositions(correctY)

	-- Debug: Show why snapping might not work
	if #self.PlacedModules > 0 and #validSnapPositions == 0 then
		-- Check if user is trying to make an L-connection
		local nearestModule = self:FindNearestPlacedModule(hitPosition)
		if nearestModule and (hitPosition - nearestModule.Position).Magnitude < 50 then
			-- Only show hint occasionally, not every frame
			if not self.LastSnapHintTime or (tick() - self.LastSnapHintTime) > 3 then
				self.LastSnapHintTime = tick()
				if self.ToastNotification then
					self.ToastNotification:Warning("Use a Junction module for 90° connections")
				end
			end
		end
	end

	if #validSnapPositions > 0 then
		-- SMART SNAP SELECTION: Heavily prioritize T-junctions and line extensions
		-- Completely ignore snaps that would create poor layouts
		local function scoreSnapPosition(snap, mousePos)
			local distance = (snap.position - mousePos).Magnitude

			-- Count nearby modules to identify T-junction opportunities
			local nearbyModules = 0
			local connectingToMiddle = false

			for _, placedModule in ipairs(self.PlacedModules) do
				if placedModule.Position then
					local dist = (placedModule.Position - snap.position).Magnitude
					if dist > 0.1 and dist < 30 then -- Not the same module, but close
						nearbyModules = nearbyModules + 1

						-- Check if we're connecting to the middle of an existing line (T-junction)
						if dist < 20 then
							connectingToMiddle = true
						end
					end
				end
			end

			-- HEAVILY prefer T-junctions (connecting to middle of existing structures)
			-- Give massive bonus for creating T-junctions
			local score = distance
			if connectingToMiddle and nearbyModules >= 2 then
				score = score - 100 -- Huge T-junction bonus
			elseif nearbyModules >= 1 then
				score = score - 40 -- Moderate bonus for extending lines
			end

			return score
		end

		-- Find the best snap position using scoring
		local nearestSnap = validSnapPositions[1]
		local bestScore = scoreSnapPosition(nearestSnap, hitPosition)

		for _, snap in ipairs(validSnapPositions) do
			local score = scoreSnapPosition(snap, hitPosition)
			if score < bestScore then
				bestScore = score
				nearestSnap = snap
			end
		end

		-- Position preview at the snap location
		self.PreviewModel:SetPrimaryPartCFrame(
			CFrame.new(nearestSnap.position) * CFrame.Angles(0, math.rad(self.CurrentRotation), 0)
		)

		-- Show snap indicator
		self.SnapIndicator.Position = nearestSnap.portPosition
		self.SnapIndicator.Transparency = 0.3
		local highlight = self.SnapIndicator:FindFirstChildOfClass("Highlight")
		if highlight then
			highlight.Enabled = true
		end

		-- Check for collisions
		local isColliding = self:CheckCollision()
		if isColliding then
			self:SetPreviewColor(COLORS.INVALID, pulseAlpha)
		else
			self:SetPreviewColor(COLORS.SNAPPING, pulseAlpha)
		end
	else
		-- No valid snaps - use grid snapping for first module only
		self.SnapIndicator.Transparency = 1
		local highlight = self.SnapIndicator:FindFirstChildOfClass("Highlight")
		if highlight then
			highlight.Enabled = false
		end

		if #self.PlacedModules == 0 then
			-- First module can be placed anywhere on grid
			local snappedPosition = self:SnapToGrid(hitPosition)
			self.PreviewModel:SetPrimaryPartCFrame(
				CFrame.new(snappedPosition) * CFrame.Angles(0, math.rad(self.CurrentRotation), 0)
			)
			self:SetPreviewColor(COLORS.VALID, pulseAlpha)
		else
			-- After first module, MUST snap to existing modules
			-- Show preview in red at mouse position to indicate invalid
			local snappedPosition = self:SnapToGrid(hitPosition)
			self.PreviewModel:SetPrimaryPartCFrame(
				CFrame.new(snappedPosition) * CFrame.Angles(0, math.rad(self.CurrentRotation), 0)
			)
			self:SetPreviewColor(COLORS.INVALID, pulseAlpha)
		end
	end
end

function BuildingSystem:FindAllValidSnapPositions(correctY)
	-- Find all valid snap positions where the preview can connect to placed modules
	-- Returns array of {position: Vector3, portPosition: Vector3, targetPort: Attachment, previewPort: Attachment}

	local validSnaps = {}

	if #self.PlacedModules == 0 then
		return validSnaps -- No placed modules yet
	end

	-- Get all ports on the preview module
	local previewPorts = {}
	if self.PreviewModel and self.PreviewModel.PrimaryPart then
		for _, attachment in ipairs(self.PreviewModel.PrimaryPart:GetChildren()) do
			if attachment:IsA("Attachment") and attachment.Name:match("Port") then
				table.insert(previewPorts, attachment)
			end
		end
	end

	-- For each placed module
	for _, placedModule in ipairs(self.PlacedModules) do
		if placedModule.Model and placedModule.Model.PrimaryPart then
			local targetPart = placedModule.Model.PrimaryPart

			-- For each port on the placed module
			for _, targetPort in ipairs(targetPart:GetChildren()) do
				if targetPort:IsA("Attachment") and targetPort.Name:match("Port") then
					-- For each port on the preview module
					for _, previewPort in ipairs(previewPorts) do
						-- Calculate where the preview would need to be to connect these ports
						local snapPosition = self:CalculateSnapPosition(
							targetPort,
							targetPart,
							previewPort,
							placedModule.Model.PrimaryPart.Size,
							correctY
						)

						if snapPosition then
							-- Test if this position would cause a collision
							-- Temporarily position preview at snap location to test
							local oldCFrame = self.PreviewModel.PrimaryPart.CFrame
							self.PreviewModel:SetPrimaryPartCFrame(
								CFrame.new(snapPosition) * CFrame.Angles(0, math.rad(self.CurrentRotation), 0)
							)

							local wouldCollide = self:CheckCollision()

							-- Restore old position
							self.PreviewModel:SetPrimaryPartCFrame(oldCFrame)

							-- Only add if no collision
							if not wouldCollide then
								table.insert(validSnaps, {
									position = snapPosition,
									portPosition = Vector3.new(
										targetPort.WorldPosition.X,
										correctY,
										targetPort.WorldPosition.Z
									),
									targetPort = targetPort,
									previewPort = previewPort,
								})
							end
						end
					end
				end
			end
		end
	end

	return validSnaps
end

function BuildingSystem:CalculateSnapPosition(targetPort, targetPart, previewPort, _targetSize, correctY)
	-- Calculate where to position the preview module so its port connects to target port
	-- Returns nil if connection is invalid (ports facing same direction)

	if not self.PreviewModel or not self.PreviewModel.PrimaryPart then
		return nil
	end

	-- Get port LOCAL positions (relative to part center)
	local targetPortLocal = targetPort.Position
	local previewPortLocal = previewPort.Position

	-- Get port directions in LOCAL space
	local targetPortDirLocal = self:GetPortDirectionFromLocal(targetPortLocal, targetPart)
	local previewPortDirLocal = self:GetPortDirectionFromLocal(previewPortLocal, self.PreviewModel.PrimaryPart)

	-- Apply rotation to preview port direction
	local rotationCFrame = CFrame.Angles(0, math.rad(self.CurrentRotation), 0)
	local previewPortDirRotated = rotationCFrame:VectorToWorldSpace(previewPortDirLocal)

	-- Transform target port direction to world space
	local targetPortDirWorld = targetPart.CFrame:VectorToWorldSpace(targetPortDirLocal)

	-- ULTRA-STRICT PORT VALIDATION: Only allow perfectly straight-through connections
	-- No L-connections, no side-to-end connections, ONLY straight-through or T-junctions

	-- Step 1: Determine which axis each port is PRIMARILY aligned with
	-- A port must be strongly aligned with ONE axis (> 0.9 on that axis)
	local function getPrimaryAxis(dir)
		local absX, absY, absZ = math.abs(dir.X), math.abs(dir.Y), math.abs(dir.Z)

		-- Port must be strongly aligned with one axis (> 0.9 threshold)
		if absX > 0.9 and absX > absY and absX > absZ then
			return "X", dir.X
		elseif absY > 0.9 and absY > absX and absY > absZ then
			return "Y", dir.Y
		elseif absZ > 0.9 and absZ > absX and absZ > absY then
			return "Z", dir.Z
		else
			-- Port not aligned with any primary axis - reject
			return nil, 0
		end
	end

	local targetAxis, targetAxisValue = getPrimaryAxis(targetPortDirWorld)
	local previewAxis, previewAxisValue = getPrimaryAxis(previewPortDirRotated)

	-- Both ports MUST be strongly axis-aligned
	if not targetAxis or not previewAxis then
		return nil
	end

	-- Step 2: SAME AXIS CHECK - Both ports must be on the same axis
	if targetAxis ~= previewAxis then
		-- Different axes = L-connection or perpendicular = INVALID
		-- Example: horizontal end (Z-axis) trying to connect to vertical side (X-axis)
		return nil
	end

	-- Step 3: OPPOSITE DIRECTION CHECK - Ports must face each other
	-- For same-axis connections, the direction values must have opposite signs
	if sign(targetAxisValue) == sign(previewAxisValue) then
		-- Same direction on same axis = both pointing same way = INVALID
		return nil
	end

	-- Step 4: Final dot product check for extra validation
	-- Dot product should be very close to -1.0 (exactly opposite)
	local dotProduct = targetPortDirWorld:Dot(previewPortDirRotated)
	if dotProduct > -0.95 then
		-- Not opposite enough - reject
		return nil
	end

	-- Step 5: CRITICAL - Verify port directions stay aligned after rotation
	-- This prevents rotated modules from incorrectly connecting
	-- We need to apply rotation to the preview port's local position to get its "effective" axis
	local previewPortLocalRotated = rotationCFrame:VectorToWorldSpace(previewPortLocal)

	-- Determine which axis each port is on (using rotated preview position)
	local function getDominantLocalAxis(localPos)
		local absX, absY, absZ = math.abs(localPos.X), math.abs(localPos.Y), math.abs(localPos.Z)
		if absX > absY and absX > absZ then
			return "X"
		elseif absY > absX and absY > absZ then
			return "Y"
		else
			return "Z"
		end
	end

	local targetLocalAxis = getDominantLocalAxis(targetPortLocal)
	local previewLocalAxisRotated = getDominantLocalAxis(previewPortLocalRotated)

	-- CRITICAL CHECK: The effective axes must match for valid connections
	-- This ensures a "front port" only connects to another "front/back port", not a "side port"
	-- Even after rotation is applied
	if targetLocalAxis ~= previewLocalAxisRotated then
		-- Mismatched axes = invalid connection (e.g., horizontal end to vertical side)
		return nil
	end

	-- PERFECT PORT SNAPPING APPROACH: Position modules so they connect seamlessly
	-- Get target port position in world space
	local targetPortWorldPos = targetPort.WorldPosition

	-- NO GAP - ports should be exactly aligned for perfect connections
	-- The module edges should touch perfectly with no overlap
	local connectionGap = 0.0

	-- Calculate where the preview port should be in world space
	-- It should be at the EXACT same position as target port for seamless connection
	local previewPortTargetWorldPos = targetPortWorldPos + (targetPortDirWorld * connectionGap)

	-- Get preview port offset from module center (after applying rotation)
	local previewPortOffsetRotated = rotationCFrame:VectorToWorldSpace(previewPortLocal)

	-- Calculate preview module center position
	-- Preview Center + Preview Port Offset = Preview Port Target Position
	-- Therefore: Preview Center = Preview Port Target Position - Preview Port Offset
	local previewCenter = previewPortTargetWorldPos - previewPortOffsetRotated

	-- Snap to grid for perfect alignment
	local snappedCenter = self:SnapToGrid(previewCenter)

	-- Force correct Y level (keep grid-snapped Y for perfect vertical alignment)
	snappedCenter = Vector3.new(snappedCenter.X, correctY, snappedCenter.Z)

	return snappedCenter
end

function BuildingSystem:GetPortDirectionFromLocal(portLocalPos, part)
	-- Determine port direction from its local position
	local absX = math.abs(portLocalPos.X)
	local absY = math.abs(portLocalPos.Y)
	local absZ = math.abs(portLocalPos.Z)

	local direction
	if absX > absY and absX > absZ then
		direction = Vector3.new(sign(portLocalPos.X), 0, 0)
	elseif absY > absX and absY > absZ then
		direction = Vector3.new(0, sign(portLocalPos.Y), 0)
	else
		direction = Vector3.new(0, 0, sign(portLocalPos.Z))
	end

	-- Transform to world space
	return part.CFrame:VectorToWorldSpace(direction).Unit
end

function BuildingSystem:FindNearestPlacedModule(position)
	-- Find the nearest placed module to a position
	local nearestModule = nil
	local nearestDistance = math.huge

	for _, module in ipairs(self.PlacedModules) do
		if module.Position then
			local distance = (module.Position - position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestModule = module
			end
		end
	end

	return nearestModule
end

function BuildingSystem:FindNearestPort(position)
	-- Find the nearest unoccupied port from placed modules
	local nearestPort = nil
	local nearestDistance = PORT_SNAP_DISTANCE
	local nearestPosition = nil

	for _, placedModule in ipairs(self.PlacedModules) do
		if placedModule.Model and placedModule.Model.PrimaryPart then
			-- Check all attachments (ports) in the module
			for _, attachment in ipairs(placedModule.Model.PrimaryPart:GetChildren()) do
				if attachment:IsA("Attachment") and attachment.Name:match("Port") then
					local portWorldPos = attachment.WorldPosition
					local distance = (portWorldPos - position).Magnitude

					if distance < nearestDistance then
						nearestDistance = distance
						nearestPort = attachment
						nearestPosition = portWorldPos
					end
				end
			end
		end
	end

	return nearestPort, nearestPosition
end

function BuildingSystem:FindClosestPreviewPort(targetPortPosition)
	-- Find which port on the preview module is closest to the target port
	-- This determines which port should connect
	if not self.PreviewModel or not self.PreviewModel.PrimaryPart then
		return nil
	end

	local closestPort = nil
	local closestDistance = math.huge

	for _, attachment in ipairs(self.PreviewModel.PrimaryPart:GetChildren()) do
		if attachment:IsA("Attachment") and attachment.Name:match("Port") then
			-- Get the world position of this port
			local portWorldPos = attachment.WorldPosition
			local distance = (portWorldPos - targetPortPosition).Magnitude

			if distance < closestDistance then
				closestDistance = distance
				closestPort = attachment
			end
		end
	end

	return closestPort
end

function BuildingSystem:GetPortDirection(portAttachment)
	-- Determine which direction a port is facing based on its local position
	-- Ports are positioned on the edges of modules, so we can determine direction
	-- from their relative position to the module center

	if not portAttachment or not portAttachment.Parent then
		return Vector3.new(0, 0, 1) -- Default forward
	end

	local portPos = portAttachment.Position -- Local position relative to PrimaryPart
	local primaryPart = portAttachment.Parent

	-- Determine the dominant axis (which side of the module this port is on)
	local absX = math.abs(portPos.X)
	local absY = math.abs(portPos.Y)
	local absZ = math.abs(portPos.Z)

	local direction
	if absX > absY and absX > absZ then
		-- Port is on X axis (left or right side)
		direction = Vector3.new(sign(portPos.X), 0, 0)
	elseif absY > absX and absY > absZ then
		-- Port is on Y axis (top or bottom)
		direction = Vector3.new(0, sign(portPos.Y), 0)
	else
		-- Port is on Z axis (front or back)
		direction = Vector3.new(0, 0, sign(portPos.Z))
	end

	-- Transform to world space using the part's CFrame
	local worldDirection = primaryPart.CFrame:VectorToWorldSpace(direction)
	return worldDirection.Unit
end

function BuildingSystem:SnapToGrid(position)
	-- Perfect grid snapping - snaps to exact grid positions aligned with lane
	local gridSize = BUILDING_ZONE.GridSize

	-- Get lane position to use as reference point for snapping
	local lanePos = BUILDING_ZONE.StartPosition

	-- Calculate offset from lane position
	local offsetX = position.X - lanePos.X
	local offsetY = position.Y - lanePos.Y
	local offsetZ = position.Z - lanePos.Z

	-- Snap offsets to grid
	local snappedOffsetX = math.floor((offsetX / gridSize) + 0.5) * gridSize
	local snappedOffsetY = math.floor((offsetY / gridSize) + 0.5) * gridSize
	local snappedOffsetZ = math.floor((offsetZ / gridSize) + 0.5) * gridSize

	-- Add back to lane position
	local snappedX = lanePos.X + snappedOffsetX
	local snappedY = lanePos.Y + snappedOffsetY
	local snappedZ = lanePos.Z + snappedOffsetZ

	return Vector3.new(snappedX, snappedY, snappedZ)
end

function BuildingSystem:IsWithinBuildingZone(position)
	-- Check if position is within the building zone boundaries with precise bounds checking
	if not self.LaneAssigned then
		-- If no lane assigned yet, allow any position (fallback)
		return true
	end

	local zonePos = BUILDING_ZONE.StartPosition
	local halfSize = BUILDING_ZONE.Size / 2

	-- Check all three axes with exact boundary validation
	local withinX = position.X >= (zonePos.X - halfSize.X) and position.X <= (zonePos.X + halfSize.X)
	local withinY = position.Y >= BUILDING_ZONE.MinHeight and position.Y <= BUILDING_ZONE.MaxHeight
	local withinZ = position.Z >= (zonePos.Z - halfSize.Z) and position.Z <= (zonePos.Z + halfSize.Z)

	return withinX and withinY and withinZ
end

function BuildingSystem:CheckCollision()
	if not self.PreviewModel or not self.PreviewModel.PrimaryPart then
		return false
	end

	-- Get the main body of preview (ignore port indicators)
	local previewMainBody = self.PreviewModel.PrimaryPart
	if not previewMainBody then
		return false
	end

	local previewPos = previewMainBody.Position
	local previewSize = previewMainBody.Size

	-- IMPROVED COLLISION DETECTION FOR T-JUNCTIONS
	-- We need to distinguish between:
	-- 1. TOUCHING (allowed) - modules are adjacent/connecting
	-- 2. OVERLAPPING (not allowed) - modules are penetrating each other

	-- Tolerance for floating point precision (0.5 studs for grid snapping)
	local TOUCH_TOLERANCE = 1.0 -- Allow modules to be this close without collision

	-- Check for overlap with ALL placed modules using precise AABB collision
	for _, placedModule in ipairs(self.PlacedModules) do
		if placedModule.Model and placedModule.Model.PrimaryPart then
			local placedBody = placedModule.Model.PrimaryPart
			local placedPos = placedBody.Position
			local placedSize = placedBody.Size

			-- Calculate half-extents for both modules
			local previewHalfX = previewSize.X / 2
			local previewHalfY = previewSize.Y / 2
			local previewHalfZ = previewSize.Z / 2

			local placedHalfX = placedSize.X / 2
			local placedHalfY = placedSize.Y / 2
			local placedHalfZ = placedSize.Z / 2

			-- Calculate distance between centers on each axis
			local deltaX = math.abs(previewPos.X - placedPos.X)
			local deltaY = math.abs(previewPos.Y - placedPos.Y)
			local deltaZ = math.abs(previewPos.Z - placedPos.Z)

			-- Calculate the sum of half-extents (distance at which they'd be touching)
			local touchDistanceX = previewHalfX + placedHalfX
			local touchDistanceY = previewHalfY + placedHalfY
			local touchDistanceZ = previewHalfZ + placedHalfZ

			-- Calculate penetration depth on each axis
			-- Negative = separated, 0 = touching, Positive = overlapping
			local penetrationX = touchDistanceX - deltaX
			local penetrationY = touchDistanceY - deltaY
			local penetrationZ = touchDistanceZ - deltaZ

			-- For a TRUE collision, modules must overlap on ALL three axes
			-- AND the overlap must be SIGNIFICANT (not just touching)
			local isOverlappingX = penetrationX > TOUCH_TOLERANCE
			local isOverlappingY = penetrationY > TOUCH_TOLERANCE
			local isOverlappingZ = penetrationZ > TOUCH_TOLERANCE

			if isOverlappingX and isOverlappingY and isOverlappingZ then
				-- TRUE OVERLAP - modules are penetrating each other significantly
				return true
			end
		end
	end

	return false -- No collision (touching is allowed)
end

function BuildingSystem:SetPreviewColor(color, pulseAlpha)
	if not self.PreviewModel then
		return
	end

	pulseAlpha = pulseAlpha or 0.5

	for _, part in ipairs(self.PreviewModel:GetDescendants()) do
		if part:IsA("Highlight") then
			part.FillColor = color
			part.OutlineColor = color
			-- Subtle pulse on transparency
			part.FillTransparency = 0.35 + (pulseAlpha * 0.15) -- Range: 0.35 to 0.50
			part.OutlineTransparency = 0.15 + (pulseAlpha * 0.1) -- Range: 0.15 to 0.25
		elseif part:IsA("BasePart") and not part.Name:find("Port_") then
			-- Subtle pulse on main part transparency
			part.Transparency = 0.55 + (pulseAlpha * 0.15) -- Range: 0.55 to 0.70
		end
	end
end

function BuildingSystem:LockPlacement()
	if not self.PreviewModel or not self.PreviewModel.PrimaryPart then
		return
	end

	-- Toggle lock state
	if self.PlacementLocked then
		-- Already locked, do nothing (use double-click to place or right-click to unlock)
		print("BuildingSystem: Position already locked - double-click to place or right-click to unlock")
		return
	end

	-- Lock the current position
	self.PlacementLocked = true
	self.LockedPosition = self.PreviewModel.PrimaryPart.Position
	self.LockedRotation = self.CurrentRotation

	print("BuildingSystem: Position locked! Rotate with R, double-click to place, right-click to unlock.")
end

function BuildingSystem:UnlockPlacement()
	-- Unlock the placement without canceling the preview entirely
	if not self.PlacementLocked then
		return
	end

	self.PlacementLocked = false
	self.LockedPosition = nil
	self.LockedRotation = 0
	self.LastClickTime = 0 -- Reset double-click timer

	print("BuildingSystem: Placement unlocked - preview follows mouse again")
end

function BuildingSystem:PlaceModule()
	-- Wrapper function for placing module (called by double-click or Place button)
	local success = self:ConfirmPlacement()

	if success then
		-- Reset lock state after successful placement
		self.PlacementLocked = false
		self.LockedPosition = nil
		self.LastClickTime = 0

		-- Keep building mode active so user can place another module
		-- The preview will be recreated by the UI if user selects same module
		print("BuildingSystem: Module placed! Select another module or adjust position.")
	end

	return success
end

function BuildingSystem:RotatePreview()
	-- Rotate preview by 90 degrees
	self.CurrentRotation = (self.CurrentRotation + 90) % 360

	-- If locked, update the rotation immediately
	if self.PlacementLocked and self.LockedPosition and self.PreviewModel then
		self.PreviewModel:SetPrimaryPartCFrame(
			CFrame.new(self.LockedPosition) * CFrame.Angles(0, math.rad(self.CurrentRotation), 0)
		)
	end

	print("BuildingSystem: Rotated to " .. self.CurrentRotation .. " degrees")
end

function BuildingSystem:ConfirmPlacement()
	if not self.PreviewModel or not self.PreviewModel.PrimaryPart then
		warn("BuildingSystem: No preview model to place")
		if self.ToastNotification then
			self.ToastNotification:Error("No module selected for placement")
		end
		return false
	end

	-- Check if placement is valid
	local position = self.PreviewModel.PrimaryPart.Position
	if not self:IsWithinBuildingZone(position) then
		warn("BuildingSystem: Placement outside building zone")
		if self.ToastNotification then
			self.ToastNotification:Error("Cannot place module outside building zone")
		end
		return false
	end

	-- Check for collisions
	if self:CheckCollision() then
		warn("BuildingSystem: Cannot place - module is colliding with existing modules")
		if self.ToastNotification then
			self.ToastNotification:Error("Module collides with existing modules")
		end
		return false
	end

	-- Convert preview to permanent module
	local placedModel = self.PreviewModel:Clone()
	placedModel.Name = self.SelectedModuleData.name .. "_" .. (#self.PlacedModules + 1)

	-- Make it solid and colorful
	for _, part in ipairs(placedModel:GetDescendants()) do
		if part:IsA("BasePart") and not part.Name:find("Port_") then
			part.Transparency = 0
			part.CanCollide = true
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.fromRGB(200, 220, 255) -- Nice light blue
		end
		if part:IsA("Highlight") then
			part.FillTransparency = 0.8
			part.OutlineTransparency = 0.5
			part.FillColor = Color3.fromRGB(150, 200, 255)
		end
		if part.Name:find("Port_") then
			-- Keep port indicators visible but dimmer
			part.Transparency = 0.85
		end
	end

	placedModel.Parent = self.BuildingZone

	-- Record placement
	table.insert(self.PlacedModules, {
		Model = placedModel,
		ModuleData = self.SelectedModuleData,
		Position = position,
		Rotation = self.CurrentRotation,
	})

	print("BuildingSystem: Module placed successfully! Total modules: " .. #self.PlacedModules)

	-- Show success toast
	if self.ToastNotification then
		self.ToastNotification:Success(string.format("%s placed successfully!", self.SelectedModuleData.name))
	end

	return true
end

function BuildingSystem:CancelPlacement()
	-- Clean up preview
	if self.PreviewModel then
		self.PreviewModel:Destroy()
		self.PreviewModel = nil
	end

	-- Reset lock state
	self.PlacementLocked = false
	self.LockedPosition = nil
	self.LockedRotation = 0

	-- Stop building mode
	self:StopBuilding()

	print("BuildingSystem: Placement cancelled")
end

function BuildingSystem:UndoLastPlacement()
	-- Remove the last placed module (Ctrl+Z)
	if #self.PlacedModules == 0 then
		if self.ToastNotification then
			self.ToastNotification:Warning("No modules to undo")
		end
		return
	end

	-- Get and remove last module
	local lastModule = table.remove(self.PlacedModules)

	if lastModule.Model then
		lastModule.Model:Destroy()
	end

	print(string.format("BuildingSystem: Undid placement of %s", lastModule.ModuleData.name))

	if self.ToastNotification then
		self.ToastNotification:Info(string.format("Removed %s", lastModule.ModuleData.name))
	end
end

function BuildingSystem:SelectPlacedModule(moduleData)
	-- Enter edit mode for a placed module
	self.EditMode = true
	self.SelectedPlacedModule = moduleData

	-- Highlight the selected module
	if moduleData.Model and moduleData.Model.PrimaryPart then
		-- Add highlight
		local highlight = Instance.new("Highlight")
		highlight.Name = "EditHighlight"
		highlight.FillColor = Color3.fromRGB(100, 200, 255)
		highlight.OutlineColor = Color3.fromRGB(150, 220, 255)
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0
		highlight.Parent = moduleData.Model
	end

	print(string.format("BuildingSystem: Selected module %s for editing", moduleData.ModuleData.name))
end

function BuildingSystem:DeleteSelectedModule()
	-- Delete the currently selected module
	if not self.SelectedPlacedModule then
		return
	end

	-- Find and remove from placed modules
	for i, module in ipairs(self.PlacedModules) do
		if module == self.SelectedPlacedModule then
			-- Destroy the model
			if module.Model then
				module.Model:Destroy()
			end

			-- Remove from array
			table.remove(self.PlacedModules, i)

			print(string.format("BuildingSystem: Deleted module %s", module.ModuleData.name))

			if self.ToastNotification then
				self.ToastNotification:Success(string.format("Deleted %s", module.ModuleData.name))
			end

			break
		end
	end

	-- Exit edit mode
	self:ExitEditMode()
end

function BuildingSystem:ExitEditMode()
	-- Exit edit mode and deselect module
	if self.SelectedPlacedModule and self.SelectedPlacedModule.Model then
		-- Remove highlight
		local highlight = self.SelectedPlacedModule.Model:FindFirstChild("EditHighlight")
		if highlight then
			highlight:Destroy()
		end
	end

	self.EditMode = false
	self.SelectedPlacedModule = nil

	print("BuildingSystem: Exited edit mode")
end

function BuildingSystem:StopBuilding()
	if not self.IsActive then
		return
	end

	self.IsActive = false

	-- Disconnect connections
	if self.RenderConnection then
		self.RenderConnection:Disconnect()
		self.RenderConnection = nil
	end

	if self.RotateConnection then
		self.RotateConnection:Disconnect()
		self.RotateConnection = nil
	end

	if self.ClickConnection then
		self.ClickConnection:Disconnect()
		self.ClickConnection = nil
	end

	-- Hide snap indicator
	if self.SnapIndicator then
		self.SnapIndicator.Transparency = 1
		local highlight = self.SnapIndicator:FindFirstChildOfClass("Highlight")
		if highlight then
			highlight.Enabled = false
		end
	end

	-- Reset selection and lock state
	self.SelectedModuleId = nil
	self.SelectedModuleData = nil
	self.NearestPort = nil
	self.CurrentRotation = 0
	self.PlacementLocked = false
	self.LockedPosition = nil
	self.LockedRotation = 0

	print("BuildingSystem: Building mode stopped")
end

function BuildingSystem:GetPlacedModulesData()
	-- Return data for saving
	local data = {}
	for _, moduleInfo in ipairs(self.PlacedModules) do
		table.insert(data, {
			id = moduleInfo.ModuleData.id,
			name = moduleInfo.ModuleData.name,
			position = { moduleInfo.Position.X, moduleInfo.Position.Y, moduleInfo.Position.Z },
			rotation = moduleInfo.Rotation,
		})
	end
	return data
end

function BuildingSystem:Cleanup()
	self:StopBuilding()

	if self.PreviewModel then
		self.PreviewModel:Destroy()
	end

	if self.BuildingZone then
		self.BuildingZone:Destroy()
	end

	if self.SnapIndicator then
		self.SnapIndicator:Destroy()
	end

	print("BuildingSystem: Cleaned up")
end

return BuildingSystem

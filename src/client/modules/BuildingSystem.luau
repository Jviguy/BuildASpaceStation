local BuildingSystem = {}
BuildingSystem.__index = BuildingSystem

-- Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

-- Building zone configuration
local BUILDING_ZONE = {
    -- Each player gets a lane (like a conveyor belt moving forward)
    Size = Vector3.new(100, 150, 100), -- 100x100 studs horizontal, 150 studs vertical
    StartPosition = Vector3.new(0, 30, 0), -- Center of the zone, elevated
    GridSize = 4, -- Snap to 4-stud grid
    MaxHeight = 150, -- Maximum build height
    MinHeight = 0 -- Can't build below starting platform
}

-- Starting platform configuration
local STARTING_PLATFORM = {
    Size = Vector3.new(16, 1, 16),
    Position = Vector3.new(0, 30, 0) -- Same as zone start
}

-- Port snapping configuration
local PORT_SNAP_DISTANCE = 8 -- Maximum distance to snap to a port

-- Visual feedback colors
local COLORS = {
    VALID = Color3.fromRGB(100, 255, 100),
    INVALID = Color3.fromRGB(255, 100, 100),
    SNAPPING = Color3.fromRGB(100, 200, 255),
    ZONE_BOUNDARY = Color3.fromRGB(100, 150, 255),
    GRID = Color3.fromRGB(150, 150, 200),
    STARTING_PLATFORM = Color3.fromRGB(80, 200, 120)
}

function BuildingSystem.new(cameraController, uiManager)
    local self = setmetatable({}, BuildingSystem)
    
    self.CameraController = cameraController
    self.UIManager = uiManager
    
    -- Building state
    self.IsActive = false
    self.SelectedModuleId = nil
    self.SelectedModuleData = nil
    self.PreviewModel = nil
    self.PlacedModules = {} -- Track all placed modules
    
    -- Building zone visualization
    self.BuildingZone = nil
    self.BuildingZonePart = nil
    
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
    
    return self
end

function BuildingSystem:Initialize()
    print("BuildingSystem: Initializing...")
    
    -- Create building zone
    self:CreateBuildingZone()
    
    -- Create snap indicator
    self:CreateSnapIndicator()
    
    print("BuildingSystem: Initialized successfully")
end

function BuildingSystem:CreateBuildingZone()
    -- Create a folder to hold the building zone
    local buildFolder = Instance.new("Folder")
    buildFolder.Name = "BuildingZone_" .. LocalPlayer.Name
    buildFolder.Parent = workspace
    self.BuildingZone = buildFolder
    
    -- Create the zone boundary visualization (semi-transparent box)
    local zonePart = Instance.new("Part")
    zonePart.Name = "ZoneBoundary"
    zonePart.Size = BUILDING_ZONE.Size
    zonePart.Position = BUILDING_ZONE.StartPosition
    zonePart.Anchored = true
    zonePart.CanCollide = false
    zonePart.Transparency = 0.95
    zonePart.Color = COLORS.ZONE_BOUNDARY
    zonePart.Material = Enum.Material.ForceField
    zonePart.Parent = buildFolder
    self.BuildingZonePart = zonePart
    
    -- Add animated border effect
    local zoneBorder = Instance.new("SelectionBox")
    zoneBorder.LineThickness = 0.1
    zoneBorder.Color3 = COLORS.ZONE_BOUNDARY
    zoneBorder.Transparency = 0.3
    zoneBorder.Adornee = zonePart
    zoneBorder.Parent = zonePart
    
    -- Add grid lines for visual reference
    self:CreateGridLines(buildFolder)
    
    -- Create starting platform (first module goes here)
    local startPlatform = Instance.new("Part")
    startPlatform.Name = "StartingPlatform"
    startPlatform.Size = STARTING_PLATFORM.Size
    startPlatform.Position = STARTING_PLATFORM.Position
    startPlatform.Anchored = true
    startPlatform.CanCollide = true
    startPlatform.Transparency = 0.3
    startPlatform.Color = COLORS.STARTING_PLATFORM
    startPlatform.Material = Enum.Material.Neon
    startPlatform.Parent = buildFolder
    
    -- Add corner indicators to platform
    local halfSize = STARTING_PLATFORM.Size.X / 2 - 0.5
    for x = -1, 1, 2 do
        for z = -1, 1, 2 do
            local corner = Instance.new("Part")
            corner.Name = "PlatformCorner"
            corner.Size = Vector3.new(1.5, 3, 1.5)
            corner.Position = startPlatform.Position + Vector3.new(x * halfSize, 1.5, z * halfSize)
            corner.Anchored = true
            corner.CanCollide = false
            corner.Transparency = 0.4
            corner.Color = COLORS.STARTING_PLATFORM
            corner.Material = Enum.Material.Neon
            corner.Parent = buildFolder
        end
    end
    
    -- Add highlight to platform
    local highlight = Instance.new("Highlight")
    highlight.FillColor = COLORS.STARTING_PLATFORM
    highlight.OutlineColor = Color3.fromRGB(100, 255, 150)
    highlight.FillTransparency = 0.7
    highlight.OutlineTransparency = 0.2
    highlight.Parent = startPlatform
    
    -- Add instructions label above platform
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 8, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = startPlatform
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "⬇️ PLACE FIRST MODULE HERE ⬇️"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.5
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = billboard
    
    print("BuildingSystem: Building zone created at " .. tostring(BUILDING_ZONE.StartPosition))
end

function BuildingSystem:CreateGridLines(parent)
    -- Create grid lines for snapping visualization
    local gridFolder = Instance.new("Folder")
    gridFolder.Name = "GridLines"
    gridFolder.Parent = parent
    
    local gridSize = BUILDING_ZONE.GridSize
    local halfSize = BUILDING_ZONE.Size / 2
    
    -- Create vertical grid lines (X direction)
    for x = -halfSize.X, halfSize.X, gridSize do
        local line = Instance.new("Part")
        line.Name = "GridLineX"
        line.Size = Vector3.new(0.1, 0.1, BUILDING_ZONE.Size.Z)
        line.Position = BUILDING_ZONE.StartPosition + Vector3.new(x, 0, 0)
        line.Anchored = true
        line.CanCollide = false
        line.Transparency = 0.95
        line.Color = Color3.fromRGB(150, 150, 200)
        line.Material = Enum.Material.Neon
        line.Parent = gridFolder
    end
    
    -- Create horizontal grid lines (Z direction)
    for z = -halfSize.Z, halfSize.Z, gridSize do
        local line = Instance.new("Part")
        line.Name = "GridLineZ"
        line.Size = Vector3.new(BUILDING_ZONE.Size.X, 0.1, 0.1)
        line.Position = BUILDING_ZONE.StartPosition + Vector3.new(0, 0, z)
        line.Anchored = true
        line.CanCollide = false
        line.Transparency = 0.95
        line.Color = Color3.fromRGB(150, 150, 200)
        line.Material = Enum.Material.Neon
        line.Parent = gridFolder
    end
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
    mainPart.Transparency = 0.6  -- Fixed: More transparent for better ghost effect
    mainPart.Color = Color3.fromRGB(100, 150, 255)
    mainPart.Material = Enum.Material.ForceField
    mainPart.Parent = model
    
    -- Add outline
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(100, 150, 255)
    highlight.OutlineColor = Color3.fromRGB(150, 200, 255)
    highlight.FillTransparency = 0.4  -- Fixed: Consistent with part transparency
    highlight.OutlineTransparency = 0.2
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
        table.insert(portPositions, {pos = Vector3.new(0, 0, size.Z/2), name = "FrontPort"})
        table.insert(portPositions, {pos = Vector3.new(0, 0, -size.Z/2), name = "BackPort"})
        
        if moduleData.id == "junction_cross" then
            -- Cross junction has 4 ports
            table.insert(portPositions, {pos = Vector3.new(size.X/2, 0, 0), name = "RightPort"})
            table.insert(portPositions, {pos = Vector3.new(-size.X/2, 0, 0), name = "LeftPort"})
        end
    else
        -- Standard modules have ports on all sides
        table.insert(portPositions, {pos = Vector3.new(0, 0, size.Z/2), name = "FrontPort"})
        table.insert(portPositions, {pos = Vector3.new(0, 0, -size.Z/2), name = "BackPort"})
        table.insert(portPositions, {pos = Vector3.new(size.X/2, 0, 0), name = "RightPort"})
        table.insert(portPositions, {pos = Vector3.new(-size.X/2, 0, 0), name = "LeftPort"})
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
    if self.IsActive then return end
    
    self.IsActive = true
    self.PlacementLocked = false
    
    -- Position preview model appropriately
    if self.PreviewModel and self.PreviewModel.PrimaryPart then
        if #self.PlacedModules == 0 then
            -- First module: lock it to starting platform
            self.LockedPosition = STARTING_PLATFORM.Position + Vector3.new(0, 8, 0)
            self.PlacementLocked = true
            
            self.PreviewModel:SetPrimaryPartCFrame(
                CFrame.new(self.LockedPosition) * CFrame.Angles(0, math.rad(self.CurrentRotation), 0)
            )
        else
            -- Subsequent modules: position next to last module at the same Y level
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
                local startPos = Vector3.new(
                    lastModule.Position.X + offset,
                    lastModule.Position.Y,  -- Use the actual Y position from the last module
                    lastModule.Position.Z
                )
                
                self.PreviewModel:SetPrimaryPartCFrame(
                    CFrame.new(startPos) * CFrame.Angles(0, math.rad(self.CurrentRotation), 0)
                )
            else
                -- Fallback: use platform height + offset
                local fallbackY = STARTING_PLATFORM.Position.Y + 8
                local startPos = Vector3.new(
                    BUILDING_ZONE.StartPosition.X + 20,
                    fallbackY,
                    BUILDING_ZONE.StartPosition.Z
                )
                self.PreviewModel:SetPrimaryPartCFrame(
                    CFrame.new(startPos) * CFrame.Angles(0, math.rad(self.CurrentRotation), 0)
                )
            end
        end
    end
    
    -- Start render loop for preview positioning
    self.RenderConnection = RunService.RenderStepped:Connect(function()
        self:UpdatePreview()
    end)
    
    -- Set up rotation input (R key)
    self.RotateConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.R then
            self:RotatePreview()
        end
    end)
    
    -- Set up mouse click to lock position
    self.ClickConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self:LockPlacement()
        end
    end)
    
    print("BuildingSystem: Building mode started")
end

function BuildingSystem:UpdatePreview()
    if not self.PreviewModel or not self.PreviewModel.PrimaryPart then return end
    
    -- Update ghost pulse effect
    self.GhostPulseTime = self.GhostPulseTime + (1/60) * self.PulseSpeed
    local pulseAlpha = (math.sin(self.GhostPulseTime) + 1) / 2 -- Oscillates between 0 and 1
    
    -- If placement is locked, just update visual effects and return
    if self.PlacementLocked and self.LockedPosition then
        self.PreviewModel:SetPrimaryPartCFrame(
            CFrame.new(self.LockedPosition) * CFrame.Angles(0, math.rad(self.CurrentRotation), 0)
        )
        
        -- Check for collisions even when locked
        local isColliding = self:CheckCollision()
        if isColliding then
            self:SetPreviewColor(COLORS.INVALID, pulseAlpha)
        else
            -- Use cyan to show it's locked and ready
            self:SetPreviewColor(COLORS.SNAPPING, pulseAlpha)
        end
        return
    end
    
    -- Get mouse position in 3D space
    local mouse = LocalPlayer:GetMouse()
    local mouseRay = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
    
    -- Raycast to find placement position
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {self.PreviewModel, LocalPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local rayResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, raycastParams)
    
    if rayResult then
        local hitPosition = rayResult.Position
        
        -- Check for nearby ports to snap to
        local nearestPort, portPosition = self:FindNearestPort(hitPosition)
        
        if nearestPort then
            -- Snap to port
            self.NearestPort = nearestPort
            self.SnapIndicator.Position = portPosition
            self.SnapIndicator.Transparency = 0.3 -- Show indicator
            
            -- Enable highlight
            local highlight = self.SnapIndicator:FindFirstChildOfClass("Highlight")
            if highlight then
                highlight.Enabled = true
            end
            
            -- Position preview at port
            self.PreviewModel:SetPrimaryPartCFrame(
                CFrame.new(portPosition) * CFrame.Angles(0, math.rad(self.CurrentRotation), 0)
            )
            
            -- Check for collisions
            local isColliding = self:CheckCollision()
            
            -- Make preview cyan when snapping, red if colliding
            if isColliding then
                self:SetPreviewColor(COLORS.INVALID, pulseAlpha)
            else
                self:SetPreviewColor(COLORS.SNAPPING, pulseAlpha)
            end
        else
            -- Grid snapping (for first module or free placement)
            self.SnapIndicator.Transparency = 1 -- Hide indicator
            
            -- Disable highlight
            local highlight = self.SnapIndicator:FindFirstChildOfClass("Highlight")
            if highlight then
                highlight.Enabled = false
            end
            
            self.NearestPort = nil
            
            local snappedPosition = self:SnapToGrid(hitPosition)
            
            -- Check if position is within building zone
            if self:IsWithinBuildingZone(snappedPosition) then
                self.PreviewModel:SetPrimaryPartCFrame(
                    CFrame.new(snappedPosition) * CFrame.Angles(0, math.rad(self.CurrentRotation), 0)
                )
                
                -- Check for collisions
                local isColliding = self:CheckCollision()
                
                -- Make preview green (valid) or red (colliding)
                if isColliding then
                    self:SetPreviewColor(COLORS.INVALID, pulseAlpha)
                else
                    self:SetPreviewColor(COLORS.VALID, pulseAlpha)
                end
            else
                -- Make preview red (outside zone)
                self:SetPreviewColor(COLORS.INVALID, pulseAlpha)
            end
        end
    end
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

function BuildingSystem:SnapToGrid(position)
    -- Snap position to grid
    local gridSize = BUILDING_ZONE.GridSize
    return Vector3.new(
        math.floor(position.X / gridSize + 0.5) * gridSize,
        math.floor(position.Y / gridSize + 0.5) * gridSize,
        math.floor(position.Z / gridSize + 0.5) * gridSize
    )
end

function BuildingSystem:IsWithinBuildingZone(position)
    -- Check if position is within the building zone boundaries
    local zonePos = BUILDING_ZONE.StartPosition
    local halfSize = BUILDING_ZONE.Size / 2
    
    return position.X >= zonePos.X - halfSize.X and position.X <= zonePos.X + halfSize.X
       and position.Y >= BUILDING_ZONE.MinHeight and position.Y <= BUILDING_ZONE.MaxHeight
       and position.Z >= zonePos.Z - halfSize.Z and position.Z <= zonePos.Z + halfSize.Z
end

function BuildingSystem:CheckCollision()
    if not self.PreviewModel or not self.PreviewModel.PrimaryPart then return false end
    
    -- Get all parts in preview model
    local previewParts = {}
    for _, part in ipairs(self.PreviewModel:GetDescendants()) do
        if part:IsA("BasePart") and not part.Name:find("Port_") then
            table.insert(previewParts, part)
        end
    end
    
    -- Check for overlap with placed modules
    for _, placedModule in ipairs(self.PlacedModules) do
        if placedModule.Model and placedModule.Model.PrimaryPart then
            for _, placedPart in ipairs(placedModule.Model:GetDescendants()) do
                if placedPart:IsA("BasePart") and not placedPart.Name:find("Port_") then
                    -- Check for overlap with each preview part
                    for _, previewPart in ipairs(previewParts) do
                        local distance = (previewPart.Position - placedPart.Position).Magnitude
                        local combinedSize = (previewPart.Size.Magnitude + placedPart.Size.Magnitude) / 2
                        
                        if distance < combinedSize * 0.7 then -- 70% overlap threshold
                            return true
                        end
                    end
                end
            end
        end
    end
    
    return false
end

function BuildingSystem:SetPreviewColor(color, pulseAlpha)
    if not self.PreviewModel then return end
    
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
    if not self.PreviewModel or not self.PreviewModel.PrimaryPart then return end
    
    -- Don't allow locking if first module and not on platform
    if #self.PlacedModules == 0 then
        print("BuildingSystem: First module must be placed on starting platform")
        return
    end
    
    -- Toggle lock state
    if self.PlacementLocked then
        -- Already locked, do nothing (use confirm button to place)
        print("BuildingSystem: Position already locked - use PLACE button to confirm")
        return
    end
    
    -- Lock the current position
    self.PlacementLocked = true
    self.LockedPosition = self.PreviewModel.PrimaryPart.Position
    self.LockedRotation = self.CurrentRotation
    
    print("BuildingSystem: Position locked! Rotation still available with R key. Click PLACE to confirm.")
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
        return false
    end
    
    -- Check if placement is valid
    local position = self.PreviewModel.PrimaryPart.Position
    if not self:IsWithinBuildingZone(position) then
        warn("BuildingSystem: Placement outside building zone")
        return false
    end
    
    -- Check for collisions
    if self:CheckCollision() then
        warn("BuildingSystem: Cannot place - module is colliding with existing modules")
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
        Rotation = self.CurrentRotation
    })
    
    print("BuildingSystem: Module placed successfully! Total modules: " .. #self.PlacedModules)
    
    -- Hide platform label after first module
    if #self.PlacedModules == 1 then
        local platform = self.BuildingZone:FindFirstChild("StartingPlatform")
        if platform then
            local billboard = platform:FindFirstChildOfClass("BillboardGui")
            if billboard then
                billboard:Destroy()
            end
        end
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

function BuildingSystem:StopBuilding()
    if not self.IsActive then return end
    
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
            position = {moduleInfo.Position.X, moduleInfo.Position.Y, moduleInfo.Position.Z},
            rotation = moduleInfo.Rotation
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


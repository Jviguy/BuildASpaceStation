local CameraController = {}
CameraController.__index = CameraController

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Local player reference
local LocalPlayer = Players.LocalPlayer

-- Camera modes
CameraController.Modes = {
	TOP_DOWN_CONTROLLABLE = "TopDownControllable",
	FREE = "Free",
}

-- Default settings
local DEFAULT_HEIGHT = 120
local MIN_HEIGHT = 20
local MAX_HEIGHT = 300
local PAN_SPEED = 50
local ZOOM_SPEED = 10

function CameraController.new()
	local self = setmetatable({}, CameraController)

	-- Camera state
	self.CurrentMode = nil
	self.CameraHeight = DEFAULT_HEIGHT
	self.CameraPosition = Vector3.new(0, DEFAULT_HEIGHT, 0)
	self.IsActive = false

	-- Input state
	self.KeysPressed = {
		W = false,
		A = false,
		S = false,
		D = false,
		Q = false, -- Move camera down (vertical)
		E = false, -- Move camera up (vertical)
	}

	-- Build plate reference (will be set when activated)
	self.BuildPlate = nil

	-- Mouse wheel connection
	self.MouseWheelConnection = nil

	return self
end

function CameraController:Initialize(gameStateInstance)
	if not workspace.CurrentCamera then
		warn("CameraController: No current camera found")
		return
	end

	-- Store game state reference
	self.GameState = gameStateInstance

	-- Set initial state to free camera
	self:SwitchToMode(CameraController.Modes.FREE)
end

function CameraController:Cleanup()
	-- Restore player character
	if LocalPlayer.Character then
		local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
		if humanoid then
			-- Re-enable character movement
			humanoid.WalkSpeed = 16
			humanoid.JumpPower = 50
			humanoid.JumpHeight = 7.2
		end

		-- Make character visible again
		for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
			if part:IsA("BasePart") or part:IsA("MeshPart") then
				part.Transparency = 0
				if part.Name == "Head" and part:FindFirstChild("face") then
					part.face.Transparency = 0
				end
			elseif part:IsA("Decal") then
				part.Transparency = 0
			end
		end
	end

	-- Disconnect all connections
	if self.RenderConnection then
		self.RenderConnection:Disconnect()
		self.RenderConnection = nil
	end

	if self.InputConnection then
		self.InputConnection:Disconnect()
		self.InputConnection = nil
	end

	if self.InputEndConnection then
		self.InputEndConnection:Disconnect()
		self.InputEndConnection = nil
	end

	if self.MouseWheelConnection then
		self.MouseWheelConnection:Disconnect()
		self.MouseWheelConnection = nil
	end

	-- Reset camera to default
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		-- Camera subject will automatically reset to humanoid when CameraType is set to Custom
	end

	self.CurrentMode = nil
	self.IsActive = false
end

function CameraController:SwitchToMode(mode)
	-- Clean up previous mode
	if self.CurrentMode then
		self:Cleanup()
	end

	self.CurrentMode = mode

	if mode == CameraController.Modes.TOP_DOWN_CONTROLLABLE then
		self:EnableTopDownControllable()
	elseif mode == CameraController.Modes.FREE then
		self:EnableFreeCamera()
	end
end

function CameraController:EnableFreeCamera()
	if workspace.CurrentCamera then
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end
	self.IsActive = false
end

function CameraController:EnableTopDownControllable(buildPlatePosition)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	-- No character to lock since we disabled character spawning

	-- Set camera to scriptable for full control
	camera.CameraType = Enum.CameraType.Scriptable

	-- Disconnect camera from player
	camera.CameraSubject = nil

	-- Set initial position above build plate or origin - CENTER ON THE POSITION
	local targetPos = buildPlatePosition or Vector3.new(0, 0, 0)
	print("========================================")
	print("CameraController: CAMERA INITIALIZATION")
	print(string.format("  Target Position: (%.1f, %.1f, %.1f)", targetPos.X, targetPos.Y, targetPos.Z))
	print(string.format("  Camera Height: %.1f", self.CameraHeight))

	-- Position camera directly above the target position
	self.CameraPosition = Vector3.new(targetPos.X, self.CameraHeight, targetPos.Z)
	print(
		string.format(
			"  Final Camera Pos: (%.1f, %.1f, %.1f)",
			self.CameraPosition.X,
			self.CameraPosition.Y,
			self.CameraPosition.Z
		)
	)
	print("========================================")

	-- Set initial camera position and rotation (looking straight down)
	camera.CFrame = CFrame.new(self.CameraPosition) * CFrame.Angles(-math.pi / 2, 0, 0)

	-- Start render loop
	self.RenderConnection = RunService.RenderStepped:Connect(function(deltaTime)
		self:UpdateCamera(deltaTime)
	end)

	-- Set up input handling (check if GUI is being used)
	self.InputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- Don't process input if a TextBox or ScrollingFrame is focused
		if gameProcessed then
			return
		end
		self:HandleInput(input, true)
	end)

	self.InputEndConnection = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		self:HandleInput(input, false)
	end)

	-- Set up mouse wheel input (only when not over UI)
	self.MouseWheelConnection = UserInputService.InputChanged:Connect(function(input, _gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			-- Check if mouse is over a ScrollingFrame
			local mousePos = UserInputService:GetMouseLocation()
			local guiObjects = LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)

			local isOverScrollingFrame = false
			for _, obj in ipairs(guiObjects) do
				if obj:IsA("ScrollingFrame") or obj.Parent and obj.Parent:IsA("ScrollingFrame") then
					isOverScrollingFrame = true
					break
				end
			end

			-- Only zoom camera if not over a scrolling frame
			if not isOverScrollingFrame then
				self:HandleMouseWheel(input.Position.Z)
			end
		end
	end)

	self.IsActive = true
	print("CameraController: Top-down controllable camera enabled")
end

function CameraController:UpdateCamera(deltaTime)
	if not self.IsActive or self.CurrentMode ~= CameraController.Modes.TOP_DOWN_CONTROLLABLE then
		return
	end

	-- Only process camera movement when in building or play mode
	if not self.GameState or (not self.GameState:IsBuildingMode() and not self.GameState:IsPlayMode()) then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	deltaTime = deltaTime or (1 / 60) -- Fallback to 60 FPS

	-- Handle horizontal panning (WASD movement)
	local moveVector = Vector3.new(0, 0, 0)

	if self.KeysPressed.W then
		moveVector = moveVector + Vector3.new(0, 0, -1)
	end
	if self.KeysPressed.S then
		moveVector = moveVector + Vector3.new(0, 0, 1)
	end
	if self.KeysPressed.A then
		moveVector = moveVector + Vector3.new(-1, 0, 0)
	end
	if self.KeysPressed.D then
		moveVector = moveVector + Vector3.new(1, 0, 0)
	end

	-- Handle vertical movement (Q/E keys)
	local verticalMove = 0
	if self.KeysPressed.Q then
		verticalMove = verticalMove - 1
	end -- Move down
	if self.KeysPressed.E then
		verticalMove = verticalMove + 1
	end -- Move up

	-- Normalize diagonal movement
	if moveVector.Magnitude > 0 then
		moveVector = moveVector.Unit
	end

	-- Apply horizontal movement (world space movement for top-down camera)
	local moveSpeed = PAN_SPEED * deltaTime

	-- For top-down camera, use world axes since camera is always looking down
	local worldMove = Vector3.new(0, 0, 0)
	if moveVector.X ~= 0 then
		worldMove = worldMove + Vector3.new(moveVector.X, 0, 0) -- A/D (left/right)
	end
	if moveVector.Z ~= 0 then
		worldMove = worldMove + Vector3.new(0, 0, moveVector.Z) -- W/S (forward/backward)
	end

	local finalMove = worldMove * moveSpeed

	-- Apply vertical movement (Q/E keys) with height clamping
	if verticalMove ~= 0 then
		self.CameraHeight = math.clamp(self.CameraHeight + (verticalMove * moveSpeed), MIN_HEIGHT, MAX_HEIGHT)
	end

	-- Update camera position with both horizontal and vertical movement
	self.CameraPosition =
		Vector3.new(self.CameraPosition.X + finalMove.X, self.CameraHeight, self.CameraPosition.Z + finalMove.Z)

	-- Update camera position and rotation (always looking straight down)
	camera.CFrame = CFrame.new(self.CameraPosition) * CFrame.Angles(-math.pi / 2, 0, 0)
end

function CameraController:HandleInput(input, isPressed)
	if input.KeyCode == Enum.KeyCode.W then
		self.KeysPressed.W = isPressed
	elseif input.KeyCode == Enum.KeyCode.A then
		self.KeysPressed.A = isPressed
	elseif input.KeyCode == Enum.KeyCode.S then
		self.KeysPressed.S = isPressed
	elseif input.KeyCode == Enum.KeyCode.D then
		self.KeysPressed.D = isPressed
	elseif input.KeyCode == Enum.KeyCode.Q then
		self.KeysPressed.Q = isPressed
	elseif input.KeyCode == Enum.KeyCode.E then
		self.KeysPressed.E = isPressed
	end
end

function CameraController:HandleMouseWheel(delta)
	if not self.IsActive or self.CurrentMode ~= CameraController.Modes.TOP_DOWN_CONTROLLABLE then
		return
	end

	-- Only process mouse wheel when in building or play mode
	if not self.GameState or (not self.GameState:IsBuildingMode() and not self.GameState:IsPlayMode()) then
		return
	end

	-- Zoom in/out based on mouse wheel
	local zoomDelta = delta * ZOOM_SPEED
	self.CameraHeight = math.clamp(self.CameraHeight - zoomDelta, MIN_HEIGHT, MAX_HEIGHT)
	self.CameraPosition = Vector3.new(self.CameraPosition.X, self.CameraHeight, self.CameraPosition.Z)

	-- Update camera immediately
	local camera = workspace.CurrentCamera
	if camera then
		camera.CFrame = CFrame.new(self.CameraPosition) * CFrame.Angles(-math.pi / 2, 0, 0)
	end
end

function CameraController:GetCameraHeight()
	return self.CameraHeight
end

function CameraController:GetCameraPosition()
	return self.CameraPosition
end

function CameraController:GetCurrentMode()
	return self.CurrentMode
end

function CameraController:IsActive()
	return self.IsActive
end

-- Convenience functions for quick mode switching
function CameraController:EnableTopDown(buildPlatePosition)
	-- Store the build plate position before switching modes
	self.BuildPlate = buildPlatePosition
	self:SwitchToMode(CameraController.Modes.TOP_DOWN_CONTROLLABLE)
	-- Now enable with the position
	if self.CurrentMode == CameraController.Modes.TOP_DOWN_CONTROLLABLE then
		self:EnableTopDownControllable(buildPlatePosition)
	end
end

function CameraController:DisableTopDown()
	self:SwitchToMode(CameraController.Modes.FREE)
end

function CameraController:SetTopDownView()
    print("CameraController: Setting top-down view for play mode")
    
    -- Set camera to top-down view of the space station
    local camera = workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Scriptable
    
    -- Calculate the actual center of placed modules
    local stationCenter = self:CalculateStationCenter()
    local cameraHeight = 100 -- Good height to see the station clearly
    
    camera.CFrame = CFrame.new(
        stationCenter + Vector3.new(0, cameraHeight, 0),
        stationCenter
    )
    
    -- Store the initial station center for movement calculations
    self.StationCenter = stationCenter
    
    -- Start forward movement animation
    self:StartForwardMovement()
end

function CameraController:SetBuildingSystem(buildingSystem)
    self.BuildingSystem = buildingSystem
end

function CameraController:CalculateStationCenter()
    -- Use BuildingSystem if available for more accurate module tracking
    if self.BuildingSystem and self.BuildingSystem.PlacedModules then
        local placedModules = self.BuildingSystem.PlacedModules
        
        if #placedModules == 0 then
            -- No modules placed, use default building zone center
            return Vector3.new(0, 30, 0)
        end
        
        -- Calculate center of all placed modules
        local totalPosition = Vector3.new(0, 0, 0)
        for _, moduleData in ipairs(placedModules) do
            if moduleData.Model and moduleData.Model.PrimaryPart then
                totalPosition = totalPosition + moduleData.Model.PrimaryPart.Position
            end
        end
        
        local center = totalPosition / #placedModules
        print("CameraController: Calculated station center from BuildingSystem at:", center)
        return center
    end
    
    -- Fallback: Find all placed modules in the workspace
    local placedModules = {}
    
    -- Look for modules in the workspace
    for _, obj in pairs(workspace:GetChildren()) do
        if obj.Name:find("Module_") and obj:IsA("Model") then
            table.insert(placedModules, obj)
        end
    end
    
    if #placedModules == 0 then
        -- No modules placed, use default building zone center
        return Vector3.new(0, 30, 0)
    end
    
    -- Calculate center of all placed modules
    local totalPosition = Vector3.new(0, 0, 0)
    for _, module in ipairs(placedModules) do
        if module.PrimaryPart then
            totalPosition = totalPosition + module.PrimaryPart.Position
        end
    end
    
    local center = totalPosition / #placedModules
    print("CameraController: Calculated station center from workspace at:", center)
    return center
end

function CameraController:StartForwardMovement()
    print("CameraController: Starting forward movement simulation")
    
    -- Create a moving effect by moving both camera and station forward
    local camera = workspace.CurrentCamera
    local forwardSpeed = 2 -- Speed of forward movement
    
    -- Cancel any existing movement
    if self.MovementConnection then
        self.MovementConnection:Disconnect()
    end
    
    self.MovementConnection = RunService.Heartbeat:Connect(function()
        -- Move camera forward
        local currentCFrame = camera.CFrame
        local forwardMovement = Vector3.new(0, 0, -forwardSpeed) -- Move forward in Z direction
        camera.CFrame = currentCFrame + forwardMovement
        
        -- Move all placed modules forward with the camera
        self:MoveStationForward(forwardMovement)
        
        -- Update station center for camera tracking
        self.StationCenter = self.StationCenter + forwardMovement
    end)
end

function CameraController:MoveStationForward(movement)
    -- Use BuildingSystem if available for more reliable module movement
    if self.BuildingSystem and self.BuildingSystem.PlacedModules then
        local placedModules = self.BuildingSystem.PlacedModules
        
        for _, moduleData in ipairs(placedModules) do
            if moduleData.Model then
                -- Move the entire module
                if moduleData.Model.PrimaryPart then
                    moduleData.Model:SetPrimaryPartCFrame(moduleData.Model.PrimaryPart.CFrame + movement)
                else
                    -- If no PrimaryPart, move all parts
                    for _, part in pairs(moduleData.Model:GetChildren()) do
                        if part:IsA("BasePart") then
                            part.CFrame = part.CFrame + movement
                        end
                    end
                end
                
                -- Update the stored position in BuildingSystem
                moduleData.Position = moduleData.Position + movement
            end
        end
    else
        -- Fallback: Find and move all placed modules in workspace
        for _, obj in pairs(workspace:GetChildren()) do
            if obj.Name:find("Module_") and obj:IsA("Model") then
                -- Move the entire module
                if obj.PrimaryPart then
                    obj:SetPrimaryPartCFrame(obj.PrimaryPart.CFrame + movement)
                else
                    -- If no PrimaryPart, move all parts
                    for _, part in pairs(obj:GetChildren()) do
                        if part:IsA("BasePart") then
                            part.CFrame = part.CFrame + movement
                        end
                    end
                end
            end
        end
    end
    
    -- Also move the building zone if it exists
    local buildingZone = workspace:FindFirstChild("BuildingZone_" .. LocalPlayer.Name)
    if buildingZone then
        for _, obj in pairs(buildingZone:GetChildren()) do
            if obj:IsA("BasePart") then
                obj.CFrame = obj.CFrame + movement
            end
        end
    end
end

function CameraController:ResetCamera()
    print("CameraController: Resetting camera from play mode")
    
    -- Stop forward movement
    if self.MovementConnection then
        self.MovementConnection:Disconnect()
        self.MovementConnection = nil
    end
    
    -- Reset to building camera mode
    self:EnableTopDownCamera()
end

return CameraController

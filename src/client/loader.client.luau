local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer.StarterPlayerScripts
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local CameraController = require(StarterPlayerScripts.Client.modules.CameraController)
local GameState = require(StarterPlayerScripts.Client.modules.GameState)
local UIManager = require(StarterPlayerScripts.Client.modules.UIManager)
local MissionDataManager = require(StarterPlayerScripts.Client.modules.MissionDataManager)
local BuildingSystem = require(StarterPlayerScripts.Client.modules.BuildingSystem)
local ToastNotification = require(StarterPlayerScripts.Client.modules.ui.ToastNotification)

-- UI Components
local WelcomeUI = require(StarterPlayerScripts.Client.modules.ui.WelcomeUI)
local MissionSetupUI = require(StarterPlayerScripts.Client.modules.ui.MissionSetupUI)
local BuildingUI = require(StarterPlayerScripts.Client.modules.ui.BuildingUI)
local PlayUI = require(StarterPlayerScripts.Client.modules.ui.PlayUI)

-- Create core systems
local gameState = GameState.new()
local missionDataManager = MissionDataManager.new()
local cameraController = CameraController.new()
local uiManager = UIManager.new(gameState)
local toastNotification = ToastNotification.new()
local buildingSystem = BuildingSystem.new(cameraController, uiManager, toastNotification)

-- Initialize mission data manager and request initial data
missionDataManager:RequestMissionData()

-- Initialize building system
buildingSystem:Initialize()

-- Initialize toast notification system
toastNotification:Initialize()

-- Request lane assignment from server
local function requestLaneAssignment()
	local RequestLaneAssignment = ReplicatedStorage:WaitForChild("RequestLaneAssignment", 10)
	local AssignLane = ReplicatedStorage:WaitForChild("AssignLane", 10)

	if RequestLaneAssignment and AssignLane then
		-- Set up listener for lane assignment response
		local connection
		connection = AssignLane.OnClientEvent:Connect(
			function(laneId, posX, posY, posZ, sizeX, sizeY, sizeZ, spawnX, spawnY, spawnZ)
				print(string.format("Client: Received lane assignment - Lane %d", laneId))
				print(string.format("  Position: (%.1f, %.1f, %.1f)", posX, posY, posZ))
				print(string.format("  Size: (%.1f, %.1f, %.1f)", sizeX, sizeY, sizeZ))
				print(string.format("  Spawn: (%.1f, %.1f, %.1f)", spawnX or 0, spawnY or 0, spawnZ or 0))

				-- Pass lane data to building system
				local position = Vector3.new(posX, posY, posZ)
				local size = Vector3.new(sizeX, sizeY, sizeZ)
				local spawnPosition = Vector3.new(spawnX or posX, spawnY or posY, spawnZ or posZ)

				buildingSystem:SetLaneData(laneId, position, size, spawnPosition)

				-- Disconnect after receiving (only need it once)
				connection:Disconnect()
			end
		)

		-- Request lane assignment
		print("Client: Requesting lane assignment...")
		RequestLaneAssignment:FireServer()
	else
		warn("Client: Failed to find lane assignment RemoteEvents")
	end
end

-- Request lane assignment immediately (no delay needed)
requestLaneAssignment()

-- FORCE render the building zone after a moment (even before state change)
task.delay(1, function()
	if buildingSystem.LaneAssigned then
		print("Client: Lane is assigned, building zone should be visible!")
		-- Check if building zone exists
		local buildingZone = workspace:FindFirstChild("BuildingZone_" .. LocalPlayer.Name)
		if buildingZone then
			print("Client: ✓ Building zone found in workspace with " .. #buildingZone:GetChildren() .. " children")
			-- List all children for debugging
			for _, child in ipairs(buildingZone:GetChildren()) do
				print("  - " .. child.Name .. " (" .. child.ClassName .. ")")
			end
		else
			warn("Client: ✗ Building zone NOT FOUND in workspace!")
		end
	else
		warn("Client: Lane not assigned yet after 1 second!")
	end
end)

-- Create UI instances with mission data manager and building system
local welcomeUI = WelcomeUI.new(uiManager, missionDataManager)
local missionSetupUI = MissionSetupUI.new(uiManager, missionDataManager)
local buildingUI = BuildingUI.new(uiManager, missionDataManager, buildingSystem)
local playUI = PlayUI.new(uiManager, missionDataManager)

-- Initialize camera controller with game state
cameraController:Initialize(gameState)

-- Add camera state change listener to respond to game state changes
gameState:AddStateChangeListener(function(oldMode, newMode)
	print("Loader: State changed from " .. tostring(oldMode) .. " to " .. tostring(newMode) .. ", updating camera...")

	if newMode == GameState.Modes.BUILDING or newMode == GameState.Modes.PLAY then
		-- Enable top-down controllable camera for building and play modes
		print("Loader: Enabling top-down camera for " .. newMode .. " mode")

		-- Focus camera on player's lane CENTER position (middle of the lane)
		local focusPosition = Vector3.new(0, 0, 0)
		if buildingSystem.LaneAssigned and buildingSystem.LaneData then
			-- Focus on the CENTER of the lane (not spawn position)
			focusPosition = buildingSystem.LaneData.Position -- This is the CENTER
			print("========================================")
			print("Loader: CENTERING CAMERA ON LANE")
			print(string.format("  Lane ID: %d", buildingSystem.LaneData.LaneId))
			print(
				string.format(
					"  Lane Center (Position): (%.1f, %.1f, %.1f)",
					buildingSystem.LaneData.Position.X,
					buildingSystem.LaneData.Position.Y,
					buildingSystem.LaneData.Position.Z
				)
			)
			print(
				string.format(
					"  Lane Size: (%.1f, %.1f, %.1f)",
					buildingSystem.LaneData.Size.X,
					buildingSystem.LaneData.Size.Y,
					buildingSystem.LaneData.Size.Z
				)
			)
			print(string.format("  Focus Position (X,Z): (%.1f, %.1f)", focusPosition.X, focusPosition.Z))
			print("========================================")
		else
			warn("Loader: Lane not assigned yet, using default camera position")
		end

		cameraController:EnableTopDown(focusPosition)
	elseif newMode == GameState.Modes.WELCOME or newMode == GameState.Modes.MISSION_SETUP then
		-- Keep camera fixed for welcome and mission setup
		print("Loader: Setting fixed camera for " .. newMode .. " mode")
		if workspace.CurrentCamera then
			workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
			workspace.CurrentCamera.CFrame = CFrame.new(Vector3.new(0, 50, 0), Vector3.new(0, 0, 0))
		end
		cameraController:DisableTopDown()
	end
end)

-- Initialize UI manager and register UIs
uiManager:Initialize()

-- Register UI components for each game state
uiManager:RegisterUI(GameState.Modes.WELCOME, welcomeUI:Create(), function(gui)
	welcomeUI:Show(gui)
end, function(gui)
	welcomeUI:Hide(gui)
end)
uiManager:RegisterUI(GameState.Modes.MISSION_SETUP, missionSetupUI:Create(), function(gui)
	missionSetupUI:Show(gui)
end, function(gui)
	missionSetupUI:Hide(gui)
end)
uiManager:RegisterUI(GameState.Modes.BUILDING, buildingUI:Create(), function(gui)
	buildingUI:Show(gui)
end, function(gui)
	buildingUI:Hide(gui)
end)
uiManager:RegisterUI(GameState.Modes.PLAY, playUI:Create(), function(gui)
	playUI:Show(gui)
end, function(gui)
	playUI:Hide(gui)
end)

-- Set initial game state to welcome mode
print("Loader: About to enter Welcome mode...")
gameState:EnterWelcome()
print("Loader: EnterWelcome() completed")

-- Set up initial fixed camera position for welcome screen
-- Camera starts fixed and only becomes controllable in Building/Play modes

-- Set initial fixed camera position (above origin, looking down)
local function setupInitialCamera()
	if workspace.CurrentCamera then
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		workspace.CurrentCamera.CFrame = CFrame.new(Vector3.new(0, 50, 0), Vector3.new(0, 0, 0))
		print("CameraController: Initial fixed camera position set for welcome screen")
	end
end

-- Set up initial camera immediately
setupInitialCamera()

print("Client: All systems initialized successfully")

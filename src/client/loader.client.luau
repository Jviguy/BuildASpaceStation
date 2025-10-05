local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer.StarterPlayerScripts
local CameraController = require(StarterPlayerScripts.Client.modules.CameraController)
local GameState = require(StarterPlayerScripts.Client.modules.GameState)
local UIManager = require(StarterPlayerScripts.Client.modules.UIManager)
local MissionDataManager = require(StarterPlayerScripts.Client.modules.MissionDataManager)
local BuildingSystem = require(StarterPlayerScripts.Client.modules.BuildingSystem)

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
local buildingSystem = BuildingSystem.new(cameraController, uiManager)

-- Initialize mission data manager and request initial data
missionDataManager:RequestMissionData()

-- Initialize building system
buildingSystem:Initialize()

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
        cameraController:EnableTopDown(Vector3.new(0, 0, 0))
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
uiManager:RegisterUI(GameState.Modes.WELCOME, welcomeUI:Create(), function(gui) welcomeUI:Show(gui) end, function(gui) welcomeUI:Hide(gui) end)
uiManager:RegisterUI(GameState.Modes.MISSION_SETUP, missionSetupUI:Create(), function(gui) missionSetupUI:Show(gui) end, function(gui) missionSetupUI:Hide(gui) end)
uiManager:RegisterUI(GameState.Modes.BUILDING, buildingUI:Create(), function(gui) buildingUI:Show(gui) end, function(gui) buildingUI:Hide(gui) end)
uiManager:RegisterUI(GameState.Modes.PLAY, playUI:Create(), function(gui) playUI:Show(gui) end, function(gui) playUI:Hide(gui) end)

-- Set initial game state to welcome mode
print("Loader: About to enter Welcome mode...")
gameState:EnterWelcome()
print("Loader: EnterWelcome() completed")

-- Set up initial fixed camera position for welcome screen
-- Camera starts fixed and only becomes controllable in Building/Play modes
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

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

-- Make all systems globally accessible for other scripts
_G.CameraController = cameraController
_G.GameState = gameState
_G.UIManager = uiManager
_G.MissionDataManager = missionDataManager
_G.BuildingSystem = buildingSystem
_G.UIComponents = {
    WelcomeUI = welcomeUI,
    MissionSetupUI = missionSetupUI,
    BuildingUI = buildingUI,
    PlayUI = playUI
}

print("Client: All systems initialized successfully")
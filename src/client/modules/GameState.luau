local GameState = {}
GameState.__index = GameState

-- Game modes based on roadmap
GameState.Modes = {
    WELCOME = "Welcome",
    MISSION_SETUP = "MissionSetup",
    BUILDING = "Building",
    PLAY = "Play",
    GAME_OVER = "GameOver"
}

-- Current state (start as nil so first state change triggers listeners)
local currentMode = nil
local stateChangeListeners = {}

function GameState.new()
    local self = setmetatable({}, GameState)
    return self
end

function GameState:GetCurrentMode()
    return currentMode
end

function GameState:SetMode(newMode)
    if currentMode == newMode then return end

    local oldMode = currentMode
    currentMode = newMode

    print("GameState: Changed from " .. tostring(oldMode) .. " to " .. tostring(newMode))

    -- Notify all listeners
    for _, listener in ipairs(stateChangeListeners) do
        listener(oldMode, newMode)
    end
end

function GameState:IsInMode(mode)
    return currentMode == mode
end

function GameState:IsBuildingMode()
    return currentMode == GameState.Modes.BUILDING
end

function GameState:IsWelcomeMode()
    return currentMode == GameState.Modes.WELCOME
end

function GameState:IsMissionSetupMode()
    return currentMode == GameState.Modes.MISSION_SETUP
end

function GameState:IsPlayMode()
    return currentMode == GameState.Modes.PLAY
end

function GameState:AddStateChangeListener(listener)
    table.insert(stateChangeListeners, listener)
end

function GameState:RemoveStateChangeListener(listener)
    for i, existingListener in ipairs(stateChangeListeners) do
        if existingListener == listener then
            table.remove(stateChangeListeners, i)
            break
        end
    end
end

-- Convenience functions for mode transitions
function GameState:EnterWelcome()
    self:SetMode(GameState.Modes.WELCOME)
end

function GameState:EnterMissionSetup()
    self:SetMode(GameState.Modes.MISSION_SETUP)
end

function GameState:EnterBuildingMode()
    self:SetMode(GameState.Modes.BUILDING)
end

function GameState:EnterPlayMode()
    self:SetMode(GameState.Modes.PLAY)
end

function GameState:EnterGameOver()
    self:SetMode(GameState.Modes.GAME_OVER)
end

return GameState

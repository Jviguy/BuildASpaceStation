-- Server loader for mission data management
local Players = game:GetService("Players")
local MissionDataManager = require(script.Parent.modules.MissionDataManager)
local MissionEvents = require(game:GetService("ReplicatedStorage").Shared.MissionEvents)

-- Store mission data managers for each player
local playerManagers = {}

-- Handle player joining
Players.PlayerAdded:Connect(function(player)
    print("Server: Player joined, creating mission data manager for " .. player.Name)

    -- Create mission data manager for this player (this will load the profile)
    -- This blocks until profile is loaded from DataStore
    print("Server: Loading profile for " .. player.Name .. "...")
    local manager = MissionDataManager.new(player)
    print("Server: Profile loading completed for " .. player.Name)
    
    -- Store the manager immediately so it's available for requests
    playerManagers[player] = manager
    print("Server: Manager stored for " .. player.Name)
    
    -- Initialize after storing (starts auto-save)
    manager:Initialize()

    print("Server: Mission data manager created for " .. player.Name)
end)

-- Handle player leaving
Players.PlayerRemoving:Connect(function(player)
    local manager = playerManagers[player]
    if manager then
        -- Stop auto-save immediately
        if manager.Profile then
            pcall(function() manager:StopAutoSave() end)
        end
        -- Clean up immediately - no waiting for saves
        playerManagers[player] = nil
    end
end)

-- Handle game shutdown - MINIMAL delay
game:BindToClose(function()
    -- Quick save all profiles without waiting
    for _, manager in pairs(playerManagers) do
        if manager and manager.Profile then
            pcall(function() 
                manager.Profile:Save()
            end)
        end
    end
    -- Minimal wait (Studio requires this or it won't save)
    task.wait(0.5)
end)

-- Handle RemoteEvents
MissionEvents.GetMissionData.OnServerEvent:Connect(function(player)
    print("Server: GetMissionData received from player " .. player.Name)
    local manager = playerManagers[player]
    if manager then
        if manager.Profile then
            print("Server: Found mission manager for player, sending data...")
            MissionEvents.HandleGetMissionData(player, manager)
            print("Server: Mission data sent to player")
        else
            warn("Server: Manager exists but profile not loaded yet for player " .. player.Name)
        end
    else
        warn("Server: No mission data manager found for player " .. player.Name)
    end
end)

MissionEvents.UpdateMissionData.OnServerEvent:Connect(function(player, updates)
    local manager = playerManagers[player]
    if manager then
        MissionEvents.HandleUpdateMissionData(player, updates, manager)
    else
        warn("Server: No mission data manager found for player " .. player.Name)
    end
end)

print("Server: Mission data system initialized")
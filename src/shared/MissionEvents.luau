-- RemoteEvents for mission data communication between client and server
-- This module provides a clean interface for mission data operations

local MissionEvents = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create RemoteEvents if they don't exist
local function getRemoteEvent(name)
    local event = ReplicatedStorage:FindFirstChild(name)
    if not event then
        event = Instance.new("RemoteEvent")
        event.Name = name
        event.Parent = ReplicatedStorage
    end
    return event
end

-- RemoteEvents
MissionEvents.GetMissionData = getRemoteEvent("GetMissionData") -- Client -> Server: Request mission data
MissionEvents.UpdateMissionData = getRemoteEvent("UpdateMissionData") -- Client -> Server: Send mission data updates
MissionEvents.MissionDataLoaded = getRemoteEvent("MissionDataLoaded") -- Server -> Client: Send mission data response

-- Client-side functions
function MissionEvents:GetMissionDataAsync(player)
    -- Send request to server
    self.GetMissionData:FireServer()

    -- Wait for response (this will be handled by a listener)
    -- The server will call MissionDataLoaded with the data
    return nil -- For now, return nil and handle asynchronously
end

function MissionEvents:UpdateMissionDataAsync(updates)
    -- Send updates to server
    self.UpdateMissionData:FireServer(updates)
end

-- Module-level functions for server-side handling
function MissionEvents.HandleGetMissionData(player, missionDataManager)
    -- Get mission data for the player
    local missionData = missionDataManager:GetMissionData()
    -- Send back to client
    MissionEvents.MissionDataLoaded:FireClient(player, missionData)
end

function MissionEvents.HandleUpdateMissionData(player, updates, missionDataManager)
    -- Update mission data for the player
    missionDataManager:UpdateMissionData(updates)
end

return MissionEvents

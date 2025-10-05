local MissionDataManager = {}
MissionDataManager.__index = MissionDataManager

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MissionEvents = require(ReplicatedStorage.Shared.MissionEvents)

-- Local player reference
local LocalPlayer = Players.LocalPlayer

function MissionDataManager.new()
    local self = setmetatable({}, MissionDataManager)

    -- Cached mission data (received from server)
    self.CurrentMissionData = {
        CrewSize = 4,
        Duration = 30,
        MissionType = "Earth Orbit",
        CurrentState = "Welcome",
        ModulesPlaced = {},
        ValidationProgress = {},
        CreatedAt = 0,
        LastUpdated = 0
    }

    -- Track if data has been loaded from server
    self.DataLoaded = false

    -- Listeners for server responses
    self.Listeners = {}

    -- Setup event listeners
    self:SetupEventListeners()

    return self
end

function MissionDataManager:SetupEventListeners()
    -- Listen for mission data responses from server
    self.Listeners.MissionDataLoaded = MissionEvents.MissionDataLoaded.OnClientEvent:Connect(function(missionData)
        self.CurrentMissionData = missionData
        self.DataLoaded = true
        print("MissionDataManager: Received mission data from server")
        print("- Crew Size: " .. missionData.CrewSize)
        print("- Duration: " .. missionData.Duration .. " days")
        print("- Mission Type: " .. missionData.MissionType)
        print("- Current State: " .. missionData.CurrentState)
    end)
end

function MissionDataManager:RequestMissionData()
    -- Request mission data from server
    print("MissionDataManager: Firing GetMissionData to server")
    MissionEvents.GetMissionData:FireServer()
    print("MissionDataManager: GetMissionData fired, waiting for response...")
    
    -- Set up retry mechanism in case server isn't ready yet
    task.delay(2, function()
        if not self.DataLoaded then
            print("MissionDataManager: No response yet, retrying...")
            MissionEvents.GetMissionData:FireServer()
        end
    end)
    
    task.delay(5, function()
        if not self.DataLoaded then
            print("MissionDataManager: Still no response, retrying again...")
            MissionEvents.GetMissionData:FireServer()
        end
    end)
end

function MissionDataManager:UpdateMissionData(updates)
    -- Send updates to server
    MissionEvents.UpdateMissionData:FireServer(updates)

    -- Update local cache immediately for responsiveness
    for key, value in pairs(updates) do
        if self.CurrentMissionData[key] ~= nil then
            self.CurrentMissionData[key] = value
        end
    end

    print("MissionDataManager: Sent mission data updates to server")
end

function MissionDataManager:GetMissionData()
    return self.CurrentMissionData
end

function MissionDataManager:ClearMissionData()
    -- Reset to default values
    self.CurrentMissionData = {
        CrewSize = 4,
        Duration = 30,
        MissionType = "Lunar Base",
        CurrentState = "Welcome",
        ModulesPlaced = {},
        ValidationProgress = {},
        CreatedAt = os.time(),
        LastUpdated = os.time()
    }

    -- Send the cleared data to server
    self:UpdateMissionData(self.CurrentMissionData)

    print("MissionDataManager: Mission data cleared")
end

function MissionDataManager:GetProgress()
    local totalModules = #self.CurrentMissionData.ModulesPlaced
    local validatedAreas = 0

    for _, progress in pairs(self.CurrentMissionData.ValidationProgress) do
        if progress >= 1.0 then
            validatedAreas = validatedAreas + 1
        end
    end

    return {
        ModulesPlaced = totalModules,
        ValidatedAreas = validatedAreas,
        CompletionPercentage = totalModules > 0 and (validatedAreas / totalModules) * 100 or 0
    }
end

function MissionDataManager:RecordModulePlacement(moduleData)
    table.insert(self.CurrentMissionData.ModulesPlaced, moduleData)
    self:UpdateMissionData({
        ModulesPlaced = self.CurrentMissionData.ModulesPlaced
    })
    print("MissionDataManager: Recorded module placement: " .. moduleData.name)
end

function MissionDataManager:UpdateValidationProgress(area, progress)
    self.CurrentMissionData.ValidationProgress[area] = progress
    self:UpdateMissionData({
        ValidationProgress = self.CurrentMissionData.ValidationProgress
    })
    print("MissionDataManager: Updated validation progress for area: " .. area)
end

function MissionDataManager:Cleanup()
    -- Disconnect listeners
    for _, listener in pairs(self.Listeners) do
        if listener then
            listener:Disconnect()
        end
    end
    self.Listeners = {}
end

return MissionDataManager
local MissionDataManager = {}
MissionDataManager.__index = MissionDataManager

-- Services
local RunService = game:GetService("RunService")

-- ProfileStore for data persistence
-- Path: MissionDataManager -> modules -> Server -> ServerScriptService -> ServerPackages -> profilestore
local ServerScriptService = game:GetService("ServerScriptService")
local ProfileStore = require(ServerScriptService.ServerPackages.profilestore)

-- Profile store for mission data
local MissionProfileStore = ProfileStore.New("MissionData", {
    CrewSize = 4,
    Duration = 30,
    MissionType = "Earth Orbit",
    CurrentState = "Welcome",
    ModulesPlaced = {},
    ValidationProgress = {},
    CreatedAt = 0,
    LastUpdated = 0
})

function MissionDataManager.new(player)
    local self = setmetatable({}, MissionDataManager)

    self.Player = player
    self.AutoSaveEnabled = false  -- Disabled for faster shutdown
    self.AutoSaveInterval = 30 -- seconds

    -- Load or create profile for this player
    -- StartSessionAsync will automatically create a new profile if one doesn't exist
    local profileKey = "Player_" .. player.UserId
    print("MissionDataManager: Attempting to load profile with key: " .. profileKey)
    
    self.Profile = MissionProfileStore:StartSessionAsync(profileKey, {
        Cancel = function()
            -- Keep trying as long as player is still in game
            return player:IsDescendantOf(game) == false
        end
    })

    if self.Profile then
        print("MissionDataManager: Profile loaded successfully for player " .. player.Name)
        print("MissionDataManager: Profile data keys: " .. tostring(self.Profile.Data and "exists" or "nil"))
        
        -- Set timestamps if this is a new profile
        if self.Profile.Data.CreatedAt == 0 then
            self.Profile.Data.CreatedAt = os.time()
            self.Profile.Data.LastUpdated = os.time()
            print("MissionDataManager: New profile created with timestamps")
        end
        
        -- Handle profile release when player leaves
        self.Profile:AddUserId(player.UserId)
        self.Profile:Reconcile()
        
        -- Listen for profile release
        self.Profile.OnSessionEnd:Connect(function()
            print("MissionDataManager: Profile session ended for player " .. player.Name)
        end)
    else
        warn("MissionDataManager: Failed to load profile for player " .. player.Name)
        warn("MissionDataManager: This usually means the player left before profile could load")
    end

    -- Auto-save connection
    self.AutoSaveConnection = nil

    return self
end

function MissionDataManager:Initialize()
    -- Profile is already loaded in constructor
    -- Set up auto-save if enabled
    if self.AutoSaveEnabled then
        self:StartAutoSave()
    end

    print("MissionDataManager: Initialized")
end

function MissionDataManager:GetMissionData()
    if not self.Profile then
        warn("MissionDataManager: No profile loaded")
        return nil
    end

    -- Get current data from profile
    local data = self.Profile.Data
    print("MissionDataManager: Retrieved mission data")
    print("- Crew Size: " .. data.CrewSize)
    print("- Duration: " .. data.Duration .. " days")
    print("- Mission Type: " .. data.MissionType)
    print("- Current State: " .. data.CurrentState)

    return data
end

function MissionDataManager:SaveMissionData()
    if not self.Profile then
        warn("MissionDataManager: No profile to save")
        return false
    end

    -- Update timestamp
    self.Profile.Data.LastUpdated = os.time()

    -- ProfileStore automatically saves periodically, manual save triggers immediate save
    self.Profile:Save()
    print("MissionDataManager: Mission data saved successfully")
    
    return true
end

function MissionDataManager:UpdateMissionData(updates)
    if not self.Profile then
        warn("MissionDataManager: No profile to update")
        return
    end

    -- Update mission data with new values
    for key, value in pairs(updates) do
        self.Profile.Data[key] = value
    end

    -- Update timestamp
    self.Profile.Data.LastUpdated = os.time()

    -- Always save immediately on updates (ProfileStore auto-throttles)
    pcall(function()
        self.Profile:Save()
    end)
end

function MissionDataManager:ClearMissionData()
    if not self.Profile then
        warn("MissionDataManager: No profile to clear")
        return
    end

    -- Reset to default values
    self.Profile.Data = {
        CrewSize = 4,
        Duration = 30,
        MissionType = "Lunar Base",
        CurrentState = "Welcome",
        ModulesPlaced = {},
        ValidationProgress = {},
        CreatedAt = os.time(),
        LastUpdated = os.time()
    }

    self.Profile:Save()
    print("MissionDataManager: Mission data cleared")
end

function MissionDataManager:StartAutoSave()
    if self.AutoSaveConnection then
        self.AutoSaveConnection:Disconnect()
    end

    self.AutoSaveConnection = RunService.Heartbeat:Connect(function()
        if self.Profile and os.time() - self.Profile.Data.LastUpdated >= self.AutoSaveInterval then
            self.Profile:Save()
        end
    end)

    print("MissionDataManager: Auto-save started (every " .. self.AutoSaveInterval .. " seconds)")
end

function MissionDataManager:StopAutoSave()
    if self.AutoSaveConnection then
        self.AutoSaveConnection:Disconnect()
        self.AutoSaveConnection = nil
        print("MissionDataManager: Auto-save stopped")
    end
end

function MissionDataManager:GetProgress()
    if not self.Profile then
        return { ModulesPlaced = 0, ValidatedAreas = 0, CompletionPercentage = 0 }
    end

    local data = self.Profile.Data
    local totalModules = #data.ModulesPlaced
    local validatedAreas = 0

    for _, progress in pairs(data.ValidationProgress) do
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
    if not self.Profile then
        warn("MissionDataManager: No profile to record module placement")
        return
    end

    table.insert(self.Profile.Data.ModulesPlaced, moduleData)
    self.Profile.Data.LastUpdated = os.time()
    -- Save immediately (wrapped for safety)
    pcall(function()
        self.Profile:Save()
    end)
end

function MissionDataManager:UpdateValidationProgress(area, progress)
    if not self.Profile then
        warn("MissionDataManager: No profile to update validation progress")
        return
    end

    self.Profile.Data.ValidationProgress[area] = progress
    self.Profile.Data.LastUpdated = os.time()
    -- Save immediately (wrapped for safety)
    pcall(function()
        self.Profile:Save()
    end)
end

return MissionDataManager

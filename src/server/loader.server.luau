-- Server loader for mission data management
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MissionDataManager = require(script.Parent.modules.MissionDataManager)
local MissionEvents = require(ReplicatedStorage.Shared.MissionEvents)
local LaneManager = require(script.Parent.modules.LaneManager)

-- Create lane manager
local laneManager = LaneManager.new()

-- Store mission data managers for each player
local playerManagers = {}

-- Disable player characters completely - this is a building game, no character needed
Players.CharacterAutoLoads = false

-- Handle player joining
Players.PlayerAdded:Connect(function(player)
	print("Server: Player joined (NO CHARACTER MODE) - " .. player.Name)

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

	-- Assign a lane to this player
	local laneData = laneManager:AssignLane(player)
	print("========================================")
	print(string.format("Server: ✓ ASSIGNED LANE %d to %s", laneData.LaneId, player.Name))
	print(
		string.format("  Position: (%.1f, %.1f, %.1f)", laneData.Position.X, laneData.Position.Y, laneData.Position.Z)
	)
	print(string.format("  Size: (%.1f x %.1f x %.1f)", laneData.Size.X, laneData.Size.Y, laneData.Size.Z))
	print("========================================")

	print("Server: Mission data manager and lane created for " .. player.Name)
end)

-- Handle player leaving
Players.PlayerRemoving:Connect(function(player)
	local manager = playerManagers[player]
	if manager then
		-- Stop auto-save immediately
		if manager.Profile then
			pcall(function()
				manager:StopAutoSave()
			end)
		end
		-- Clean up immediately - no waiting for saves
		playerManagers[player] = nil
	end

	-- Remove lane assignment
	laneManager:RemoveLane(player)
	print("Server: Cleaned up lane for " .. player.Name)
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

-- Create RemoteEvents for lane assignment
local RequestLaneAssignment = Instance.new("RemoteEvent")
RequestLaneAssignment.Name = "RequestLaneAssignment"
RequestLaneAssignment.Parent = ReplicatedStorage

local AssignLane = Instance.new("RemoteEvent")
AssignLane.Name = "AssignLane"
AssignLane.Parent = ReplicatedStorage

-- Handle lane assignment requests
RequestLaneAssignment.OnServerEvent:Connect(function(player)
	print("Server: Lane assignment request from " .. player.Name)
	local laneData = laneManager:GetLane(player)

	if laneData then
		-- Send lane data to client including spawn position
		AssignLane:FireClient(
			player,
			laneData.LaneId,
			laneData.Position.X,
			laneData.Position.Y,
			laneData.Position.Z,
			laneData.Size.X,
			laneData.Size.Y,
			laneData.Size.Z,
			laneData.SpawnPosition.X,
			laneData.SpawnPosition.Y,
			laneData.SpawnPosition.Z
		)
		print(
			string.format(
				"Server: Sent lane %d data to %s (Size: %s, Spawn: %s)",
				laneData.LaneId,
				player.Name,
				tostring(laneData.Size),
				tostring(laneData.SpawnPosition)
			)
		)
	else
		warn("Server: No lane assigned to player " .. player.Name)
	end
end)

print("Server: Mission data system and lane manager initialized")

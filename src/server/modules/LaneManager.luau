local LaneManager = {}
LaneManager.__index = LaneManager

-- Lane configuration - Space Highway style
local LANE_CONFIG = {
	-- Each lane is a long highway extending into space
	LaneWidth = 400, -- Width of each lane (studs) - WIDER
	LaneHeight = 200, -- Height of each lane (studs)
	LaneLength = 2048, -- Length of highway lane (studs) - MASSIVE
	LaneSpacing = 500, -- Space between lanes (studs) - more spacing for wider lanes
	StartingYPosition = 100, -- Y position where lanes start (elevated)
	StartingZPosition = 0, -- Z position where lanes start
	GridSize = 4, -- Snap grid size
}

function LaneManager.new()
	local self = setmetatable({}, LaneManager)

	-- Track assigned lanes
	self.PlayerLanes = {} -- [Player] = LaneData
	self.NextLaneId = 0
	self.UsedLaneIds = {} -- Set of used lane IDs

	return self
end

function LaneManager:AssignLane(player)
	-- Check if player already has a lane
	if self.PlayerLanes[player] then
		return self.PlayerLanes[player]
	end

	-- Get next available lane ID
	local laneId = self.NextLaneId
	self.NextLaneId = self.NextLaneId + 1

	-- Calculate lane position - Lanes extend along Z axis (forward), separated along X axis
	-- Each player gets their own "highway" lane
	local positionX = laneId * (LANE_CONFIG.LaneWidth + LANE_CONFIG.LaneSpacing)
	local positionY = LANE_CONFIG.StartingYPosition
	local positionZ = LANE_CONFIG.StartingZPosition + (LANE_CONFIG.LaneLength / 2) -- Center of the lane

	local laneData = {
		LaneId = laneId,
		Player = player,
		Position = Vector3.new(positionX, positionY, positionZ),
		Size = Vector3.new(LANE_CONFIG.LaneWidth, LANE_CONFIG.LaneHeight, LANE_CONFIG.LaneLength),
		GridSize = LANE_CONFIG.GridSize,
		SpawnPosition = Vector3.new(positionX, positionY, LANE_CONFIG.StartingZPosition + 50), -- Spawn at start of lane
	}

	self.PlayerLanes[player] = laneData
	self.UsedLaneIds[laneId] = true

	print(
		string.format(
			"LaneManager: Assigned lane %d to %s at position %s",
			laneId,
			player.Name,
			tostring(laneData.Position)
		)
	)

	return laneData
end

function LaneManager:GetLane(player)
	return self.PlayerLanes[player]
end

function LaneManager:RemoveLane(player)
	local laneData = self.PlayerLanes[player]
	if laneData then
		self.UsedLaneIds[laneData.LaneId] = nil
		self.PlayerLanes[player] = nil
		print(string.format("LaneManager: Removed lane %d for %s", laneData.LaneId, player.Name))
	end
end

function LaneManager:Cleanup()
	self.PlayerLanes = {}
	self.UsedLaneIds = {}
	print("LaneManager: Cleaned up all lanes")
end

return LaneManager

local ModuleDataManager = {}
ModuleDataManager.__index = ModuleDataManager

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

function ModuleDataManager.new()
	local self = setmetatable({}, ModuleDataManager)
	
	-- Module data storage
	self.Categories = {}
	self.ModulesByCategory = {}
	self.ModulesById = {}
	self.CategoryData = {}
	
	-- Loading state
	self.IsLoaded = false
	self.LoadingPromise = nil
	
	return self
end

function ModuleDataManager:Initialize()
	print("ModuleDataManager: Initializing...")
	
	-- Load all module data
	self:LoadModuleData()
	
	print("ModuleDataManager: Initialized")
end

function ModuleDataManager:LoadModuleData()
	if self.LoadingPromise then
		return self.LoadingPromise
	end
	
	print("ModuleDataManager: Loading module data...")
	
	-- Create a promise-like structure
	self.LoadingPromise = task.spawn(function()
		-- Load category definitions (Rojo converts JSON to ModuleScript that returns a table)
		local categorySuccess, categoryData = pcall(function()
			return require(ReplicatedStorage.Shared.data.module_categories)
		end)
		
		if categorySuccess then
			self.CategoryData = categoryData
			print("ModuleDataManager: Loaded category data")
		else
			warn("ModuleDataManager: Failed to load category data:", categoryData)
		end
		
		-- Load modules from each category (Rojo converts JSON files to ModuleScripts that return tables)
		local categories = {"habitat", "power", "science", "operations", "storage"}
		
		for _, categoryName in ipairs(categories) do
			local success, moduleData = pcall(function()
				local modulePath = ReplicatedStorage.Shared.data.modules:FindFirstChild(categoryName)
				if modulePath then
					return require(modulePath)
				else
					error("Module not found: " .. categoryName)
				end
			end)
			
			if success then
				self.ModulesByCategory[categoryName] = moduleData
				
				-- Index modules by ID
				for _, module in ipairs(moduleData) do
					self.ModulesById[module.id] = module
					module.category = categoryName -- Ensure category is set
				end
				
				print("ModuleDataManager: Loaded", #moduleData, "modules from category:", categoryName)
			else
				warn("ModuleDataManager: Failed to load modules for category:", categoryName, moduleData)
			end
		end
		
		self.IsLoaded = true
		print("ModuleDataManager: All module data loaded successfully")
		print("ModuleDataManager: Total modules loaded:", self:GetTotalModuleCount())
	end)
	
	return self.LoadingPromise
end

function ModuleDataManager:WaitForLoad()
	if self.IsLoaded then
		return
	end
	
	if self.LoadingPromise then
		-- Wait for loading to complete
		while not self.IsLoaded do
			task.wait(0.1)
		end
	else
		self:LoadModuleData()
		self:WaitForLoad()
	end
end

function ModuleDataManager:GetCategories()
	self:WaitForLoad()
	
	local categories = {}
	if self.CategoryData and self.CategoryData.categories then
		-- Sort categories by order
		local sortedCategories = {}
		for categoryId, categoryInfo in pairs(self.CategoryData.categories) do
			table.insert(sortedCategories, {
				id = categoryId,
				name = categoryInfo.name,
				description = categoryInfo.description,
				icon = categoryInfo.icon,
				color = categoryInfo.color,
				order = categoryInfo.order or 999
			})
		end
		
		table.sort(sortedCategories, function(a, b)
			return a.order < b.order
		end)
		
		return sortedCategories
	end
	
	return categories
end

function ModuleDataManager:GetModulesByCategory(categoryId)
	self:WaitForLoad()
	return self.ModulesByCategory[categoryId] or {}
end

function ModuleDataManager:GetModuleById(moduleId)
	self:WaitForLoad()
	return self.ModulesById[moduleId]
end

function ModuleDataManager:GetAllModules()
	self:WaitForLoad()
	
	local allModules = {}
	for _, modules in pairs(self.ModulesByCategory) do
		for _, module in ipairs(modules) do
			table.insert(allModules, module)
		end
	end
	
	return allModules
end

function ModuleDataManager:GetTotalModuleCount()
	local count = 0
	for _, modules in pairs(self.ModulesByCategory) do
		count = count + #modules
	end
	return count
end

function ModuleDataManager:GetUISettings()
	self:WaitForLoad()
	
	if self.CategoryData and self.CategoryData.ui_settings then
		return self.CategoryData.ui_settings
	end
	
	-- Default settings
	return {
		cards_per_row = 3,
		card_spacing = 10,
		category_transition_time = 0.3,
		back_button_text = "← Back to Categories"
	}
end

-- Validation and utility functions
function ModuleDataManager:ValidateModule(module)
	local required_fields = {"id", "name", "category", "description", "icon", "model", "dimensions", "mass", "power", "cost"}
	
	for _, field in ipairs(required_fields) do
		if module[field] == nil then
			warn("ModuleDataManager: Module", module.id or "unknown", "missing required field:", field)
			return false
		end
	end
	
	return true
end

function ModuleDataManager:GetModuleProperty(moduleId, property)
	local module = self:GetModuleById(moduleId)
	if module then
		return module[property]
	end
	return nil
end

-- Power calculations
function ModuleDataManager:CalculateTotalPower(moduleIds)
	local totalGeneration = 0
	local totalConsumption = 0
	
	for _, moduleId in ipairs(moduleIds) do
		local module = self:GetModuleById(moduleId)
		if module and module.power then
			totalGeneration = totalGeneration + (module.power.generation or 0)
			totalConsumption = totalConsumption + (module.power.consumption or 0)
		end
	end
	
	return {
		generation = totalGeneration,
		consumption = totalConsumption,
		balance = totalGeneration - totalConsumption
	}
end

-- Crew calculations
function ModuleDataManager:CalculateTotalCrew(moduleIds)
	local totalCapacity = 0
	local averageComfort = 0
	local comfortModules = 0
	
	for _, moduleId in ipairs(moduleIds) do
		local module = self:GetModuleById(moduleId)
		if module and module.crew then
			totalCapacity = totalCapacity + (module.crew.capacity or 0)
			if module.crew.comfort and module.crew.capacity > 0 then
				averageComfort = averageComfort + module.crew.comfort
				comfortModules = comfortModules + 1
			end
		end
	end
	
	if comfortModules > 0 then
		averageComfort = averageComfort / comfortModules
	end
	
	return {
		capacity = totalCapacity,
		comfort = averageComfort
	}
end

return ModuleDataManager

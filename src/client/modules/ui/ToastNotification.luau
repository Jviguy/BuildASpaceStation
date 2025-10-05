local ToastNotification = {}
ToastNotification.__index = ToastNotification

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Toast types with different colors
local TOAST_TYPES = {
	ERROR = {
		Color = Color3.fromRGB(255, 85, 85),
		Icon = "❌",
		Duration = 3,
	},
	WARNING = {
		Color = Color3.fromRGB(255, 200, 100),
		Icon = "⚠️",
		Duration = 2.5,
	},
	SUCCESS = {
		Color = Color3.fromRGB(100, 220, 140),
		Icon = "✓",
		Duration = 2,
	},
	INFO = {
		Color = Color3.fromRGB(100, 180, 255),
		Icon = "ℹ️",
		Duration = 2,
	},
}

function ToastNotification.new()
	local self = setmetatable({}, ToastNotification)

	self.ToastContainer = nil
	self.ActiveToasts = {}
	self.ToastQueue = {}
	self.IsProcessing = false

	return self
end

function ToastNotification:Initialize()
	-- Create container for toasts (top-center of screen)
	self.ToastContainer = Instance.new("ScreenGui")
	self.ToastContainer.Name = "ToastNotifications"
	self.ToastContainer.ResetOnSpawn = false
	self.ToastContainer.IgnoreGuiInset = true
	self.ToastContainer.DisplayOrder = 1000 -- High priority
	self.ToastContainer.Parent = LocalPlayer:WaitForChild("PlayerGui")

	-- Create frame to hold toasts vertically in bottom right
	local toastHolder = Instance.new("Frame")
	toastHolder.Name = "ToastHolder"
	toastHolder.Size = UDim2.fromScale(0.3, 0.4) -- 30% width, 40% height
	toastHolder.Position = UDim2.fromScale(0.68, 0.55) -- Bottom right area (68% right, 55% down)
	toastHolder.BackgroundTransparency = 1
	toastHolder.Parent = self.ToastContainer

	-- Add list layout for stacking toasts from bottom up
	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom -- Stack from bottom
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = toastHolder

	self.ToastHolder = toastHolder

	print("ToastNotification: System initialized")
end

function ToastNotification:Show(message, toastType)
	-- Add toast to queue
	table.insert(self.ToastQueue, {
		Message = message,
		Type = toastType or "INFO",
	})

	-- Process queue if not already processing
	if not self.IsProcessing then
		self:ProcessQueue()
	end
end

function ToastNotification:ProcessQueue()
	if #self.ToastQueue == 0 then
		self.IsProcessing = false
		return
	end

	self.IsProcessing = true
	local toastData = table.remove(self.ToastQueue, 1)

	-- Create and show toast
	self:CreateToast(toastData.Message, toastData.Type)

	-- Process next after a short delay
	task.delay(0.3, function()
		self:ProcessQueue()
	end)
end

function ToastNotification:CreateToast(message, toastType)
	local typeData = TOAST_TYPES[toastType] or TOAST_TYPES.INFO

	-- Limit to 3 toasts maximum - remove oldest if we exceed the limit
	local MAX_TOASTS = 3
	while #self.ActiveToasts >= MAX_TOASTS do
		local oldestToast = self.ActiveToasts[1]
		if oldestToast then
			self:DismissToast(oldestToast)
			-- Wait a moment for the dismissal to process
			task.wait(0.1)
		else
			break
		end
	end

	-- Create toast frame
	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(1, 0, 0, 60)
	toast.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
	toast.BorderSizePixel = 0
	toast.LayoutOrder = #self.ActiveToasts
	toast.Parent = self.ToastHolder

	-- Start off-screen (above)
	toast.Position = UDim2.fromScale(0, -1)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = toast

	-- Colored left border
	local border = Instance.new("Frame")
	border.Size = UDim2.new(0, 5, 1, 0)
	border.Position = UDim2.fromScale(0, 0)
	border.BackgroundColor3 = typeData.Color
	border.BorderSizePixel = 0
	border.Parent = toast

	local borderCorner = Instance.new("UICorner")
	borderCorner.CornerRadius = UDim.new(0, 10)
	borderCorner.Parent = border

	-- Icon
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(0, 40, 1, 0)
	icon.Position = UDim2.fromOffset(10, 0)
	icon.BackgroundTransparency = 1
	icon.Text = typeData.Icon
	icon.TextSize = 24
	icon.Font = Enum.Font.GothamBold
	icon.TextColor3 = typeData.Color
	icon.Parent = toast

	-- Message text
	local messageLabel = Instance.new("TextLabel")
	messageLabel.Size = UDim2.new(1, -60, 1, 0)
	messageLabel.Position = UDim2.fromOffset(50, 0)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Text = message
	messageLabel.TextSize = 14
	messageLabel.Font = Enum.Font.Gotham
	messageLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.TextWrapped = true
	messageLabel.Parent = toast

	-- Add shadow effect
	local shadow = Instance.new("ImageLabel")
	shadow.Size = UDim2.new(1, 10, 1, 10)
	shadow.Position = UDim2.fromOffset(-5, -5)
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
	shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
	shadow.ImageTransparency = 0.7
	shadow.ZIndex = toast.ZIndex - 1
	shadow.Parent = toast

	-- Animate in
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local slideIn = TweenService:Create(toast, tweenInfo, {
		Position = UDim2.fromScale(0, 0),
	})
	slideIn:Play()

	-- Track active toast
	table.insert(self.ActiveToasts, toast)

	-- Auto-dismiss after duration
	task.delay(typeData.Duration, function()
		self:DismissToast(toast)
	end)
end

function ToastNotification:DismissToast(toast)
	if not toast or not toast.Parent then
		return
	end

	-- Fade out animation
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local fadeOut = TweenService:Create(toast, tweenInfo, {
		BackgroundTransparency = 1,
	})

	-- Fade all children with appropriate properties
	for _, child in ipairs(toast:GetDescendants()) do
		if child:IsA("GuiObject") then
			local tweenProperties = {}

			-- Only set properties that exist on this object
			if child:IsA("TextLabel") or child:IsA("TextButton") then
				tweenProperties.BackgroundTransparency = 1
				tweenProperties.TextTransparency = 1
				tweenProperties.TextStrokeTransparency = 1
			elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
				tweenProperties.BackgroundTransparency = 1
				tweenProperties.ImageTransparency = 1
			elseif child:IsA("Frame") then
				tweenProperties.BackgroundTransparency = 1
			end

			-- Only create tween if we have properties to animate
			if next(tweenProperties) then
				local childTween = TweenService:Create(child, tweenInfo, tweenProperties)
				childTween:Play()
			end
		end
	end

	fadeOut:Play()
	fadeOut.Completed:Connect(function()
		-- Remove from active toasts
		for i, activeToast in ipairs(self.ActiveToasts) do
			if activeToast == toast then
				table.remove(self.ActiveToasts, i)
				break
			end
		end

		toast:Destroy()
	end)
end

-- Convenience methods
function ToastNotification:Error(message)
	self:Show(message, "ERROR")
end

function ToastNotification:Warning(message)
	self:Show(message, "WARNING")
end

function ToastNotification:Success(message)
	self:Show(message, "SUCCESS")
end

function ToastNotification:Info(message)
	self:Show(message, "INFO")
end

function ToastNotification:Destroy()
	if self.ToastContainer then
		self.ToastContainer:Destroy()
		self.ToastContainer = nil
	end
	self.ActiveToasts = {}
	self.ToastQueue = {}
end

return ToastNotification

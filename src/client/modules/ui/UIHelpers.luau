-- UI Helper functions for consistent styling across all UIs
local UIHelpers = {}

-- Create a rounded button with modern styling
function UIHelpers.CreateRoundedButton(config)
    local button = Instance.new("TextButton")
    button.Size = config.Size or UDim2.new(0.3, 0, 0.7, 0)
    button.Position = config.Position or UDim2.new(0, 0, 0, 0)
    button.BackgroundColor3 = config.BackgroundColor or Color3.fromRGB(100, 150, 255)
    button.BorderSizePixel = 0
    button.Text = config.Text or "Button"
    button.TextColor3 = config.TextColor or Color3.fromRGB(255, 255, 255)
    button.TextScaled = false
    button.TextSize = config.TextSize or 20
    button.Font = config.Font or Enum.Font.SourceSansBold
    button.AutoButtonColor = false
    button.ZIndex = config.ZIndex or 4
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, config.CornerRadius or 8)
    corner.Parent = button
    
    -- Add subtle shadow/border
    local stroke = Instance.new("UIStroke")
    stroke.Color = config.StrokeColor or Color3.fromRGB(80, 120, 200)
    stroke.Thickness = 2
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = button
    
    -- Hover effects
    local originalBg = button.BackgroundColor3
    local originalStroke = stroke.Color
    local hoverBg = config.HoverColor or Color3.fromRGB(120, 170, 255)
    local hoverStroke = config.HoverStrokeColor or Color3.fromRGB(140, 180, 255)
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = hoverBg
        stroke.Color = hoverStroke
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = originalBg
        stroke.Color = originalStroke
    end)
    
    return button
end

-- Create a rounded frame/panel
function UIHelpers.CreateRoundedFrame(config)
    local frame = Instance.new("Frame")
    frame.Size = config.Size or UDim2.new(0.5, 0, 0.5, 0)
    frame.Position = config.Position or UDim2.new(0, 0, 0, 0)
    frame.BackgroundColor3 = config.BackgroundColor or Color3.fromRGB(30, 30, 50)
    frame.BorderSizePixel = 0
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, config.CornerRadius or 12)
    corner.Parent = frame
    
    -- Optional stroke
    if config.Stroke then
        local stroke = Instance.new("UIStroke")
        stroke.Color = config.StrokeColor or Color3.fromRGB(80, 80, 120)
        stroke.Thickness = config.StrokeThickness or 2
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = frame
    end
    
    return frame
end

-- Create a modern text label
function UIHelpers.CreateLabel(config)
    local label = Instance.new("TextLabel")
    label.Size = config.Size or UDim2.new(1, 0, 0.1, 0)
    label.Position = config.Position or UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = config.BackgroundTransparency or 1
    label.Text = config.Text or ""
    label.TextColor3 = config.TextColor or Color3.fromRGB(255, 255, 255)
    label.TextScaled = false
    label.TextSize = config.TextSize or 20
    label.Font = config.Font or Enum.Font.SourceSans
    label.TextXAlignment = config.TextXAlignment or Enum.TextXAlignment.Center
    label.TextYAlignment = config.TextYAlignment or Enum.TextYAlignment.Center
    label.TextWrapped = config.TextWrapped or false
    
    return label
end

-- Create a modern text input
function UIHelpers.CreateInput(config)
    local input = Instance.new("TextBox")
    input.Size = config.Size or UDim2.new(0.5, 0, 0.1, 0)
    input.Position = config.Position or UDim2.new(0, 0, 0, 0)
    input.BackgroundColor3 = config.BackgroundColor or Color3.fromRGB(40, 40, 60)
    input.BorderSizePixel = 0
    input.Text = config.Text or ""
    input.PlaceholderText = config.PlaceholderText or ""
    input.TextColor3 = config.TextColor or Color3.fromRGB(255, 255, 255)
    input.PlaceholderColor3 = Color3.fromRGB(150, 150, 170)
    input.TextScaled = false
    input.TextSize = config.TextSize or 18
    input.Font = config.Font or Enum.Font.SourceSans
    input.ClearTextOnFocus = false
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, config.CornerRadius or 6)
    corner.Parent = input
    
    -- Add stroke
    local stroke = Instance.new("UIStroke")
    stroke.Color = config.StrokeColor or Color3.fromRGB(80, 80, 120)
    stroke.Thickness = 2
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = input
    
    -- Focus effects
    input.Focused:Connect(function()
        stroke.Color = Color3.fromRGB(100, 150, 255)
        stroke.Thickness = 3
    end)
    
    input.FocusLost:Connect(function()
        stroke.Color = config.StrokeColor or Color3.fromRGB(80, 80, 120)
        stroke.Thickness = 2
    end)
    
    return input
end

-- Create a gradient background (NASA style)
function UIHelpers.CreateGradientBackground(parent, topColor, bottomColor)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, topColor or Color3.fromRGB(10, 15, 35)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 20, 45)),
        ColorSequenceKeypoint.new(1, bottomColor or Color3.fromRGB(8, 12, 28))
    })
    gradient.Rotation = 90
    gradient.Parent = parent
    return gradient
end

-- Add shadow effect to element
function UIHelpers.AddShadow(element)
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.new(0, -10, 0, -10)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxasset://textures/ui/Shadow.png"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.5
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(10, 10, 118, 118)
    shadow.ZIndex = element.ZIndex - 1
    shadow.Parent = element.Parent
    
    -- Ensure element is above shadow
    element.ZIndex = element.ZIndex or 1
    
    return shadow
end

-- Create NASA-style header with gradient
function UIHelpers.CreateNASAHeader(config)
    local header = Instance.new("Frame")
    header.Size = config.Size or UDim2.new(1, 0, 0.15, 0)
    header.Position = config.Position or UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Color3.fromRGB(20, 30, 60)
    header.BorderSizePixel = 0
    
    -- Add gradient
    UIHelpers.CreateGradientBackground(header, Color3.fromRGB(25, 35, 70), Color3.fromRGB(15, 25, 50))
    
    -- Add bottom border stripe (NASA style)
    local stripe = Instance.new("Frame")
    stripe.Size = UDim2.new(1, 0, 0, 3)
    stripe.Position = UDim2.new(0, 0, 1, -3)
    stripe.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
    stripe.BorderSizePixel = 0
    stripe.Parent = header
    
    -- Add gradient to stripe
    local stripeGradient = Instance.new("UIGradient")
    stripeGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 110, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 150, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 110, 255))
    })
    stripeGradient.Parent = stripe
    
    return header
end

-- Color palette for consistent theming (NASA inspired)
UIHelpers.Colors = {
    Background = Color3.fromRGB(10, 15, 35),
    BackgroundAlt = Color3.fromRGB(8, 12, 28),
    Panel = Color3.fromRGB(20, 28, 50),
    PanelDark = Color3.fromRGB(15, 22, 42),
    Header = Color3.fromRGB(25, 35, 70),
    Accent = Color3.fromRGB(100, 150, 255),
    AccentBright = Color3.fromRGB(120, 170, 255),
    Success = Color3.fromRGB(80, 180, 120),
    Warning = Color3.fromRGB(255, 180, 80),
    Danger = Color3.fromRGB(220, 80, 80),
    Text = Color3.fromRGB(255, 255, 255),
    TextDim = Color3.fromRGB(180, 190, 210),
    Border = Color3.fromRGB(60, 80, 140),
    BorderBright = Color3.fromRGB(100, 150, 255),
}

return UIHelpers


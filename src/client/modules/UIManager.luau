local UIManager = {}
UIManager.__index = UIManager

-- Services (TweenService reserved for future animations)
local TweenService = game:GetService("TweenService")

function UIManager.new(gameState)
    local self = setmetatable({}, UIManager)

    -- Game state reference
    self.GameState = gameState

    -- UI registry: state -> {gui: GuiObject, showFunction: function, hideFunction: function}
    self.UIComponents = {}

    -- Currently active UI
    self.ActiveUI = nil

    -- Transition effects
    self.FadeTime = 0.3

    return self
end

function UIManager:Initialize()
    -- Listen to game state changes
    self.GameState:AddStateChangeListener(function(oldState, newState)
        self:OnStateChanged(oldState, newState)
    end)

    print("UIManager: Initialized and listening to game state changes")
end

function UIManager:RegisterUI(state, guiObject, showFunction, hideFunction)
    -- Validate inputs
    if not guiObject then
        warn("UIManager: guiObject is nil for state " .. state)
        return
    end

    -- Check if object has IsA method
    local hasIsA = type(guiObject) == "userdata" and guiObject.IsA ~= nil
    if not hasIsA then
        warn("UIManager: guiObject does not have IsA method for state " .. state .. " (type: " .. type(guiObject) .. ")")
        return
    end

    -- Accept both GuiObject and LayerCollector (ScreenGui inherits from LayerCollector)
    if not (guiObject:IsA("GuiObject") or guiObject:IsA("LayerCollector")) then
        warn("UIManager: Invalid GUI object for state " .. state .. " - not a GuiObject or LayerCollector (ClassName: " .. guiObject.ClassName .. ")")
        return
    end

    -- Store UI component
    self.UIComponents[state] = {
        gui = guiObject,
        show = showFunction or function(gui) gui.Visible = true end,
        hide = hideFunction or function(gui) gui.Visible = false end
    }

    print("UIManager: Registered UI for state: " .. state)
end

function UIManager:UnregisterUI(state)
    if self.UIComponents[state] then
        -- Hide if currently active
        if self.ActiveUI == state then
            self:HideUI(state)
        end

        self.UIComponents[state] = nil
        print("UIManager: Unregistered UI for state: " .. state)
    end
end

function UIManager:OnStateChanged(oldState, newState)
    print("UIManager: State changed from " .. (oldState or "nil") .. " to " .. (newState or "nil"))

    -- Hide old UI
    if oldState and self.UIComponents[oldState] then
        print("UIManager: Hiding UI for state: " .. oldState)
        self:HideUI(oldState)
    end

    -- Show new UI
    if newState and self.UIComponents[newState] then
        print("UIManager: Showing UI for state: " .. newState)
        self:ShowUI(newState)
    else
        print("UIManager: No UI registered for state: " .. (newState or "nil"))
    end
end

function UIManager:ShowUI(state)
    local uiComponent = self.UIComponents[state]
    if not uiComponent then
        print("UIManager: No UI component found for state: " .. state)
        return
    end

    print("UIManager: Found UI component for state: " .. state)

    -- Hide currently active UI first
    if self.ActiveUI and self.ActiveUI ~= state then
        print("UIManager: Hiding previous UI: " .. self.ActiveUI)
        self:HideUI(self.ActiveUI)
    end

    -- Show the new UI
    self.ActiveUI = state

    -- Use custom show function or default
    print("UIManager: Calling show function for state: " .. state)
    uiComponent.show(uiComponent.gui)

    print("UIManager: UI shown for state: " .. state)
end

function UIManager:HideUI(state)
    local uiComponent = self.UIComponents[state]
    if not uiComponent then return end

    -- Use custom hide function or default
    uiComponent.hide(uiComponent.gui)

    if self.ActiveUI == state then
        self.ActiveUI = nil
    end

    print("UIManager: Hiding UI for state: " .. state)
end

function UIManager:GetActiveUI()
    return self.ActiveUI
end

function UIManager:GetUIForState(state)
    return self.UIComponents[state]
end

function UIManager:ForceShowUI(state)
    if self.UIComponents[state] then
        self:ShowUI(state)
    end
end

function UIManager:ForceHideUI(state)
    if self.UIComponents[state] then
        self:HideUI(state)
    end
end

-- Utility function to create fade transition
function UIManager:CreateFadeTransition(guiObject, targetTransparency)
    if not guiObject then return end

    local tweenInfo = TweenInfo.new(self.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(guiObject, tweenInfo, {BackgroundTransparency = targetTransparency})

    return tween
end

return UIManager

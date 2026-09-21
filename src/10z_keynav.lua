-- ============================================================
-- Module: 10z_keynav.lua
-- ============================================================
--[[
    Keyboard navigation.

    Controls:
      Tab          - focus next interactive element in active tab
      Shift+Tab    - focus previous
      Up/Down      - move focus (same as Tab/Shift+Tab)
      Left/Right   - adjust focused slider, cycle dropdown/radio
      Space        - toggle focused toggle / checkbox
      Enter        - activate focused element (varies by kind)
      Escape       - blur current focus
      Ctrl+F       - (falls through to Settings Search if open)

    Focus indicator is a UIStroke on the element's Instance. Fades
    in over 120ms, out over 80ms. Accent-colored, thickness 2,
    slightly outside the element with ApplyStrokeMode.Border.

    Element kinds are detected by wrapping Section:Create* methods
    and tagging each returned obj with `_kbKind`. Metadata like
    slider increment and dropdown options are passed through the
    same wrapper.

    Focusable kinds:
      toggle, checkbox, slider, button, dropdown, radio

    Skip-on-blur: any element whose Instance or any ancestor is
    invisible. Elements in other tabs are ignored.

    Opt-out per window:
        CreateWindow({ KeyboardNav = false })

    Default is ON for every window.
]]

do

if not LucidUI or not LucidUI.Window then return end

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local FOCUS_THICKNESS  = 2
local FOCUS_FADE_IN    = 0.12
local FOCUS_FADE_OUT   = 0.08

-- ------------------------------------------------------------
-- Kind wrappers — tag each element as it comes out of a builder
-- ------------------------------------------------------------
local function tag(obj, kind, meta)
    if type(obj) ~= "table" or not obj.Instance then return obj end
    obj._kbKind = kind
    if meta then
        for k, v in pairs(meta) do
            obj["_kb" .. k] = v
        end
    end
    return obj
end

local _origToggle = LucidUI.Section.CreateToggle
function LucidUI.Section:CreateToggle(config)
    return tag(_origToggle(self, config), "toggle")
end

local _origCheckbox = LucidUI.Section.CreateCheckbox
function LucidUI.Section:CreateCheckbox(config)
    return tag(_origCheckbox(self, config), "checkbox")
end

local _origSlider = LucidUI.Section.CreateSlider
function LucidUI.Section:CreateSlider(config)
    local obj = _origSlider(self, config)
    return tag(obj, "slider", {
        Increment = (config and config.Increment) or 1,
        Range     = (config and config.Range) or { 0, 100 },
    })
end

local _origButton = LucidUI.Section.CreateButton
function LucidUI.Section:CreateButton(config)
    local obj = _origButton(self, config)
    return tag(obj, "button", {
        Callback = config and config.Callback,
    })
end

local _origDropdown = LucidUI.Section.CreateDropdown
function LucidUI.Section:CreateDropdown(config)
    local obj = _origDropdown(self, config)
    return tag(obj, "dropdown", {
        Options  = (config and config.Options) or {},
        Callback = config and config.Callback,
    })
end

local _origRadio = LucidUI.Section.CreateRadio
function LucidUI.Section:CreateRadio(config)
    local obj = _origRadio(self, config)
    return tag(obj, "radio", {
        Options  = (config and config.Options) or {},
        Callback = config and config.Callback,
    })
end

-- ------------------------------------------------------------
-- Focus management
-- ------------------------------------------------------------
local function isVisible(inst)
    local p = inst
    while p and p ~= game do
        if p:IsA("GuiObject") and not p.Visible then return false end
        p = p.Parent
    end
    return true
end

local function isInActiveTab(W, obj)
    local tab = W.ActiveTab
    if not tab or not tab.Page then return false end
    local p = obj.Instance
    while p do
        if p == tab.Page then return true end
        p = p.Parent
    end
    return false
end

local function collectFocusable(W)
    local list = {}
    for _, obj in pairs(W._elementsByFlag or {}) do
        if obj and obj._kbKind and obj.Instance and obj.Instance.Parent then
            if isVisible(obj.Instance) and isInActiveTab(W, obj) then
                table.insert(list, obj)
            end
        end
    end
    table.sort(list, function(a, b)
        local ay = a.Instance.AbsolutePosition.Y
        local by = b.Instance.AbsolutePosition.Y
        if math.abs(ay - by) > 4 then return ay < by end
        return a.Instance.AbsolutePosition.X < b.Instance.AbsolutePosition.X
    end)
    return list
end

local function findIndex(list, target)
    for i, obj in ipairs(list) do
        if obj == target then return i end
    end
    return nil
end

local function applyFocus(W, obj)
    if W._kbFocus == obj then return end

    if W._kbFocusStroke and W._kbFocusStroke.Parent then
        local s = W._kbFocusStroke
        TweenService:Create(s, TweenInfo.new(FOCUS_FADE_OUT), { Transparency = 1 }):Play()
        task.delay(FOCUS_FADE_OUT + 0.02, function()
            if s and s.Parent and (not W._kbFocus or W._kbFocusStroke ~= s) then
                pcall(function() s:Destroy() end)
            end
        end)
    end

    W._kbFocus = obj
    W._kbFocusStroke = nil

    if not obj or not obj.Instance or not obj.Instance.Parent then return end

    local theme = W.Theme or LucidUI.Themes.Default
    local stroke = Instance.new("UIStroke")
    stroke.Name               = "LucidKeyboardFocus"
    stroke.Color              = theme.Accent
    stroke.Thickness          = FOCUS_THICKNESS
    stroke.Transparency       = 1
    stroke.ApplyStrokeMode    = Enum.ApplyStrokeMode.Border
    stroke.LineJoinMode       = Enum.LineJoinMode.Round
    stroke.Parent             = obj.Instance

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = stroke

    W._kbFocusStroke = stroke

    TweenService:Create(stroke, TweenInfo.new(FOCUS_FADE_IN), { Transparency = 0 }):Play()
end

local function cycleFocus(W, direction)
    local list = collectFocusable(W)
    if #list == 0 then return end

    local idx = findIndex(list, W._kbFocus)
    local nextIdx
    if not idx then
        nextIdx = direction > 0 and 1 or #list
    else
        nextIdx = ((idx - 1 + direction) % #list) + 1
    end

    applyFocus(W, list[nextIdx])
end

local function resetFocusOn(W)
    if W._kbFocusStroke and W._kbFocusStroke.Parent then
        pcall(function() W._kbFocusStroke:Destroy() end)
    end
    W._kbFocus = nil
    W._kbFocusStroke = nil
end

-- ------------------------------------------------------------
-- Activation
-- ------------------------------------------------------------
local function activateToggle(obj)
    if not obj or type(obj.Get) ~= "function" or type(obj.Set) ~= "function" then return end
    local ok, current = pcall(function() return obj:Get() end)
    if not ok then return end
    pcall(function() obj:Set(not current) end)
end

local function adjustSlider(obj, direction)
    if not obj or type(obj.Get) ~= "function" or type(obj.Set) ~= "function" then return end

    local cur = obj:Get()
    local inc = obj._kbIncrement or 1
    local rng = obj._kbRange or { 0, 100 }
    local new = cur + direction * inc
    new = math.clamp(new, rng[1], rng[2])
    pcall(function() obj:Set(new) end)
end

local function fireButton(obj)
    if not obj then return end
    if type(obj._kbCallback) == "function" then
        pcall(obj._kbCallback)
    end
end

local function cycleChoice(obj, direction)
    if not obj or type(obj.Get) ~= "function" or type(obj.Set) ~= "function" then return end
    local options = obj._kbOptions
    if type(options) ~= "table" or #options == 0 then return end

    local cur = obj:Get()
    local idx
    for i, v in ipairs(options) do
        if v == cur then idx = i break end
    end
    if not idx then idx = 1 end
    local nextIdx = ((idx - 1 + direction) % #options) + 1
    local nextVal = options[nextIdx]

    pcall(function() obj:Set(nextVal) end)
    if type(obj._kbCallback) == "function" then
        pcall(obj._kbCallback, nextVal)
    end
end

-- ------------------------------------------------------------
-- Input
-- ------------------------------------------------------------
local function activeFocusedWindow()
    for _, W in ipairs(LucidUI._windows or {}) do
        if W.Gui and W.Gui.Parent and W.Gui.Enabled and W._kbFocus then
            return W
        end
    end
    -- If nothing is focused yet, return the first visible window
    for _, W in ipairs(LucidUI._windows or {}) do
        if W.Gui and W.Gui.Parent and W.Gui.Enabled
           and not W.Minimized and not W.Floating and not W.SettingsOpen then
            return W
        end
    end
    return nil
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if LucidUI._keyListening then return end

    local kc = input.KeyCode

    if kc == Enum.KeyCode.Tab then
        local W = activeFocusedWindow()
        if not W then return end
        if W.SettingsOpen or W.Minimized or W.Floating then return end
        local dir = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
                 or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
                 and -1 or 1
        cycleFocus(W, dir)
        return
    end

    if kc == Enum.KeyCode.Escape then
        local W = activeFocusedWindow()
        if W then resetFocusOn(W) end
        return
    end

    local W = activeFocusedWindow()
    if not W or not W._kbFocus then return end

    local obj = W._kbFocus

    if kc == Enum.KeyCode.Up then
        if obj._kbKind == "slider" then
            adjustSlider(obj, 1)
        else
            cycleFocus(W, -1)
        end
    elseif kc == Enum.KeyCode.Down then
        if obj._kbKind == "slider" then
            adjustSlider(obj, -1)
        else
            cycleFocus(W, 1)
        end
    elseif kc == Enum.KeyCode.Left then
        if obj._kbKind == "slider" then
            adjustSlider(obj, -1)
        elseif obj._kbKind == "dropdown" or obj._kbKind == "radio" then
            cycleChoice(obj, -1)
        end
    elseif kc == Enum.KeyCode.Right then
        if obj._kbKind == "slider" then
            adjustSlider(obj, 1)
        elseif obj._kbKind == "dropdown" or obj._kbKind == "radio" then
            cycleChoice(obj, 1)
        end
    elseif kc == Enum.KeyCode.Space then
        if obj._kbKind == "toggle" or obj._kbKind == "checkbox" then
            activateToggle(obj)
        end
    elseif kc == Enum.KeyCode.Return or kc == Enum.KeyCode.KeypadEnter then
        if obj._kbKind == "toggle" or obj._kbKind == "checkbox" then
            activateToggle(obj)
        elseif obj._kbKind == "button" then
            fireButton(obj)
        elseif obj._kbKind == "dropdown" or obj._kbKind == "radio" then
            cycleChoice(obj, 1)
        end
    end
end)

-- ------------------------------------------------------------
-- Reset focus on tab switch / window state change
-- ------------------------------------------------------------
local _origSelectTab = LucidUI.Window.SelectTab
function LucidUI.Window:SelectTab(tab)
    _origSelectTab(self, tab)
    resetFocusOn(self)
end

local _origToggleSettings = LucidUI.Window.ToggleSettings
function LucidUI.Window:ToggleSettings(state)
    _origToggleSettings(self, state)
    resetFocusOn(self)
end

-- ------------------------------------------------------------
-- Theme: retint the focus ring live
-- ------------------------------------------------------------
LucidUI:OnCleanup(function()
    for _, W in ipairs(LucidUI._windows or {}) do
        resetFocusOn(W)
    end
    print("[LucidUI] KeyNav cleaned up")
end)

end

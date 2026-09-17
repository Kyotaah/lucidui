--[[
    Dev Mode — developer tooling overlay.

    When enabled:
      • Every element gets a hover outline (magenta = has flag, cyan = no flag)
      • Tooltip shows the element's flag + current value
      • Live HUD in the top-left corner: FPS, element count, error count
      • Right-click any element to copy its flag to the clipboard

    Off by default. Toggle via settings or:
        LucidUI:SetDevMode(true)
        LucidUI:SetDevMode(false)
        LucidUI:IsDevMode()

    The HUD is a separate ScreenGui so it survives window minimize/close.
]]

-- ============================================================
-- State
-- ============================================================
local DevMode = {
    enabled      = false,
    hudGui       = nil,
    hudFrame     = nil,
    hudLabels    = {},
    trackedFrames = {},   -- { frame = frame, flag = flag, kind = "Button" }
    hoverOutline = nil,
    hoverTooltip = nil,
    hoverConn    = nil,
    rightClickConn = nil,
    updateLoop   = nil,
    fpsBuffer    = {},
    frameCount   = 0,
    lastHudTick  = 0,
}

LucidUI._devMode = DevMode

-- ============================================================
-- Helpers
-- ============================================================
local function safeGetCurrentFlag(frame)
    -- Walk up the parent tree to find the wrapping element
    local current = frame
    local depth = 0
    while current and depth < 10 do
        for entry, flag in pairs(DevMode.flagLookup or {}) do
            if entry == current then return flag end
        end
        current = current.Parent
        depth = depth + 1
    end
    return nil
end

-- ============================================================
-- Element tracking — hook Section._track
-- ============================================================
local _origTrack = LucidUI.Section._track
function LucidUI.Section:_track(frame)
    local result = _origTrack(self, frame)

    if result and DevMode.enabled then
        -- Find the flag from the window's reverse lookup
        local win = self.Tab and self.Tab.Window
        local flag = nil
        if win then
            for f, obj in pairs(win._elementsByFlag or {}) do
                if obj.Instance == frame then
                    flag = f
                    break
                end
            end
        end
        table.insert(DevMode.trackedFrames, {
            frame = frame,
            flag  = flag,
            kind  = frame.ClassName,
        })
    end

    return result
end

-- ============================================================
-- Hover outline
-- ============================================================
local function ensureHoverOutline()
    if DevMode.hoverOutline and DevMode.hoverOutline.Parent then
        return DevMode.hoverOutline
    end
    local gui = DevMode.hudGui
    if not gui then return nil end

    local outline = Instance.new("Frame")
    outline.Name = "DevHoverOutline"
    outline.BackgroundTransparency = 1
    outline.BorderSizePixel = 0
    outline.ZIndex = 1000
    outline.Visible = false
    outline.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = outline

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 0, 180)
    stroke.Thickness = 2
    stroke.Transparency = 0
    stroke.Parent = outline

    DevMode.hoverOutline = outline
    return outline
end

local function ensureHoverTooltip()
    if DevMode.hoverTooltip and DevMode.hoverTooltip.Parent then
        return DevMode.hoverTooltip
    end
    local gui = DevMode.hudGui
    if not gui then return nil end

    local tip = Instance.new("Frame")
    tip.Name = "DevHoverTooltip"
    tip.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    tip.BackgroundTransparency = 0.1
    tip.BorderSizePixel = 0
    tip.Size = UDim2.fromOffset(0, 22)
    tip.AutomaticSize = Enum.AutomaticSize.X
    tip.ZIndex = 1001
    tip.Visible = false
    tip.Parent = gui

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = tip

    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(255, 0, 180)
    s.Thickness = 1
    s.Parent = tip

    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.Text = ""
    label.Font = Enum.Font.Code
    label.TextSize = 11
    label.TextColor3 = Color3.fromRGB(255, 200, 230)
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0, 0, 1, 0)
    label.AutomaticSize = Enum.AutomaticSize.X
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = tip

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = label

    DevMode.hoverTooltip = tip
    return tip
end

local function onElementEnter(entry)
    if not DevMode.enabled then return end

    local frame = entry.frame
    if not frame or not frame.Parent then return end

    local outline = ensureHoverOutline()
    local tooltip = ensureHoverTooltip()
    if not outline or not tooltip then return end

    local abs = frame.AbsolutePosition
    local size = frame.AbsoluteSize

    outline.Position = UDim2.fromOffset(abs.X, abs.Y)
    outline.Size = UDim2.fromOffset(size.X, size.Y)
    outline.Visible = true

    -- Color depends on whether the element has a flag
    for _, child in ipairs(outline:GetChildren()) do
        if child:IsA("UIStroke") then
            child.Color = entry.flag and Color3.fromRGB(255, 0, 180)
                                 or Color3.fromRGB(80, 220, 255)
        end
    end

    -- Build tooltip text
    local label = tooltip:FindFirstChild("Text")
    if label then
        if entry.flag then
            label.Text = entry.kind .. "  |  flag: " .. entry.flag
        else
            label.Text = entry.kind .. "  |  (no flag)"
        end
        label.TextColor3 = entry.flag and Color3.fromRGB(255, 200, 230)
                                        or Color3.fromRGB(150, 220, 255)
    end

    tooltip.Position = UDim2.fromOffset(abs.X, abs.Y - 28)
    tooltip.Visible = true
end

local function onElementLeave()
    if DevMode.hoverOutline then
        DevMode.hoverOutline.Visible = false
    end
    if DevMode.hoverTooltip then
        DevMode.hoverTooltip.Visible = false
    end
end

-- ============================================================
-- HUD
-- ============================================================
local function buildHud()
    if DevMode.hudGui and DevMode.hudGui.Parent then
        DevMode.hudGui:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "LucidUI_DevHud"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 900
    gui.Parent = PlayerGui

    local frame = Instance.new("Frame")
    frame.Name = "Hud"
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Size = UDim2.fromOffset(180, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.Position = UDim2.fromOffset(16, 16)
    frame.Parent = gui

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 10)
    c.Parent = frame

    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(255, 0, 180)
    s.Thickness = 1
    s.Transparency = 0.4
    s.Parent = frame

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = frame

    local function addLine(text, order)
        local lbl = Instance.new("TextLabel")
        lbl.Text = text
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 12
        lbl.TextColor3 = Color3.fromRGB(255, 200, 230)
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(1, 0, 0, 16)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.LayoutOrder = order
        lbl.Parent = frame
        return lbl
    end

    DevMode.hudFrame = frame
    DevMode.hudGui   = gui
    DevMode.hudLabels.fps       = addLine("FPS: --",       1)
    DevMode.hudLabels.elements  = addLine("Elements: 0",   2)
    DevMode.hudLabels.errors    = addLine("Errors: 0",     3)
    DevMode.hudLabels.theme     = addLine("Theme: --",     4)
    DevMode.hudLabels.windows   = addLine("Windows: 0",    5)

    return gui
end

local function updateHud()
    if not DevMode.enabled then return end
    if not DevMode.hudFrame or not DevMode.hudFrame.Parent then
        buildHud()
    end

    local now = tick()
    DevMode.frameCount = DevMode.frameCount + 1
    if now - DevMode.lastHudTick >= 0.5 then
        local fps = math.floor(DevMode.frameCount / (now - DevMode.lastHudTick) + 0.5)
        DevMode.frameCount = 0
        DevMode.lastHudTick = now

        local elementCount = 0
        for _, win in ipairs(LucidUI._windows or {}) do
            for _ in pairs(win._elementsByFlag or {}) do
                elementCount = elementCount + 1
            end
        end

        local themeName = "unknown"
        local firstWin = LucidUI._windows and LucidUI._windows[1]
        if firstWin then
            themeName = firstWin.ThemeName or "Default"
        end

        local L = DevMode.hudLabels
        if L.fps then      L.fps.Text      = "FPS: "      .. fps end
        if L.elements then L.elements.Text = "Elements: " .. elementCount end
        if L.errors then   L.errors.Text   = "Errors: "   .. (LucidUI._errorCount or 0) end
        if L.theme then    L.theme.Text    = "Theme: "    .. themeName end
        if L.windows then  L.windows.Text  = "Windows: "  .. #(LucidUI._windows or {}) end
    end
end

-- ============================================================
-- Track-and-connect helper
-- ============================================================
local function connectToFrame(entry)
    local frame = entry.frame
    if not frame or not frame.Parent then return end
    if entry.connected then return end
    entry.connected = true

    frame.MouseEnter:Connect(function()
        if DevMode.enabled then onElementEnter(entry) end
    end)
    frame.MouseLeave:Connect(function()
        if DevMode.enabled then onElementLeave() end
    end)
end

-- ============================================================
-- Enable / disable
-- ============================================================
local function enableDevMode()
    if DevMode.enabled then return end
    DevMode.enabled = true

    buildHud()

    -- Track all existing tracked frames
    for _, entry in ipairs(DevMode.trackedFrames) do
        connectToFrame(entry)
    end

    DevMode.lastHudTick = tick()
    DevMode.updateLoop = task.spawn(function()
        while DevMode.enabled do
            task.wait(0.03)
            pcall(updateHud)
        end
    end)

    -- Right-click to copy flag
    DevMode.rightClickConn = UserInputService.InputBegan:Connect(function(input)
        if not DevMode.enabled then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
        local mouse = LocalPlayer:GetMouse()
        local target = mouse.Target
        -- Simplified: just copy the flag of the element under the outline
        if DevMode.hoverTooltip and DevMode.hoverTooltip.Visible then
            local label = DevMode.hoverTooltip:FindFirstChild("Text")
            if label and label.Text:find("flag:") then
                local flag = label.Text:match("flag: (%S+)")
                if flag and type(setclipboard) == "function" then
                    pcall(setclipboard, flag)
                    LucidUI:Notify({
                        Title = "Copied",
                        Message = "Flag: " .. flag,
                        Variant = "success",
                        Duration = 2,
                    })
                end
            end
        end
    end)
end

local function disableDevMode()
    if not DevMode.enabled then return end
    DevMode.enabled = false

    if DevMode.hoverOutline then DevMode.hoverOutline.Visible = false end
    if DevMode.hoverTooltip then DevMode.hoverTooltip.Visible = false end
    if DevMode.hudGui and DevMode.hudGui.Parent then
        DevMode.hudGui:Destroy()
    end
    DevMode.hudGui = nil
    DevMode.hudFrame = nil
    DevMode.hudLabels = {}

    if DevMode.rightClickConn then
        DevMode.rightClickConn:Disconnect()
        DevMode.rightClickConn = nil
    end

    DevMode.updateLoop = nil
end

-- ============================================================
-- Public API
-- ============================================================
function LucidUI:SetDevMode(enabled)
    if enabled then enableDevMode() else disableDevMode() end
end

function LucidUI:IsDevMode()
    return DevMode.enabled
end

function LucidUI:GetDevModeState()
    return DevMode
end

-- ============================================================
-- Settings UI
-- ============================================================
function LucidUI.Window:_buildDevSettings()
    self:_addSettingSection("Developer")

    local row = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 44),
    })
    Corner(10, row)
    self:_addSettingFrame(row)

    local label = Create("TextLabel", {
        Text = "Dev Mode",
        Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 4),
        Size = UDim2.new(1, -100, 0, 18),
        Parent = row,
    })

    local subLabel = Create("TextLabel", {
        Text = "Hover outlines, flag tooltips, live HUD",
        Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = self.Theme.TextMuted, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 22),
        Size = UDim2.new(1, -100, 0, 14),
        Parent = row,
    })

    local isOn = DevMode.enabled
    local track = Create("Frame", {
        Size = UDim2.fromOffset(44, 24),
        Position = UDim2.new(1, -58, 0.5, -12),
        BackgroundColor3 = isOn and self.Theme.Accent or self.Theme.ToggleOff,
        BorderSizePixel = 0, Parent = row,
    })
    Corner(12, track)

    local knob = Create("Frame", {
        Size = UDim2.fromOffset(20, 20),
        Position = isOn and UDim2.new(1, -22, 0.5, -10) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0, Parent = track,
    })
    Corner(10, knob)

    local clickArea = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = row,
    })

    BindTap(clickArea, function()
        PlayUISound("click")
        local on = not DevMode.enabled
        LucidUI:SetDevMode(on)
        local t = self.Theme
        Tween(track, 0.22, {
            BackgroundColor3 = on and t.Accent or t.ToggleOff,
        }, Enum.EasingStyle.Quart):Play()
        Tween(knob, 0.22, {
            Position = on and UDim2.new(1, -22, 0.5, -10) or UDim2.fromOffset(2, 2),
        }, Enum.EasingStyle.Quart):Play()

        LucidUI:Notify({
            Title = "Dev Mode",
            Message = on and "Enabled" or "Disabled",
            Variant = on and "success" or "info",
            Duration = 2,
        })
    end)

    self:_registerTheme(function(t)
        row.BackgroundColor3 = t.Surface
        label.TextColor3 = t.TextPrimary
        subLabel.TextColor3 = t.TextMuted
        track.BackgroundColor3 = DevMode.enabled and t.Accent or t.ToggleOff
    end)
end

-- ============================================================
-- Hook BuildSettingsPanel
-- ============================================================
local _origBuildSettings = LucidUI.Window.BuildSettingsPanel
LucidUI.Window.BuildSettingsPanel = function(self, ...)
    _origBuildSettings(self, ...)
    if not self._devSettingsBuilt and self._settingsBuilt then
        self._devSettingsBuilt = true
        pcall(function() self:_buildDevSettings() end)
    end
end

-- ============================================================
-- Also hook Section._track for future elements
-- ============================================================
-- (Already overridden above, this comment documents the hook)

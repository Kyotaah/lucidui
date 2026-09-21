-- ============================================================
-- Module: 10d1_density.lua
-- ============================================================
--[[
    UI Density Modes.

    LucidUI:SetDensity("compact" | "comfortable" | "spacious")

    Scales row heights and text sizes across:
      • Section headers
      • Element rows (every Create* in 09_elements.lua)
      • Settings panel rows

    Does NOT scale:
      • The window frame itself (that's user-resizable)
      • The tab strip (it's a fixed-height chrome bar)
      • The header (title + buttons stay at designed size)
      • Inter-row padding (would require touching every UIListLayout)

    Persistence:
      Saved to LucidUI/_preferences.json
      Loaded on module init
      Applied to every new window at CreateWindow

    Tween:
      Density changes animate over 220ms so the reflow reads as
      "everything is settling" rather than "everything snapped."

    Storage:
      Per-frame base values saved as attributes
        _lucidBaseH       frame Size.Y.Offset at 1.0x
        _lucidBaseW       frame Size.X.Offset at 1.0x
        _lucidBaseTS      TextSize at 1.0x
      This lets us re-apply any density from any starting state
      without accumulating rounding errors.

    Wrapped in do...end — zero top-level locals added.
]]

do

if not LucidUI or not LucidUI.Window then return end

local TweenService = game:GetService("TweenService")

local DENSITIES = {
    compact     = { height = 0.80, font = 0.90, label = "Compact"     },
    comfortable = { height = 1.00, font = 1.00, label = "Comfortable" },
    spacious    = { height = 1.25, font = 1.10, label = "Spacious"    },
}

local DEFAULT_DENSITY = "comfortable"
local TWEEN_TIME      = 0.22
local PREFS_PATH      = "LucidUI/_preferences.json"

LucidUI._density = DEFAULT_DENSITY

-- ------------------------------------------------------------
-- Persistence
-- ------------------------------------------------------------
local function loadPrefs()
    if not Compat or not Compat.read then return nil end
    local raw = Compat.read(PREFS_PATH)
    if not raw then return nil end
    return Compat.decode(raw)
end

local function savePrefs()
    if not Compat or not Compat.write then return end
    local data = { density = LucidUI._density }
    local encoded = Compat.encode(data)
    if encoded then Compat.write(PREFS_PATH, encoded) end
end

-- ------------------------------------------------------------
-- Base-value capture
-- ------------------------------------------------------------
local function ensureBase(frame)
    if frame:GetAttribute("_lucidBaseH") == nil then
        frame:SetAttribute("_lucidBaseH", frame.Size.Y.Offset)
    end
    if frame:GetAttribute("_lucidBaseW") == nil then
        frame:SetAttribute("_lucidBaseW", frame.Size.X.Offset)
    end
end

local function ensureTextBase(inst)
    if inst:GetAttribute("_lucidBaseTS") == nil then
        inst:SetAttribute("_lucidBaseTS", inst.TextSize)
    end
end

-- ------------------------------------------------------------
-- Apply
-- ------------------------------------------------------------
local function applyToFrame(frame, dens, animate)
    if not frame or not frame.Parent then return end
    if not frame:IsA("GuiObject") then return end

    ensureBase(frame)
    local baseH = frame:GetAttribute("_lucidBaseH")
    local baseW = frame:GetAttribute("_lucidBaseW")

    -- Guard against base values that were captured while already scaled
    if baseH == 0 and frame.Size.Y.Scale == 0 then
        -- Auto-sized or zero-height, skip
    else
        local targetH = math.floor(baseH * dens.height + 0.5)
        local targetW = math.floor(baseW * dens.height + 0.5)
        local targetSize = UDim2.new(
            frame.Size.X.Scale, targetW,
            frame.Size.Y.Scale, targetH
        )

        if animate and frame:FindFirstChildOfClass("UIScale") == nil then
            TweenService:Create(frame, TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                { Size = targetSize }):Play()
        else
            frame.Size = targetSize
        end
    end

    for _, d in ipairs(frame:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            ensureTextBase(d)
            local baseTS = d:GetAttribute("_lucidBaseTS")
            if baseTS and baseTS > 0 then
                local targetTS = math.max(8, math.floor(baseTS * dens.font + 0.5))
                if animate then
                    TweenService:Create(d, TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                        { TextSize = targetTS }):Play()
                else
                    d.TextSize = targetTS
                end
            end
        end
    end
end

-- ------------------------------------------------------------
-- Walk a window's rows
-- ------------------------------------------------------------
local function applyToWindow(W, dens, animate)
    if not W or not W.Main or not W.Main.Parent then return end

    -- Element rows in every tab
    for _, tab in ipairs(W.Tabs or {}) do
        for _, section in ipairs(tab.Sections or {}) do
            if section.HeaderBtn then
                pcall(applyToFrame, section.HeaderBtn, dens, animate)
            end
            local container = section.Container
            if container then
                for _, child in ipairs(container:GetChildren()) do
                    if child:IsA("GuiObject") then
                        pcall(applyToFrame, child, dens, animate)
                    end
                end
            end
        end
    end

    -- Settings rows
    if W._spContent then
        for _, child in ipairs(W._spContent:GetChildren()) do
            if child:IsA("GuiObject")
               and not child:IsA("UIListLayout")
               and not child:IsA("UIPadding") then
                pcall(applyToFrame, child, dens, animate)
            end
        end
    end
end

-- ------------------------------------------------------------
-- Public API
-- ------------------------------------------------------------
function LucidUI:GetDensity()
    return self._density
end

function LucidUI:GetDensityFactor()
    local d = DENSITIES[self._density] or DENSITIES[DEFAULT_DENSITY]
    return d
end

function LucidUI:SetDensity(name, silent)
    if not DENSITIES[name] then
        warn("[LucidUI] Unknown density: " .. tostring(name))
        return false
    end
    if self._density == name then return true end

    self._density = name
    savePrefs()

    local dens = DENSITIES[name]
    for _, W in ipairs(self._windows or {}) do
        pcall(applyToWindow, W, dens, true)
    end

    if not silent then
        pcall(function()
            LucidUI:Notify({
                Title = "UI Density",
                Message = dens.label,
                Variant = "info",
                Duration = 2,
            })
        end)
    end
    return true
end

-- ------------------------------------------------------------
-- Auto-apply on window creation
-- ------------------------------------------------------------
local function applyCurrentDensity(W)
    local dens = DENSITIES[LucidUI._density] or DENSITIES[DEFAULT_DENSITY]
    pcall(applyToWindow, W, dens, false)
end

-- ------------------------------------------------------------
-- Track new elements as they are added
-- ------------------------------------------------------------
local _origTrack = LucidUI.Section._track
function LucidUI.Section:_track(frame)
    local result = _origTrack(self, frame)
    if result and result:IsA("GuiObject") then
        local dens = DENSITIES[LucidUI._density] or DENSITIES[DEFAULT_DENSITY]
        task.defer(function()
            if result.Parent then
                pcall(applyToFrame, result, dens, false)
            end
        end)
    end
    return result
end

-- ------------------------------------------------------------
-- Settings UI — hook into BuildSettingsPanel
-- ------------------------------------------------------------
function LucidUI.Window:_buildDensitySettings()
    self:_addSettingSection("UI Density")

    local row = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 42),
    })
    Corner(10, row)
    self:_addSettingFrame(row)

    local label = Create("TextLabel", {
        Text = "Row Density",
        Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -260, 1, 0),
        Parent = row,
    })

    local segRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Background,
        BackgroundTransparency = 0.4,
        Size = UDim2.fromOffset(230, 28),
        Position = UDim2.new(1, -240, 0.5, -14),
        Parent = row,
    })
    Corner(8, segRow)
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = segRow,
    })
    Create("UIPadding", {
        PaddingLeft  = UDim.new(0, 2),
        PaddingRight = UDim.new(0, 2),
        PaddingTop   = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 2),
        Parent = segRow,
    })

    local buttons = {}
    local order = 0
    for _, key in ipairs({ "compact", "comfortable", "spacious" }) do
        order = order + 1
        local dens = DENSITIES[key]
        local active = (LucidUI._density == key)

        local btn = Create("TextButton", {
            Text = dens.label,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = active and Color3.fromRGB(255, 255, 255) or self.Theme.TextSecondary,
            BackgroundColor3 = active and self.Theme.Accent or self.Theme.Surface,
            BackgroundTransparency = active and 0.15 or 0.5,
            AutoButtonColor = false,
            Size = UDim2.new(1/3, -2, 1, 0),
            LayoutOrder = order,
            Parent = segRow,
        })
        Corner(6, btn)

        buttons[key] = btn

        BindTap(btn, function()
            PlayUISound("click")
            LucidUI:SetDensity(key, true)
            for k, b in pairs(buttons) do
                local isActive = (k == key)
                Tween(b, 0.18, {
                    BackgroundColor3 = isActive and self.Theme.Accent or self.Theme.Surface,
                    BackgroundTransparency = isActive and 0.15 or 0.5,
                    TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or self.Theme.TextSecondary,
                }, Enum.EasingStyle.Quart):Play()
            end
        end)
    end

    self:_registerTheme(function(t)
        row.BackgroundColor3 = t.Surface
        label.TextColor3 = t.TextPrimary
        segRow.BackgroundColor3 = t.Background
        for key, b in pairs(buttons) do
            local isActive = (LucidUI._density == key)
            b.BackgroundColor3 = isActive and t.Accent or t.Surface
            b.TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or t.TextSecondary
        end
    end)
end

local _origBuildSettings = LucidUI.Window.BuildSettingsPanel
function LucidUI.Window:BuildSettingsPanel(...)
    _origBuildSettings(self, ...)
    if self._settingsBuilt and not self._densitySettingsBuilt then
        self._densitySettingsBuilt = true
        pcall(function() self:_buildDensitySettings() end)
    end
end

-- ------------------------------------------------------------
-- CreateWindow hook — apply density + reapply after settings build
-- ------------------------------------------------------------
local _origCreateWindow = LucidUI.CreateWindow
function LucidUI:CreateWindow(config)
    local W = _origCreateWindow(self, config)
    task.defer(function()
        if W and W.Main then
            pcall(applyCurrentDensity, W)
        end
    end)
    return W
end

-- ------------------------------------------------------------
-- Load saved preference at module init
-- ------------------------------------------------------------
task.defer(function()
    local prefs = loadPrefs()
    if prefs and type(prefs.density) == "string" and DENSITIES[prefs.density] then
        LucidUI._density = prefs.density
    end
end)

LucidUI:OnCleanup(function()
    print("[LucidUI] Density cleaned up")
end)

end

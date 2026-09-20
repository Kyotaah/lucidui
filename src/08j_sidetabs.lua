-- ============================================================
-- Module: 08j_sidetabs.lua
-- ============================================================
--[[
    Side Tabs — turns LucidUI's horizontal tab strip into a vertical
    left sidebar. Matches RayVoid's `SideTabs = true` behaviour.

    Usage:
        LucidUI:CreateWindow({
            Name = "My Hub",
            SideTabs = true,                 -- default width 130
            -- OR:
            SideTabs = { Width = 150 },      -- custom width
        })

    What it changes:
      • TabStrip becomes a vertical ScrollingFrame on the left
      • Content moves to the right of the sidebar
      • Tab buttons become full-width, left-aligned
      • A subtle vertical divider sits between sidebar and content
      • Sidebar gets a faint theme-tinted background
      • Header + separator + window controls are untouched

    Also handles:
      • Theme changes (sidebar bg, divider color, tab text)
      • Window resize (re-applies the layout after LucidUI's
        default resize handler overwrites Content.Size)
      • Window minimize (no-op — dimensions already account for it)

    [FIX] convertTabStripToSidebar now re-styles every tab that
    already exists on the window. Previously it only flipped the
    UIListLayout to Vertical, which meant pre-existing tabs (like
    the auto-created MainCredit tab from 08i_credit.lua, or any
    tabs created before SetSideTabs was called at runtime) kept
    their horizontal widths and rendered as squat little boxes in
    the sidebar. Now they're all resized to (1, -8, 0, 36) and
    left-aligned to match tabs created after conversion.

    NO tracking. NO network. NO clipboard.
]]

-- ============================================================
-- Per-window layout
-- ============================================================
--[[
    Layout math (from top of W.Main):
        y = 0    : header              (height 44)
        y = 44   : separator           (height 1)
        y = 52   : sidebar + content   (8px gap after separator)
        y = H-12 : bottom margin

    Sidebar:
        x = 12, width = sw, height = H - 64

    Content:
        x = 12 + sw + 8, width = W - (12 + sw + 8) - 12 = W - (sw + 32)
        height = H - 64

    Divider (optional):
        x = 12 + sw + 4, width = 1, height = H - 64
]]

local HEADER_H = 44
local GAP      = 8
local MARGIN   = 12

local function computeLayout(W)
    local sw = W._sideTabsWidth or 130
    local sidebarX  = MARGIN
    local contentX  = MARGIN + sw + GAP
    local contentW  = -(contentX + MARGIN)   -- for UDim2.new(1, contentW, ...)
    local innerH    = -(HEADER_H + GAP + MARGIN)

    return {
        sidebarPosition  = UDim2.fromOffset(sidebarX, HEADER_H + GAP),
        sidebarSize      = UDim2.new(0, sw, 1, innerH),
        contentPosition  = UDim2.fromOffset(contentX, HEADER_H + GAP),
        contentSize      = UDim2.new(1, contentW, 1, innerH),
        dividerPosition  = UDim2.fromOffset(contentX - GAP / 2, HEADER_H + GAP),
        dividerSize      = UDim2.new(0, 1, 1, innerH),
    }
end

local function applyLayout(W)
    if not W._sideTabsMode then return end
    if W.Minimized then return end

    local L = computeLayout(W)
    W.TabStrip.Position = L.sidebarPosition
    W.TabStrip.Size     = L.sidebarSize
    W.Content.Position  = L.contentPosition
    W.Content.Size      = L.contentSize
    if W._sideTabsDivider then
        W._sideTabsDivider.Position = L.dividerPosition
        W._sideTabsDivider.Size     = L.dividerSize
    end
end

-- [FIX] Re-style a single tab button to fit the sidebar.
-- Shared between conversion-time (existing tabs) and
-- creation-time (tabs created after conversion).
local function styleTabForSidebar(tab)
    if not tab then return end
    if tab.Button then
        tab.Button.Size = UDim2.new(1, -8, 0, 36)
    end
    if tab.Label then
        tab.Label.TextXAlignment = Enum.TextXAlignment.Left
    end
end

-- ============================================================
-- Turn a horizontal TabStrip into a vertical sidebar
-- ============================================================
local function convertTabStripToSidebar(W, width)
    W._sideTabsMode  = true
    W._sideTabsWidth = width

    -- 1. Switch the tab list layout to vertical
    local list = W.TabStrip:FindFirstChildOfClass("UIListLayout")
    if list then
        list.FillDirection       = Enum.FillDirection.Vertical
        list.HorizontalAlignment = Enum.HorizontalAlignment.Left
        list.VerticalAlignment   = Enum.VerticalAlignment.Top
        list.Padding             = UDim.new(0, 6)
    end

    -- 2. Switch the scrolling direction
    W.TabStrip.ScrollingDirection = Enum.ScrollingDirection.Y
    W.TabStrip.CanvasSize         = UDim2.new(0, 0, 0, 0)
    W.TabStrip.AutomaticCanvasSize = Enum.AutomaticSize.Y
    W.TabStrip.ScrollBarThickness = 2
    W.TabStrip.ScrollBarImageColor3 = W.Theme.TextMuted
    W.TabStrip.ScrollBarImageTransparency = 0.5

    -- 3. Give the sidebar a subtle theme tint
    W.TabStrip.BackgroundColor3     = W.Theme.Surface
    W.TabStrip.BackgroundTransparency = 0.55

    -- 4. Add a thin vertical divider between sidebar and content
    local divider = Create("Frame", {
        Name = "SideTabsDivider",
        BackgroundColor3 = W.Theme.Border,
        BackgroundTransparency = (W.Theme.BorderTrans or 0.75) + 0.1,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = W.Main,
    })
    W._sideTabsDivider = divider

    -- 5. Position everything
    applyLayout(W)

    -- [FIX] 5b. Re-style every tab that already exists on this
    -- window. Without this, tabs created before conversion (which
    -- includes the auto-Main tab from 08i_credit.lua, since that
    -- hook runs before ours) keep their horizontal widths and
    -- render as tiny boxes in a 130px-wide sidebar.
    for _, tab in ipairs(W.Tabs or {}) do
        styleTabForSidebar(tab)
    end

    -- 6. Re-apply layout whenever Main resizes (window resize,
    --    minimize animation, etc.). We defer one frame because
    --    LucidUI's own resize handler runs after us and rewrites
    --    Content.Size with its hardcoded formula.
    local pending = false
    local function scheduleLayout()
        if pending then return end
        pending = true
        task.defer(function()
            pending = false
            applyLayout(W)
        end)
    end

    table.insert(W._conns, W.Main:GetPropertyChangedSignal("Size"):Connect(scheduleLayout))

    -- 7. Defensive: if Content.Size gets overwritten with a wrong
    --    formula (this happens on resize), snap it back.
    table.insert(W._conns, W.Content:GetPropertyChangedSignal("Size"):Connect(function()
        if W._fixingSideTabsSize or W.Minimized then return end
        local L = computeLayout(W)
        if W.Content.Size.X.Offset ~= L.contentSize.X.Offset then
            W._fixingSideTabsSize = true
            W.Content.Position = L.contentPosition
            W.Content.Size     = L.contentSize
            W._fixingSideTabsSize = false
        end
    end))

    -- 8. Theme hook
    W:_registerTheme(function(t)
        W.TabStrip.BackgroundColor3     = t.Surface
        W.TabStrip.ScrollBarImageColor3 = t.TextMuted
        if W._sideTabsDivider then
            W._sideTabsDivider.BackgroundColor3     = t.Border
            W._sideTabsDivider.BackgroundTransparency = (t.BorderTrans or 0.75) + 0.1
        end
    end)
end

-- ============================================================
-- Hook CreateWindow
-- ============================================================
local _origCreateWindow = LucidUI.CreateWindow
function LucidUI:CreateWindow(config)
    config = config or {}
    local W = _origCreateWindow(self, config)

    local sideCfg = config.SideTabs
    local enabled, width = false, 130

    if sideCfg == true then
        enabled = true
    elseif type(sideCfg) == "table" then
        enabled = true
        width = math.clamp(sideCfg.Width or 130, 90, 220)
    end

    if enabled then
        pcall(convertTabStripToSidebar, W, width)
    end

    return W
end

-- ============================================================
-- Hook CreateTab to make tab buttons fill the sidebar.
-- Fast-path returns immediately when side tabs aren't active,
-- so the default horizontal layout has zero overhead.
-- ============================================================
local _origCreateTab = LucidUI.Window.CreateTab
function LucidUI.Window:CreateTab(config)
    if not self._sideTabsMode then
        return _origCreateTab(self, config)
    end

    local tab = _origCreateTab(self, config)
    styleTabForSidebar(tab)
    return tab
end

-- ============================================================
-- Runtime toggle
-- ============================================================
--[[
    -- Convert an already-created window to side tabs:
    Window:SetSideTabs(true, 140)
    -- Revert:
    Window:SetSideTabs(false)
]]

function LucidUI.Window:SetSideTabs(enabled, width)
    if enabled and not self._sideTabsMode then
        convertTabStripToSidebar(self, width or 130)
        -- Note: convertTabStripToSidebar already restyles existing
        -- tabs, so we don't need a second loop here anymore.
        return true

    elseif not enabled and self._sideTabsMode then
        -- Revert to default horizontal layout
        self._sideTabsMode = false

        local list = self.TabStrip:FindFirstChildOfClass("UIListLayout")
        if list then
            list.FillDirection       = Enum.FillDirection.Horizontal
            list.VerticalAlignment   = Enum.VerticalAlignment.Center
            list.HorizontalAlignment = Enum.HorizontalAlignment.Left
        end

        self.TabStrip.ScrollingDirection  = Enum.ScrollingDirection.X
        self.TabStrip.CanvasSize          = UDim2.new(0, 0, 0, 34)
        self.TabStrip.AutomaticCanvasSize = Enum.AutomaticSize.X
        self.TabStrip.BackgroundTransparency = 1
        self.TabStrip.Size     = UDim2.new(1, -32, 0, 34)
        self.TabStrip.Position = UDim2.fromOffset(16, 52)
        self.TabStrip.ScrollBarThickness = 0

        self.Content.Position = UDim2.fromOffset(12, 94)
        self.Content.Size     = UDim2.new(1, -24, 1, -110)

        if self._sideTabsDivider then
            pcall(function() self._sideTabsDivider:Destroy() end)
            self._sideTabsDivider = nil
        end

        -- Re-style existing tabs back to auto-width
        for _, tab in ipairs(self.Tabs or {}) do
            local ts = TextService:GetTextSize(
                tab.Name or "", 13, Enum.Font.GothamMedium, Vector2.new(1000, 34)
            )
            local hasIcon = tab.IconParts and #tab.IconParts > 0
            local labelX  = hasIcon and 30 or 12
            if tab.Button then
                tab.Button.Size = UDim2.fromOffset(ts.X + labelX + 14, 34)
            end
            if tab.Label then
                tab.Label.TextXAlignment = Enum.TextXAlignment.Center
            end
        end
        return true
    end
    return false
end

-- ============================================================
-- Cleanup
-- ============================================================
LucidUI:OnCleanup(function()
    print("[LucidUI] SideTabs cleaned up")
end)

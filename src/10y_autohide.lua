-- ============================================================
-- Module: 10y_autohide.lua
-- ============================================================
--[[
    Auto-hide scrolled header — when the user scrolls down inside an
    active tab page, the tab strip and separator fade out and slide
    up. Content expands upward to fill the space. Scrolling up (or
    returning to the top) restores them.

    Opt-in per window:
        CreateWindow({ AutohideHeader = true })

    Or set globally:
        LucidUI:SetAutohideDefault(true)

    Behavior:
      • Wraps TabStrip + Separator in a CanvasGroup for a single-
        property fade instead of per-child transparency tweens
      • Content.Position / Size tween in sync so the bottom edge
        stays fixed while the top expands
      • Resets to visible on tab switch, minimize, settings toggle,
        and window resize
      • Skipped automatically when SideTabs is active

    Wrapped in do...end — zero top-level locals added.
]]

do

if not LucidUI or not LucidUI.Window then return end

local TweenService = game:GetService("TweenService")

local HIDE_AT_SCROLLY = 40   -- px scrolled before header can hide
local HIDE_DELTA      = 3    -- px of downward motion to trigger hide
local SHOW_DELTA      = -3   -- px of upward motion to trigger show
local TWEEN_TIME      = 0.22

LucidUI._autohideDefault = false

function LucidUI:SetAutohideDefault(on)
    self._autohideDefault = on and true or false
end

-- ------------------------------------------------------------
-- Install
-- ------------------------------------------------------------
local function install(W)
    if W._autohideInstalled then return end
    if W._sideTabsMode then return end
    if not (W.Main and W.TabStrip and W.Separator and W.Content) then return end
    W._autohideInstalled = true

    -- Base values captured at install time
    local BASE_Y             = W.Content.Position.Y.Offset
    local BASE_SIZE_OFFSET   = W.Content.Size.Y.Offset
    local HIDDEN_Y           = BASE_Y - 50
    local HIDDEN_SIZE_OFFSET = BASE_SIZE_OFFSET + 50

    -- Wrapper group around Separator + TabStrip
    local group = Create("CanvasGroup", {
        Name = "AutohideGroup",
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.fromOffset(0, 44),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        GroupTransparency = 0,
        ZIndex = 2,
        Parent = W.Main,
    })
    W._autohideGroup = group

    -- Reparent into the group
    W.Separator.Position = UDim2.fromOffset(16, 0)
    W.Separator.Parent   = group

    W.TabStrip.Position  = UDim2.fromOffset(16, 8)
    W.TabStrip.Parent    = group

    local hidden = false
    local lastY  = 0

    local function setHidden(hide)
        if hide == hidden then return end
        hidden = hide

        if not hide then
            group.Visible = true
        end

        local info = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

        local fadeTween = TweenService:Create(group, info, {
            GroupTransparency = hide and 1 or 0,
        })
        fadeTween:Play()

        if hide then
            fadeTween.Completed:Connect(function()
                if hidden then group.Visible = false end
            end)
        end

        TweenService:Create(W.Content, info, {
            Position = UDim2.fromOffset(12, hide and HIDDEN_Y or BASE_Y),
            Size     = UDim2.new(1, -24, 1, hide and HIDDEN_SIZE_OFFSET or BASE_SIZE_OFFSET),
        }):Play()
    end

    local function onScroll()
        local tab = W.ActiveTab
        if not tab or not tab.Page then return end

        if W.SettingsOpen or W.Minimized or W.Floating then
            setHidden(false)
            lastY = tab.Page.CanvasPosition.Y
            return
        end

        local y     = tab.Page.CanvasPosition.Y
        local delta = y - lastY
        lastY       = y

        if y <= HIDE_AT_SCROLLY then
            setHidden(false)
        elseif delta >= HIDE_DELTA then
            setHidden(true)
        elseif delta <= SHOW_DELTA then
            setHidden(false)
        end
    end

    local function hookTab(tab)
        if not tab or not tab.Page then return end
        if tab._autohideHooked then return end
        tab._autohideHooked = true
        tab.Page:GetPropertyChangedSignal("CanvasPosition"):Connect(onScroll)
    end

    for _, t in ipairs(W.Tabs or {}) do
        hookTab(t)
    end

    -- Called by SelectTab wrapper
    W._autohideOnTabChange = function(tab)
        hookTab(tab)
        if tab and tab.Page then
            lastY = tab.Page.CanvasPosition.Y
        else
            lastY = 0
        end
        setHidden(false)
    end

    -- Called by SetMinimized and ToggleSettings wrappers
    W._autohideReset = function()
        setHidden(false)
        if W.ActiveTab and W.ActiveTab.Page then
            lastY = W.ActiveTab.Page.CanvasPosition.Y
        else
            lastY = 0
        end
    end

    -- Reapply Content size after window resize. 06_window's resize
    -- handler hardcodes Size.Y.Offset = -110 regardless of our state.
    table.insert(W._conns, W.Main:GetPropertyChangedSignal("Size"):Connect(function()
        task.defer(function()
            if W.Content and W.Content.Parent then
                W.Content.Size = UDim2.new(1, -24, 1,
                    hidden and HIDDEN_SIZE_OFFSET or BASE_SIZE_OFFSET)
            end
        end)
    end))
end

-- ------------------------------------------------------------
-- Wrappers
-- ------------------------------------------------------------
local _origCreateWindow = LucidUI.CreateWindow
function LucidUI:CreateWindow(config)
    config = config or {}
    local W = _origCreateWindow(self, config)

    local enabled = config.AutohideHeader
    if enabled == nil then
        enabled = self._autohideDefault
    end

    if enabled then
        task.defer(function()
            if W and W.TabStrip then
                pcall(install, W)
            end
        end)
    end

    return W
end

local _origSelectTab = LucidUI.Window.SelectTab
function LucidUI.Window:SelectTab(tab)
    _origSelectTab(self, tab)
    if self._autohideOnTabChange then
        pcall(self._autohideOnTabChange, tab)
    end
end

local _origSetMinimized = LucidUI.Window.SetMinimized
function LucidUI.Window:SetMinimized(state)
    _origSetMinimized(self, state)
    if self._autohideReset then
        pcall(self._autohideReset)
    end
end

local _origToggleSettings = LucidUI.Window.ToggleSettings
function LucidUI.Window:ToggleSettings(state)
    _origToggleSettings(self, state)
    if self._autohideReset and not self.SettingsOpen then
        pcall(self._autohideReset)
    end
end

LucidUI:OnCleanup(function()
    print("[LucidUI] Autohide cleaned up")
end)

end

-- ============================================================
-- Module: 10u_autohideheader.lua
-- ============================================================
--[[
    Auto-Hide Scrolled Header — when the user scrolls down inside
    an active tab page, the tab strip slides up off-screen to give
    more vertical space. It slides back when scrolled to top or
    scrolled up.

    Threshold: 40px of downward scroll before the strip hides.
    Cooldown: 0.15s between state changes to prevent flicker.
]]

do

if not LucidUI or not LucidUI.Window then return end

local TweenService = game:GetService("TweenService")

local HIDE_AFTER  = 40   -- px scrolled down before hiding
local SHOW_BEFORE = 10   -- px from top before showing
local COOLDOWN    = 0.15

local function hookPage(W, page)
    if not page or page:GetAttribute("LucidAutoHideHooked") then return end
    page:SetAttribute("LucidAutoHideHooked", true)

    local hidden = false
    local lastChange = 0

    local function setHidden(state)
        if hidden == state then return end
        local now = tick()
        if now - lastChange < COOLDOWN then return end
        lastChange = now
        hidden = state

        local strip = W.TabStrip
        if not strip or not strip.Parent then return end

        if state then
            TweenService:Create(strip,
                TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                { Position = UDim2.fromOffset(16, -40) }):Play()
        else
            TweenService:Create(strip,
                TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                { Position = UDim2.fromOffset(16, 52) }):Play()
        end
    end

    page:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        if W.Minimized or W.SettingsOpen then return end
        local y = page.CanvasPosition.Y
        if y > HIDE_AFTER then
            setHidden(true)
        elseif y < SHOW_BEFORE then
            setHidden(false)
        end
    end)
end

local _origSelectTab = LucidUI.Window.SelectTab
function LucidUI.Window:SelectTab(tab)
    _origSelectTab(self, tab)
    if tab and tab.Page then
        task.defer(function()
            pcall(hookPage, self, tab.Page)
        end)
    end
end

LucidUI:OnCleanup(function()
    print("[LucidUI] AutoHideHeader cleaned up")
end)

end

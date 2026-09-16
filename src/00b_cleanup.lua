--[[
    Cleanup — runs FIRST on every execution to wipe the previous
    session's state before anything new is created.

    This fixes the "re-execution" problem where users end up with:
      • Two UIs on screen
      • Duplicate notification roots
      • Ghost connections firing from the old session
      • Toggles still doing work in the background

    What it does:
      1. Calls every cleanup callback registered via LucidUI:OnCleanup()
      2. Disconnects every connection stored in w._conns
      3. Destroys every tracked window GUI
      4. Destroys the notification root
      5. Destroys the intro GUI
      6. Destroys watermarks
      7. Fallback: nukes any ScreenGui whose name starts with "LucidUI"
      8. Clears the global LucidUI reference so a fresh one is built

    Usage for YOUR features (aimbot, ESP, fly, remotes, etc.):
        LucidUI:OnCleanup(function()
            connection:Disconnect()
            isAimbotActive = false
            -- stop any loops, revert any character changes, etc.
        end)
]]

-- ============================================================
-- 1. Run user cleanup callbacks from the previous session
-- ============================================================
local oldLucidUI = getgenv().LucidUI
if oldLucidUI and type(oldLucidUI) == "table" then
    if type(oldLucidUI._cleanupCallbacks) == "table" then
        for _, fn in ipairs(oldLucidUI._cleanupCallbacks) do
            pcall(fn)
        end
    end
end

-- ============================================================
-- 2. Destroy tracked windows and their connections
-- ============================================================
if oldLucidUI and type(oldLucidUI) == "table" then
    if type(oldLucidUI._windows) == "table" then
        for _, w in ipairs(oldLucidUI._windows) do
            pcall(function()
                -- Disconnect stored connections
                if w._conns then
                    for _, c in ipairs(w._conns) do
                        if typeof(c) == "RBXScriptConnection" then
                            pcall(function() c:Disconnect() end)
                        end
                    end
                    w._conns = {}
                end

                -- Destroy watermark (has its own ScreenGui)
                if w._watermark and type(w._watermark.Destroy) == "function" then
                    pcall(function() w._watermark:Destroy() end)
                end

                -- Destroy the main GUI
                if w.Gui then
                    pcall(function() w.Gui:Destroy() end)
                end
            end)
        end
        oldLucidUI._windows = {}
    end

    -- 3. Destroy notification root
    if oldLucidUI._notifRoot then
        pcall(function() oldLucidUI._notifRoot:Destroy() end)
    end

    -- 4. Destroy the intro GUI
    if oldLucidUI._activeIntro then
        pcall(function() oldLucidUI._activeIntro:Destroy() end)
    end

    -- 5. Reset transient flags
    oldLucidUI._keyListening = false
    oldLucidUI._activeSlider = nil
end

-- ============================================================
-- 6. Fallback sweep: destroy any ScreenGui named LucidUI_*
--    (catches tooltip GUI, watermark GUIs, key system GUIs,
--     and anything else that escaped the tracker)
-- ============================================================
pcall(function()
    local players = game:GetService("Players")
    local lp = players.LocalPlayer
    if lp then
        local playerGui = lp:FindFirstChild("PlayerGui")
        if playerGui then
            for _, gui in ipairs(playerGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Name:match("^LucidUI") then
                    pcall(function() gui:Destroy() end)
                end
            end
        end
    end
end)

-- ============================================================
-- 7. Clear the global reference so 02_themes.lua builds fresh
-- ============================================================
getgenv().LucidUI = nil
getgenv().LucidUI_ActiveWindows = nil

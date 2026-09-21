-- ============================================================
-- Module: 10r_settingsorder.lua
-- ============================================================
--[[
    Settings Panel Ordering — reorders settings sections from
    "necessary" (top) to "display" (bottom), matching how users
    actually navigate the panel.

    Runs as the outermost BuildSettingsPanel wrapper so it fires
    after every other module has added its section. Groups each
    section header with the rows below it, then re-assigns
    LayoutOrder sequentially.

    To customize the order: edit SECTION_ORDER below. Higher
    numbers appear later. Unknown sections fall to priority 500
    (between Share Codes and Discord Webhook).
]]

do

if not LucidUI or not LucidUI.Window then return end

-- ------------------------------------------------------------
-- Ordering map — lower number = appears higher
-- ------------------------------------------------------------
local SECTION_ORDER = {
    -- Workflow essentials
    ["THEME"]             =  10,
    ["CONFIGS"]           =  20,
    ["PER-GAME CONFIGS"]  =  25,
    ["KEYBINDS"]          =  30,
    ["HOTKEYS"]           =  40,
    -- Behavior & feedback
    ["PERFORMANCE"]       =  50,
    ["DOCKING"]           =  60,
    ["WATERMARK"]         =  70,
    ["SOUND"]             =  80,
    -- Appearance
    ["BACKGROUND IMAGE"]  =  90,
    ["CUSTOM THEME"]      = 100,
    ["SAVED THEMES"]      = 110,
    ["SHARE CODES"]       = 120,
    -- Advanced
    ["DISCORD WEBHOOK"]   = 130,
    ["ERRORS"]            = 140,
    ["DEVELOPER"]         = 150,
    -- Bottom
    ["ABOUT"]             = 900,
}

local DEFAULT_PRIORITY = 500

-- ------------------------------------------------------------
-- Section header detection
-- ------------------------------------------------------------
-- Section headers are bare TextLabels, all-uppercase, <=22px tall.
-- The _addSettingSection helper in 07_settings_a.lua produces
-- exactly this shape:  Text = title:upper(), Size.Y.Offset = 18.
local function isSectionHeader(child)
    if not child:IsA("TextLabel") then return false end
    if child.Size.Y.Offset > 22 then return false end
    local t = child.Text or ""
    if t == "" then return false end
    if not t:match("%a") then return false end  -- skip pure numbers
    return t == t:upper()
end

-- ------------------------------------------------------------
-- Reorder
-- ------------------------------------------------------------
local function reorderSections(W)
    local sp = W._spContent
    if not sp or not sp.Parent then return end

    -- Snapshot children in current order
    local children = {}
    for _, c in ipairs(sp:GetChildren()) do
        if c:IsA("GuiObject")
            and not c:IsA("UIListLayout")
            and not c:IsA("UIPadding") then
            table.insert(children, c)
        end
    end

    -- Group: each group starts at a header and includes every
    -- following non-header child until the next header.
    local groups = {}
    local current = nil
    for _, c in ipairs(children) do
        if isSectionHeader(c) then
            current = { header = c, name = c.Text, items = {} }
            table.insert(groups, current)
        elseif current then
            table.insert(current.items, c)
        else
            -- Items before any header — synthetic group at the top
            table.insert(groups, { header = nil, name = "", items = { c } })
        end
    end

    -- Stable sort by priority, then alphabetically for ties
    table.sort(groups, function(a, b)
        local pa = SECTION_ORDER[a.name] or DEFAULT_PRIORITY
        local pb = SECTION_ORDER[b.name] or DEFAULT_PRIORITY
        if pa == pb then
            return (a.name or "") < (b.name or "")
        end
        return pa < pb
    end)

    -- Reassign LayoutOrder
    local n = 1
    for _, g in ipairs(groups) do
        if g.header then
            g.header.LayoutOrder = n
            n = n + 1
        end
        for _, item in ipairs(g.items) do
            item.LayoutOrder = n
            n = n + 1
        end
    end
end

-- ------------------------------------------------------------
-- Hook — install as the outermost wrapper so we run LAST
-- ------------------------------------------------------------
local _origBuildSettings = LucidUI.Window.BuildSettingsPanel
function LucidUI.Window:BuildSettingsPanel(...)
    _origBuildSettings(self, ...)
    if self._settingsBuilt and not self._settingsOrderApplied then
        self._settingsOrderApplied = true
        task.defer(function()
            pcall(reorderSections, self)
        end)
    end
end

LucidUI:OnCleanup(function()
    print("[LucidUI] SettingsOrder cleaned up")
end)

end

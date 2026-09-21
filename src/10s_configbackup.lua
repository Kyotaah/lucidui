-- ============================================================
-- Module: 10s_configbackup.lua
-- ============================================================
--[[
    Config Backup — every SaveConfig rotates the current file to
    .bak1, .bak1 to .bak2, up to .bak5. Also writes a metadata
    sidecar with lastUsed, createdAt, elementCount, themeName.

    Provides:
      LucidUI.Backup:ListFor(configName)  -> { {slot, meta}, ... }
      LucidUI.Backup:Restore(configName, slot) -> bool
      LucidUI.Backup:PruneStale()  -- not needed, rotation is bounded

    The settings panel gets a "Restore from backup" submenu
    appended automatically under the Configs section.
]]

do

if not LucidUI or not Compat then return end

LucidUI.Backup = {}
local Backup = LucidUI.Backup

local MAX_BACKUPS = 5

-- ------------------------------------------------------------
-- Paths
-- ------------------------------------------------------------
local function basePath(name)
    return "LucidUI/Configs/" .. name .. ".json"
end

local function bakPath(name, slot)
    return "LucidUI/Configs/" .. name .. ".bak" .. slot .. ".json"
end

local function metaPath(name)
    return "LucidUI/Configs/" .. name .. ".meta.json"
end

-- ------------------------------------------------------------
-- Rotation
-- ------------------------------------------------------------
local function rotateBackups(name)
    -- Move bak4 -> bak5, bak3 -> bak4, ..., bak1 -> bak2
    for slot = MAX_BACKUPS - 1, 1, -1 do
        local src = bakPath(name, slot)
        local dst = bakPath(name, slot + 1)
        local content = Compat.read(src)
        if content then
            Compat.write(dst, content)
            Compat.delete(src)
        end
    end
    -- Current file -> bak1
    local current = Compat.read(basePath(name))
    if current then
        Compat.write(bakPath(name, 1), current)
    end
end

-- ------------------------------------------------------------
-- Metadata
-- ------------------------------------------------------------
local function writeMeta(name, data)
    local meta = {
        name         = name,
        lastUsed     = os.time(),
        elementCount = 0,
        themeName    = data.theme or "Default",
    }
    if type(data.elements) == "table" then
        for _ in pairs(data.elements) do
            meta.elementCount = meta.elementCount + 1
        end
    end
    -- Preserve createdAt if it already exists
    local existing = Compat.read(metaPath(name))
    if existing then
        local prev = Compat.decode(existing)
        if type(prev) == "table" and prev.createdAt then
            meta.createdAt = prev.createdAt
        end
    end
    if not meta.createdAt then meta.createdAt = meta.lastUsed end

    local encoded = Compat.encode(meta)
    if encoded then Compat.write(metaPath(name), encoded) end
end

function Backup:GetMeta(name)
    local raw = Compat.read(metaPath(name))
    if not raw then return nil end
    return Compat.decode(raw)
end

-- ------------------------------------------------------------
-- Listing backups
-- ------------------------------------------------------------
function Backup:ListFor(name)
    local out = {}
    for slot = 1, MAX_BACKUPS do
        local content = Compat.read(bakPath(name, slot))
        if content then
            local decoded = Compat.decode(content)
            local elemCount = 0
            if decoded and type(decoded.elements) == "table" then
                for _ in pairs(decoded.elements) do
                    elemCount = elemCount + 1
                end
            end
            table.insert(out, {
                slot         = slot,
                size         = #content,
                elementCount = elemCount,
                themeName    = decoded and decoded.theme or "?",
            })
        end
    end
    return out
end

-- ------------------------------------------------------------
-- Restore
-- ------------------------------------------------------------
function Backup:Restore(name, slot)
    if type(name) ~= "string" or type(slot) ~= "number" then return false end
    if slot < 1 or slot > MAX_BACKUPS then return false end

    local content = Compat.read(bakPath(name, slot))
    if not content then return false end

    -- Rotate the current file out before overwriting so the user
    -- can undo a restore if they pick the wrong backup
    rotateBackups(name)

    Compat.write(basePath(name), content)
    return true
end

-- ------------------------------------------------------------
-- Hook SaveConfig
-- ------------------------------------------------------------
local function hookWindow(W)
    if W._backupHooked then return end
    W._backupHooked = true

    local _origSave = W.SaveConfig
    W.SaveConfig = function(self, profileName)
        profileName = profileName or "default"
        -- Rotate BEFORE the save writes over the current file
        pcall(rotateBackups, profileName)
        local result = _origSave(self, profileName)
        -- Write metadata after the save completes
        pcall(function()
            local content = Compat.read(basePath(profileName))
            if content then
                local data = Compat.decode(content) or {}
                writeMeta(profileName, data)
            end
        end)
        return result
    end
end

local _origCreateWindow = LucidUI.CreateWindow
function LucidUI:CreateWindow(config)
    local W = _origCreateWindow(self, config)
    task.defer(function() pcall(hookWindow, W) end)
    return W
end

LucidUI:OnCleanup(function()
    print("[LucidUI] ConfigBackup cleaned up")
end)

end

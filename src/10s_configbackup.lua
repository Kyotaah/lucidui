-- ============================================================
-- Module: 10s_configbackup.lua
-- ============================================================
--[[
    Config Backup + Metadata.

    On every SaveConfig:
      • Rotates current.json -> current.bak1.json -> .bak2.json ... -> .bak5.json
      • Writes {name}.meta.json with lastUsed, createdAt, elementCount, themeName

    On every LoadConfig:
      • Updates lastUsed in the meta sidecar

    Public API:
      LucidUI.ConfigBackup.ListBackups(name) -> { 1, 2, 3, 4, 5 }
      LucidUI.ConfigBackup.RestoreBackup(name, index) -> bool
]]

do

if not LucidUI or not LucidUI.Window then return end

-- ------------------------------------------------------------
-- File helpers (guarded for executors without FS)
-- ------------------------------------------------------------
local function isFile(path)
    if type(isfile) ~= "function" then return false end
    local ok, res = pcall(isfile, path)
    return ok and res == true
end

local function readFile(path)
    if type(readfile) ~= "function" then return nil end
    local ok, content = pcall(readfile, path)
    return ok and content or nil
end

local function writeFile(path, content)
    if type(writefile) ~= "function" then return false end
    return (pcall(writefile, path, content))
end

local function deleteFile(path)
    if type(delfile) ~= "function" then return false end
    return (pcall(delfile, path))
end

local function moveFile(from, to)
    if not isFile(from) then return false end
    local content = readFile(from)
    if not content then return false end
    if isFile(to) then deleteFile(to) end
    if not writeFile(to, content) then return false end
    deleteFile(from)
    return true
end

-- ------------------------------------------------------------
-- Path helpers
-- ------------------------------------------------------------
local CONFIG_DIR = "LucidUI/Configs"

local function configPath(name)   return CONFIG_DIR .. "/" .. tostring(name) .. ".json" end
local function metaPath(name)     return CONFIG_DIR .. "/" .. tostring(name) .. ".meta.json" end
local function backupPath(name, i)
    return CONFIG_DIR .. "/" .. tostring(name) .. ".bak" .. i .. ".json"
end

-- ------------------------------------------------------------
-- Rotation
-- ------------------------------------------------------------
local MAX_BACKUPS = 5

local function rotateBackups(name)
    -- Delete the oldest first (bak5)
    deleteFile(backupPath(name, MAX_BACKUPS))

    -- Slide everything up: bak4 -> bak5, bak3 -> bak4, ...
    for i = MAX_BACKUPS - 1, 1, -1 do
        moveFile(backupPath(name, i), backupPath(name, i + 1))
    end

    -- Current -> bak1
    moveFile(configPath(name), backupPath(name, 1))
end

-- ------------------------------------------------------------
-- Metadata sidecar
-- ------------------------------------------------------------
local function readMeta(name)
    local raw = readFile(metaPath(name))
    if not raw then return {} end
    local data = Compat.decode(raw)
    return type(data) == "table" and data or {}
end

local function writeMeta(name, meta)
    local encoded = Compat.encode(meta)
    if encoded then writeFile(metaPath(name), encoded) end
end

local function touchMetaOnSave(W, name)
    local meta = readMeta(name)
    meta.createdAt   = meta.createdAt or os.time()
    meta.lastUsed    = os.time()
    meta.elementCount = 0
    for _ in pairs(W._elementsByFlag or {}) do
        meta.elementCount = meta.elementCount + 1
    end
    meta.themeName = W._customThemeActive and "Custom" or (W.ThemeName or "Default")
    meta.version   = "0.10.0"
    writeMeta(name, meta)
end

local function touchMetaOnLoad(name)
    local meta = readMeta(name)
    if next(meta) == nil then return end
    meta.lastUsed = os.time()
    writeMeta(name, meta)
end

-- ------------------------------------------------------------
-- Hook SaveConfig / LoadConfig
-- ------------------------------------------------------------
local _origSave = LucidUI.Window.SaveConfig
function LucidUI.Window:SaveConfig(name)
    name = name or "default"
    pcall(rotateBackups, name)
    local result = _origSave(self, name)
    pcall(touchMetaOnSave, self, name)
    return result
end

local _origLoad = LucidUI.Window.LoadConfig
function LucidUI.Window:LoadConfig(name)
    name = name or "default"
    local result = _origLoad(self, name)
    pcall(touchMetaOnLoad, name)
    return result
end

-- ------------------------------------------------------------
-- Public API
-- ------------------------------------------------------------
LucidUI.ConfigBackup = LucidUI.ConfigBackup or {}

function LucidUI.ConfigBackup.ListBackups(name)
    local out = {}
    for i = 1, MAX_BACKUPS do
        if isFile(backupPath(name, i)) then table.insert(out, i) end
    end
    return out
end

function LucidUI.ConfigBackup.RestoreBackup(name, index)
    local path = backupPath(name, index)
    if not isFile(path) then return false end
    local content = readFile(path)
    if not content then return false end
    if not writeFile(configPath(name), content) then return false end
    LucidUI:Notify({
        Title = "Backup Restored",
        Message = name .. " from .bak" .. index,
        Variant = "success",
        Duration = 3,
    })
    return true
end

function LucidUI.ConfigBackup.GetMeta(name)
    return readMeta(name)
end

LucidUI:OnCleanup(function()
    print("[LucidUI] ConfigBackup cleaned up")
end)

end

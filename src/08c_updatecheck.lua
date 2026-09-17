--[[
    Auto-Update Checker — fetches version.json from GitHub on load,
    compares against LucidUI._version, and notifies the user if a
    newer release exists.

    Fails silently if the network is down, the file is missing, or
    the version format is unrecognized. Never blocks the hub.

    Developers can opt out by calling:
        LucidUI:DisableUpdateCheck()

    Or by passing to CreateWindow:
        CreateWindow({ CheckForUpdates = false })
]]

-- ============================================================
-- Config
-- ============================================================
local UPDATE_URL = "https://raw.githubusercontent.com/Kyotaah/lucidui/main/version.json"

LucidUI._updateCheckEnabled = true
LucidUI._updateChecked       = false
LucidUI._updateNotified      = false

-- ============================================================
-- Version parsing — supports "1.2.3", "1.2", "1"
-- ============================================================
local function parseVersion(str)
    if type(str) ~= "string" then return 0, 0, 0 end
    str = str:gsub("^%s+", ""):gsub("%s+$", "")

    local major, minor, patch = str:match("^(%d+)%.(%d+)%.(%d+)")
    if major then
        return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
    end

    major, minor = str:match("^(%d+)%.(%d+)")
    if major then
        return tonumber(major) or 0, tonumber(minor) or 0, 0
    end

    major = str:match("^(%d+)")
    if major then
        return tonumber(major) or 0, 0, 0
    end

    return 0, 0, 0
end

local function isNewer(current, latest)
    local cMaj, cMin, cPat = parseVersion(current)
    local lMaj, lMin, lPat = parseVersion(latest)
    if lMaj ~= cMaj then return lMaj > cMaj end
    if lMin ~= cMin then return lMin > cMin end
    return lPat > cPat
end

-- ============================================================
-- Public API
-- ============================================================
function LucidUI:DisableUpdateCheck()
    self._updateCheckEnabled = false
end

function LucidUI:CheckForUpdates(silent)
    if not self._updateCheckEnabled then return end
    if self._updateChecked then return end
    self._updateChecked = true

    task.spawn(function()
        -- Fetch version.json
        local ok, body = pcall(function()
            return game:HttpGet(UPDATE_URL .. "?t=" .. os.time(), true)
        end)
        if not ok or not body or #body < 10 then
            return -- silent fail
        end

        -- Strip UTF-8 BOM if present
        if body:sub(1, 3) == "\239\187\191" then
            body = body:sub(4)
        end

        -- Parse JSON
        local data = Compat and Compat.decode and Compat.decode(body)
        if type(data) ~= "table" or not data.version then
            return -- silent fail
        end

        local current = self._version or "0.0.0"
        if not isNewer(current, data.version) then
            return -- we're up to date
        end

        if self._updateNotified then return end
        self._updateNotified = true

        -- Give the UI a moment to settle first
        task.delay(2.5, function()
            local msg = "v" .. current .. " → v" .. tostring(data.version)
            if data.changelog then
                msg = msg .. "\n" .. tostring(data.changelog)
            end

            pcall(function()
                LucidUI:Notify({
                    Title    = "Update Available",
                    Message  = msg,
                    Duration = 8,
                    Variant  = "warn",
                })
            end)

            if not silent then
                print("[LucidUI] Update available — current: v" .. current ..
                      " | latest: v" .. tostring(data.version))
                if data.url then
                    print("[LucidUI] Download: " .. tostring(data.url))
                end
            end
        end)
    end)
end

-- ============================================================
-- Hook CreateWindow so CheckForUpdates = false is honored
-- ============================================================
local _origCreateWindow = LucidUI.CreateWindow
function LucidUI:CreateWindow(config)
    if config and config.CheckForUpdates == false then
        self:DisableUpdateCheck()
    end
    return _origCreateWindow(self, config)
end

-- ============================================================
-- Run the check ~1s after load, once the library is fully initialized
-- ============================================================
task.delay(1, function()
    pcall(function() LucidUI:CheckForUpdates() end)
end)

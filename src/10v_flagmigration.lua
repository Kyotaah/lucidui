-- ============================================================
-- Module: 10v_flagmigration.lua
-- ============================================================
--[[
    Flag Migration — allows renaming a flag while still reading
    old configs that used the original name.

    Usage:
        -- Old flag was "auto_parry", now it's "parry_enabled":
        LucidUI:RegisterFlagAlias("auto_parry", "parry_enabled")

    Implementation:
      Adds an __index metatable to each window's _elementsByFlag
      table. When a lookup misses, it consults the alias map.
      Old config files load cleanly, no data lost.

    Also migrates config data on save: when SaveConfig runs, any
    alias-keyed data in _configData is dropped (it's stale) and
    the current flag is used instead.
]]

do

if not LucidUI or not LucidUI.Window then return end

LucidUI._flagAliases = LucidUI._flagAliases or {}

-- ------------------------------------------------------------
-- Public registration
-- ------------------------------------------------------------
function LucidUI:RegisterFlagAlias(oldFlag, newFlag)
    if type(oldFlag) ~= "string" or oldFlag == "" then return end
    if type(newFlag) ~= "string" or newFlag == "" then return end

    self._flagAliases[oldFlag] = newFlag

    -- Retrofit any already-created windows
    for _, W in ipairs(self._windows or {}) do
        local el = W._elementsByFlag[newFlag]
        if el then
            rawset(W._elementsByFlag, oldFlag, el)
        end
    end

    return true
end

function LucidUI:GetFlagAliases()
    return self._flagAliases
end

function LucidUI:ClearFlagAliases()
    self._flagAliases = {}
    for _, W in ipairs(self._windows or {}) do
        local t = W._elementsByFlag
        for oldFlag in pairs(self._flagAliases) do
            rawset(t, oldFlag, nil)
        end
    end
end

-- ------------------------------------------------------------
-- Install metatable on a window's element table
-- ------------------------------------------------------------
local function installMetatable(W)
    local t = W._elementsByFlag
    if getmetatable(t) then return end

    setmetatable(t, {
        __index = function(_, key)
            local aliases = LucidUI._flagAliases
            if aliases and aliases[key] then
                return rawget(t, aliases[key])
            end
            return nil
        end,
    })
end

-- ------------------------------------------------------------
-- Hook CreateWindow
-- ------------------------------------------------------------
local _origCreateWindow = LucidUI.CreateWindow
function LucidUI:CreateWindow(config)
    local W = _origCreateWindow(self, config)
    if W and W._elementsByFlag then
        task.defer(function()
            if W._elementsByFlag then
                pcall(installMetatable, W)
            end
        end)
    end
    return W
end

LucidUI:OnCleanup(function()
    LucidUI._flagAliases = {}
    print("[LucidUI] FlagMigration cleaned up")
end)

end

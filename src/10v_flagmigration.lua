-- ============================================================
-- Module: 10v_flagmigration.lua
-- ============================================================
--[[
    Flag Migration — register a mapping from an old flag name to
    its new name. When LoadConfig encounters an old flag, it's
    rewritten to the new name before applying.

    Usage in your hub script:
      LucidUI:RegisterFlagAlias("auto_parry", "parry_enabled")

    Then when a user loads an old config with `auto_parry`, the
    library transparently applies it to the `parry_enabled` element.

    Non-destructive: the config file itself isn't modified on
    disk until the next SaveConfig. The mapping is only applied
    at load time.
]]

do

if not LucidUI or not Compat then return end

LucidUI._flagAliases = LucidUI._flagAliases or {}

function LucidUI:RegisterFlagAlias(oldFlag, newFlag)
    if type(oldFlag) ~= "string" or type(newFlag) ~= "string" then
        warn("[LucidUI] RegisterFlagAlias: both args must be strings")
        return false
    end
    self._flagAliases[oldFlag] = newFlag
    return true
end

function LucidUI:ResolveFlag(flag)
    local seen = {}
    while self._flagAliases[flag] do
        if seen[flag] then break end  -- cycle guard
        seen[flag] = true
        flag = self._flagAliases[flag]
    end
    return flag
end

-- Hook LoadConfig indirectly by wrapping the element lookup.
-- We can't patch `_elementsByFlag` directly, so we intercept at
-- the LoadConfig level. Every module that has its own LoadConfig
-- (per-game configs) also benefits because it eventually calls
-- `window:LoadConfig` or reads `_elementsByFlag` via the same path.
local _origLoadConfig = LucidUI.Window.LoadConfig
function LucidUI.Window:LoadConfig(profileName)
    -- Before loading, translate old flag names in the raw JSON
    local path = "LucidUI/Configs/" .. (profileName or "default") .. ".json"
    local raw = Compat.read(path)
    if raw then
        local data = Compat.decode(raw)
        if type(data) == "table" and type(data.elements) == "table" then
            local rewritten = false
            local newElements = {}
            for flag, value in pairs(data.elements) do
                local resolved = LucidUI:ResolveFlag(flag)
                if resolved ~= flag then
                    rewritten = true
                end
                newElements[resolved] = value
            end
            if rewritten then
                data.elements = newElements
                local encoded = Compat.encode(data)
                if encoded then
                    -- Write the migrated version to a temp path,
                    -- load it, then clean up
                    local tmpPath = path .. ".migrated"
                    Compat.write(tmpPath, encoded)

                    -- Temporarily swap the file, run LoadConfig, swap back
                    local backup = raw
                    Compat.write(path, encoded)
                    local result = _origLoadConfig(self, profileName)
                    Compat.write(path, backup)
                    Compat.delete(tmpPath)
                    return result
                end
            end
        end
    end
    return _origLoadConfig(self, profileName)
end

LucidUI:OnCleanup(function()
    LucidUI._flagAliases = {}
    print("[LucidUI] FlagMigration cleaned up")
end)

end

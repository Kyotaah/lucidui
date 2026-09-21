-- ============================================================
-- Module: 10w_instanceguard.lua
-- ============================================================
--[[
    Multi-Instance Guard — prevents a hub from running twice in the
    same game session, which causes duplicate UIs, conflicting
    flags, and double-firing callbacks.

    Refuses to build a second window unless the caller explicitly
    opts in via CreateWindow({ AllowMultiple = true }).

    The lock lives in getgenv().LucidUI_InstanceLock and is cleared
    by 00b_cleanup.lua on re-execute, so re-running the script
    works as expected.

    Opt-out:
      CreateWindow({ AllowMultiple = true })
      LucidUI:SetMultiInstanceAllowed(true)
]]

do

if not LucidUI or not LucidUI.Window then return end

local LOCK_KEY = "LucidUI_InstanceLock"

LucidUI._multiInstanceAllowed = false

function LucidUI:SetMultiInstanceAllowed(on)
    self._multiInstanceAllowed = on and true or false
    if on and getgenv() then
        getgenv()[LOCK_KEY] = nil
    end
end

local _origCreateWindow = LucidUI.CreateWindow
function LucidUI:CreateWindow(config)
    config = config or {}

    local gg = getgenv and getgenv()
    local alreadyLocked = gg and gg[LOCK_KEY]

    local override = config.AllowMultiple == true or LucidUI._multiInstanceAllowed

    if alreadyLocked and not override then
        warn("[LucidUI] Instance already running. Pass AllowMultiple = true to override.")
        return nil
    end

    local W = _origCreateWindow(self, config)

    if W and gg and not override then
        gg[LOCK_KEY] = os.time()
    end

    return W
end

-- 00b_cleanup.lua already clears getgenv().LucidUI on re-execute,
-- but not the lock. Clear it here so a fresh script run always
-- gets a clean slate.
LucidUI:OnCleanup(function()
    local gg = getgenv and getgenv()
    if gg then gg[LOCK_KEY] = nil end
    print("[LucidUI] InstanceGuard cleaned up")
end)

end

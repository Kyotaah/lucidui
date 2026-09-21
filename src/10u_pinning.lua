-- ============================================================
-- Module: 10u_pinning.lua
-- ============================================================
--[[
    Persistent Element Pinning.

    The context menu (10b) sets obj.Instance.LayoutOrder = -1000
    when the user pins a flag. This module captures that state on
    save and reapplies it on load.

    Storage key inside configs: _lucid_pinned_flags
]]

do

if not LucidUI or not LucidUI.Window then return end

local PINNED_ORDER = -1000
local STORAGE_KEY  = "_lucid_pinned_flags"

-- ------------------------------------------------------------
-- Capture current pin state from LayoutOrder
-- ------------------------------------------------------------
local function capturePinned(W)
    local pinned = {}
    for flag, obj in pairs(W._elementsByFlag or {}) do
        if obj and obj.Instance and obj.Instance.Parent then
            if obj.Instance.LayoutOrder == PINNED_ORDER then
                pinned[flag] = true
            end
        end
    end
    return pinned
end

-- ------------------------------------------------------------
-- Apply pinned layout after load
-- ------------------------------------------------------------
local function applyPinned(W, pinned)
    if type(pinned) ~= "table" then return end
    for flag, isPinned in pairs(pinned) do
        if isPinned then
            local obj = W._elementsByFlag[flag]
            if obj and obj.Instance and obj.Instance.Parent then
                obj.Instance.LayoutOrder = PINNED_ORDER
            end
        end
    end
end

-- ------------------------------------------------------------
-- Hook SaveConfig / LoadConfig
-- ------------------------------------------------------------
local _origSave = LucidUI.Window.SaveConfig
function LucidUI.Window:SaveConfig(name)
    local pinned = capturePinned(self)
    local prev = self._configData[STORAGE_KEY]
    self._configData[STORAGE_KEY] = next(pinned) and pinned or nil

    local result = _origSave(self, name)

    if prev then
        self._configData[STORAGE_KEY] = prev
    else
        self._configData[STORAGE_KEY] = nil
    end

    return result
end

local _origLoad = LucidUI.Window.LoadConfig
function LucidUI.Window:LoadConfig(name)
    name = name or "default"
    local path = "LucidUI/Configs/" .. name .. ".json"

    local data
    if type(readfile) == "function" then
        local ok, content = pcall(readfile, path)
        if ok and content then
            data = Compat.decode(content)
        end
    end

    local result = _origLoad(self, name)

    if data and data.elements and type(data.elements[STORAGE_KEY]) == "table" then
        task.defer(function()
            if self.Gui and self.Gui.Parent then
                pcall(applyPinned, self, data.elements[STORAGE_KEY])
            end
        end)
    end

    return result
end

-- ------------------------------------------------------------
-- Public API
-- ------------------------------------------------------------
function LucidUI.Window:PinElement(flag)
    local obj = self._elementsByFlag[flag]
    if not obj or not obj.Instance then return false end
    obj.Instance.LayoutOrder = PINNED_ORDER
    return true
end

function LucidUI.Window:UnpinElement(flag)
    local obj = self._elementsByFlag[flag]
    if not obj or not obj.Instance then return false end
    obj.Instance.LayoutOrder = 1000
    return true
end

function LucidUI.Window:IsPinned(flag)
    local obj = self._elementsByFlag[flag]
    return obj and obj.Instance and obj.Instance.LayoutOrder == PINNED_ORDER
end

LucidUI:OnCleanup(function()
    print("[LucidUI] Pinning cleaned up")
end)

end

-- ============================================================
-- Module: 10x_undo.lua
-- ============================================================
--[[
    Session Undo / Redo.

    Tracks every element Set() call in a per-window history stack.
    Ctrl+Z pops and applies the old value. Ctrl+Y reverses.

    Features:
      • 50-entry cap per window
      • Redo stack clears on any new change
      • Config loads reset both stacks (loading isn't undoable)
      • Optional toast — Enable with LucidUI:SetUndoToasts(true)
        to show an "Undo" action on the first change of every burst
      • Coalesces bursts: only the first change in a 1.5s window
        fires a toast

    Public API:
      LucidUI:Undo(window?)       -> bool applied
      LucidUI:Redo(window?)       -> bool applied
      LucidUI:ClearUndoHistory(window?)
      LucidUI:SetUndoToasts(on)
      LucidUI:GetUndoStack(window?) -> { {flag, old, new}, ... }

    Implementation:
      Installs a metatable on W._elementsByFlag with __newindex.
      The first time a flag is registered, its obj.Set is wrapped
      to record (flag, oldValue, newValue) before and after the
      call. Subsequent registrations of the same flag don't fire
      __newindex (Lua semantics) — which is fine since flag
      re-registration is a hub bug, not a library concern.
]]

do

if not LucidUI or not LucidUI.Window then return end

local UserInputService = game:GetService("UserInputService")

local MAX_HISTORY     = 50
local TOAST_COOLDOWN  = 1.5

LucidUI._undoToasts       = false
LucidUI._lastChangedWin   = nil
LucidUI._lastToastAt      = 0

-- ------------------------------------------------------------
-- Stacks
-- ------------------------------------------------------------
local function ensureStacks(W)
    if not W._undoStack then W._undoStack = {} end
    if not W._redoStack then W._redoStack = {} end
end

local function recordChange(W, flag, oldValue, newValue)
    if W._undoSuppressed then return end
    if oldValue == newValue then return end
    if oldValue == nil then return end  -- can't undo to nothing

    ensureStacks(W)

    table.insert(W._undoStack, {
        flag     = flag,
        oldValue = oldValue,
        newValue = newValue,
        time     = tick(),
    })
    if #W._undoStack > MAX_HISTORY then
        table.remove(W._undoStack, 1)
    end

    W._redoStack = {}
    LucidUI._lastChangedWin = W

    -- Optional toast (coalesced)
    if LucidUI._undoToasts then
        local now = tick()
        if now - LucidUI._lastToastAt >= TOAST_COOLDOWN then
            LucidUI._lastToastAt = now
            pcall(function()
                LucidUI:Notify({
                    Title = "Changed",
                    Message = flag,
                    Variant = "info",
                    Duration = 3,
                    Action = {
                        Label = "Undo",
                        Callback = function() LucidUI:Undo(W) end,
                    },
                    ActionTimeout = 4,
                })
            end)
        end
    end
end

-- ------------------------------------------------------------
-- Install capture on a window
-- ------------------------------------------------------------
local function installCapture(W)
    local t = W._elementsByFlag
    if not t or getmetatable(t) then return end

    setmetatable(t, {
        __newindex = function(tbl, flag, obj)
            rawset(tbl, flag, obj)

            if obj
                and type(obj.Set) == "function"
                and not obj._undoWrapped
            then
                obj._undoWrapped = true
                local origSet = obj.Set

                obj.Set = function(self, value, ...)
                    local oldValue = W._configData[flag]
                    local ok, err = pcall(origSet, self, value, ...)
                    if not ok then error(err, 0) end
                    pcall(recordChange, W, flag, oldValue, value)
                end
            end
        end,
    })
end

-- ------------------------------------------------------------
-- Undo / Redo
-- ------------------------------------------------------------
local function applyValue(W, flag, value)
    local obj = W._elementsByFlag[flag]
    if not obj or type(obj.Set) ~= "function" then return false end

    W._undoSuppressed = true
    local ok = pcall(function() obj:Set(value) end)
    W._undoSuppressed = false

    return ok
end

function LucidUI:Undo(W)
    W = W or self._lastChangedWin
    if not W then return false end
    ensureStacks(W)

    local entry = table.remove(W._undoStack)
    if not entry then return false end

    if not applyValue(W, entry.flag, entry.oldValue) then
        table.insert(W._undoStack, entry)
        return false
    end

    table.insert(W._redoStack, entry)
    return true
end

function LucidUI:Redo(W)
    W = W or self._lastChangedWin
    if not W then return false end
    ensureStacks(W)

    local entry = table.remove(W._redoStack)
    if not entry then return false end

    if not applyValue(W, entry.flag, entry.newValue) then
        table.insert(W._redoStack, entry)
        return false
    end

    table.insert(W._undoStack, entry)
    return true
end

function LucidUI:ClearUndoHistory(W)
    W = W or self._lastChangedWin
    if not W then
        for _, w in ipairs(self._windows or {}) do
            w._undoStack = {}
            w._redoStack = {}
        end
        return
    end
    W._undoStack = {}
    W._redoStack = {}
end

function LucidUI:GetUndoStack(W)
    W = W or self._lastChangedWin
    if not W or not W._undoStack then return {} end
    return W._undoStack
end

function LucidUI:SetUndoToasts(on)
    self._undoToasts = on and true or false
end

-- ------------------------------------------------------------
-- Hooks
-- ------------------------------------------------------------
local _origCreateWindow = LucidUI.CreateWindow
function LucidUI:CreateWindow(config)
    local W = _origCreateWindow(self, config)
    task.defer(function()
        if W and W._elementsByFlag then
            pcall(installCapture, W)
        end
    end)
    return W
end

-- Suppress + clear history during config load
local _origLoad = LucidUI.Window.LoadConfig
function LucidUI.Window:LoadConfig(name)
    self._undoSuppressed = true
    local result = _origLoad(self, name)
    self._undoSuppressed = false
    self._undoStack = {}
    self._redoStack = {}
    return result
end

-- ------------------------------------------------------------
-- Ctrl+Z / Ctrl+Y
-- ------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
              or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
    local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
               or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

    if not ctrl then return end

    if input.KeyCode == Enum.KeyCode.Z then
        if shift then
            LucidUI:Redo()
        else
            LucidUI:Undo()
        end
    elseif input.KeyCode == Enum.KeyCode.Y then
        LucidUI:Redo()
    end
end)

LucidUI:OnCleanup(function()
    LucidUI._undoToasts     = false
    LucidUI._lastChangedWin = nil
    LucidUI._lastToastAt    = 0
    for _, w in ipairs(LucidUI._windows or {}) do
        w._undoStack = {}
        w._redoStack = {}
    end
    print("[LucidUI] Undo cleaned up")
end)

end

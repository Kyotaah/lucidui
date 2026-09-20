-- ============================================================
-- Module: 08l_hotkeys.lua
-- ============================================================
--[[
    Global Hotkey Registry — one place to register every keybind
    in your hub, with persistence, conflict detection, and a live
    rebind UI in the settings panel.

    WHY
      Every hub ends up writing the same boilerplate:
          UIS.InputBegan:Connect(function(input, processed)
              if processed then return end
              if input.KeyCode == Enum.KeyCode.R then
                  -- toggle something
              end
          end)

      This module replaces that with one registration per hotkey.
      Rebinding, persistence, conflict warnings, and a settings
      panel row are all automatic.

    USAGE
      LucidUI:RegisterHotkey({
          Id       = "aim_toggle",       -- unique, required, used for saving
          Name     = "Toggle Aim",       -- shown in the settings panel
          Default  = Enum.KeyCode.R,     -- first-run binding
          Category = "Combat",           -- grouping in the settings panel
          Callback = function()
              AimEnabled = not AimEnabled
          end,
          -- Optional:
          OnRelease   = function() end,  -- fires on key up
          AllowInChat = false,           -- ignore while typing in chat
      })

    API
      LucidUI:RegisterHotkey(opts)          -> hotkey object or nil
      LucidUI:GetHotkey(id)                 -> hotkey object or nil
      LucidUI:GetAllHotkeys()               -> { hotkey, ... }
      LucidUI:SetHotkey(id, keycode)        -> true on success
      LucidUI:ResetHotkey(id)               -> true on success
      LucidUI:ResetAllHotkeys()             -> true
      LucidUI:SetHotkeysEnabled(bool)       -> master kill switch
      LucidUI:AreHotkeysEnabled()           -> bool
      LucidUI:ClearHotkeyConflicts()        -> { [id] = { id2, id3 } }

    The hotkey object exposes:
      .Id       .Name       .Category
      .Key      .Default
      .Enabled  .AllowInChat
      :SetKey(kc)     :GetKey()      :Reset()
      :Enable(on)     :Disable()
      :Destroy()

    PERSISTENCE
      Saved to LucidUI/Hotkeys.json. Loaded at module load, so
      user bindings survive between sessions on executors with
      filesystem access. No-ops gracefully without FS.
]]

local UserInputService = game:GetService("UserInputService")

-- ============================================================
-- State
-- ============================================================
local REGISTRY   = {}   -- [id] = hotkey
local ORDER      = {}   -- preserve registration order
local SAVE_PATH  = "LucidUI/Hotkeys.json"

LucidUI._hotkeys           = REGISTRY
LucidUI._hotkeysEnabled    = true
LucidUI._hotkeyListeners   = {}   -- [id] = { done = function, cancel = function }
LucidUI._hotkeyConnections = {}

-- ============================================================
-- Persistence
-- ============================================================
local function loadSaved()
    if not Compat or not Compat.read then return {} end
    local raw = Compat.read(SAVE_PATH)
    if not raw then return {} end
    local data = Compat.decode(raw)
    if type(data) ~= "table" then return {} end
    return data.bindings or {}
end

local function persist()
    if not Compat or not Compat.write then return end
    local bindings = {}
    for id, hk in pairs(REGISTRY) do
        if hk.Key then
            bindings[id] = hk.Key.Name
        end
    end
    local encoded = Compat.encode({ v = 1, bindings = bindings })
    if encoded then
        Compat.write(SAVE_PATH, encoded)
    end
end

local saved = loadSaved()

-- ============================================================
-- Hotkey object
-- ============================================================
local Hotkey = {}
Hotkey.__index = Hotkey

function Hotkey:GetKey()      return self.Key end
function Hotkey:SetKey(kc)    self.Key = kc   persist()  return true end
function Hotkey:Reset()
    self.Key = self.Default
    persist()
    return true
end
function Hotkey:Enable(on)
    self.Enabled = on and true or false
    if self._onEnabledChanged then self._onEnabledChanged(self) end
end
function Hotkey:Disable()      self:Enable(false) end
function Hotkey:Destroy()
    REGISTRY[self.Id] = nil
    for i, id in ipairs(ORDER) do
        if id == self.Id then table.remove(ORDER, i) break end
    end
    if LucidUI._hotkeyListeners[self.Id] then
        pcall(LucidUI._hotkeyListeners[self.Id].cancel)
        LucidUI._hotkeyListeners[self.Id] = nil
    end
    persist()
end

-- ============================================================
-- Public registration
-- ============================================================
function LucidUI:RegisterHotkey(opts)
    opts = opts or {}
    local id = opts.Id
    if type(id) ~= "string" or id == "" then
        warn("[LucidUI] RegisterHotkey: opts.Id is required")
        return nil
    end
    if REGISTRY[id] then
        warn("[LucidUI] RegisterHotkey: duplicate Id '" .. id .. "'")
        return REGISTRY[id]
    end

    local hk = setmetatable({}, Hotkey)
    hk.Id          = id
    hk.Name        = opts.Name or id
    hk.Category    = opts.Category or "General"
    hk.Default     = opts.Default or Enum.KeyCode.Unknown
    hk.Callback    = opts.Callback
    hk.OnRelease   = opts.OnRelease
    hk.AllowInChat = opts.AllowInChat == true
    hk.Enabled     = opts.Enabled ~= false

    -- Prefer the saved binding, fall back to Default
    local savedName = saved[id]
    if type(savedName) == "string" and savedName ~= "" then
        local ok, kc = pcall(function() return Enum.KeyCode[savedName] end)
        if ok and kc then
            hk.Key = kc
        end
    end
    if not hk.Key then hk.Key = hk.Default end

    REGISTRY[id] = hk
    table.insert(ORDER, id)

    -- If the settings panel is already built, refresh its list
    for _, win in ipairs(LucidUI._windows or {}) do
        if win._hotkeyListRefresh then
            pcall(win._hotkeyListRefresh)
            break
        end
    end

    return hk
end

function LucidUI:GetHotkey(id)         return REGISTRY[id] end
function LucidUI:GetAllHotkeys()
    local out = {}
    for _, id in ipairs(ORDER) do
        local hk = REGISTRY[id]
        if hk then table.insert(out, hk) end
    end
    return out
end

function LucidUI:SetHotkey(id, kc)
    local hk = REGISTRY[id]
    if not hk then return false end
    return hk:SetKey(kc)
end

function LucidUI:ResetHotkey(id)
    local hk = REGISTRY[id]
    if not hk then return false end
    return hk:Reset()
end

function LucidUI:ResetAllHotkeys()
    for _, hk in pairs(REGISTRY) do hk:Reset() end
    return true
end

function LucidUI:SetHotkeysEnabled(on)
    LucidUI._hotkeysEnabled = on and true or false
end

function LucidUI:AreHotkeysEnabled()
    return LucidUI._hotkeysEnabled
end

-- Return a map of { [id] = { otherId, otherId, ... } } for any key
-- bound to more than one hotkey.
function LucidUI:GetHotkeyConflicts()
    local byKey = {}
    for id, hk in pairs(REGISTRY) do
        if hk.Key and hk.Key ~= Enum.KeyCode.Unknown then
            local k = hk.Key.Name
            byKey[k] = byKey[k] or {}
            table.insert(byKey[k], id)
        end
    end
    local conflicts = {}
    for _, ids in pairs(byKey) do
        if #ids > 1 then
            for _, id in ipairs(ids) do
                conflicts[id] = {}
                for _, other in ipairs(ids) do
                    if other ~= id then
                        table.insert(conflicts[id], other)
                    end
                end
            end
        end
    end
    return conflicts
end

-- ============================================================
-- Key event dispatch
-- ============================================================
local function matchesModifiers(input, required)
    -- input has KeyCode for keyboard events; we do not track held
    -- modifiers separately here for simplicity. If you want
    -- modifier support later, extend the registration schema.
    return true
end

local function onInputBegan(input, processed)
    if not LucidUI._hotkeysEnabled then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if not input.KeyCode then return end

    -- If a rebind listener is open, it consumes the key
    for id, listener in pairs(LucidUI._hotkeyListeners) do
        if listener.active then
            local action = listener.onKey(input.KeyCode)
            if action == "handled" then
                return
            end
        end
    end

    for _, id in ipairs(ORDER) do
        local hk = REGISTRY[id]
        if hk and hk.Enabled and hk.Key == input.KeyCode then
            if processed and not hk.AllowInChat then
                -- Input was consumed by chat or a text box; skip
            else
                if hk.Callback then
                    pcall(hk.Callback)
                end
            end
        end
    end
end

local function onInputEnded(input)
    if not LucidUI._hotkeysEnabled then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if not input.KeyCode then return end

    for _, id in ipairs(ORDER) do
        local hk = REGISTRY[id]
        if hk and hk.Enabled and hk.Key == input.KeyCode and hk.OnRelease then
            pcall(hk.OnRelease)
        end
    end
end

table.insert(LucidUI._hotkeyConnections,
    UserInputService.InputBegan:Connect(onInputBegan))
table.insert(LucidUI._hotkeyConnections,
    UserInputService.InputEnded:Connect(onInputEnded))

-- ============================================================
-- Settings panel section
-- ============================================================
function LucidUI.Window:_buildHotkeySettings()
    self:_addSettingSection("Hotkeys")

    -- Master toggle
    local masterRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 44),
    })
    Corner(10, masterRow)
    self:_addSettingFrame(masterRow)

    local masterLbl = Create("TextLabel", {
        Text = "Hotkeys Enabled",
        Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -80, 1, 0),
        Parent = masterRow,
    })

    local masterTrack = Create("Frame", {
        Size = UDim2.fromOffset(44, 24),
        Position = UDim2.new(1, -58, 0.5, -12),
        BackgroundColor3 = LucidUI._hotkeysEnabled and self.Theme.Accent or self.Theme.ToggleOff,
        BorderSizePixel = 0, Parent = masterRow,
    })
    Corner(12, masterTrack)

    local masterKnob = Create("Frame", {
        Size = UDim2.fromOffset(20, 20),
        Position = LucidUI._hotkeysEnabled
            and UDim2.new(1, -22, 0.5, -10)
            or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0, Parent = masterTrack,
    })
    Corner(10, masterKnob)

    local masterClick = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = masterRow,
    })
    BindTap(masterClick, function()
        local on = not LucidUI._hotkeysEnabled
        LucidUI:SetHotkeysEnabled(on)
        local t = self.Theme
        Tween(masterTrack, 0.22, {
            BackgroundColor3 = on and t.Accent or t.ToggleOff,
        }, Enum.EasingStyle.Quart):Play()
        Tween(masterKnob, 0.22, {
            Position = on and UDim2.new(1, -22, 0.5, -10) or UDim2.fromOffset(2, 2),
        }, Enum.EasingStyle.Quart):Play()
    end)

    -- Container that gets rebuilt when hotkeys are registered or rebound
    local list = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = self._spContent,
    })
    list.LayoutOrder = self._settingsOrder
    self._settingsOrder = self._settingsOrder + 1
    Create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = list,
    })

    local rowsByCategory = {}

    local function rebuild()
        -- Wipe
        for _, c in ipairs(list:GetChildren()) do
            if not c:IsA("UIListLayout") then
                c:Destroy()
            end
        end
        rowsByCategory = {}

        local order = 0
        local function nextOrder() order = order + 1 return order end

        local conflicts = LucidUI:GetHotkeyConflicts()

        -- Group by category, preserving registration order
        for _, hk in ipairs(LucidUI:GetAllHotkeys()) do
            local cat = hk.Category or "General"
            rowsByCategory[cat] = rowsByCategory[cat] or {}
            table.insert(rowsByCategory[cat], hk)
        end

        -- Emit categories alphabetically (General last so it appears
        -- at the bottom for the ever-present catch-all)
        local catNames = {}
        for cat in pairs(rowsByCategory) do
            table.insert(catNames, cat)
        end
        table.sort(catNames, function(a, b)
            if a == "General" then return false end
            if b == "General" then return true end
            return a:lower() < b:lower()
        end)

        for _, cat in ipairs(catNames) do
            -- Category header
            local head = Create("TextLabel", {
                Text = cat:upper(),
                Font = Enum.Font.GothamBold, TextSize = 10,
                TextColor3 = self.Theme.TextMuted, BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                Size = UDim2.new(1, 0, 0, 16),
                LayoutOrder = nextOrder(),
                Parent = list,
            })

            for _, hk in ipairs(rowsByCategory[cat]) do
                local conflict = conflicts[hk.Id]

                local row = Create("Frame", {
                    BackgroundColor3 = self.Theme.Surface,
                    BackgroundTransparency = self.Theme.SurfaceTrans,
                    Size = UDim2.new(1, 0, 0, 40),
                    LayoutOrder = nextOrder(),
                    Parent = list,
                })
                Corner(8, row)
                local rowStroke = Stroke(self.Theme.Border, 1,
                    (self.Theme.BorderTrans or 0.75) + 0.05, row)

                local nameLbl = Create("TextLabel", {
                    Text = hk.Name .. (conflict and "  ⚠" or ""),
                    Font = Enum.Font.GothamMedium, TextSize = 13,
                    TextColor3 = conflict and Color3.fromRGB(255, 190, 60) or self.Theme.TextPrimary,
                    BackgroundTransparency = 1,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Position = UDim2.fromOffset(12, 0),
                    Size = UDim2.new(1, -110, 1, 0),
                    Parent = row,
                })

                local keyBtn = Create("TextButton", {
                    Text = hk.Key and hk.Key.Name or "—",
                    Font = Enum.Font.GothamBold, TextSize = 12,
                    TextColor3 = self.Theme.TextPrimary,
                    BackgroundColor3 = self.Theme.Background,
                    BackgroundTransparency = 0.3,
                    AutoButtonColor = false,
                    Size = UDim2.fromOffset(82, 26),
                    Position = UDim2.new(1, -94, 0.5, -13),
                    Parent = row,
                })
                Corner(8, keyBtn)

                -- Show "..." while listening
                local listening = false
                local function startListening()
                    if listening then return end
                    listening = true
                    keyBtn.Text = "press…"
                    keyBtn.BackgroundColor3 = self.Theme.Accent
                    keyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)

                    local finished = false
                    local listener = {
                        active = true,
                        onKey = function(kc)
                            if finished then return "handled" end

                            if kc == Enum.KeyCode.Escape then
                                -- cancel
                                finished = true
                                listening = false
                                listener.active = false
                                LucidUI._hotkeyListeners[hk.Id] = nil
                                keyBtn.Text = hk.Key and hk.Key.Name or "—"
                                keyBtn.BackgroundColor3 = self.Theme.Background
                                keyBtn.TextColor3 = self.Theme.TextPrimary
                                return "handled"
                            end

                            if kc == Enum.KeyCode.Backspace or kc == Enum.KeyCode.Delete then
                                -- unbind
                                hk.Key = nil
                                persist()
                            else
                                hk:SetKey(kc)
                            end

                            finished = true
                            listening = false
                            listener.active = false
                            LucidUI._hotkeyListeners[hk.Id] = nil

                            keyBtn.Text = hk.Key and hk.Key.Name or "—"
                            keyBtn.BackgroundColor3 = self.Theme.Background
                            keyBtn.TextColor3 = self.Theme.TextPrimary

                            -- Refresh conflicts across the panel
                            task.defer(function()
                                if self._hotkeyListRefresh then
                                    pcall(self._hotkeyListRefresh)
                                end
                            end)

                            return "handled"
                        end,
                    }
                    LucidUI._hotkeyListeners[hk.Id] = listener
                end

                BindTap(keyBtn, startListening, { MoveThreshold = 8 })

                keyBtn.MouseEnter:Connect(function()
                    if not listening then
                        Tween(keyBtn, 0.12, {
                            BackgroundColor3 = self.Theme.SurfaceHover,
                        }):Play()
                    end
                end)
                keyBtn.MouseLeave:Connect(function()
                    if not listening then
                        Tween(keyBtn, 0.12, {
                            BackgroundColor3 = self.Theme.Background,
                        }):Play()
                    end
                end)
            end
        end

        -- Reset-all button
        local resetRow = Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 32),
            LayoutOrder = nextOrder(),
            Parent = list,
        })
        local resetBtn = Create("TextButton", {
            Text = "Reset All Hotkeys",
            Font = Enum.Font.GothamBold, TextSize = 12,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundColor3 = Color3.fromRGB(180, 60, 60),
            BackgroundTransparency = 0.2, AutoButtonColor = false,
            Size = UDim2.fromScale(1, 1),
            Parent = resetRow,
        })
        Corner(8, resetBtn)
        BindTap(resetBtn, function()
            LucidUI:ResetAllHotkeys()
            rebuild()
        end, { MoveThreshold = 8 })
    end

    -- Expose so RegisterHotkey can rebuild the panel
    self._hotkeyListRefresh = rebuild
    rebuild()

    self:_registerTheme(function(t)
        masterRow.BackgroundColor3 = t.Surface
        masterLbl.TextColor3 = t.TextPrimary
        masterTrack.BackgroundColor3 = LucidUI._hotkeysEnabled and t.Accent or t.ToggleOff
    end)
end

-- ============================================================
-- Hook into BuildSettingsPanel
-- ============================================================
local _origBuildSettings = LucidUI.Window.BuildSettingsPanel
LucidUI.Window.BuildSettingsPanel = function(self, ...)
    _origBuildSettings(self, ...)
    if not self._hotkeySettingsBuilt and self._settingsBuilt then
        self._hotkeySettingsBuilt = true
        pcall(function() self:_buildHotkeySettings() end)
    end
end

-- ============================================================
-- Cleanup
-- ============================================================
LucidUI:OnCleanup(function()
    for _, conn in ipairs(LucidUI._hotkeyConnections or {}) do
        pcall(function() conn:Disconnect() end)
    end
    LucidUI._hotkeyConnections = {}
    LucidUI._hotkeyListeners   = {}
    print("[LucidUI] Hotkeys cleaned up")
end)

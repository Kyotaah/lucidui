-- ============================================================
-- Module: 08b_soundpacks.lua
-- ============================================================
--[[
    Sound Packs — selectable UI sound sets.

    Loads after 01b_polish.lua so it can mutate SOUND_IDS via the
    exported LucidUI._SOUND_IDS reference.

    Adds:
      LucidUI:SetSoundPack(name)     -> boolean
      LucidUI:GetSoundPack()         -> string
      LucidUI:ListSoundPacks()       -> { { key, display }, ... }

    Also hooks BuildSettingsPanel to register a Sound dropdown.

    [FIX] applyPack now writes through LucidUI._SOUND_IDS instead of
    directly indexing a SOUND_IDS local. The old approach depended on
    01b_polish.lua and this file living in the same chunk scope; the
    moment either file is wrapped in do...end or extracted, the
    assignment would silently fail. The exported reference is stable
    across any future refactor.
]]

-- ============================================================
-- Pack definitions
-- Each entry's `click` / `hover` values are written into the
-- shared SOUND_IDS table (via LucidUI._SOUND_IDS) when applied.
-- ============================================================
local PACKS = {
    classic = {
        display = "Classic",
        click   = "rbxasset://sounds/electronicpingshort.wav",
        hover   = "rbxasset://sounds/switch.wav",
    },
    soft = {
        display = "Soft",
        click   = "rbxasset://sounds/button.wav",
        hover   = "rbxasset://sounds/clickfast.wav",
    },
    mechanical = {
        display = "Mechanical",
        click   = "rbxasset://sounds/switch3.wav",
        hover   = "rbxasset://sounds/switch.wav",
    },
    typewriter = {
        display = "Typewriter",
        click   = "rbxasset://sounds/clickfast.wav",
        hover   = "rbxasset://sounds/button.wav",
    },
    silent = {
        display = "Silent",
        click   = "",
        hover   = "",
    },
}

LucidUI._currentSoundPack = "classic"

-- ============================================================
-- Apply a pack — writes into the shared SOUND_IDS table
-- ============================================================
local function applyPack(name)
    local pack = PACKS[name]
    if not pack then return false end

    -- [FIX] Use the stable export from 01b_polish.lua instead of
    -- relying on chunk-scope visibility of a local. Empty strings
    -- are treated as "no sound" so PlayUISound can early-return
    -- without creating a dead Sound instance.
    local ids = LucidUI._SOUND_IDS
    if not ids then
        warn("[LucidUI] SoundPack: SOUND_IDS export missing — "
            .. "make sure 01b_polish.lua ran first.")
        return false
    end

    ids.click = (pack.click ~= "" and pack.click) or nil
    ids.hover = (pack.hover ~= "" and pack.hover) or nil

    LucidUI._currentSoundPack = name
    return true
end

-- ============================================================
-- Public API
-- ============================================================
function LucidUI:SetSoundPack(name)
    if not PACKS[name] then
        warn("[LucidUI] Unknown sound pack: " .. tostring(name))
        return false
    end
    return applyPack(name)
end

function LucidUI:GetSoundPack()
    return LucidUI._currentSoundPack or "classic"
end

function LucidUI:ListSoundPacks()
    local list = {}
    for key, pack in pairs(PACKS) do
        table.insert(list, { key = key, display = pack.display })
    end
    table.sort(list, function(a, b) return a.display < b.display end)
    return list
end

-- Apply the default pack so SOUND_IDS matches the current state
applyPack("classic")

-- ============================================================
-- Settings UI — hooked into BuildSettingsPanel
-- ============================================================
function LucidUI.Window:_buildSoundSettings()
    self:_addSettingSection("Sound")

    local row = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 44),
        ClipsDescendants = true,
    })
    Corner(10, row)
    self:_addSettingFrame(row)

    local headerBtn = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 44), Parent = row,
    })
    Create("TextLabel", {
        Text = "Sound Pack", Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -100, 1, 0),
        Parent = headerBtn,
    })
    local valueLbl = Create("TextLabel", {
        Text = PACKS[LucidUI:GetSoundPack()] and PACKS[LucidUI:GetSoundPack()].display or "Classic",
        Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = self.Theme.Accent, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Size = UDim2.new(1, -40, 1, 0), Parent = headerBtn,
    })
    local arrowLbl = Create("TextLabel", {
        Text = "v", Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = self.Theme.TextMuted, BackgroundTransparency = 1,
        Position = UDim2.new(1, -24, 0, 0), Size = UDim2.fromOffset(20, 44),
        Parent = headerBtn,
    })

    local list = Create("Frame", {
        Size = UDim2.new(1, -20, 0, 0), Position = UDim2.fromOffset(10, 44),
        BackgroundTransparency = 1, ClipsDescendants = true, Parent = row,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list,
    })

    local expanded = false
    local optionBtns = {}
    local packs = LucidUI:ListSoundPacks()

    for i, pack in ipairs(packs) do
        local opt = Create("TextButton", {
            Text = pack.display, Font = Enum.Font.GothamMedium, TextSize = 13,
            TextColor3 = self.Theme.TextPrimary, BackgroundColor3 = self.Theme.Background,
            BackgroundTransparency = 0.5, AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, 32), LayoutOrder = i, Parent = list,
        })
        Corner(8, opt)

        opt.MouseEnter:Connect(function()
            local t = self.Theme
            Tween(opt, 0.12, { BackgroundColor3 = t.Accent, BackgroundTransparency = 0.3 }):Play()
        end)
        opt.MouseLeave:Connect(function()
            local t = self.Theme
            Tween(opt, 0.12, { BackgroundColor3 = t.Background, BackgroundTransparency = 0.5 }):Play()
        end)

        local packKey = pack.key
        local packName = pack.display
        BindTap(opt, function()
            LucidUI:SetSoundPack(packKey)
            valueLbl.Text = packName
            expanded = false
            Tween(list, 0.22, { Size = UDim2.new(1, -20, 0, 0) }):Play()
            Tween(row, 0.22, { Size = UDim2.new(1, 0, 0, 44) }):Play()
            Tween(arrowLbl, 0.2, { Rotation = 0 }):Play()
            PlayUISound("click")
            LucidUI:Notify({
                Title = "Sound Pack",
                Message = packName,
                Variant = "success",
                Duration = 2,
            })
        end)

        table.insert(optionBtns, opt)
    end

    BindTap(headerBtn, function()
        expanded = not expanded
        local h = #optionBtns * 36 + 8
        Tween(list, 0.22, { Size = UDim2.new(1, -20, 0, expanded and h or 0) }, Enum.EasingStyle.Quart):Play()
        Tween(row, 0.22, { Size = UDim2.new(1, 0, 0, expanded and (44 + h + 8) or 44) }, Enum.EasingStyle.Quart):Play()
        Tween(arrowLbl, 0.2, { Rotation = expanded and 180 or 0 }):Play()
    end)

    self:_registerTheme(function(t)
        row.BackgroundColor3 = t.Surface
        valueLbl.TextColor3 = t.Accent
        arrowLbl.TextColor3 = t.TextMuted
        for _, b in ipairs(optionBtns) do
            b.BackgroundColor3 = t.Background
            b.TextColor3 = t.TextPrimary
        end
    end)
end

-- ============================================================
-- Hook into BuildSettingsPanel without touching 07_settings_b.lua
-- ============================================================
local _origBuildSettings = LucidUI.Window.BuildSettingsPanel
LucidUI.Window.BuildSettingsPanel = function(self, ...)
    _origBuildSettings(self, ...)
    if not self._soundSettingsBuilt and self._settingsBuilt then
        self._soundSettingsBuilt = true
        pcall(function() self:_buildSoundSettings() end)
    end
end

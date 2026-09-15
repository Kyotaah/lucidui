--[[
    Settings A — theme dropdown, custom theme editor, saved themes.

    Click handling:
      Every click goes through BindTap (from 01b_polish.lua). The
      color picker's SV square and hue strip keep InputBegan/InputChanged
      because drag IS their interaction model.

    Custom theme editor:
      Each color field is a 48px row with a swatch. Tapping the row
      opens a modal HSV picker.

    Color picker modal:
      • Pop-in: scale 0.82 → 1 with Back easing (0.32s), fade 0.22s
      • Pop-out: scale 1 → 0.86 with Quad.In (0.18s), fade 0.18s
      • Backdrop absorbs clicks and closes the picker when tapped
      • Header carries a Frames-built paint bucket icon
]]

-- ============================================================
-- Paint bucket icon — handle + tapered body + paint drop.
-- Built entirely from Frames so it renders on every device.
-- ============================================================
local function BuildPaintBucketIcon(parent, size, color)
    size = size or 18

    local holder = Create("Frame", {
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        Parent = parent,
    })

    local barW = math.max(size * 0.08, 1)
    local parts = {}

    -- Handle: thin U above the bucket
    local handleH = size * 0.26
    local leftBar = Create("Frame", {
        Size = UDim2.fromOffset(barW, handleH),
        Position = UDim2.new(0.30, 0, 0.12, 0),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(barW / 2, leftBar)
    table.insert(parts, leftBar)

    local rightBar = Create("Frame", {
        Size = UDim2.fromOffset(barW, handleH),
        Position = UDim2.new(0.70, 0, 0.12, 0),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(barW / 2, rightBar)
    table.insert(parts, rightBar)

    local topBar = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.40, barW),
        Position = UDim2.new(0.50, 0, 0.12, 0),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(barW / 2, topBar)
    table.insert(parts, topBar)

    -- Bucket body — slightly rounded bottom, square top
    local bodyW = size * 0.74
    local bodyH = size * 0.50
    local body = Create("Frame", {
        Size = UDim2.fromOffset(bodyW, bodyH),
        Position = UDim2.new(0.50, 0, 0.62, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    local bodyCorner = Instance.new("UICorner")
    bodyCorner.TopLeftRadius     = UDim.new(0, 1)
    bodyCorner.TopRightRadius    = UDim.new(0, 1)
    bodyCorner.BottomLeftRadius  = UDim.new(0, bodyW * 0.18)
    bodyCorner.BottomRightRadius = UDim.new(0, bodyW * 0.18)
    bodyCorner.Parent = body
    table.insert(parts, body)

    -- Rim: a thin lighter bar across the top of the body
    local rim = Create("Frame", {
        Size = UDim2.new(1, 2, 0, barW),
        Position = UDim2.new(0.5, 0, 0, 0),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = color,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Parent = body,
    })
    Corner(barW / 2, rim)

    -- Paint drop falling from the right side
    local dropSize = size * 0.16
    local drop = Create("Frame", {
        Size = UDim2.fromOffset(dropSize, dropSize),
        Position = UDim2.new(0.78, 0, 0.94, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(999, drop)
    table.insert(parts, drop)

    return holder, parts
end

function LucidUI.Window:_addSettingFrame(frame)
    frame.LayoutOrder = self._settingsOrder
    self._settingsOrder = self._settingsOrder + 1
    frame.Parent = self._spContent
    return frame
end

function LucidUI.Window:_addSettingSection(title)
    local label = Create("TextLabel", {
        Text = title:upper(),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = self.Theme.TextMuted,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 18),
        LayoutOrder = self._settingsOrder,
        Parent = self._spContent,
    })
    self._settingsOrder = self._settingsOrder + 1
    self:_registerTheme(function(t) label.TextColor3 = t.TextMuted end)
    return label
end

function LucidUI.Window:_ensureCustomTheme()
    if self._customTheme then return end
    self._customTheme = {
        Background   = self.Theme.Background,
        Surface      = self.Theme.Surface,
        SurfaceHover = self.Theme.SurfaceHover,
        Accent       = self.Theme.Accent,
        Border       = self.Theme.Border,
        TextPrimary  = self.Theme.TextPrimary,
    }
end

function LucidUI.Window:ApplyCustomTheme()
    self:_ensureCustomTheme()
    local base = LucidUI.Themes.Default
    local t = {}
    for k, v in pairs(base) do t[k] = v end
    for k, v in pairs(self._customTheme) do t[k] = v end
    t.TextSecondary = Color3.new(
        math.min(t.TextPrimary.R * 0.92, 1),
        math.min(t.TextPrimary.G * 0.92, 1),
        math.min(t.TextPrimary.B * 0.92, 1))
    t.TextMuted = Color3.new(
        (t.TextPrimary.R + t.Background.R) * 0.5,
        (t.TextPrimary.G + t.Background.G) * 0.5,
        (t.TextPrimary.B + t.Background.B) * 0.5)
    t.ToggleOff   = t.Surface
    t.SliderTrack = t.Surface
    t.TabActive   = t.TextPrimary
    t.TabInactive = t.TextMuted
    LucidUI.Themes["__custom_runtime"] = t
    self.Theme = t
    self.ThemeName = "Custom"
    self._customThemeActive = true
    LucidUI._lastTheme = t
    self:SetThemeObject(t)
end

function LucidUI.Window:SaveCustomTheme(name)
    name = name or "Custom Theme"
    self:_ensureCustomTheme()
    local data = {
        customTheme = Compat.serializeColors(self._customTheme),
        accent = self._accentOverride and {
            R = self._accentOverride.R, G = self._accentOverride.G, B = self._accentOverride.B
        } or nil,
    }
    local encoded = Compat.encode(data)
    if not encoded then return end
    Compat.ensureFolders()
    local ok = Compat.write("LucidUI/Themes/" .. name .. ".json", encoded)
    if ok then
        LucidUI:Notify({ Title = "Theme Saved", Message = name })
        if self._savedThemeSlotsRefresh then pcall(self._savedThemeSlotsRefresh) end
    else
        LucidUI:Notify({ Title = "Save Failed", Message = "No file system", Accent = Color3.fromRGB(255,80,80) })
    end
end

function LucidUI.Window:LoadCustomTheme(name)
    name = name or "Custom Theme"
    local contents = Compat.read("LucidUI/Themes/" .. name .. ".json")
    if not contents then
        LucidUI:Notify({ Title = "Load Failed", Message = "Not found: " .. name, Accent = Color3.fromRGB(255,80,80) })
        return
    end
    local data = Compat.decode(contents)
    if not data or not data.customTheme then return end
    local restored = Compat.deserializeColors(data.customTheme)
    if not restored then return end
    local d = LucidUI.Themes.Default
    self._customTheme = {
        Background   = restored.Background   or d.Background,
        Surface      = restored.Surface      or d.Surface,
        SurfaceHover = restored.SurfaceHover or d.SurfaceHover,
        Accent       = restored.Accent       or d.Accent,
        Border       = restored.Border       or d.Border,
        TextPrimary  = restored.TextPrimary  or d.TextPrimary,
    }
    if data.accent then
        self:SetAccent(Color3.new(data.accent.R, data.accent.G, data.accent.B))
    end
    self:ApplyCustomTheme()
    self.ThemeName = name
    LucidUI:Notify({ Title = "Theme Loaded", Message = name })
end

function LucidUI.Window:_buildThemeSettings()
    self:_addSettingSection("Theme")

    local row = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 40),
        ClipsDescendants = true,
    })
    Corner(10, row)
    local rowStroke = Stroke(self.Theme.Border, 1, self.Theme.BorderTrans + 0.05, row)
    self:_addSettingFrame(row)

    local headerBtn = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 40), Parent = row,
    })
    Create("TextLabel", {
        Text = "Active Theme", Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -100, 1, 0), Parent = headerBtn,
    })
    local valueLbl = Create("TextLabel", {
        Text = self.ThemeName, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = self.Theme.Accent, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Size = UDim2.new(1, -40, 1, 0), Parent = headerBtn,
    })
    local arrowLbl = Create("TextLabel", {
        Text = "v", Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = self.Theme.TextMuted, BackgroundTransparency = 1,
        Position = UDim2.new(1, -24, 0, 0), Size = UDim2.fromOffset(20, 40), Parent = headerBtn,
    })

    local list = Create("Frame", {
        Size = UDim2.new(1, -20, 0, 0), Position = UDim2.fromOffset(10, 40),
        BackgroundTransparency = 1, ClipsDescendants = true, Parent = row,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list,
    })

    local expanded = false
    local optionBtns = {}

    local function buildOptions()
        for _, b in ipairs(optionBtns) do b:Destroy() end
        optionBtns = {}

        local options = {}
        local presetNames = {}
        for name in pairs(LucidUI.Themes) do
            if not name:match("^__") and name ~= "Custom" then
                table.insert(presetNames, name)
            end
        end
        table.sort(presetNames, function(a, b)
            if a == "Default" then return true end
            if b == "Default" then return false end
            return a:lower() < b:lower()
        end)
        for _, name in ipairs(presetNames) do table.insert(options, name) end
        table.insert(options, "Custom")
        for _, name in ipairs(Compat.listThemes()) do table.insert(options, name) end

        for i, name in ipairs(options) do
            local opt = Create("TextButton", {
                Text = name, Font = Enum.Font.GothamMedium, TextSize = 13,
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

            local themeName = name
            BindTap(opt, function()
                valueLbl.Text = themeName
                expanded = false
                Tween(list, 0.22, { Size = UDim2.new(1, -20, 0, 0) }):Play()
                Tween(row, 0.22, { Size = UDim2.new(1, 0, 0, 40) }):Play()
                Tween(arrowLbl, 0.2, { Rotation = 0 }):Play()
                if themeName == "Custom" then
                    self:ApplyCustomTheme()
                else
                    self:SetTheme(themeName)
                end
            end)

            table.insert(optionBtns, opt)
        end
    end

    buildOptions()
    self._themeDropdownRefresh = function() if expanded then buildOptions() end end

    BindTap(headerBtn, function()
        expanded = not expanded
        if expanded then buildOptions() end
        local h = #optionBtns * 36 + 8
        Tween(list, 0.22, { Size = UDim2.new(1, -20, 0, expanded and h or 0) }, Enum.EasingStyle.Quart):Play()
        Tween(row, 0.22, { Size = UDim2.new(1, 0, 0, expanded and (40 + h + 8) or 40) }, Enum.EasingStyle.Quart):Play()
        Tween(arrowLbl, 0.2, { Rotation = expanded and 180 or 0 }):Play()
    end)

    self:_registerTheme(function(t)
        row.BackgroundColor3 = t.Surface
        rowStroke.Color = t.Border
        valueLbl.TextColor3 = t.Accent
        arrowLbl.TextColor3 = t.TextMuted
        for _, b in ipairs(optionBtns) do
            b.BackgroundColor3 = t.Background
            b.TextColor3 = t.TextPrimary
        end
    end)
end

-- ============================================================
-- Modern HSV color picker modal
-- ============================================================
function LucidUI.Window:_openColorPicker(fieldKey, fieldLabel)
    if self._colorPickerModal and self._colorPickerModal.Parent then
        self._colorPickerModal:Destroy()
    end

    local base = self._customTheme[fieldKey]
    local H, S, V = Color3.toHSV(base)

    -- ── Modal root: full-screen overlay (Frame, dim backdrop) ──
    local modal = Create("Frame", {
        Name = "ColorPickerModal",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 500,
        Parent = self.SettingsPanel,
    })
    self._colorPickerModal = modal

    -- ── Backdrop button — absorbs clicks + closes on tap-outside ──
    local backdrop = Create("TextButton", {
        Name = "Backdrop",
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = modal,
    })

    -- ── Card (CanvasGroup so we can fade the whole thing) ──────
    local card = Create("CanvasGroup", {
        Size = UDim2.fromOffset(360, 260),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = self.Theme.Background,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        GroupTransparency = 1,          -- invisible at start
        ZIndex = 2,
        Parent = modal,
    })
    Corner(16, card)
    Stroke(self.Theme.Border, 1, 0.5, card)

    -- Pop scale — starts small, tweens up with Back easing.
    local popScale = Instance.new("UIScale")
    popScale.Scale = 0.82
    popScale.Parent = card

    -- ── Header: paint bucket icon + label ──────────────────────
    local iconHolder = BuildPaintBucketIcon(card, 20, self.Theme.Accent)
    iconHolder.Position = UDim2.fromOffset(16, 14)
    iconHolder.ZIndex = 3

    Create("TextLabel", {
        Text = fieldLabel,
        Font = Enum.Font.GothamBold, TextSize = 15,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(46, 14),
        Size = UDim2.new(1, -60, 0, 22),
        ZIndex = 3, Parent = card,
    })

    local closeBtn = Create("TextButton", {
        Text = "x", Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = self.Theme.TextMuted, BackgroundTransparency = 1,
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -34, 0, 12),
        ZIndex = 3, Parent = card,
    })

    -- ── SV square ──────────────────────────────────────────────
    local svArea = Create("Frame", {
        Size = UDim2.fromOffset(250, 155),
        Position = UDim2.fromOffset(18, 48),
        BackgroundColor3 = Color3.fromHSV(H, 1, 1),
        BorderSizePixel = 0, ClipsDescendants = true,
        ZIndex = 3, Parent = card,
    })
    Corner(10, svArea)

    local satOverlay = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0, ZIndex = 4, Parent = svArea,
    })
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Rotation = 0, Parent = satOverlay,
    })

    local valOverlay = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0, ZIndex = 5, Parent = svArea,
    })
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Rotation = 90, Parent = valOverlay,
    })

    local dot = Create("Frame", {
        Size = UDim2.fromOffset(16, 16),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(S, 1 - V),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 2, BorderColor3 = Color3.new(0, 0, 0),
        ZIndex = 6, Parent = svArea,
    })
    Corner(8, dot)

    -- ── Hue strip ──────────────────────────────────────────────
    local hueStrip = Create("Frame", {
        Size = UDim2.fromOffset(26, 155),
        Position = UDim2.new(1, -44, 0, 48),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0, ClipsDescendants = true,
        ZIndex = 3, Parent = card,
    })
    Corner(10, hueStrip)
    Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.000, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.500, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1.000, Color3.fromRGB(255, 0, 0)),
        }),
        Rotation = 90, Parent = hueStrip,
    })
    local hueDot = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 5),
        Position = UDim2.new(0, 0, H, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 1, BorderColor3 = Color3.new(0, 0, 0),
        ZIndex = 6, Parent = hueStrip,
    })

    -- ── Bottom row: preview swatch, hex, done ──────────────────
    local preview = Create("Frame", {
        Size = UDim2.fromOffset(32, 32),
        Position = UDim2.fromOffset(18, 214),
        BackgroundColor3 = base,
        BorderSizePixel = 0, ZIndex = 3, Parent = card,
    })
    Corner(8, preview)
    Stroke(self.Theme.Border, 1, 0.5, preview)

    local hexBox = Create("TextBox", {
        Text = string.format("#%02X%02X%02X",
            math.floor(base.R * 255),
            math.floor(base.G * 255),
            math.floor(base.B * 255)),
        Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = self.Theme.TextPrimary,
        BackgroundColor3 = self.Theme.Background,
        BackgroundTransparency = 0.3,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Center,
        Size = UDim2.fromOffset(120, 32),
        Position = UDim2.fromOffset(60, 214),
        ZIndex = 3, Parent = card,
    })
    Corner(8, hexBox)

    local doneBtn = Create("TextButton", {
        Text = "Done",
        Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = self.Theme.Accent,
        AutoButtonColor = false,
        Size = UDim2.fromOffset(100, 32),
        Position = UDim2.new(1, -118, 0, 214),
        ZIndex = 3, Parent = card,
    })
    Corner(8, doneBtn)

    local function applyColor()
        local c = Color3.fromHSV(H, S, V)
        preview.BackgroundColor3   = c
        svArea.BackgroundColor3    = Color3.fromHSV(H, 1, 1)
        dot.Position               = UDim2.fromScale(S, 1 - V)
        hueDot.Position            = UDim2.new(0, 0, H, 0)
        hexBox.Text = string.format("#%02X%02X%02X",
            math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
        self._customTheme[fieldKey] = c
        self:ApplyCustomTheme()
    end

    -- ── SV drag ────────────────────────────────────────────────
    local svDrag = false
    local function svUpdate(input)
        S = math.clamp((input.Position.X - svArea.AbsolutePosition.X) / svArea.AbsoluteSize.X, 0, 1)
        V = 1 - math.clamp((input.Position.Y - svArea.AbsolutePosition.Y) / svArea.AbsoluteSize.Y, 0, 1)
        applyColor()
    end
    svArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            svDrag = true; svUpdate(input)
        end
    end)
    table.insert(self._conns, UserInputService.InputChanged:Connect(function(input)
        if not svDrag then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then svUpdate(input) end
    end))
    table.insert(self._conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then svDrag = false end
    end))

    -- ── Hue drag ───────────────────────────────────────────────
    local hueDrag = false
    local function hueUpdate(input)
        H = math.clamp((input.Position.Y - hueStrip.AbsolutePosition.Y) / hueStrip.AbsoluteSize.Y, 0, 1)
        applyColor()
    end
    hueStrip.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            hueDrag = true; hueUpdate(input)
        end
    end)
    table.insert(self._conns, UserInputService.InputChanged:Connect(function(input)
        if not hueDrag then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then hueUpdate(input) end
    end))
    table.insert(self._conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then hueDrag = false end
    end))

    -- ── Hex input ──────────────────────────────────────────────
    hexBox.FocusLost:Connect(function()
        local hex = hexBox.Text:gsub("#", "")
        if #hex == 6 then
            local r = tonumber(hex:sub(1, 2), 16)
            local g = tonumber(hex:sub(3, 4), 16)
            local b = tonumber(hex:sub(5, 6), 16)
            if r and g and b then
                H, S, V = Color3.toHSV(Color3.fromRGB(r, g, b))
                applyColor()
            end
        end
    end)

    -- ── Pop-in animation ───────────────────────────────────────
    -- Fade backdrop in, pop card with Back-ease overshoot, fade card.
    -- Total ~0.32s. Deliberately visible, not a blink.
    TweenService:Create(modal, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 0.55 }):Play()
    TweenService:Create(popScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }):Play()
    TweenService:Create(card, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { GroupTransparency = 0 }):Play()

    -- ── Close with exit animation ──────────────────────────────
    local closing = false
    local function closeModal()
        if closing then return end
        closing = true

        local exitScale = TweenService:Create(popScale,
            TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Scale = 0.86 })
        exitScale:Play()
        TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { GroupTransparency = 1 }):Play()
        TweenService:Create(modal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { BackgroundTransparency = 1 }):Play()

        exitScale.Completed:Connect(function()
            modal:Destroy()
            if self._colorPickerModal == modal then
                self._colorPickerModal = nil
            end
        end)
    end

    BindTap(backdrop, closeModal)
    BindTap(closeBtn, closeModal)
    BindTap(doneBtn, closeModal)
end

function LucidUI.Window:_buildCustomThemeSettings()
    self:_addSettingSection("Custom Theme")
    self:_ensureCustomTheme()

    local fields = {
        { key = "Background",   label = "Background"     },
        { key = "Surface",      label = "Surface"        },
        { key = "SurfaceHover", label = "Surface Hover"  },
        { key = "Accent",       label = "Accent"         },
        { key = "Border",       label = "Border"         },
        { key = "TextPrimary",  label = "Text"           },
    }
    local editorRows = {}
    local swatches   = {}

    for _, field in ipairs(fields) do
        local row = Create("Frame", {
            BackgroundColor3 = self.Theme.Surface,
            BackgroundTransparency = self.Theme.SurfaceTrans,
            Size = UDim2.new(1, 0, 0, 48),
        })
        Corner(10, row)
        self:_addSettingFrame(row)
        table.insert(editorRows, row)

        local labelLbl = Create("TextLabel", {
            Text = field.label,
            Font = Enum.Font.GothamMedium, TextSize = 14,
            TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(14, 0),
            Size = UDim2.new(1, -110, 1, 0),
            Parent = row,
        })

        local swatch = Create("Frame", {
            Size = UDim2.fromOffset(32, 32),
            Position = UDim2.new(1, -46, 0.5, -16),
            BackgroundColor3 = self._customTheme[field.key],
            BorderSizePixel = 0,
            Parent = row,
        })
        Corner(8, swatch)
        Stroke(self.Theme.Border, 1, 0.5, swatch)
        table.insert(swatches, { frame = swatch, key = field.key })

        local clickArea = Create("TextButton", {
            Text = "",
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 5,
            Parent = row,
        })
        local fieldKey, fieldLabel = field.key, field.label
        BindTap(clickArea, function()
            self:_openColorPicker(fieldKey, fieldLabel)
        end)

        clickArea.MouseEnter:Connect(function()
            local t = self.Theme
            Tween(row, 0.12, {
                BackgroundTransparency = math.max(t.SurfaceTrans - 0.1, 0),
            }):Play()
        end)
        clickArea.MouseLeave:Connect(function()
            local t = self.Theme
            Tween(row, 0.12, { BackgroundTransparency = t.SurfaceTrans }):Play()
        end)
    end

    local actionRow = Create("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36),
    })
    self:_addSettingFrame(actionRow)
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6), Parent = actionRow,
    })

    local function mkActionBtn(label, color, cb)
        local b = Create("TextButton", {
            Text = label, Font = Enum.Font.GothamBold, TextSize = 12,
            TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundColor3 = color,
            BackgroundTransparency = 0.2, AutoButtonColor = false,
            Size = UDim2.new(0.5, -3, 1, 0), Parent = actionRow,
        })
        Corner(8, b)
        BindTap(b, cb, { MoveThreshold = 8 })
        return b
    end

    mkActionBtn("Reset to Default", self.Theme.Surface, function()
        self._customTheme = {
            Background   = LucidUI.Themes.Default.Background,
            Surface      = LucidUI.Themes.Default.Surface,
            SurfaceHover = LucidUI.Themes.Default.SurfaceHover,
            Accent       = LucidUI.Themes.Default.Accent,
            Border       = LucidUI.Themes.Default.Border,
            TextPrimary  = LucidUI.Themes.Default.TextPrimary,
        }
        for _, s in ipairs(swatches) do
            s.frame.BackgroundColor3 = self._customTheme[s.key]
        end
        self:ApplyCustomTheme()
        LucidUI:Notify({ Title = "Reset", Message = "Custom theme reset to Default" })
    end)

    mkActionBtn("Apply Custom", self.Theme.Accent, function()
        self:ApplyCustomTheme()
        LucidUI:Notify({ Title = "Applied", Message = "Custom theme active" })
    end)

    local saveRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 40),
    })
    Corner(10, saveRow)
    self:_addSettingFrame(saveRow)

    local nameBox = Create("TextBox", {
        Text = "", PlaceholderText = "theme name...",
        PlaceholderColor3 = self.Theme.TextMuted, Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = self.Theme.TextPrimary, BackgroundColor3 = self.Theme.Background,
        BackgroundTransparency = 0.3, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -120, 0, 26),
        Position = UDim2.new(0, 14, 0.5, -13), Parent = saveRow,
    })
    Corner(8, nameBox)
    Create("UIPadding", {
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = nameBox,
    })

    local saveBtn = Create("TextButton", {
        Text = "Save As", Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundColor3 = self.Theme.Accent,
        BackgroundTransparency = 0.2, AutoButtonColor = false,
        Size = UDim2.fromOffset(100, 26),
        Position = UDim2.new(1, -114, 0.5, -13), Parent = saveRow,
    })
    Corner(8, saveBtn)
    BindTap(saveBtn, function()
        local name = nameBox.Text
        if name == "" then
            LucidUI:Notify({
                Title = "Invalid", Message = "Enter a theme name",
                Accent = Color3.fromRGB(255, 80, 80),
            })
            return
        end
        self:SaveCustomTheme(name)
        nameBox.Text = ""
    end, { MoveThreshold = 8 })

    self:_registerTheme(function(t)
        for _, r in ipairs(editorRows) do r.BackgroundColor3 = t.Surface end
        saveRow.BackgroundColor3 = t.Surface
        nameBox.BackgroundColor3 = t.Background
        nameBox.TextColor3 = t.TextPrimary
        saveBtn.BackgroundColor3 = t.Accent
    end)
end

function LucidUI.Window:_buildSavedThemesSettings()
    self:_addSettingSection("Saved Themes")

    local savedRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 40),
        ClipsDescendants = true,
    })
    Corner(10, savedRow)
    self:_addSettingFrame(savedRow)

    local savedHeader = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 40), Parent = savedRow,
    })
    Create("TextLabel", {
        Text = "Saved Themes", Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -100, 1, 0),
        Parent = savedHeader,
    })
    local savedArrow = Create("TextLabel", {
        Text = "v", Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = self.Theme.TextMuted, BackgroundTransparency = 1,
        Position = UDim2.new(1, -24, 0, 0), Size = UDim2.fromOffset(20, 40),
        Parent = savedHeader,
    })

    local savedList = Create("Frame", {
        Size = UDim2.new(1, -20, 0, 0), Position = UDim2.fromOffset(10, 40),
        BackgroundTransparency = 1, ClipsDescendants = true, Parent = savedRow,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = savedList,
    })

    local savedExpanded = false
    local savedRowFrames = {}

    local function updateListSize()
        local h = 0
        for _, f in ipairs(savedRowFrames) do
            h = h + f.Size.Y.Offset + 4
        end
        if h > 0 then h = h - 4 end
        h = h + 8

        if savedExpanded then
            Tween(savedList, 0.22, { Size = UDim2.new(1, -20, 0, h) }, Enum.EasingStyle.Quart):Play()
            Tween(savedRow, 0.22, { Size = UDim2.new(1, 0, 0, 40 + h + 8) }, Enum.EasingStyle.Quart):Play()
        end
    end

    local function rebuildSaved()
        for _, f in ipairs(savedRowFrames) do
            if f and f.Parent then f:Destroy() end
        end
        savedRowFrames = {}

        local names = Compat.listThemes()
        if #names == 0 then
            local empty = Create("TextLabel", {
                Text = "No saved themes yet",
                Font = Enum.Font.Gotham, TextSize = 12,
                TextColor3 = self.Theme.TextMuted, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 32),
                LayoutOrder = 1, Parent = savedList,
            })
            table.insert(savedRowFrames, empty)
            updateListSize()
            return
        end

        for i, name in ipairs(names) do
            local rowWrap = Create("Frame", {
                Size = UDim2.new(1, 0, 0, 32),
                BackgroundColor3 = self.Theme.Background,
                BackgroundTransparency = 0.5,
                LayoutOrder = i,
                Parent = savedList,
            })
            Corner(8, rowWrap)
            table.insert(savedRowFrames, rowWrap)

            local nameBtn = Create("TextButton", {
                Text = name,
                Font = Enum.Font.GothamMedium, TextSize = 13,
                TextColor3 = self.Theme.TextPrimary,
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Size = UDim2.new(1, -36, 1, 0),
                Position = UDim2.fromOffset(10, 0),
                ZIndex = 3, Parent = rowWrap,
            })

            local delBtn = Create("TextButton", {
                Text = "x",
                Font = Enum.Font.GothamBold, TextSize = 14,
                TextColor3 = Color3.fromRGB(255, 100, 100),
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Size = UDim2.fromOffset(28, 32),
                Position = UDim2.new(1, -32, 0, 0),
                ZIndex = 3, Parent = rowWrap,
            })

            local themeName = name
            BindTap(nameBtn, function()
                savedExpanded = false
                Tween(savedList, 0.22, { Size = UDim2.new(1, -20, 0, 0) }):Play()
                Tween(savedRow, 0.22, { Size = UDim2.new(1, 0, 0, 40) }):Play()
                Tween(savedArrow, 0.2, { Rotation = 0 }):Play()
                self:LoadCustomTheme(themeName)
            end)

            BindTap(delBtn, function()
                Compat.delete("LucidUI/Themes/" .. themeName .. ".json")
                if self.ThemeName == themeName then self:SetTheme("Default") end
                rebuildSaved()
                LucidUI:Notify({ Title = "Deleted", Message = themeName })
            end, { MoveThreshold = 8 })

            nameBtn.MouseEnter:Connect(function()
                local t = self.Theme
                Tween(rowWrap, 0.12, { BackgroundColor3 = t.Accent, BackgroundTransparency = 0.3 }):Play()
            end)
            nameBtn.MouseLeave:Connect(function()
                local t = self.Theme
                Tween(rowWrap, 0.12, { BackgroundColor3 = t.Background, BackgroundTransparency = 0.5 }):Play()
            end)
        end

        updateListSize()
    end

    self._savedThemeSlotsRefresh = rebuildSaved

    BindTap(savedHeader, function()
        savedExpanded = not savedExpanded
        rebuildSaved()
        Tween(savedArrow, 0.2, { Rotation = savedExpanded and 180 or 0 }):Play()
    end)

    self:_registerTheme(function(t)
        savedRow.BackgroundColor3 = t.Surface
        savedArrow.TextColor3 = t.TextMuted
        for _, f in ipairs(savedRowFrames) do
            if f:IsA("Frame") then
                f.BackgroundColor3 = t.Background
            elseif f:IsA("TextLabel") then
                f.TextColor3 = t.TextMuted
            end
        end
    end)
end

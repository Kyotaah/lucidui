--[[
    Settings A — theme dropdown, custom theme editor, saved themes.

    Click handling:
      Every click goes through BindTap (from 01b_polish.lua). The
      color picker sliders keep InputBegan/InputChanged because drag
      IS their interaction model.
]]

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
        table.sort(presetNames)
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
                Tween(opt, 0.12, { BackgroundColor3 = self.Theme.Accent, BackgroundTransparency = 0.3 }):Play()
            end)
            opt.MouseLeave:Connect(function()
                Tween(opt, 0.12, { BackgroundColor3 = self.Theme.Background, BackgroundTransparency = 0.5 }):Play()
            end)

            local themeName = name  -- capture per iteration
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

function LucidUI.Window:_buildCustomThemeSettings()
    self:_addSettingSection("Custom Theme")
    self:_ensureCustomTheme()

    local fields = {
        { key = "Background",   label = "Background" },
        { key = "Surface",      label = "Surface" },
        { key = "SurfaceHover", label = "Surface Hover" },
        { key = "Accent",       label = "Accent" },
        { key = "Border",       label = "Border" },
        { key = "TextPrimary",  label = "Text" },
    }
    local editorRows = {}

    for _, field in ipairs(fields) do
        local row = Create("Frame", {
            BackgroundColor3 = self.Theme.Surface,
            BackgroundTransparency = self.Theme.SurfaceTrans,
            Size = UDim2.new(1, 0, 0, 100),
        })
        Corner(10, row)
        self:_addSettingFrame(row)
        table.insert(editorRows, row)

        Create("TextLabel", {
            Text = field.label, Font = Enum.Font.GothamMedium, TextSize = 14,
            TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -80, 0, 18), Parent = row,
        })

        local preview = Create("Frame", {
            Size = UDim2.fromOffset(48, 48), Position = UDim2.new(1, -62, 0, 8),
            BackgroundColor3 = self._customTheme[field.key],
            BorderSizePixel = 0, Parent = row,
        })
        Corner(10, preview)
        Stroke(self.Theme.Border, 1, 0.6, preview)

        local channels = {
            R = math.floor(self._customTheme[field.key].R * 255),
            G = math.floor(self._customTheme[field.key].G * 255),
            B = math.floor(self._customTheme[field.key].B * 255),
        }
        local function commit()
            self._customTheme[field.key] = Color3.fromRGB(channels.R, channels.G, channels.B)
            preview.BackgroundColor3 = self._customTheme[field.key]
            self:ApplyCustomTheme()
        end

        -- Color picker sliders — these keep InputBegan/InputChanged
        -- because dragging is their interaction model.
        for i, ch in ipairs({ "R", "G", "B" }) do
            local y = 32 + (i - 1) * 20
            Create("TextLabel", {
                Text = ch, Font = Enum.Font.GothamBold, TextSize = 12,
                TextColor3 = self.Theme.TextMuted, BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(14, 14), Parent = row,
            })
            local track = Create("Frame", {
                Size = UDim2.new(1, -120, 0, 4), Position = UDim2.fromOffset(34, y + 5),
                BackgroundColor3 = self.Theme.SliderTrack, BorderSizePixel = 0, Parent = row,
            })
            Corner(2, track)
            local fill = Create("Frame", {
                Size = UDim2.new(channels[ch] / 255, 0, 1, 0),
                BackgroundColor3 = self.Theme.Accent, BorderSizePixel = 0, Parent = track,
            })
            Corner(2, fill)
            local drag = Create("TextButton", {
                Text = "", BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 2, 0), Position = UDim2.fromOffset(0, -10), Parent = track,
            })
            local active = false
            local function upd(input)
                local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                channels[ch] = math.floor(rel * 255 + 0.5)
                fill.Size = UDim2.new(channels[ch] / 255, 0, 1, 0)
                commit()
            end
            drag.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    active = true
                    upd(input)
                end
            end)
            table.insert(self._conns, UserInputService.InputChanged:Connect(function(input)
                if not active then return end
                if input.UserInputType == Enum.UserInputType.MouseMovement
                    or input.UserInputType == Enum.UserInputType.Touch then upd(input) end
            end))
            table.insert(self._conns, UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then active = false end
            end))
        end
    end

    local actionRow = Create("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36),
    })
    self:_addSettingFrame(actionRow)
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = actionRow,
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
        Size = UDim2.new(1, -120, 0, 26), Position = UDim2.new(0, 14, 0.5, -13), Parent = saveRow,
    })
    Corner(8, nameBox)
    Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = nameBox })
    local saveBtn = Create("TextButton", {
        Text = "Save As", Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundColor3 = self.Theme.Accent,
        BackgroundTransparency = 0.2, AutoButtonColor = false,
        Size = UDim2.fromOffset(100, 26), Position = UDim2.new(1, -114, 0.5, -13), Parent = saveRow,
    })
    Corner(8, saveBtn)
    BindTap(saveBtn, function()
        local name = nameBox.Text
        if name == "" then
            LucidUI:Notify({ Title = "Invalid", Message = "Enter a theme name", Accent = Color3.fromRGB(255,80,80) })
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
        -- Destroy every tracked row frame (not just inner buttons)
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

            local themeName = name  -- capture per iteration
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
                Tween(rowWrap, 0.12, { BackgroundColor3 = self.Theme.Accent, BackgroundTransparency = 0.3 }):Play()
            end)
            nameBtn.MouseLeave:Connect(function()
                Tween(rowWrap, 0.12, { BackgroundColor3 = self.Theme.Background, BackgroundTransparency = 0.5 }):Play()
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

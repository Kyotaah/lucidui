--[[
    Settings — everything inside the gear panel.

    Sections:
      • Theme            — dropdown: Default / Custom / saved themes
      • Custom Theme     — 6 live color editors + Save As / Reset / Apply
      • Background Image — URL input, transparency slider, auto accent
      • Configs          — config slots with save/load/delete
      • About            — version info

    Also provides:
      • ApplyCustomTheme, SaveCustomTheme, LoadCustomTheme
      • SetBackgroundImage, _downloadAndLoadImage, AutoDetectAccent
      • SaveConfig, LoadConfig
      • BuildSettingsPanel  (call once to populate everything)
]]

-- ============================================================
-- Settings layout helpers
-- ============================================================
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

-- ============================================================
-- Custom theme state
-- ============================================================
function LucidUI.Window:_ensureCustomTheme()
    if self._customTheme then return end
    local t = self.Theme
    self._customTheme = NewCustomTheme(t)
end

function LucidUI.Window:ApplyCustomTheme()
    self:_ensureCustomTheme()
    local derived = DeriveTheme(self._customTheme)
    LucidUI.Themes["__custom_runtime"] = derived
    self.Theme = derived
    self.ThemeName = "Custom"
    self._customThemeActive = true
    LucidUI._lastTheme = derived
    self:SetThemeObject(derived)
end

-- ============================================================
-- Save / load custom themes
-- ============================================================
function LucidUI.Window:SaveCustomTheme(name)
    name = name or "Custom Theme"
    self:_ensureCustomTheme()

    local data = {
        customTheme = Compat.serializeColors(self._customTheme),
        accent = self._accentOverride and {
            R = self._accentOverride.R,
            G = self._accentOverride.G,
            B = self._accentOverride.B,
        } or nil,
    }

    local encoded = Compat.encode(data)
    if not encoded then return end

    Compat.ensureFolders()
    local ok = Compat.write("LucidUI/Themes/" .. name .. ".json", encoded)

    if ok then
        LucidUI:Notify({ Title = "Theme Saved", Message = name })
        if self._savedThemeSlotsRefresh then pcall(self._savedThemeSlotsRefresh) end
        if self._themeDropdownRefresh   then pcall(self._themeDropdownRefresh)   end
    else
        LucidUI:Notify({
            Title = "Save Failed",
            Message = "No file system",
            Accent = Color3.fromRGB(255, 80, 80),
        })
    end
end

function LucidUI.Window:LoadCustomTheme(name)
    name = name or "Custom Theme"
    local contents = Compat.read("LucidUI/Themes/" .. name .. ".json")
    if not contents then
        LucidUI:Notify({
            Title = "Load Failed",
            Message = "Not found: " .. name,
            Accent = Color3.fromRGB(255, 80, 80),
        })
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

-- ============================================================
-- Theme dropdown  (Default / Custom / saved themes)
-- ============================================================
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
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 40),
        Parent = row,
    })

    local titleLbl = Create("TextLabel", {
        Text = "Active Theme",
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextColor3 = self.Theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -100, 1, 0),
        Parent = headerBtn,
    })

    local valueLbl = Create("TextLabel", {
        Text = self.ThemeName,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = self.Theme.Accent,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Size = UDim2.new(1, -40, 1, 0),
        Parent = headerBtn,
    })

    local arrowLbl = Create("TextLabel", {
        Text = "v",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = self.Theme.TextMuted,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -24, 0, 0),
        Size = UDim2.fromOffset(20, 40),
        Parent = headerBtn,
    })

    local list = Create("Frame", {
        Size = UDim2.new(1, -20, 0, 0),
        Position = UDim2.fromOffset(10, 40),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = row,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = list,
    })

    local expanded = false
    local optionBtns = {}

    local function buildOptions()
        for _, b in ipairs(optionBtns) do b:Destroy() end
        optionBtns = {}

        local options = { "Default", "Custom" }
        for _, name in ipairs(Compat.listThemes()) do
            table.insert(options, name)
        end

        for i, name in ipairs(options) do
            local opt = Create("TextButton", {
                Text = name,
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextColor3 = self.Theme.TextPrimary,
                BackgroundColor3 = self.Theme.Background,
                BackgroundTransparency = 0.5,
                AutoButtonColor = false,
                Size = UDim2.new(1, 0, 0, 32),
                LayoutOrder = i,
                Parent = list,
            })
            Corner(8, opt)

            opt.MouseEnter:Connect(function()
                Tween(opt, 0.12, {
                    BackgroundColor3 = self.Theme.Accent,
                    BackgroundTransparency = 0.3,
                }):Play()
            end)
            opt.MouseLeave:Connect(function()
                Tween(opt, 0.12, {
                    BackgroundColor3 = self.Theme.Background,
                    BackgroundTransparency = 0.5,
                }):Play()
            end)

            opt.MouseButton1Click:Connect(function()
                valueLbl.Text = name
                expanded = false
                Tween(list, 0.22, { Size = UDim2.new(1, -20, 0, 0) }):Play()
                Tween(row, 0.22, { Size = UDim2.new(1, 0, 0, 40) }):Play()
                Tween(arrowLbl, 0.2, { Rotation = 0 }):Play()

                if name == "Default" then
                    self:SetTheme("Default")
                elseif name == "Custom" then
                    self:ApplyCustomTheme()
                else
                    self:LoadCustomTheme(name)
                end
            end)

            table.insert(optionBtns, opt)
        end
    end

    local function refreshOptions()
        if expanded then buildOptions() end
    end

    buildOptions()
    self._themeDropdownRefresh = refreshOptions

    headerBtn.MouseButton1Click:Connect(function()
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
        titleLbl.TextColor3 = t.TextPrimary
        valueLbl.TextColor3 = t.Accent
        arrowLbl.TextColor3 = t.TextMuted
        for _, b in ipairs(optionBtns) do
            b.BackgroundColor3 = t.Background
            b.TextColor3 = t.TextPrimary
        end
    end)
end

-- ============================================================
-- Custom theme editor
-- ============================================================
function LucidUI.Window:_buildCustomThemeSettings()
    self:_addSettingSection("Custom Theme")
    self:_ensureCustomTheme()

    for _, field in ipairs(EDITABLE_COLORS) do
        local row = Create("Frame", {
            BackgroundColor3 = self.Theme.Surface,
            BackgroundTransparency = self.Theme.SurfaceTrans,
            Size = UDim2.new(1, 0, 0, 100),
        })
        Corner(10, row)
        self:_addSettingFrame(row)

        Create("TextLabel", {
            Text = field.label,
            Font = Enum.Font.GothamMedium,
            TextSize = 14,
            TextColor3 = self.Theme.TextPrimary,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(14, 8),
            Size = UDim2.new(1, -80, 0, 18),
            Parent = row,
        })

        local preview = Create("Frame", {
            Size = UDim2.fromOffset(48, 48),
            Position = UDim2.new(1, -62, 0, 8),
            BackgroundColor3 = self._customTheme[field.key],
            BorderSizePixel = 0,
            Parent = row,
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

        for i, ch in ipairs({ "R", "G", "B" }) do
            local y = 32 + (i - 1) * 20

            Create("TextLabel", {
                Text = ch,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextColor3 = self.Theme.TextMuted,
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                Position = UDim2.fromOffset(14, y),
                Size = UDim2.fromOffset(14, 14),
                Parent = row,
            })

            local track = Create("Frame", {
                Size = UDim2.new(1, -120, 0, 4),
                Position = UDim2.fromOffset(34, y + 5),
                BackgroundColor3 = self.Theme.SliderTrack,
                BorderSizePixel = 0,
                Parent = row,
            })
            Corner(2, track)

            local fill = Create("Frame", {
                Size = UDim2.new(channels[ch] / 255, 0, 1, 0),
                BackgroundColor3 = self.Theme.Accent,
                BorderSizePixel = 0,
                Parent = track,
            })
            Corner(2, fill)

            local drag = Create("TextButton", {
                Text = "",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 2, 0),
                Position = UDim2.fromOffset(0, -10),
                Parent = track,
            })

            local active = false
            local function upd(input)
                local rel = math.clamp(
                    (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X,
                    0, 1
                )
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
                    or input.UserInputType == Enum.UserInputType.Touch then
                    upd(input)
                end
            end))

            table.insert(self._conns, UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    active = false
                end
            end))
        end

        self:_registerTheme(function(t)
            row.BackgroundColor3 = t.Surface
            track.BackgroundColor3 = t.SliderTrack
            fill.BackgroundColor3 = t.Accent
        end)
    end

    -- Action row: Reset / Apply
    local actionRow = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
    })
    self:_addSettingFrame(actionRow)
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        Parent = actionRow,
    })

    local function mkActionBtn(label, color, cb)
        local b = Create("TextButton", {
            Text = label,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundColor3 = color,
            BackgroundTransparency = 0.2,
            AutoButtonColor = false,
            Size = UDim2.new(0.5, -3, 1, 0),
            Parent = actionRow,
        })
        Corner(8, b)
        b.MouseButton1Click:Connect(cb)
        return b
    end

    mkActionBtn("Reset to Default", self.Theme.Surface, function()
        self._customTheme = NewCustomTheme(LucidUI.Themes.Default)
        self:ApplyCustomTheme()
        LucidUI:Notify({ Title = "Reset", Message = "Custom theme reset to Default" })
    end)

    mkActionBtn("Apply Custom", self.Theme.Accent, function()
        self:ApplyCustomTheme()
        LucidUI:Notify({ Title = "Applied", Message = "Custom theme active" })
    end)

    -- Save As row
    local saveRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 40),
    })
    Corner(10, saveRow)
    self:_addSettingFrame(saveRow)

    local nameBox = Create("TextBox", {
        Text = "",
        PlaceholderText = "theme name...",
        PlaceholderColor3 = self.Theme.TextMuted,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = self.Theme.TextPrimary,
        BackgroundColor3 = self.Theme.Background,
        BackgroundTransparency = 0.3,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -120, 0, 26),
        Position = UDim2.new(0, 14, 0.5, -13),
        Parent = saveRow,
    })
    Corner(8, nameBox)
    Create("UIPadding", {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        Parent = nameBox,
    })

    local saveBtn = Create("TextButton", {
        Text = "Save As",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = self.Theme.Accent,
        BackgroundTransparency = 0.2,
        AutoButtonColor = false,
        Size = UDim2.fromOffset(100, 26),
        Position = UDim2.new(1, -114, 0.5, -13),
        Parent = saveRow,
    })
    Corner(8, saveBtn)

    saveBtn.MouseButton1Click:Connect(function()
        local name = nameBox.Text
        if name == "" then
            LucidUI:Notify({
                Title = "Invalid",
                Message = "Enter a theme name",
                Accent = Color3.fromRGB(255, 80, 80),
            })
            return
        end
        self:SaveCustomTheme(name)
        nameBox.Text = ""
        if self._savedThemeSlotsRefresh then pcall(self._savedThemeSlotsRefresh) end
    end)

    -- Saved themes dropdown
    local listRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 40),
        ClipsDescendants = true,
    })
    Corner(10, listRow)
    self:_addSettingFrame(listRow)

    local listHeader = Create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 40),
        Parent = listRow,
    })

    Create("TextLabel", {
        Text = "Saved Themes",
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextColor3 = self.Theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -100, 1, 0),
        Parent = listHeader,
    })

    local slotLbl = Create("TextLabel", {
        Text = "—",
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = self.Theme.Accent,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Size = UDim2.new(1, -34, 1, 0),
        Parent = listHeader,
    })

    local listArrow = Create("TextLabel", {
        Text = "v",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = self.Theme.TextMuted,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -24, 0, 0),
        Size = UDim2.fromOffset(20, 40),
        Parent = listHeader,
    })

    local slotList = Create("Frame", {
        Size = UDim2.new(1, -20, 0, 0),
        Position = UDim2.fromOffset(10, 40),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = listRow,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = slotList,
    })

    local slotsExpanded = false
    local slotButtons = {}

    local function rebuildSaved()
        for _, b in ipairs(slotButtons) do b:Destroy() end
        slotButtons = {}

        local saved = Compat.listThemes()

        if #saved == 0 then
            local empty = Create("TextLabel", {
                Text = "No saved themes yet",
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextColor3 = self.Theme.TextMuted,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 32),
                LayoutOrder = 1,
                Parent = slotList,
            })
            table.insert(slotButtons, empty)
            return
        end

        for i, name in ipairs(saved) do
            local opt = Create("TextButton", {
                Text = name,
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextColor3 = self.Theme.TextPrimary,
                BackgroundColor3 = self.Theme.Background,
                BackgroundTransparency = 0.5,
                AutoButtonColor = false,
                Size = UDim2.new(1, -80, 0, 32),
                LayoutOrder = i,
                Parent = slotList,
            })
            Corner(8, opt)

            opt.MouseEnter:Connect(function()
                Tween(opt, 0.12, {
                    BackgroundColor3 = self.Theme.Accent,
                    BackgroundTransparency = 0.3,
                }):Play()
            end)
            opt.MouseLeave:Connect(function()
                Tween(opt, 0.12, {
                    BackgroundColor3 = self.Theme.Background,
                    BackgroundTransparency = 0.5,
                }):Play()
            end)

            opt.MouseButton1Click:Connect(function()
                slotLbl.Text = name
                slotsExpanded = false
                Tween(slotList, 0.22, { Size = UDim2.new(1, -20, 0, 0) }):Play()
                Tween(listRow, 0.22, { Size = UDim2.new(1, 0, 0, 40) }):Play()
                Tween(listArrow, 0.2, { Rotation = 0 }):Play()
                self:LoadCustomTheme(name)
            end)

            local del = Create("TextButton", {
                Text = "x",
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextColor3 = Color3.fromRGB(255, 100, 100),
                BackgroundColor3 = self.Theme.Background,
                BackgroundTransparency = 0.5,
                AutoButtonColor = false,
                Size = UDim2.fromOffset(28, 32),
                Position = UDim2.new(1, -72, 0, 0),
                LayoutOrder = i,
                Parent = slotList,
            })
            Corner(8, del)

            del.MouseButton1Click:Connect(function()
                Compat.delete("LucidUI/Themes/" .. name .. ".json")
                if self.ThemeName == name then self:SetTheme("Default") end
                rebuildSaved()
                if self._themeDropdownRefresh then pcall(self._themeDropdownRefresh) end
                LucidUI:Notify({ Title = "Deleted", Message = name })
            end)

            table.insert(slotButtons, opt)
        end
    end

    self._savedThemeSlotsRefresh = rebuildSaved

    listHeader.MouseButton1Click:Connect(function()
        slotsExpanded = not slotsExpanded
        local h = 0
        if slotsExpanded then
            rebuildSaved()
            h = #slotButtons * 36 + 8
        end
        Tween(slotList, 0.22, { Size = UDim2.new(1, -20, 0, slotsExpanded and h or 0) }, Enum.EasingStyle.Quart):Play()
        Tween(listRow, 0.22, { Size = UDim2.new(1, 0, 0, slotsExpanded and (40 + h + 8) or 40) }, Enum.EasingStyle.Quart):Play()
        Tween(listArrow, 0.2, { Rotation = slotsExpanded and 180 or 0 }):Play()
    end)

    self:_registerTheme(function(t)
        listRow.BackgroundColor3 = t.Surface
        slotLbl.TextColor3 = t.Accent
        listArrow.TextColor3 = t.TextMuted
        saveRow.BackgroundColor3 = t.Surface
        nameBox.BackgroundColor3 = t.Background
        nameBox.TextColor3 = t.TextPrimary
        saveBtn.BackgroundColor3 = t.Accent
        for _, b in ipairs(slotButtons) do
            if b:IsA("TextButton") then
                b.BackgroundColor3 = t.Background
                b.TextColor3 = t.TextPrimary
            else
                b.TextColor3 = t.TextMuted
            end
        end
    end)
end

-- ============================================================
-- Background image
-- ============================================================
function LucidUI.Window:_buildBackgroundSettings()
    self:_addSettingSection("Background Image")

    -- URL input row
    local urlRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 40),
    })
    Corner(10, urlRow)
    self:_addSettingFrame(urlRow)

    Create("TextLabel", {
        Text = "Image URL",
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextColor3 = self.Theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -180, 1, 0),
        Parent = urlRow,
    })

    local urlBox = Create("TextBox", {
        Text = self._backgroundUrl or "",
        PlaceholderText = "asset id or https://...",
        PlaceholderColor3 = self.Theme.TextMuted,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = self.Theme.TextPrimary,
        BackgroundColor3 = self.Theme.Background,
        BackgroundTransparency = 0.3,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.fromOffset(140, 26),
        Position = UDim2.new(1, -154, 0.5, -13),
        Parent = urlRow,
    })
    Corner(8, urlBox)
    Create("UIPadding", {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        Parent = urlBox,
    })

    -- Action buttons
    local actionRow = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
    })
    self:_addSettingFrame(actionRow)
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        Parent = actionRow,
    })

    local function mkBtn(text, color, cb)
        local b = Create("TextButton", {
            Text = text,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundColor3 = color,
            BackgroundTransparency = 0.2,
            AutoButtonColor = false,
            Size = UDim2.new(0.33, -4, 1, 0),
            Parent = actionRow,
        })
        Corner(8, b)
        b.MouseButton1Click:Connect(cb)
        return b
    end

    local applyBtn = mkBtn("Apply", self.Theme.Accent, function()
        local url = urlBox.Text
        if url == "" then return end
        self:SetBackgroundImage(url)
    end)

    local detectBtn = mkBtn("Auto Accent", self.Theme.Surface, function()
        local url = urlBox.Text
        if url == "" then
            LucidUI:Notify({
                Title = "No URL",
                Message = "Paste a URL first",
                Accent = Color3.fromRGB(255, 80, 80),
            })
            return
        end

        local accent = self:AutoDetectAccent(url)
        if accent then
            self:SetAccent(accent)
            LucidUI:Notify({
                Title = "Accent Detected",
                Message = string.format(
                    "RGB(%d, %d, %d)",
                    math.floor(accent.R * 255),
                    math.floor(accent.G * 255),
                    math.floor(accent.B * 255)
                ),
            })
        else
            LucidUI:Notify({
                Title = "Detection Failed",
                Message = "Pick accent manually",
                Accent = Color3.fromRGB(255, 80, 80),
            })
        end
    end)

    local clearBtn = mkBtn("Clear", Color3.fromRGB(220, 60, 60), function()
        self:SetBackgroundImage(nil)
        urlBox.Text = ""
    end)

    -- Transparency slider
    local transRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 54),
    })
    Corner(10, transRow)
    self:_addSettingFrame(transRow)

    Create("TextLabel", {
        Text = "Image Transparency",
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextColor3 = self.Theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 6),
        Size = UDim2.new(1, -28, 0, 18),
        Parent = transRow,
    })

    local transValue = Create("TextLabel", {
        Text = "0.10",
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = self.Theme.Accent,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.fromOffset(14, 6),
        Size = UDim2.new(1, -28, 0, 18),
        Parent = transRow,
    })

    local transTrack = Create("Frame", {
        Size = UDim2.new(1, -28, 0, 4),
        Position = UDim2.new(0, 14, 1, -16),
        BackgroundColor3 = self.Theme.SliderTrack,
        BorderSizePixel = 0,
        Parent = transRow,
    })
    Corner(2, transTrack)

    local transFill = Create("Frame", {
        Size = UDim2.new(0.1, 0, 1, 0),
        BackgroundColor3 = self.Theme.Accent,
        BorderSizePixel = 0,
        Parent = transTrack,
    })
    Corner(2, transFill)

    local transHandle = Create("Frame", {
        Size = UDim2.fromOffset(18, 18),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.1, 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Parent = transTrack,
    })
    Corner(9, transHandle)

    local transDrag = Create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = transTrack,
    })

    local transActive = false
    local function setTrans(input)
        local rel = math.clamp(
            (input.Position.X - transTrack.AbsolutePosition.X) / transTrack.AbsoluteSize.X,
            0, 1
        )
        transFill.Size = UDim2.new(rel, 0, 1, 0)
        transHandle.Position = UDim2.new(rel, 0, 0.5, 0)
        transValue.Text = string.format("%.2f", rel)
        if self._bgImage and self._bgImage.Visible then
            self._bgImage.ImageTransparency = rel
        end
    end

    transDrag.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            transActive = true
            setTrans(input)
        end
    end)

    table.insert(self._conns, UserInputService.InputChanged:Connect(function(input)
        if not transActive then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            setTrans(input)
        end
    end))

    table.insert(self._conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            transActive = false
        end
    end))

    -- Info note
    local note = Create("TextLabel", {
        Text = "Supports asset IDs, rbxassetid:// URLs, and https:// links (via getcustomasset). PNG/JPG only.",
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = self.Theme.TextMuted,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    self:_addSettingFrame(note)

    self:_registerTheme(function(t)
        urlRow.BackgroundColor3 = t.Surface
        urlBox.BackgroundColor3 = t.Background
        urlBox.TextColor3 = t.TextPrimary
        transRow.BackgroundColor3 = t.Surface
        transValue.TextColor3 = t.Accent
        transTrack.BackgroundColor3 = t.SliderTrack
        transFill.BackgroundColor3 = t.Accent
        note.TextColor3 = t.TextMuted
        applyBtn.BackgroundColor3 = t.Accent
        detectBtn.BackgroundColor3 = t.Surface
    end)
end

-- ============================================================
-- Set background image
-- ============================================================
function LucidUI.Window:SetBackgroundImage(url)
    if not self._bgImage then return end

    -- Clear
    if not url or url == "" then
        Tween(self._bgImage, 0.2, { ImageTransparency = 1 }):Play()
        task.delay(0.25, function()
            if self._bgImage then self._bgImage.Visible = false end
            if self.Main then
                self.Main.BackgroundTransparency = self.Theme.BackgroundTrans
            end
        end)
        self._backgroundUrl = nil
        return
    end

    self._backgroundUrl = url

    -- HTTP(S) → download, then apply
    if url:match("^https?://") then
        local ok = self:_downloadAndLoadImage(url)
        if not ok then
            LucidUI:Notify({
                Title = "Download Failed",
                Message = "Executor needs getcustomasset + writefile support",
                Accent = Color3.fromRGB(255, 80, 80),
            })
        end
        return
    end

    -- Asset ID forms
    local imageId = url
    if not url:match("^rbxasset") then
        local num = url:match("(%d+)")
        if not num then
            LucidUI:Notify({
                Title = "Invalid URL",
                Message = "Use an asset ID or https:// link",
                Accent = Color3.fromRGB(255, 80, 80),
            })
            return
        end
        imageId = "rbxassetid://" .. num
    end

    self._bgImage.Image = imageId
    self._bgImage.Visible = true
    self._bgImage.ImageTransparency = 1
    Tween(self._bgImage, 0.4, { ImageTransparency = 0.10 }):Play()
    Tween(self.Main, 0.4, { BackgroundTransparency = 0.65 }):Play()
end

function LucidUI.Window:_downloadAndLoadImage(url)
    if not Compat.hasCustomAsset() then
        warn("[LucidUI] getcustomasset not available")
        return false
    end
    if not Compat.hasFS() then
        warn("[LucidUI] writefile not available")
        return false
    end

    local ext = url:match("%.(%w+)%?") or url:match("%.(%w+)$") or "png"
    ext = ext:lower()
    if ext ~= "png" and ext ~= "jpg" and ext ~= "jpeg" then
        ext = "png"
    end

    Compat.ensureFolders()
    local filename = "LucidUI/bg_" .. tostring(os.time()) .. "." .. ext

    local ok, data = pcall(function() return game:HttpGet(url, true) end)
    if not ok or not data or #data == 0 then
        warn("[LucidUI] HTTP download failed")
        return false
    end

    if not Compat.write(filename, data) then
        warn("[LucidUI] writefile failed")
        return false
    end

    local assetOk, asset = pcall(getcustomasset, filename)
    if not assetOk or not asset then
        warn("[LucidUI] getcustomasset failed")
        return false
    end

    self._bgImage.Image = asset
    self._bgImage.Visible = true
    self._bgImage.ImageTransparency = 1
    Tween(self._bgImage, 0.4, { ImageTransparency = 0.10 }):Play()
    Tween(self.Main, 0.4, { BackgroundTransparency = 0.65 }):Play()
    return true
end

-- ============================================================
-- Auto accent detection
-- ============================================================
function LucidUI.Window:AutoDetectAccent(url)
    local imageId = url
    if not imageId:match("^rbxasset") then
        local num = imageId:match("(%d+)")
        if num then imageId = "rbxassetid://" .. num end
    end

    local ok, img = pcall(function()
        return game:GetService("AssetService"):CreateEditableImageAsync(imageId)
    end)
    if not ok or not img then return nil end

    local size = img.Size
    if not size or size.X == 0 or size.Y == 0 then return nil end

    local rSum, gSum, bSum, count = 0, 0, 0, 0
    local stepX = math.max(1, math.floor(size.X / 20))
    local stepY = math.max(1, math.floor(size.Y / 20))

    for y = 0, size.Y - 1, stepY do
        for x = 0, size.X - 1, stepX do
            local ok2, pixels = pcall(function()
                return img:ReadPixels(Vector2.new(x, y), Vector2.new(1, 1))
            end)
            if ok2 and pixels and #pixels >= 3 then
                rSum = rSum + pixels[1]
                gSum = gSum + pixels[2]
                bSum = bSum + pixels[3]
                count = count + 1
            end
        end
    end

    if count == 0 then return nil end

    local avg = Color3.new(rSum / count, gSum / count, bSum / count)
    local h, s, v = Color3.toHSV(avg)
    return Color3.fromHSV(h, math.min(s * 1.4, 1), math.max(v, 0.75))
end

-- ============================================================
-- Config slots
-- ============================================================
function LucidUI.Window:_buildConfigSettings()
    self:_addSettingSection("Configs")

    local row = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 40),
        ClipsDescendants = true,
    })
    Corner(10, row)
    self:_addSettingFrame(row)

    local headerBtn = Create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 40),
        Parent = row,
    })

    Create("TextLabel", {
        Text = "Active Config",
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextColor3 = self.Theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -100, 1, 0),
        Parent = headerBtn,
    })

    local slotLabel = Create("TextLabel", {
        Text = self._currentConfig,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = self.Theme.Accent,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Size = UDim2.new(1, -34, 1, 0),
        Parent = headerBtn,
    })

    local arrowLbl = Create("TextLabel", {
        Text = "v",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = self.Theme.TextMuted,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -24, 0, 0),
        Size = UDim2.fromOffset(20, 40),
        Parent = headerBtn,
    })

    local list = Create("Frame", {
        Size = UDim2.new(1, -20, 0, 0),
        Position = UDim2.fromOffset(10, 40),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = row,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = list,
    })

    local expanded = false
    local slotButtons = {}

    local function rebuildSlots()
        for _, b in ipairs(slotButtons) do b:Destroy() end
        slotButtons = {}

        local slots = Compat.listConfigs()
        for i, name in ipairs(slots) do
            local isDefault = (name == "default")
            local label = isDefault and (name .. "  (locked)") or name

            local opt = Create("TextButton", {
                Text = label,
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextColor3 = self.Theme.TextPrimary,
                BackgroundColor3 = self.Theme.Background,
                BackgroundTransparency = 0.5,
                AutoButtonColor = false,
                Size = UDim2.new(1, 0, 0, 32),
                LayoutOrder = i,
                Parent = list,
            })
            Corner(8, opt)

            opt.MouseEnter:Connect(function()
                Tween(opt, 0.12, {
                    BackgroundColor3 = self.Theme.Accent,
                    BackgroundTransparency = 0.3,
                }):Play()
            end)
            opt.MouseLeave:Connect(function()
                Tween(opt, 0.12, {
                    BackgroundColor3 = self.Theme.Background,
                    BackgroundTransparency = 0.5,
                }):Play()
            end)

            opt.MouseButton1Click:Connect(function()
                self._currentConfig = name
                slotLabel.Text = name
                expanded = false
                Tween(list, 0.22, { Size = UDim2.new(1, -20, 0, 0) }):Play()
                Tween(row, 0.22, { Size = UDim2.new(1, 0, 0, 40) }):Play()
                Tween(arrowLbl, 0.2, { Rotation = 0 }):Play()
                self:LoadConfig(name)
            end)

            table.insert(slotButtons, opt)
        end
    end

    headerBtn.MouseButton1Click:Connect(function()
        expanded = not expanded
        local h = 0
        if expanded then
            rebuildSlots()
            h = #slotButtons * 36 + 8
        end
        Tween(list, 0.22, { Size = UDim2.new(1, -20, 0, expanded and h or 0) }, Enum.EasingStyle.Quart):Play()
        Tween(row, 0.22, { Size = UDim2.new(1, 0, 0, expanded and (40 + h + 8) or 40) }, Enum.EasingStyle.Quart):Play()
        Tween(arrowLbl, 0.2, { Rotation = expanded and 180 or 0 }):Play()
    end)

    self._themeSlotsRefresh = rebuildSlots

    -- Save As New
    local newRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 40),
    })
    Corner(10, newRow)
    self:_addSettingFrame(newRow)

    local inputBox = Create("TextBox", {
        Text = "",
        PlaceholderText = "new config name...",
        PlaceholderColor3 = self.Theme.TextMuted,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = self.Theme.TextPrimary,
        BackgroundColor3 = self.Theme.Background,
        BackgroundTransparency = 0.3,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -110, 0, 26),
        Position = UDim2.new(0, 14, 0.5, -13),
        Parent = newRow,
    })
    Corner(8, inputBox)
    Create("UIPadding", {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        Parent = inputBox,
    })

    local saveNewBtn = Create("TextButton", {
        Text = "Save As New",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = self.Theme.Accent,
        BackgroundTransparency = 0.2,
        AutoButtonColor = false,
        Size = UDim2.fromOffset(90, 26),
        Position = UDim2.new(1, -104, 0.5, -13),
        Parent = newRow,
    })
    Corner(8, saveNewBtn)

    saveNewBtn.MouseButton1Click:Connect(function()
        local name = inputBox.Text
        if name == "" or name == "default" then
            LucidUI:Notify({
                Title = "Invalid Name",
                Message = "Pick a name other than 'default'",
                Accent = Color3.fromRGB(255, 80, 80),
            })
            return
        end
        self:SaveConfig(name)
        inputBox.Text = ""
        rebuildSlots()
    end)

    -- Action buttons
    local actionRow = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
    })
    self:_addSettingFrame(actionRow)
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        Parent = actionRow,
    })

    local function mkBtn(label, color, cb)
        local b = Create("TextButton", {
            Text = label,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundColor3 = color,
            BackgroundTransparency = 0.2,
            AutoButtonColor = false,
            Size = UDim2.new(0.33, -4, 1, 0),
            Parent = actionRow,
        })
        Corner(8, b)
        b.MouseButton1Click:Connect(cb)
        return b
    end

    mkBtn("Save", self.Theme.Accent, function()
        self:SaveConfig(self._currentConfig)
        rebuildSlots()
    end)

    mkBtn("Load", self.Theme.Surface, function()
        self:LoadConfig(self._currentConfig)
    end)

    mkBtn("Delete", Color3.fromRGB(220, 60, 60), function()
        if self._currentConfig == "default" then
            LucidUI:Notify({
                Title = "Cannot Delete",
                Message = "Default is locked",
                Accent = Color3.fromRGB(255, 80, 80),
            })
            return
        end
        Compat.delete("LucidUI/Configs/" .. self._currentConfig .. ".json")
        self._currentConfig = "default"
        slotLabel.Text = "default"
        rebuildSlots()
        LucidUI:Notify({ Title = "Config Deleted", Message = "Slot removed" })
    end)

    self:_registerTheme(function(t)
        row.BackgroundColor3 = t.Surface
        slotLabel.TextColor3 = t.Accent
        arrowLbl.TextColor3 = t.TextMuted
        newRow.BackgroundColor3 = t.Surface
        inputBox.BackgroundColor3 = t.Background
        inputBox.TextColor3 = t.TextPrimary
        saveNewBtn.BackgroundColor3 = t.Accent
        for _, b in ipairs(slotButtons) do
            b.BackgroundColor3 = t.Background
            b.TextColor3 = t.TextPrimary
        end
    end)
end

-- ============================================================
-- About
-- ============================================================
function LucidUI.Window:_buildAboutSettings()
    self:_addSettingSection("About")

    local row = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    Corner(10, row)
    self:_addSettingFrame(row)

    Create("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 14),
        PaddingRight = UDim.new(0, 14),
        Parent = row,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = row,
    })

    local lbl = Create("TextLabel", {
        Text = "LucidUI v" .. LucidUI._version .. "\nA modern, glass-morphism UI for Roblox.\nMIT licensed.",
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = self.Theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1,
        Parent = row,
    })

    self:_registerTheme(function(t)
        row.BackgroundColor3 = t.Surface
        lbl.TextColor3 = t.TextPrimary
    end)
end

-- ============================================================
-- Build every settings section
-- ============================================================
function LucidUI.Window:BuildSettingsPanel()
    if self._settingsBuilt then return end
    self._settingsBuilt = true

    self:_buildThemeSettings()
    self:_buildCustomThemeSettings()
    self:_buildBackgroundSettings()
    self:_buildConfigSettings()
    self:_buildAboutSettings()
end

-- ============================================================
-- Config save / load
-- ============================================================
function LucidUI.Window:SaveConfig(profileName)
    profileName = profileName or "default"

    local data = {
        theme = self._customThemeActive and "Custom" or self.ThemeName,
        accent = self._accentOverride and {
            R = self._accentOverride.R,
            G = self._accentOverride.G,
            B = self._accentOverride.B,
        } or nil,
        windowSize = { self._width, self._height },
        customTheme = self._customTheme and Compat.serializeColors(self._customTheme) or nil,
        backgroundUrl = self._backgroundUrl,
        elements = self._configData,
    }

    local encoded = Compat.encode(data)
    if not encoded then return end

    Compat.ensureFolders()
    local ok = Compat.write("LucidUI/Configs/" .. profileName .. ".json", encoded)

    if ok then
        LucidUI:Notify({ Title = "Config Saved", Message = profileName })
        if self._themeSlotsRefresh then pcall(self._themeSlotsRefresh) end
    else
        LucidUI:Notify({
            Title = "Save Failed",
            Message = "No file system",
            Accent = Color3.fromRGB(255, 80, 80),
        })
    end
end

function LucidUI.Window:LoadConfig(profileName)
    profileName = profileName or "default"
    local contents = Compat.read("LucidUI/Configs/" .. profileName .. ".json")

    if not contents then
        LucidUI:Notify({
            Title = "Load Failed",
            Message = "Not found: " .. profileName,
            Accent = Color3.fromRGB(255, 80, 80),
        })
        return
    end

    local data = Compat.decode(contents)
    if not data then return end

    if data.theme then
        if data.theme == "Custom" and data.customTheme then
            local restored = Compat.deserializeColors(data.customTheme)
            if restored then
                local d = LucidUI.Themes.Default
                self._customTheme = {
                    Background   = restored.Background   or d.Background,
                    Surface      = restored.Surface      or d.Surface,
                    SurfaceHover = restored.SurfaceHover or d.SurfaceHover,
                    Accent       = restored.Accent       or d.Accent,
                    Border       = restored.Border       or d.Border,
                    TextPrimary  = restored.TextPrimary  or d.TextPrimary,
                }
                self:ApplyCustomTheme()
            end
        elseif data.theme == "Default" then
            self:SetTheme("Default")
        end
    end

    if data.accent then
        self:SetAccent(Color3.new(data.accent.R, data.accent.G, data.accent.B))
    end

    if data.windowSize then
        self._width  = math.clamp(data.windowSize[1], self._minWidth,  self._maxWidth)
        self._height = math.clamp(data.windowSize[2], self._minHeight, self._maxHeight)
        self._fullSize = UDim2.fromOffset(self._width, self._height)
        self._collapsedSize = UDim2.fromOffset(self._width, 44)
        if not self.Minimized then
            self.Main.Size = self._fullSize
        end
    end

    if data.backgroundUrl then
        self:SetBackgroundImage(data.backgroundUrl)
    end

    local applied = 0
    if data.elements then
        for flag, value in pairs(data.elements) do
            local el = self._elementsByFlag[flag]
            if el and el.Set then
                pcall(function() el:Set(value) end)
                applied = applied + 1
            end
        end
    end

    LucidUI:Notify({
        Title = "Config Loaded",
        Message = profileName .. " (" .. applied .. ")",
    })
end

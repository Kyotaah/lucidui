-- ============================================================
-- Module: 09_elements.lua
-- ============================================================
--[[
    Elements — every interactive widget LucidUI ships.

    [IMPROVEMENT] Added ProgressBar, LoadingSpinner, ConfirmDialog.
    Added search to Dropdown. Added Loading state to Button.
    All callbacks wrapped in Compat.safeCallback. All elements now
    have Get/Set methods.

    [NEW] Every builder accepts a `Tooltip = "..."` config field.
    When provided, a themed tooltip is attached (works on hover and
    mobile long-press via 08n_tooltips.lua).
]]--

-- ============================================================
-- Button
-- ============================================================
function LucidUI.Section:CreateButton(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local btn = Create("TextButton", {
        Text = "",
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans,
        AutoButtonColor = false,
        ClipsDescendants = true,
        Size = UDim2.new(1, 0, 0, 38),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, btn)
    local stroke = Stroke(theme.Border, 1, theme.BorderTrans + 0.05, btn)

    local label = Create("TextLabel", {
        Text = config.Name or "Button",
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextColor3 = theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Center,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 3,
        Parent = btn,
    })

    local glow = AttachHoverGlow(btn, theme.Accent)
    AttachHoverSound(btn)

    local pressPos = Vector2.new()
    local busy = false

    BindTap(btn, function()
        if busy then return end
        local abs = btn.AbsolutePosition
        SpawnRipple(btn, pressPos.X - abs.X, pressPos.Y - abs.Y)
        PlayUISound("click")
        Compat.safeCallback(config.Callback)
    end, { OnDown = function(input) pressPos = input.Position end, Scale = true, ScaleAmount = 0.98 })

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            Tween(btn, 0.08, { Size = UDim2.new(1, 0, 0, 36) }):Play()
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            Tween(btn, 0.15, { Size = UDim2.new(1, 0, 0, 38) }):Play()
        end
    end)

    btn.MouseEnter:Connect(function()
        local t = win.Theme
        Tween(btn, 0.15, {
            BackgroundColor3 = t.SurfaceHover,
            BackgroundTransparency = t.SurfaceHoverTrans or 0.15,
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        local t = win.Theme
        Tween(btn, 0.15, {
            BackgroundColor3 = t.Surface,
            BackgroundTransparency = t.SurfaceTrans,
            Size = UDim2.new(1, 0, 0, 38),
        }):Play()
    end)

    win:_registerTheme(function(t)
        btn.BackgroundColor3 = t.Surface
        label.TextColor3 = t.TextPrimary
        stroke.Color = t.Border
        if glow then glow.Color = t.Accent end
    end)

    self:_track(btn)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(btn, config.Tooltip)
    end

    return {
        Instance = btn,
        SetText = function(_, text) label.Text = tostring(text) end,
        GetText = function() return label.Text end,
        SetLoading = function(_, on)
            busy = on and true or false
            label.TextTransparency = busy and 0.5 or 0
        end,
    }
end

-- ============================================================
-- ButtonPair
-- ============================================================
function LucidUI.Section:CreateButtonPair(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local row = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 38),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })

    local function makeBtn(side, info)
        info = info or {}
        local btn = Create("TextButton", {
            Text = "",
            BackgroundColor3 = info.Color or theme.Surface,
            BackgroundTransparency = info.Color and 0.15 or theme.SurfaceTrans,
            AutoButtonColor = false,
            ClipsDescendants = true,
            Size = UDim2.new(0.5, -3, 1, 0),
            Position = UDim2.new(side == "right" and 1 or 0, side == "right" and -3 or 0, 0, 0),
            AnchorPoint = side == "right" and Vector2.new(1, 0) or Vector2.new(0, 0),
            ZIndex = 2,
            Parent = row,
        })
        Corner(10, btn)
        local stroke = Stroke(theme.Border, 1, theme.BorderTrans + 0.05, btn)

        local label = Create("TextLabel", {
            Text = info.Name or side,
            Font = Enum.Font.GothamMedium, TextSize = 13,
            TextColor3 = info.TextColor or theme.TextPrimary,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Center,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 3, Parent = btn,
        })

        local glow = AttachHoverGlow(btn, theme.Accent)
        AttachHoverSound(btn)

        local pressPos = Vector2.new()
        BindTap(btn, function()
            local abs = btn.AbsolutePosition
            SpawnRipple(btn, pressPos.X - abs.X, pressPos.Y - abs.Y)
            PlayUISound("click")
            Compat.safeCallback(info.Callback)
        end, { OnDown = function(input) pressPos = input.Position end })

        btn.MouseEnter:Connect(function()
            local t = win.Theme
            if not info.Color then
                Tween(btn, 0.15, { BackgroundColor3 = t.SurfaceHover }):Play()
            else
                Tween(btn, 0.15, { BackgroundTransparency = 0.05 }):Play()
            end
        end)
        btn.MouseLeave:Connect(function()
            local t = win.Theme
            if not info.Color then
                Tween(btn, 0.15, {
                    BackgroundColor3 = t.Surface,
                    BackgroundTransparency = t.SurfaceTrans,
                }):Play()
            else
                Tween(btn, 0.15, { BackgroundTransparency = 0.15 }):Play()
            end
        end)

        win:_registerTheme(function(t)
            if not info.Color then
                btn.BackgroundColor3 = t.Surface
                label.TextColor3 = info.TextColor or t.TextPrimary
            end
            stroke.Color = t.Border
            if glow then glow.Color = t.Accent end
        end)

        return { Instance = btn, SetText = function(_, text) label.Text = tostring(text) end }
    end

    local left  = makeBtn("left",  config.Left)
    local right = makeBtn("right", config.Right)

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return { Instance = row, Left = left, Right = right }
end

-- ============================================================
-- Toggle
-- ============================================================
function LucidUI.Section:CreateToggle(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme
    local state = config.CurrentValue or false
    local flag  = config.Flag

    local row = Create("Frame", {
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 42),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, row)
    local rowStroke = Stroke(theme.Border, 1, theme.BorderTrans + 0.05, row)

    local label = Create("TextLabel", {
        Text = config.Name or "Toggle",
        Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -80, 1, 0),
        ZIndex = 3, Parent = row,
    })

    local track = Create("Frame", {
        Size = UDim2.fromOffset(44, 24),
        Position = UDim2.new(1, -58, 0.5, -12),
        BackgroundColor3 = state and theme.Accent or theme.ToggleOff,
        BorderSizePixel = 0, ZIndex = 3, Parent = row,
    })
    Corner(12, track)

    local knob = Create("Frame", {
        Size = UDim2.fromOffset(20, 20),
        Position = state and UDim2.new(1, -22, 0.5, -10) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0, ZIndex = 4, Parent = track,
    })
    Corner(10, knob)

    local clickArea = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = row,
    })

    local glow = AttachHoverGlow(row, theme.Accent)
    AttachHoverSound(row)

    local function update(value, silent)
        state = value
        local t = win.Theme
        pcall(function()
            Tween(track, 0.22, {
                BackgroundColor3 = state and t.Accent or t.ToggleOff,
            }, Enum.EasingStyle.Quart):Play()
            Tween(knob, 0.22, {
                Position = state and UDim2.new(1, -22, 0.5, -10) or UDim2.fromOffset(2, 2),
            }, Enum.EasingStyle.Quart):Play()
        end)
        if flag then win._configData[flag] = state end
        if not silent and config.Callback then Compat.safeCallback(config.Callback, state) end
    end

    BindTap(clickArea, function()
        PlayUISound("click")
        update(not state)
    end)

    clickArea.MouseEnter:Connect(function()
        local t = win.Theme
        Tween(row, 0.15, { BackgroundTransparency = math.max(t.SurfaceTrans - 0.1, 0) }):Play()
    end)
    clickArea.MouseLeave:Connect(function()
        local t = win.Theme
        Tween(row, 0.15, { BackgroundTransparency = t.SurfaceTrans }):Play()
    end)

    win:_registerTheme(function(t)
        row.BackgroundColor3 = t.Surface
        label.TextColor3 = t.TextPrimary
        rowStroke.Color = t.Border
        track.BackgroundColor3 = state and t.Accent or t.ToggleOff
        if glow then glow.Color = t.Accent end
    end)

    local obj = {
        Instance = row, Flag = flag,
        Set = function(_, value) update(value, true) end,
        Get = function() return state end,
    }
    if flag then
        win._elementsByFlag[flag] = obj
        win._configData[flag] = state
    end

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return obj
end

-- ============================================================
-- Checkbox
-- ============================================================
function LucidUI.Section:CreateCheckbox(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme
    local state = config.CurrentValue or false
    local flag  = config.Flag

    local row = Create("Frame", {
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 38),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, row)
    local rowStroke = Stroke(theme.Border, 1, theme.BorderTrans + 0.05, row)

    local box = Create("Frame", {
        Size = UDim2.fromOffset(20, 20),
        Position = UDim2.fromOffset(14, 9),
        BackgroundColor3 = state and theme.Accent or theme.Background,
        BackgroundTransparency = state and 0 or 0.3,
        BorderSizePixel = 0,
        ZIndex = 3, Parent = row,
    })
    Corner(5, box)
    local boxStroke = Stroke(theme.Border, 1, state and 1 or 0.4, box)

    local shortArm = Create("Frame", {
        Size = UDim2.fromOffset(5, 2),
        Position = UDim2.new(0.42, 0, 0.58, 0),
        AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = state and 0 or 1,
        BorderSizePixel = 0, ZIndex = 4, Parent = box,
    })
    Corner(1, shortArm)

    local longArm = Create("Frame", {
        Size = UDim2.fromOffset(10, 2),
        Position = UDim2.new(0.58, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5), Rotation = -45,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = state and 0 or 1,
        BorderSizePixel = 0, ZIndex = 4, Parent = box,
    })
    Corner(1, longArm)

    local label = Create("TextLabel", {
        Text = config.Name or "Check",
        Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(46, 0),
        Size = UDim2.new(1, -60, 1, 0),
        ZIndex = 3, Parent = row,
    })

    local clickArea = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = row,
    })

    AttachHoverSound(row)

    local function update(value, silent)
        state = value
        local t = win.Theme
        pcall(function()
            Tween(box, 0.18, {
                BackgroundColor3 = state and t.Accent or t.Background,
                BackgroundTransparency = state and 0 or 0.3,
            }, Enum.EasingStyle.Quart):Play()
            Tween(boxStroke, 0.18, { Transparency = state and 1 or 0.4 }):Play()
            Tween(shortArm, 0.18, { BackgroundTransparency = state and 0 or 1 }):Play()
            Tween(longArm, 0.18, { BackgroundTransparency = state and 0 or 1 }):Play()
        end)
        if flag then win._configData[flag] = state end
        if not silent and config.Callback then Compat.safeCallback(config.Callback, state) end
    end

    BindTap(clickArea, function()
        PlayUISound("click")
        update(not state)
    end)

    clickArea.MouseEnter:Connect(function()
        local t = win.Theme
        Tween(row, 0.15, { BackgroundTransparency = math.max(t.SurfaceTrans - 0.1, 0) }):Play()
    end)
    clickArea.MouseLeave:Connect(function()
        local t = win.Theme
        Tween(row, 0.15, { BackgroundTransparency = t.SurfaceTrans }):Play()
    end)

    win:_registerTheme(function(t)
        row.BackgroundColor3 = t.Surface
        label.TextColor3 = t.TextPrimary
        rowStroke.Color = t.Border
        boxStroke.Color = t.Border
        if not state then box.BackgroundColor3 = t.Background end
        if state then box.BackgroundColor3 = t.Accent end
    end)

    local obj = {
        Instance = row, Flag = flag,
        Set = function(_, value) update(value, true) end,
        Get = function() return state end,
    }
    if flag then
        win._elementsByFlag[flag] = obj
        win._configData[flag] = state
    end

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return obj
end

-- ============================================================
-- Radio
-- ============================================================
function LucidUI.Section:CreateRadio(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local options = config.Options or {}
    local value   = config.Default or options[1]
    local flag    = config.Flag

    local container = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })

    if config.Name then
        Create("TextLabel", {
            Text = config.Name,
            Font = Enum.Font.GothamBold, TextSize = 12,
            TextColor3 = theme.TextMuted, BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, 20),
            LayoutOrder = 1, ZIndex = 3, Parent = container,
        })
    end

    local list = Create("Frame", {
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2, ZIndex = 2, Parent = container,
    })
    Corner(10, list)
    local listStroke = Stroke(theme.Border, 1, theme.BorderTrans + 0.05, list)
    Create("UIListLayout", {
        Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list,
    })

    local ROW_H = 38
    local refs = {}

    local function setValue(new, silent)
        if value == new and silent then return end
        value = new

        for opt, ref in pairs(refs) do
            local selected = (opt == value)
            local t = win.Theme
            Tween(ref.dot, 0.18, {
                BackgroundColor3 = selected and t.Accent or t.Background,
                BackgroundTransparency = selected and 0 or 0.4,
            }, Enum.EasingStyle.Quart):Play()
            Tween(ref.dotStroke, 0.18, { Transparency = selected and 1 or 0.4 }):Play()
            Tween(ref.inner, 0.18, { BackgroundTransparency = selected and 0 or 1 }):Play()
        end

        if flag then win._configData[flag] = value end
        if not silent and config.Callback then Compat.safeCallback(config.Callback, value) end
    end

    for i, opt in ipairs(options) do
        local optRow = Create("TextButton", {
            Text = "",
            BackgroundTransparency = 1, AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, ROW_H),
            LayoutOrder = i, ZIndex = 3, Parent = list,
        })

        local dot = Create("Frame", {
            Size = UDim2.fromOffset(18, 18),
            Position = UDim2.fromOffset(14, (ROW_H - 18) / 2),
            BackgroundColor3 = (opt == value) and theme.Accent or theme.Background,
            BackgroundTransparency = (opt == value) and 0 or 0.4,
            BorderSizePixel = 0, ZIndex = 4, Parent = optRow,
        })
        Corner(999, dot)
        local dotStroke = Stroke(theme.Border, 1, (opt == value) and 1 or 0.4, dot)

        local inner = Create("Frame", {
            Size = UDim2.fromOffset(7, 7),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = (opt == value) and 0 or 1,
            BorderSizePixel = 0, ZIndex = 5, Parent = dot,
        })
        Corner(999, inner)

        local lbl = Create("TextLabel", {
            Text = tostring(opt),
            Font = Enum.Font.GothamMedium, TextSize = 13,
            TextColor3 = theme.TextPrimary, BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(44, 0),
            Size = UDim2.new(1, -58, 1, 0),
            ZIndex = 4, Parent = optRow,
        })

        refs[opt] = { dot = dot, dotStroke = dotStroke, inner = inner, label = lbl, row = optRow }

        optRow.MouseEnter:Connect(function()
            local t = win.Theme
            Tween(optRow, 0.12, { BackgroundColor3 = t.SurfaceHover, BackgroundTransparency = 0.4 }):Play()
        end)
        optRow.MouseLeave:Connect(function()
            Tween(optRow, 0.12, { BackgroundTransparency = 1 }):Play()
        end)

        BindTap(optRow, function()
            PlayUISound("click")
            setValue(opt)
        end)
    end

    win:_registerTheme(function(t)
        list.BackgroundColor3 = t.Surface
        listStroke.Color = t.Border
        for opt, ref in pairs(refs) do
            ref.label.TextColor3 = t.TextPrimary
            ref.dotStroke.Color = t.Border
            if opt ~= value then ref.dot.BackgroundColor3 = t.Background end
            if opt == value then ref.dot.BackgroundColor3 = t.Accent end
        end
        if config.Name then
            for _, c in ipairs(container:GetChildren()) do
                if c:IsA("TextLabel") then c.TextColor3 = t.TextMuted end
            end
        end
    end)

    self:_track(container)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(container, config.Tooltip)
    end

    local obj = {
        Instance = container, Flag = flag,
        Set = function(_, v) if refs[v] then setValue(v, true) end end,
        Get = function() return value end,
    }
    if flag then
        win._elementsByFlag[flag] = obj
        win._configData[flag] = value
    end

    return obj
end

-- ============================================================
-- Slider
-- ============================================================
function LucidUI.Section:CreateSlider(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local min   = (config.Range and config.Range[1]) or 0
    local max   = (config.Range and config.Range[2]) or 100
    local value = config.CurrentValue or min
    local inc   = config.Increment or 1
    local flag  = config.Flag

    local HANDLE_BASE, HANDLE_HOVER, HANDLE_GRAB = 18, 20, 22

    local row = Create("Frame", {
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 56),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, row)
    local rowStroke = Stroke(theme.Border, 1, theme.BorderTrans + 0.05, row)

    local nameLabel = Create("TextLabel", {
        Text = config.Name or "Slider",
        Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 8),
        Size = UDim2.new(1, -28, 0, 18),
        ZIndex = 3, Parent = row,
    })

    local valueLabel = Create("TextLabel", {
        Text = tostring(value),
        Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = theme.Accent, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.fromOffset(14, 8),
        Size = UDim2.new(1, -28, 0, 18),
        ZIndex = 3, Parent = row,
    })

    local track = Create("Frame", {
        Size = UDim2.new(1, -28, 0, 4),
        Position = UDim2.new(0, 14, 1, -18),
        BackgroundColor3 = theme.SliderTrack,
        BorderSizePixel = 0, ZIndex = 3, Parent = row,
    })
    Corner(2, track)

    local fill = Create("Frame", {
        Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = theme.Accent, BorderSizePixel = 0, ZIndex = 4, Parent = track,
    })
    Corner(2, fill)

    local handle = Create("Frame", {
        Size = UDim2.fromOffset(HANDLE_BASE, HANDLE_BASE),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0, ZIndex = 4, Parent = track,
    })
    Corner(9, handle)
    local handleStroke = Stroke(theme.Border, 1, 0.7, handle)

    local drag = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0), ZIndex = 5, Parent = track,
    })

    local targetRel, displayRel = (value - min) / (max - min), (value - min) / (max - min)
    local DRAG_SPEED, SET_SPEED = 30, 12
    local dragging, hovering = false, false

    local scrollAncestor = nil
    do
        local p = row.Parent
        while p do
            if p:IsA("ScrollingFrame") then scrollAncestor = p break end
            p = p.Parent
        end
    end

    local lastFlashedValue = value
    local flashTween = nil
    local function flashIfChanged()
        if value == lastFlashedValue then return end
        lastFlashedValue = value
        if flashTween then pcall(function() flashTween:Cancel() end) end
        valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        flashTween = Tween(valueLabel, 0.32, { TextColor3 = win.Theme.Accent })
        flashTween:Play()
    end

    local function setFromInput(input)
        local rel = math.clamp(
            (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1
        )
        local raw = min + (max - min) * rel
        value = math.floor((raw / inc) + 0.5) * inc
        value = math.clamp(value, min, max)
        targetRel = (value - min) / (max - min)
        valueLabel.Text = tostring(value)
        flashIfChanged()
    end

    local function setHandleSize(size)
        Tween(handle, 0.14, { Size = UDim2.fromOffset(size, size) }, Enum.EasingStyle.Quart):Play()
    end

    drag.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if LucidUI._activeSlider and LucidUI._activeSlider ~= drag then return end
            LucidUI._activeSlider = drag
            dragging = true
            if scrollAncestor then scrollAncestor.ScrollingEnabled = false end
            setHandleSize(HANDLE_GRAB)
            Tween(handleStroke, 0.12, { Transparency = 0.35 }):Play()
            setFromInput(input)
            if flag then win._configData[flag] = value end
            if config.Callback then Compat.safeCallback(config.Callback, value) end
        end
    end)

    table.insert(win._conns, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            setFromInput(input)
            if flag then win._configData[flag] = value end
            if config.Callback then Compat.safeCallback(config.Callback, value) end
        end
    end))

    table.insert(win._conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if LucidUI._activeSlider == drag then LucidUI._activeSlider = nil end
            if not dragging then return end
            dragging = false
            if scrollAncestor then scrollAncestor.ScrollingEnabled = true end
            setHandleSize(hovering and HANDLE_HOVER or HANDLE_BASE)
            Tween(handleStroke, 0.18, { Transparency = 0.7 }):Play()
        end
    end))

    drag.MouseEnter:Connect(function()
        hovering = true
        local t = win.Theme
        Tween(row, 0.15, {
            BackgroundTransparency = math.max(t.SurfaceTrans - 0.1, 0),
        }):Play()
        if not dragging then setHandleSize(HANDLE_HOVER) end
    end)
    drag.MouseLeave:Connect(function()
        hovering = false
        local t = win.Theme
        Tween(row, 0.15, { BackgroundTransparency = t.SurfaceTrans }):Play()
        if not dragging then setHandleSize(HANDLE_BASE) end
    end)

    table.insert(win._conns, RunService.RenderStepped:Connect(function(dt)
        if not fill.Parent or not handle.Parent then return end
        local diff = targetRel - displayRel
        if math.abs(diff) < 0.0004 then
            if displayRel ~= targetRel then
                displayRel = targetRel
                fill.Size = UDim2.new(displayRel, 0, 1, 0)
                handle.Position = UDim2.new(displayRel, 0, 0.5, 0)
            end
            return
        end
        local speed = dragging and DRAG_SPEED or SET_SPEED
        local alpha = 1 - math.exp(-speed * dt)
        displayRel = displayRel + diff * alpha
        fill.Size = UDim2.new(displayRel, 0, 1, 0)
        handle.Position = UDim2.new(displayRel, 0, 0.5, 0)
    end))

    win:_registerTheme(function(t)
        row.BackgroundColor3 = t.Surface
        nameLabel.TextColor3 = t.TextPrimary
        valueLabel.TextColor3 = t.Accent
        track.BackgroundColor3 = t.SliderTrack
        fill.BackgroundColor3 = t.Accent
        rowStroke.Color = t.Border
        handleStroke.Color = t.Border
    end)

    local obj = {
        Instance = row, Flag = flag,
        Set = function(_, v)
            v = math.clamp(v, min, max)
            value = v
            targetRel = (value - min) / (max - min)
            valueLabel.Text = tostring(value)
            flashIfChanged()
            if flag then win._configData[flag] = value end
        end,
        Get = function() return value end,
    }
    if flag then
        win._elementsByFlag[flag] = obj
        win._configData[flag] = value
    end

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return obj
end

-- ============================================================
-- Dropdown (with optional search)
-- ============================================================
function LucidUI.Section:CreateDropdown(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local options   = config.Options or {}
    local value     = config.CurrentOption or options[1] or ""
    local expanded  = false
    local flag      = config.Flag
    local withSearch = (config.Search ~= false) and (#options > 8)
    local filterText = ""

    local ROW_H, OPT_H, OPT_P = 42, 34, 4
    local SEARCH_H = withSearch and 34 or 0

    local row = Create("Frame", {
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, ROW_H),
        ClipsDescendants = true,
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, row)
    local rowStroke = Stroke(theme.Border, 1, theme.BorderTrans + 0.05, row)

    local headerBtn = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, ROW_H), ZIndex = 3, Parent = row,
    })

    local nameLabel = Create("TextLabel", {
        Text = config.Name or "Dropdown",
        Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -100, 1, 0),
        ZIndex = 4, Parent = headerBtn,
    })

    local valueLabel = Create("TextLabel", {
        Text = tostring(value),
        Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = theme.Accent, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Size = UDim2.new(1, -40, 1, 0), ZIndex = 4, Parent = headerBtn,
    })

    local arrowLbl = Create("TextLabel", {
        Text = "v", Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = theme.TextMuted, BackgroundTransparency = 1,
        Position = UDim2.new(1, -24, 0, 0), Size = UDim2.fromOffset(20, ROW_H),
        ZIndex = 4, Parent = headerBtn,
    })

    local searchBox
    if withSearch then
        searchBox = Create("TextBox", {
            Text = "",
            PlaceholderText = "Search...",
            PlaceholderColor3 = theme.TextMuted,
            Font = Enum.Font.Gotham, TextSize = 12,
            TextColor3 = theme.TextPrimary,
            BackgroundColor3 = theme.Background,
            BackgroundTransparency = 0.3,
            ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, -20, 0, 26),
            Position = UDim2.fromOffset(10, ROW_H + 4),
            ZIndex = 4,
            Parent = row,
        })
        Corner(8, searchBox)
        Create("UIPadding", {
            PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = searchBox,
        })
    end

    local list = Create("Frame", {
        Size = UDim2.new(1, -20, 0, 0),
        Position = UDim2.fromOffset(10, ROW_H + SEARCH_H + 4),
        BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 3, Parent = row,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, OPT_P), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list,
    })

    local optionBtns = {}

    local function rebuildOptions()
        for _, b in ipairs(optionBtns) do pcall(function() b:Destroy() end) end
        optionBtns = {}

        local lower = filterText:lower()
        local idx = 0
        for _, opt in ipairs(options) do
            local matches = (lower == "") or tostring(opt):lower():find(lower, 1, true)
            if matches then
                idx = idx + 1
                local optBtn = Create("TextButton", {
                    Text = tostring(opt),
                    Font = Enum.Font.GothamMedium, TextSize = 13,
                    TextColor3 = theme.TextPrimary, BackgroundColor3 = theme.Background,
                    BackgroundTransparency = 0.5, AutoButtonColor = false,
                    Size = UDim2.new(1, 0, 0, OPT_H), LayoutOrder = idx,
                    ZIndex = 4, Parent = list,
                })
                Corner(8, optBtn)

                optBtn.MouseEnter:Connect(function()
                    local t = win.Theme
                    Tween(optBtn, 0.12, { BackgroundColor3 = t.Accent, BackgroundTransparency = 0.3 }):Play()
                end)
                optBtn.MouseLeave:Connect(function()
                    local t = win.Theme
                    Tween(optBtn, 0.12, { BackgroundColor3 = t.Background, BackgroundTransparency = 0.5 }):Play()
                end)

                local optVal = opt
                BindTap(optBtn, function()
                    value = optVal
                    valueLabel.Text = tostring(optVal)
                    expanded = false
                    Tween(list, 0.22, { Size = UDim2.new(1, -20, 0, 0) }):Play()
                    Tween(row, 0.22, { Size = UDim2.new(1, 0, 0, ROW_H) }):Play()
                    Tween(arrowLbl, 0.20, { Rotation = 0 }):Play()
                    PlayUISound("click")
                    if flag then win._configData[flag] = value end
                    if config.Callback then Compat.safeCallback(config.Callback, optVal) end
                end)

                table.insert(optionBtns, optBtn)
            end
        end
    end

    rebuildOptions()

    if searchBox then
        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            filterText = searchBox.Text or ""
            rebuildOptions()
            local visibleCount = #optionBtns
            local openH = visibleCount * (OPT_H + OPT_P) + 8
            if expanded then
                Tween(list, 0.15, { Size = UDim2.new(1, -20, 0, openH) }):Play()
                Tween(row, 0.15, {
                    Size = UDim2.new(1, 0, 0, ROW_H + SEARCH_H + openH + 12),
                }):Play()
            end
        end)
    end

    BindTap(headerBtn, function()
        expanded = not expanded
        local visibleCount = #optionBtns
        local openH = visibleCount * (OPT_H + OPT_P) + 8
        Tween(list, 0.22, {
            Size = UDim2.new(1, -20, 0, expanded and openH or 0),
        }, Enum.EasingStyle.Quart):Play()
        Tween(row, 0.22, {
            Size = UDim2.new(1, 0, 0, expanded and (ROW_H + SEARCH_H + openH + 12) or ROW_H),
        }, Enum.EasingStyle.Quart):Play()
        Tween(arrowLbl, 0.20, { Rotation = expanded and 180 or 0 }):Play()
        PlayUISound("click")
    end)

    win:_registerTheme(function(t)
        row.BackgroundColor3  = t.Surface
        nameLabel.TextColor3  = t.TextPrimary
        valueLabel.TextColor3 = t.Accent
        arrowLbl.TextColor3   = t.TextMuted
        rowStroke.Color       = t.Border
        if searchBox then
            searchBox.BackgroundColor3 = t.Background
            searchBox.TextColor3       = t.TextPrimary
            searchBox.PlaceholderColor3 = t.TextMuted
        end
        for _, ob in ipairs(optionBtns) do
            ob.BackgroundColor3 = t.Background
            ob.TextColor3       = t.TextPrimary
        end
    end)

    local obj = {
        Instance = row, Flag = flag,
        Set = function(_, v)
            value = v
            valueLabel.Text = tostring(v)
            if flag then win._configData[flag] = value end
        end,
        Get = function() return value end,
    }
    if flag then
        win._elementsByFlag[flag] = obj
        win._configData[flag] = value
    end

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return obj
end

-- ============================================================
-- MultiDropdown
-- ============================================================
function LucidUI.Section:CreateMultiDropdown(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local options = config.Options or {}
    local flag    = config.Flag

    local ROW_H, OPT_H, OPT_P = 42, 32, 2
    local MAX_VISIBLE = 6
    local MAX_LIST_H  = MAX_VISIBLE * (OPT_H + OPT_P) - OPT_P + 8

    local selected, selectedCount = {}, 0

    if type(config.Default) == "table" then
        for _, name in ipairs(config.Default) do
            for _, opt in ipairs(options) do
                if opt == name and not selected[opt] then
                    selected[opt] = true
                    selectedCount = selectedCount + 1
                    break
                end
            end
        end
    end

    local row = Create("Frame", {
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, ROW_H),
        ClipsDescendants = true,
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, row)
    local rowStroke = Stroke(theme.Border, 1, theme.BorderTrans + 0.05, row)

    local headerBtn = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, ROW_H), ZIndex = 3, Parent = row,
    })

    local nameLabel = Create("TextLabel", {
        Text = config.Name or "Select",
        Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -110, 1, 0),
        ZIndex = 4, Parent = headerBtn,
    })

    local valueLabel = Create("TextLabel", {
        Text = "None", Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = theme.Accent, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Size = UDim2.new(1, -50, 1, 0), ZIndex = 4, Parent = headerBtn,
    })

    local arrowLbl = Create("TextLabel", {
        Text = "v", Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = theme.TextMuted, BackgroundTransparency = 1,
        Position = UDim2.new(1, -24, 0, 0), Size = UDim2.fromOffset(20, ROW_H),
        ZIndex = 4, Parent = headerBtn,
    })

    local listWrap = Create("Frame", {
        Size = UDim2.new(1, -20, 0, 0), Position = UDim2.fromOffset(10, ROW_H),
        BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 3, Parent = row,
    })

    local scroll = Create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = theme.TextMuted,
        ScrollBarImageTransparency = 0.5,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollingEnabled = (#options > MAX_VISIBLE),
        CanvasSize = UDim2.new(0, 0, 0, #options * (OPT_H + OPT_P) - OPT_P),
        AutomaticCanvasSize = Enum.AutomaticSize.None,
        ZIndex = 4, Parent = listWrap,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, OPT_P), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll,
    })

    local optionRefs = {}

    local function updateHeader()
        if selectedCount == 0 then
            valueLabel.Text = "None"
        elseif selectedCount == 1 then
            for opt, on in pairs(selected) do
                if on then valueLabel.Text = opt break end
            end
        else
            valueLabel.Text = selectedCount .. " selected"
        end
    end

    local function buildSelectedArray()
        local out = {}
        for _, opt in ipairs(options) do
            if selected[opt] then table.insert(out, opt) end
        end
        return out
    end

    local function fireCallback(silent)
        local arr = buildSelectedArray()
        if flag then win._configData[flag] = arr end
        if not silent and config.Callback then Compat.safeCallback(config.Callback, arr) end
    end

    local function setOption(opt, on, silent)
        if selected[opt] == on then return end
        selected[opt] = on or nil
        selectedCount = (selectedCount or 0) + (on and 1 or -1)
        if selectedCount < 0 then selectedCount = 0 end

        local ref = optionRefs[opt]
        if ref then
            local t = win.Theme
            Tween(ref.checkBg, 0.18, {
                BackgroundColor3 = on and t.Accent or t.Background,
                BackgroundTransparency = on and 0 or 0.3,
            }, Enum.EasingStyle.Quart):Play()
            Tween(ref.checkBorder, 0.18, { Transparency = on and 1 or 0.4 }):Play()
            for _, part in ipairs(ref.checkParts) do
                Tween(part, 0.18, { BackgroundTransparency = on and 0 or 1 }):Play()
            end
        end

        updateHeader()
        fireCallback(silent)
    end

    for i, opt in ipairs(options) do
        local optRow = Create("TextButton", {
            Text = "",
            BackgroundColor3 = theme.Background, BackgroundTransparency = 0.5,
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, OPT_H), LayoutOrder = i, ZIndex = 4, Parent = scroll,
        })
        Corner(8, optRow)

        local checkBox = Create("Frame", {
            Size = UDim2.fromOffset(18, 18),
            Position = UDim2.fromOffset(10, (OPT_H - 18) / 2),
            BackgroundColor3 = selected[opt] and theme.Accent or theme.Background,
            BackgroundTransparency = selected[opt] and 0 or 0.3,
            BorderSizePixel = 0, ZIndex = 5, Parent = optRow,
        })
        Corner(5, checkBox)
        local checkBorder = Stroke(theme.Border, 1, selected[opt] and 1 or 0.4, checkBox)

        local shortArm = Create("Frame", {
            Size = UDim2.fromOffset(5, 2),
            Position = UDim2.new(0.42, 0, 0.58, 0),
            AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = selected[opt] and 0 or 1,
            BorderSizePixel = 0, ZIndex = 6, Parent = checkBox,
        })
        Corner(1, shortArm)

        local longArm = Create("Frame", {
            Size = UDim2.fromOffset(9, 2),
            Position = UDim2.new(0.58, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5), Rotation = -45,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = selected[opt] and 0 or 1,
            BorderSizePixel = 0, ZIndex = 6, Parent = checkBox,
        })
        Corner(1, longArm)

        local optLabel = Create("TextLabel", {
            Text = tostring(opt),
            Font = Enum.Font.GothamMedium, TextSize = 13,
            TextColor3 = theme.TextPrimary, BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -48, 1, 0),
            ZIndex = 5, Parent = optRow,
        })

        optionRefs[opt] = {
            row = optRow, label = optLabel,
            checkBg = checkBox, checkBorder = checkBorder,
            checkParts = { shortArm, longArm },
        }

        optRow.MouseEnter:Connect(function()
            local t = win.Theme
            Tween(optRow, 0.12, { BackgroundColor3 = t.Accent, BackgroundTransparency = 0.35 }):Play()
        end)
        optRow.MouseLeave:Connect(function()
            local t = win.Theme
            Tween(optRow, 0.12, { BackgroundColor3 = t.Background, BackgroundTransparency = 0.5 }):Play()
        end)

        BindTap(optRow, function()
            PlayUISound("click")
            setOption(opt, not selected[opt], false)
        end)
    end

    updateHeader()
    fireCallback(true)

    local outerScroll = nil
    do
        local p = row.Parent
        while p do
            if p:IsA("ScrollingFrame") then outerScroll = p break end
            p = p.Parent
        end
    end

    if outerScroll then
        local innerScrolling = false
        table.insert(win._conns, scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
            if not innerScrolling then
                innerScrolling = true
                outerScroll.ScrollingEnabled = false
                task.delay(0.15, function()
                    innerScrolling = false
                    if outerScroll and outerScroll.Parent then
                        outerScroll.ScrollingEnabled = true
                    end
                end)
            end
        end))
    end

    local expanded = false
    BindTap(headerBtn, function()
        expanded = not expanded
        local fullH = #options * (OPT_H + OPT_P) - OPT_P
        local openH = math.min(fullH + 8, MAX_LIST_H)
        Tween(listWrap, 0.24, {
            Size = UDim2.new(1, -20, 0, expanded and openH or 0),
        }, Enum.EasingStyle.Quart):Play()
        Tween(row, 0.24, {
            Size = UDim2.new(1, 0, 0, expanded and (ROW_H + openH + 8) or ROW_H),
        }, Enum.EasingStyle.Quart):Play()
        Tween(arrowLbl, 0.20, { Rotation = expanded and 180 or 0 }):Play()
        PlayUISound("click")
    end)

    win:_registerTheme(function(t)
        row.BackgroundColor3  = t.Surface
        rowStroke.Color       = t.Border
        nameLabel.TextColor3  = t.TextPrimary
        valueLabel.TextColor3 = t.Accent
        arrowLbl.TextColor3   = t.TextMuted
        scroll.ScrollBarImageColor3 = t.TextMuted
        for opt, ref in pairs(optionRefs) do
            ref.row.BackgroundColor3 = t.Background
            ref.label.TextColor3     = t.TextPrimary
            ref.checkBorder.Color    = t.Border
            ref.checkBg.BackgroundColor3 = selected[opt] and t.Accent or t.Background
        end
    end)

    local obj = {
        Instance = row, Flag = flag,
        Set = function(_, v)
            if type(v) ~= "table" then return end
            for _, opt in ipairs(options) do
                selected[opt] = nil
                local ref = optionRefs[opt]
                if ref then
                    ref.checkBg.BackgroundColor3 = win.Theme.Background
                    ref.checkBg.BackgroundTransparency = 0.3
                    ref.checkBorder.Transparency = 0.4
                    for _, part in ipairs(ref.checkParts) do
                        part.BackgroundTransparency = 1
                    end
                end
            end
            selectedCount = 0
            for _, name in ipairs(v) do
                if optionRefs[name] then
                    selected[name] = true
                    selectedCount = selectedCount + 1
                    local ref = optionRefs[name]
                    ref.checkBg.BackgroundColor3 = win.Theme.Accent
                    ref.checkBg.BackgroundTransparency = 0
                    ref.checkBorder.Transparency = 1
                    for _, part in ipairs(ref.checkParts) do
                        part.BackgroundTransparency = 0
                    end
                end
            end
            updateHeader()
            if flag then win._configData[flag] = buildSelectedArray() end
        end,
        Get = function() return buildSelectedArray() end,
    }

    if flag then
        win._elementsByFlag[flag] = obj
        win._configData[flag] = buildSelectedArray()
    end

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return obj
end

-- ============================================================
-- ColorPicker
-- ============================================================
function LucidUI.Section:CreateColorPicker(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local value = config.Default or Color3.fromRGB(90, 180, 255)
    local flag  = config.Flag

    local row = Create("Frame", {
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 52),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, row)
    local rowStroke = Stroke(theme.Border, 1, theme.BorderTrans + 0.05, row)

    local nameLabel = Create("TextLabel", {
        Text = config.Name or "Color",
        Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -110, 1, 0),
        ZIndex = 3, Parent = row,
    })

    local hexLabel = Create("TextLabel", {
        Text = string.format("#%02X%02X%02X",
            math.floor(value.R * 255), math.floor(value.G * 255), math.floor(value.B * 255)),
        Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = theme.TextMuted, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -110, 0, 14),
        ZIndex = 3, Parent = row,
    })

    local swatch = Create("Frame", {
        Size = UDim2.fromOffset(32, 32),
        Position = UDim2.new(1, -46, 0.5, -16),
        BackgroundColor3 = value,
        BorderSizePixel = 0, ZIndex = 3, Parent = row,
    })
    Corner(8, swatch)
    local swatchStroke = Stroke(theme.Border, 1, 0.5, swatch)

    local clickArea = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = row,
    })

    local function setColorInternal(c, silent)
        value = c
        swatch.BackgroundColor3 = c
        hexLabel.Text = string.format("#%02X%02X%02X",
            math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
        if flag then win._configData[flag] = { R = c.R, G = c.G, B = c.B } end
        if not silent and config.Callback then Compat.safeCallback(config.Callback, c) end
    end

    BindTap(clickArea, function()
        PlayUISound("click")
        win:_openColorPickerModal({
            Label = config.Name or "Color",
            InitialColor = value,
            OnChange = function(c) setColorInternal(c, false) end,
        })
    end)

    clickArea.MouseEnter:Connect(function()
        local t = win.Theme
        Tween(row, 0.12, { BackgroundTransparency = math.max(t.SurfaceTrans - 0.1, 0) }):Play()
    end)
    clickArea.MouseLeave:Connect(function()
        local t = win.Theme
        Tween(row, 0.12, { BackgroundTransparency = t.SurfaceTrans }):Play()
    end)

    win:_registerTheme(function(t)
        row.BackgroundColor3 = t.Surface
        nameLabel.TextColor3 = t.TextPrimary
        hexLabel.TextColor3  = t.TextMuted
        rowStroke.Color      = t.Border
        swatchStroke.Color   = t.Border
    end)

    local obj = {
        Instance = row, Flag = flag,
        Set = function(_, v)
            if typeof(v) == "Color3" then
                setColorInternal(v, true)
            elseif type(v) == "table" and v.R and v.G and v.B then
                setColorInternal(Color3.new(v.R, v.G, v.B), true)
            end
        end,
        Get = function() return value end,
    }
    if flag then
        win._elementsByFlag[flag] = obj
        win._configData[flag] = { R = value.R, G = value.G, B = value.B }
    end

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return obj
end

-- ============================================================
-- Keybind
-- ============================================================
function LucidUI.Section:CreateKeybind(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local currentKey = config.CurrentKeybind or Enum.KeyCode.F
    local flag       = config.Flag
    local listenConn = nil

    local row = Create("Frame", {
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 42),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, row)

    local nameLabel = Create("TextLabel", {
        Text = config.Name or "Keybind",
        Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -110, 1, 0),
        ZIndex = 3, Parent = row,
    })

    local keyBox = Create("TextButton", {
        Text = currentKey.Name,
        Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = theme.TextPrimary,
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 0.3, AutoButtonColor = false,
        Size = UDim2.fromOffset(90, 28),
        Position = UDim2.new(1, -104, 0.5, -14),
        ZIndex = 3, Parent = row,
    })
    Corner(8, keyBox)

    local function stopListening()
        if listenConn then listenConn:Disconnect() listenConn = nil end
        keyBox.Text = currentKey.Name
        keyBox.BackgroundColor3 = win.Theme.Background
        LucidUI._keyListening = false
    end

    local function startListening()
        if LucidUI._keyListening then return end
        LucidUI._keyListening = true
        keyBox.Text = "..."
        keyBox.BackgroundColor3 = win.Theme.Accent
        PlayUISound("click")

        listenConn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            currentKey = input.KeyCode
            if flag then win._configData[flag] = currentKey.Name end
            if config.Callback then Compat.safeCallback(config.Callback, currentKey) end
            stopListening()
        end)
    end

    BindTap(keyBox, startListening)

    table.insert(win._conns, UserInputService.InputBegan:Connect(function(input, processed)
        if not LucidUI._keyListening then return end
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            if not processed then stopListening() end
        end
    end))

    win:_registerTheme(function(t)
        row.BackgroundColor3 = t.Surface
        nameLabel.TextColor3 = t.TextPrimary
        if not LucidUI._keyListening then
            keyBox.BackgroundColor3 = t.Background
            keyBox.TextColor3 = t.TextPrimary
        end
    end)

    local obj = {
        Instance = row, Flag = flag,
        Set = function(_, v)
            local key = typeof(v) == "EnumItem" and v or Enum.KeyCode[v]
            if key then
                currentKey = key
                keyBox.Text = key.Name
                if flag then win._configData[flag] = key.Name end
            end
        end,
        Get = function() return currentKey end,
    }
    if flag then
        win._elementsByFlag[flag] = obj
        win._configData[flag] = currentKey.Name
    end

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return obj
end

-- ============================================================
-- Input
-- ============================================================
function LucidUI.Section:CreateInput(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local value = config.CurrentValue or ""
    local flag  = config.Flag

    local row = Create("Frame", {
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 42),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, row)

    local nameLabel = Create("TextLabel", {
        Text = config.Name or "Input",
        Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -180, 1, 0),
        ZIndex = 3, Parent = row,
    })

    local box = Create("TextBox", {
        Text = value,
        PlaceholderText = config.Placeholder or "...",
        PlaceholderColor3 = theme.TextMuted,
        Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = theme.TextPrimary,
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 0.3, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.fromOffset(140, 28),
        Position = UDim2.new(1, -154, 0.5, -14),
        ZIndex = 3, Parent = row,
    })
    Corner(8, box)
    Create("UIPadding", {
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = box,
    })

    box.FocusLost:Connect(function()
        value = box.Text
        if flag then win._configData[flag] = value end
        if config.Callback then Compat.safeCallback(config.Callback, value) end
    end)

    win:_registerTheme(function(t)
        row.BackgroundColor3  = t.Surface
        nameLabel.TextColor3  = t.TextPrimary
        box.BackgroundColor3  = t.Background
        box.TextColor3        = t.TextPrimary
        box.PlaceholderColor3 = t.TextMuted
    end)

    local obj = {
        Instance = row, Flag = flag,
        Set = function(_, v)
            value = tostring(v)
            box.Text = value
            if flag then win._configData[flag] = value end
        end,
        Get = function() return value end,
    }
    if flag then
        win._elementsByFlag[flag] = obj
        win._configData[flag] = value
    end

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return obj
end

-- ============================================================
-- Search
-- ============================================================
function LucidUI.Section:CreateSearch(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local value    = ""
    local flag     = config.Flag
    local debounce = config.Debounce or 0.12
    local target   = config.Target

    local row = Create("Frame", {
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 42),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, row)
    local rowStroke = Stroke(theme.Border, 1, theme.BorderTrans + 0.05, row)

    local iconHolder = Create("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromOffset(12, 13),
        BackgroundTransparency = 1, ZIndex = 3, Parent = row,
    })
    if LucidUI.IconBuilders and LucidUI.IconBuilders.search then
        pcall(LucidUI.IconBuilders.search, iconHolder, 16, theme.TextMuted)
    end

    local box = Create("TextBox", {
        Text = "",
        PlaceholderText = config.Placeholder or "Search...",
        PlaceholderColor3 = theme.TextMuted,
        Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = theme.TextPrimary,
        BackgroundTransparency = 1, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(36, 0),
        Size = UDim2.new(1, -72, 1, 0),
        ZIndex = 3, Parent = row,
    })

    local clearBtn = Create("TextButton", {
        Text = "x", Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = theme.TextMuted, BackgroundTransparency = 1,
        AutoButtonColor = false,
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -34, 0.5, -14),
        TextTransparency = 1, ZIndex = 4, Parent = row,
    })

    local debounceToken = 0
    local function fire(query)
        debounceToken = debounceToken + 1
        local myToken = debounceToken
        task.delay(debounce, function()
            if myToken ~= debounceToken then return end

            if target and target.Parent then
                local q = query:lower()
                for _, child in ipairs(target:GetChildren()) do
                    if child:IsA("GuiObject") and not child:IsA("UIListLayout") then
                        local matchText = ""
                        for _, sub in ipairs(child:GetDescendants()) do
                            if sub:IsA("TextLabel") or sub:IsA("TextButton") then
                                matchText = sub.Text
                                break
                            end
                        end
                        local match = (q == "") or (matchText:lower():find(q, 1, true) ~= nil)
                        child.Visible = match
                    end
                end
            end

            if config.Callback then Compat.safeCallback(config.Callback, query) end
        end)
    end

    box:GetPropertyChangedSignal("Text"):Connect(function()
        value = box.Text
        local hasText = value ~= ""
        Tween(clearBtn, 0.15, { TextTransparency = hasText and 0 or 1 }):Play()
        fire(value)
        if flag then win._configData[flag] = value end
    end)

    box.FocusLost:Connect(function()
        if config.OnSubmit then Compat.safeCallback(config.OnSubmit, value) end
    end)

    BindTap(clearBtn, function()
        box.Text = ""
        value = ""
        if box:IsFocused() then box:ReleaseFocus() end
        if flag then win._configData[flag] = "" end
        fire("")
        PlayUISound("click")
    end)

    clearBtn.MouseEnter:Connect(function()
        Tween(clearBtn, 0.12, { TextColor3 = win.Theme.TextPrimary }):Play()
    end)
    clearBtn.MouseLeave:Connect(function()
        Tween(clearBtn, 0.12, { TextColor3 = win.Theme.TextMuted }):Play()
    end)

    win:_registerTheme(function(t)
        row.BackgroundColor3 = t.Surface
        rowStroke.Color      = t.Border
        box.TextColor3       = t.TextPrimary
        box.PlaceholderColor3 = t.TextMuted
        clearBtn.TextColor3  = t.TextMuted
    end)

    local obj = {
        Instance = row, Flag = flag,
        Set = function(_, v)
            box.Text = tostring(v or "")
            value = box.Text
            if flag then win._configData[flag] = value end
        end,
        Get = function() return value end,
        Clear = function() box.Text = "" value = "" end,
    }
    if flag then
        win._elementsByFlag[flag] = obj
        win._configData[flag] = ""
    end

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return obj
end

-- ============================================================
-- ProgressBar
-- ============================================================
function LucidUI.Section:CreateProgressBar(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local value = math.clamp(config.CurrentValue or 0, 0, 1)
    local flag  = config.Flag
    local showPct = config.ShowPercent ~= false

    local row = Create("Frame", {
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 50),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, row)
    local rowStroke = Stroke(theme.Border, 1, theme.BorderTrans + 0.05, row)

    local nameLabel = Create("TextLabel", {
        Text = config.Name or "Progress",
        Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 6),
        Size = UDim2.new(1, -60, 0, 18),
        ZIndex = 3, Parent = row,
    })

    local pctLabel = Create("TextLabel", {
        Text = showPct and (math.floor(value * 100) .. "%") or "",
        Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = theme.Accent, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.fromOffset(14, 6),
        Size = UDim2.new(1, -28, 0, 18),
        ZIndex = 3, Parent = row,
    })

    local track = Create("Frame", {
        Size = UDim2.new(1, -28, 0, 6),
        Position = UDim2.new(0, 14, 1, -18),
        BackgroundColor3 = theme.SliderTrack,
        BorderSizePixel = 0, ZIndex = 3, Parent = row,
    })
    Corner(3, track)

    local fill = Create("Frame", {
        Size = UDim2.new(value, 0, 1, 0),
        BackgroundColor3 = config.Color or theme.Accent,
        BorderSizePixel = 0, ZIndex = 4, Parent = track,
    })
    Corner(3, fill)

    win:_registerTheme(function(t)
        row.BackgroundColor3 = t.Surface
        nameLabel.TextColor3 = t.TextPrimary
        pctLabel.TextColor3  = config.Color or t.Accent
        track.BackgroundColor3 = t.SliderTrack
        fill.BackgroundColor3 = config.Color or t.Accent
        rowStroke.Color = t.Border
    end)

    local obj = {
        Instance = row, Flag = flag,
        Set = function(_, v)
            value = math.clamp(v or 0, 0, 1)
            pcall(function()
                Tween(fill, 0.25, { Size = UDim2.new(value, 0, 1, 0) }):Play()
            end)
            pctLabel.Text = showPct and (math.floor(value * 100) .. "%") or ""
            if flag then win._configData[flag] = value end
        end,
        Get = function() return value end,
        SetLabel = function(_, text) nameLabel.Text = tostring(text) end,
    }
    if flag then
        win._elementsByFlag[flag] = obj
        win._configData[flag] = value
    end

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return obj
end

-- ============================================================
-- LoadingSpinner
-- ============================================================
function LucidUI.Section:CreateLoadingSpinner(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local row = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 32),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })

    local spinnerSize = config.Size or 20
    local spinner = Create("Frame", {
        Size = UDim2.fromOffset(spinnerSize, spinnerSize),
        Position = UDim2.fromOffset(4, (32 - spinnerSize) / 2),
        BackgroundTransparency = 1,
        ZIndex = 3, Parent = row,
    })

    local ring = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 3, Parent = spinner,
    })
    Corner(999, ring)
    local ringStroke = Stroke(config.Color or theme.Accent, 2, 0.2, ring)

    local label = Create("TextLabel", {
        Text = config.Text or "Loading...",
        Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = theme.TextSecondary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(spinnerSize + 12, 0),
        Size = UDim2.new(1, -(spinnerSize + 16), 1, 0),
        ZIndex = 3, Parent = row,
    })

    local spinning = true
    task.spawn(function()
        while spinning and spinner.Parent do
            spinner.Rotation = (spinner.Rotation + 4) % 360
            task.wait(0.016)
        end
    end)

    win:_registerTheme(function(t)
        label.TextColor3 = t.TextSecondary
        if not config.Color then ringStroke.Color = t.Accent end
    end)

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return {
        Instance = row,
        Stop = function()
            spinning = false
            pcall(function() row:Destroy() end)
        end,
        SetText = function(_, text) label.Text = tostring(text) end,
    }
end

-- ============================================================
-- ConfirmDialog
-- ============================================================
function LucidUI.Section:CreateConfirmDialog(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local row = Create("Frame", {
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 42),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, row)

    local label = Create("TextLabel", {
        Text = config.Name or "Confirm",
        Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -100, 1, 0),
        ZIndex = 3, Parent = row,
    })

    local trigger = Create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 5, Parent = row,
    })

    local function openConfirm()
        local modal = Create("Frame", {
            Name = "ConfirmModal",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 500,
            Parent = win.Gui,
        })
        local backdrop = Create("TextButton", {
            Text = "", AutoButtonColor = false,
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, ZIndex = 1,
            Parent = modal,
        })
        local card = Create("CanvasGroup", {
            Size = UDim2.fromOffset(340, 180),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = win.Theme.Background,
            BackgroundTransparency = 0.05,
            BorderSizePixel = 0,
            GroupTransparency = 1,
            ZIndex = 2, Parent = modal,
        })
        Corner(16, card)
        Stroke(win.Theme.Border, 1, 0.5, card)

        local popScale = Instance.new("UIScale")
        popScale.Scale = 0.82
        popScale.Parent = card

        Create("TextLabel", {
            Text = config.Title or "Are you sure?",
            Font = Enum.Font.GothamBold, TextSize = 18,
            TextColor3 = win.Theme.TextPrimary, BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Center,
            Position = UDim2.fromOffset(0, 30),
            Size = UDim2.new(1, 0, 0, 24),
            ZIndex = 3, Parent = card,
        })
        Create("TextLabel", {
            Text = config.Message or "This action cannot be undone.",
            Font = Enum.Font.Gotham, TextSize = 13,
            TextColor3 = win.Theme.TextSecondary, BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextWrapped = true,
            Position = UDim2.fromOffset(24, 60),
            Size = UDim2.new(1, -48, 0, 60),
            ZIndex = 3, Parent = card,
        })

        local function close()
            pcall(function()
                Tween(card, 0.18, { GroupTransparency = 1 }):Play()
                Tween(modal, 0.18, { BackgroundTransparency = 1 }):Play()
                Tween(popScale, 0.18, { Scale = 0.86 }):Play()
            end)
            task.delay(0.2, function()
                pcall(function() modal:Destroy() end)
            end)
        end

        local yes = Create("TextButton", {
            Text = config.ConfirmText or "Confirm",
            Font = Enum.Font.GothamBold, TextSize = 13,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundColor3 = config.ConfirmColor or Color3.fromRGB(220, 60, 60),
            BackgroundTransparency = 0.15, AutoButtonColor = false,
            Size = UDim2.fromOffset(140, 34),
            Position = UDim2.new(0.5, 78, 1, -50),
            AnchorPoint = Vector2.new(0.5, 0),
            ZIndex = 3, Parent = card,
        })
        Corner(8, yes)

        local no = Create("TextButton", {
            Text = config.CancelText or "Cancel",
            Font = Enum.Font.GothamBold, TextSize = 13,
            TextColor3 = win.Theme.TextPrimary,
            BackgroundColor3 = win.Theme.Surface,
            BackgroundTransparency = 0.3, AutoButtonColor = false,
            Size = UDim2.fromOffset(140, 34),
            Position = UDim2.new(0.5, -78, 1, -50),
            AnchorPoint = Vector2.new(0.5, 0),
            ZIndex = 3, Parent = card,
        })
        Corner(8, no)

        BindTap(yes, function()
            close()
            if config.OnConfirm then Compat.safeCallback(config.OnConfirm) end
        end)
        BindTap(no, function()
            close()
            if config.OnCancel then Compat.safeCallback(config.OnCancel) end
        end)
        BindTap(backdrop, function()
            close()
            if config.OnCancel then Compat.safeCallback(config.OnCancel) end
        end)

        Tween(modal, 0.22, { BackgroundTransparency = 0.55 }):Play()
        Tween(popScale, 0.32, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
        Tween(card, 0.22, { GroupTransparency = 0 }):Play()
    end

    BindTap(trigger, function()
        PlayUISound("click")
        openConfirm()
    end)

    win:_registerTheme(function(t)
        row.BackgroundColor3 = t.Surface
        label.TextColor3 = t.TextPrimary
    end)

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return {
        Instance = row,
        Show = openConfirm,
    }
end

-- ============================================================
-- Table
-- ============================================================
function LucidUI.Section:CreateTable(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local columns    = config.Columns or {}
    local rows       = config.Rows or {}
    local sortable   = config.Sortable ~= false
    local maxHeight  = config.MaxHeight or 220
    local rowHeight  = config.RowHeight or 28
    local headerH    = 30

    local sumW, hasWidths = 0, false
    for _, c in ipairs(columns) do
        if c.Width then hasWidths = true sumW = sumW + c.Width end
    end
    local colFracs = {}
    for i, c in ipairs(columns) do
        if hasWidths and c.Width then
            colFracs[i] = c.Width / sumW
        else
            colFracs[i] = 1 / math.max(#columns, 1)
        end
    end

    local sortState = { column = nil, ascending = true }

    local wrapper = Create("Frame", {
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, wrapper)
    local wrapperStroke = Stroke(theme.Border, 1, theme.BorderTrans + 0.05, wrapper)

    local pad = Create("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Parent = wrapper,
    })

    local header = Create("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, headerH),
        ZIndex = 3, Parent = pad,
    })
    local headerLine = Create("Frame", {
        Size = UDim2.new(1, -20, 0, 1),
        Position = UDim2.new(0, 10, 1, -1),
        BackgroundColor3 = theme.Border,
        BackgroundTransparency = math.min((theme.BorderTrans or 0.85) + 0.08, 1),
        BorderSizePixel = 0, ZIndex = 3, Parent = header,
    })

    local body = Create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = theme.TextMuted,
        ScrollBarImageTransparency = 0.5,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 3, Parent = pad,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body,
    })

    local headerBtns = {}

    local function compareRows(a, b, colIdx, ascending)
        local av, bv = a[colIdx], b[colIdx]
        local an, bn = tonumber(av), tonumber(bv)
        if an and bn then
            if ascending then return an < bn end
            return an > bn
        end
        local as = tostring(av or ""):lower()
        local bs = tostring(bv or ""):lower()
        if ascending then return as < bs end
        return as > bs
    end

    local function clearBody()
        for _, child in ipairs(body:GetChildren()) do
            if child:IsA("GuiObject") then pcall(function() child:Destroy() end) end
        end
    end

    local function renderRows()
        clearBody()
        local displayRows = {}
        for _, r in ipairs(rows) do table.insert(displayRows, r) end
        if sortState.column then
            table.sort(displayRows, function(a, b)
                return compareRows(a, b, sortState.column, sortState.ascending)
            end)
        end

        for i, rowData in ipairs(displayRows) do
            local rowFrame = Create("TextButton", {
                Text = "", BackgroundTransparency = 1, AutoButtonColor = false,
                Size = UDim2.new(1, 0, 0, rowHeight),
                LayoutOrder = i, ZIndex = 4, Parent = body,
            })
            if i % 2 == 0 then
                rowFrame.BackgroundColor3 = theme.Background
                rowFrame.BackgroundTransparency = 0.65
            end

            local cursorX = 10
            for c = 1, #columns do
                local frac = colFracs[c]
                Create("TextLabel", {
                    Text = rowData[c] ~= nil and tostring(rowData[c]) or "",
                    Font = Enum.Font.Gotham, TextSize = 12,
                    TextColor3 = theme.TextPrimary, BackgroundTransparency = 1,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Position = UDim2.new(cursorX / 620, 0, 0, 0),
                    Size = UDim2.new(frac * (1 - 40/620), 0, 1, 0),
                    ZIndex = 5, Parent = rowFrame,
                })
                cursorX = cursorX + 620 * frac
            end

            rowFrame.MouseEnter:Connect(function()
                rowFrame.BackgroundColor3 = win.Theme.Accent
                rowFrame.BackgroundTransparency = 0.85
            end)
            rowFrame.MouseLeave:Connect(function()
                rowFrame.BackgroundColor3 = theme.Background
                rowFrame.BackgroundTransparency = (i % 2 == 0) and 0.65 or 1
            end)

            if config.OnRowClick then
                BindTap(rowFrame, function()
                    PlayUISound("click")
                    Compat.safeCallback(config.OnRowClick, i, rowData)
                end)
            end
        end

        local contentH = #displayRows * rowHeight
        body.Size = UDim2.new(1, 0, 0, math.min(contentH, maxHeight))
        body.CanvasSize = UDim2.new(0, 0, 0, contentH)
        body.ScrollingEnabled = contentH > maxHeight
    end

    local function buildHeader()
        for _, b in ipairs(headerBtns) do pcall(function() b:Destroy() end) end
        headerBtns = {}

        local cursorX = 10
        for i, col in ipairs(columns) do
            local frac = colFracs[i]
            local btn = Create("TextButton", {
                Text = "", BackgroundTransparency = 1, AutoButtonColor = false,
                Position = UDim2.new(cursorX / 620, 0, 0, 0),
                Size = UDim2.new(frac * (1 - 40/620), 0, 1, 0),
                ZIndex = 4, Parent = header,
            })

            local lbl = Create("TextLabel", {
                Text = tostring(col.Name or ("Col " .. i)),
                Font = Enum.Font.GothamBold, TextSize = 11,
                TextColor3 = theme.TextMuted, BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = btn,
            })

            local arrow = Create("TextLabel", {
                Text = "", Font = Enum.Font.GothamBold, TextSize = 10,
                TextColor3 = theme.Accent, BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Right,
                Size = UDim2.new(1, -4, 1, 0), ZIndex = 6, Parent = btn,
            })

            if sortable then
                btn.MouseEnter:Connect(function()
                    Tween(lbl, 0.12, { TextColor3 = win.Theme.TextPrimary }):Play()
                end)
                btn.MouseLeave:Connect(function()
                    Tween(lbl, 0.12, { TextColor3 = win.Theme.TextMuted }):Play()
                end)

                BindTap(btn, function()
                    if sortState.column == i then
                        sortState.ascending = not sortState.ascending
                    else
                        sortState.column = i
                        sortState.ascending = true
                    end

                    for j, b in ipairs(headerBtns) do
                        for _, child in ipairs(b:GetChildren()) do
                            if child:IsA("TextLabel") and child.ZIndex == 6 then
                                if j == sortState.column then
                                    child.Text = sortState.ascending and "▲" or "▼"
                                else
                                    child.Text = ""
                                end
                            end
                        end
                    end

                    PlayUISound("click")
                    renderRows()
                end)
            end

            table.insert(headerBtns, btn)
            cursorX = cursorX + 620 * frac
        end
    end

    buildHeader()
    renderRows()

    win:_registerTheme(function(t)
        wrapper.BackgroundColor3 = t.Surface
        wrapperStroke.Color      = t.Border
        headerLine.BackgroundColor3 = t.Border
        body.ScrollBarImageColor3 = t.TextMuted
        for _, b in ipairs(headerBtns) do
            for _, child in ipairs(b:GetChildren()) do
                if child:IsA("TextLabel") then
                    if child.ZIndex == 5 then child.TextColor3 = t.TextMuted
                    elseif child.ZIndex == 6 then child.TextColor3 = t.Accent end
                end
            end
        end
        renderRows()
    end)

    local obj = {
        Instance = wrapper, Flag = config.Flag,
        Set = function(_, newRows) rows = newRows or {} renderRows() end,
        Get = function() return rows end,
        SortBy = function(_, colIdx, ascending)
            sortState.column = colIdx
            sortState.ascending = ascending ~= false
            renderRows()
        end,
        Refresh = function() renderRows() end,
    }

    self:_track(wrapper)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(wrapper, config.Tooltip)
    end

    return obj
end

-- ============================================================
-- Display elements
-- ============================================================
function LucidUI.Section:CreateTextDisplay(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local row = Create("Frame", {
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, row)

    Create("UIPadding", {
        PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = row,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row,
    })

    local titleLabel = Create("TextLabel", {
        Text = config.Title or "Info",
        Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = theme.TextMuted, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1, ZIndex = 3, Parent = row,
    })

    local contentLabel = Create("TextLabel", {
        Text = config.Content or "",
        Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2, ZIndex = 3, Parent = row,
    })

    win:_registerTheme(function(t)
        row.BackgroundColor3    = t.Surface
        titleLabel.TextColor3   = t.TextMuted
        contentLabel.TextColor3 = t.TextPrimary
    end)

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return {
        Instance = row,
        Set      = function(_, v) contentLabel.Text = tostring(v) end,
        Get      = function() return contentLabel.Text end,
        SetTitle = function(_, v) titleLabel.Text = tostring(v) end,
    }
end

function LucidUI.Section:CreateLabel(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local TEXT_H   = config.TextSize or 13
    local ROW_H    = math.max(config.Height or 26, TEXT_H + 10)
    local hasIcon  = config.Icon ~= nil
    local ICON_SZ  = config.IconSize or 16
    local ICON_PAD = 6
    local LEFT_PAD = 4

    local textOffsetX = LEFT_PAD + (hasIcon and (ICON_SZ + ICON_PAD) or 0)
    local textWidth   = -(textOffsetX + 4)

    local row = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, ROW_H),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })

    local iconParts = {}
    if hasIcon then
        local iconHolder = Create("Frame", {
            Size = UDim2.fromOffset(ICON_SZ, ICON_SZ),
            Position = UDim2.fromOffset(LEFT_PAD, (ROW_H - ICON_SZ) / 2),
            BackgroundTransparency = 1, ZIndex = 3, Parent = row,
        })
        if LucidUI.BuildIcon then
            local ok, _, parts = pcall(LucidUI.BuildIcon, config.Icon, iconHolder, ICON_SZ, config.IconColor or theme.TextPrimary)
            if ok then iconParts = parts or {} end
        end
    end

    local label = Create("TextLabel", {
        Text = config.Text or "",
        Font = config.Bold and Enum.Font.GothamBold or Enum.Font.GothamMedium,
        TextSize = TEXT_H,
        TextColor3 = config.TextColor or theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = config.Align or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = config.Wrapped == true,
        Position = UDim2.fromOffset(textOffsetX, 0),
        Size = UDim2.new(1, textWidth, 1, 0),
        ZIndex = 3, Parent = row,
    })

    win:_registerTheme(function(t)
        if not config.TextColor then label.TextColor3 = t.TextPrimary end
    end)

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return {
        Instance = row,
        Set = function(_, v) label.Text = tostring(v) end,
        Get = function() return label.Text end,
        SetColor = function(_, c)
            label.TextColor3 = c
            config.TextColor = c
        end,
    }
end

function LucidUI.Section:CreateParagraph(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local TEXT_H = config.TextSize or 13
    local PAD_X  = config.PaddingX or 4
    local PAD_Y  = config.PaddingY or 6

    local row = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })

    local label = Create("TextLabel", {
        Text = config.Text or "",
        Font = config.Bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize = TEXT_H,
        TextColor3 = config.TextColor or theme.TextSecondary,
        BackgroundTransparency = 1,
        TextXAlignment = config.Align or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        RichText = config.RichText == true,
        Position = UDim2.fromOffset(PAD_X, PAD_Y),
        Size = UDim2.new(1, -PAD_X * 2, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 3, Parent = row,
    })

    Create("Frame", {
        Size = UDim2.new(1, 0, 0, PAD_Y),
        Position = UDim2.new(0, 0, 1, 0),
        BackgroundTransparency = 1, ZIndex = 2, Parent = row,
    })

    win:_registerTheme(function(t)
        if not config.TextColor then
            label.TextColor3 = config.Muted and t.TextMuted or t.TextSecondary
        end
    end)

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return {
        Instance = row,
        Set = function(_, v) label.Text = tostring(v) end,
        Get = function() return label.Text end,
    }
end

function LucidUI.Section:CreateDivider(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local H = (config.Label and config.Label ~= "") and 20 or 10

    local row = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, H),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })

    if config.Label and config.Label ~= "" then
        local leftLine = Create("Frame", {
            Size = UDim2.new(0.5, -44, 0, 1),
            Position = UDim2.new(0, 4, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = theme.Border,
            BackgroundTransparency = math.min((theme.BorderTrans or 0.85) + 0.08, 1),
            BorderSizePixel = 0, ZIndex = 3, Parent = row,
        })
        local rightLine = Create("Frame", {
            Size = UDim2.new(0.5, -44, 0, 1),
            Position = UDim2.new(1, -4, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = theme.Border,
            BackgroundTransparency = math.min((theme.BorderTrans or 0.85) + 0.08, 1),
            BorderSizePixel = 0, ZIndex = 3, Parent = row,
        })
        local label = Create("TextLabel", {
            Text = tostring(config.Label):upper(),
            Font = Enum.Font.GothamBold, TextSize = 10,
            TextColor3 = theme.TextMuted, BackgroundTransparency = 1,
            Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(80, 14), ZIndex = 3, Parent = row,
        })
        win:_registerTheme(function(t)
            leftLine.BackgroundColor3  = t.Border
            rightLine.BackgroundColor3 = t.Border
            label.TextColor3           = t.TextMuted
        end)
    else
        local line = Create("Frame", {
            Size = UDim2.new(1, -8, 0, 1),
            Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = theme.Border,
            BackgroundTransparency = math.min((theme.BorderTrans or 0.85) + 0.08, 1),
            BorderSizePixel = 0, ZIndex = 3, Parent = row,
        })
        Create("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.12, 0),
                NumberSequenceKeypoint.new(0.88, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Rotation = 0, Parent = line,
        })
        win:_registerTheme(function(t) line.BackgroundColor3 = t.Border end)
    end

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return { Instance = row }
end

function LucidUI.Section:CreateSpacer(config)
    config = config or {}
    local size = config.Height or 8

    local row = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, size),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 1,
    })

    self:_track(row)
    -- Spacer has no tooltip (nothing to hover meaningfully)
    return { Instance = row }
end

function LucidUI.Section:CreateBadge(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local text      = config.Text or "Badge"
    local hasDot    = config.Dot ~= false
    local DOT_SZ    = 6
    local PAD_X     = 10
    local TEXT_H    = config.TextSize or 11
    local BADGE_H   = config.Height or 20

    local textPx = TextService:GetTextSize(text, TEXT_H, Enum.Font.GothamBold, Vector2.new(400, BADGE_H))
    local badgeW = textPx.X + PAD_X * 2 + (hasDot and (DOT_SZ + 6) or 0)

    local row = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, BADGE_H + 4),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })

    local badge = Create("Frame", {
        Size = UDim2.fromOffset(badgeW, BADGE_H),
        Position = UDim2.new(
            config.Align == "center" and 0.5 or (config.Align == "right" and 1 or 0),
            0, 0, 2
        ),
        AnchorPoint = Vector2.new(
            config.Align == "center" and 0.5 or (config.Align == "right" and 1 or 0),
            0
        ),
        BackgroundColor3 = config.Color or theme.Accent,
        BackgroundTransparency = 0.75,
        BorderSizePixel = 0,
        ZIndex = 3, Parent = row,
    })
    Corner(BADGE_H / 2, badge)
    local badgeStroke = Stroke(config.Color or theme.Accent, 1, 0.4, badge)

    local cursorX = PAD_X
    if hasDot then
        local dot = Create("Frame", {
            Size = UDim2.fromOffset(DOT_SZ, DOT_SZ),
            Position = UDim2.fromOffset(cursorX, (BADGE_H - DOT_SZ) / 2),
            BackgroundColor3 = config.Color or theme.Accent,
            BorderSizePixel = 0, ZIndex = 4, Parent = badge,
        })
        Corner(999, dot)
        cursorX = cursorX + DOT_SZ + 6
    end

    local label = Create("TextLabel", {
        Text = text,
        Font = Enum.Font.GothamBold, TextSize = TEXT_H,
        TextColor3 = config.TextColor or (config.Color or theme.Accent),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(cursorX, 0),
        Size = UDim2.new(1, -(cursorX + PAD_X), 1, 0),
        ZIndex = 4, Parent = badge,
    })

    win:_registerTheme(function(t)
        if not config.Color then
            badge.BackgroundColor3 = t.Accent
            badgeStroke.Color = t.Accent
            label.TextColor3 = t.Accent
        end
    end)

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return {
        Instance = row,
        Set = function(_, v) label.Text = tostring(v) end,
        SetColor = function(_, c)
            badge.BackgroundColor3 = c
            badgeStroke.Color = c
            label.TextColor3 = c
            config.Color = c
        end,
    }
end

function LucidUI.Section:CreateStatCard(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local cardH = config.Height or 72

    local row = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, cardH),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })

    local card = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans,
        BorderSizePixel = 0,
        ZIndex = 2, Parent = row,
    })
    Corner(12, card)
    local stroke = Stroke(theme.Border, 1, theme.BorderTrans + 0.05, card)

    if config.Icon and LucidUI.BuildIcon then
        local iconHolder = Create("Frame", {
            Size = UDim2.fromOffset(28, 28),
            Position = UDim2.new(1, -18, 0.5, -14),
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = theme.Accent,
            BackgroundTransparency = 0.85,
            BorderSizePixel = 0,
            ZIndex = 3, Parent = card,
        })
        Corner(8, iconHolder)

        local iconInner = Create("Frame", {
            Size = UDim2.fromOffset(18, 18),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1, ZIndex = 4, Parent = iconHolder,
        })
        pcall(LucidUI.BuildIcon, config.Icon, iconInner, 18, theme.Accent)

        win:_registerTheme(function(t)
            iconHolder.BackgroundColor3 = t.Accent
        end)
    end

    local valueLabel = Create("TextLabel", {
        Text = tostring(config.Value or "0"),
        Font = Enum.Font.GothamBold, TextSize = 24,
        TextColor3 = config.Color or theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(16, 10),
        Size = UDim2.new(1, -70, 0, 30),
        ZIndex = 3, Parent = card,
    })

    local titleLabel = Create("TextLabel", {
        Text = config.Label or "Stat",
        Font = Enum.Font.GothamMedium, TextSize = 11,
        TextColor3 = theme.TextMuted,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(16, 40),
        Size = UDim2.new(1, -24, 0, 16),
        ZIndex = 3, Parent = card,
    })

    win:_registerTheme(function(t)
        card.BackgroundColor3 = t.Surface
        stroke.Color = t.Border
        valueLabel.TextColor3 = config.Color or t.TextPrimary
        titleLabel.TextColor3 = t.TextMuted
    end)

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    local obj = {
        Instance = row,
        Set = function(_, v) valueLabel.Text = tostring(v) end,
        Get = function() return valueLabel.Text end,
        SetColor = function(_, c)
            valueLabel.TextColor3 = c
            config.Color = c
        end,
        SetLabel = function(_, text) titleLabel.Text = tostring(text) end,
    }

    return obj
end

function LucidUI.Section:CreateStatusIndicator(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local state = config.Default ~= false
    local flag  = config.Flag
    local DOT_SZ = 8
    local ROW_H = config.Height or 30

    local row = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, ROW_H),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })

    local dotWrap = Create("Frame", {
        Size = UDim2.fromOffset(DOT_SZ * 2, DOT_SZ * 2),
        Position = UDim2.fromOffset(0, (ROW_H - DOT_SZ * 2) / 2),
        BackgroundTransparency = 1, ZIndex = 3, Parent = row,
    })

    local ring = Create("Frame", {
        Size = UDim2.fromOffset(DOT_SZ, DOT_SZ),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = config.Color or theme.Accent,
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ZIndex = 4, Parent = dotWrap,
    })
    Corner(999, ring)

    local dot = Create("Frame", {
        Size = UDim2.fromOffset(DOT_SZ, DOT_SZ),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = config.Color or theme.Accent,
        BorderSizePixel = 0, ZIndex = 5, Parent = dotWrap,
    })
    Corner(999, dot)

    local label = Create("TextLabel", {
        Text = config.Text or (state and "Running" or "Idle"),
        Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = theme.TextSecondary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(DOT_SZ * 2 + 6, 0),
        Size = UDim2.new(1, -(DOT_SZ * 2 + 6), 1, 0),
        ZIndex = 3, Parent = row,
    })

    local pulseRun = true
    table.insert(win._conns, RunService.RenderStepped:Connect(function(dt)
        if not pulseRun or not ring.Parent then return end
        local t = (tick() * 1.2) % 1
        local size = DOT_SZ + t * DOT_SZ * 1.4
        ring.Size = UDim2.fromOffset(size, size)
        ring.BackgroundTransparency = 0.2 + t * 0.75
    end))

    local function setState(on, silent)
        state = on
        local c = config.Color or win.Theme.Accent
        if not on then c = win.Theme.TextMuted end
        dot.BackgroundColor3 = c
        ring.BackgroundColor3 = c
        ring.BackgroundTransparency = on and 0.5 or 1
        pulseRun = on
        if config.Text == nil then
            label.Text = on and (config.OnText or "Running") or (config.OffText or "Idle")
        end
        if flag then win._configData[flag] = state end
        if not silent and config.Callback then Compat.safeCallback(config.Callback, state) end
    end

    setState(state, true)

    win:_registerTheme(function(t)
        local c = config.Color or t.Accent
        if state then
            dot.BackgroundColor3 = c
            ring.BackgroundColor3 = c
        else
            dot.BackgroundColor3 = t.TextMuted
            ring.BackgroundColor3 = t.TextMuted
        end
        label.TextColor3 = t.TextSecondary
    end)

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    local obj = {
        Instance = row, Flag = flag,
        Set = function(_, v) setState(v, true) end,
        Get = function() return state end,
        SetText = function(_, text) label.Text = tostring(text) end,
    }
    if flag then
        win._elementsByFlag[flag] = obj
        win._configData[flag] = state
    end

    return obj
end

function LucidUI.Section:CreateBanner(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local VARIANT_COLORS = {
        info    = Color3.fromRGB(90, 180, 255),
        success = Color3.fromRGB(90, 210, 130),
        warn    = Color3.fromRGB(255, 189, 46),
        error   = Color3.fromRGB(255, 95, 87),
    }

    local variant = config.Variant or "info"
    local accent  = config.Color or VARIANT_COLORS[variant] or VARIANT_COLORS.info
    local text    = config.Text or ""
    local title   = config.Title

    local row = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })

    local card = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        ZIndex = 2, Parent = row,
    })
    Corner(10, card)
    local stroke = Stroke(accent, 1, 0.55, card)

    local bar = Create("Frame", {
        Size = UDim2.new(0, 3, 1, -16),
        Position = UDim2.fromOffset(8, 8),
        BackgroundColor3 = accent,
        BorderSizePixel = 0, ZIndex = 3, Parent = card,
    })
    Corner(2, bar)

    local ICON_SZ = 16
    local hasIcon = config.Icon ~= false
    if hasIcon and LucidUI.BuildIcon then
        local iconHolder = Create("Frame", {
            Size = UDim2.fromOffset(ICON_SZ, ICON_SZ),
            Position = UDim2.fromOffset(20, 12),
            BackgroundTransparency = 1, ZIndex = 4, Parent = card,
        })
        local iconName = config.Icon
        if not iconName or iconName == true then
            iconName = ({
                info    = "bell",
                success = "check",
                warn    = "warning",
                error   = "cross",
            })[variant] or "bell"
        end
        pcall(LucidUI.BuildIcon, iconName, iconHolder, ICON_SZ, accent)
    end

    local leftPad = hasIcon and 44 or 22
    local rightPad = 14

    local titleLabel
    if title then
        titleLabel = Create("TextLabel", {
            Text = tostring(title),
            Font = Enum.Font.GothamBold, TextSize = 13,
            TextColor3 = accent, BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(leftPad, 10),
            Size = UDim2.new(1, -(leftPad + rightPad), 0, 18),
            ZIndex = 4, Parent = card,
        })
    end

    local bodyLabel = Create("TextLabel", {
        Text = text,
        Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = theme.TextSecondary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Position = UDim2.fromOffset(leftPad, title and 30 or 12),
        Size = UDim2.new(1, -(leftPad + rightPad), 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 4, Parent = card,
    })

    Create("Frame", {
        Size = UDim2.new(1, 0, 0, 12),
        Position = UDim2.new(0, 0, 1, 0),
        BackgroundTransparency = 1, ZIndex = 2, Parent = card,
    })

    win:_registerTheme(function(t)
        card.BackgroundColor3 = t.Surface
        bodyLabel.TextColor3 = t.TextSecondary
    end)

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return {
        Instance = row,
        Set = function(_, v) bodyLabel.Text = tostring(v) end,
        SetTitle = function(_, v)
            if titleLabel then titleLabel.Text = tostring(v) end
        end,
        SetColor = function(_, c)
            accent = c
            stroke.Color = c
            bar.BackgroundColor3 = c
            if titleLabel then titleLabel.TextColor3 = c end
        end,
    }
end

function LucidUI.Section:CreateImage(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local imgH = config.Height or 120
    local img  = config.Image or ""

    local row = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, imgH + (config.Label and 22 or 0)),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })

    local frame = Create("Frame", {
        Size = UDim2.new(1, 0, 0, imgH),
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 2, Parent = row,
    })
    Corner(10, frame)
    local stroke = Stroke(theme.Border, 1, theme.BorderTrans + 0.05, frame)

    local image = Create("ImageLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Image = img,
        ImageTransparency = 0,
        ScaleType = config.ScaleType or Enum.ScaleType.Crop,
        ZIndex = 3, Parent = frame,
    })
    Corner(10, image)

    if config.Label then
        Create("TextLabel", {
            Text = config.Label,
            Font = Enum.Font.GothamMedium, TextSize = 11,
            TextColor3 = theme.TextMuted,
            BackgroundTransparency = 1,
            TextXAlignment = config.Align or Enum.TextXAlignment.Center,
            Position = UDim2.fromOffset(0, imgH + 4),
            Size = UDim2.new(1, 0, 0, 16),
            ZIndex = 3, Parent = row,
        })
    end

    win:_registerTheme(function(t)
        frame.BackgroundColor3 = t.Background
        stroke.Color = t.Border
        for _, c in ipairs(row:GetChildren()) do
            if c:IsA("TextLabel") then c.TextColor3 = t.TextMuted end
        end
    end)

    self:_track(row)

    -- [NEW] Tooltip
    if config.Tooltip and LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(row, config.Tooltip)
    end

    return {
        Instance = row,
        Set = function(_, v)
            img = v or ""
            image.Image = img
        end,
        Get = function() return img end,
        SetTransparency = function(_, a) image.ImageTransparency = a or 0 end,
    }
end

-- ============================================================
-- Cleanup Registration API
-- ============================================================
-- Register a cleanup callback that runs automatically the next
-- time the script is re-executed. Use this for ANY feature that
-- creates connections, loops, character changes, or remotes.
--
-- Example:
--     local conn = RunService.Heartbeat:Connect(function() ... end)
--     LucidUI:OnCleanup(function()
--         conn:Disconnect()
--     end)
--
-- Note: This is a duplicate of the definition in 02_themes.lua.
-- Kept here for backwards compatibility with scripts that expect
-- to find it in the elements module. The 02_themes version runs
-- first and takes priority.
-- ============================================================
if not LucidUI.OnCleanup then
    function LucidUI:OnCleanup(fn)
        if type(fn) ~= "function" then
            warn("[LucidUI] OnCleanup expects a function")
            return
        end
        LucidUI._cleanupCallbacks = LucidUI._cleanupCallbacks or {}
        table.insert(LucidUI._cleanupCallbacks, fn)
    end
end

-- ============================================================
-- Export
-- ============================================================
getgenv().LucidUI = LucidUI
getgenv().LucidUI_ActiveWindows = LucidUI._windows

print("[LucidUI] v" .. LucidUI._version .. " loaded")

return LucidUI

--[[
    Elements — interactive widgets.

    Click handling:
      BindTap (from 01b_polish.lua) fires the callback only when the
      pointer goes down and up within ~12 px of movement.

    Theme handling:
      Hover and press handlers read `win.Theme` at call time, not at
      creation time. This means switching themes mid-session updates
      the hover color, the leave color, and the glow accent live.

    Slider animation:
      • Row highlights on hover
      • Handle grows 18 → 20 on hover, 20 → 22 on grab
      • Grab adds a soft glow ring around the handle
      • :Set() animates fill and handle instead of snapping
      • Value label briefly flashes white then fades back to accent
        every time the value changes
]]

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
        Size = UDim2.new(1, 0, 0, 36),
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

    BindTap(btn, function()
        local abs = btn.AbsolutePosition
        SpawnRipple(btn, pressPos.X - abs.X, pressPos.Y - abs.Y)
        PlayUISound("click")
        if config.Callback then pcall(config.Callback) end
    end, {
        OnDown = function(input) pressPos = input.Position end,
    })

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            Tween(btn, 0.08, { Size = UDim2.new(0.97, 0, 0, 34) }):Play()
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            Tween(btn, 0.15, { Size = UDim2.new(1, 0, 0, 36) }):Play()
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
            Size = UDim2.new(1, 0, 0, 36),
        }):Play()
    end)

    win:_registerTheme(function(t)
        btn.BackgroundColor3 = t.Surface
        label.TextColor3 = t.TextPrimary
        stroke.Color = t.Border
        if glow then glow.Color = t.Accent end
    end)

    self:_track(btn)
    return { Instance = btn, SetText = function(_, text) label.Text = tostring(text) end }
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
        Size = UDim2.new(1, 0, 0, 40),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, row)
    local rowStroke = Stroke(theme.Border, 1, theme.BorderTrans + 0.05, row)

    local label = Create("TextLabel", {
        Text = config.Name or "Toggle",
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextColor3 = theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -80, 1, 0),
        ZIndex = 3,
        Parent = row,
    })

    local track = Create("Frame", {
        Size = UDim2.fromOffset(44, 24),
        Position = UDim2.new(1, -58, 0.5, -12),
        BackgroundColor3 = state and theme.Accent or theme.ToggleOff,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = row,
    })
    Corner(12, track)

    local knob = Create("Frame", {
        Size = UDim2.fromOffset(20, 20),
        Position = state and UDim2.new(1, -22, 0.5, -10) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = track,
    })
    Corner(10, knob)

    local clickArea = Create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 5,
        Parent = row,
    })

    local glow = AttachHoverGlow(row, theme.Accent)
    AttachHoverSound(row)

    local function update(value, silent)
        state = value
        local t = win.Theme
        Tween(track, 0.22, {
            BackgroundColor3 = state and t.Accent or t.ToggleOff,
        }, Enum.EasingStyle.Quart):Play()
        Tween(knob, 0.22, {
            Position = state and UDim2.new(1, -22, 0.5, -10) or UDim2.fromOffset(2, 2),
        }, Enum.EasingStyle.Quart):Play()
        if flag then win._configData[flag] = state end
        if not silent and config.Callback then pcall(config.Callback, state) end
    end

    BindTap(clickArea, function()
        PlayUISound("click")
        update(not state)
    end)

    clickArea.MouseEnter:Connect(function()
        local t = win.Theme
        Tween(row, 0.15, {
            BackgroundTransparency = math.max(t.SurfaceTrans - 0.1, 0),
        }):Play()
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
        Instance = row,
        Flag = flag,
        Set = function(_, value) update(value, true) end,
        Get = function() return state end,
    }
    if flag then
        win._elementsByFlag[flag] = obj
        win._configData[flag] = state
    end

    self:_track(row)
    return obj
end

-- ============================================================
-- Slider — animated
-- ============================================================
function LucidUI.Section:CreateSlider(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local min   = (config.Range and config.Range[1]) or 0
    local max   = (config.Range and config.Range[2]) or 100
    local value = config.CurrentValue or min
    local inc   = config.Increment or 1
    local flag  = config.Flag

    local HANDLE_BASE  = 18
    local HANDLE_HOVER = 20
    local HANDLE_GRAB  = 22

    local row = Create("Frame", {
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 54),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, row)
    local rowStroke = Stroke(theme.Border, 1, theme.BorderTrans + 0.05, row)

    local nameLabel = Create("TextLabel", {
        Text = config.Name or "Slider",
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextColor3 = theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 6),
        Size = UDim2.new(1, -28, 0, 18),
        ZIndex = 3,
        Parent = row,
    })

    local valueLabel = Create("TextLabel", {
        Text = tostring(value),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = theme.Accent,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.fromOffset(14, 6),
        Size = UDim2.new(1, -28, 0, 18),
        ZIndex = 3,
        Parent = row,
    })

    local track = Create("Frame", {
        Size = UDim2.new(1, -28, 0, 4),
        Position = UDim2.new(0, 14, 1, -16),
        BackgroundColor3 = theme.SliderTrack,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = row,
    })
    Corner(2, track)

    local fill = Create("Frame", {
        Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = track,
    })
    Corner(2, fill)

    local handle = Create("Frame", {
        Size = UDim2.fromOffset(HANDLE_BASE, HANDLE_BASE),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = track,
    })
    Corner(9, handle)
    local handleStroke = Stroke(theme.Border, 1, 0.7, handle)

    local drag = Create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 5,
        Parent = track,
    })

    local dragging = false
    local hovering = false
    local flashConn = nil

    -- ── Value flash ───────────────────────────────────────────
    -- Briefly white, then fade back to accent. Used on every
    -- value change (drag or programmatic).
    local function flashValue()
        if flashConn then flashConn:Disconnect() flashConn = nil end
        valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        flashConn = Tween(valueLabel, 0.35, { TextColor3 = win.Theme.Accent })
        flashConn:Play()
    end

    -- ── Handle sizing helper ──────────────────────────────────
    local function setHandleSize(size)
        Tween(handle, 0.14, { Size = UDim2.fromOffset(size, size) }, Enum.EasingStyle.Quart):Play()
    end

    -- ── Snap-to-input (used while dragging) ───────────────────
    local function setFromInput(input)
        local rel = math.clamp(
            (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X,
            0, 1
        )
        local raw = min + (max - min) * rel
        value = math.floor((raw / inc) + 0.5) * inc
        value = math.clamp(value, min, max)
        fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
        handle.Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0)
        valueLabel.Text = tostring(value)
    end

    drag.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if LucidUI._activeSlider and LucidUI._activeSlider ~= drag then return end
            LucidUI._activeSlider = drag
            dragging = true
            setHandleSize(HANDLE_GRAB)
            Tween(handleStroke, 0.12, { Transparency = 0.35 }):Play()
            setFromInput(input)
            flashValue()
            if flag then win._configData[flag] = value end
            if config.Callback then pcall(config.Callback, value) end
        end
    end)

    table.insert(win._conns, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            setFromInput(input)
            flashValue()
            if flag then win._configData[flag] = value end
            if config.Callback then pcall(config.Callback, value) end
        end
    end))

    table.insert(win._conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if LucidUI._activeSlider == drag then LucidUI._activeSlider = nil end
            dragging = false
            setHandleSize(hovering and HANDLE_HOVER or HANDLE_BASE)
            Tween(handleStroke, 0.18, { Transparency = 0.7 }):Play()
        end
    end))

    -- ── Hover state ──────────────────────────────────────────
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

    -- ── Theme registration ────────────────────────────────────
    win:_registerTheme(function(t)
        row.BackgroundColor3   = t.Surface
        nameLabel.TextColor3   = t.TextPrimary
        valueLabel.TextColor3  = t.Accent
        track.BackgroundColor3 = t.SliderTrack
        fill.BackgroundColor3  = t.Accent
        rowStroke.Color        = t.Border
        handleStroke.Color     = t.Border
    end)

    -- ── Programmatic set — animated ───────────────────────────
    local obj = {
        Instance = row,
        Flag = flag,
        Set = function(_, v)
            v = math.clamp(v, min, max)
            value = v
            local targetFill   = UDim2.new((value - min) / (max - min), 0, 1, 0)
            local targetHandle = UDim2.new((value - min) / (max - min), 0, 0.5, 0)
            Tween(fill, 0.24, { Size = targetFill }, Enum.EasingStyle.Quart):Play()
            Tween(handle, 0.24, { Position = targetHandle }, Enum.EasingStyle.Quart):Play()
            valueLabel.Text = tostring(value)
            flashValue()
            if flag then win._configData[flag] = value end
        end,
        Get = function() return value end,
    }
    if flag then
        win._elementsByFlag[flag] = obj
        win._configData[flag] = value
    end

    self:_track(row)
    return obj
end

-- ============================================================
-- Dropdown
-- ============================================================
function LucidUI.Section:CreateDropdown(config)
    config = config or {}
    local win, theme = self.Tab.Window, self.Tab.Window.Theme

    local options  = config.Options or {}
    local value    = config.CurrentOption or options[1] or ""
    local expanded = false
    local flag     = config.Flag

    local ROW_H, OPT_H, OPT_P = 40, 32, 4

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
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, ROW_H),
        ZIndex = 3,
        Parent = row,
    })

    local nameLabel = Create("TextLabel", {
        Text = config.Name or "Dropdown",
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextColor3 = theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -100, 1, 0),
        ZIndex = 4,
        Parent = headerBtn,
    })

    local valueLabel = Create("TextLabel", {
        Text = tostring(value),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = theme.Accent,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Size = UDim2.new(1, -40, 1, 0),
        ZIndex = 4,
        Parent = headerBtn,
    })

    local arrowLbl = Create("TextLabel", {
        Text = "v",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = theme.TextMuted,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -24, 0, 0),
        Size = UDim2.fromOffset(20, ROW_H),
        ZIndex = 4,
        Parent = headerBtn,
    })

    local list = Create("Frame", {
        Size = UDim2.new(1, -20, 0, 0),
        Position = UDim2.fromOffset(10, ROW_H),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 3,
        Parent = row,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, OPT_P),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = list,
    })

    local optionBtns = {}
    for i, opt in ipairs(options) do
        local optBtn = Create("TextButton", {
            Text = tostring(opt),
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextColor3 = theme.TextPrimary,
            BackgroundColor3 = theme.Background,
            BackgroundTransparency = 0.5,
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, OPT_H),
            LayoutOrder = i,
            ZIndex = 4,
            Parent = list,
        })
        Corner(8, optBtn)

        optBtn.MouseEnter:Connect(function()
            local t = win.Theme
            Tween(optBtn, 0.12, {
                BackgroundColor3 = t.Accent,
                BackgroundTransparency = 0.3,
            }):Play()
        end)
        optBtn.MouseLeave:Connect(function()
            local t = win.Theme
            Tween(optBtn, 0.12, {
                BackgroundColor3 = t.Background,
                BackgroundTransparency = 0.5,
            }):Play()
        end)

        BindTap(optBtn, function()
            value = opt
            valueLabel.Text = tostring(opt)
            expanded = false
            Tween(list, 0.22, { Size = UDim2.new(1, -20, 0, 0) }):Play()
            Tween(row,  0.22, { Size = UDim2.new(1, 0, 0, ROW_H) }):Play()
            Tween(arrowLbl, 0.20, { Rotation = 0 }):Play()
            PlayUISound("click")
            if flag then win._configData[flag] = value end
            if config.Callback then pcall(config.Callback, opt) end
        end)

        table.insert(optionBtns, optBtn)
    end

    BindTap(headerBtn, function()
        expanded = not expanded
        local openH = #options * (OPT_H + OPT_P) + 8
        Tween(list, 0.22, {
            Size = UDim2.new(1, -20, 0, expanded and openH or 0),
        }, Enum.EasingStyle.Quart):Play()
        Tween(row, 0.22, {
            Size = UDim2.new(1, 0, 0, expanded and (ROW_H + openH + 8) or ROW_H),
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
        for _, ob in ipairs(optionBtns) do
            ob.BackgroundColor3 = t.Background
            ob.TextColor3       = t.TextPrimary
        end
    end)

    local obj = {
        Instance = row,
        Flag = flag,
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
        Size = UDim2.new(1, 0, 0, 40),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, row)

    local nameLabel = Create("TextLabel", {
        Text = config.Name or "Keybind",
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextColor3 = theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -110, 1, 0),
        ZIndex = 3,
        Parent = row,
    })

    local keyBox = Create("TextButton", {
        Text = currentKey.Name,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = theme.TextPrimary,
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 0.3,
        AutoButtonColor = false,
        Size = UDim2.fromOffset(90, 26),
        Position = UDim2.new(1, -104, 0.5, -13),
        ZIndex = 3,
        Parent = row,
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
            if config.Callback then pcall(config.Callback, currentKey) end
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
        Instance = row,
        Flag = flag,
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
        Size = UDim2.new(1, 0, 0, 40),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, row)

    local nameLabel = Create("TextLabel", {
        Text = config.Name or "Input",
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextColor3 = theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -180, 1, 0),
        ZIndex = 3,
        Parent = row,
    })

    local box = Create("TextBox", {
        Text = value,
        PlaceholderText = config.Placeholder or "...",
        PlaceholderColor3 = theme.TextMuted,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = theme.TextPrimary,
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 0.3,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.fromOffset(140, 26),
        Position = UDim2.new(1, -154, 0.5, -13),
        ZIndex = 3,
        Parent = row,
    })
    Corner(8, box)
    Create("UIPadding", {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        Parent = box,
    })

    box.FocusLost:Connect(function()
        value = box.Text
        if flag then win._configData[flag] = value end
        if config.Callback then pcall(config.Callback, value) end
    end)

    win:_registerTheme(function(t)
        row.BackgroundColor3  = t.Surface
        nameLabel.TextColor3  = t.TextPrimary
        box.BackgroundColor3  = t.Background
        box.TextColor3        = t.TextPrimary
        box.PlaceholderColor3 = t.TextMuted
    end)

    local obj = {
        Instance = row,
        Flag = flag,
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
    return obj
end

-- ============================================================
-- TextDisplay
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

    local titleLabel = Create("TextLabel", {
        Text = config.Title or "Info",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = theme.TextMuted,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 16),
        LayoutOrder = 1,
        ZIndex = 3,
        Parent = row,
    })

    local contentLabel = Create("TextLabel", {
        Text = config.Content or "",
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2,
        ZIndex = 3,
        Parent = row,
    })

    win:_registerTheme(function(t)
        row.BackgroundColor3    = t.Surface
        titleLabel.TextColor3   = t.TextMuted
        contentLabel.TextColor3 = t.TextPrimary
    end)

    self:_track(row)

    return {
        Instance = row,
        Set      = function(_, v) contentLabel.Text = tostring(v) end,
        SetTitle = function(_, v) titleLabel.Text   = tostring(v) end,
    }
end

-- ============================================================
-- Cleanup and export
-- ============================================================
if getgenv().LucidUI_ActiveWindows then
    for _, w in ipairs(getgenv().LucidUI_ActiveWindows) do
        pcall(function()
            for _, c in ipairs(w._conns or {}) do
                if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
            end
            if w.Gui then w.Gui:Destroy() end
        end)
    end
    pcall(function()
        if LucidUI._notifRoot then LucidUI._notifRoot:Destroy() end
    end)
end

getgenv().LucidUI_ActiveWindows = LucidUI._windows
getgenv().LucidUI = LucidUI

print("[LucidUI] v" .. LucidUI._version .. " loaded")

return LucidUI

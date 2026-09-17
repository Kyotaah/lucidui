--[[
    Window — creates the main window and every layer that sits inside it.

    [IMPROVEMENT] Fixed the missing `end)` bug in the resize handler.
    Added CloseAction config, Center/GetSize/SetSize methods, larger
    mobile resize hitbox, and safe pcall wrapping on all tweens.
]]

LucidUI.Window = {}
LucidUI.Window.__index = LucidUI.Window

local function TweenColor(inst, prop, target, time)
    if not inst or not inst.Parent then return end
    local current = inst[prop]
    if typeof(current) ~= "Color3" then
        inst[prop] = target
        return
    end
    pcall(function()
        TweenService:Create(
            inst,
            TweenInfo.new(time or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { [prop] = target }
        ):Play()
    end)
end

local function isPrimaryPointer(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

function LucidUI:CreateWindow(config)
    config = config or {}

    local W = setmetatable({}, LucidUI.Window)

    W.Name         = config.Name or "LucidUI"
    W.Theme        = LucidUI.Themes[config.Theme or "Default"] or LucidUI.Themes.Default
    W.ThemeName    = config.Theme or "Default"
    W.Tabs         = {}
    W.ActiveTab    = nil
    W.Visible      = true
    W.Minimized    = false
    W.Floating     = false
    W.SettingsOpen = false

    W.PillKeybind  = config.PillKeybind or Enum.KeyCode.Home
    W._closeAction = config.CloseAction or "pill" -- "pill" or "destroy"

    W._configData     = {}
    W._elementsByFlag = {}
    W._themeElements  = {}
    W._conns          = {}
    W._accentOverride = nil

    W._minWidth,  W._minHeight = 320, 240
    W._maxWidth,  W._maxHeight = 1200, 900

    W._customTheme       = nil
    W._customThemeActive = false
    W._currentConfig     = "default"
    W._backgroundUrl     = nil

    W._width  = config.Width  or 620
    W._height = config.Height or 460
    W._fullSize      = UDim2.fromOffset(W._width, W._height)
    W._collapsedSize = UDim2.fromOffset(W._width, 44)

    W._compactWidth = nil

    LucidUI._lastTheme = W.Theme
    Compat.ensureFolders()

    W.Gui = Create("ScreenGui", {
        Name = "LucidUI_" .. W.Name,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 100,
        Enabled = false,
        Parent = PlayerGui,
    })

    W.UIScale = Create("UIScale", { Scale = GetResponsiveScale(), Parent = W.Gui })

    table.insert(W._conns, Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        if W.UIScale and W.UIScale.Parent then W.UIScale.Scale = GetResponsiveScale() end
        pcall(function() ClampPosition(W.Main) end)
        pcall(function() ClampPosition(W.FloatingPill) end)
    end))

    W.Main = Create("Frame", {
        Name = "Main",
        Size = W._fullSize,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Visible = false,
        Parent = W.Gui,
    })
    ApplyGlass(W.Main, W.Theme, { cornerRadius = 18, shadow = true })

    W._bgImage = Create("ImageLabel", {
        Name = "BackgroundImage",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Image = "",
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 0,
        Visible = false,
        Parent = W.Main,
    })
    Corner(18, W._bgImage)

    W.Header = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundTransparency = 1,
        ZIndex = 3,
        Parent = W.Main,
    })

    W.TitleLabel = Create("TextLabel", {
        Text = W.Name,
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = W.Theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(18, 0),
        Size = UDim2.new(1, -170, 1, 0),
        ZIndex = 3,
        Parent = W.Header,
    })

    local titlePx = TextService:GetTextSize(
        W.Name, 16, Enum.Font.GothamBold, Vector2.new(2000, 44)
    )
    W._compactWidth = math.clamp(titlePx.X + 120, 220, W._width)

    local pillTextPx = TextService:GetTextSize(
        W.Name, 13, Enum.Font.GothamBold, Vector2.new(2000, 32)
    )
    local pillWidth = math.clamp(pillTextPx.X + 50, 120, 280)

    local settingsBtn = Create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(36, 36),
        Position = UDim2.new(1, -120, 0.5, -18),
        ZIndex = 3,
        Parent = W.Header,
    })
    W._settingsBtn = settingsBtn

    local gearHolder, gearRing, gearParts, gearHole =
        BuildGearIcon(settingsBtn, 18, W.Theme.TextSecondary, W.Theme.Background)
    gearHolder.Position = UDim2.fromScale(0.5, 0.5)
    gearHolder.AnchorPoint = Vector2.new(0.5, 0.5)

    local gearRot   = 0
    local gearSpeed = 30
    table.insert(W._conns, RunService.RenderStepped:Connect(function(dt)
        if not gearRing or not gearRing.Parent then return end
        gearRot = (gearRot + dt * gearSpeed) % 360
        gearRing.Rotation = gearRot
    end))

    BindTap(settingsBtn, function() W:ToggleSettings() end)

    settingsBtn.MouseEnter:Connect(function()
        for _, p in ipairs(gearParts) do
            Tween(p, 0.15, { BackgroundColor3 = W.Theme.Accent }):Play()
        end
        gearSpeed = 120
    end)
    settingsBtn.MouseLeave:Connect(function()
        for _, p in ipairs(gearParts) do
            Tween(p, 0.15, { BackgroundColor3 = W.Theme.TextSecondary }):Play()
        end
        gearSpeed = 30
    end)

    W._gearRefs = { parts = gearParts, hole = gearHole, ring = gearRing }

    -- ==========================================
    -- MINIMIZE BUTTON
    -- ==========================================
    local minBtn = Create("TextButton", {
        Text = "",
        BackgroundColor3 = Color3.fromRGB(255, 189, 46),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(12, 12),
        Position = UDim2.new(1, -48, 0.5, -6),
        AutoButtonColor = false,
        ZIndex = 3,
        Parent = W.Header,
    })
    Corner(999, minBtn)

    local minDot = Create("TextLabel", {
        Text = "-",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(140, 90, 0),
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        TextTransparency = 1,
        ZIndex = 4,
        Parent = minBtn,
    })

    BindTap(minBtn, function() W:SetMinimized(not W.Minimized) end, { MoveThreshold = 25 })

    minBtn.MouseEnter:Connect(function()
        Tween(minBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(255, 214, 100) }):Play()
        Tween(minDot, 0.15, { TextTransparency = 0 }):Play()
    end)
    minBtn.MouseLeave:Connect(function()
        Tween(minBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(255, 189, 46) }):Play()
        Tween(minDot, 0.15, { TextTransparency = 1 }):Play()
    end)

    -- ==========================================
    -- CLOSE BUTTON
    -- ==========================================
    local closeBtn = Create("TextButton", {
        Text = "",
        BackgroundColor3 = Color3.fromRGB(255, 95, 87),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(12, 12),
        Position = UDim2.new(1, -26, 0.5, -6),
        AutoButtonColor = false,
        ZIndex = 3,
        Parent = W.Header,
    })
    Corner(999, closeBtn)

    local closeDot = Create("TextLabel", {
        Text = "x",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(120, 20, 20),
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        TextTransparency = 1,
        ZIndex = 4,
        Parent = closeBtn,
    })

    BindTap(closeBtn, function()
        if W._closeAction == "destroy" then
            W:Destroy()
        else
            W:MinimizeToPill()
        end
    end, { MoveThreshold = 25 })

    closeBtn.MouseEnter:Connect(function()
        Tween(closeBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(255, 130, 120) }):Play()
        Tween(closeDot, 0.15, { TextTransparency = 0 }):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        Tween(closeBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(255, 95, 87) }):Play()
        Tween(closeDot, 0.15, { TextTransparency = 1 }):Play()
    end)

    W._iconRefs = {
        minimize = { label = minBtn },
        close    = { label = closeBtn },
    }

    W.Separator = Create("Frame", {
        Size = UDim2.new(1, -32, 0, 1),
        Position = UDim2.fromOffset(16, 44),
        BackgroundColor3 = W.Theme.Border,
        BackgroundTransparency = W.Theme.BorderTrans + 0.03,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = W.Main,
    })

    W.TabStrip = Create("ScrollingFrame", {
        Name = "TabStrip",
        Size = UDim2.new(1, -32, 0, 34),
        Position = UDim2.fromOffset(16, 52),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.X,
        CanvasSize = UDim2.new(0, 0, 0, 34),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ZIndex = 2,
        Parent = W.Main,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Parent = W.TabStrip,
    })

    W.Content = Create("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -24, 1, -110),
        Position = UDim2.fromOffset(12, 94),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 2,
        Parent = W.Main,
    })

    -- ============================================================
    -- Shared gesture state — header drag and resize
    -- ============================================================
    local gesture = {
        input        = nil,
        mode         = nil,
        startPos     = nil,
        startSize    = nil,
        mainStartPos = nil,
    }

    W.Header.InputBegan:Connect(function(input)
        if not isPrimaryPointer(input) then return end
        if gesture.input then return end
        
        -- CRITICAL FIX: Delay the drag to allow button clicks to register
        task.wait(0.05)
        
        -- If the input was released during the delay, or another gesture started, cancel
        if gesture.input then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return end
        end

        if W._onBeforeDragStart then W:_onBeforeDragStart() end
        gesture.input        = input
        gesture.mode         = "drag"
        gesture.startPos     = input.Position
        gesture.mainStartPos = W.Main.Position
    end)

    -- [IMPROVEMENT] 44x44 hitbox for mobile friendliness
    local resizeHandle = Create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(44, 44),
        Position = UDim2.new(1, -44, 1, -44),
        ZIndex = 4,
        Parent = W.Main,
    })

    local grip1 = Create("Frame", {
        Size = UDim2.fromOffset(12, 2),
        Position = UDim2.new(1, -8, 1, -8),
        AnchorPoint = Vector2.new(1, 0.5),
        Rotation = 45,
        BackgroundColor3 = W.Theme.TextMuted,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Parent = resizeHandle,
    })
    Corner(1, grip1)

    local grip2 = Create("Frame", {
        Size = UDim2.fromOffset(8, 2),
        Position = UDim2.new(1, -8, 1, -5),
        AnchorPoint = Vector2.new(1, 0.5),
        Rotation = 45,
        BackgroundColor3 = W.Theme.TextMuted,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Parent = resizeHandle,
    })
    Corner(1, grip2)

    W._gripFrames = { grip1, grip2 }

    resizeHandle.InputBegan:Connect(function(input)
        if not isPrimaryPointer(input) then return end
        if gesture.input then return end
        if W._docked then return end
        gesture.input     = input
        gesture.mode      = "resize"
        gesture.startPos  = input.Position
        gesture.startSize = { X = W._width, Y = W._height }
    end)

    table.insert(W._conns, UserInputService.InputChanged:Connect(function(input)
        if input ~= gesture.input then return end

        if gesture.mode == "drag" then
            local d = input.Position - gesture.startPos
            W.Main.Position = UDim2.new(
                gesture.mainStartPos.X.Scale, gesture.mainStartPos.X.Offset + d.X,
                gesture.mainStartPos.Y.Scale, gesture.mainStartPos.Y.Offset + d.Y
            )
            if W._onDragTick then W:_onDragTick() end
        elseif gesture.mode == "resize" then
            local d = input.Position - gesture.startPos
            W._width  = math.clamp(gesture.startSize.X + d.X, W._minWidth,  W._maxWidth)
            W._height = math.clamp(gesture.startSize.Y + d.Y, W._minHeight, W._maxHeight)
            W._fullSize      = UDim2.fromOffset(W._width, W._height)
            W._collapsedSize = UDim2.fromOffset(W._width, 44)

            local tpx = TextService:GetTextSize(
                W.Name, 16, Enum.Font.GothamBold, Vector2.new(2000, 44)
            )
            W._compactWidth = math.clamp(tpx.X + 120, 220, W._width)

            if not W.Minimized then
                W.Main.Size    = UDim2.fromOffset(W._width, W._height)
                W.Content.Size = UDim2.new(1, -24, 1, -110)
            end
        end
    end))

    table.insert(W._conns, UserInputService.InputEnded:Connect(function(input)
        if input ~= gesture.input then return end
        local wasDrag = (gesture.mode == "drag")
        if gesture.mode == "drag" or gesture.mode == "resize" then
            ClampPosition(W.Main)
        end
        if wasDrag and W._onDragEnd then W:_onDragEnd() end
        gesture.input        = nil
        gesture.mode         = nil
        gesture.startPos     = nil
        gesture.startSize    = nil
        gesture.mainStartPos = nil
    end))

    -- ============================================================
    -- Global keybinds
    -- ============================================================
    table.insert(W._conns, UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if LucidUI._keyListening then return end

        if input.KeyCode == Enum.KeyCode.RightShift then
            if W.Floating then
                W:RestoreFromPill()
            else
                W:SetVisible(not W.Visible)
            end
        elseif W.PillKeybind and input.KeyCode == W.PillKeybind then
            W:TogglePillMode()
        end
    end))

    -- ============================================================
    -- Settings panel
    -- ============================================================
    W.SettingsPanel = Create("CanvasGroup", {
        Name = "SettingsPanel",
        Size = UDim2.new(1, 0, 1, -45),
        Position = UDim2.new(0, 0, 0, 45),
        BackgroundColor3 = W.Theme.Background,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Visible = false,
        GroupTransparency = 1,
        ZIndex = 5,
        Parent = W.Main,
    })
    local spCorner = Instance.new("UICorner")
    spCorner.TopLeftRadius     = UDim.new(0, 0)
    spCorner.TopRightRadius    = UDim.new(0, 0)
    spCorner.BottomLeftRadius  = UDim.new(0, 18)
    spCorner.BottomRightRadius = UDim.new(0, 18)
    spCorner.Parent = W.SettingsPanel

    local spHeader = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        ZIndex = 6,
        Parent = W.SettingsPanel,
    })

    local backBtn = Create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(32, 32),
        Position = UDim2.fromOffset(12, 4),
        ZIndex = 7,
        Parent = spHeader,
    })
    local backLbl = Create("TextLabel", {
        Text = "<",
        Font = Enum.Font.GothamBold,
        TextSize = 22,
        TextColor3 = W.Theme.TextSecondary,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 7,
        Parent = backBtn,
    })

    BindTap(backBtn, function()
        if W._cancelKeybindListen then pcall(W._cancelKeybindListen) end
        W:ToggleSettings(false)
    end, { MoveThreshold = 8 })

    Create("TextLabel", {
        Text = "Settings",
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = W.Theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(52, 0),
        Size = UDim2.new(1, -60, 1, 0),
        ZIndex = 7,
        Parent = spHeader,
    })

    Create("Frame", {
        Size = UDim2.new(1, -24, 0, 1),
        Position = UDim2.fromOffset(12, 40),
        BackgroundColor3 = W.Theme.Border,
        BackgroundTransparency = W.Theme.BorderTrans + 0.03,
        BorderSizePixel = 0,
        ZIndex = 7,
        Parent = W.SettingsPanel,
    })

    local spContent = Create("ScrollingFrame", {
        Size = UDim2.new(1, -20, 1, -50),
        Position = UDim2.fromOffset(10, 44),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = W.Theme.TextMuted,
        ScrollBarImageTransparency = 0.5,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 6,
        Parent = W.SettingsPanel,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = spContent,
    })
    Create("UIPadding", {
        PaddingRight = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 12),
        Parent = spContent,
    })

    W._spContent     = spContent
    W._settingsOrder = 0
    W._backArrowLbl  = backLbl

    -- ============================================================
    -- Floating pill
    -- ============================================================
    W.FloatingPill = Create("TextButton", {
        Name = "FloatingPill",
        Text = "",
        Size = UDim2.fromOffset(pillWidth, 32),
        Position = UDim2.new(0.5, 0, 0, 8),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = W.Theme.Background,
        BackgroundTransparency = W.Theme.BackgroundTrans,
        AutoButtonColor = false,
        Visible = false,
        ClipsDescendants = true,
        Parent = W.Gui,
    })
    Corner(16, W.FloatingPill)
    W._pillStroke = Stroke(W.Theme.Accent, 1, 0.3, W.FloatingPill)

    W._pillDot = Create("Frame", {
        Size = UDim2.fromOffset(8, 8),
        Position = UDim2.fromOffset(14, 12),
        BackgroundColor3 = W.Theme.Accent,
        BorderSizePixel = 0,
        Parent = W.FloatingPill,
    })
    Corner(4, W._pillDot)

    W._pillLabel = Create("TextLabel", {
        Text = W.Name,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = W.Theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(28, 0),
        Size = UDim2.new(1, -34, 1, 0),
        Parent = W.FloatingPill,
    })

    task.spawn(function()
        local t = 0
        while W._pillDot do
            if W._pillDot.Parent then
                t = (t + 0.03) % 2
                local pulse = 0.5 + 0.5 * math.sin(t * math.pi)
                W._pillDot.BackgroundTransparency = pulse * 0.55
            end
            task.wait(0.03)
        end
    end)

    local pillGesture = { input = nil, startPos = nil, startWindowPos = nil }

    W.FloatingPill.InputBegan:Connect(function(input)
        if not isPrimaryPointer(input) then return end
        if pillGesture.input then return end
        pillGesture.input          = input
        pillGesture.startPos       = input.Position
        pillGesture.startWindowPos = W.FloatingPill.Position
    end)

    table.insert(W._conns, UserInputService.InputChanged:Connect(function(input)
        if input ~= pillGesture.input then return end
        local d = input.Position - pillGesture.startPos
        W.FloatingPill.Position = UDim2.new(
            pillGesture.startWindowPos.X.Scale, pillGesture.startWindowPos.X.Offset + d.X,
            pillGesture.startWindowPos.Y.Scale, pillGesture.startWindowPos.Y.Offset + d.Y
        )
    end))

    table.insert(W._conns, UserInputService.InputEnded:Connect(function(input)
        if input ~= pillGesture.input then return end
        ClampPosition(W.FloatingPill)
        pillGesture.input          = nil
        pillGesture.startPos       = nil
        pillGesture.startWindowPos = nil
    end))

    BindTap(W.FloatingPill, function()
        W:RestoreFromPill()
    end, { MoveThreshold = 8 })

    table.insert(LucidUI._windows, W)

    print("[LucidUI] Window created:", W.Name)

    local entranceScale = Create("UIScale", { Scale = 0.90, Parent = W.Main })

    local function RunEntrance()
        W.Main.Visible = true
        W.Gui.Enabled  = true
        entranceScale.Scale = 0.90
        W.Main.BackgroundTransparency = 1
        Tween(entranceScale, 0.40, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
        Tween(W.Main, 0.40, { BackgroundTransparency = W.Theme.BackgroundTrans }):Play()
    end

    if W._initDocking then W:_initDocking(config) end

    if config.IntroEnabled ~= false and type(LucidUI.ShowIntro) == "function" then
        LucidUI:ShowIntro({
            Title       = config.IntroTitle or W.Name,
            Subtitle    = config.IntroSubtitle or ("v" .. LucidUI._version),
            Tagline     = config.IntroTagline or "Modern interface suite",
            Duration    = config.IntroDuration or 2.8,
            Stages      = config.IntroStages,
            Theme       = W.Theme,
            SkipOnInput = config.IntroSkipOnInput ~= false,
            OnComplete  = RunEntrance,
        })
    else
        RunEntrance()
    end

    return W
end

function LucidUI.Window:MinimizeToPill()
    if not self.FloatingPill then return end
    self.Floating = true

    local mx, my = self.Main.Position.X, self.Main.Position.Y

    local mainSlide = TweenService:Create(self.Main, Ease.In(0.22), {
        Position = UDim2.new(mx.Scale, mx.Offset, my.Scale, my.Offset - 30),
        BackgroundTransparency = 1,
    })
    mainSlide:Play()

    mainSlide.Completed:Connect(function()
        if not self.Floating then return end

        self.Main.Visible  = false
        self.Main.Position = UDim2.new(0.5, 0, 0.5, 0)

        self.FloatingPill.Visible                = true
        self.FloatingPill.Position               = UDim2.new(0.5, 0, 0, -50)
        self.FloatingPill.BackgroundTransparency = 1
        self._pillStroke.Transparency            = 1
        self._pillDot.BackgroundTransparency     = 1
        self._pillLabel.TextTransparency         = 1

        TweenService:Create(self.FloatingPill, Ease.Out(0.32), {
            Position = UDim2.new(0.5, 0, 0, 8),
        }):Play()
        TweenService:Create(self.FloatingPill, Ease.FadeIn(0.25), {
            BackgroundTransparency = self.Theme.BackgroundTrans,
        }):Play()
        TweenService:Create(self._pillStroke, Ease.FadeIn(0.28), { Transparency = 0.3 }):Play()
        TweenService:Create(self._pillLabel,  Ease.FadeIn(0.25), { TextTransparency = 0 }):Play()
        self._pillDot.BackgroundTransparency = 0
    end)
end

function LucidUI.Window:RestoreFromPill()
    if not self.FloatingPill then return end
    self.Floating = false

    local slide = TweenService:Create(self.FloatingPill, Ease.In(0.26), {
        Position = UDim2.new(0.5, 0, 0, -50),
    })
    slide:Play()

    TweenService:Create(self.FloatingPill, Ease.FadeOut(0.20), { BackgroundTransparency = 1 }):Play()
    TweenService:Create(self._pillStroke,  Ease.FadeOut(0.20), { Transparency = 1 }):Play()
    TweenService:Create(self._pillDot,     Ease.FadeOut(0.18), { BackgroundTransparency = 1 }):Play()
    TweenService:Create(self._pillLabel,   Ease.FadeOut(0.18), { TextTransparency = 1 }):Play()

    self.Main.Visible                = true
    self.Main.Position               = UDim2.new(0.5, 0, 0.5, -20)
    self.Main.BackgroundTransparency = 1

    TweenService:Create(self.Main, Ease.Out(0.35), {
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundTransparency = self.Theme.BackgroundTrans,
    }):Play()

    slide.Completed:Connect(function()
        if not self.Floating then
            self.FloatingPill.Visible = false
        end
    end)

    task.delay(0.4, function() ClampPosition(self.Main) end)
end

function LucidUI.Window:TogglePillMode()
    if self.Floating then
        self:RestoreFromPill()
    else
        self:MinimizeToPill()
    end
end

function LucidUI.Window:ToggleSettings(state)
    if state == nil then state = not self.SettingsOpen end
    self.SettingsOpen = state

    local SHOWN  = UDim2.new(0, 0, 0, 45)
    local HIDDEN = UDim2.new(0, 0, 0, 85)

    if state then
        self.TabStrip.Visible  = false
        self.Content.Visible   = false
        self.Separator.Visible = false

        self.SettingsPanel.Visible           = true
        self.SettingsPanel.Position          = HIDDEN
        self.SettingsPanel.GroupTransparency = 1

        TweenService:Create(self.SettingsPanel, Ease.Out(0.38), { Position = SHOWN }):Play()
        TweenService:Create(self.SettingsPanel, Ease.FadeIn(0.32), { GroupTransparency = 0 }):Play()

        if self._themeSlotsRefresh    then pcall(self._themeSlotsRefresh) end
        if self._themeDropdownRefresh then pcall(self._themeDropdownRefresh) end
    else
        if self._cancelKeybindListen then pcall(self._cancelKeybindListen) end

        local slide = TweenService:Create(self.SettingsPanel, Ease.In(0.26), { Position = HIDDEN })
        slide:Play()
        TweenService:Create(self.SettingsPanel, Ease.FadeOut(0.22), { GroupTransparency = 1 }):Play()

        slide.Completed:Connect(function()
            if not self.SettingsOpen then
                self.SettingsPanel.Visible = false
                if not self.Minimized then
                    self.TabStrip.Visible  = true
                    self.Content.Visible   = true
                    self.Separator.Visible = true
                end
            end
        end)
    end
end

function LucidUI.Window:Destroy()
    for _, c in ipairs(self._conns or {}) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    self._conns = {}

    if LucidUI._activeSlider and LucidUI._activeSlider.Parent == self.Gui then
        LucidUI._activeSlider = nil
    end

    if self.Gui then
        self.Gui:Destroy()
        self.Gui = nil
    end

    for i, w in ipairs(LucidUI._windows) do
        if w == self then
            table.remove(LucidUI._windows, i)
            break
        end
    end

    print("[LucidUI] Window destroyed:", self.Name)
end

function LucidUI.Window:SetVisible(state)
    self.Visible = state
    if self.Gui then self.Gui.Enabled = state end
end

-- [IMPROVEMENT] Center the window on screen
function LucidUI.Window:Center()
    if not self.Main then return end
    self.Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    self.Main.AnchorPoint = Vector2.new(0.5, 0.5)
end

-- [IMPROVEMENT] Get/Set window size
function LucidUI.Window:GetSize()
    return self._width, self._height
end

function LucidUI.Window:SetSize(w, h)
    self._width  = math.clamp(w, self._minWidth,  self._maxWidth)
    self._height = math.clamp(h, self._minHeight, self._maxHeight)
    self._fullSize = UDim2.fromOffset(self._width, self._height)
    if not self.Minimized then
        self.Main.Size = self._fullSize
    end
end

function LucidUI.Window:SetMinimized(state)
    if state == self.Minimized then return end
    self.Minimized = state

    local collapsedHeight = 44
    local targetWidth  = state and (self._compactWidth or self._width) or self._width
    local targetHeight = state and collapsedHeight or self._height

    if state then
        if self._gearRefs then
            for _, p in ipairs(self._gearRefs.parts) do
                TweenService:Create(p, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { BackgroundTransparency = 1 }):Play()
            end
            if self._gearRefs.hole then
                TweenService:Create(self._gearRefs.hole, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { BackgroundTransparency = 1 }):Play()
            end
        end
        task.delay(0.17, function()
            if self._settingsBtn then
                self._settingsBtn.Visible = false
            end
        end)

        if self.SettingsOpen then self:ToggleSettings(false) end

        self.Content.Visible   = false
        self.Separator.Visible = false
        self.TabStrip.Visible  = false
    end

    TweenService:Create(self.Main, Ease.Out(0.30), {
        Size = UDim2.fromOffset(targetWidth, targetHeight),
    }):Play()

    if not state then
        task.delay(0.05, function()
            if self._settingsBtn then
                self._settingsBtn.Visible = true
                if self._gearRefs then
                    for _, p in ipairs(self._gearRefs.parts) do
                        p.BackgroundTransparency = 1
                        TweenService:Create(p, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                            { BackgroundTransparency = 0 }):Play()
                    end
                    if self._gearRefs.hole then
                        self._gearRefs.hole.BackgroundTransparency = 1
                        TweenService:Create(self._gearRefs.hole, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                            { BackgroundTransparency = 0 }):Play()
                    end
                end
            end
        end)

        if not self.SettingsOpen then
            task.delay(0.15, function()
                if not self.Minimized then
                    self.Content.Visible   = true
                    self.Separator.Visible = true
                    self.TabStrip.Visible  = true
                end
            end)
        end
    end

    task.delay(0.35, function() ClampPosition(self.Main) end)
end

function LucidUI.Window:SetTheme(name)
    if name == "Custom" or name == "__custom_runtime" then
        self:ApplyCustomTheme()
        return
    end
    if LucidUI.Themes[name] then
        self.Theme     = LucidUI.Themes[name]
        self.ThemeName = name
        self._customThemeActive = false
        LucidUI._lastTheme = self.Theme
        self:SetThemeObject(self.Theme)
        return
    end
    self:LoadCustomTheme(name)
end

function LucidUI.Window:SetThemeObject(t)
    if not t then return end

    TweenColor(self.Main, "BackgroundColor3", t.Background, 0.30)
    if not (self._bgImage and self._bgImage.Visible) then
        self.Main.BackgroundTransparency = t.BackgroundTrans or 0.20
    end

    TweenColor(self.TitleLabel, "TextColor3", t.TextPrimary, 0.30)
    TweenColor(self.Separator, "BackgroundColor3", t.Border, 0.30)
    TweenColor(self.SettingsPanel, "BackgroundColor3", t.Background, 0.30)

    local accent = self._accentOverride or t.Accent
    if self._pillStroke then self._pillStroke.Color = accent end

    if self.FloatingPill then
        TweenColor(self.FloatingPill, "BackgroundColor3", t.Background, 0.30)
        TweenColor(self._pillLabel, "TextColor3", t.TextPrimary, 0.30)
        TweenColor(self._pillDot, "BackgroundColor3", accent, 0.30)
    end

    if self._gearRefs then
        for _, p in ipairs(self._gearRefs.parts) do
            TweenColor(p, "BackgroundColor3", t.TextSecondary, 0.30)
        end
        TweenColor(self._gearRefs.hole, "BackgroundColor3", t.Background, 0.30)
    end

    if self._backArrowLbl then
        TweenColor(self._backArrowLbl, "TextColor3", t.TextSecondary, 0.30)
    end

    for _, g in ipairs(self._gripFrames or {}) do
        TweenColor(g, "BackgroundColor3", t.TextMuted, 0.30)
    end

    for _, tb in ipairs(self.Tabs) do
        local active = (tb == self.ActiveTab)
        local color  = active and t.TabActive or t.TabInactive
        if tb.Label then TweenColor(tb.Label, "TextColor3", color, 0.30) end
        for _, part in ipairs(tb.IconParts or {}) do
            if part:IsA("UIStroke") then
                part.Color = color
            else
                TweenColor(part, "BackgroundColor3", color, 0.30)
            end
        end
    end

    for _, fn in ipairs(self._themeElements) do
        pcall(fn, t)
    end
end

function LucidUI.Window:SetAccent(c)
    self._accentOverride = c
    self.Theme.Accent    = c

    for _, fn in ipairs(self._themeElements) do pcall(fn, self.Theme) end

    if self._pillStroke then self._pillStroke.Color = c end
    if self._pillDot    then TweenColor(self._pillDot, "BackgroundColor3", c, 0.25) end
end

function LucidUI.Window:_registerTheme(fn)
    table.insert(self._themeElements, fn)
end

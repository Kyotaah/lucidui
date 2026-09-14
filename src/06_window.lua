--[[
    Window — creates the main window and every layer that sits inside it.
]]

LucidUI.Window = {}
LucidUI.Window.__index = LucidUI.Window

local function TweenColor(inst, prop, target, time)
    local current = inst[prop]
    if typeof(current) ~= "Color3" then
        inst[prop] = target
        return
    end
    TweenService:Create(
        inst,
        TweenInfo.new(time or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { [prop] = target }
    ):Play()
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
    ApplyGlass(W.Main, W.Theme, { cornerRadius = 18 })

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

    local settingsBtn = Create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(36, 36),
        Position = UDim2.new(1, -120, 0.5, -18),
        ZIndex = 3,
        Parent = W.Header,
    })

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

    settingsBtn.MouseButton1Click:Connect(function() W:ToggleSettings() end)
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

    minBtn.MouseButton1Click:Connect(function() W:SetMinimized(not W.Minimized) end)
    minBtn.MouseEnter:Connect(function()
        Tween(minBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(255, 214, 100) }):Play()
        Tween(minDot, 0.15, { TextTransparency = 0 }):Play()
    end)
    minBtn.MouseLeave:Connect(function()
        Tween(minBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(255, 189, 46) }):Play()
        Tween(minDot, 0.15, { TextTransparency = 1 }):Play()
    end)

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

    closeBtn.MouseButton1Click:Connect(function() W:MinimizeToPill() end)
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

    local dragging, dragStart, startPos = false, nil, nil

    W.Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = W.Main.Position
        end
    end)

    table.insert(W._conns, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            W.Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end))

    table.insert(W._conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                ClampPosition(W.Main)
            end
        end
    end))

    local resizeHandle = Create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(20, 20),
        Position = UDim2.new(1, -20, 1, -20),
        ZIndex = 4,
        Parent = W.Main,
    })

    local grip1 = Create("Frame", {
        Size = UDim2.fromOffset(12, 2),
        Position = UDim2.new(1, -6, 1, -6),
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
        Position = UDim2.new(1, -6, 1, -3),
        AnchorPoint = Vector2.new(1, 0.5),
        Rotation = 45,
        BackgroundColor3 = W.Theme.TextMuted,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Parent = resizeHandle,
    })
    Corner(1, grip2)

    W._gripFrames = { grip1, grip2 }

    local resizing, rStart, rStartSize = false, nil, nil

    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            resizing   = true
            rStart     = input.Position
            rStartSize = { X = W._width, Y = W._height }
        end
    end)

    table.insert(W._conns, UserInputService.InputChanged:Connect(function(input)
        if not resizing then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - rStart
            W._width  = math.clamp(rStartSize.X + d.X, W._minWidth,  W._maxWidth)
            W._height = math.clamp(rStartSize.Y + d.Y, W._minHeight, W._maxHeight)
            W._fullSize      = UDim2.fromOffset(W._width, W._height)
            W._collapsedSize = UDim2.fromOffset(W._width, 44)
            if not W.Minimized then
                W.Main.Size    = UDim2.fromOffset(W._width, W._height)
                W.Content.Size = UDim2.new(1, -24, 1, -110)
            end
        end
    end))

    table.insert(W._conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if resizing then
                resizing = false
                ClampPosition(W.Main)
            end
        end
    end))

    table.insert(W._conns, UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            if W.Floating then
                W:RestoreFromPill()
            else
                W:SetVisible(not W.Visible)
            end
        end
    end))

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
    Corner(0, W.SettingsPanel)

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
    backBtn.MouseButton1Click:Connect(function() W:ToggleSettings(false) end)

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

    W.FloatingPill = Create("TextButton", {
        Name = "FloatingPill",
        Text = "",
        Size = UDim2.fromOffset(180, 32),
        Position = UDim2.new(0.5, 0, 0, 8),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = W.Theme.Background,
        BackgroundTransparency = W.Theme.BackgroundTrans,
        AutoButtonColor = false,
        Visible = false,
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
        Position = UDim2.fromOffset(28, 0),
        Size = UDim2.new(1, -34, 1, 0),
        Parent = W.FloatingPill,
    })

    local pillDragging, pillDragStart, pillStartPos = false, nil, nil

    W.FloatingPill.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            pillDragging  = true
            pillDragStart = input.Position
            pillStartPos  = W.FloatingPill.Position
        end
    end)

    table.insert(W._conns, UserInputService.InputChanged:Connect(function(input)
        if not pillDragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - pillDragStart
            if math.abs(d.X) > 5 or math.abs(d.Y) > 5 then
                W._pillMoved = true
            end
            W.FloatingPill.Position = UDim2.new(
                pillStartPos.X.Scale, pillStartPos.X.Offset + d.X,
                pillStartPos.Y.Scale, pillStartPos.Y.Offset + d.Y
            )
        end
    end))

    table.insert(W._conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if pillDragging then
                pillDragging = false
                ClampPosition(W.FloatingPill)
            end
        end
    end))

    W.FloatingPill.MouseButton1Click:Connect(function()
        if W._pillMoved then
            W._pillMoved = false
            return
        end
        W:RestoreFromPill()
    end)

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
        TweenService:Create(self._pillDot,    Ease.FadeIn(0.25), { BackgroundTransparency = 0 }):Play()
        TweenService:Create(self._pillLabel,  Ease.FadeIn(0.25), { TextTransparency = 0 }):Play()
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

        if self._themeSlotsRefresh      then pcall(self._themeSlotsRefresh) end
        if self._savedThemeSlotsRefresh then pcall(self._savedThemeSlotsRefresh) end
        if self._themeDropdownRefresh   then pcall(self._themeDropdownRefresh) end
    else
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

function LucidUI.Window:SetVisible(state)
    self.Visible = state
    if self.Gui then self.Gui.Enabled = state end
end

function LucidUI.Window:SetMinimized(state)
    self.Minimized = state
    local targetY = state and 44 or self._height

    TweenService:Create(self.Main, Ease.Out(0.30), {
        Size = UDim2.fromOffset(self._width, targetY),
    }):Play()

    if state then
        self.Content.Visible   = false
        self.Separator.Visible = false
        self.TabStrip.Visible  = false
        if self.SettingsOpen then self:ToggleSettings(false) end
    else
        if not self.SettingsOpen then
            self.Content.Visible   = true
            self.Separator.Visible = true
            self.TabStrip.Visible  = true
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

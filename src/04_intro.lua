--[[
    Intro — animated loading screen that plays before the main window.

    Beats:
      • Dark overlay + blur ramp in
      • Glass card scales in with Back easing
      • "L" logo bounces in, title and tagline fade up
      • Progress track and status text appear
      • 5 stages run (Loading libraries → Ready) with shimmer sweep
      • Card scales up and fades while blur clears
      • onComplete fires → main window entrance runs

    Skip: any click, tap, or keypress fires onComplete immediately.
]]

-- ============================================================
-- Show the intro overlay
-- ============================================================
function LucidUI:ShowIntro(opts)
    opts = opts or {}

    -- Kill any existing intro
    if LucidUI._activeIntro and LucidUI._activeIntro.Parent then
        LucidUI._activeIntro:Destroy()
    end

    local duration    = opts.Duration or 1.6
    local title       = opts.Title or "LucidUI"
    local subtitle    = opts.Subtitle or ("v" .. LucidUI._version)
    local tagline     = opts.Tagline or "Modern interface suite"
    local theme       = opts.Theme or LucidUI._lastTheme or LucidUI.Themes.Default
    local onComplete  = opts.OnComplete
    local skipOnInput = opts.SkipOnInput ~= false

    -- --------------------------------------------------------
    -- Root GUI
    -- --------------------------------------------------------
    local introGui = Create("ScreenGui", {
        Name = "LucidUI_Intro",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 500,
        Parent = PlayerGui,
    })
    LucidUI._activeIntro = introGui

    local overlay = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = introGui,
    })

    -- --------------------------------------------------------
    -- Post-processing
    -- --------------------------------------------------------
    local blur = Create("BlurEffect", {
        Size = 0,
        Parent = Lighting,
    })

    local colorFx = Create("ColorCorrectionEffect", {
        Brightness = 0,
        Contrast = 0,
        Saturation = 0,
        Parent = Lighting,
    })

    -- --------------------------------------------------------
    -- Accent glow (behind the card)
    -- --------------------------------------------------------
    local glow = Create("Frame", {
        Size = UDim2.fromOffset(320, 170),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = overlay,
    })
    Corner(24, glow)
    local glowStroke = Stroke(theme.Accent, 2, 1, glow)

    -- --------------------------------------------------------
    -- Glass card
    -- --------------------------------------------------------
    local card = Create("Frame", {
        Size = UDim2.fromOffset(320, 170),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = overlay,
    })
    Corner(22, card)
    local cardStroke = Stroke(theme.Border, 1, 1, card)

    Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.5, Color3.new(0.96, 0.96, 0.96)),
            ColorSequenceKeypoint.new(1,   Color3.new(0.86, 0.86, 0.86)),
        }),
        Rotation = 135,
        Parent = card,
    })

    local cardScale = Create("UIScale", {
        Scale = 0.85,
        Parent = card,
    })

    -- --------------------------------------------------------
    -- Logo
    -- --------------------------------------------------------
    local logo = Create("Frame", {
        Size = UDim2.fromOffset(46, 46),
        Position = UDim2.new(0.5, 0, 0, 22),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = theme.Accent,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Parent = card,
    })
    Corner(12, logo)
    Stroke(theme.Accent, 1.5, 0.2, logo)

    local logoLabel = Create("TextLabel", {
        Text = "L",
        Font = Enum.Font.GothamBlack,
        TextSize = 26,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        TextTransparency = 1,
        Parent = logo,
    })

    -- --------------------------------------------------------
    -- Title + tagline
    -- --------------------------------------------------------
    local titleLbl = Create("TextLabel", {
        Text = title,
        Font = Enum.Font.GothamBold,
        TextSize = 22,
        TextColor3 = theme.TextPrimary,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 76),
        Size = UDim2.new(1, 0, 0, 26),
        TextTransparency = 1,
        Parent = card,
    })

    local tagLbl = Create("TextLabel", {
        Text = tagline,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = theme.TextMuted,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 102),
        Size = UDim2.new(1, 0, 0, 16),
        TextTransparency = 1,
        Parent = card,
    })

    -- --------------------------------------------------------
    -- Progress track + fill + shimmer
    -- --------------------------------------------------------
    local track = Create("Frame", {
        Size = UDim2.new(1, -48, 0, 3),
        Position = UDim2.new(0, 24, 1, -26),
        BackgroundColor3 = theme.SliderTrack,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Parent = card,
    })
    Corner(2, track)

    local fill = Create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        Parent = track,
    })
    Corner(2, fill)

    local shimmer = Create("Frame", {
        Size = UDim2.fromOffset(40, 3),
        Position = UDim2.new(0, -40, 0, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Parent = fill,
    })
    Corner(2, shimmer)

    -- --------------------------------------------------------
    -- Status + subtitle labels
    -- --------------------------------------------------------
    local statusLbl = Create("TextLabel", {
        Text = "Loading...",
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextColor3 = theme.TextMuted,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 24, 1, -50),
        Size = UDim2.new(1, -48, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        Parent = card,
    })

    local subLbl = Create("TextLabel", {
        Text = subtitle,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextColor3 = theme.TextMuted,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 24, 1, -50),
        Size = UDim2.new(1, -48, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTransparency = 1,
        Parent = card,
    })

    -- --------------------------------------------------------
    -- Entrance animations
    -- --------------------------------------------------------
    Tween(overlay, 0.35, { BackgroundTransparency = 0.45 }):Play()
    Tween(blur, 0.40, { Size = 24 }):Play()
    Tween(colorFx, 0.40, { Saturation = -0.15 }):Play()
    Tween(cardScale, 0.50, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
    Tween(card, 0.40, { BackgroundTransparency = theme.BackgroundTrans or 0.15 }):Play()
    Tween(cardStroke, 0.40, { Transparency = 0.4 }):Play()
    Tween(logo, 0.40, { BackgroundTransparency = 0.15 }):Play()
    Tween(logoLabel, 0.50, { TextTransparency = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
    Tween(titleLbl, 0.40, { TextTransparency = 0 }):Play()
    Tween(tagLbl, 0.40, { TextTransparency = 0 }):Play()
    Tween(statusLbl, 0.40, { TextTransparency = 0 }):Play()
    Tween(subLbl, 0.40, { TextTransparency = 0 }):Play()

    -- --------------------------------------------------------
    -- Glow pulse (loops until the intro ends)
    -- --------------------------------------------------------
    Tween(glowStroke, 0.40, { Transparency = 0.7 }):Play()
    task.spawn(function()
        while introGui.Parent do
            Tween(glowStroke, 1.2, { Transparency = 0.85 }):Play()
            task.wait(1.2)
            if not introGui.Parent then break end
            Tween(glowStroke, 1.2, { Transparency = 0.7 }):Play()
            task.wait(1.2)
        end
    end)

    -- --------------------------------------------------------
    -- Shimmer sweep
    -- --------------------------------------------------------
    local shimmerConn = RunService.RenderStepped:Connect(function(dt)
        if not shimmer.Parent then
            shimmerConn:Disconnect()
            return
        end
        local p = shimmer.Position.X.Offset + dt * 260
        if p > track.AbsoluteSize.X then p = -40 end
        shimmer.Position = UDim2.new(0, p, 0, 0)
    end)

    -- --------------------------------------------------------
    -- Stage sequence
    -- --------------------------------------------------------
    local stages = {
        { pct = 0.05, text = "Loading libraries...",  wait = 0.15 },
        { pct = 0.30, text = "Initializing theme...", wait = 0.35 },
        { pct = 0.60, text = "Building interface...", wait = 0.45 },
        { pct = 0.85, text = "Optimizing layout...",  wait = 0.35 },
        { pct = 1.00, text = "Ready",                 wait = 0.30 },
    }

    local completed = false

    local function finish()
        if completed then return end
        completed = true

        if shimmerConn then shimmerConn:Disconnect() end

        Tween(card,       0.40, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In):Play()
        Tween(cardStroke, 0.40, { Transparency = 1 }):Play()
        Tween(glowStroke, 0.30, { Transparency = 1 }):Play()
        Tween(logo,       0.30, { BackgroundTransparency = 1 }):Play()
        Tween(logoLabel,  0.30, { TextTransparency = 1 }):Play()
        Tween(titleLbl,   0.30, { TextTransparency = 1 }):Play()
        Tween(tagLbl,     0.30, { TextTransparency = 1 }):Play()
        Tween(statusLbl,  0.30, { TextTransparency = 1 }):Play()
        Tween(subLbl,     0.30, { TextTransparency = 1 }):Play()
        Tween(track,      0.30, { BackgroundTransparency = 1 }):Play()
        Tween(fill,       0.30, { BackgroundTransparency = 1 }):Play()
        Tween(shimmer,    0.30, { BackgroundTransparency = 1 }):Play()
        Tween(cardScale,  0.45, { Scale = 1.08 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In):Play()
        Tween(overlay,    0.50, { BackgroundTransparency = 1 }):Play()
        Tween(blur,       0.50, { Size = 0 }):Play()
        Tween(colorFx,    0.50, { Saturation = 0 }):Play()

        task.wait(0.55)

        if blur.Parent    then blur:Destroy()    end
        if colorFx.Parent then colorFx:Destroy() end
        if introGui.Parent then introGui:Destroy() end
        if LucidUI._activeIntro == introGui then LucidUI._activeIntro = nil end

        if onComplete then pcall(onComplete) end
    end

    -- --------------------------------------------------------
    -- Skip on any input
    -- --------------------------------------------------------
    if skipOnInput then
        local skipConn
        skipConn = UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
                or input.UserInputType == Enum.UserInputType.Keyboard then
                if skipConn then skipConn:Disconnect() end
                finish()
            end
        end)
        -- Safety disconnect in case the intro finishes before any input
        task.delay(duration + 2, function()
            if skipConn then skipConn:Disconnect() end
        end)
    end

    -- --------------------------------------------------------
    -- Run stages
    -- --------------------------------------------------------
    task.spawn(function()
        for _, stage in ipairs(stages) do
            if completed then return end

            -- Fade out the current status text
            local fadeOut = Tween(statusLbl, 0.12, { TextTransparency = 1 })
            fadeOut:Play()
            fadeOut.Completed:Wait()
            if completed then return end

            -- Update text and fade back in
            statusLbl.Text = stage.text
            Tween(statusLbl, 0.12, { TextTransparency = 0 }):Play()

            -- Tween the progress fill
            local prevScale = fill.Size.X.Scale
            local t = math.max(stage.wait * ((stage.pct - prevScale) / 0.3), 0.08)
            Tween(fill, t, { Size = UDim2.new(stage.pct, 0, 1, 0) },
                Enum.EasingStyle.Quad, Enum.EasingDirection.Out):Play()

            task.wait(t)
        end

        task.wait(0.15)
        finish()
    end)

    return introGui
end

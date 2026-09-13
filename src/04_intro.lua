--[[
    Intro — premium animated loading screen with task support.

    Supports two modes:
      1. Default  — 5 fixed stages, timing scales to Duration
      2. Custom   — pass opts.Stages = { { text, pct, task?, wait? }, ... }
                    Each stage runs sequentially. task functions can yield
                    and receive a report(subProgress) callback to advance
                    the bar mid-stage (perfect for download progress).

    Visuals:
      • Rotating gradient border on the glass card
      • Pulsing ambient glow behind the card
      • Geometric logo with an orbiting dot and breathing pulse
      • Version chip pill under the title
      • Stage dots that fill in one by one
      • Progress bar with a clipped shimmer that stays inside the fill
      • Expanding ring + particle burst on completion
      • Staggered entrance for every element
      • Skippable at any moment via click, tap, or keypress
]]

function LucidUI:ShowIntro(opts)
    opts = opts or {}

    -- Kill any existing intro
    if LucidUI._activeIntro and LucidUI._activeIntro.Parent then
        LucidUI._activeIntro:Destroy()
    end

    local duration     = opts.Duration or 2.8
    local customStages = opts.Stages
    local title        = opts.Title or "LucidUI"
    local subtitle     = opts.Subtitle or ("v" .. LucidUI._version)
    local tagline      = opts.Tagline or "Modern interface suite"
    local theme        = opts.Theme or LucidUI._lastTheme or LucidUI.Themes.Default
    local onComplete   = opts.OnComplete
    local skipOnInput  = opts.SkipOnInput ~= false

    local accent = theme.Accent
    local bg     = theme.Background
    local text   = theme.TextPrimary
    local muted  = theme.TextMuted

    -- --------------------------------------------------------
    -- Stage list (default vs. custom)
    -- --------------------------------------------------------
    local stages
    if customStages and #customStages > 0 then
        stages = {}
        for _, s in ipairs(customStages) do
            table.insert(stages, {
                text = s.text or "Loading...",
                pct  = s.pct or 1,
                task = s.task,
                wait = s.wait,
            })
        end
    else
        -- Default 5-stage sequence
        local defaultTexts = {
            "Loading modules...",
            "Initializing theme...",
            "Building interface...",
            "Optimizing layout...",
            "Ready",
        }
        local defaultPcts = { 0.15, 0.38, 0.62, 0.85, 1.00 }
        local perStage = duration / #defaultTexts
        stages = {}
        for i = 1, #defaultTexts do
            table.insert(stages, {
                text = defaultTexts[i],
                pct  = defaultPcts[i],
                wait = perStage,
            })
        end
    end

    local DOT_COUNT = #stages

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
    local blur = Create("BlurEffect", { Size = 0, Parent = Lighting })
    local colorFx = Create("ColorCorrectionEffect", {
        Brightness = -0.05, Contrast = 0.05, Saturation = -0.25,
        Parent = Lighting,
    })

    -- --------------------------------------------------------
    -- Ambient glow
    -- --------------------------------------------------------
    local ambientWrap = Create("Frame", {
        Size = UDim2.fromOffset(520, 520),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 0,
        Parent = overlay,
    })
    local ambientCircle = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = ambientWrap,
    })
    Corner(999, ambientCircle)

    -- --------------------------------------------------------
    -- Card
    -- --------------------------------------------------------
    local CARD_W, CARD_H = 400, 240
    local card = Create("Frame", {
        Size = UDim2.fromOffset(CARD_W, CARD_H),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = bg,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = overlay,
    })
    Corner(24, card)
    Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.5, Color3.new(0.97, 0.97, 0.97)),
            ColorSequenceKeypoint.new(1, Color3.new(0.9, 0.9, 0.9)),
        }),
        Rotation = 135,
        Parent = card,
    })

    local cardStroke = Stroke(theme.Border, 1.5, 1, card)
    local strokeGrad = Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme.Border),
            ColorSequenceKeypoint.new(0.35, accent),
            ColorSequenceKeypoint.new(0.65, accent),
            ColorSequenceKeypoint.new(1, theme.Border),
        }),
        Rotation = 0,
        Parent = cardStroke,
    })

    local cardScale = Create("UIScale", { Scale = 0.88, Parent = card })

    -- --------------------------------------------------------
    -- Logo + orbit
    -- --------------------------------------------------------
    local LOGO_SIZE = 60
    local logoHolder = Create("Frame", {
        Size = UDim2.fromOffset(LOGO_SIZE, LOGO_SIZE),
        Position = UDim2.new(0.5, 0, 0, 26),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        ZIndex = 6,
        Parent = card,
    })

    local logo = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = accent,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = logoHolder,
    })
    Corner(999, logo)
    Stroke(accent, 2, 0.2, logo)

    local logoLabel = Create("TextLabel", {
        Text = "L",
        Font = Enum.Font.GothamBlack,
        TextSize = 32,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        TextTransparency = 1,
        ZIndex = 7,
        Parent = logo,
    })

    local ORBIT_SIZE = LOGO_SIZE + 16
    local orbitHolder = Create("Frame", {
        Size = UDim2.fromOffset(ORBIT_SIZE, ORBIT_SIZE),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 7,
        Parent = logoHolder,
    })
    local orbitDot = Create("Frame", {
        Size = UDim2.fromOffset(6, 6),
        Position = UDim2.new(0.5, 0, 0, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ZIndex = 7,
        Parent = orbitHolder,
    })
    Corner(3, orbitDot)

    -- --------------------------------------------------------
    -- Title + version chip + tagline
    -- --------------------------------------------------------
    local titleLbl = Create("TextLabel", {
        Text = title,
        Font = Enum.Font.GothamBold,
        TextSize = 24,
        TextColor3 = text,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 100),
        Size = UDim2.new(1, 0, 0, 30),
        TextTransparency = 1,
        ZIndex = 6,
        Parent = card,
    })

    local chipHolder = Create("Frame", {
        Size = UDim2.fromOffset(74, 20),
        Position = UDim2.new(0.5, 0, 0, 132),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        ZIndex = 6,
        Parent = card,
    })
    local chip = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = chipHolder,
    })
    Corner(10, chip)
    local chipStroke = Stroke(accent, 1, 1, chip)
    local chipLabel = Create("TextLabel", {
        Text = subtitle,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = accent,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        TextTransparency = 1,
        ZIndex = 7,
        Parent = chip,
    })

    local tagLbl = Create("TextLabel", {
        Text = tagline,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = muted,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 158),
        Size = UDim2.new(1, 0, 0, 16),
        TextTransparency = 1,
        ZIndex = 6,
        Parent = card,
    })

    -- --------------------------------------------------------
    -- Stage dots (dynamic based on #stages)
    -- --------------------------------------------------------
    local DOT_SIZE = 8
    local DOT_GAP  = 10
    local dotsRowWidth = (DOT_COUNT * DOT_SIZE) + ((DOT_COUNT - 1) * DOT_GAP)
    local dotsRow = Create("Frame", {
        Size = UDim2.fromOffset(dotsRowWidth, DOT_SIZE),
        Position = UDim2.new(0.5, 0, 0, 182),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        ZIndex = 6,
        Parent = card,
    })
    local stageDots = {}
    for i = 1, DOT_COUNT do
        local dot = Create("Frame", {
            Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE),
            Position = UDim2.fromOffset((i - 1) * (DOT_SIZE + DOT_GAP), 0),
            BackgroundColor3 = muted,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 6,
            Parent = dotsRow,
        })
        Corner(999, dot)
        stageDots[i] = dot
    end

    -- --------------------------------------------------------
    -- Progress bar
    -- --------------------------------------------------------
    local track = Create("Frame", {
        Size = UDim2.new(1, -56, 0, 6),
        Position = UDim2.new(0, 28, 1, -32),
        BackgroundColor3 = theme.SliderTrack,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        ZIndex = 6,
        Parent = card,
    })
    Corner(999, track)

    local fill = Create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        ClipsDescendants = true,   -- clip shimmer to the fill bounds
        ZIndex = 7,
        Parent = track,
    })
    Corner(999, fill)
    Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, accent),
            ColorSequenceKeypoint.new(1, Color3.new(
                math.min(accent.R * 1.4, 1),
                math.min(accent.G * 1.4, 1),
                math.min(accent.B * 1.4, 1)
            )),
        }),
        Parent = fill,
    })

    local fillGlow = Stroke(accent, 3, 1, fill)

    -- Shimmer is a child of fill, clipped to fill bounds
    local shimmer = Create("Frame", {
        Size = UDim2.fromOffset(60, 6),
        Position = UDim2.new(0, -60, 0, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        ZIndex = 8,
        Parent = fill,
    })
    Corner(999, shimmer)

    -- --------------------------------------------------------
    -- Status text
    -- --------------------------------------------------------
    local statusLbl = Create("TextLabel", {
        Text = stages[1] and stages[1].text or "Preparing...",
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = muted,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 28, 1, -52),
        Size = UDim2.new(1, -56, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 6,
        Parent = card,
    })

    local rightLbl = Create("TextLabel", {
        Text = "0%",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = accent,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 28, 1, -52),
        Size = UDim2.new(1, -56, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTransparency = 1,
        ZIndex = 6,
        Parent = card,
    })

    -- --------------------------------------------------------
    -- Entrance
    -- --------------------------------------------------------
    Tween(overlay, 0.40, { BackgroundTransparency = 0.35 }):Play()
    Tween(blur, 0.55, { Size = 28 }):Play()
    Tween(colorFx, 0.55, { Saturation = -0.25 }):Play()
    Tween(ambientCircle, 0.60, { BackgroundTransparency = 0.88 }):Play()
    Tween(cardScale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
    Tween(card, 0.50, { BackgroundTransparency = theme.BackgroundTrans or 0.15 }):Play()
    Tween(cardStroke, 0.50, { Transparency = 0.35 }):Play()
    Tween(logoLabel, 0.50, { TextTransparency = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
    Tween(orbitDot, 0.50, { BackgroundTransparency = 0 }):Play()

    task.delay(0.25, function() Tween(titleLbl, 0.40, { TextTransparency = 0 }):Play() end)
    task.delay(0.35, function()
        Tween(chip, 0.30, { BackgroundTransparency = 0.85 }):Play()
        Tween(chipStroke, 0.30, { Transparency = 0.40 }):Play()
        Tween(chipLabel, 0.30, { TextTransparency = 0 }):Play()
    end)
    task.delay(0.45, function() Tween(tagLbl, 0.40, { TextTransparency = 0 }):Play() end)
    task.delay(0.55, function()
        for _, d in ipairs(stageDots) do
            Tween(d, 0.30, { BackgroundTransparency = 0.55 }):Play()
        end
        Tween(track, 0.35, { BackgroundTransparency = 0.4 }):Play()
        Tween(statusLbl, 0.30, { TextTransparency = 0 }):Play()
        Tween(rightLbl, 0.30, { TextTransparency = 0 }):Play()
    end)

    -- --------------------------------------------------------
    -- Continuous animations
    -- --------------------------------------------------------
    local animStart = tick()
    local animConn = RunService.RenderStepped:Connect(function()
        if not introGui.Parent then animConn:Disconnect() return end
        local t = tick() - animStart

        if strokeGrad and strokeGrad.Parent then
            strokeGrad.Rotation = (t * 60) % 360
        end
        if orbitHolder and orbitHolder.Parent then
            orbitHolder.Rotation = (t * 90) % 360
        end
        if ambientCircle and ambientCircle.Parent then
            ambientCircle.BackgroundTransparency = 0.86 + 0.04 * math.sin(t * 2)
        end
        if logo and logo.Parent then
            logo.BackgroundTransparency = 0.15 + 0.05 * math.sin(t * 3)
        end
    end)

    -- --------------------------------------------------------
    -- Shimmer sweep (clipped to fill bounds, wraps on fill width)
    -- --------------------------------------------------------
    local shimmerConn = RunService.RenderStepped:Connect(function(dt)
        if not shimmer.Parent then shimmerConn:Disconnect() return end

        local fillW = fill.AbsoluteSize.X
        if fillW < 70 then
            shimmer.Visible = false
            shimmer.Position = UDim2.new(0, -60, 0, 0)
            return
        end

        shimmer.Visible = true
        local p = shimmer.Position.X.Offset + dt * 260
        if p > fillW then p = -60 end
        shimmer.Position = UDim2.new(0, p, 0, 0)
    end)

    -- --------------------------------------------------------
    -- Completion flourish
    -- --------------------------------------------------------
    local function burstParticles()
        for i = 1, 14 do
            local angle = (i / 14) * math.pi * 2
            local dx = math.cos(angle) * 120
            local dy = math.sin(angle) * 120
            local dot = Create("Frame", {
                Size = UDim2.fromOffset(5, 5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = accent,
                BorderSizePixel = 0,
                ZIndex = 10,
                Parent = overlay,
            })
            Corner(999, dot)
            Tween(dot, 0.7, {
                Position = UDim2.new(0.5, dx, 0.5, dy),
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(2, 2),
            }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out):Play()
            task.delay(0.8, function() pcall(function() dot:Destroy() end) end)
        end
    end

    local function expandRing()
        local ring = Create("Frame", {
            Size = UDim2.fromOffset(60, 60),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 10,
            Parent = overlay,
        })
        Corner(999, ring)
        local ringStroke = Stroke(accent, 3, 0, ring)
        Tween(ring, 0.7, {
            Size = UDim2.fromOffset(420, 420),
        }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out):Play()
        Tween(ringStroke, 0.7, {
            Transparency = 1,
            Thickness = 1,
        }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out):Play()
        task.delay(0.8, function() pcall(function() ring:Destroy() end) end)
    end

    -- --------------------------------------------------------
    -- Finish
    -- --------------------------------------------------------
    local completed = false
    local function finish()
        if completed then return end
        completed = true

        if animConn then animConn:Disconnect() end
        if shimmerConn then shimmerConn:Disconnect() end

        expandRing()
        burstParticles()

        Tween(card, 0.5, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In):Play()
        Tween(cardStroke, 0.5, { Transparency = 1 }):Play()
        Tween(logo, 0.4, { BackgroundTransparency = 1 }):Play()
        Tween(logoLabel, 0.35, { TextTransparency = 1 }):Play()
        Tween(orbitDot, 0.3, { BackgroundTransparency = 1 }):Play()
        Tween(titleLbl, 0.35, { TextTransparency = 1 }):Play()
        Tween(chip, 0.3, { BackgroundTransparency = 1 }):Play()
        Tween(chipStroke, 0.3, { Transparency = 1 }):Play()
        Tween(chipLabel, 0.3, { TextTransparency = 1 }):Play()
        Tween(tagLbl, 0.35, { TextTransparency = 1 }):Play()
        Tween(track, 0.35, { BackgroundTransparency = 1 }):Play()
        Tween(fill, 0.35, { BackgroundTransparency = 1 }):Play()
        Tween(fillGlow, 0.35, { Transparency = 1 }):Play()
        Tween(shimmer, 0.35, { BackgroundTransparency = 1 }):Play()
        Tween(statusLbl, 0.3, { TextTransparency = 1 }):Play()
        Tween(rightLbl, 0.3, { TextTransparency = 1 }):Play()
        for _, d in ipairs(stageDots) do
            Tween(d, 0.3, { BackgroundTransparency = 1 }):Play()
        end
        Tween(cardScale, 0.55, { Scale = 1.06 }, Enum.EasingStyle.Quart, Enum.EasingDirection.In):Play()
        Tween(overlay, 0.65, { BackgroundTransparency = 1 }):Play()
        Tween(ambientCircle, 0.5, { BackgroundTransparency = 1 }):Play()
        Tween(blur, 0.65, { Size = 0 }):Play()
        Tween(colorFx, 0.65, { Saturation = 0, Brightness = 0, Contrast = 0 }):Play()

        task.wait(0.7)

        if blur.Parent then blur:Destroy() end
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
        task.delay(duration + 5, function()
            if skipConn then skipConn:Disconnect() end
        end)
    end

    -- --------------------------------------------------------
    -- Run stages
    -- --------------------------------------------------------
    task.spawn(function()
        local prevPct = 0

        for index, stage in ipairs(stages) do
            if completed then return end

            -- Update text
            statusLbl.Text = stage.text
            rightLbl.Text = string.format("%d%%", math.floor(stage.pct * 100))

            -- Fill this stage's dot
            local dot = stageDots[index]
            if dot then
                Tween(dot, 0.25, { BackgroundColor3 = accent, BackgroundTransparency = 0 }):Play()
            end

            -- If the stage has a task, run it and let it report progress
            if stage.task then
                local startPct = prevPct
                local targetPct = stage.pct

                local function report(subProgress)
                    subProgress = math.clamp(subProgress or 0, 0, 1)
                    local pct = startPct + (targetPct - startPct) * subProgress
                    fill.Size = UDim2.new(pct, 0, 1, 0)
                    rightLbl.Text = string.format("%d%%", math.floor(pct * 100))
                end

                local ok, err = pcall(stage.task, report)
                if not ok then
                    warn("[LucidUI] Intro stage task failed:", err)
                end

                -- Snap to final pct for this stage
                Tween(fill, 0.18, {
                    Size = UDim2.new(targetPct, 0, 1, 0),
                }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
                rightLbl.Text = string.format("%d%%", math.floor(targetPct * 100))
                task.wait(0.15)

            else
                -- No task: just tween over the stage wait time
                local waitTime = stage.wait or 0.35
                local startPct = prevPct
                local targetPct = stage.pct

                Tween(fill, waitTime, {
                    Size = UDim2.new(targetPct, 0, 1, 0),
                }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
                Tween(fillGlow, waitTime, { Transparency = 0.35 }):Play()

                local elapsed = 0
                local step = 0.05
                while elapsed < waitTime do
                    if completed then return end
                    local sub = elapsed / waitTime
                    local pct = startPct + (targetPct - startPct) * sub
                    rightLbl.Text = string.format("%d%%", math.floor(pct * 100))
                    task.wait(step)
                    elapsed = elapsed + step
                end
            end

            prevPct = stage.pct
        end

        task.wait(0.25)
        finish()
    end)

    return introGui
end    -- --------------------------------------------------------
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
    local blur = Create("BlurEffect", { Size = 0, Parent = Lighting })
    local colorFx = Create("ColorCorrectionEffect", {
        Brightness = -0.05, Contrast = 0.05, Saturation = -0.25,
        Parent = Lighting,
    })

    -- --------------------------------------------------------
    -- Ambient glow (a wide circle behind the card that pulses)
    -- --------------------------------------------------------
    local ambientWrap = Create("Frame", {
        Size = UDim2.fromOffset(520, 520),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 0,
        Parent = overlay,
    })
    local ambientCircle = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = ambientWrap,
    })
    Corner(999, ambientCircle)

    -- --------------------------------------------------------
    -- Card
    -- --------------------------------------------------------
    local CARD_W, CARD_H = 400, 240
    local card = Create("Frame", {
        Size = UDim2.fromOffset(CARD_W, CARD_H),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = bg,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = overlay,
    })
    Corner(24, card)
    Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.5, Color3.new(0.97, 0.97, 0.97)),
            ColorSequenceKeypoint.new(1, Color3.new(0.9, 0.9, 0.9)),
        }),
        Rotation = 135,
        Parent = card,
    })

    local cardStroke = Stroke(theme.Border, 1.5, 1, card)

    -- Rotating accent gradient on the stroke
    local strokeGrad = Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme.Border),
            ColorSequenceKeypoint.new(0.35, accent),
            ColorSequenceKeypoint.new(0.65, accent),
            ColorSequenceKeypoint.new(1, theme.Border),
        }),
        Rotation = 0,
        Parent = cardStroke,
    })

    -- Card scale
    local cardScale = Create("UIScale", { Scale = 0.88, Parent = card })

    -- --------------------------------------------------------
    -- Logo (circle + orbiting dot + breathing pulse)
    -- --------------------------------------------------------
    local LOGO_SIZE = 60
    local logoHolder = Create("Frame", {
        Size = UDim2.fromOffset(LOGO_SIZE, LOGO_SIZE),
        Position = UDim2.new(0.5, 0, 0, 26),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        ZIndex = 6,
        Parent = card,
    })

    local logo = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = accent,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = logoHolder,
    })
    Corner(999, logo)
    Stroke(accent, 2, 0.2, logo)

    local logoLabel = Create("TextLabel", {
        Text = "L",
        Font = Enum.Font.GothamBlack,
        TextSize = 32,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        TextTransparency = 1,
        ZIndex = 7,
        Parent = logo,
    })

    -- Orbit ring (rotates; contains an off-center dot)
    local ORBIT_SIZE = LOGO_SIZE + 16
    local orbitHolder = Create("Frame", {
        Size = UDim2.fromOffset(ORBIT_SIZE, ORBIT_SIZE),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 7,
        Parent = logoHolder,
    })
    local orbitDot = Create("Frame", {
        Size = UDim2.fromOffset(6, 6),
        Position = UDim2.new(0.5, 0, 0, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ZIndex = 7,
        Parent = orbitHolder,
    })
    Corner(3, orbitDot)

    -- --------------------------------------------------------
    -- Title + version chip + tagline
    -- --------------------------------------------------------
    local titleLbl = Create("TextLabel", {
        Text = title,
        Font = Enum.Font.GothamBold,
        TextSize = 24,
        TextColor3 = text,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 100),
        Size = UDim2.new(1, 0, 0, 30),
        TextTransparency = 1,
        ZIndex = 6,
        Parent = card,
    })

    -- Version chip
    local chipHolder = Create("Frame", {
        Size = UDim2.fromOffset(74, 20),
        Position = UDim2.new(0.5, 0, 0, 132),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        ZIndex = 6,
        Parent = card,
    })
    local chip = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = chipHolder,
    })
    Corner(10, chip)
    local chipStroke = Stroke(accent, 1, 1, chip)
    local chipLabel = Create("TextLabel", {
        Text = subtitle,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = accent,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        TextTransparency = 1,
        ZIndex = 7,
        Parent = chip,
    })

    local tagLbl = Create("TextLabel", {
        Text = tagline,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = muted,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 158),
        Size = UDim2.new(1, 0, 0, 16),
        TextTransparency = 1,
        ZIndex = 6,
        Parent = card,
    })

    -- --------------------------------------------------------
    -- Stage dots
    -- --------------------------------------------------------
    local DOT_COUNT = 5
    local DOT_SIZE  = 8
    local DOT_GAP   = 10
    local dotsRow = Create("Frame", {
        Size = UDim2.fromOffset((DOT_COUNT * DOT_SIZE) + ((DOT_COUNT - 1) * DOT_GAP), DOT_SIZE),
        Position = UDim2.new(0.5, 0, 0, 184),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        ZIndex = 6,
        Parent = card,
    })
    local stageDots = {}
    for i = 1, DOT_COUNT do
        local dot = Create("Frame", {
            Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE),
            Position = UDim2.fromOffset((i - 1) * (DOT_SIZE + DOT_GAP), 0),
            BackgroundColor3 = muted,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 6,
            Parent = dotsRow,
        })
        Corner(999, dot)
        stageDots[i] = dot
    end

    -- --------------------------------------------------------
    -- Progress bar
    -- --------------------------------------------------------
    local track = Create("Frame", {
        Size = UDim2.new(1, -56, 0, 6),
        Position = UDim2.new(0, 28, 1, -32),
        BackgroundColor3 = theme.SliderTrack,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = card,
    })
    Corner(999, track)

    local fill = Create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        ZIndex = 7,
        Parent = track,
    })
    Corner(999, fill)
    local fillGrad = Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, accent),
            ColorSequenceKeypoint.new(1, Color3.new(
                math.min(accent.R * 1.4, 1),
                math.min(accent.G * 1.4, 1),
                math.min(accent.B * 1.4, 1)
            )),
        }),
        Parent = fill,
    })

    local fillGlow = Stroke(accent, 3, 0.6, fill)

    local shimmer = Create("Frame", {
        Size = UDim2.fromOffset(60, 6),
        Position = UDim2.new(0, -60, 0, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        ZIndex = 8,
        Parent = fill,
    })
    Corner(999, shimmer)

    -- --------------------------------------------------------
    -- Status text
    -- --------------------------------------------------------
    local statusLbl = Create("TextLabel", {
        Text = "Preparing...",
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = muted,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 28, 1, -52),
        Size = UDim2.new(1, -56, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        ZIndex = 6,
        Parent = card,
    })

    local rightLbl = Create("TextLabel", {
        Text = "0%",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = accent,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 28, 1, -52),
        Size = UDim2.new(1, -56, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTransparency = 1,
        ZIndex = 6,
        Parent = card,
    })

    -- --------------------------------------------------------
    -- Entrance
    -- --------------------------------------------------------
    Tween(overlay, 0.40, { BackgroundTransparency = 0.35 }):Play()
    Tween(blur, 0.55, { Size = 28 }):Play()
    Tween(colorFx, 0.55, { Saturation = -0.25 }):Play()

    -- Ambient glow fade in
    Tween(ambientCircle, 0.6, { BackgroundTransparency = 0.88 }):Play()

    -- Card: scale in + fade in
    Tween(cardScale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
    Tween(card, 0.5, { BackgroundTransparency = theme.BackgroundTrans or 0.15 }):Play()
    Tween(cardStroke, 0.5, { Transparency = 0.35 }):Play()

    -- Logo reveal
    Tween(logoLabel, 0.5, { TextTransparency = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
    Tween(orbitDot, 0.5, { BackgroundTransparency = 0 }):Play()

    -- Title, chip, tagline (staggered)
    task.delay(0.25, function()
        Tween(titleLbl, 0.4, { TextTransparency = 0 }):Play()
    end)
    task.delay(0.35, function()
        Tween(chip, 0.3, { BackgroundTransparency = 0.85 }):Play()
        Tween(chipStroke, 0.3, { Transparency = 0.4 }):Play()
        Tween(chipLabel, 0.3, { TextTransparency = 0 }):Play()
    end)
    task.delay(0.45, function()
        Tween(tagLbl, 0.4, { TextTransparency = 0 }):Play()
    end)
    task.delay(0.55, function()
        for _, d in ipairs(stageDots) do
            Tween(d, 0.3, { BackgroundTransparency = 0.55 }):Play()
        end
        Tween(track, 0.35, { BackgroundTransparency = 0.4 }):Play()
        Tween(statusLbl, 0.3, { TextTransparency = 0 }):Play()
        Tween(rightLbl, 0.3, { TextTransparency = 0 }):Play()
    end)

    -- --------------------------------------------------------
    -- Continuous animations (rotating stroke + orbiting dot + pulse)
    -- --------------------------------------------------------
    local animStart = tick()
    local animConn = RunService.RenderStepped:Connect(function()
        if not introGui.Parent then
            animConn:Disconnect()
            return
        end
        local t = tick() - animStart

        -- Rotating gradient border
        if strokeGrad and strokeGrad.Parent then
            strokeGrad.Rotation = (t * 60) % 360
        end

        -- Orbiting dot
        if orbitHolder and orbitHolder.Parent then
            orbitHolder.Rotation = (t * 90) % 360
        end

        -- Breathing pulse on the ambient glow
        if ambientCircle and ambientCircle.Parent then
            local pulse = 0.86 + 0.04 * math.sin(t * 2)
            ambientCircle.BackgroundTransparency = pulse
        end

        -- Breathing pulse on the logo
        if logo and logo.Parent then
            local s = 1 + 0.03 * math.sin(t * 3)
            -- keep it as just a background transparency pulse to avoid layout thrash
            logo.BackgroundTransparency = 0.15 + 0.05 * math.sin(t * 3)
        end
    end)

    -- --------------------------------------------------------
    -- Shimmer sweep on the progress bar
    -- --------------------------------------------------------
    local shimmerConn = RunService.RenderStepped:Connect(function(dt)
        if not shimmer.Parent then
            shimmerConn:Disconnect()
            return
        end
        local p = shimmer.Position.X.Offset + dt * 320
        local w = track.AbsoluteSize.X
        if p > w then p = -60 end
        shimmer.Position = UDim2.new(0, p, 0, 0)
    end)

    -- --------------------------------------------------------
    -- Completion flourish
    -- --------------------------------------------------------
    local function burstParticles()
        for i = 1, 14 do
            local angle = (i / 14) * math.pi * 2
            local dx = math.cos(angle) * 120
            local dy = math.sin(angle) * 120

            local dot = Create("Frame", {
                Size = UDim2.fromOffset(5, 5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = accent,
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                ZIndex = 10,
                Parent = overlay,
            })
            Corner(999, dot)

            Tween(dot, 0.7, {
                Position = UDim2.new(0.5, dx, 0.5, dy),
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(2, 2),
            }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out):Play()

            task.delay(0.8, function()
                pcall(function() dot:Destroy() end)
            end)
        end
    end

    local function expandRing()
        local ring = Create("Frame", {
            Size = UDim2.fromOffset(60, 60),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 10,
            Parent = overlay,
        })
        Corner(999, ring)
        local ringStroke = Stroke(accent, 3, 0, ring)

        Tween(ring, 0.7, {
            Size = UDim2.fromOffset(420, 420),
        }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out):Play()
        Tween(ringStroke, 0.7, {
            Transparency = 1,
            Thickness = 1,
        }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out):Play()

        task.delay(0.8, function()
            pcall(function() ring:Destroy() end)
        end)
    end

    -- --------------------------------------------------------
    -- Stage sequence
    -- --------------------------------------------------------
    local stages = {
        { pct = 0.12, text = "Loading modules...",     wait = 0.28 },
        { pct = 0.34, text = "Initializing theme...",  wait = 0.30 },
        { pct = 0.58, text = "Building interface...",  wait = 0.32 },
        { pct = 0.82, text = "Optimizing layout...",   wait = 0.30 },
        { pct = 1.00, text = "Ready",                  wait = 0.28 },
    }

    -- Scale stage timings to fit Duration
    local totalStage = 0
    for _, s in ipairs(stages) do totalStage = totalStage + s.wait end
    local scaleFactor = math.max(duration / totalStage, 0.35)

    local completed = false

    local function finish()
        if completed then return end
        completed = true

        if animConn then animConn:Disconnect() end
        if shimmerConn then shimmerConn:Disconnect() end

        -- Celebration
        expandRing()
        burstParticles()

        -- Fade everything out (slight stagger)
        Tween(card, 0.5, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In):Play()
        Tween(cardStroke, 0.5, { Transparency = 1 }):Play()
        Tween(logo, 0.4, { BackgroundTransparency = 1 }):Play()
        Tween(logoLabel, 0.35, { TextTransparency = 1 }):Play()
        Tween(orbitDot, 0.3, { BackgroundTransparency = 1 }):Play()
        Tween(titleLbl, 0.35, { TextTransparency = 1 }):Play()
        Tween(chip, 0.3, { BackgroundTransparency = 1 }):Play()
        Tween(chipStroke, 0.3, { Transparency = 1 }):Play()
        Tween(chipLabel, 0.3, { TextTransparency = 1 }):Play()
        Tween(tagLbl, 0.35, { TextTransparency = 1 }):Play()
        Tween(track, 0.35, { BackgroundTransparency = 1 }):Play()
        Tween(fill, 0.35, { BackgroundTransparency = 1 }):Play()
        Tween(fillGlow, 0.35, { Transparency = 1 }):Play()
        Tween(shimmer, 0.35, { BackgroundTransparency = 1 }):Play()
        Tween(statusLbl, 0.3, { TextTransparency = 1 }):Play()
        Tween(rightLbl, 0.3, { TextTransparency = 1 }):Play()
        for _, d in ipairs(stageDots) do
            Tween(d, 0.3, { BackgroundTransparency = 1 }):Play()
        end

        Tween(cardScale, 0.55, { Scale = 1.06 }, Enum.EasingStyle.Quart, Enum.EasingDirection.In):Play()
        Tween(overlay, 0.65, { BackgroundTransparency = 1 }):Play()
        Tween(ambientCircle, 0.5, { BackgroundTransparency = 1 }):Play()
        Tween(blur, 0.65, { Size = 0 }):Play()
        Tween(colorFx, 0.65, { Saturation = 0, Brightness = 0, Contrast = 0 }):Play()

        task.wait(0.7)

        if blur.Parent then blur:Destroy() end
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
        task.delay(duration + 3, function()
            if skipConn then skipConn:Disconnect() end
        end)
    end

    -- --------------------------------------------------------
    -- Run stages
    -- --------------------------------------------------------
    task.spawn(function()
        for index, stage in ipairs(stages) do
            if completed then return end

            -- Micro-fade the status text
            local fadeOut = Tween(statusLbl, 0.12, { TextTransparency = 1 })
            fadeOut:Play()
            fadeOut.Completed:Wait()
            if completed then return end

            statusLbl.Text = stage.text
            rightLbl.Text = string.format("%d%%", math.floor(stage.pct * 100))
            Tween(statusLbl, 0.12, { TextTransparency = 0 }):Play()

            -- Fill the dot for this stage
            local dot = stageDots[index]
            if dot then
                Tween(dot, 0.25, { BackgroundColor3 = accent, BackgroundTransparency = 0 }):Play()
            end

            -- Tween the progress fill
            local prevScale = fill.Size.X.Scale
            local t = math.max(stage.wait * scaleFactor * ((stage.pct - prevScale) / 0.34), 0.1)
            Tween(fill, t, {
                Size = UDim2.new(stage.pct, 0, 1, 0),
            }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
            Tween(fillGlow, t, { Transparency = 0.3 }):Play()

            task.wait(t)
        end

        -- All dots filled + progress complete → brief pause, then finish
        task.wait(0.25)
        finish()
    end)

    return introGui
end

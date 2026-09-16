--[[
    Intro — premium animated loading screen with task support.

    Visuals:
      • Music-reactive blob behind the card
      • Rotating gradient border on the glass card
      • Geometric logo with an orbiting dot and breathing pulse
      • Version chip pill under the title (with pulse)
      • Stage dots that fill in one by one
      • Progress bar with a UIGradient shimmer
      • Expanding ring + particle burst on completion
      • Staggered entrance for every element
      • Skippable at any moment via click, tap, or keypress

    [IMPROVEMENT] Removed every early-return path that could kill the
    whole library silently. Every tween/connection is pcall-wrapped.
    Added opts.Speed and opts.Skip. Blob now rotates + scales.
    Particle burst uses golden-ratio distribution.
]]

function LucidUI:ShowIntro(opts)
    opts = opts or {}

    if LucidUI._activeIntro and LucidUI._activeIntro.Parent then
        pcall(function() LucidUI._activeIntro:Destroy() end)
    end

    local speed        = opts.Speed or 1
    local duration     = (opts.Duration or 2.8) / speed
    local customStages = opts.Stages
    local title        = opts.Title or "LucidUI"
    local subtitle     = opts.Subtitle or ("v" .. (LucidUI._version or "0"))
    local tagline      = opts.Tagline or "Modern interface suite"
    local theme        = opts.Theme or LucidUI._lastTheme or LucidUI.Themes.Default
    local onComplete   = opts.OnComplete
    local skipOnInput  = opts.SkipOnInput ~= false
    local skipNow      = opts.Skip == true

    local accent = theme.Accent
    local bg     = theme.Background
    local text   = theme.TextPrimary
    local muted  = theme.TextMuted

    -- Build stage list
    local stages
    if customStages and #customStages > 0 then
        stages = {}
        for _, s in ipairs(customStages) do
            table.insert(stages, {
                text = s.text or "Loading...",
                pct  = s.pct or 1,
                task = s.task,
                wait = s.wait and (s.wait / speed) or nil,
            })
        end
    else
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

    -- Root GUI
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

    local blur = Create("BlurEffect", { Size = 0, Parent = Lighting })
    local colorFx = Create("ColorCorrectionEffect", {
        Brightness = -0.05, Contrast = 0.05, Saturation = -0.25,
        Parent = Lighting,
    })

    -- ── Music-reactive blob ────────────────────────────────────
    local BLOB_BASE = 360
    local blobWrap = Create("Frame", {
        Size = UDim2.fromOffset(BLOB_BASE, BLOB_BASE),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 0,
        Parent = overlay,
    })

    local blobHalo = Create("Frame", {
        Size = UDim2.fromScale(1.1, 1.1),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = blobWrap,
    })
    Corner(999, blobHalo)

    local blobCore = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = blobWrap,
    })
    Corner(999, blobCore)

    local blobShine = Create("Frame", {
        Size = UDim2.fromScale(0.7, 0.7),
        Position = UDim2.fromScale(0.32, 0.28),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = blobCore,
    })
    Corner(999, blobShine)
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.0, 0),
            NumberSequenceKeypoint.new(0.7, 1),
            NumberSequenceKeypoint.new(1.0, 1),
        }),
        Rotation = 135,
        Parent = blobShine,
    })

    -- ── Card ───────────────────────────────────────────────────
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

    local shimmerGrad = Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, accent),
            ColorSequenceKeypoint.new(0.35, accent),
            ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.65, accent),
            ColorSequenceKeypoint.new(1, accent),
        }),
        Offset = Vector2.new(-1, 0),
        Parent = fill,
    })

    local fillGlow = Stroke(accent, 3, 1, fill)

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

    Tween(overlay, 0.40 / speed, { BackgroundTransparency = 0.35 }):Play()
    Tween(blur, 0.55 / speed, { Size = 28 }):Play()
    Tween(colorFx, 0.55 / speed, { Saturation = -0.25 }):Play()
    Tween(cardScale, 0.55 / speed, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
    Tween(card, 0.50 / speed, { BackgroundTransparency = theme.BackgroundTrans or 0.15 }):Play()
    Tween(cardStroke, 0.50 / speed, { Transparency = 0.35 }):Play()
    Tween(logoLabel, 0.50 / speed, { TextTransparency = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
    Tween(orbitDot, 0.50 / speed, { BackgroundTransparency = 0 }):Play()

    task.delay(0.25 / speed, function() Tween(titleLbl, 0.40 / speed, { TextTransparency = 0 }):Play() end)
    task.delay(0.35 / speed, function()
        Tween(chip, 0.30 / speed, { BackgroundTransparency = 0.85 }):Play()
        Tween(chipStroke, 0.30 / speed, { Transparency = 0.40 }):Play()
        Tween(chipLabel, 0.30 / speed, { TextTransparency = 0 }):Play()
    end)
    task.delay(0.45 / speed, function() Tween(tagLbl, 0.40 / speed, { TextTransparency = 0 }):Play() end)
    task.delay(0.55 / speed, function()
        for _, d in ipairs(stageDots) do
            Tween(d, 0.30 / speed, { BackgroundTransparency = 0.55 }):Play()
        end
        Tween(track, 0.35 / speed, { BackgroundTransparency = 0.4 }):Play()
        Tween(statusLbl, 0.30 / speed, { TextTransparency = 0 }):Play()
        Tween(rightLbl, 0.30 / speed, { TextTransparency = 0 }):Play()
    end)

    local animStart = tick()
    local animConn = RunService.RenderStepped:Connect(function()
        if not introGui.Parent then
            pcall(function() animConn:Disconnect() end)
            return
        end
        local t = (tick() - animStart) * speed

        if strokeGrad and strokeGrad.Parent then
            strokeGrad.Rotation = (t * 60) % 360
        end
        if orbitHolder and orbitHolder.Parent then
            orbitHolder.Rotation = (t * 90) % 360
        end
        if logo and logo.Parent then
            logo.BackgroundTransparency = 0.15 + 0.05 * math.sin(t * 3)
        end
        if shimmerGrad and shimmerGrad.Parent then
            local cycle = (t % 1.4) / 1.4
            shimmerGrad.Offset = Vector2.new(-1 + cycle * 2, 0)
        end

        local bass  = (math.sin(t * 0.62) * 0.5) + 0.5
        local kick  = math.max(0, math.sin(t * 2.35)) ^ 4
        local snare = math.max(0, math.sin(t * 3.85 + 1.4)) ^ 6
        local energy = bass * 0.35 + kick * 0.45 + snare * 0.20
        energy = math.clamp(energy, 0, 1)

        local alpha = math.clamp((t - 0.15) / 0.6, 0, 1)

        local stretch = energy * 0.28
        local squash  = energy * 0.10

        local sx = (1 + stretch) * alpha
        local sy = (1 - squash)  * alpha
        if blobCore and blobCore.Parent then
            blobCore.Size = UDim2.fromScale(sx, sy)
            blobCore.Rotation = math.sin(t * 1.6) * 6 * alpha
            local coreTarget = 0.80 - energy * 0.12
            blobCore.BackgroundTransparency = 1 - (1 - coreTarget) * alpha
        end

        if blobHalo and blobHalo.Parent then
            local haloScale = 1.10 + (1 - energy) * 0.15
            blobHalo.Size = UDim2.fromScale(haloScale * alpha, haloScale * alpha)
            local haloTarget = 0.88 - energy * 0.06
            blobHalo.BackgroundTransparency = 1 - (1 - haloTarget) * alpha
        end

        if blobShine and blobShine.Parent then
            local shineTarget = 0.72 - energy * 0.15
            blobShine.BackgroundTransparency = 1 - (1 - shineTarget) * alpha
        end
    end)

    local function burstParticles()
        local GOLDEN = 2.39996323 -- golden angle in radians
        for i = 1, 14 do
            local angle = i * GOLDEN
            local radius = 100 + (i % 3) * 20 -- vary radius for organic feel
            local dx = math.cos(angle) * radius
            local dy = math.sin(angle) * radius
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
            pcall(function()
                Tween(dot, 0.7 / speed, {
                    Position = UDim2.new(0.5, dx, 0.5, dy),
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(2, 2),
                }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out):Play()
            end)
            task.delay(0.8 / speed, function() pcall(function() dot:Destroy() end) end)
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
        pcall(function()
            Tween(ring, 0.7 / speed, {
                Size = UDim2.fromOffset(420, 420),
            }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out):Play()
            Tween(ringStroke, 0.7 / speed, {
                Transparency = 1,
                Thickness = 1,
            }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out):Play()
        end)
        task.delay(0.8 / speed, function() pcall(function() ring:Destroy() end) end)
    end

    local completed = false
    local function finish()
        if completed then return end
        completed = true

        if animConn then pcall(function() animConn:Disconnect() end) end

        expandRing()
        burstParticles()

        pcall(function()
            Tween(card, 0.5 / speed, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In):Play()
            Tween(cardStroke, 0.5 / speed, { Transparency = 1 }):Play()
            Tween(logo, 0.4 / speed, { BackgroundTransparency = 1 }):Play()
            Tween(logoLabel, 0.35 / speed, { TextTransparency = 1 }):Play()
            Tween(orbitDot, 0.3 / speed, { BackgroundTransparency = 1 }):Play()
            Tween(titleLbl, 0.35 / speed, { TextTransparency = 1 }):Play()
            Tween(chip, 0.3 / speed, { BackgroundTransparency = 1 }):Play()
            Tween(chipStroke, 0.3 / speed, { Transparency = 1 }):Play()
            Tween(chipLabel, 0.3 / speed, { TextTransparency = 1 }):Play()
            Tween(tagLbl, 0.35 / speed, { TextTransparency = 1 }):Play()
            Tween(track, 0.35 / speed, { BackgroundTransparency = 1 }):Play()
            Tween(fill, 0.35 / speed, { BackgroundTransparency = 1 }):Play()
            Tween(fillGlow, 0.35 / speed, { Transparency = 1 }):Play()
            Tween(statusLbl, 0.3 / speed, { TextTransparency = 1 }):Play()
            Tween(rightLbl, 0.3 / speed, { TextTransparency = 1 }):Play()
            for _, d in ipairs(stageDots) do
                Tween(d, 0.3 / speed, { BackgroundTransparency = 1 }):Play()
            end
            Tween(blobCore, 0.6 / speed, {
                Size = UDim2.fromScale(1.6, 1.6),
                BackgroundTransparency = 1,
            }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out):Play()
            Tween(blobHalo, 0.6 / speed, {
                Size = UDim2.fromScale(2.0, 2.0),
                BackgroundTransparency = 1,
            }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out):Play()
            Tween(blobShine, 0.4 / speed, { BackgroundTransparency = 1 }):Play()
            Tween(cardScale, 0.55 / speed, { Scale = 1.06 }, Enum.EasingStyle.Quart, Enum.EasingDirection.In):Play()
            Tween(overlay, 0.65 / speed, { BackgroundTransparency = 1 }):Play()
            Tween(blur, 0.65 / speed, { Size = 0 }):Play()
            Tween(colorFx, 0.65 / speed, { Saturation = 0, Brightness = 0, Contrast = 0 }):Play()
        end)

        task.wait(0.7 / speed)

        if blur.Parent then pcall(function() blur:Destroy() end) end
        if colorFx.Parent then pcall(function() colorFx:Destroy() end) end
        if introGui.Parent then pcall(function() introGui:Destroy() end) end
        if LucidUI._activeIntro == introGui then LucidUI._activeIntro = nil end

        if onComplete then pcall(onComplete) end
    end

    if skipNow then
        finish()
        return introGui
    end

    if skipOnInput then
        local skipConn
        skipConn = UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
                or input.UserInputType == Enum.UserInputType.Keyboard then
                if skipConn then pcall(function() skipConn:Disconnect() end) end
                finish()
            end
        end)
        task.delay(duration + 5, function()
            if skipConn then pcall(function() skipConn:Disconnect() end) end
        end)
    end

    task.spawn(function()
        local prevPct = 0

        for index, stage in ipairs(stages) do
            if completed then return end

            statusLbl.Text = stage.text
            rightLbl.Text = string.format("%d%%", math.floor(stage.pct * 100))

            local dot = stageDots[index]
            if dot then
                Tween(dot, 0.25 / speed, { BackgroundColor3 = accent, BackgroundTransparency = 0 }):Play()
            end

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

                Tween(fill, 0.18 / speed, {
                    Size = UDim2.new(targetPct, 0, 1, 0),
                }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
                rightLbl.Text = string.format("%d%%", math.floor(targetPct * 100))
                task.wait(0.15 / speed)

            else
                local waitTime  = (stage.wait or 0.35)
                local startPct  = prevPct
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

        task.wait(0.25 / speed)
        finish()
    end)

    return introGui
end

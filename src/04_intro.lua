--[[
    Intro — premium animated loading screen with task support.

    Visuals:
      • Music-reactive blob behind the card (stretches on the beat)
      • Rotating gradient border on the glass card
      • Geometric logo with an orbiting dot and breathing pulse
      • Version chip pill under the title
      • Stage dots that fill in one by one
      • Progress bar with a UIGradient shimmer
      • Expanding ring + particle burst on completion
      • Staggered entrance for every element
      • Skippable at any moment via click, tap, or keypress

    Blob:
      The blob is a fully procedural bass visualizer. Since Roblox
      has no real-time audio analysis, the "beat" is simulated with
      three layered sine waves (slow bass, kick, snare). The blob
      stretches horizontally and squashes vertically on each pulse,
      sways gently, and fades the shine in/out with the energy.

    Task support:
      Pass opts.Stages = { { text, pct, task?, wait? }, ... }
      Each task function receives a report(subProgress) callback so it
      can advance the bar mid-stage (perfect for downloads).
]]

function LucidUI:ShowIntro(opts)
    opts = opts or {}

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

    -- Build stage list
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
    -- 360×360 base, positioned center. Anchored there so scaling
    -- and rotation happen around the visual center.
    local BLOB_BASE = 360
    local blobWrap = Create("Frame", {
        Size = UDim2.fromOffset(BLOB_BASE, BLOB_BASE),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 0,
        Parent = overlay,
    })

    -- Soft outer halo — expands when the core is resting,
    -- contracts when the core stretches.
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

    -- Main jelly body
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

    -- Specular shine (top-left highlight) — the glass-bubble look
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

    -- Logo + orbit
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

    -- Title / chip / tagline
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

    -- Stage dots
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

    -- Progress bar
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

    -- Card + text entrance (blob is driven entirely by the loop)
    Tween(overlay, 0.40, { BackgroundTransparency = 0.35 }):Play()
    Tween(blur, 0.55, { Size = 28 }):Play()
    Tween(colorFx, 0.55, { Saturation = -0.25 }):Play()
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

    -- ── Continuous animations ──────────────────────────────────
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
        if logo and logo.Parent then
            logo.BackgroundTransparency = 0.15 + 0.05 * math.sin(t * 3)
        end
        if shimmerGrad and shimmerGrad.Parent then
            local cycle = (t % 1.4) / 1.4
            shimmerGrad.Offset = Vector2.new(-1 + cycle * 2, 0)
        end

        -- ── Blob: layered pseudo-audio ─────────────────────────
        -- Three waves stacked so the pulse feels like a real track
        -- rather than a single sine. Kick hits every ~0.4s, snare
        -- offsets, and a slow bass wave underneath modulates the
        -- overall "loudness."
        local bass  = (math.sin(t * 0.62) * 0.5) + 0.5            -- 0..1, slow
        local kick  = math.max(0, math.sin(t * 2.35)) ^ 4         -- sharp pulse
        local snare = math.max(0, math.sin(t * 3.85 + 1.4)) ^ 6   -- rare flick
        local energy = bass * 0.35 + kick * 0.45 + snare * 0.20
        energy = math.clamp(energy, 0, 1)

        -- Entrance ramp: alpha goes 0 → 1 over the first 0.75s
        local alpha = math.clamp((t - 0.15) / 0.6, 0, 1)

        -- Stretch on X (elongate), squash on Y (volume conserved)
        local stretch = energy * 0.28
        local squash  = energy * 0.10

        local sx = (1 + stretch) * alpha
        local sy = (1 - squash)  * alpha
        blobCore.Size = UDim2.fromScale(sx, sy)

        -- Gentle sway (rotation is fine on a rounded Frame —
        -- the corner follows, giving an organic wobble)
        blobCore.Rotation = math.sin(t * 1.6) * 6 * alpha

        -- Core opacity: visible + a touch brighter when loud
        local coreTarget = 0.80 - energy * 0.12
        blobCore.BackgroundTransparency = 1 - (1 - coreTarget) * alpha

        -- Halo: grows when the core is resting, fades as core stretches
        local haloScale = 1.10 + (1 - energy) * 0.15
        blobHalo.Size = UDim2.fromScale(haloScale * alpha, haloScale * alpha)
        local haloTarget = 0.88 - energy * 0.06
        blobHalo.BackgroundTransparency = 1 - (1 - haloTarget) * alpha

        -- Shine: brighter when loud (energy catches the light)
        local shineTarget = 0.72 - energy * 0.15
        blobShine.BackgroundTransparency = 1 - (1 - shineTarget) * alpha
    end)

    -- Completion flourish
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

    -- Finish
    local completed = false
    local function finish()
        if completed then return end
        completed = true

        if animConn then animConn:Disconnect() end

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
        Tween(statusLbl, 0.3, { TextTransparency = 1 }):Play()
        Tween(rightLbl, 0.3, { TextTransparency = 1 }):Play()
        for _, d in ipairs(stageDots) do
            Tween(d, 0.3, { BackgroundTransparency = 1 }):Play()
        end

        -- Blob exit: expands outward and fades, like a burst of energy
        Tween(blobCore, 0.6, {
            Size = UDim2.fromScale(1.6, 1.6),
            BackgroundTransparency = 1,
        }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out):Play()
        Tween(blobHalo, 0.6, {
            Size = UDim2.fromScale(2.0, 2.0),
            BackgroundTransparency = 1,
        }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out):Play()
        Tween(blobShine, 0.4, { BackgroundTransparency = 1 }):Play()

        Tween(cardScale, 0.55, { Scale = 1.06 }, Enum.EasingStyle.Quart, Enum.EasingDirection.In):Play()
        Tween(overlay, 0.65, { BackgroundTransparency = 1 }):Play()
        Tween(blur, 0.65, { Size = 0 }):Play()
        Tween(colorFx, 0.65, { Saturation = 0, Brightness = 0, Contrast = 0 }):Play()

        task.wait(0.7)

        if blur.Parent then blur:Destroy() end
        if colorFx.Parent then colorFx:Destroy() end
        if introGui.Parent then introGui:Destroy() end
        if LucidUI._activeIntro == introGui then LucidUI._activeIntro = nil end

        if onComplete then pcall(onComplete) end
    end

    -- Skip on input
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

    -- Run stages
    task.spawn(function()
        local prevPct = 0

        for index, stage in ipairs(stages) do
            if completed then return end

            statusLbl.Text = stage.text
            rightLbl.Text = string.format("%d%%", math.floor(stage.pct * 100))

            local dot = stageDots[index]
            if dot then
                Tween(dot, 0.25, { BackgroundColor3 = accent, BackgroundTransparency = 0 }):Play()
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

                Tween(fill, 0.18, {
                    Size = UDim2.new(targetPct, 0, 1, 0),
                }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
                rightLbl.Text = string.format("%d%%", math.floor(targetPct * 100))
                task.wait(0.15)

            else
                local waitTime  = stage.wait or 0.35
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

        task.wait(0.25)
        finish()
    end)

    return introGui
end

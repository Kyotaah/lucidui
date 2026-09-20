--[[
    Polish — ripple, hover glow, hover tooltip, press scale, UI sounds.

    [IMPROVEMENT] BindTap now cleans up its input connections when the
    target is destroyed mid-press. PlayUISound pools its Sound instances
    to prevent spam. AttachPressScale gives tactile feedback. BindTap
    accepts options.Sound and options.Ripple to toggle effects per element.
]]

-- ============================================================
-- UI Sounds (MUST come before BindTap)
-- ============================================================
local soundPool = {}
local SOUND_IDS = {
    click = "rbxasset://sounds/electronicpingshort.wav",
    hover = "rbxasset://sounds/switch.wav",
}

local function PlayUISound(kind)
    local id = SOUND_IDS[kind]
    if not id or id == "" then return end

    soundPool[kind] = soundPool[kind] or {}
    local pool = soundPool[kind]

    local s
    for _, sound in ipairs(pool) do
        if not sound.Playing then s = sound break end
    end

    if not s then
        if #pool >= 4 then return end
        s = Instance.new("Sound")
        s.Volume = (kind == "click") and 0.15 or 0.07
        s.Parent = SoundService
        table.insert(pool, s)
    end

    s.SoundId = id  -- reapply every call so sound packs work on pooled sounds

    pcall(function() s:Play() end)
end

local function AttachHoverSound(element)
    local last = 0
    element.MouseEnter:Connect(function()
        local now = tick()
        if now - last < 0.12 then return end
        last = now
        PlayUISound("hover")
    end)
end

-- ============================================================
-- Press Scale
-- ============================================================
local function AttachPressScale(button, scaleAmount)
    scaleAmount = scaleAmount or 0.96
    local originalSize = button.Size

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            Tween(button, 0.08, {
                Size = UDim2.new(
                    originalSize.X.Scale * scaleAmount, originalSize.X.Offset,
                    originalSize.Y.Scale * scaleAmount, originalSize.Y.Offset
                ),
            }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out):Play()
        end
    end)

    local function restore()
        Tween(button, 0.15, { Size = originalSize },
            Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
    end

    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            restore()
        end
    end)
end

-- ============================================================
-- BindTap — tap vs drag discriminator
-- ============================================================
local function BindTap(guiObject, callback, options)
    options = options or {}
    local moveThreshold = options.MoveThreshold or 12
    local maxDuration   = options.MaxDuration   or 1.0
    local onDown        = options.OnDown
    local onCancel      = options.OnCancel
    local withSound     = options.Sound  ~= false
    local withScale     = options.Scale  == true

    if withScale then
        AttachPressScale(guiObject, options.ScaleAmount)
    end

    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local startPos  = input.Position
        local startTime = tick()
        local moved     = false
        local finished  = false

        if onDown then
            pcall(onDown, input)
        end

        local changeConn, endConn, destroyConn

        local function cleanup()
            if changeConn then pcall(function() changeConn:Disconnect() end) end
            if endConn    then pcall(function() endConn:Disconnect()    end) end
            if destroyConn then pcall(function() destroyConn:Disconnect() end) end
            changeConn, endConn, destroyConn = nil, nil, nil
        end

        changeConn = UserInputService.InputChanged:Connect(function(changed)
            if changed ~= input then return end
            if (changed.Position - startPos).Magnitude > moveThreshold then
                moved = true
            end
        end)

        endConn = UserInputService.InputEnded:Connect(function(ended)
            if ended ~= input then return end
            if finished then return end
            finished = true

            cleanup()

            local duration = tick() - startTime
            local isTap = (not moved) and duration <= maxDuration

            if isTap then
                if withSound then pcall(PlayUISound, "click") end
                pcall(callback, input)
            elseif onCancel then
                pcall(onCancel, input)
            end
        end)

        destroyConn = guiObject.Destroying:Connect(function()
            finished = true
            cleanup()
        end)
    end)
end

-- ============================================================
-- Ripple
-- ============================================================
local function SpawnRipple(button, px, py)
    local parentZ = button.ZIndex or 1
    local ripple = Create("Frame", {
        Name = "LucidRipple",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(px, py),
        Size = UDim2.fromOffset(0, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        ZIndex = math.clamp(parentZ + 5, 1, 200),
        Parent = button,
    })
    Corner(999, ripple)

    local maxSize = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 2.2
    local t = TweenService:Create(
        ripple,
        TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            Size = UDim2.fromOffset(maxSize, maxSize),
            BackgroundTransparency = 1,
        }
    )
    t:Play()
    t.Completed:Connect(function()
        pcall(function() ripple:Destroy() end)
    end)
end

local function AttachRipple(button)
    button.ClipsDescendants = true
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            local abs = button.AbsolutePosition
            local px = input.Position.X - abs.X
            local py = input.Position.Y - abs.Y
            SpawnRipple(button, px, py)
        end
    end)
end

-- ============================================================
-- Hover Glow
-- ============================================================
local function AttachHoverGlow(element, accent)
    accent = accent or Color3.fromRGB(90, 180, 255)
    local glow = Stroke(accent, 1.5, 1, element)

    element.MouseEnter:Connect(function()
        TweenService:Create(
            glow,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Transparency = 0.35 }
        ):Play()
    end)
    element.MouseLeave:Connect(function()
        TweenService:Create(
            glow,
            TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Transparency = 1 }
        ):Play()
    end)

    return glow
end

-- ============================================================
-- Tooltip
-- ============================================================
local tooltipGui
local function GetTooltipGui()
    if tooltipGui and tooltipGui.Parent then return tooltipGui end
    tooltipGui = Create("ScreenGui", {
        Name = "LucidUI_Tooltip",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 400,
        Parent = PlayerGui,
    })
    return tooltipGui
end

local function AttachTooltip(element, text, opts)
    if not text or text == "" then return end
    opts = opts or {}
    local theme = opts.Theme or LucidUI._lastTheme or LucidUI.Themes.Default

    local tooltip
    element.MouseEnter:Connect(function()
        local gui = GetTooltipGui()
        tooltip = Create("Frame", {
            Name = "Tooltip",
            Size = UDim2.fromOffset(0, 26),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = theme.Background,
            BackgroundTransparency = 0.15,
            BorderSizePixel = 0,
            ZIndex = 5,
            Parent = gui,
        })
        Corner(8, tooltip)
        Stroke(theme.Border, 1, 0.55, tooltip)

        local label = Create("TextLabel", {
            Text = text,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = theme.TextPrimary,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            ZIndex = 6,
            Parent = tooltip,
        })
        Create("UIPadding", {
            PaddingLeft  = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
            Parent = label,
        })

        local abs = element.AbsolutePosition
        local sz  = element.AbsoluteSize
        task.defer(function()
            if not tooltip or not tooltip.Parent then return end
            local w = tooltip.AbsoluteSize.X
            tooltip.Position = UDim2.fromOffset(
                abs.X + (sz.X - w) / 2,
                abs.Y - 34
            )
            tooltip.BackgroundTransparency = 1
            label.TextTransparency = 1
            Tween(tooltip, 0.18, { BackgroundTransparency = 0.15 }):Play()
            Tween(label,   0.18, { TextTransparency = 0 }):Play()
        end)
    end)

    element.MouseLeave:Connect(function()
        if tooltip and tooltip.Parent then
            local t = tooltip
            tooltip = nil
            Tween(t, 0.12, { BackgroundTransparency = 1 }):Play()
            for _, c in ipairs(t:GetDescendants()) do
                if c:IsA("TextLabel") then
                    Tween(c, 0.12, { TextTransparency = 1 }):Play()
                end
            end
            task.delay(0.15, function()
                pcall(function() t:Destroy() end)
            end)
        end
    end)
end

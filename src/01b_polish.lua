--[[
    Polish — ripple, hover glow, UI sounds.
]]

local function SpawnRipple(button, px, py)
    local ripple = Create("Frame", {
        Name = "LucidRipple",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(px, py),
        Size = UDim2.fromOffset(0, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        ZIndex = (button.ZIndex or 1) + 5,
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

local function PlayUISound(kind)
    local ids = {
        click = "rbxasset://sounds/electronicpingshort.wav",
        hover = "rbxasset://sounds/switch.wav",
    }
    local id = ids[kind]
    if not id then return end

    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = (kind == "click") and 0.15 or 0.07
    s.Parent = SoundService
    s:Play()
    task.delay(2, function()
        pcall(function() s:Destroy() end)
    end)
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

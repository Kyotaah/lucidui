--[[
    Helpers — services, easing shorthands, instance constructors,
    glass rendering, viewport utilities, and premium polish
    (ripple, hover glow, sounds).
]]

-- ============================================================
-- Services
-- ============================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local TextService      = game:GetService("TextService")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")
local SoundService     = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui", 10)

local Camera = workspace.CurrentCamera
local tries = 0
while not Camera and tries < 20 do
    task.wait(0.1)
    Camera = workspace.CurrentCamera
    tries = tries + 1
end

if not PlayerGui then
    warn("[LucidUI] PlayerGui not found")
    return
end
if not Camera then
    warn("[LucidUI] Camera not found")
    return
end

-- ============================================================
-- Easing shorthands
-- ============================================================
local Ease = {
    In      = function(t) return TweenInfo.new(t or 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)    end,
    Out     = function(t) return TweenInfo.new(t or 0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)   end,
    InOut   = function(t) return TweenInfo.new(t or 0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut) end,
    FadeIn  = function(t) return TweenInfo.new(t or 0.25, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)   end,
    FadeOut = function(t) return TweenInfo.new(t or 0.22, Enum.EasingStyle.Quad,  Enum.EasingDirection.In)    end,
}

-- ============================================================
-- Instance constructors
-- ============================================================
local function Create(className, props)
    local inst = Instance.new(className)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then inst[k] = v end
    end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end

local function Corner(radius, parent)
    return Create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
        Parent = parent,
    })
end

local function Stroke(color, thickness, transparency, parent)
    return Create("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0.5,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function Tween(inst, time, props, style, dir)
    return TweenService:Create(
        inst,
        TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
end

-- ============================================================
-- Glass rendering
-- ============================================================
local function ApplyGlass(frame, theme, opts)
    opts = opts or {}
    frame.BackgroundColor3       = theme.Background
    frame.BackgroundTransparency = theme.BackgroundTrans or 0.15
    frame.BorderSizePixel        = 0
    Corner(opts.cornerRadius or 16, frame)
    Stroke(theme.Border, 1, theme.BorderTrans or 0.88, frame)
    Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.5, Color3.new(0.96, 0.96, 0.96)),
            ColorSequenceKeypoint.new(1,   Color3.new(0.88, 0.88, 0.88)),
        }),
        Rotation = 135,
        Parent = frame,
    })
end

-- ============================================================
-- Viewport utilities
-- ============================================================
local function GetResponsiveScale()
    local vp = Camera.ViewportSize
    return math.clamp(math.min(vp.X / 1920, vp.Y / 1080) * 1.35, 0.75, 1.35)
end

local function ClampPosition(frame)
    local vp   = Camera.ViewportSize
    local pos  = frame.AbsolutePosition
    local size = frame.AbsoluteSize

    local nx = math.clamp(pos.X, 0, math.max(vp.X - size.X, 0))
    local ny = math.clamp(pos.Y, 0, math.max(vp.Y - size.Y, 0))

    local cur = frame.Position
    frame.Position = UDim2.new(
        cur.X.Scale, cur.X.Offset + (nx - pos.X),
        cur.Y.Scale, cur.Y.Offset + (ny - pos.Y)
    )
end

local function LerpColor(a, b, t)
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
    )
end

-- ============================================================
-- Premium polish — ripple, hover glow, sound
-- ============================================================
local function SpawnRipple(button, x, y)
    local ripple = Create("Frame", {
        Name = "LucidRipple",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(x, y),
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
            local pos = input.Position - button.AbsolutePosition
            SpawnRipple(button, pos.X, pos.Y)
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

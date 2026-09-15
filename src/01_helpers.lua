--[[
    Helpers — services, easing, instance constructors, glass rendering,
    viewport utilities. Polish helpers live in 01b_polish.lua.

    ApplyGlass produces a layered glass effect:
      • Base tinted translucent background
      • Top-edge highlight with rounded top corners
      • Static diagonal sheen (glass catching light)
      • Animated light sweep (a bright band gliding across)
      • Bottom shade with rounded bottom corners

    Also exports PartialCorner for panels that need per-corner radii.
]]

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

if not PlayerGui then warn("[LucidUI] PlayerGui not found") return end
if not Camera then warn("[LucidUI] Camera not found") return end

local Ease = {
    In      = function(t) return TweenInfo.new(t or 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)    end,
    Out     = function(t) return TweenInfo.new(t or 0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)   end,
    InOut   = function(t) return TweenInfo.new(t or 0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut) end,
    FadeIn  = function(t) return TweenInfo.new(t or 0.25, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)   end,
    FadeOut = function(t) return TweenInfo.new(t or 0.22, Enum.EasingStyle.Quad,  Enum.EasingDirection.In)    end,
}

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

-- Per-corner radii helper. Used by the glass layers so highlights
-- don't poke past the panel's rounded corners.
local function PartialCorner(parent, tl, tr, bl, br)
    local c = Instance.new("UICorner")
    c.TopLeftRadius     = UDim.new(0, tl or 0)
    c.TopRightRadius    = UDim.new(0, tr or 0)
    c.BottomLeftRadius  = UDim.new(0, bl or 0)
    c.BottomRightRadius = UDim.new(0, br or 0)
    c.Parent = parent
    return c
end

local function Tween(inst, time, props, style, dir)
    return TweenService:Create(
        inst,
        TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
end

local function ApplyGlass(frame, theme, opts)
    opts = opts or {}
    local radius   = opts.cornerRadius or 18
    local animated = (opts.animated ~= false)
    local sweepGap = opts.sweepGap or 5

    frame.BackgroundColor3       = theme.Background
    frame.BackgroundTransparency = theme.BackgroundTrans or 0.35
    frame.BorderSizePixel        = 0
    Corner(radius, frame)
    Stroke(theme.Border, 1, math.min((theme.BorderTrans or 0.85) + 0.05, 1), frame)

    -- Top-edge highlight
    local topHighlight = Create("Frame", {
        Name = "GlassTopHighlight",
        Size = UDim2.fromScale(1, 0.5),
        Position = UDim2.fromScale(0, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = frame,
    })
    PartialCorner(topHighlight, radius, radius, 0, 0)
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.0, 0.0),
            NumberSequenceKeypoint.new(0.6, 1.0),
            NumberSequenceKeypoint.new(1.0, 1.0),
        }),
        Rotation = 90,
        Parent = topHighlight,
    })

    -- Static diagonal sheen
    local sheenBase = Create("Frame", {
        Name = "GlassSheenBase",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.92,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = frame,
    })
    Corner(radius, sheenBase)
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.0, 0.0),
            NumberSequenceKeypoint.new(0.45, 1.0),
            NumberSequenceKeypoint.new(1.0, 1.0),
        }),
        Rotation = 135,
        Parent = sheenBase,
    })

    -- Animated light sweep
    local sweep = Create("Frame", {
        Name = "GlassSweep",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = frame,
    })
    Corner(radius, sweep)
    local sweepGradient = Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.00, 1.0),
            NumberSequenceKeypoint.new(0.42, 1.0),
            NumberSequenceKeypoint.new(0.50, 0.0),
            NumberSequenceKeypoint.new(0.58, 1.0),
            NumberSequenceKeypoint.new(1.00, 1.0),
        }),
        Rotation = 135,
        Offset = Vector2.new(-1, 0),
        Parent = sweep,
    })

    if animated then
        task.spawn(function()
            while sweep and sweep.Parent do
                sweepGradient.Offset = Vector2.new(-1, 0)
                local ok = pcall(function()
                    TweenService:Create(
                        sweepGradient,
                        TweenInfo.new(2.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                        { Offset = Vector2.new(1, 0) }
                    ):Play()
                end)
                if not ok then break end
                task.wait(2.9)
                task.wait(sweepGap)
            end
        end)
    end

    -- Bottom shade
    local bottomShade = Create("Frame", {
        Name = "GlassBottomShade",
        Size = UDim2.fromScale(1, 0.35),
        Position = UDim2.fromScale(0, 0.65),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.92,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = frame,
    })
    PartialCorner(bottomShade, 0, 0, radius, radius)
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.0, 1.0),
            NumberSequenceKeypoint.new(1.0, 0.2),
        }),
        Rotation = 90,
        Parent = bottomShade,
    })
end

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

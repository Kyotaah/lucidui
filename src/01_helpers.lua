--[[
    Helpers — services, easing shorthands, instance constructors,
    glass rendering, and viewport utilities.
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

-- ============================================================
-- Small math helper — lerp between two Color3 values
-- ============================================================
local function LerpColor(a, b, t)
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
    )
end

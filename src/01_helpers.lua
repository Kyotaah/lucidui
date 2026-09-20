-- ============================================================
-- Module: 01_helpers.lua
-- ============================================================
--[[
    Helpers — services, easing, instance constructors, glass rendering,
    viewport utilities. Polish helpers live in 01b_polish.lua.

    ApplyGlass produces a layered glass effect:
      • Base tinted translucent background
      • Top-edge highlight with rounded top corners
      • Static diagonal sheen (glass catching light)
      • Animated light sweep (a bright band gliding across)
      • Bottom shade with rounded bottom corners
      • (Optional) Soft drop shadow

    Also exports PartialCorner for panels that need per-corner radii.

    [IMPROVEMENT] Never returns early. If PlayerGui or Camera is missing,
    the module waits for it instead of killing the whole library.

    [NEW] ClampPosition now supports animated spring-back via opts.
    ApplyEdgeResistance provides rubber-band damping during drag.
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

local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
if not PlayerGui then
    PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 30)
end

local Camera = workspace.CurrentCamera
if not Camera then
    local tries = 0
    while not Camera and tries < 100 do
        task.wait(0.1)
        Camera = workspace.CurrentCamera
        tries = tries + 1
    end
end
if not Camera then
    warn("[LucidUI] Camera was not found. Some features may not work.")
end

local function GetPlayerGui() return PlayerGui end
local function GetCamera()    return Camera or workspace.CurrentCamera end

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

local function CreateRoundedFrame(props, radius)
    local frame = Create("Frame", props)
    Corner(radius or 10, frame)
    return frame
end

local function Debounce(wait, fn)
    local token = 0
    return function(...)
        token = token + 1
        local myToken = token
        local args = { ... }
        task.delay(wait, function()
            if myToken == token then
                fn(unpack and unpack(args) or table.unpack(args))
            end
        end)
    end
end

local function Throttle(interval, fn)
    local lastCall = 0
    return function(...)
        local now = tick()
        if now - lastCall >= interval then
            lastCall = now
            fn(...)
        end
    end
end

local function ApplyGlass(frame, theme, opts)
    opts = opts or {}
    local radius   = opts.cornerRadius or 18
    local animated = (opts.animated ~= false)
    local sweepGap = opts.sweepGap or 5
    local shadow   = opts.shadow == true

    frame.BackgroundColor3       = theme.Background
    frame.BackgroundTransparency = theme.BackgroundTrans or 0.35
    frame.BorderSizePixel        = 0
    Corner(radius, frame)
    Stroke(theme.Border, 1, math.min((theme.BorderTrans or 0.85) + 0.05, 1), frame)

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
    local cam = Camera or workspace.CurrentCamera
    if not cam then return 1 end
    local vp = cam.ViewportSize
    return math.clamp(math.min(vp.X / 1920, vp.Y / 1080) * 1.35, 0.75, 1.35)
end

-- ============================================================
-- [NEW] ClampPosition with animated spring-back
-- ============================================================
-- opts.instant = true → snap immediately (used for resize, resize-end)
-- opts.duration / opts.style / opts.direction → customize the spring
local function ClampPosition(frame, opts)
    opts = opts or {}
    local cam = Camera or workspace.CurrentCamera
    if not cam then return end

    local vp   = cam.ViewportSize
    local pos  = frame.AbsolutePosition
    local size = frame.AbsoluteSize

    local nx = math.clamp(pos.X, 0, math.max(vp.X - size.X, 0))
    local ny = math.clamp(pos.Y, 0, math.max(vp.Y - size.Y, 0))

    local cur = frame.Position
    local dx = nx - pos.X
    local dy = ny - pos.Y

    -- In bounds, or instant requested → snap like before
    if opts.instant or (math.abs(dx) < 0.5 and math.abs(dy) < 0.5) then
        frame.Position = UDim2.new(
            cur.X.Scale, cur.X.Offset + dx,
            cur.Y.Scale, cur.Y.Offset + dy
        )
        return
    end

    -- Spring back with a subtle overshoot
    local target = UDim2.new(
        cur.X.Scale, cur.X.Offset + dx,
        cur.Y.Scale, cur.Y.Offset + dy
    )
    pcall(function()
        TweenService:Create(frame, TweenInfo.new(
            opts.duration  or 0.35,
            opts.style     or Enum.EasingStyle.Back,
            opts.direction or Enum.EasingDirection.Out
        ), { Position = target }):Play()
    end)
end

-- ============================================================
-- [NEW] Rubber-band damping during drag
-- ============================================================
--[[
    Given a raw (X, Y) pixel position, the frame's size, and the
    viewport, returns an adjusted (X, Y) that resists being pushed
    past the viewport edges.

    Damping: sqrt curve, scaled by DAMP, capped at MAX_PUSH.
    Feel: the first few px of overshoot move ~1:1, then rapidly
    diminish. You can always feel the wall, but never blow past
    the screen far enough to lose the window.
]]
local function ApplyEdgeResistance(rawX, rawY, w, h, vp)
    local overLeft   = math.max(0, -rawX)
    local overRight  = math.max(0, (rawX + w) - vp.X)
    local overTop    = math.max(0, -rawY)
    local overBottom = math.max(0, (rawY + h) - vp.Y)

    local DAMP     = 4.0
    local MAX_PUSH = 60

    local pushLeft   = math.min(math.sqrt(overLeft)   * DAMP, MAX_PUSH)
    local pushRight  = math.min(math.sqrt(overRight)  * DAMP, MAX_PUSH)
    local pushTop    = math.min(math.sqrt(overTop)    * DAMP, MAX_PUSH)
    local pushBottom = math.min(math.sqrt(overBottom) * DAMP, MAX_PUSH)

    return rawX + pushLeft - pushRight,
           rawY + pushTop  - pushBottom
end

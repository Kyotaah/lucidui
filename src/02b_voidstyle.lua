-- ============================================================
-- Module: 02b_void_style.lua
-- ============================================================
--[[
    Void Style — RayVoid's dark purple/pink aesthetic, packaged as
    a full enhancement layer for LucidUI.

    Features:
      • "Void" theme registered into LucidUI.Themes
      • Universal glass tinting — every theme's sheen layers
        become accent-tinted (fixes the invisible white-on-white
        sweep that Light/Latte themes had)
      • Ambient glow — a soft, breathing halo behind the window
      • Animated gradient border — optional rotating accent stroke
      • Style helper library (AccentBar, Gradient, Card, HoverGlow,
        ValueLabel, Divider, ShinePass) for building VoidUI
        components in later modules

    Opt-out per window:
      CreateWindow({
          VoidStyle        = true,   -- applies Void theme + features
          EnhanceGlass     = false,  -- disable accent-tinted glass
          AmbientGlow      = false,  -- disable the breathing halo
          AnimatedBorder   = false,  -- disable rotating border
          GlowIntensity    = 1.0,    -- 0.5 .. 1.5
          GlowPulse        = true,   -- true=breathing, false=static
      })

    NO tracking. NO network. NO clipboard.
]]

-- ============================================================
-- 1. Void palette & theme
-- ============================================================
LucidUI.VoidPalette = {
    -- Core surfaces
    BgDeep     = Color3.fromRGB(8,   8,  12),
    BgMid      = Color3.fromRGB(14,  14, 20),
    BgLight    = Color3.fromRGB(22,  22, 32),
    BgLighter  = Color3.fromRGB(30,  28, 45),

    -- Accent ramp
    Accent     = Color3.fromRGB(130, 80,  255),
    AccentSoft = Color3.fromRGB(100, 60,  200),
    AccentPink = Color3.fromRGB(220, 80,  160),
    AccentGlow = Color3.fromRGB(160, 110, 255),
    AccentDeep = Color3.fromRGB(70,  40,  140),

    -- Text
    TextBright = Color3.fromRGB(240, 238, 255),
    TextMid    = Color3.fromRGB(160, 155, 190),
    TextDim    = Color3.fromRGB(85,  82,  115),

    -- Utility
    BorderDim  = Color3.fromRGB(35,  32,  58),
    Success    = Color3.fromRGB(55,  210, 120),
    Warning    = Color3.fromRGB(255, 185, 40),
    Error      = Color3.fromRGB(230, 55,  75),
    Info       = Color3.fromRGB(60,  155, 255),
    White      = Color3.fromRGB(255, 255, 255),
    Black      = Color3.fromRGB(0,   0,   0),
}

LucidUI.Themes["Void"] = LucidUI._validateTheme({
    Background        = Color3.fromRGB(14,  14, 20),
    BackgroundTrans   = 0.12,

    Surface           = Color3.fromRGB(22,  22, 32),
    SurfaceTrans      = 0.25,

    SurfaceHover      = Color3.fromRGB(30,  28, 45),
    SurfaceHoverTrans = 0.15,

    Border            = Color3.fromRGB(130, 80,  255),
    BorderTrans       = 0.72,

    Accent            = Color3.fromRGB(130, 80,  255),

    TextPrimary       = Color3.fromRGB(240, 238, 255),
    TextSecondary     = Color3.fromRGB(200, 195, 235),
    TextMuted         = Color3.fromRGB(160, 155, 190),

    ToggleOff         = Color3.fromRGB(35,  32,  58),
    SliderTrack       = Color3.fromRGB(35,  32,  58),

    TabActive         = Color3.fromRGB(240, 238, 255),
    TabInactive       = Color3.fromRGB(160, 155, 190),
})

-- ============================================================
-- 2. Color math helpers
-- ============================================================
local function luminance(c)
    return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

local function mixColor(c1, c2, t)
    return Color3.new(
        c1.R + (c2.R - c1.R) * t,
        c1.G + (c2.G - c1.G) * t,
        c1.B + (c2.B - c1.B) * t
    )
end

local function darken(c, amount)
    return Color3.new(
        math.max(c.R - amount, 0),
        math.max(c.G - amount, 0),
        math.max(c.B - amount, 0)
    )
end

local function lighten(c, amount)
    return Color3.new(
        math.min(c.R + amount, 1),
        math.min(c.G + amount, 1),
        math.min(c.B + amount, 1)
    )
end

local function colorWithAlpha(c, a)  -- a 0..1, returns {color, transparency}
    return c, 1 - a
end

-- ============================================================
-- 3. Universal glass enhancement
-- ============================================================
--[[
    Re-tints the four glass layers (top highlight, sheen base,
    animated sweep, bottom shade) to match the current theme's
    accent + background.

    Fixes a real bug: Light and Catppuccin Latte themes have
    near-white backgrounds, so the hardcoded white sweep was
    completely invisible. Now they get a subtle darker tint.
]]

local function enhanceGlassLayers(frame, theme, opts)
    if not frame or not frame.Parent or not theme then return end

    local topHighlight = frame:FindFirstChild("GlassTopHighlight")
    local sheenBase    = frame:FindFirstChild("GlassSheenBase")
    local sweep        = frame:FindFirstChild("GlassSweep")
    local bottomShade  = frame:FindFirstChild("GlassBottomShade")

    local accent  = theme.Accent     or Color3.fromRGB(10, 132, 255)
    local bg      = theme.Background or Color3.fromRGB(28, 28, 30)
    local isLight = luminance(bg) > 0.5

    if isLight then
        local highlightTint = mixColor(accent, Color3.new(0, 0, 0), 0.55)
        local sheenTint     = mixColor(accent, Color3.new(0, 0, 0), 0.68)
        local sweepTint     = mixColor(accent, Color3.new(0, 0, 0), 0.50)
        local shadeTint     = mixColor(bg,     Color3.new(0, 0, 0), 0.15)

        if topHighlight then topHighlight.BackgroundColor3 = highlightTint end
        if sheenBase    then sheenBase.BackgroundColor3    = sheenTint     end
        if sweep        then sweep.BackgroundColor3        = sweepTint     end
        if bottomShade  then bottomShade.BackgroundColor3  = shadeTint     end
    else
        local highlightTint = mixColor(Color3.new(1, 1, 1), accent, 0.20)
        local sheenTint     = mixColor(Color3.new(1, 1, 1), accent, 0.30)
        local sweepTint     = mixColor(Color3.new(1, 1, 1), accent, 0.55)
        local shadeTint     = mixColor(Color3.new(0, 0, 0), bg,     0.55)

        if topHighlight then topHighlight.BackgroundColor3 = highlightTint end
        if sheenBase    then sheenBase.BackgroundColor3    = sheenTint     end
        if sweep        then sweep.BackgroundColor3        = sweepTint     end
        if bottomShade  then bottomShade.BackgroundColor3  = shadeTint     end
    end

    -- Give the animated sweep a two-tone gradient instead of flat tint
    if sweep and opts.gradientSweep ~= false then
        local grad = sweep:FindFirstChildOfClass("UIGradient")
        if grad then
            if isLight then
                grad.Color = ColorSequence.new(
                    mixColor(accent, Color3.new(0, 0, 0), 0.62),
                    mixColor(accent, Color3.new(1, 1, 1), 0.20)
                )
            else
                grad.Color = ColorSequence.new(accent, lighten(accent, 0.28))
            end
        end
    end
end

-- ============================================================
-- 4. Ambient glow (breathing halo behind the window)
-- ============================================================
--[[
    Multi-layer halo parented to the window's ScreenGui, sitting
    behind W.Main. Its Position/Size mirror W.Main every frame so
    it moves, resizes, docks, and minimizes with the window.

    Layers: 3 concentric frames with progressively lower opacity.
    On a dark theme this reads as a soft purple bloom; on a light
    theme it reads as a subtle colored shadow.
]]

local function buildAmbientGlow(W, theme, opts)
    if not W.Gui or not W.Main then return nil end
    if W._ambientGlow then
        pcall(function() W._ambientGlow:Destroy() end)
        W._ambientGlow = nil
    end

    local intensity = math.clamp(opts.GlowIntensity or 1.0, 0.3, 2.0)
    local pulseOn   = opts.GlowPulse ~= false
    local accent    = theme.Accent or Color3.fromRGB(130, 80, 255)
    local isLight   = luminance(theme.Background or Color3.fromRGB(28,28,30)) > 0.5

    -- Container so we can destroy all layers at once
    local container = Create("Frame", {
        Name = "VoidAmbientGlow",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 0,
        Visible = true,
        Parent = W.Gui,
    })

    local layers = {}
    local layerSpecs = {
        { offset =  6, transparency = 0.78 },
        { offset = 14, transparency = 0.88 },
        { offset = 24, transparency = 0.94 },
    }

    for i, spec in ipairs(layerSpecs) do
        local layer = Create("Frame", {
            Name = "GlowLayer" .. i,
            BackgroundColor3 = accent,
            BackgroundTransparency = spec.transparency,
            BorderSizePixel = 0,
            ZIndex = 0,
            Parent = container,
        })
        Corner(26 + spec.offset * 0.5, layer)
        table.insert(layers, {
            frame = layer,
            base = spec,
            alpha = spec.transparency,
            pulseOffset = (i - 1) * 0.35,  -- stagger the breathing
        })
    end

    -- Sync position/size with W.Main (mirror with an outward offset)
    local function sync()
        if not container.Parent or not W.Main or not W.Main.Parent then return end
        local mp = W.Main.Position
        local ms = W.Main.Size

        container.Position = mp
        container.AnchorPoint = W.Main.AnchorPoint
        container.Size = ms
    end

    -- Connect to Main's position/size changes.
    -- Using property signals means we don't need a heavy RenderStepped
    -- loop just for the halo.
    table.insert(W._conns, W.Main:GetPropertyChangedSignal("Position"):Connect(sync))
    table.insert(W._conns, W.Main:GetPropertyChangedSignal("Size"):Connect(sync))
    table.insert(W._conns, W.Main:GetPropertyChangedSignal("Visible"):Connect(function()
        container.Visible = W.Main.Visible
    end))
    sync()

    -- Breathing pulse loop. Uses a single RenderStepped connection
    -- and stops automatically when the container is destroyed.
    if pulseOn then
        local t = 0
        local pulseConn
        pulseConn = RunService.RenderStepped:Connect(function(dt)
            if not container.Parent then
                pcall(function() pulseConn:Disconnect() end)
                return
            end
            t = t + dt

            -- Each layer breathes with its own phase; deeper layers
            -- move less, near layers move more. This reads as a
            -- living glow rather than a flat flash.
            for _, layer in ipairs(layers) do
                local phase = math.sin((t + layer.pulseOffset) * 1.4)
                local breathe = (phase * 0.5 + 0.5)  -- 0..1
                local adj = (1 - layer.base.transparency)
                local target = layer.base.transparency + (adj * 0.06 * breathe * intensity)
                layer.frame.BackgroundTransparency = math.clamp(target, 0.5, 0.99)

                -- Also nudge the size outward slightly during the pulse
                local baseOffset = layer.base.offset
                local offsetNow = baseOffset + breathe * 2 * intensity
                local mp = W.Main.Position
                local ms = W.Main.Size
                layer.frame.Position = UDim2.new(0, -offsetNow, 0, -offsetNow)
                layer.frame.Size = UDim2.new(1, offsetNow * 2, 1, offsetNow * 2)
            end
        end)
        table.insert(W._conns, pulseConn)
    else
        -- Static: set the offsets once and forget about it
        for _, layer in ipairs(layers) do
            layer.frame.Position = UDim2.new(0, -layer.base.offset, 0, -layer.base.offset)
            layer.frame.Size = UDim2.new(1, layer.base.offset * 2, 1, layer.base.offset * 2)
        end
    end

    W._ambientGlow = container
    W._ambientGlowLayers = layers

    return container
end

-- ============================================================
-- 5. Animated gradient border
-- ============================================================
--[[
    Replaces the window's static stroke with a rotating gradient
    stroke that cycles through the accent colors. Sits on top of
    the existing glass border.
]]

local function buildAnimatedBorder(W, theme, opts)
    if not W.Main then return end
    if W._animatedBorder and W._animatedBorder.Parent then
        pcall(function() W._animatedBorder:Destroy() end)
    end

    -- Find the existing stroke on W.Main so we can sit alongside it
    local existingStroke
    for _, child in ipairs(W.Main:GetChildren()) do
        if child:IsA("UIStroke") then
            existingStroke = child
            break
        end
    end

    local accent = theme.Accent or Color3.fromRGB(130, 80, 255)
    local accent2 = LucidUI.VoidPalette and LucidUI.VoidPalette.AccentPink
                    or lighten(accent, 0.3)

    local stroke = Create("UIStroke", {
        Name = "VoidAnimatedBorder",
        Color = accent,
        Thickness = (existingStroke and existingStroke.Thickness or 1) + 0.5,
        Transparency = 0.55,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = W.Main,
    })

    local grad = Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,    accent),
            ColorSequenceKeypoint.new(0.35, accent2),
            ColorSequenceKeypoint.new(0.65, accent),
            ColorSequenceKeypoint.new(1,    accent2),
        }),
        Rotation = 0,
        Parent = stroke,
    })

    -- Rotate the gradient continuously
    local borderConn
    borderConn = RunService.RenderStepped:Connect(function(dt)
        if not stroke.Parent then
            pcall(function() borderConn:Disconnect() end)
            return
        end
        grad.Rotation = (grad.Rotation + dt * 45) % 360
    end)
    table.insert(W._conns, borderConn)

    W._animatedBorder = stroke
    W._animatedBorderGrad = grad
end

-- ============================================================
-- 6. Style helper library (for future VoidUI components)
-- ============================================================
LucidUI.VoidStyle = {}
local VS = LucidUI.VoidStyle

VS.Create  = Create
VS.Corner  = Corner
VS.Stroke  = Stroke
VS.Palette = LucidUI.VoidPalette

-- ── Accent bar ─────────────────────────────────────────────
function VS.AccentBar(parent, opts)
    opts = opts or {}
    local barH   = opts.height or 0.55
    local barY   = opts.y      or 0.225
    local radius = opts.radius or 2
    local c1     = opts.color1 or LucidUI.VoidPalette.Accent
    local c2     = opts.color2 or LucidUI.VoidPalette.AccentPink

    local bar = Create("Frame", {
        Name = "AccentBar",
        Size = UDim2.new(0, 3, barH, 0),
        Position = UDim2.new(0, 0, barY, 0),
        BackgroundColor3 = LucidUI.VoidPalette.White,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = parent,
    })
    Corner(radius, bar)
    local grad = Create("UIGradient", {
        Color = ColorSequence.new(c1, c2),
        Rotation = 90,
        Parent = bar,
    })
    return bar, grad
end

-- ── Gradient helper ────────────────────────────────────────
function VS.Gradient(frame, opts)
    opts = opts or {}
    local existing = frame:FindFirstChildOfClass("UIGradient")
    if existing then existing:Destroy() end
    return Create("UIGradient", {
        Color    = ColorSequence.new(
            opts.color1 or LucidUI.VoidPalette.Accent,
            opts.color2 or LucidUI.VoidPalette.AccentPink
        ),
        Rotation = opts.rotation or 0,
        Parent   = frame,
    })
end

-- ── Void card ──────────────────────────────────────────────
function VS.Card(parent, size, position, opts)
    opts = opts or {}
    local card = Create("Frame", {
        Size = size or UDim2.new(1, 0, 0, 42),
        Position = position or UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = LucidUI.VoidPalette.BgMid,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        LayoutOrder = opts.layoutOrder,
        Parent = parent,
    })
    Corner(opts.radius or 10, card)

    local stroke = Stroke(
        opts.borderColor or LucidUI.VoidPalette.BorderDim,
        opts.borderThickness or 1,
        opts.borderTransparency or 0.15,
        card
    )

    VS.Gradient(card, {
        color1 = LucidUI.VoidPalette.BgMid,
        color2 = LucidUI.VoidPalette.BgLight,
        rotation = 90,
    })

    local bar = VS.AccentBar(card, opts)

    return card, stroke, bar
end

-- ── Value label ────────────────────────────────────────────
function VS.ValueLabel(parent, text, color)
    return Create("TextLabel", {
        Text = text or "",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = color or LucidUI.VoidPalette.Accent,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Size = UDim2.new(1, -24, 1, 0),
        ZIndex = 5,
        Parent = parent,
    })
end

-- ── Hover glow ─────────────────────────────────────────────
function VS.HoverGlow(element)
    local glow = Stroke(LucidUI.VoidPalette.Accent, 1.5, 1, element)
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

-- ── Shine pass (a one-shot sweep across a frame on demand) ─
function VS.ShinePass(frame, opts)
    opts = opts or {}
    local duration = opts.duration or 0.55
    local color    = opts.color or Color3.fromRGB(255, 255, 255)

    local shine = Create("Frame", {
        Name = "VoidShinePass",
        Size = UDim2.new(0.4, 0, 1, 0),
        Position = UDim2.new(-0.4, 0, 0, 0),
        BackgroundColor3 = color,
        BackgroundTransparency = 0.65,
        BorderSizePixel = 0,
        ZIndex = opts.zIndex or 6,
        Parent = frame,
    })
    Corner(4, shine)
    local grad = Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.0, 1.0),
            NumberSequenceKeypoint.new(0.5, 0.0),
            NumberSequenceKeypoint.new(1.0, 1.0),
        }),
        Rotation = 0,
        Parent = shine,
    })

    local t = TweenService:Create(
        shine,
        TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Position = UDim2.new(1.0, 0, 0, 0) }
    )
    t:Play()
    t.Completed:Connect(function()
        pcall(function() shine:Destroy() end)
    end)
end

-- ── Divider ────────────────────────────────────────────────
function VS.Divider(parent, opts)
    opts = opts or {}
    local line = Create("Frame", {
        Size = opts.size or UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = opts.color or LucidUI.VoidPalette.BorderDim,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = parent,
    })
    local grad = Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.0, 1.0),
            NumberSequenceKeypoint.new(0.5, 0.0),
            NumberSequenceKeypoint.new(1.0, 1.0),
        }),
        Rotation = 0,
        Parent = line,
    })
    return line, grad
end

-- ============================================================
-- 7. Window hooks
-- ============================================================
local _origCreateWindow = LucidUI.CreateWindow
function LucidUI:CreateWindow(config)
    config = config or {}

    -- Auto-select Void theme if VoidStyle is requested without a theme
    if config.VoidStyle and not config.Theme then
        config.Theme = "Void"
    end

    local W = _origCreateWindow(self, config)

    -- Default opts: all enhancements ON when VoidStyle is set,
    -- otherwise glass tint + ambient glow ON by default too
    -- (users can opt out per-window with `false`).
    local enhanceGlass  = config.EnhanceGlass
    local ambientGlow   = config.AmbientGlow
    local animatedBord  = config.AnimatedBorder

    if config.VoidStyle then
        if enhanceGlass  == nil then enhanceGlass  = true  end
        if ambientGlow   == nil then ambientGlow   = true  end
        if animatedBord  == nil then animatedBord  = true  end
    else
        -- Non-VoidStyle windows still get glass tint by default
        if enhanceGlass  == nil then enhanceGlass  = true  end
        if ambientGlow   == nil then ambientGlow   = false end
        if animatedBord  == nil then animatedBord  = false end
    end

    W._voidEnhance = {
        EnhanceGlass   = enhanceGlass,
        AmbientGlow    = ambientGlow,
        AnimatedBorder = animatedBord,
        GlowIntensity  = config.GlowIntensity or 1.0,
        GlowPulse      = config.GlowPulse ~= false,
        gradientSweep  = config.GradientSweep ~= false,
    }

    -- Apply after entrance so W.Main is guaranteed visible
    task.defer(function()
        if not (W.Main and W.Main.Parent) then return end

        if W._voidEnhance.EnhanceGlass then
            pcall(function()
                enhanceGlassLayers(W.Main, W.Theme, W._voidEnhance)
            end)
        end

        if W._voidEnhance.AmbientGlow then
            pcall(function()
                buildAmbientGlow(W, W.Theme, W._voidEnhance)
            end)
        end

        if W._voidEnhance.AnimatedBorder then
            pcall(function()
                buildAnimatedBorder(W, W.Theme, W._voidEnhance)
            end)
        end
    end)

    return W
end

-- ============================================================
-- 8. Re-apply enhancements on runtime theme change
-- ============================================================
local _origSetThemeObject = LucidUI.Window.SetThemeObject
function LucidUI.Window:SetThemeObject(t)
    _origSetThemeObject(self, t)

    if not self._voidEnhance then return end
    local opts = self._voidEnhance

    if opts.EnhanceGlass and self.Main then
        pcall(function()
            enhanceGlassLayers(self.Main, t, opts)
        end)
    end

    if opts.AmbientGlow and self._ambientGlowLayers then
        -- Retint the glow layers to the new accent
        for _, layer in ipairs(self._ambientGlowLayers) do
            if layer.frame and layer.frame.Parent then
                layer.frame.BackgroundColor3 = t.Accent or Color3.fromRGB(130, 80, 255)
            end
        end
    end

    if opts.AnimatedBorder and self._animatedBorder and self._animatedBorder.Parent then
        local accent = t.Accent or Color3.fromRGB(130, 80, 255)
        local accent2 = lighten(accent, 0.3)
        self._animatedBorder.Color = accent
        if self._animatedBorderGrad then
            self._animatedBorderGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0,    accent),
                ColorSequenceKeypoint.new(0.35, accent2),
                ColorSequenceKeypoint.new(0.65, accent),
                ColorSequenceKeypoint.new(1,    accent2),
            })
        end
    end
end

-- ============================================================
-- 9. Cleanup hook (destroys the glow ring when window goes away)
-- ============================================================
local _origWindowDestroy = LucidUI.Window.Destroy
function LucidUI.Window:Destroy()
    if self._ambientGlow and self._ambientGlow.Parent then
        pcall(function() self._ambientGlow:Destroy() end)
    end
    self._ambientGlow = nil
    self._ambientGlowLayers = nil

    if self._animatedBorder and self._animatedBorder.Parent then
        pcall(function() self._animatedBorder:Destroy() end)
    end
    self._animatedBorder = nil
    self._animatedBorderGrad = nil

    _origWindowDestroy(self)
end

-- ============================================================
-- 10. Global cleanup registration
-- ============================================================
LucidUI:OnCleanup(function()
    -- Any window-level cleanup already handled by Destroy(),
    -- this is just the module-level hook.
    print("[LucidUI] VoidStyle cleaned up")
end)

-- ============================================================
-- 11. Public API
-- ============================================================
function LucidUI.EnhanceGlass(frame, theme, opts)
    enhanceGlassLayers(frame, theme or LucidUI._lastTheme, opts or {})
end

function LucidUI:ApplyVoidStyle(window)
    if not window or not window.Main then return false end
    window._voidEnhance = window._voidEnhance or {
        EnhanceGlass = true, AmbientGlow = true, AnimatedBorder = true,
        GlowIntensity = 1.0, GlowPulse = true, gradientSweep = true,
    }
    pcall(function() enhanceGlassLayers(window.Main, window.Theme, window._voidEnhance) end)
    pcall(function() buildAmbientGlow(window, window.Theme, window._voidEnhance) end)
    if window._voidEnhance.AnimatedBorder then
        pcall(function() buildAnimatedBorder(window, window.Theme, window._voidEnhance) end)
    end
    return true
end

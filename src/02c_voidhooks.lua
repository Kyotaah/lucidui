-- ============================================================
-- Module: 02c_void_hooks.lua
-- ============================================================
--[[
    VoidStyle window hooks — installed AFTER 06_window.lua defines
    LucidUI.CreateWindow, LucidUI.Window.SetThemeObject, and
    LucidUI.Window.Destroy.

    Must load immediately after 06_window.lua in build order.

    Adds:
      • CreateWindow hook — applies VoidStyle theme + enhancements
      • SetThemeObject hook — re-tints glow ring + animated border
        when the theme changes at runtime
      • Destroy hook — cleans up the glow ring + animated border

    NO tracking. NO network. NO clipboard.
]]

-- Guard: bail if 06_window hasn't loaded yet
if not LucidUI or not LucidUI.CreateWindow or not LucidUI.Window then
    warn("[LucidUI] VoidHooks: 06_window not loaded — skipping")
    return
end

-- ============================================================
-- 1. CreateWindow hook
-- ============================================================
local _origCreateWindow = LucidUI.CreateWindow
function LucidUI:CreateWindow(config)
    config = config or {}

    -- Auto-select Void theme if VoidStyle is requested without a theme
    if config.VoidStyle and not config.Theme then
        config.Theme = "Void"
    end

    local W = _origCreateWindow(self, config)

    -- Resolve enhancement flags
    local enhanceGlass = config.EnhanceGlass
    local ambientGlow  = config.AmbientGlow
    local animatedBord = config.AnimatedBorder

    if config.VoidStyle then
        if enhanceGlass == nil then enhanceGlass = true end
        if ambientGlow  == nil then ambientGlow  = true end
        if animatedBord == nil then animatedBord = true end
    else
        if enhanceGlass == nil then enhanceGlass = true  end
        if ambientGlow  == nil then ambientGlow  = false end
        if animatedBord == nil then animatedBord = false end
    end

    W._voidEnhance = {
        EnhanceGlass   = enhanceGlass,
        AmbientGlow    = ambientGlow,
        AnimatedBorder = animatedBord,
        GlowIntensity  = config.GlowIntensity or 1.0,
        GlowPulse      = config.GlowPulse ~= false,
        gradientSweep  = config.GradientSweep ~= false,
    }

    task.defer(function()
        if not (W.Main and W.Main.Parent) then return end

        if W._voidEnhance.EnhanceGlass and LucidUI.EnhanceGlass then
            pcall(function()
                LucidUI.EnhanceGlass(W.Main, W.Theme, W._voidEnhance)
            end)
        end

        if W._voidEnhance.AmbientGlow and LucidUI._BuildAmbientGlow then
            pcall(function()
                LucidUI._BuildAmbientGlow(W, W.Theme, W._voidEnhance)
            end)
        end

        if W._voidEnhance.AnimatedBorder and LucidUI._BuildAnimatedBorder then
            pcall(function()
                LucidUI._BuildAnimatedBorder(W, W.Theme, W._voidEnhance)
            end)
        end
    end)

    return W
end

-- ============================================================
-- 2. SetThemeObject hook — retint on runtime theme change
-- ============================================================
local _origSetThemeObject = LucidUI.Window.SetThemeObject
function LucidUI.Window:SetThemeObject(t)
    _origSetThemeObject(self, t)

    if not self._voidEnhance then return end
    local opts = self._voidEnhance

    if opts.EnhanceGlass and self.Main and LucidUI.EnhanceGlass then
        pcall(function()
            LucidUI.EnhanceGlass(self.Main, t, opts)
        end)
    end

    if opts.AmbientGlow and self._ambientGlowLayers then
        for _, layer in ipairs(self._ambientGlowLayers) do
            if layer.frame and layer.frame.Parent then
                layer.frame.BackgroundColor3 = t.Accent or Color3.fromRGB(130, 80, 255)
            end
        end
    end

    if opts.AnimatedBorder and self._animatedBorder and self._animatedBorder.Parent then
        local accent  = t.Accent or Color3.fromRGB(130, 80, 255)
        local accent2 = Color3.new(
            math.min(accent.R + 0.3, 1),
            math.min(accent.G + 0.3, 1),
            math.min(accent.B + 0.3, 1)
        )
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
-- 3. Destroy hook — cleanup glow ring + animated border
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
-- 4. Cleanup registration
-- ============================================================
LucidUI:OnCleanup(function()
    print("[LucidUI] VoidHooks cleaned up")
end)

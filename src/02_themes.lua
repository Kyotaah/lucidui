--[[
    Themes — the shipped Default theme, the list of user-editable colors,
    and the derivation function that expands 6 user colors into a full
    theme table with all the secondary values LucidUI needs.
]]

-- ============================================================
-- Library root table (shared across every module)
-- ============================================================
LucidUI          = LucidUI or {}
LucidUI._version = "0.9.0"
LucidUI._windows = LucidUI._windows or {}

-- ============================================================
-- Default theme
-- ============================================================
local DefaultTheme = {
    Background           = Color3.fromRGB(28, 28, 30),
    BackgroundTrans      = 0.20,

    Surface              = Color3.fromRGB(58, 58, 60),
    SurfaceTrans         = 0.35,
    SurfaceHover         = Color3.fromRGB(68, 68, 72),
    SurfaceHoverTrans    = 0.20,

    Border               = Color3.fromRGB(255, 255, 255),
    BorderTrans          = 0.85,

    Accent               = Color3.fromRGB(10, 132, 255),

    TextPrimary          = Color3.fromRGB(255, 255, 255),
    TextSecondary        = Color3.fromRGB(235, 235, 245),
    TextMuted            = Color3.fromRGB(152, 152, 160),

    ToggleOff            = Color3.fromRGB(90, 90, 95),
    SliderTrack          = Color3.fromRGB(90, 90, 95),

    TabActive            = Color3.fromRGB(255, 255, 255),
    TabInactive          = Color3.fromRGB(152, 152, 160),
}

LucidUI.Themes = {
    Default = DefaultTheme,
}

-- ============================================================
-- Editable colors shown in the Custom Theme editor
-- ============================================================
local EDITABLE_COLORS = {
    { key = "Background",   label = "Background"    },
    { key = "Surface",      label = "Surface"       },
    { key = "SurfaceHover", label = "Surface Hover" },
    { key = "Accent",       label = "Accent"        },
    { key = "Border",       label = "Border"        },
    { key = "TextPrimary",  label = "Text"          },
}

-- ============================================================
-- Derive a full theme from 6 user colors
-- ============================================================
local function DeriveTheme(custom)
    local t = {}
    for k, v in pairs(DefaultTheme) do t[k] = v end

    for _, f in ipairs(EDITABLE_COLORS) do
        if custom[f.key] then t[f.key] = custom[f.key] end
    end

    -- SurfaceHover — brighten the Surface slightly
    if not custom.SurfaceHover then
        t.SurfaceHover = Color3.new(
            math.min(t.Surface.R + 0.10, 1),
            math.min(t.Surface.G + 0.10, 1),
            math.min(t.Surface.B + 0.10, 1)
        )
    end

    -- TextSecondary — a slightly dimmer version of TextPrimary
    t.TextSecondary = Color3.new(
        math.min(t.TextPrimary.R * 0.92, 1),
        math.min(t.TextPrimary.G * 0.92, 1),
        math.min(t.TextPrimary.B * 0.92, 1)
    )

    -- TextMuted — midpoint between text and background
    t.TextMuted = Color3.new(
        (t.TextPrimary.R + t.Background.R) * 0.5,
        (t.TextPrimary.G + t.Background.G) * 0.5,
        (t.TextPrimary.B + t.Background.B) * 0.5
    )

    -- Reuse surface for toggles and slider tracks so they blend
    t.ToggleOff   = t.Surface
    t.SliderTrack = t.Surface

    -- Tab colors
    t.TabActive   = t.TextPrimary
    t.TabInactive = t.TextMuted

    return t
end

-- ============================================================
-- Fresh custom theme from the current theme
-- ============================================================
local function NewCustomTheme(fromTheme)
    fromTheme = fromTheme or DefaultTheme
    return {
        Background   = fromTheme.Background,
        Surface      = fromTheme.Surface,
        SurfaceHover = fromTheme.SurfaceHover,
        Accent       = fromTheme.Accent,
        Border       = fromTheme.Border,
        TextPrimary  = fromTheme.TextPrimary,
    }
end

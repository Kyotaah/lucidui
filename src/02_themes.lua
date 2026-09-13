--[[
    Themes — ships with 6 presets plus derivation logic.
]]

LucidUI          = LucidUI or {}
LucidUI._version = "0.9.0"
LucidUI._windows = LucidUI._windows or {}

-- ============================================================
-- Presets
-- ============================================================
LucidUI.Themes = {
    Default = {
        Background=Color3.fromRGB(28,28,30), BackgroundTrans=0.20,
        Surface=Color3.fromRGB(58,58,60),    SurfaceTrans=0.35,
        SurfaceHover=Color3.fromRGB(68,68,72), SurfaceHoverTrans=0.20,
        Border=Color3.fromRGB(255,255,255),  BorderTrans=0.85,
        Accent=Color3.fromRGB(10,132,255),
        TextPrimary=Color3.fromRGB(255,255,255),
        TextSecondary=Color3.fromRGB(235,235,245),
        TextMuted=Color3.fromRGB(152,152,160),
        ToggleOff=Color3.fromRGB(90,90,95),
        SliderTrack=Color3.fromRGB(90,90,95),
        TabActive=Color3.fromRGB(255,255,255),
        TabInactive=Color3.fromRGB(152,152,160),
    },
    Light = {
        Background=Color3.fromRGB(245,245,250), BackgroundTrans=0.10,
        Surface=Color3.fromRGB(255,255,255),    SurfaceTrans=0.15,
        SurfaceHover=Color3.fromRGB(230,230,235), SurfaceHoverTrans=0.05,
        Border=Color3.fromRGB(0,0,0),           BorderTrans=0.88,
        Accent=Color3.fromRGB(0,122,255),
        TextPrimary=Color3.fromRGB(0,0,0),
        TextSecondary=Color3.fromRGB(60,60,67),
        TextMuted=Color3.fromRGB(142,142,147),
        ToggleOff=Color3.fromRGB(209,209,214),
        SliderTrack=Color3.fromRGB(209,209,214),
        TabActive=Color3.fromRGB(0,0,0),
        TabInactive=Color3.fromRGB(142,142,147),
    },
    Nebula = {
        Background=Color3.fromRGB(24,16,48), BackgroundTrans=0.15,
        Surface=Color3.fromRGB(52,36,96),    SurfaceTrans=0.30,
        SurfaceHover=Color3.fromRGB(72,50,130), SurfaceHoverTrans=0.15,
        Border=Color3.fromRGB(180,140,255),  BorderTrans=0.80,
        Accent=Color3.fromRGB(160,100,255),
        TextPrimary=Color3.fromRGB(255,255,255),
        TextSecondary=Color3.fromRGB(210,190,255),
        TextMuted=Color3.fromRGB(150,130,200),
        ToggleOff=Color3.fromRGB(70,50,120),
        SliderTrack=Color3.fromRGB(70,50,120),
        TabActive=Color3.fromRGB(255,255,255),
        TabInactive=Color3.fromRGB(150,130,200),
    },
    Midnight = {
        Background=Color3.fromRGB(12,12,20), BackgroundTrans=0.15,
        Surface=Color3.fromRGB(30,30,45),    SurfaceTrans=0.25,
        SurfaceHover=Color3.fromRGB(45,45,65), SurfaceHoverTrans=0.15,
        Border=Color3.fromRGB(90,90,140),    BorderTrans=0.75,
        Accent=Color3.fromRGB(120,180,255),
        TextPrimary=Color3.fromRGB(230,230,245),
        TextSecondary=Color3.fromRGB(180,180,210),
        TextMuted=Color3.fromRGB(110,110,140),
        ToggleOff=Color3.fromRGB(50,50,75),
        SliderTrack=Color3.fromRGB(50,50,75),
        TabActive=Color3.fromRGB(230,230,245),
        TabInactive=Color3.fromRGB(110,110,140),
    },
    Dracula = {
        Background=Color3.fromRGB(40,42,54), BackgroundTrans=0.15,
        Surface=Color3.fromRGB(68,71,90),    SurfaceTrans=0.30,
        SurfaceHover=Color3.fromRGB(80,83,105), SurfaceHoverTrans=0.15,
        Border=Color3.fromRGB(189,147,249),  BorderTrans=0.75,
        Accent=Color3.fromRGB(189,147,249),
        TextPrimary=Color3.fromRGB(248,248,242),
        TextSecondary=Color3.fromRGB(220,220,220),
        TextMuted=Color3.fromRGB(139,143,167),
        ToggleOff=Color3.fromRGB(68,71,90),
        SliderTrack=Color3.fromRGB(68,71,90),
        TabActive=Color3.fromRGB(248,248,242),
        TabInactive=Color3.fromRGB(139,143,167),
    },
    TokyoNight = {
        Background=Color3.fromRGB(26,27,38), BackgroundTrans=0.15,
        Surface=Color3.fromRGB(36,40,59),    SurfaceTrans=0.25,
        SurfaceHover=Color3.fromRGB(45,50,72), SurfaceHoverTrans=0.15,
        Border=Color3.fromRGB(122,162,247),  BorderTrans=0.75,
        Accent=Color3.fromRGB(122,162,247),
        TextPrimary=Color3.fromRGB(192,202,245),
        TextSecondary=Color3.fromRGB(160,170,210),
        TextMuted=Color3.fromRGB(86,95,137),
        ToggleOff=Color3.fromRGB(45,50,72),
        SliderTrack=Color3.fromRGB(45,50,72),
        TabActive=Color3.fromRGB(192,202,245),
        TabInactive=Color3.fromRGB(86,95,137),
    },
    Forest = {
        Background=Color3.fromRGB(20,30,24), BackgroundTrans=0.15,
        Surface=Color3.fromRGB(30,48,36),    SurfaceTrans=0.25,
        SurfaceHover=Color3.fromRGB(42,66,50), SurfaceHoverTrans=0.15,
        Border=Color3.fromRGB(120,200,140),  BorderTrans=0.75,
        Accent=Color3.fromRGB(120,200,140),
        TextPrimary=Color3.fromRGB(230,240,232),
        TextSecondary=Color3.fromRGB(200,215,205),
        TextMuted=Color3.fromRGB(110,130,115),
        ToggleOff=Color3.fromRGB(42,66,50),
        SliderTrack=Color3.fromRGB(42,66,50),
        TabActive=Color3.fromRGB(230,240,232),
        TabInactive=Color3.fromRGB(110,130,115),
    },
}

-- ============================================================
-- Editable colors for the Custom Theme editor
-- ============================================================
local EDITABLE_COLORS = {
    { key = "Background",   label = "Background"    },
    { key = "Surface",      label = "Surface"       },
    { key = "SurfaceHover", label = "Surface Hover" },
    { key = "Accent",       label = "Accent"        },
    { key = "Border",       label = "Border"        },
    { key = "TextPrimary",  label = "Text"          },
}

local function DeriveTheme(custom)
    local base = LucidUI.Themes.Default
    local t = {}
    for k, v in pairs(base) do t[k] = v end

    for _, f in ipairs(EDITABLE_COLORS) do
        if custom[f.key] then t[f.key] = custom[f.key] end
    end

    if not custom.SurfaceHover then
        t.SurfaceHover = Color3.new(
            math.min(t.Surface.R + 0.10, 1),
            math.min(t.Surface.G + 0.10, 1),
            math.min(t.Surface.B + 0.10, 1)
        )
    end

    t.TextSecondary = Color3.new(
        math.min(t.TextPrimary.R * 0.92, 1),
        math.min(t.TextPrimary.G * 0.92, 1),
        math.min(t.TextPrimary.B * 0.92, 1)
    )
    t.TextMuted = Color3.new(
        (t.TextPrimary.R + t.Background.R) * 0.5,
        (t.TextPrimary.G + t.Background.G) * 0.5,
        (t.TextPrimary.B + t.Background.B) * 0.5
    )
    t.ToggleOff   = t.Surface
    t.SliderTrack = t.Surface
    t.TabActive   = t.TextPrimary
    t.TabInactive = t.TextMuted
    return t
end

local function NewCustomTheme(fromTheme)
    fromTheme = fromTheme or LucidUI.Themes.Default
    return {
        Background   = fromTheme.Background,
        Surface      = fromTheme.Surface,
        SurfaceHover = fromTheme.SurfaceHover,
        Accent       = fromTheme.Accent,
        Border       = fromTheme.Border,
        TextPrimary  = fromTheme.TextPrimary,
    }
end

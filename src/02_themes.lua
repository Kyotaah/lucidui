--[[
    Themes — preset palettes and the custom theme derivation.

    Roster (17):
      Default, Light, Nebula, Midnight, Dracula, Tokyo Night, Forest,
      Catppuccin Mocha, Catppuccin Latte, Nord, Gruvbox, Rosé Pine,
      One Dark, Synthwave '84, Solarized Dark, Ayu Mirage, Kanagawa
]]

getgenv().LucidUI = getgenv().LucidUI or {}
LucidUI = getgenv().LucidUI
LucidUI._version = "0.10.0"
LucidUI._windows = LucidUI._windows or {}

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
    ["Tokyo Night"] = {
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
    ["Catppuccin Mocha"] = {
        Background=Color3.fromRGB(30,30,46), BackgroundTrans=0.15,
        Surface=Color3.fromRGB(49,50,68),    SurfaceTrans=0.25,
        SurfaceHover=Color3.fromRGB(69,71,90), SurfaceHoverTrans=0.15,
        Border=Color3.fromRGB(137,180,250),  BorderTrans=0.75,
        Accent=Color3.fromRGB(137,180,250),
        TextPrimary=Color3.fromRGB(205,214,244),
        TextSecondary=Color3.fromRGB(186,194,222),
        TextMuted=Color3.fromRGB(127,132,156),
        ToggleOff=Color3.fromRGB(69,71,90),
        SliderTrack=Color3.fromRGB(69,71,90),
        TabActive=Color3.fromRGB(205,214,244),
        TabInactive=Color3.fromRGB(127,132,156),
    },
    ["Catppuccin Latte"] = {
        Background=Color3.fromRGB(230,233,239), BackgroundTrans=0.10,
        Surface=Color3.fromRGB(255,255,255),    SurfaceTrans=0.15,
        SurfaceHover=Color3.fromRGB(220,224,232), SurfaceHoverTrans=0.05,
        Border=Color3.fromRGB(30,102,245),      BorderTrans=0.85,
        Accent=Color3.fromRGB(30,102,245),
        TextPrimary=Color3.fromRGB(76,79,105),
        TextSecondary=Color3.fromRGB(92,95,119),
        TextMuted=Color3.fromRGB(140,143,161),
        ToggleOff=Color3.fromRGB(188,192,204),
        SliderTrack=Color3.fromRGB(188,192,204),
        TabActive=Color3.fromRGB(76,79,105),
        TabInactive=Color3.fromRGB(140,143,161),
    },
    Nord = {
        Background=Color3.fromRGB(46,52,64), BackgroundTrans=0.15,
        Surface=Color3.fromRGB(59,66,82),    SurfaceTrans=0.25,
        SurfaceHover=Color3.fromRGB(67,76,94), SurfaceHoverTrans=0.15,
        Border=Color3.fromRGB(136,192,208),  BorderTrans=0.75,
        Accent=Color3.fromRGB(136,192,208),
        TextPrimary=Color3.fromRGB(216,222,233),
        TextSecondary=Color3.fromRGB(190,197,210),
        TextMuted=Color3.fromRGB(129,161,193),
        ToggleOff=Color3.fromRGB(67,76,94),
        SliderTrack=Color3.fromRGB(67,76,94),
        TabActive=Color3.fromRGB(216,222,233),
        TabInactive=Color3.fromRGB(129,161,193),
    },
    Gruvbox = {
        Background=Color3.fromRGB(40,40,40), BackgroundTrans=0.15,
        Surface=Color3.fromRGB(60,56,54),    SurfaceTrans=0.25,
        SurfaceHover=Color3.fromRGB(80,73,69), SurfaceHoverTrans=0.15,
        Border=Color3.fromRGB(215,153,33),   BorderTrans=0.75,
        Accent=Color3.fromRGB(250,189,47),
        TextPrimary=Color3.fromRGB(235,219,178),
        TextSecondary=Color3.fromRGB(213,196,161),
        TextMuted=Color3.fromRGB(146,131,116),
        ToggleOff=Color3.fromRGB(80,73,69),
        SliderTrack=Color3.fromRGB(80,73,69),
        TabActive=Color3.fromRGB(235,219,178),
        TabInactive=Color3.fromRGB(146,131,116),
    },
    ["Rosé Pine"] = {
        Background=Color3.fromRGB(25,23,36), BackgroundTrans=0.15,
        Surface=Color3.fromRGB(31,29,46),    SurfaceTrans=0.25,
        SurfaceHover=Color3.fromRGB(38,35,58), SurfaceHoverTrans=0.15,
        Border=Color3.fromRGB(196,167,231),  BorderTrans=0.75,
        Accent=Color3.fromRGB(196,167,231),
        TextPrimary=Color3.fromRGB(224,222,244),
        TextSecondary=Color3.fromRGB(200,197,222),
        TextMuted=Color3.fromRGB(110,106,134),
        ToggleOff=Color3.fromRGB(38,35,58),
        SliderTrack=Color3.fromRGB(38,35,58),
        TabActive=Color3.fromRGB(224,222,244),
        TabInactive=Color3.fromRGB(110,106,134),
    },
    ["One Dark"] = {
        Background=Color3.fromRGB(40,44,52), BackgroundTrans=0.15,
        Surface=Color3.fromRGB(53,59,69),    SurfaceTrans=0.25,
        SurfaceHover=Color3.fromRGB(67,72,82), SurfaceHoverTrans=0.15,
        Border=Color3.fromRGB(97,175,239),   BorderTrans=0.75,
        Accent=Color3.fromRGB(97,175,239),
        TextPrimary=Color3.fromRGB(171,178,191),
        TextSecondary=Color3.fromRGB(155,162,175),
        TextMuted=Color3.fromRGB(92,99,112),
        ToggleOff=Color3.fromRGB(67,72,82),
        SliderTrack=Color3.fromRGB(67,72,82),
        TabActive=Color3.fromRGB(171,178,191),
        TabInactive=Color3.fromRGB(92,99,112),
    },
    ["Synthwave '84"] = {
        Background=Color3.fromRGB(38,35,53), BackgroundTrans=0.15,
        Surface=Color3.fromRGB(52,41,79),    SurfaceTrans=0.25,
        SurfaceHover=Color3.fromRGB(69,53,107), SurfaceHoverTrans=0.15,
        Border=Color3.fromRGB(255,126,219),  BorderTrans=0.75,
        Accent=Color3.fromRGB(255,126,219),
        TextPrimary=Color3.fromRGB(244,238,228),
        TextSecondary=Color3.fromRGB(220,214,205),
        TextMuted=Color3.fromRGB(132,120,163),
        ToggleOff=Color3.fromRGB(69,53,107),
        SliderTrack=Color3.fromRGB(69,53,107),
        TabActive=Color3.fromRGB(244,238,228),
        TabInactive=Color3.fromRGB(132,120,163),
    },
    ["Solarized Dark"] = {
        Background=Color3.fromRGB(0,43,54), BackgroundTrans=0.15,
        Surface=Color3.fromRGB(7,54,66),    SurfaceTrans=0.25,
        SurfaceHover=Color3.fromRGB(20,68,82), SurfaceHoverTrans=0.15,
        Border=Color3.fromRGB(38,139,210),  BorderTrans=0.75,
        Accent=Color3.fromRGB(38,139,210),
        TextPrimary=Color3.fromRGB(147,161,161),
        TextSecondary=Color3.fromRGB(131,148,150),
        TextMuted=Color3.fromRGB(88,110,117),
        ToggleOff=Color3.fromRGB(20,68,82),
        SliderTrack=Color3.fromRGB(20,68,82),
        TabActive=Color3.fromRGB(147,161,161),
        TabInactive=Color3.fromRGB(88,110,117),
    },
    ["Ayu Mirage"] = {
        Background=Color3.fromRGB(31,36,48), BackgroundTrans=0.15,
        Surface=Color3.fromRGB(36,41,54),    SurfaceTrans=0.25,
        SurfaceHover=Color3.fromRGB(45,51,67), SurfaceHoverTrans=0.15,
        Border=Color3.fromRGB(255,180,84),   BorderTrans=0.75,
        Accent=Color3.fromRGB(255,180,84),
        TextPrimary=Color3.fromRGB(203,204,198),
        TextSecondary=Color3.fromRGB(178,180,175),
        TextMuted=Color3.fromRGB(112,122,140),
        ToggleOff=Color3.fromRGB(45,51,67),
        SliderTrack=Color3.fromRGB(45,51,67),
        TabActive=Color3.fromRGB(203,204,198),
        TabInactive=Color3.fromRGB(112,122,140),
    },
    Kanagawa = {
        Background=Color3.fromRGB(22,22,29), BackgroundTrans=0.15,
        Surface=Color3.fromRGB(42,42,55),    SurfaceTrans=0.25,
        SurfaceHover=Color3.fromRGB(60,60,75), SurfaceHoverTrans=0.15,
        Border=Color3.fromRGB(126,156,216),  BorderTrans=0.75,
        Accent=Color3.fromRGB(126,156,216),
        TextPrimary=Color3.fromRGB(220,215,186),
        TextSecondary=Color3.fromRGB(200,192,147),
        TextMuted=Color3.fromRGB(114,113,105),
        ToggleOff=Color3.fromRGB(60,60,75),
        SliderTrack=Color3.fromRGB(60,60,75),
        TabActive=Color3.fromRGB(220,215,186),
        TabInactive=Color3.fromRGB(114,113,105),
    },
}

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

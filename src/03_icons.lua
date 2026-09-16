--[[
    Icons — frame-based builders. All visuals are constructed from
    Frames/Rects so they render identically on any device.

    [IMPROVEMENT] Centralized icon registry (LucidUI.IconBuilders) so
    every icon — gear, dot, bars, home, sword, etc. — lives in one
    place. BuildIcon() is a unified entry point. Added 6 new icons:
    warning, info, search, refresh, trash, download.

    BuildGearIcon returns (holder, spinTarget, parts, hole):
      holder     — the 18×18 container parented to the button
      spinTarget — the object whose .Rotation should be animated.
                   This is the HOLDER, not the ring. Rotating the
                   ring alone does nothing visible because a circle
                   looks the same at every angle, and the teeth are
                   siblings of the ring, not children.
      parts      — array of all colored frames (for theme tweens)
      hole       — the center cutout frame

    The parts array also has a :SetColor(color) method for convenience.
]]

local function IconHolder(parent, size)
    return Create("Frame", {
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        Parent = parent,
    })
end

-- ============================================================
-- [IMPROVEMENT] Helper: attach a SetColor method to a parts array
-- ============================================================
local function AttachSetColor(parts, strokes)
    strokes = strokes or {}

    -- [FIX] Copy parts into the API table with numeric indices so
    -- ipairs() works on it directly. The previous setmetatable
    -- approach broke ipairs(), so the theme system couldn't
    -- recolor icons when the theme changed.
    local api = {}
    for i, p in ipairs(parts) do
        api[i] = p
    end
    api.__parts   = parts
    api.__strokes = strokes

    function api:SetColor(color)
        for _, p in ipairs(parts) do
            if p and p.Parent then
                if p:IsA("UIStroke") then
                    p.Color = color
                elseif p:IsA("GuiObject") then
                    p.BackgroundColor3 = color
                end
            end
        end
        for _, s in ipairs(strokes) do
            if s and s.Parent then s.Color = color end
        end
    end

    return api
end

-- ============================================================
-- Gear (settings) — 8 rounded teeth + solid ring + center hole
-- ============================================================
function BuildGearIcon(parent, size, color, holeColor, opts)
    opts = opts or {}
    size = size or 18

    local holder = IconHolder(parent, size)
    local parts  = {}
    local strokes = {}

    local ringDiameter = size * 0.70
    local ringRadius   = ringDiameter / 2
    local toothLen     = size * 0.22
    local toothWid     = size * 0.20
    local toothDist    = ringRadius + toothLen * 0.15
    local teethCount   = 8

    -- Teeth sit behind the ring so their inner ends tuck under it
    for i = 1, teethCount do
        local angle = (i - 1) * (360 / teethCount)
        local rad   = math.rad(angle - 90)
        local px    = 0.5 + (toothDist / size) * math.cos(rad)
        local py    = 0.5 + (toothDist / size) * math.sin(rad)

        local tooth = Create("Frame", {
            Size             = UDim2.fromOffset(toothWid, toothLen),
            Position         = UDim2.fromScale(px, py),
            AnchorPoint      = Vector2.new(0.5, 0.5),
            Rotation         = angle,
            BackgroundColor3 = color,
            BorderSizePixel  = 0,
            Parent           = holder,
        })
        Corner(toothWid * 0.35, tooth)
        table.insert(parts, tooth)
    end

    -- Main ring on top of teeth
    local ring = Create("Frame", {
        Size             = UDim2.fromOffset(ringDiameter, ringDiameter),
        Position         = UDim2.fromScale(0.5, 0.5),
        AnchorPoint      = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel  = 0,
        Parent           = holder,
    })
    Corner(999, ring)
    table.insert(parts, ring)

    -- Center hole
    local holeSize = ringDiameter * 0.36
    local hole = Create("Frame", {
        Size             = UDim2.fromOffset(holeSize, holeSize),
        Position         = UDim2.fromScale(0.5, 0.5),
        AnchorPoint      = Vector2.new(0.5, 0.5),
        BackgroundColor3 = holeColor or Color3.fromRGB(28, 28, 30),
        BorderSizePixel  = 0,
        Parent           = ring,
    })
    Corner(999, hole)

    -- [IMPROVEMENT] Optional notification badge dot.
    local badge
    if opts.badge then
        badge = Create("Frame", {
            Name = "GearBadge",
            Size = UDim2.fromOffset(math.max(size * 0.28, 6), math.max(size * 0.28, 6)),
            Position = UDim2.new(1, -size * 0.18, 0, -size * 0.05),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(255, 95, 87),
            BorderSizePixel = 0,
            ZIndex = 2,
            Parent = holder,
        })
        Corner(999, badge)
        table.insert(parts, badge)
    end

    -- Return the holder as the spin target so the whole gear
    -- (ring + teeth + hole) rotates as one unit.
    return holder, holder, AttachSetColor(parts, strokes), hole
end

-- ============================================================
-- [IMPROVEMENT] Unified BuildIcon API + registry
-- ============================================================
LucidUI.IconBuilders = LucidUI.IconBuilders or {}

local IB = LucidUI.IconBuilders

-- Basic shapes
IB.dot = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local dot = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.7, size * 0.7),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(999, dot)
    return holder, AttachSetColor({ dot })
end

IB.bars = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local parts = {}
    for i = 1, 3 do
        local line = Create("Frame", {
            Size = UDim2.fromOffset(size * 0.75, math.max(math.floor(size / 7), 2)),
            Position = UDim2.new(0.5, 0, 0.2 + (i - 1) * 0.3, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Corner(1, line)
        table.insert(parts, line)
    end
    return holder, AttachSetColor(parts)
end

IB.diamond = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local diamond = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.6, size * 0.6),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = 45,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(2, diamond)
    return holder, AttachSetColor({ diamond })
end

IB.cross = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local thickness = math.max(math.floor(size / 7), 2)
    local len = size * 0.8
    local a = Create("Frame", {
        Size = UDim2.fromOffset(len, thickness),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = 45,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, a)
    local b = Create("Frame", {
        Size = UDim2.fromOffset(len, thickness),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = -45,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, b)
    return holder, AttachSetColor({ a, b })
end

IB.plus = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local thickness = math.max(math.floor(size / 7), 2)
    local len = size * 0.8
    local h = Create("Frame", {
        Size = UDim2.fromOffset(len, thickness),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, h)
    local v = Create("Frame", {
        Size = UDim2.fromOffset(thickness, len),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, v)
    return holder, AttachSetColor({ h, v })
end

IB.check = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local thickness = math.max(math.floor(size / 7), 2)
    local short = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.35, thickness),
        Position = UDim2.new(0.35, 0, 0.6, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = 45,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, short)
    local long = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.6, thickness),
        Position = UDim2.new(0.6, 0, 0.45, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = -45,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, long)
    return holder, AttachSetColor({ short, long })
end

IB.shield = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local top = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.85, size * 0.5),
        Position = UDim2.new(0.5, 0, 0, 0),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(size * 0.25, top)
    local bottom = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.55, size * 0.55),
        Position = UDim2.new(0.5, 0, 0, size * 0.35),
        AnchorPoint = Vector2.new(0.5, 0),
        Rotation = 45,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(size * 0.1, bottom)
    return holder, AttachSetColor({ top, bottom })
end

IB.gavel = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local thickness = math.max(math.floor(size / 7), 2)
    local blade = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.55, size * 0.55),
        Position = UDim2.new(0.65, 0, 0.35, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = 45,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(2, blade)
    local handle = Create("Frame", {
        Size = UDim2.fromOffset(thickness, size * 0.6),
        Position = UDim2.new(0.3, 0, 0.7, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = 45,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, handle)
    return holder, AttachSetColor({ blade, handle })
end

IB.star = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local s = size * 0.85
    local h = Create("Frame", {
        Size = UDim2.fromOffset(s, math.max(math.floor(size / 8), 2)),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, h)
    local v = Create("Frame", {
        Size = UDim2.fromOffset(math.max(math.floor(size / 8), 2), s),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, v)
    return holder, AttachSetColor({ h, v })
end

IB.coins = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local outer = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.75, size * 0.75),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(999, outer)
    local inner = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.35, size * 0.35),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        BorderSizePixel = 0,
        Parent = outer,
    })
    Corner(999, inner)
    return holder, AttachSetColor({ outer })
end

IB.person = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local head = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.4, size * 0.4),
        Position = UDim2.new(0.5, 0, 0.05, 0),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(999, head)
    local body = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.75, size * 0.4),
        Position = UDim2.new(0.5, 0, 0.55, 0),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(4, body)
    return holder, AttachSetColor({ head, body })
end

IB.eye = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local oval = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.95, size * 0.6),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(999, oval)
    local stroke = Stroke(color, 1.5, 0, oval)
    local pupil = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.25, size * 0.25),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(999, pupil)
    return holder, AttachSetColor({ pupil }, { stroke })
end

IB.lock = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local thickness = math.max(math.floor(size / 7), 2)
    local leftBar = Create("Frame", {
        Size = UDim2.fromOffset(thickness, size * 0.28),
        Position = UDim2.new(0.32, 0, 0.28, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, leftBar)
    local rightBar = Create("Frame", {
        Size = UDim2.fromOffset(thickness, size * 0.28),
        Position = UDim2.new(0.68, 0, 0.28, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, rightBar)
    local topBar = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.4, thickness),
        Position = UDim2.new(0.5, 0, 0.14, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, topBar)
    local body = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.72, size * 0.5),
        Position = UDim2.new(0.5, 0, 0.68, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(2, body)
    return holder, AttachSetColor({ leftBar, rightBar, topBar, body })
end

IB.unlock = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local thickness = math.max(math.floor(size / 7), 2)
    local topBar = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.4, thickness),
        Position = UDim2.new(0.62, 0, 0.14, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, topBar)
    local rightBar = Create("Frame", {
        Size = UDim2.fromOffset(thickness, size * 0.3),
        Position = UDim2.new(0.78, 0, 0.3, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, rightBar)
    local body = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.72, size * 0.5),
        Position = UDim2.new(0.42, 0, 0.68, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(2, body)
    return holder, AttachSetColor({ topBar, rightBar, body })
end

IB.play = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local thickness = math.max(math.floor(size / 6), 2)
    local len = size * 0.5
    local top = Create("Frame", {
        Size = UDim2.fromOffset(len, thickness),
        Position = UDim2.new(0.42, 0, 0.35, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = -50,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, top)
    local bottom = Create("Frame", {
        Size = UDim2.fromOffset(len, thickness),
        Position = UDim2.new(0.42, 0, 0.65, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = 50,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, bottom)
    return holder, AttachSetColor({ top, bottom })
end

IB.pause = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local left = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.15, size * 0.7),
        Position = UDim2.new(0.32, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, left)
    local right = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.15, size * 0.7),
        Position = UDim2.new(0.68, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, right)
    return holder, AttachSetColor({ left, right })
end

IB.stop = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local sq = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.6, size * 0.6),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(2, sq)
    return holder, AttachSetColor({ sq })
end

IB.bell = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local top = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.15, size * 0.15),
        Position = UDim2.new(0.5, 0, 0.15, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(999, top)
    local body = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.65, size * 0.5),
        Position = UDim2.new(0.5, 0, 0.55, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(size * 0.15, body)
    local base = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.85, math.max(math.floor(size / 8), 2)),
        Position = UDim2.new(0.5, 0, 0.82, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, base)
    return holder, AttachSetColor({ top, body, base })
end

IB.home = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local base = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.65, size * 0.5),
        Position = UDim2.new(0.5, 0, 0.68, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, base)
    local roofL = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.5, math.max(math.floor(size / 7), 2)),
        Position = UDim2.new(0.5, 0, 0.3, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = -45,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, roofL)
    local roofR = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.5, math.max(math.floor(size / 7), 2)),
        Position = UDim2.new(0.5, 0, 0.3, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = 45,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, roofR)
    return holder, AttachSetColor({ base, roofL, roofR })
end

IB.settings = function(parent, size, color)
    local holder, _, parts = BuildGearIcon(parent, size, color, Color3.new(0,0,0))
    return holder, parts
end

IB.sword = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local thickness = math.max(math.floor(size / 8), 2)
    local blade = Create("Frame", {
        Size = UDim2.fromOffset(thickness, size * 0.75),
        Position = UDim2.new(0.6, 0, 0.35, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = 45,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, blade)
    local guard = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.5, thickness),
        Position = UDim2.new(0.42, 0, 0.58, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = 45,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, guard)
    local handle = Create("Frame", {
        Size = UDim2.fromOffset(thickness, size * 0.25),
        Position = UDim2.new(0.28, 0, 0.72, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = 45,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, handle)
    return holder, AttachSetColor({ blade, guard, handle })
end

IB.target = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local ring = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.85, size * 0.85),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(999, ring)
    local stroke = Stroke(color, 1.5, 0, ring)
    local center = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.3, size * 0.3),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(999, center)
    return holder, AttachSetColor({ center }, { stroke })
end

IB.flame = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local base = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.55, size * 0.55),
        Position = UDim2.new(0.5, 0, 0.65, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(size * 0.2, base)
    local tip = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.4, size * 0.5),
        Position = UDim2.new(0.55, 0, 0.32, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = 30,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(size * 0.15, tip)
    return holder, AttachSetColor({ base, tip })
end

IB.crown = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local base = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.8, size * 0.35),
        Position = UDim2.new(0.5, 0, 0.68, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, base)
    local parts = { base }
    for i = 1, 3 do
        local spike = Create("Frame", {
            Size = UDim2.fromOffset(size * 0.15, size * 0.4),
            Position = UDim2.new(0.2 + (i - 1) * 0.3, 0, 0.4, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Corner(1, spike)
        table.insert(parts, spike)
    end
    return holder, AttachSetColor(parts)
end

IB.zap = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local thickness = math.max(math.floor(size / 7), 2)
    local top = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.55, thickness),
        Position = UDim2.new(0.42, 0, 0.25, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, top)
    local diag = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.4, thickness),
        Position = UDim2.new(0.55, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = -75,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, diag)
    local bottom = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.55, thickness),
        Position = UDim2.new(0.58, 0, 0.75, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, bottom)
    return holder, AttachSetColor({ top, diag, bottom })
end

-- ============================================================
-- [IMPROVEMENT] New icons
-- ============================================================
IB.warning = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local tri = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.85, size * 0.85),
        Position = UDim2.fromScale(0.5, 0.55),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(2, tri)
    local stroke = Stroke(color, 2, 0, tri)
    local bang = Create("Frame", {
        Size = UDim2.fromOffset(math.max(math.floor(size / 10), 1), size * 0.3),
        Position = UDim2.new(0.5, 0, 0.35, 0),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    local dot = Create("Frame", {
        Size = UDim2.fromOffset(math.max(math.floor(size / 10), 2), math.max(math.floor(size / 10), 2)),
        Position = UDim2.new(0.5, 0, 0.78, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(999, dot)
    return holder, AttachSetColor({ bang, dot }, { stroke })
end

IB.info = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local ring = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.85, size * 0.85),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(999, ring)
    local stroke = Stroke(color, 2, 0, ring)
    local stem = Create("Frame", {
        Size = UDim2.fromOffset(math.max(math.floor(size / 10), 2), size * 0.35),
        Position = UDim2.new(0.5, 0, 0.55, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    local dot = Create("Frame", {
        Size = UDim2.fromOffset(math.max(math.floor(size / 10), 2), math.max(math.floor(size / 10), 2)),
        Position = UDim2.new(0.5, 0, 0.3, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(999, dot)
    return holder, AttachSetColor({ stem, dot }, { stroke })
end

IB.search = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local ring = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.6, size * 0.6),
        Position = UDim2.new(0.42, 0, 0.4, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(999, ring)
    local stroke = Stroke(color, 2, 0, ring)
    local handle = Create("Frame", {
        Size = UDim2.fromOffset(math.max(math.floor(size / 8), 2), size * 0.35),
        Position = UDim2.new(0.78, 0, 0.78, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = 45,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, handle)
    return holder, AttachSetColor({ handle }, { stroke })
end

IB.refresh = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local ring = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.8, size * 0.8),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(999, ring)
    local stroke = Stroke(color, 2, 0.3, ring)
    local arrow = Create("Frame", {
        Size = UDim2.fromOffset(math.max(math.floor(size / 7), 2), size * 0.3),
        Position = UDim2.new(1, -size * 0.15, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, arrow)
    return holder, AttachSetColor({ arrow }, { stroke })
end

IB.trash = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local lid = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.7, math.max(math.floor(size / 8), 2)),
        Position = UDim2.new(0.5, 0, 0.2, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, lid)
    local body = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.55, size * 0.55),
        Position = UDim2.new(0.5, 0, 0.62, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, body)
    local stroke = Stroke(color, 1.5, 0, body)
    return holder, AttachSetColor({ lid }, { stroke })
end

IB.download = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local shaft = Create("Frame", {
        Size = UDim2.fromOffset(math.max(math.floor(size / 7), 2), size * 0.5),
        Position = UDim2.new(0.5, 0, 0.35, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, shaft)
    local arrowL = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.3, math.max(math.floor(size / 7), 2)),
        Position = UDim2.new(0.5, 0, 0.6, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = 45,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, arrowL)
    local arrowR = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.3, math.max(math.floor(size / 7), 2)),
        Position = UDim2.new(0.5, 0, 0.6, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = -45,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, arrowR)
    local base = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.7, math.max(math.floor(size / 7), 2)),
        Position = UDim2.new(0.5, 0, 0.85, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(1, base)
    return holder, AttachSetColor({ shaft, arrowL, arrowR, base })
end

IB.default = IB.dot

-- ============================================================
-- [IMPROVEMENT] Unified BuildIcon API
-- ============================================================
function LucidUI.BuildIcon(name, parent, size, color)
    local builder = LucidUI.IconBuilders[name] or LucidUI.IconBuilders.default
    if not builder then
        warn("[LucidUI] BuildIcon: unknown icon name '" .. tostring(name) .. "'")
        return nil, nil
    end
    return builder(parent, size or 16, color or Color3.fromRGB(255, 255, 255))
end

-- ============================================================
-- [IMPROVEMENT] PulseIcon — continuous breathing pulse
-- ============================================================
function LucidUI.PulseIcon(parts, opts)
    opts = opts or {}
    local speed = opts.Speed or 3
    local minAlpha = opts.MinAlpha or 0
    local maxAlpha = opts.MaxAlpha or 0.35

    task.spawn(function()
        local t = 0
        while true do
            local first = parts and parts[1]
            if not first or not first.Parent then break end
            t = t + 0.03
            local pulse = 0.5 + 0.5 * math.sin(t * speed)
            local alpha = minAlpha + (maxAlpha - minAlpha) * pulse
            if parts.SetColor then
                -- Can't pulse transparency through SetColor; do it directly
            end
            for _, p in ipairs(parts) do
                if p and p.Parent and p:IsA("GuiObject") then
                    p.BackgroundTransparency = alpha
                end
            end
            task.wait(0.03)
        end
    end)
end

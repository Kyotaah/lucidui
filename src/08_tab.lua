--[[
    Tab + Section — layout containers plus frame-based tab icons.
]]

local function IconHolder(parent, size)
    return Create("Frame", {
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        Parent = parent,
    })
end

local function RecolorIconParts(parts, color)
    for _, p in ipairs(parts) do
        if typeof(p) == "Instance" then
            if p:IsA("UIStroke") then
                p.Color = color
            elseif p:IsA("GuiObject") then
                p.BackgroundColor3 = color
            end
        end
    end
end

LucidUI.IconBuilders = {}

LucidUI.IconBuilders.dot = function(parent, size, color)
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
    return holder, { dot }
end

LucidUI.IconBuilders.bars = function(parent, size, color)
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
    return holder, parts
end

LucidUI.IconBuilders.diamond = function(parent, size, color)
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
    return holder, { diamond }
end

LucidUI.IconBuilders.cross = function(parent, size, color)
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
    return holder, { a, b }
end

LucidUI.IconBuilders.plus = function(parent, size, color)
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
    return holder, { h, v }
end

LucidUI.IconBuilders.check = function(parent, size, color)
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
    return holder, { short, long }
end

LucidUI.IconBuilders.shield = function(parent, size, color)
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
    return holder, { top, bottom }
end

LucidUI.IconBuilders.gavel = function(parent, size, color)
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
    return holder, { blade, handle }
end

LucidUI.IconBuilders.star = function(parent, size, color)
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
    return holder, { h, v }
end

LucidUI.IconBuilders.coins = function(parent, size, color)
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
    return holder, { outer }
end

LucidUI.IconBuilders.person = function(parent, size, color)
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
    return holder, { head, body }
end

LucidUI.IconBuilders.eye = function(parent, size, color)
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
    return holder, { stroke, pupil }
end

LucidUI.IconBuilders.lock = function(parent, size, color)
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
    return holder, { leftBar, rightBar, topBar, body }
end

LucidUI.IconBuilders.unlock = function(parent, size, color)
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
    return holder, { topBar, rightBar, body }
end

LucidUI.IconBuilders.play = function(parent, size, color)
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
    return holder, { top, bottom }
end

LucidUI.IconBuilders.pause = function(parent, size, color)
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
    return holder, { left, right }
end

LucidUI.IconBuilders.stop = function(parent, size, color)
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
    return holder, { sq }
end

LucidUI.IconBuilders.bell = function(parent, size, color)
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
    return holder, { top, body, base }
end

LucidUI.IconBuilders.home = function(parent, size, color)
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
    return holder, { base, roofL, roofR }
end

LucidUI.IconBuilders.settings = function(parent, size, color)
    local holder = IconHolder(parent, size)
    local circle = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.55, size * 0.55),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(999, circle)
    local parts = { circle }
    for i = 1, 8 do
        local angle = (i - 1) * 45
        local rad = math.rad(angle - 90)
        local tooth = Create("Frame", {
            Size = UDim2.fromOffset(math.max(math.floor(size / 8), 1), size * 0.16),
            Position = UDim2.new(0.5 + 0.38 * math.cos(rad), 0.5 + 0.38 * math.sin(rad)),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Rotation = angle,
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Corner(1, tooth)
        table.insert(parts, tooth)
    end
    return holder, parts
end

LucidUI.IconBuilders.sword = function(parent, size, color)
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
    return holder, { blade, guard, handle }
end

LucidUI.IconBuilders.target = function(parent, size, color)
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
    return holder, { stroke, center }
end

LucidUI.IconBuilders.flame = function(parent, size, color)
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
    return holder, { base, tip }
end

LucidUI.IconBuilders.crown = function(parent, size, color)
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
    return holder, parts
end

LucidUI.IconBuilders.zap = function(parent, size, color)
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
    return holder, { top, diag, bottom }
end

LucidUI.IconBuilders.default = LucidUI.IconBuilders.dot

LucidUI.Tab = {}
LucidUI.Tab.__index = LucidUI.Tab

function LucidUI.Window:CreateTab(config)
    config = config or {}

    local tab = setmetatable({}, LucidUI.Tab)
    tab.Name          = config.Name or "Tab"
    tab.Window        = self
    tab.Sections      = {}
    tab._orderCounter = 0
    tab.IconName      = config.Icon

    local builder = tab.IconName and LucidUI.IconBuilders[tab.IconName] or nil
    if tab.IconName and not builder then
        builder = LucidUI.IconBuilders.default
    end

    local btn = Create("TextButton", {
        Name = tab.Name,
        Text = "",
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Size = UDim2.fromOffset(0, 30),
        ZIndex = 2,
        Parent = self.TabStrip,
    })
    Corner(8, btn)

    local iconHolder, iconParts = nil, {}
    local ICON_SIZE = 14
    local ICON_PAD = 10

    if builder then
        iconHolder, iconParts = builder(btn, ICON_SIZE, self.Theme.TabInactive)
        iconHolder.Position = UDim2.fromOffset(ICON_PAD, (30 - ICON_SIZE) / 2)
        iconHolder.ZIndex = 3
    end

    local labelX = builder and (ICON_PAD + ICON_SIZE + 6) or 12
    local labelW = -(labelX + 12)

    local labelLbl = Create("TextLabel", {
        Text = tab.Name,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = self.Theme.TabInactive,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Center,
        Position = UDim2.fromOffset(labelX, 0),
        Size = UDim2.new(1, labelW, 1, 0),
        ZIndex = 3,
        Parent = btn,
    })

    local ts = TextService:GetTextSize(tab.Name, 13, Enum.Font.GothamMedium, Vector2.new(1000, 30))
    btn.Size = UDim2.fromOffset(ts.X + (labelX + 12), 30)

    tab.Button    = btn
    tab.Label     = labelLbl
    tab.IconParts = iconParts

    btn.MouseEnter:Connect(function()
        if tab == self.ActiveTab then return end
        Tween(btn, 0.15, { BackgroundTransparency = 0.7 }):Play()
    end)
    btn.MouseLeave:Connect(function()
        if tab == self.ActiveTab then return end
        Tween(btn, 0.15, { BackgroundTransparency = 1 }):Play()
    end)

    local page = Create("ScrollingFrame", {
        Name = tab.Name .. "Page",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = self.Theme.TextMuted,
        ScrollBarImageTransparency = 0.5,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        ZIndex = 2,
        Parent = self.Content,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = page,
    })
    Create("UIPadding", {
        PaddingRight = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 12),
        Parent = page,
    })
    tab.Page = page

    self:_registerTheme(function(t)
        local active = (tab == self.ActiveTab)
        local c = active and t.TabActive or t.TabInactive
        labelLbl.TextColor3 = c
        RecolorIconParts(iconParts, c)
    end)

    btn.MouseButton1Click:Connect(function()
        self:SelectTab(tab)
    end)

    table.insert(self.Tabs, tab)
    if not self.ActiveTab then
        self:SelectTab(tab)
    end

    return tab
end

function LucidUI.Window:SelectTab(tab)
    for _, t in ipairs(self.Tabs) do
        local active = (t == tab)
        t.Page.Visible = active

        local c = active and self.Theme.TabActive or self.Theme.TabInactive

        Tween(t.Button, 0.18, { BackgroundTransparency = active and 0.20 or 1 }):Play()
        Tween(t.Label, 0.18, { TextColor3 = c }):Play()
        RecolorIconParts(t.IconParts or {}, c)

        if active then
            for _, section in ipairs(t.Sections or {}) do
                if section.Expanded then
                    section.Wrapper.AutomaticSize = Enum.AutomaticSize.Y
                end
            end
            t.Page.Position = UDim2.fromOffset(8, 0)
            Tween(t.Page, 0.20, { Position = UDim2.fromOffset(0, 0) }):Play()
        end
    end

    self.ActiveTab = tab
end

LucidUI.Section = {}
LucidUI.Section.__index = LucidUI.Section

function LucidUI.Tab:CreateSection(nameOrConfig)
    local cfg = type(nameOrConfig) == "table"
        and nameOrConfig
        or { Name = nameOrConfig }

    local section = setmetatable({}, LucidUI.Section)
    section.Name        = cfg.Name or ""
    section.Tab         = self
    section.Collapsible = true
    section.Expanded    = cfg.StartExpanded ~= false
    section._order      = self._orderCounter * 1000
    section._elemOrder  = section._order
    section._cachedH    = 0
    self._orderCounter = self._orderCounter + 1

    if section.Name ~= "" then
        local headerBtn = Create("TextButton", {
            Text = "",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 22),
            LayoutOrder = section._order,
            ZIndex = 2,
            Parent = self.Page,
        })

        local arrowTxt = Create("TextLabel", {
            Text = section.Expanded and "v" or ">",
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = self.Window.Theme.TextMuted,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(2, 0),
            Size = UDim2.fromOffset(16, 22),
            ZIndex = 2,
            Parent = headerBtn,
        })

        local header = Create("TextLabel", {
            Text = section.Name:upper(),
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = self.Window.Theme.TextMuted,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(18, 0),
            Size = UDim2.new(1, -18, 1, 0),
            ZIndex = 2,
            Parent = headerBtn,
        })

        section.HeaderBtn = headerBtn
        section.Header    = header
        section.Arrow     = arrowTxt

        headerBtn.MouseButton1Click:Connect(function()
            section:SetExpanded(not section.Expanded)
        end)

        headerBtn.MouseEnter:Connect(function()
            Tween(header,   0.15, { TextColor3 = self.Window.Theme.TextPrimary }):Play()
            Tween(arrowTxt, 0.15, { TextColor3 = self.Window.Theme.TextPrimary }):Play()
        end)
        headerBtn.MouseLeave:Connect(function()
            Tween(header,   0.15, { TextColor3 = self.Window.Theme.TextMuted }):Play()
            Tween(arrowTxt, 0.15, { TextColor3 = self.Window.Theme.TextMuted }):Play()
        end)

        self.Window:_registerTheme(function(t)
            header.TextColor3   = t.TextMuted
            arrowTxt.TextColor3 = t.TextMuted
        end)
    end

    local wrapper = Create("Frame", {
        Name = "Wrapper",
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        LayoutOrder = section._order + 1,
        ZIndex = 2,
        Parent = self.Page,
    })

    local container = Create("Frame", {
        Name = "Container",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = wrapper,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = container,
    })

    section.Wrapper   = wrapper
    section.Container = container

    task.spawn(function()
        task.wait()
        task.wait()
        if not wrapper.Parent then return end
        if section.Expanded then
            wrapper.AutomaticSize = Enum.AutomaticSize.Y
        end
    end)

    table.insert(self.Sections, section)
    return section
end

function LucidUI.Section:_nextOrder()
    self._elemOrder = self._elemOrder + 1
    return self._elemOrder
end

function LucidUI.Section:_track(frame)
    frame.Parent = self.Container
    return frame
end

function LucidUI.Section:SetExpanded(state, instant)
    if state == self.Expanded and not instant then return end
    self.Expanded = state
    if self.Arrow then self.Arrow.Text = state and "v" or ">" end

    local wrapper   = self.Wrapper
    local container = self.Container

    -- Read the true content height from the container
    local layout = container:FindFirstChildOfClass("UIListLayout")
    local target = 0
    if layout then target = layout.AbsoluteContentSize.Y end
    if target <= 0 then target = container.Size.Y.Offset end
    if target <= 0 then
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("GuiObject") and child.Visible then
                target = target + child.Size.Y.Offset
            end
        end
    end
    if target <= 0 then target = 40 end

    self._cachedH = target

    -- Cache the container's own size and freeze it during the tween
    container.AutomaticSize = Enum.AutomaticSize.None
    container.Size = UDim2.new(1, 0, 0, target)

    if instant then
        wrapper.AutomaticSize = Enum.AutomaticSize.None
        wrapper.Size = UDim2.new(1, 0, 0, state and target or 0)
        container.AutomaticSize = Enum.AutomaticSize.Y
        if state then wrapper.AutomaticSize = Enum.AutomaticSize.Y end
        return
    end

    wrapper.AutomaticSize = Enum.AutomaticSize.None

    -- Set starting point
    if state then
        wrapper.Size = UDim2.new(1, 0, 0, 0)
    else
        wrapper.Size = UDim2.new(1, 0, 0, target)
    end

    local goalH = state and target or 0

    -- Same easing + duration as dropdowns
    TweenService:Create(
        wrapper,
        TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Size = UDim2.new(1, 0, 0, goalH) }
    ):Play()

    task.delay(0.24, function()
        container.AutomaticSize = Enum.AutomaticSize.Y
        if self.Expanded then
            wrapper.AutomaticSize = Enum.AutomaticSize.Y
        end
    end)
end

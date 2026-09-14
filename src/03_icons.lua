--[[
    Icons — frame-based builders. All visuals are constructed from
    Frames/Rects so they render identically on any device.
]]

local function IconHolder(parent, size)
    return Create("Frame", {
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        Parent = parent,
    })
end

-- ============================================================
-- Gear (settings) — 8 rounded teeth + solid ring + center hole
-- ============================================================
function BuildGearIcon(parent, size, color, holeColor)
    size = size or 18

    local holder = IconHolder(parent, size)
    local parts  = {}

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

    return holder, ring, parts, hole
end

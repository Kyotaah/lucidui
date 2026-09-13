--[[
    Icons — frame-based icon builders.

    Everything here is drawn with rotated Frames instead of text glyphs
    or image assets, so it renders identically on every device, font,
    and executor. No Unicode fallback boxes, no asset-loading delays.
]]

-- ============================================================
-- Gear icon (used by the settings button in the header)
-- Returns: holder, ring, parts, hole
--   holder  — the container Frame, position/size this
--   ring    — the rotating Frame, tween this for the spin
--   parts   — array of every gear part, apply color tweens to these
--   hole    — the inner hole Frame, usually colored to match the background
-- ============================================================
local function BuildGearIcon(parent, size, color, holeColor)
    size = size or 18

    local holder = Create("Frame", {
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        Parent = parent,
    })

    local parts = {}

    -- Rotating ring holds all the teeth
    local ring = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = holder,
    })

    -- Eight teeth evenly spaced around the circumference
    for i = 1, 8 do
        local angle = (i - 1) * 45
        local rad   = math.rad(angle - 90)

        local tooth = Create("Frame", {
            Size = UDim2.fromOffset(size * 0.18, size * 0.26),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(
                0.5 + 0.35 * math.cos(rad),
                0.5 + 0.35 * math.sin(rad)
            ),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = ring,
        })
        Corner(1, tooth)
        tooth.Rotation = angle

        table.insert(parts, tooth)
    end

    -- Outer ring (the circular body of the gear)
    local outer = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.68, size * 0.68),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Corner(size * 0.20, outer)
    table.insert(parts, outer)

    -- Inner hole (should match the parent background so it looks cut out)
    local hole = Create("Frame", {
        Size = UDim2.fromOffset(size * 0.28, size * 0.28),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = holeColor or Color3.fromRGB(28, 28, 30),
        BorderSizePixel = 0,
        Parent = outer,
    })
    Corner(size * 0.14, hole)

    return holder, ring, parts, hole
end

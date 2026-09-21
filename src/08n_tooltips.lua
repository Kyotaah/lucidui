-- ============================================================
-- Module: 08n_tooltips.lua
-- ============================================================
--[[
    Tooltips — universal, theme-aware hover/long-press hints.

    Works on PC (hover) and mobile (long-press). Only one tooltip
    visible at a time. Auto-positions so it never goes off-screen.
    Auto-themes on change.

    [NEW] Default position is "bottom" (centered below the element).
    [NEW] A per-tooltip move-watcher cancels the tooltip if the
    owning element moves more than 6px — fixes the "tooltip stuck
    after scrolling" bug on both PC and mobile.
]]

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

-- ============================================================
-- Global config
-- ============================================================
LucidUI._tooltipConfig = {
    Enabled      = true,
    Delay        = 0.35,
    MobileDelay  = 0.40,
    MobileHold   = 2.0,
    MaxWidth     = 260,
    Position     = "bottom",   -- [CHANGED] was "auto"
    Offset       = 8,
    Padding      = 10,
    Font         = Enum.Font.GothamMedium,
    TextSize     = 12,
    CornerRadius = 8,
    FadeIn       = 0.15,
    FadeOut      = 0.12,
}

function LucidUI:SetTooltipConfig(opts)
    if type(opts) ~= "table" then return end
    for k, v in pairs(opts) do
        if self._tooltipConfig[k] ~= nil then
            self._tooltipConfig[k] = v
        end
    end
end

function LucidUI:GetTooltipConfig()
    return self._tooltipConfig
end

-- ============================================================
-- Shared tooltip GUI
-- ============================================================
local tooltipGui
local function getGui()
    if tooltipGui and tooltipGui.Parent then return tooltipGui end
    tooltipGui = Create("ScreenGui", {
        Name = "LucidUI_Tooltip",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 400,
        Parent = PlayerGui,
    })
    return tooltipGui
end

-- ============================================================
-- Active tooltip state (only one at a time)
-- ============================================================
local active = {
    frame = nil,
    label = nil,
    stroke = nil,
    owner = nil,
}

local function destroyActive(animated)
    if not active.frame then return end
    local f, s, l = active.frame, active.stroke, active.label
    active.frame = nil
    active.label = nil
    active.stroke = nil
    active.owner = nil
    if not f or not f.Parent then return end

    local cfg = LucidUI._tooltipConfig
    if animated then
        pcall(function()
            TweenService:Create(f, TweenInfo.new(cfg.FadeOut), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(s, TweenInfo.new(cfg.FadeOut), { Transparency = 1 }):Play()
            TweenService:Create(l, TweenInfo.new(cfg.FadeOut), { TextTransparency = 1 }):Play()
        end)
        task.delay(cfg.FadeOut + 0.05, function()
            pcall(function() f:Destroy() end)
        end)
    else
        pcall(function() f:Destroy() end)
    end
end

-- ============================================================
-- Smart positioning
-- ============================================================
local function positionFrame(frame, element, position)
    local cfg = LucidUI._tooltipConfig
    local cam = workspace.CurrentCamera
    if not cam then return end

    local eAbs  = element.AbsolutePosition
    local eSize = element.AbsoluteSize
    local tSize = frame.AbsoluteSize
    local vp    = cam.ViewportSize

    local pos = position or cfg.Position

    -- "auto" = bottom, but flip to top if there isn't room below.
    if pos == "auto" then
        if eAbs.Y + eSize.Y + cfg.Offset + tSize.Y <= vp.Y then
            pos = "bottom"
        else
            pos = "top"
        end
    end

    local x, y
    if pos == "top" then
        x = eAbs.X + eSize.X / 2 - tSize.X / 2
        y = eAbs.Y - tSize.Y - cfg.Offset
    elseif pos == "bottom" then
        x = eAbs.X + eSize.X / 2 - tSize.X / 2
        y = eAbs.Y + eSize.Y + cfg.Offset
    elseif pos == "left" then
        x = eAbs.X - tSize.X - cfg.Offset
        y = eAbs.Y + eSize.Y / 2 - tSize.Y / 2
    elseif pos == "right" then
        x = eAbs.X + eSize.X + cfg.Offset
        y = eAbs.Y + eSize.Y / 2 - tSize.Y / 2
    else
        x = eAbs.X + eSize.X / 2 - tSize.X / 2
        y = eAbs.Y + eSize.Y + cfg.Offset
    end

    x = math.clamp(x, cfg.Offset, math.max(vp.X - tSize.X - cfg.Offset, cfg.Offset))
    y = math.clamp(y, cfg.Offset, math.max(vp.Y - tSize.Y - cfg.Offset, cfg.Offset))

    frame.Position = UDim2.fromOffset(x, y)
end

-- ============================================================
-- Show / hide
-- ============================================================
local function showTooltip(element, text, opts)
    opts = opts or {}
    local cfg = LucidUI._tooltipConfig
    if not cfg.Enabled then return end

    destroyActive(false)

    local gui = getGui()
    if not gui then return end

    local theme    = opts.Theme or LucidUI._lastTheme or LucidUI.Themes.Default
    local maxWidth = opts.MaxWidth or cfg.MaxWidth

    local frame = Create("Frame", {
        Name = "TooltipCard",
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        ZIndex = 5,
        Parent = gui,
    })
    Corner(cfg.CornerRadius, frame)

    local stroke = Stroke(theme.Border, 1, 1, frame)

    local label = Create("TextLabel", {
        Text = text,
        Font = cfg.Font,
        TextSize = cfg.TextSize,
        TextColor3 = theme.TextPrimary,
        BackgroundTransparency = 1,
        TextTransparency = 1,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Size = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        ZIndex = 6,
        Parent = frame,
    })

    Create("UIPadding", {
        PaddingLeft   = UDim.new(0, cfg.Padding),
        PaddingRight  = UDim.new(0, cfg.Padding),
        PaddingTop    = UDim.new(0, cfg.Padding - 2),
        PaddingBottom = UDim.new(0, cfg.Padding - 2),
        Parent = frame,
    })

    Create("UISizeConstraint", {
        MaxSize = Vector2.new(maxWidth, 400),
        Parent = frame,
    })

    active.frame  = frame
    active.label  = label
    active.stroke = stroke
    active.owner  = element

    task.defer(function()
        if active.frame ~= frame then return end
        if not frame.Parent then return end
        positionFrame(frame, element, opts.Position)

        TweenService:Create(frame, TweenInfo.new(cfg.FadeIn), {
            BackgroundTransparency = theme.BackgroundTrans or 0.15,
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(cfg.FadeIn), {
            Transparency = 0.4,
        }):Play()
        TweenService:Create(label, TweenInfo.new(cfg.FadeIn), {
            TextTransparency = 0,
        }):Play()
    end)
end

-- ============================================================
-- Public attach
-- ============================================================
function LucidUI._AttachTooltip(element, text, opts)
    if not element then return end
    if type(text) ~= "string" or text == "" then return end

    local cfg         = LucidUI._tooltipConfig
    local delay       = (opts and opts.Delay)       or cfg.Delay
    local mobileDelay = (opts and opts.MobileDelay) or cfg.MobileDelay
    local mobileHold  = (opts and opts.MobileHold)  or cfg.MobileHold

    local token         = 0
    local showing       = false
    local touchActive   = false
    local moveCheckConn = nil

    -- [NEW] Stop the move-watcher. Called on cancel and before
    -- re-arming after the tooltip shows.
    local function stopMoveWatch()
        if moveCheckConn then
            pcall(function() moveCheckConn:Disconnect() end)
            moveCheckConn = nil
        end
    end

    -- [NEW] Cancel — hides tooltip (if visible) and stops the watcher.
    local function cancel()
        token = token + 1
        stopMoveWatch()
        if showing then
            showing = false
            destroyActive(true)
        end
    end

    -- [NEW] Watch the element's position. Any shift > 6px in either
    -- axis (scroll, layout reflow, window drag) cancels the tooltip.
    -- This is what fixes "tooltip stuck after scrolling".
    local function startMoveWatch()
        stopMoveWatch()
        if not element.Parent then return end
        local anchorX = element.AbsolutePosition.X
        local anchorY = element.AbsolutePosition.Y

        moveCheckConn = RunService.RenderStepped:Connect(function()
            if not element or not element.Parent then
                cancel()
                return
            end
            local cur = element.AbsolutePosition
            if math.abs(cur.X - anchorX) > 6
            or math.abs(cur.Y - anchorY) > 6 then
                cancel()
            end
        end)
    end

    local function scheduleShow(d)
        token = token + 1
        local myToken = token

        -- Arm the watcher immediately so we catch movement during
        -- the delay window too (user begins a scroll before the
        -- timer fires).
        startMoveWatch()

        task.delay(d, function()
            if myToken ~= token then return end
            if not element.Parent then return end
            showing = true
            showTooltip(element, text, opts)
            -- Re-anchor: the tooltip has now moved the layout a bit,
            -- and we want to catch subsequent movement only.
            startMoveWatch()
        end)
    end

    -- PC hover
    element.MouseEnter:Connect(function()
        if touchActive then return end
        scheduleShow(delay)
    end)
    element.MouseLeave:Connect(function()
        if touchActive then return end
        cancel()
    end)

    -- Mobile long-press
    element.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch then return end
        touchActive = true
        scheduleShow(mobileDelay)
    end)
    element.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch then return end
        local myToken = token
        task.delay(mobileHold, function()
            if myToken ~= token then return end
            touchActive = false
            cancel()
        end)
    end)
end

-- ============================================================
-- Convenience: attach a tooltip to every direct child of a
-- container that has a Name property. Used for header icons.
-- ============================================================
function LucidUI._AttachHeaderTooltips(header, map)
    if not header or type(map) ~= "table" then return end
    for _, child in ipairs(header:GetChildren()) do
        local tipText = map[child.Name]
        if tipText then
            LucidUI._AttachTooltip(child, tipText, { Position = "bottom" })
        end
    end
end

-- ============================================================
-- Cleanup
-- ============================================================
LucidUI:OnCleanup(function()
    destroyActive(false)
    if tooltipGui and tooltipGui.Parent then
        pcall(function() tooltipGui:Destroy() end)
    end
    tooltipGui = nil
    print("[LucidUI] Tooltips cleaned up")
end)

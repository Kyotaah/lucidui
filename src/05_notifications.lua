--[[
    Notifications — glass toasts in the top-right corner.

    Each toast:
      • Slides in from the right with Back easing
      • Has a colored accent bar on the left that adapts to text height
      • Auto-dismisses after Duration (default 4s)
      • Fades out and destroys itself cleanly
]]

-- ============================================================
-- Root container (created once, reused forever)
-- ============================================================
local function GetNotificationRoot()
    if LucidUI._notifRoot and LucidUI._notifRoot.Parent then
        return LucidUI._notifRoot
    end

    local root = Create("ScreenGui", {
        Name = "LucidUI_Notifications",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 200,
        Parent = PlayerGui,
    })

    Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Parent = root,
    })

    Create("UIPadding", {
        PaddingTop = UDim.new(0, 16),
        PaddingRight = UDim.new(0, 16),
        Parent = root,
    })

    LucidUI._notifRoot = root
    return root
end

-- ============================================================
-- Public API
-- ============================================================
function LucidUI:Notify(config)
    config = config or {}

    local theme    = config.Theme or LucidUI._lastTheme or LucidUI.Themes.Default
    local root     = GetNotificationRoot()
    local title    = config.Title or "Notice"
    local message  = config.Message or ""
    local duration = config.Duration or 4
    local accent   = config.Accent or theme.Accent

    -- --------------------------------------------------------
    -- Card
    -- --------------------------------------------------------
    local card = Create("Frame", {
        Size = UDim2.fromOffset(300, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 1,
        Parent = root,
    })
    Corner(14, card)
    local stroke = Stroke(accent, 1, 0.4, card)

    -- --------------------------------------------------------
    -- Accent bar (height adjusted after layout settles)
    -- --------------------------------------------------------
    local bar = Create("Frame", {
        Size = UDim2.new(0, 3, 0, 20),
        Position = UDim2.fromOffset(8, 10),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        Parent = card,
    })
    Corner(2, bar)

    -- --------------------------------------------------------
    -- Title + message
    -- --------------------------------------------------------
    local titleLbl = Create("TextLabel", {
        Text = title,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(18, 10),
        Size = UDim2.new(1, -30, 0, 18),
        Parent = card,
    })

    local msgLbl = Create("TextLabel", {
        Text = message,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = theme.TextSecondary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Position = UDim2.fromOffset(18, 30),
        Size = UDim2.new(1, -30, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = card,
    })

    -- Bottom spacer so the card has symmetric padding
    Create("Frame", {
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 1, 0),
        BackgroundTransparency = 1,
        Parent = card,
    })

    -- --------------------------------------------------------
    -- Adapt accent bar to message height
    -- --------------------------------------------------------
    task.spawn(function()
        for _ = 1, 20 do
            if not card.Parent then return end
            bar.Size = UDim2.new(0, 3, 0, 18 + 2 + msgLbl.AbsoluteSize.Y)
            task.wait(0.1)
        end
    end)

    -- --------------------------------------------------------
    -- Slide in from the right
    -- --------------------------------------------------------
    card.Position = UDim2.fromOffset(340, 0)
    Tween(card, 0.30, {
        Position = UDim2.fromOffset(0, 0),
        BackgroundTransparency = theme.BackgroundTrans or 0.15,
    }, Enum.EasingStyle.Back):Play()

    -- --------------------------------------------------------
    -- Auto-dismiss
    -- --------------------------------------------------------
    task.delay(duration, function()
        if not card.Parent then return end

        Tween(card, 0.25, {
            Position = UDim2.fromOffset(340, 0),
            BackgroundTransparency = 1,
        }, Enum.EasingStyle.Quad, Enum.EasingDirection.In):Play()

        Tween(stroke,   0.25, { Transparency = 1 }):Play()
        Tween(titleLbl, 0.20, { TextTransparency = 1 }):Play()
        Tween(msgLbl,   0.20, { TextTransparency = 1 }):Play()
        Tween(bar,      0.25, { BackgroundTransparency = 1 }):Play()

        task.wait(0.30)
        if card.Parent then card:Destroy() end
    end)

    return card
end

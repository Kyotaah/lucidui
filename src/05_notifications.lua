--[[
    Notifications — glass toasts in the top-right corner.

    Each toast:
      • Slides in from the right with a scale entrance
      • Has a colored accent bar on the left that adapts to text height
      • Auto-dismisses after Duration (default 4s)
      • Can be clicked to dismiss early
      • Auto-icons based on Variant (info / success / warn / error)

    [IMPROVEMENT] Queue system, variant colors, manual dismiss.
    Caps visible notifications at MaxVisible (default 4).
    Progress bar removed for cleaner look.
]]

local MAX_VISIBLE = 4
local notifQueue = {}
local notifActive = {}

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
-- Variant → default accent + icon mapping
-- ============================================================
local VARIANTS = {
    info    = { Color = Color3.fromRGB(90, 180, 255),  Icon = "bell"    },
    success = { Color = Color3.fromRGB(90, 210, 130),  Icon = "check"   },
    warn    = { Color = Color3.fromRGB(255, 189, 46),  Icon = "warning" },
    error   = { Color = Color3.fromRGB(255, 95, 87),   Icon = "cross"   },
    default = { Color = nil,                           Icon = nil       },
}

-- ============================================================
-- Active notification count check
-- ============================================================
local function ActiveCount()
    local n = 0
    for i = #notifActive, 1, -1 do
        if notifActive[i] and notifActive[i].Parent then
            n = n + 1
        else
            table.remove(notifActive, i)
        end
    end
    return n
end

-- ============================================================
-- Process queue
-- ============================================================
local function ProcessQueue()
    while #notifQueue > 0 and ActiveCount() < MAX_VISIBLE do
        local nextConfig = table.remove(notifQueue, 1)
        LucidUI:_renderNotification(nextConfig)
    end
end

-- ============================================================
-- Public API
-- ============================================================
function LucidUI:Notify(config)
    config = config or {}

    if type(config) == "string" then
        config = { Title = "Notice", Message = config }
    end

    if ActiveCount() >= MAX_VISIBLE then
        table.insert(notifQueue, config)
        return nil
    end

    return self:_renderNotification(config)
end

function LucidUI:ClearAllNotifications()
    for _, card in ipairs(notifActive) do
        pcall(function()
            if card and card.Parent then card:Destroy() end
        end)
    end
    notifActive = {}
    notifQueue = {}
end

-- ============================================================
-- Internal renderer
-- ============================================================
function LucidUI:_renderNotification(config)
    local theme    = config.Theme or LucidUI._lastTheme or LucidUI.Themes.Default
    local root     = GetNotificationRoot()

    -- Resolve variant styling
    local variantName = config.Variant or "default"
    local variantData = VARIANTS[variantName] or VARIANTS.default

    local title    = config.Title or "Notice"
    local message  = config.Message or ""
    local duration = config.Duration or 4
    local accent   = config.Accent or variantData.Color or theme.Accent
    local iconName = config.Icon or variantData.Icon

    -- --------------------------------------------------------
    -- Card
    -- --------------------------------------------------------
    local card = Create("TextButton", {
        Name = "NotifCard",
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromOffset(320, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 1,
        Parent = root,
    })
    Corner(14, card)
    local stroke = Stroke(accent, 1, 0.4, card)

    local cardScale = Create("UIScale", { Scale = 0.85, Parent = card })

    -- --------------------------------------------------------
    -- Accent bar (height adjusted after layout settles)
    -- --------------------------------------------------------

    local bar = Create("Frame", {
    Size = UDim2.new(0, 3, 0, 20),
    Position = UDim2.new(0, 8, 0.5, 0), -- Center vertically
    AnchorPoint = Vector2.new(0, 0.5),  -- Anchor to its own middle
    BackgroundColor3 = accent,
    BorderSizePixel = 0,
    Parent = card,
})
Corner(2, bar)

    -- --------------------------------------------------------
    -- Icon (optional)
    -- --------------------------------------------------------
    local iconLeft = 18
    if iconName then
        local iconHolder = Create("Frame", {
            Size = UDim2.fromOffset(18, 18),
            Position = UDim2.fromOffset(20, 14),
            BackgroundTransparency = 1,
            Parent = card,
        })
        if LucidUI.IconBuilders and LucidUI.IconBuilders[iconName] then
            pcall(function()
                LucidUI.IconBuilders[iconName](iconHolder, 18, accent)
            end)
        end
        iconLeft = 46
    end

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
        Position = UDim2.fromOffset(iconLeft, 12),
        Size = UDim2.new(1, -(iconLeft + 14), 0, 18),
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
        Position = UDim2.fromOffset(iconLeft, 32),
        Size = UDim2.new(1, -(iconLeft + 14), 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = card,
    })

    -- Bottom spacer so the card has symmetric padding
    Create("Frame", {
        Size = UDim2.new(1, 0, 0, 14),
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
    -- Track this card
    -- --------------------------------------------------------
    table.insert(notifActive, card)

    -- --------------------------------------------------------
    -- Slide in from the right + scale up
    -- --------------------------------------------------------
    card.Position = UDim2.fromOffset(340, 0)
    pcall(function()
        Tween(card, 0.30, {
            Position = UDim2.fromOffset(0, 0),
            BackgroundTransparency = theme.BackgroundTrans or 0.15,
        }, Enum.EasingStyle.Back):Play()
        Tween(cardScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
    end)

    -- --------------------------------------------------------
    -- Dismiss logic
    -- --------------------------------------------------------
    local dismissed = false
    local function dismiss()
        if dismissed then return end
        dismissed = true

        pcall(function()
            Tween(card, 0.25, {
                Position = UDim2.fromOffset(340, 0),
                BackgroundTransparency = 1,
            }, Enum.EasingStyle.Quad, Enum.EasingDirection.In):Play()

            Tween(cardScale, 0.25, { Scale = 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In):Play()
            Tween(stroke,   0.25, { Transparency = 1 }):Play()
            Tween(titleLbl, 0.20, { TextTransparency = 1 }):Play()
            Tween(msgLbl,   0.20, { TextTransparency = 1 }):Play()
            Tween(bar,      0.25, { BackgroundTransparency = 1 }):Play()
        end)

        task.wait(0.30)
        if card.Parent then pcall(function() card:Destroy() end) end

        -- Remove from active list
        for i = #notifActive, 1, -1 do
            if notifActive[i] == card then
                table.remove(notifActive, i)
                break
            end
        end

        -- Process the queue
        task.defer(ProcessQueue)
    end

    -- Click to dismiss
    card.MouseButton1Click:Connect(dismiss)
    card.TouchTap:Connect(dismiss)

    -- Auto-dismiss
    task.delay(duration, dismiss)

    return card
end

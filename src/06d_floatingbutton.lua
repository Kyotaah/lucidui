-- ============================================================
-- Module: 06d_floatingbutton.lua
-- ============================================================
--[[
    Floating Button — a draggable, always-visible button that
    survives window minimize/pill/hide.

    Two ways to use:

        -- Standalone (recommended for "open my hub" buttons):
        local btn = LucidUI:CreateFloatingButton({
            Text = "HUB",
            Color = Color3.fromRGB(130, 80, 255),
            Position = UDim2.new(0, 20, 0.5, -26),
            Size = UDim2.new(0, 52, 0, 52),
            SnapToEdge = true,
            OnClick = function() Window:SetVisible(true) end,
        })

        -- Bound to a window (auto-hides when window is visible):
        local btn = Window:CreateFloatingButton({
            Text = "MENU",
            HideWhenVisible = true,
        })

    Features:
      • Drag to reposition (mouse or touch)
      • Press-scale + hover-glow + click sound
      • Optional snap-to-nearest-edge on release
      • Optional auto-hide when its window is open
      • Theme-aware (auto-tints on theme change)
      • Cleaned up on re-execute via OnCleanup

    [FIX] Badge pulse loop was an infinite no-op (set static values,
    did nothing). Now it actually breathes — scale + transparency
    oscillate on a sine wave and stop cleanly when the badge is
    destroyed.

    NO tracking. NO network. NO clipboard.
]]

LucidUI.FloatingButton = {}
LucidUI.FloatingButton.__index = LucidUI.FloatingButton

-- ============================================================
-- Internals
-- ============================================================
local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function lightenColor(c, amount)
    return Color3.new(
        math.min(c.R + amount, 1),
        math.min(c.G + amount, 1),
        math.min(c.B + amount, 1)
    )
end

local function buildButtonInstance(cfg, parentGui)
    -- Container frame so we can apply hover-scale without fighting
    -- the actual button's position math.
    local wrap = Create("Frame", {
        Name = "FloatingButtonWrap",
        BackgroundTransparency = 1,
        Size = cfg.Size or UDim2.fromOffset(52, 52),
        Position = cfg.Position or UDim2.new(0, 20, 0.5, -26),
        AnchorPoint = cfg.AnchorPoint or Vector2.new(0, 0),
        ZIndex = cfg.ZIndex or 10,
        Parent = parentGui,
    })

    local btn = Create("TextButton", {
        Name = "FloatingButton",
        Text = "",
        BackgroundColor3 = cfg.Color or Color3.fromRGB(30, 28, 45),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 11,
        Parent = wrap,
    })
    Corner(cfg.CornerRadius or 14, btn)

    local outerStroke = Stroke(Color3.fromRGB(0, 0, 0), 3, 0.4, btn)
    local innerStroke = Stroke(cfg.Color or Color3.fromRGB(130, 80, 255), 1.4, 0.15, btn)

    -- Icon / text
    local iconLbl
    if cfg.Icon and cfg.Icon ~= "" then
        iconLbl = Create("ImageLabel", {
            Size = UDim2.new(0.7, 0, 0.7, 0),
            Position = UDim2.fromScale(0.15, 0.15),
            BackgroundTransparency = 1,
            Image = cfg.Icon,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 12,
            Parent = btn,
        })
    else
        iconLbl = Create("TextLabel", {
            Text = cfg.Text or "•",
            Font = Enum.Font.GothamBold,
            TextSize = cfg.TextSize or 12,
            TextColor3 = Color3.fromRGB(240, 238, 255),
            BackgroundTransparency = 1,
            TextWrapped = true,
            Size = UDim2.new(1, -8, 1, -8),
            Position = UDim2.fromOffset(4, 4),
            ZIndex = 12,
            Parent = btn,
        })
    end

    -- Optional badge / notification dot
    local badge
    if cfg.Badge then
        badge = Create("Frame", {
            Name = "Badge",
            Size = UDim2.fromOffset(10, 10),
            Position = UDim2.new(1, -4, 0, -4),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = cfg.BadgeColor or Color3.fromRGB(255, 95, 87),
            BorderSizePixel = 0,
            ZIndex = 13,
            Parent = btn,
        })
        Corner(999, badge)

        local badgeStroke = Stroke(Color3.fromRGB(0, 0, 0), 1.5, 0.4, badge)

        -- [FIX] Previously this was an infinite no-op loop that set
        -- static values forever. Now it actually pulses: the badge
        -- grows/shrinks and fades in a sine wave. The loop exits
        -- cleanly when the badge is destroyed.
        task.spawn(function()
            local BASE_SIZE = 10
            local PULSE_AMPLITUDE = 3
            while badge and badge.Parent do
                local t = tick()
                local pulse = 0.5 + 0.5 * math.sin(t * 3)   -- 0..1
                local size = BASE_SIZE + pulse * PULSE_AMPLITUDE
                badge.Size = UDim2.fromOffset(size, size)
                badge.BackgroundTransparency = pulse * 0.35
                task.wait(0.03)
            end
        end)
    end

    return wrap, btn, iconLbl, outerStroke, innerStroke, badge
end

local function buildTooltip(parentGui, text)
    local tip = Create("Frame", {
        Name = "FloatingButtonTooltip",
        Size = UDim2.fromOffset(0, 24),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Color3.fromRGB(20, 20, 28),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 20,
        Parent = parentGui,
    })
    Corner(6, tip)
    Stroke(Color3.fromRGB(130, 80, 255), 1, 0.5, tip)

    local lbl = Create("TextLabel", {
        Text = text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(240, 238, 255),
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 21,
        Parent = tip,
    })
    Create("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        Parent = lbl,
    })

    return tip, lbl
end

-- ============================================================
-- Public: CreateFloatingButton
-- ============================================================
--[[
    cfg = {
        Text          = "HUB",
        Icon          = nil,      -- rbxassetid://... (wins over Text)
        TextSize      = 12,
        Size          = UDim2.fromOffset(52, 52),
        Position      = UDim2.new(0, 20, 0.5, -26),
        AnchorPoint   = Vector2.new(0, 0),
        Color         = Color3,
        CornerRadius  = 14,
        SnapToEdge    = false,    -- snap to nearest screen edge on release
        SnapMargin    = 12,
        Tooltip       = nil,      -- string shown on hover
        OnClick       = function() end,
        OnRightClick  = function() end,  -- optional
        Draggable     = true,
        Badge         = false,
        BadgeColor    = Color3,
        Window        = nil,      -- optional owning window for auto-hide + theme
        HideWhenVisible = false,  -- hide when Window.Gui is visible
        DisplayOrder  = 500,
    }
]]

function LucidUI:CreateFloatingButton(cfg)
    cfg = cfg or {}

    -- Its own ScreenGui so it survives window minimize/pill/hide
    local gui = Create("ScreenGui", {
        Name = "LucidUI_FloatingButton_" .. tostring(math.floor(tick() * 1000) % 100000),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = cfg.DisplayOrder or 500,
        Parent = PlayerGui,
    })

    local wrap, btn, iconLbl, outerStroke, innerStroke, badge =
        buildButtonInstance(cfg, gui)

    local tipFrame, tipLabel
    if cfg.Tooltip and cfg.Tooltip ~= "" then
        tipFrame, tipLabel = buildTooltip(gui, cfg.Tooltip)
    end

    local obj = setmetatable({}, LucidUI.FloatingButton)

    obj.Gui      = gui
    obj.Wrap     = wrap
    obj.Button   = btn
    obj.Icon     = iconLbl
    obj.OuterStroke = outerStroke
    obj.InnerStroke = innerStroke
    obj.Badge    = badge
    obj.TooltipFrame = tipFrame
    obj.TooltipLabel = tipLabel
    obj.Window   = cfg.Window
    obj._cfg     = cfg
    obj._visible = true
    obj._conns   = {}

    local theme = (cfg.Window and cfg.Window.Theme)
              or LucidUI._lastTheme
              or LucidUI.Themes.Default
    obj.Theme = theme

    -- Accent color: cfg.Color wins, else theme accent
    local accent = cfg.Color or theme.Accent
    obj._accent = accent

    innerStroke.Color = accent
    if badge then badge.BackgroundColor3 = cfg.BadgeColor or accent end

    -- ============================================================
    -- Hover / press animations
    -- ============================================================
    btn.MouseEnter:Connect(function()
        Tween(btn, 0.15, {
            BackgroundColor3 = cfg.HoverColor or lightenColor(accent, 0.15),
        }):Play()
        Tween(innerStroke, 0.15, { Transparency = 0.0 }):Play()
        if tipFrame and tipLabel then
            tipFrame.Position = UDim2.new(
                wrap.Position.X.Scale,
                wrap.Position.X.Offset + wrap.AbsoluteSize.X + 8,
                wrap.Position.Y.Scale,
                wrap.Position.Y.Offset + (wrap.AbsoluteSize.Y - 24) / 2
            )
            tipFrame.Visible = true
            tipFrame.BackgroundTransparency = 1
            tipLabel.TextTransparency = 1
            Tween(tipFrame, 0.15, { BackgroundTransparency = 0.1 }):Play()
            Tween(tipLabel, 0.15, { TextTransparency = 0 }):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        Tween(btn, 0.20, {
            BackgroundColor3 = cfg.Color or theme.Background or Color3.fromRGB(30, 28, 45),
        }):Play()
        Tween(innerStroke, 0.20, { Transparency = 0.15 }):Play()
        if tipFrame then
            Tween(tipFrame, 0.12, { BackgroundTransparency = 1 }):Play()
            if tipLabel then Tween(tipLabel, 0.12, { TextTransparency = 1 }):Play() end
            task.delay(0.15, function()
                if tipFrame and tipFrame.Parent then tipFrame.Visible = false end
            end)
        end
    end)

    local pressStartSize = wrap.Size
    btn.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        Tween(wrap, 0.08, {
            Size = UDim2.new(
                pressStartSize.X.Scale * 0.94, pressStartSize.X.Offset,
                pressStartSize.Y.Scale * 0.94, pressStartSize.Y.Offset
            ),
        }):Play()
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        Tween(wrap, 0.15, { Size = pressStartSize }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
    end)

    -- ============================================================
    -- Click handler (differentiates tap from drag)
    -- ============================================================
    if cfg.Draggable ~= false then
        local dragging, dragStart, startPos, moved, dragInput
        local MOVE_THRESHOLD = 6

        btn.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
            dragging  = true
            moved     = false
            dragStart = input.Position
            startPos  = wrap.Position
            dragInput = input
        end)

        local dragConn = UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
            if input ~= dragInput then return end

            local delta = input.Position - dragStart
            if math.abs(delta.X) > MOVE_THRESHOLD or math.abs(delta.Y) > MOVE_THRESHOLD then
                moved = true
                wrap.AnchorPoint = Vector2.new(0, 0)
                wrap.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
        table.insert(obj._conns, dragConn)

        local endConn = UserInputService.InputEnded:Connect(function(input)
            if input ~= dragInput then return end
            dragging = false
            dragInput = nil

            if moved and cfg.SnapToEdge then
                -- Snap to nearest horizontal edge
                local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
                          or Vector2.new(1920, 1080)
                local margin = cfg.SnapMargin or 12
                local curX = wrap.AbsolutePosition.X
                local curY = wrap.AbsolutePosition.Y
                local w    = wrap.AbsoluteSize.X
                local h    = wrap.AbsoluteSize.Y

                local distLeft  = curX
                local distRight = vp.X - (curX + w)
                local targetX

                if distLeft < distRight then
                    targetX = margin
                else
                    targetX = vp.X - w - margin
                end

                local targetY = clamp(curY, margin, vp.Y - h - margin)

                Tween(wrap, 0.22, {
                    Position = UDim2.fromOffset(targetX, targetY),
                }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out):Play()
            end

            if not moved then
                PlayUISound("click")
                if cfg.OnClick then Compat.safeCallback(cfg.OnClick) end
            end
        end)
        table.insert(obj._conns, endConn)
    else
        -- Non-draggable: simple click
        BindTap(btn, function()
            PlayUISound("click")
            if cfg.OnClick then Compat.safeCallback(cfg.OnClick) end
        end)
    end

    -- Optional right-click handler
    if cfg.OnRightClick then
        btn.MouseButton2Click:Connect(function()
            Compat.safeCallback(cfg.OnRightClick)
        end)
    end

    -- ============================================================
    -- Auto-hide when bound window is visible
    -- ============================================================
    if cfg.Window and cfg.HideWhenVisible then
        local function syncVisibility()
            local w = obj.Window
            if not w or not w.Gui then return end
            -- Window is "visible" if its Gui is enabled and Main is visible
            local isOpen = w.Gui.Enabled and w.Main and w.Main.Visible and not w.Floating
            if isOpen then
                obj:Hide()
            else
                obj:Show()
            end
        end

        if cfg.Window.Main then
            table.insert(cfg.Window._conns, cfg.Window.Main:GetPropertyChangedSignal("Visible"):Connect(syncVisibility))
        end
        if cfg.Window.Gui then
            table.insert(cfg.Window._conns, cfg.Window.Gui:GetPropertyChangedSignal("Enabled"):Connect(syncVisibility))
        end
        task.defer(syncVisibility)
    end

    -- ============================================================
    -- Theme registration
    -- ============================================================
    local function applyTheme(t)
        obj.Theme = t
        local c = cfg.Color or t.Accent
        obj._accent = c
        innerStroke.Color = c
        if cfg.Icon then
            -- nothing to retint on images
        else
            if iconLbl and iconLbl:IsA("TextLabel") then
                iconLbl.TextColor3 = t.TextPrimary
            end
        end
        if badge then badge.BackgroundColor3 = cfg.BadgeColor or c end
    end

    if cfg.Window then
        cfg.Window:_registerTheme(applyTheme)
    end

    -- ============================================================
    -- Public methods
    -- ============================================================
    function obj:Show()
        if self._visible then return end
        self._visible = true
        self.Gui.Enabled = true
        self.Wrap.Visible = true
    end

    function obj:Hide()
        if not self._visible then return end
        self._visible = false
        self.Gui.Enabled = false
    end

    function obj:SetVisible(v)
        if v then self:Show() else self:Hide() end
    end

    function obj:SetPosition(udim2)
        self.Wrap.Position = udim2
    end

    function obj:SetIcon(id)
        if iconLbl and iconLbl:IsA("ImageLabel") then
            iconLbl.Image = id
        end
    end

    function obj:SetText(text)
        if iconLbl and iconLbl:IsA("TextLabel") then
            iconLbl.Text = tostring(text)
        end
    end

    function obj:SetColor(c)
        self._accent = c
        self.InnerStroke.Color = c
        if self.Badge then self.Badge.BackgroundColor3 = c end
    end

    function obj:SetBadge(on)
        if on and not self.Badge then
            -- build badge on demand
            local b = Create("Frame", {
                Name = "Badge",
                Size = UDim2.fromOffset(10, 10),
                Position = UDim2.new(1, -4, 0, -4),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = cfg.BadgeColor or self._accent,
                BorderSizePixel = 0,
                ZIndex = 13,
                Parent = self.Button,
            })
            Corner(999, b)
            self.Badge = b

            -- [FIX] Same animated pulse as the primary badge path
            task.spawn(function()
                local BASE_SIZE = 10
                local PULSE_AMPLITUDE = 3
                while b and b.Parent do
                    local t = tick()
                    local pulse = 0.5 + 0.5 * math.sin(t * 3)
                    local size = BASE_SIZE + pulse * PULSE_AMPLITUDE
                    b.Size = UDim2.fromOffset(size, size)
                    b.BackgroundTransparency = pulse * 0.35
                    task.wait(0.03)
                end
            end)
        elseif not on and self.Badge then
            pcall(function() self.Badge:Destroy() end)
            self.Badge = nil
        end
    end

    function obj:Destroy()
        if self._conns then
            for _, c in ipairs(self._conns) do
                if typeof(c) == "RBXScriptConnection" then
                    pcall(function() c:Disconnect() end)
                end
            end
            self._conns = {}
        end
        if self.Gui then
            pcall(function() self.Gui:Destroy() end)
            self.Gui = nil
        end
    end

    -- Track for cleanup
    LucidUI._floatingButtons = LucidUI._floatingButtons or {}
    table.insert(LucidUI._floatingButtons, obj)

    return obj
end

-- ============================================================
-- Window-scoped wrapper
-- ============================================================
function LucidUI.Window:CreateFloatingButton(cfg)
    cfg = cfg or {}
    cfg.Window = self
    return LucidUI:CreateFloatingButton(cfg)
end

-- ============================================================
-- Cleanup
-- ============================================================
LucidUI:OnCleanup(function()
    if LucidUI._floatingButtons then
        for _, btn in ipairs(LucidUI._floatingButtons) do
            pcall(function() btn:Destroy() end)
        end
        LucidUI._floatingButtons = {}
    end
    -- Fallback sweep: destroy any stragglers by ScreenGui name
    pcall(function()
        if PlayerGui then
            for _, gui in ipairs(PlayerGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Name:match("^LucidUI_FloatingButton_") then
                    pcall(function() gui:Destroy() end)
                end
            end
        end
    end)
    print("[LucidUI] FloatingButton cleaned up")
end)

-- ============================================================
-- Module: 06d_floatingbutton.lua
-- ============================================================
--[[
    Floating Button — a draggable, always-visible button that
    survives window minimize/pill/hide.

    Also provides CreateFlagButton — a floating button linked to
    an existing UI element that auto-syncs state and appearance.

    [FIX] Badge pulse loop was an infinite no-op (set static values,
    did nothing). Now it actually breathes.

    [NEW] CreateFlagButton — see the section near the bottom.
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
        Stroke(Color3.fromRGB(0, 0, 0), 1.5, 0.4, badge)

        task.spawn(function()
            local BASE_SIZE = 10
            local PULSE_AMPLITUDE = 3
            while badge and badge.Parent do
                local t = tick()
                local pulse = 0.5 + 0.5 * math.sin(t * 3)
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
function LucidUI:CreateFloatingButton(cfg)
    cfg = cfg or {}

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

    local accent = cfg.Color or theme.Accent
    obj._accent = accent

    innerStroke.Color = accent
    if badge then badge.BackgroundColor3 = cfg.BadgeColor or accent end

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
        BindTap(btn, function()
            PlayUISound("click")
            if cfg.OnClick then Compat.safeCallback(cfg.OnClick) end
        end)
    end

    if cfg.OnRightClick then
        btn.MouseButton2Click:Connect(function()
            Compat.safeCallback(cfg.OnRightClick)
        end)
    end

    if cfg.Window and cfg.HideWhenVisible then
        local function syncVisibility()
            local w = obj.Window
            if not w or not w.Gui then return end
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
-- Flag Button — floating button linked to an existing element
-- ============================================================
--[[
    Creates a floating button that mirrors and controls an existing
    UI element (Toggle, Checkbox, Slider, Dropdown, Keybind, etc.).

    How it behaves per element type:
        boolean   → click toggles it. Button color signals state.
        number    → click cycles through Snapshots (if provided).
                    Otherwise display-only.
        string    → click cycles through CycleOptions (if provided).
                    Otherwise display-only.
        Color3    → display-only (shows "COLOR" or config.Text)
        EnumItem  → display-only (shows key name)
        table     → display-only (shows count of truthy values)

    Two-way sync: any change to the element — whether it came from
    the flag button itself, the settings panel, a LoadConfig call,
    or dev mode — is reflected back on the button within ~100 ms
    via a lightweight poll.

    For boolean toggles, note that the element's own Callback does
    NOT fire on programmatic Set (this is intentional in the base
    library to avoid double-fires on config load). If your feature
    needs to react to the flag button's click, pass OnToggle — it
    fires with the new value every time the button is pressed.

    Usage:
        local aimToggle = Combat:CreateToggle({
            Name = "Aim Assist", Flag = "aim",
            Callback = function(v) StartAim(v) end,
        })

        LucidUI:CreateFlagButton(aimToggle, {
            Text     = "AIM",
            Position = UDim2.new(1, -90, 0.4, 0),
            OnToggle = function(newValue)
                StartAim(newValue)
            end,
        })

    Options:
        Text, Position, Size, CornerRadius, Color, HoverColor
        Icon, Tooltip, SnapToEdge, SnapMargin, Draggable, DisplayOrder
            — same as CreateFloatingButton

        OnText, OffText     — custom labels for boolean states
                              (default: label text with color change only)
        Suffix              — appended to numbers ("%", "s", etc.)
        OnColor, OffColor   — button tint for active/inactive
        Interactive         — force click behavior on/off
                              (auto-detected by default)
        Snapshots           — numeric values to cycle through
                              e.g. { 16, 50, 100, 200 }
        CycleOptions        — string values to cycle through
                              e.g. { "Off", "Low", "High" }
        OnToggle            — callback(newValue) fired on each click
        OnClick             — callback() fired when non-interactive
        OnRightClick        — same as CreateFloatingButton
        Window, HideWhenVisible — same as CreateFloatingButton
]]

local function flagValuesEqual(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    -- Tables are mutated in place, so reference equality isn't
    -- enough. Compare contents both ways.
    for k, v in pairs(a) do
        if b[k] ~= v then return false end
    end
    for k, v in pairs(b) do
        if a[k] ~= v then return false end
    end
    return true
end

function LucidUI:CreateFlagButton(element, config)
    config = config or {}

    if not element or type(element.Get) ~= "function" then
        warn("[LucidUI] CreateFlagButton: element must have a Get() method")
        return nil
    end

    local okGet, initial = pcall(function() return element:Get() end)
    if not okGet then
        warn("[LucidUI] CreateFlagButton: element.Get() failed")
        return nil
    end

    local kind = typeof(initial)

    -- Auto-detect interactivity
    local interactive = config.Interactive
    if interactive == nil then
        interactive = (kind == "boolean")
            or (kind == "number" and config.Snapshots)
            or (kind == "string" and config.CycleOptions)
    end

    -- Compute button text and active flag from a raw element value
    local function computeDisplay(value)
        local active = false
        local text   = config.Text or "BTN"

        if kind == "boolean" then
            active = value == true
            if config.OnText or config.OffText then
                text = active and (config.OnText or text) or (config.OffText or text)
            end
            -- else: label text stays put; color signals state

        elseif kind == "number" then
            local n = value or 0
            local nStr = (n == math.floor(n))
                and tostring(math.floor(n))
                or string.format("%.2f", n)
            text = nStr .. (config.Suffix or "")
            if config.Text then text = config.Text .. " " .. text end
            active = n > 0

        elseif kind == "string" then
            local s = tostring(value or "")
            text = (s ~= "" and s or "NONE")
            if config.Text then text = config.Text .. " " .. text end
            active = s ~= "" and s:lower() ~= "none"

        elseif kind == "EnumItem" then
            text = tostring(value.Name)
            active = true

        elseif kind == "Color3" then
            text = config.Text or "COLOR"
            active = true

        elseif kind == "table" then
            local n = 0
            for _, v in pairs(value) do
                if v then n = n + 1 end
            end
            text = tostring(n)
            if config.Text then text = config.Text .. " " .. text end
            active = n > 0
        end

        return text, active
    end

    -- Build the underlying floating button
    local btn = self:CreateFloatingButton({
        Text            = config.Text or "BTN",
        Icon            = config.Icon,
        Position        = config.Position,
        Size            = config.Size,
        CornerRadius    = config.CornerRadius,
        Color           = config.Color,
        HoverColor      = config.HoverColor,
        SnapToEdge      = config.SnapToEdge,
        SnapMargin      = config.SnapMargin,
        Tooltip         = config.Tooltip,
        Draggable       = config.Draggable ~= false,
        DisplayOrder    = config.DisplayOrder,
        Badge           = config.Badge,
        BadgeColor      = config.BadgeColor,
        Window          = config.Window,
        HideWhenVisible = config.HideWhenVisible,

        OnClick = function()
            if not interactive then
                if config.OnClick then Compat.safeCallback(config.OnClick) end
                return
            end

            if kind == "boolean" then
                local newValue = not element:Get()
                element:Set(newValue)
                if config.OnToggle then
                    Compat.safeCallback(config.OnToggle, newValue)
                end

            elseif kind == "number" and config.Snapshots then
                local cur = element:Get()
                local snaps = config.Snapshots
                local idx = 1
                for i, v in ipairs(snaps) do
                    if math.abs(cur - v) < 0.001 then idx = i break end
                end
                idx = (idx % #snaps) + 1
                local nextValue = snaps[idx]
                element:Set(nextValue)
                if config.OnToggle then
                    Compat.safeCallback(config.OnToggle, nextValue)
                end

            elseif kind == "string" and config.CycleOptions then
                local cur = element:Get()
                local opts = config.CycleOptions
                local idx = 1
                for i, v in ipairs(opts) do
                    if v == cur then idx = i break end
                end
                idx = (idx % #opts) + 1
                local nextValue = opts[idx]
                element:Set(nextValue)
                if config.OnToggle then
                    Compat.safeCallback(config.OnToggle, nextValue)
                end
            end
        end,

        OnRightClick = config.OnRightClick,
    })

    if not btn then return nil end

    btn.Element     = element
    btn.Kind        = kind
    btn.Interactive = interactive

    local lastValue  = initial
    local lastAccent = btn.Theme and btn.Theme.Accent

    local function applyState(value)
        local text, active = computeDisplay(value)
        btn:SetText(text)

        local accent   = btn.Theme and btn.Theme.Accent or Color3.fromRGB(130, 80, 255)
        local onColor  = config.OnColor  or accent
        local offColor = config.OffColor or config.Color or Color3.fromRGB(30, 28, 45)

        btn:SetColor(active and onColor or offColor)
        lastAccent = btn.Theme and btn.Theme.Accent
    end

    applyState(initial)

    -- Poll element state at 10 Hz. Also catches theme changes so the
    -- button keeps its active/inactive tint in sync when the user
    -- switches themes at runtime.
    local accum = 0
    local pollConn
    pollConn = RunService.RenderStepped:Connect(function(dt)
        if not btn.Gui or not btn.Gui.Parent then
            pcall(function() pollConn:Disconnect() end)
            return
        end

        accum = accum + dt
        if accum < 0.1 then return end
        accum = 0

        local okNow, current = pcall(function() return element:Get() end)
        if not okNow then
            pcall(function() pollConn:Disconnect() end)
            return
        end

        local themeAccent = btn.Theme and btn.Theme.Accent
        if not flagValuesEqual(current, lastValue) or themeAccent ~= lastAccent then
            lastValue = current
            applyState(current)
        end
    end)
    btn._pollConn = pollConn

    -- Manual re-sync
    function btn:Refresh()
        local okNow, current = pcall(function() return element:Get() end)
        if okNow then
            lastValue = current
            applyState(current)
        end
    end

    function btn:GetElement()
        return element
    end

    -- Wrap Destroy so the poll disconnects with the button
    local origDestroy = btn.Destroy
    btn.Destroy = function(self2, ...)
        if self2._pollConn then
            pcall(function() self2._pollConn:Disconnect() end)
            self2._pollConn = nil
        end
        return origDestroy(self2, ...)
    end

    return btn
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

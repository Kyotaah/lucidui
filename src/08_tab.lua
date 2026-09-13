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
        for _, p in ipairs(iconParts) do
            p.BackgroundColor3 = c
        end
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

        for _, p in ipairs(t.IconParts or {}) do
            Tween(p, 0.18, { BackgroundColor3 = c }):Play()
        end

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
    section.Collapsible = cfg.Collapsible ~= false
    section.Expanded    = cfg.StartExpanded ~= false
    section._order      = self._orderCounter * 1000
    section._elemOrder  = section._order
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
            if not section.Collapsible then return end
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
        else
            wrapper.AutomaticSize = Enum.AutomaticSize.None
            wrapper.Size = UDim2.new(1, 0, 0, 0)
        end
    end)

    table.insert(self.Sections, section)
    return section
end

function LucidUI.Section:_measureHeight()
    local layout = self.Container:FindFirstChildOfClass("UIListLayout")
    if layout then
        local h = layout.AbsoluteContentSize.Y
        if h > 0 then return h end
    end
    local h = self.Container.Size.Y.Offset
    if h > 0 then return h end
    local total, count = 0, 0
    for _, child in ipairs(self.Container:GetChildren()) do
        if child:IsA("GuiObject") and child.Visible then
            total = total + child.Size.Y.Offset
            count = count + 1
        end
    end
    if count > 1 then total = total + (count - 1) * 8 end
    return total
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

    -- Read real content height from the layout
    local layout = container:FindFirstChildOfClass("UIListLayout")
    local contentH = 0
    if layout then
        contentH = layout.AbsoluteContentSize.Y
    end
    if contentH <= 0 then
        contentH = container.Size.Y.Offset
    end
    if contentH <= 0 then
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("GuiObject") and child.Visible then
                contentH = contentH + child.Size.Y.Offset
            end
        end
    end
    if contentH <= 0 then contentH = 40 end

    -- Non-collapsible or instant: snap
    if not self.Collapsible or instant then
        wrapper.AutomaticSize = Enum.AutomaticSize.None
        if state then
            wrapper.Size = UDim2.new(1, 0, 0, contentH)
            wrapper.AutomaticSize = Enum.AutomaticSize.Y
        else
            wrapper.Size = UDim2.new(1, 0, 0, 0)
        end
        return
    end

    -- Freeze container so its children don't fight the tween
    container.AutomaticSize = Enum.AutomaticSize.None
    container.Size = UDim2.new(1, 0, 0, contentH)
    wrapper.AutomaticSize = Enum.AutomaticSize.None

    -- Set starting size
    if state then
        wrapper.Size = UDim2.new(1, 0, 0, 0)
    else
        wrapper.Size = UDim2.new(1, 0, 0, contentH)
    end

    local targetH = state and contentH or 0
    local t = TweenService:Create(wrapper,
        TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Size = UDim2.new(1, 0, 0, targetH) }
    )
    t:Play()

    t.Completed:Connect(function()
        container.AutomaticSize = Enum.AutomaticSize.Y
        if self.Expanded then
            wrapper.AutomaticSize = Enum.AutomaticSize.Y
        end
    end)
end

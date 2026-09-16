--[[
    Tab + Section — layout containers. Icon builders now live in
    03_icons.lua and are accessed via LucidUI.IconBuilders.

    [IMPROVEMENT] Added GetTab, GetSection, SetVisible, SetTitle,
    Destroy. Bigger tap targets. Section arrow animates via rotation.
]]

local function IconHolder(parent, size)
    return Create("Frame", {
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        Parent = parent,
    })
end

-- [IMPROVEMENT] Safe recolor that skips nil/destroyed parts.
local function RecolorIconParts(parts, color)
    if not parts then return end
    for _, p in ipairs(parts) do
        if p and typeof(p) == "Instance" and p.Parent then
            if p:IsA("UIStroke") then
                p.Color = color
            elseif p:IsA("GuiObject") then
                p.BackgroundColor3 = color
            end
        end
    end
end

-- ============================================================
-- Tab
-- ============================================================
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

    -- [IMPROVEMENT] Taller tab button for mobile
    local TAB_H = 34
    local btn = Create("TextButton", {
        Name = tab.Name,
        Text = "",
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Size = UDim2.fromOffset(0, TAB_H),
        ZIndex = 2,
        Parent = self.TabStrip,
    })
    Corner(10, btn)

    local iconHolder, iconParts = nil, {}
    local ICON_SIZE = 14
    local ICON_PAD = 10

    if builder then
        local ok, holder, parts = pcall(builder, btn, ICON_SIZE, self.Theme.TabInactive)
        if ok and holder then
            iconHolder = holder
            iconParts = parts or {}
            iconHolder.Position = UDim2.fromOffset(ICON_PAD, (TAB_H - ICON_SIZE) / 2)
            iconHolder.ZIndex = 3
        end
    end

    local labelX = iconHolder and (ICON_PAD + ICON_SIZE + 6) or 12
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

    local ts = TextService:GetTextSize(tab.Name, 13, Enum.Font.GothamMedium, Vector2.new(1000, TAB_H))
    btn.Size = UDim2.fromOffset(ts.X + labelX + 14, TAB_H)

    tab.Button    = btn
    tab.Label     = labelLbl
    tab.IconParts = iconParts
    tab.Page      = nil -- set below
    tab._visible  = true

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
        ScrollingEnabled = true,
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
        if not tab._visible then return end
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
        t.Page.Visible = active and t._visible

        local c = active and self.Theme.TabActive or self.Theme.TabInactive

        pcall(function()
            Tween(t.Button, 0.18, { BackgroundTransparency = active and 0.20 or 1 }):Play()
            Tween(t.Label, 0.18, { TextColor3 = c }):Play()
        end)
        RecolorIconParts(t.IconParts or {}, c)

        if active then
            for _, section in ipairs(t.Sections or {}) do
                if section.Expanded and section.Wrapper then
                    section.Wrapper.AutomaticSize = Enum.AutomaticSize.Y
                end
            end
            t.Page.Position = UDim2.fromOffset(8, 0)
            Tween(t.Page, 0.20, { Position = UDim2.fromOffset(0, 0) }):Play()
        end
    end

    self.ActiveTab = tab
end

-- [IMPROVEMENT] Find a tab by name.
function LucidUI.Window:GetTab(name)
    for _, t in ipairs(self.Tabs) do
        if t.Name == name then return t end
    end
    return nil
end

-- [IMPROVEMENT] Hide/show a tab.
function LucidUI.Tab:SetVisible(on)
    self._visible = on and true or false
    self.Button.Visible = self._visible

    if not self._visible and self.Window.ActiveTab == self then
        -- Pick the next visible tab
        for _, t in ipairs(self.Window.Tabs) do
            if t._visible then
                self.Window:SelectTab(t)
                return
            end
        end
    end
end

function LucidUI.Tab:GetSection(name)
    for _, s in ipairs(self.Sections) do
        if s.Name == name then return s end
    end
    return nil
end

-- ============================================================
-- Section
-- ============================================================
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
    section._elements   = {}
    self._orderCounter = self._orderCounter + 1

    if section.Name ~= "" then
        -- [IMPROVEMENT] Taller header for mobile
        local HEADER_H = 26
        local headerBtn = Create("TextButton", {
            Text = "",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, HEADER_H),
            LayoutOrder = section._order,
            ZIndex = 2,
            Parent = self.Page,
        })

        local arrowTxt = Create("TextLabel", {
            Text = "v",
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = self.Window.Theme.TextMuted,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(2, 0),
            Size = UDim2.fromOffset(16, HEADER_H),
            Rotation = section.Expanded and 0 or -90, -- [IMPROVEMENT] animate via rotation
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
    table.insert(self._elements, frame)
    return frame
end

function LucidUI.Section:SetExpanded(state, instant)
    if state == self.Expanded and not instant then return end
    self.Expanded = state

    if self.Arrow then
        pcall(function()
            Tween(self.Arrow, 0.22, {
                Rotation = state and 0 or -90,
            }, Enum.EasingStyle.Quart):Play()
        end)
    end

    local wrapper   = self.Wrapper
    local container = self.Container

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

    if state then
        wrapper.Size = UDim2.new(1, 0, 0, 0)
    else
        wrapper.Size = UDim2.new(1, 0, 0, target)
    end

    local goalH = state and target or 0

    pcall(function()
        TweenService:Create(
            wrapper,
            TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            { Size = UDim2.new(1, 0, 0, goalH) }
        ):Play()
    end)

    task.delay(0.24, function()
        if not wrapper.Parent then return end
        container.AutomaticSize = Enum.AutomaticSize.Y
        if self.Expanded then
            wrapper.AutomaticSize = Enum.AutomaticSize.Y
        end
    end)
end

-- [IMPROVEMENT] Rename a section at runtime.
function LucidUI.Section:SetTitle(newName)
    if not self.Header then return end
    self.Name = newName
    self.Header.Text = newName:upper()
end

-- [IMPROVEMENT] Count elements.
function LucidUI.Section:GetElementCount()
    return #self._elements
end

-- [IMPROVEMENT] Remove a section entirely.
function LucidUI.Section:Destroy()
    if self.HeaderBtn then pcall(function() self.HeaderBtn:Destroy() end) end
    if self.Wrapper   then pcall(function() self.Wrapper:Destroy()   end) end

    local tab = self.Tab
    if tab then
        for i, s in ipairs(tab.Sections) do
            if s == self then
                table.remove(tab.Sections, i)
                break
            end
        end
    end
end

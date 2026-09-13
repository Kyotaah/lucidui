--[[
    Tab + Section — the layout containers that elements live inside.

    Tab:
      • Renders a pill-shaped button in the window's tab strip
      • Owns a full-size ScrollingFrame page that shows when active
      • Handles hover / selection state, colors follow the theme

    Section:
      • Collapsible header with an ASCII chevron (v / >)
      • A "wrapper" Frame with ClipsDescendants owns the animated height
      • A nested "container" Frame auto-sizes to its children
      • Elements attach to the container via section:_track(frame)

    Height measurement is deterministic: we sum each child's declared
    Size.Y.Offset plus the list padding. This avoids the layout-timing
    bugs you get when a tween races the layout pass.
]]

-- ============================================================
-- Tab class
-- ============================================================
LucidUI.Tab = {}
LucidUI.Tab.__index = LucidUI.Tab

function LucidUI.Window:CreateTab(config)
    config = config or {}

    local tab = setmetatable({}, LucidUI.Tab)
    tab.Name        = config.Name or "Tab"
    tab.Window      = self
    tab.Sections    = {}
    tab._orderCounter = 0

    -- --------------------------------------------------------
    -- Button in the tab strip
    -- --------------------------------------------------------
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

    local labelLbl = Create("TextLabel", {
        Text = tab.Name,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = self.Theme.TabInactive,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Center,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 1, 0),
        ZIndex = 2,
        Parent = btn,
    })

    -- Size the button to fit its text
    local ts = TextService:GetTextSize(tab.Name, 13, Enum.Font.GothamMedium, Vector2.new(1000, 30))
    btn.Size = UDim2.fromOffset(ts.X + 24, 30)

    tab.Button = btn
    tab.Label  = labelLbl

    btn.MouseEnter:Connect(function()
        if tab == self.ActiveTab then return end
        Tween(btn, 0.15, { BackgroundTransparency = 0.7 }):Play()
    end)
    btn.MouseLeave:Connect(function()
        if tab == self.ActiveTab then return end
        Tween(btn, 0.15, { BackgroundTransparency = 1 }):Play()
    end)

    -- --------------------------------------------------------
    -- Page
    -- --------------------------------------------------------
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

    btn.MouseButton1Click:Connect(function()
        self:SelectTab(tab)
    end)

    table.insert(self.Tabs, tab)
    if not self.ActiveTab then
        self:SelectTab(tab)
    end

    return tab
end

-- ============================================================
-- Select tab
-- ============================================================
function LucidUI.Window:SelectTab(tab)
    for _, t in ipairs(self.Tabs) do
        local active = (t == tab)
        t.Page.Visible = active

        local tc = active and self.Theme.TabActive or self.Theme.TabInactive

        Tween(t.Button, 0.18, {
            BackgroundTransparency = active and 0.20 or 1,
        }):Play()
        Tween(t.Label, 0.18, {
            TextColor3 = tc,
        }):Play()

        if active then
            t.Page.Position = UDim2.fromOffset(8, 0)
            Tween(t.Page, 0.20, { Position = UDim2.fromOffset(0, 0) }):Play()
        end
    end

    self.ActiveTab = tab
end

-- ============================================================
-- Section class
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
    section.Collapsible = cfg.Collapsible ~= false
    section.Expanded    = cfg.StartExpanded ~= false

    section._order      = self._orderCounter * 1000
    section._elemOrder  = section._order
    section._targetHeight = 0

    self._orderCounter = self._orderCounter + 1

    -- --------------------------------------------------------
    -- Header
    -- --------------------------------------------------------
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

    -- --------------------------------------------------------
    -- Wrapper (owns the animated height)
    -- --------------------------------------------------------
    local wrapper = Create("Frame", {
        Name = "Wrapper",
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        LayoutOrder = section._order + 1,
        ZIndex = 2,
        Parent = self.Page,
    })

    -- --------------------------------------------------------
    -- Container (auto-sizes to its children)
    -- --------------------------------------------------------
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

    -- --------------------------------------------------------
    -- Measure after layout settles, then snap the wrapper to fit
    -- --------------------------------------------------------
    task.spawn(function()
        task.wait()
        task.wait()
        if not wrapper.Parent then return end

        local h = section:_measureHeight()
        section._targetHeight = h

        wrapper.Size = UDim2.new(1, 0, 0, section.Expanded and h or 0)
    end)

    table.insert(self.Sections, section)
    return section
end

-- ============================================================
-- Deterministic height measurement
-- ============================================================
function LucidUI.Section:_measureHeight()
    local total, count = 0, 0

    for _, child in ipairs(self.Container:GetChildren()) do
        if child:IsA("GuiObject") and child.Visible then
            total = total + child.Size.Y.Offset
            count = count + 1
        end
    end

    -- Add the list padding between items (8px)
    if count > 1 then
        total = total + (count - 1) * 8
    end

    return total
end

-- ============================================================
-- Element order counter
-- ============================================================
function LucidUI.Section:_nextOrder()
    self._elemOrder = self._elemOrder + 1
    return self._elemOrder
end

-- ============================================================
-- Attach an element to the container
-- ============================================================
function LucidUI.Section:_track(frame)
    frame.Parent = self.Container
    return frame
end

-- ============================================================
-- Expand / collapse
-- ============================================================
function LucidUI.Section:SetExpanded(state, instant)
    if state == self.Expanded and not instant then return end

    self.Expanded = state

    if self.Arrow then
        self.Arrow.Text = state and "v" or ">"
    end

    local target = self:_measureHeight()
    self._targetHeight = target

    if instant or not self.Collapsible then
        self.Wrapper.Size = UDim2.new(1, 0, 0, state and target or 0)
        return
    end

    TweenService:Create(
        self.Wrapper,
        state and Ease.Out(0.30) or Ease.In(0.28),
        { Size = UDim2.new(1, 0, 0, state and target or 0) }
    ):Play()
end

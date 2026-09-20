-- ============================================================
-- Module: 08h_void_components.lua
-- ============================================================
--[[
    VoidUI Components — Section-level widgets that RayVoid's fork
    had but LucidUI doesn't. Styled via LucidUI.VoidStyle so they
    match whatever theme is active.

    Adds to LucidUI.Section:
      • CreateVoidProgressBar  — accent-styled bar (separate from
                                 the plain CreateProgressBar in
                                 09_elements.lua)
      • CreateCardGrid         — grid of selectable image cards
      • CreateFilteredCardGrid — same + group dropdown filter
      • CreateMultiToggle      — list of independent pill toggles

    NO tracking. NO network. NO clipboard.
]]

local VS   = LucidUI.VoidStyle
local VP   = LucidUI.VoidPalette
local VT   = TweenService

-- ============================================================
-- Shared helpers
-- ============================================================
local function getWin(section)
    return section.Tab and section.Tab.Window
end

local function themeOf(section)
    local w = getWin(section)
    return w and w.Theme or LucidUI._lastTheme or LucidUI.Themes.Default
end

-- Defer-apply a theme callback once the window is registered.
local function registerTheme(section, fn)
    local w = getWin(section)
    if w then w:_registerTheme(fn) end
end

-- ============================================================
-- CreateVoidProgressBar
-- ============================================================
--[[
    Void-styled progress bar. Same signature as CreateProgressBar
    but with the accent-bar + gradient + top-shine treatment.

    Usage:
        section:CreateVoidProgressBar({
            Name        = "Loading",
            Value       = 0,
            Max         = 1,
            ShowPercent = true,
            Flag        = "loading_bar",
            Callback    = function(value, ratio) end,
        })
]]

function LucidUI.Section:CreateVoidProgressBar(config)
    config = config or {}
    local theme = themeOf(self)

    local row = Create("Frame", {
        Name = "VoidProgressBar",
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans or 0.25,
        Size = UDim2.new(1, 0, 0, 56),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })
    Corner(10, row)
    local rowStroke = Stroke(theme.Border, 1, (theme.BorderTrans or 0.75) + 0.05, row)

    -- Accent bar (the VoidUI signature element)
    local bar, barGrad = VS.AccentBar(row)

    -- Label + value
    local label = Create("TextLabel", {
        Text = config.Name or "Progress",
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(16, 8),
        Size = UDim2.new(1, -100, 0, 18),
        ZIndex = 3,
        Parent = row,
    })

    local valueLbl = Create("TextLabel", {
        Text = "",
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = theme.Accent,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.fromOffset(16, 8),
        Size = UDim2.new(1, -32, 0, 18),
        ZIndex = 3,
        Parent = row,
    })

    -- Track + fill
    local track = Create("Frame", {
        Size = UDim2.new(1, -32, 0, 8),
        Position = UDim2.new(0, 16, 1, -18),
        BackgroundColor3 = theme.SliderTrack,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = row,
    })
    Corner(4, track)

    local fill = Create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = track,
    })
    Corner(4, fill)

    -- Gradient overlay on the fill
    local fillGrad = Create("UIGradient", {
        Color = ColorSequence.new(theme.Accent, VP and VP.AccentPink or theme.Accent),
        Rotation = 0,
        Parent = fill,
    })

    -- Highlight strip along the top of the fill for extra polish
    local fillShine = Create("Frame", {
        Size = UDim2.new(1, 0, 0.5, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.75,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = fill,
    })
    Corner(3, fillShine)

    -- State + methods
    local minV   = config.Min   or 0
    local maxV   = config.Max   or (config.IsPercent == false and 100 or 1)
    local value  = math.clamp(config.Value or minV, minV, maxV)
    local suffix = config.Suffix or ""
    local showPct = config.ShowPercent ~= false

    local function formatValue()
        if showPct and maxV == 1 then
            return math.floor(value * 100) .. "%"
        elseif showPct and maxV == 100 then
            return math.floor(value) .. "%"
        else
            return tostring(math.floor(value)) .. suffix
        end
    end

    local function setValue(v, silent)
        value = math.clamp(v, minV, maxV)
        local rel = (value - minV) / math.max(maxV - minV, 0.0001)
        VT:Create(fill, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.new(rel, 0, 1, 0),
        }):Play()
        valueLbl.Text = formatValue()
        if not silent and config.Callback then
            Compat.safeCallback(config.Callback, value, rel)
        end
        if config.Flag and getWin(self) then
            getWin(self)._configData[config.Flag] = value
        end
    end

    -- Initial layout without animation
    local initRel = (value - minV) / math.max(maxV - minV, 0.0001)
    fill.Size = UDim2.new(initRel, 0, 1, 0)
    valueLbl.Text = formatValue()

    -- Theme hook
    registerTheme(self, function(t)
        row.BackgroundColor3 = t.Surface
        rowStroke.Color      = t.Border
        label.TextColor3     = t.TextPrimary
        valueLbl.TextColor3  = t.Accent
        track.BackgroundColor3 = t.SliderTrack
        fill.BackgroundColor3  = t.Accent
        if fillGrad then
            fillGrad.Color = ColorSequence.new(
                t.Accent,
                VP and VP.AccentPink or t.Accent
            )
        end
        if barGrad then
            barGrad.Color = ColorSequence.new(
                t.Accent,
                VP and VP.AccentPink or t.Accent
            )
        end
    end)

    self:_track(row)

    local obj = {
        Instance = row,
        Flag = config.Flag,
        Set = function(_, v) setValue(v, true) end,
        Get = function() return value end,
        SetLabel = function(_, text) label.Text = tostring(text) end,
    }
    if config.Flag then
        local w = getWin(self)
        if w then
            w._elementsByFlag[config.Flag] = obj
            w._configData[config.Flag] = value
        end
    end

    return obj
end

-- ============================================================
-- CreateMultiToggle
-- ============================================================
function LucidUI.Section:CreateMultiToggle(config)
    config = config or {}
    local theme = themeOf(self)
    local options = config.Options or {}
    local rowH = 32
    local gap = 6
    local totalH = 24 + #options * (rowH + gap)

    local container = Create("Frame", {
        Name = "VoidMultiToggle",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, totalH),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })

    if config.Label then
        Create("TextLabel", {
            Text = config.Label,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = theme.TextMuted,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, 20),
            ZIndex = 3,
            Parent = container,
        })
    end

    local selected = {}
    local refs = {}

    for i, opt in ipairs(options) do
        local yPos = 24 + (i - 1) * (rowH + gap)

        local row = Create("Frame", {
            BackgroundColor3 = theme.Surface,
            BackgroundTransparency = theme.SurfaceTrans or 0.25,
            Size = UDim2.new(1, 0, 0, rowH),
            Position = UDim2.new(0, 0, 0, yPos),
            ZIndex = 3,
            Parent = container,
        })
        Corner(8, row)
        local rowStroke = Stroke(theme.Border, 1, (theme.BorderTrans or 0.75) + 0.05, row)

        local bar, barGrad = VS.AccentBar(row, { height = 0.5, y = 0.25 })

        local optLabel = Create("TextLabel", {
            Text = tostring(opt),
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = theme.TextPrimary,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(16, 0),
            Size = UDim2.new(1, -80, 1, 0),
            ZIndex = 4,
            Parent = row,
        })

        -- Pill toggle
        local pill = Create("Frame", {
            Size = UDim2.fromOffset(40, 20),
            Position = UDim2.new(1, -52, 0.5, -10),
            BackgroundColor3 = theme.ToggleOff or VP and VP.BgDeep or theme.Surface,
            BorderSizePixel = 0,
            ZIndex = 4,
            Parent = row,
        })
        Corner(10, pill)

        local knob = Create("Frame", {
            Size = UDim2.fromOffset(14, 14),
            Position = UDim2.new(0, 3, 0.5, -7),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel = 0,
            ZIndex = 5,
            Parent = pill,
        })
        Corner(7, knob)

        local state = false
        local function setState(v, silent)
            state = v
            local t = themeOf(self)
            if state then
                VT:Create(pill, TweenInfo.new(0.20), {
                    BackgroundColor3 = t.Accent,
                }):Play()
                VT:Create(knob, TweenInfo.new(0.20, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Position = UDim2.new(1, -17, 0.5, -7),
                }):Play()
                selected[opt] = true
            else
                VT:Create(pill, TweenInfo.new(0.20), {
                    BackgroundColor3 = t.ToggleOff or t.Surface,
                }):Play()
                VT:Create(knob, TweenInfo.new(0.20, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Position = UDim2.new(0, 3, 0.5, -7),
                }):Play()
                selected[opt] = nil
            end
            if not silent and config.Callback then
                Compat.safeCallback(config.Callback, selected)
            end
            if config.Flag and getWin(self) then
                getWin(self)._configData[config.Flag] = selected
            end
        end

        refs[opt] = { setState = setState, getState = function() return state end, row = row, bar = bar, barGrad = barGrad }

        local clickArea = Create("TextButton", {
            Text = "",
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 6,
            Parent = row,
        })
        BindTap(clickArea, function()
            PlayUISound("click")
            setState(not state)
        end)

        clickArea.MouseEnter:Connect(function()
            VT:Create(row, TweenInfo.new(0.12), {
                BackgroundTransparency = math.max((themeOf(self).SurfaceTrans or 0.25) - 0.1, 0),
            }):Play()
        end)
        clickArea.MouseLeave:Connect(function()
            VT:Create(row, TweenInfo.new(0.12), {
                BackgroundTransparency = themeOf(self).SurfaceTrans or 0.25,
            }):Play()
        end)
    end

    -- Theme
    registerTheme(self, function(t)
        for opt, ref in pairs(refs) do
            ref.row.BackgroundColor3 = t.Surface
            for _, c in ipairs(ref.row:GetChildren()) do
                if c:IsA("TextLabel") then c.TextColor3 = t.TextPrimary end
                if c:IsA("UIStroke") then c.Color = t.Border end
            end
            if ref.barGrad then
                ref.barGrad.Color = ColorSequence.new(t.Accent, VP and VP.AccentPink or t.Accent)
            end
        end
    end)

    self:_track(container)

    local obj = {
        Instance = container,
        Flag = config.Flag,
        Set = function(_, data)
            if type(data) ~= "table" then return end
            for opt, ref in pairs(refs) do
                ref.setState(data[opt] == true, true)
            end
        end,
        Get = function() return selected end,
    }
    if config.Flag then
        local w = getWin(self)
        if w then
            w._elementsByFlag[config.Flag] = obj
            w._configData[config.Flag] = selected
        end
    end

    return obj
end

-- ============================================================
-- CreateCardGrid
-- ============================================================
--[[
    Grid of selectable image cards. Each item:
        { Name = "Foo", Icon = "rbxassetid://123" }

    Options:
        Columns  = 3       -- grid columns
        CardHeight = 115
        Callback = function(selectedTable) end
        OnCardCreated = function(name, label) end
]]

function LucidUI.Section:CreateCardGrid(config)
    config = config or {}
    local theme = themeOf(self)
    local items  = config.Items or {}
    local cols   = config.Columns or 3
    local gap    = 8
    local cardH  = config.CardHeight or 115
    local rowsN  = math.ceil(#items / math.max(cols, 1))
    local totalH = rowsN * (cardH + gap) + gap

    local container = Create("Frame", {
        Name = "VoidCardGrid",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, totalH),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })

    local grid = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = container,
    })

    local layout = Create("UIGridLayout", {
        CellSize = UDim2.new(1/cols, -(gap * (cols + 1) / cols), 0, cardH),
        CellPadding = UDim2.new(0, gap, 0, gap),
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirection = Enum.FillDirection.Horizontal,
        Parent = grid,
    })
    Create("UIPadding", {
        PaddingTop    = UDim.new(0, gap),
        PaddingBottom = UDim.new(0, gap),
        PaddingLeft   = UDim.new(0, gap),
        PaddingRight  = UDim.new(0, gap),
        Parent = grid,
    })

    local selected = {}
    local cardRefs = {}

    for i, item in ipairs(items) do
        local card = Create("Frame", {
            Name = item.Name or ("card" .. i),
            BackgroundColor3 = VP and VP.BgMid or theme.Surface,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            LayoutOrder = i,
            ZIndex = 3,
            Parent = grid,
        })
        Corner(10, card)

        VS.Gradient(card, {
            color1 = VP and VP.BgMid or theme.Surface,
            color2 = VP and VP.BgLight or theme.SurfaceHover,
            rotation = 90,
        })

        local stroke = Stroke(VP and VP.BorderDim or theme.Border, 1, 0.3, card)
        local bar, barGrad = VS.AccentBar(card, { height = 0.5, y = 0.25 })

        -- Icon
        local img = Create("ImageLabel", {
            Size = UDim2.new(0.72, 0, 0, cardH * 0.58),
            Position = UDim2.new(0.14, 0, 0, 8),
            BackgroundTransparency = 1,
            Image = item.Icon or "",
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 4,
            Parent = card,
        })

        -- Name
        local nameLbl = Create("TextLabel", {
            Text = item.Name or "",
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = theme.TextMuted,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.new(0, 4, 1, -22),
            Size = UDim2.new(1, -8, 0, 18),
            ZIndex = 4,
            Parent = card,
        })

        -- Checkmark badge
        local check = Create("Frame", {
            Size = UDim2.fromOffset(20, 20),
            Position = UDim2.new(1, -26, 0, 6),
            BackgroundColor3 = theme.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 5,
            Parent = card,
        })
        Corner(10, check)

        local checkLbl = Create("TextLabel", {
            Text = "✓",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            TextTransparency = 1,
            ZIndex = 6,
            Parent = check,
        })

        local clickArea = Create("TextButton", {
            Text = "",
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 7,
            Parent = card,
        })

        local isSelected = false
        local function applyVisual(v, silent)
            isSelected = v
            local t = themeOf(self)
            if v then
                selected[item.Name] = true
                stroke.Color = t.Accent
                stroke.Thickness = 2
                check.BackgroundTransparency = 0
                checkLbl.TextTransparency = 0
                nameLbl.TextColor3 = t.TextPrimary
                VT:Create(card, TweenInfo.new(0.15), {
                    BackgroundColor3 = VP and VP.BgLighter or t.SurfaceHover,
                }):Play()
            else
                selected[item.Name] = nil
                stroke.Color = VP and VP.BorderDim or t.Border
                stroke.Thickness = 1
                check.BackgroundTransparency = 1
                checkLbl.TextTransparency = 1
                nameLbl.TextColor3 = t.TextMuted
                VT:Create(card, TweenInfo.new(0.15), {
                    BackgroundColor3 = VP and VP.BgMid or t.Surface,
                }):Play()
            end
            if not silent and config.Callback then
                Compat.safeCallback(config.Callback, selected)
            end
            if config.Flag and getWin(self) then
                getWin(self)._configData[config.Flag] = selected
            end
        end

        cardRefs[item.Name] = { applyVisual = applyVisual, getState = function() return isSelected end }

        clickArea.MouseEnter:Connect(function()
            if not isSelected then
                VT:Create(card, TweenInfo.new(0.12), {
                    BackgroundColor3 = VP and VP.BgLight or themeOf(self).SurfaceHover,
                }):Play()
            end
        end)
        clickArea.MouseLeave:Connect(function()
            if not isSelected then
                VT:Create(card, TweenInfo.new(0.12), {
                    BackgroundColor3 = VP and VP.BgMid or themeOf(self).Surface,
                }):Play()
            end
        end)
        BindTap(clickArea, function()
            PlayUISound("click")
            applyVisual(not isSelected)
            VS.ShinePass(card, { duration = 0.4 })
        end)

        if config.OnCardCreated then
            task.spawn(function()
                pcall(config.OnCardCreated, item.Name, nameLbl)
            end)
        end
    end

    -- Theme
    registerTheme(self, function(t)
        for name, ref in pairs(cardRefs) do
            -- handled by applyVisual, but re-apply visual to refresh colors
            ref.applyVisual(ref.getState(), true)
        end
    end)

    self:_track(container)

    local obj = {
        Instance = container,
        Flag = config.Flag,
        Set = function(_, data)
            if type(data) ~= "table" then return end
            for name, ref in pairs(cardRefs) do
                ref.applyVisual(data[name] == true, true)
            end
        end,
        Get = function() return selected end,
        Clear = function(_)
            for _, ref in pairs(cardRefs) do
                ref.applyVisual(false, true)
            end
        end,
    }
    if config.Flag then
        local w = getWin(self)
        if w then
            w._elementsByFlag[config.Flag] = obj
            w._configData[config.Flag] = selected
        end
    end

    return obj
end

-- ============================================================
-- CreateFilteredCardGrid
-- ============================================================
--[[
    CardGrid with a group dropdown at the top. Options:
        Groups = {
            { Label = "Weapons", Items = { { Name = "AK-47", Icon = "..." }, ... } },
            { Label = "Tools",   Items = { ... } },
        }
        Columns  = 4
        CardHeight = 100
        Callback = function(selectedTable) end
]]

function LucidUI.Section:CreateFilteredCardGrid(config)
    config = config or {}
    local theme = themeOf(self)
    local groups = config.Groups or {}
    local cols = config.Columns or 4
    local cardH = config.CardHeight or 100
    local gap = 8

    -- Group index
    local groupIndex = {}
    local groupLabels = {}
    for _, g in ipairs(groups) do
        groupIndex[g.Label] = g
        table.insert(groupLabels, g.Label)
    end
    local currentGroup = groupLabels[1] or ""

    -- Group max height for grid sizing
    local function rowsFor(items) return math.ceil(#items / cols) end
    local function gridHeightFor(items)
        local r = rowsFor(items)
        return r * (cardH + gap) + gap
    end

    local maxGridH = 0
    for _, g in ipairs(groups) do
        maxGridH = math.max(maxGridH, gridHeightFor(g.Items or {}))
    end

    -- Container
    local container = Create("Frame", {
        Name = "VoidFilteredCardGrid",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 34 + maxGridH + 8),
        LayoutOrder = self:_nextOrder(),
        ZIndex = 2,
    })

    -- Group dropdown row
    local dropRow = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = theme.SurfaceTrans or 0.25,
        ZIndex = 3,
        Parent = container,
    })
    Corner(8, dropRow)
    local dropStroke = Stroke(theme.Border, 1, (theme.BorderTrans or 0.75) + 0.05, dropRow)
    local dropBar, dropBarGrad = VS.AccentBar(dropRow, { height = 0.6, y = 0.2 })

    Create("TextLabel", {
        Text = "Group",
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextColor3 = theme.TextMuted,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(0, 60, 1, 0),
        ZIndex = 4,
        Parent = dropRow,
    })

    local selLabel = Create("TextLabel", {
        Text = currentGroup,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(0, 76, 0, 0),
        Size = UDim2.new(1, -110, 1, 0),
        ZIndex = 4,
        Parent = dropRow,
    })

    local arrow = Create("TextLabel", {
        Text = "▾",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = theme.Accent,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Center,
        Position = UDim2.new(1, -22, 0, 0),
        Size = UDim2.fromOffset(16, 34),
        ZIndex = 4,
        Parent = dropRow,
    })

    -- Dropdown list (parented to Main so it renders over the grid)
    local win = getWin(self)
    local dropH = math.min(#groupLabels * 28 + 6, 240)
    local dropList = Create("Frame", {
        Size = UDim2.new(0, 200, 0, dropH),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = VP and VP.BgMid or theme.Surface,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 60,
        Parent = win and win.Main or container,
    })
    Corner(8, dropList)
    Stroke(VP and VP.Accent or theme.Accent, 1, 0.35, dropList)

    local dropScroll = Create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = theme.TextMuted,
        ScrollBarImageTransparency = 0.5,
        CanvasSize = UDim2.new(0, 0, 0, #groupLabels * 28 + 6),
        AutomaticCanvasSize = Enum.AutomaticSize.None,
        ZIndex = 61,
        Parent = dropList,
    })
    local dLayout = Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = dropScroll,
    })

    local expanded = false
    local function positionDropdown()
        if not win or not win.Main then return end
        local sfPos  = win.Main.AbsolutePosition
        local pos    = dropRow.AbsolutePosition
        local size   = dropRow.AbsoluteSize
        dropList.Size = UDim2.new(0, size.X, 0, dropH)
        dropList.Position = UDim2.new(0,
            pos.X - sfPos.X,
            0,
            pos.Y - sfPos.Y + size.Y + 2
        )
    end

    local function closeDropdown()
        expanded = false
        dropList.Visible = false
        arrow.Rotation = 0
    end

    for i, label in ipairs(groupLabels) do
        local opt = Create("TextButton", {
            Text = label,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = theme.TextPrimary,
            BackgroundColor3 = VP and VP.BgLight or theme.Surface,
            BackgroundTransparency = 0.3,
            AutoButtonColor = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, 26),
            Position = UDim2.fromOffset(0, 3 + (i - 1) * 28),
            LayoutOrder = i,
            ZIndex = 62,
            Parent = dropScroll,
        })
        Corner(6, opt)
        Create("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = opt })

        opt.MouseEnter:Connect(function()
            opt.BackgroundColor3 = themeOf(self).Accent
        end)
        opt.MouseLeave:Connect(function()
            opt.BackgroundColor3 = VP and VP.BgLight or themeOf(self).Surface
        end)
        BindTap(opt, function()
            currentGroup = label
            selLabel.Text = label
            closeDropdown()
            rebuildGrid(label)
            PlayUISound("click")
        end)
    end

    -- Grid container
    local gridContainer = Create("Frame", {
        Size = UDim2.new(1, 0, 0, maxGridH),
        Position = UDim2.fromOffset(0, 42),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = container,
    })

    -- The actual grid is rebuilt each group switch
    local function rebuildGrid(groupLabel)
        for _, c in ipairs(gridContainer:GetChildren()) do c:Destroy() end

        local grp = groupIndex[groupLabel]
        if not grp or not grp.Items then return end
        local items = grp.Items
        local rowsN = rowsFor(items)
        gridContainer.Size = UDim2.new(1, 0, 0, gridHeightFor(items))
        container.Size = UDim2.new(1, 0, 0, 34 + gridHeightFor(items) + 8)

        local grid = Create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Parent = gridContainer,
        })
        Create("UIGridLayout", {
            CellSize = UDim2.new(1/cols, -(gap * (cols + 1) / cols), 0, cardH),
            CellPadding = UDim2.new(0, gap, 0, gap),
            SortOrder = Enum.SortOrder.LayoutOrder,
            FillDirection = Enum.FillDirection.Horizontal,
            Parent = grid,
        })
        Create("UIPadding", {
            PaddingTop    = UDim.new(0, gap),
            PaddingBottom = UDim.new(0, gap),
            PaddingLeft   = UDim.new(0, gap),
            PaddingRight  = UDim.new(0, gap),
            Parent = grid,
        })

        for i, item in ipairs(items) do
            local card = Create("Frame", {
                Name = item.Name or ("card" .. i),
                BackgroundColor3 = VP and VP.BgMid or theme.Surface,
                BorderSizePixel = 0,
                LayoutOrder = i,
                ZIndex = 3,
                Parent = grid,
            })
            Corner(10, card)
            VS.Gradient(card, {
                color1 = VP and VP.BgMid or theme.Surface,
                color2 = VP and VP.BgLight or theme.SurfaceHover,
                rotation = 90,
            })
            local stroke = Stroke(VP and VP.BorderDim or theme.Border, 1, 0.3, card)
            VS.AccentBar(card, { height = 0.5, y = 0.25 })

            local img = Create("ImageLabel", {
                Size = UDim2.new(0.72, 0, 0, cardH * 0.58),
                Position = UDim2.new(0.14, 0, 0, 6),
                BackgroundTransparency = 1,
                Image = item.Icon or "",
                ScaleType = Enum.ScaleType.Fit,
                ZIndex = 4,
                Parent = card,
            })

            local nameLbl = Create("TextLabel", {
                Text = item.Name or "",
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                TextColor3 = theme.TextMuted,
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Position = UDim2.new(0, 4, 1, -20),
                Size = UDim2.new(1, -8, 0, 16),
                ZIndex = 4,
                Parent = card,
            })

            local check = Create("Frame", {
                Size = UDim2.fromOffset(18, 18),
                Position = UDim2.new(1, -24, 0, 6),
                BackgroundColor3 = theme.Accent,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 5,
                Parent = card,
            })
            Corner(9, check)
            local checkLbl = Create("TextLabel", {
                Text = "✓",
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                TextTransparency = 1,
                ZIndex = 6,
                Parent = check,
            })

            local isSelected = selected[item.Name] == true
            local function applyVisual(v, silent)
                isSelected = v
                local t = themeOf(self)
                if v then
                    selected[item.Name] = true
                    stroke.Color = t.Accent
                    stroke.Thickness = 2
                    check.BackgroundTransparency = 0
                    checkLbl.TextTransparency = 0
                    nameLbl.TextColor3 = t.TextPrimary
                else
                    selected[item.Name] = nil
                    stroke.Color = VP and VP.BorderDim or t.Border
                    stroke.Thickness = 1
                    check.BackgroundTransparency = 1
                    checkLbl.TextTransparency = 1
                    nameLbl.TextColor3 = t.TextMuted
                end
                if not silent and config.Callback then
                    Compat.safeCallback(config.Callback, selected)
                end
                if config.Flag and win then win._configData[config.Flag] = selected end
            end
            if isSelected then applyVisual(true, true) end

            local clickArea = Create("TextButton", {
                Text = "",
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                ZIndex = 7,
                Parent = card,
            })
            BindTap(clickArea, function()
                PlayUISound("click")
                applyVisual(not isSelected)
                VS.ShinePass(card, { duration = 0.4 })
            end)
        end
    end

    -- Toggle dropdown
    local dropClick = Create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 5,
        Parent = dropRow,
    })
    BindTap(dropClick, function()
        expanded = not expanded
        if expanded then
            positionDropdown()
            dropList.Visible = true
            arrow.Rotation = 180
        else
            closeDropdown()
        end
    end)

    -- Outside-click to close
    if win then
        table.insert(win._conns, UserInputService.InputBegan:Connect(function(input, processed)
            if not expanded then return end
            if processed then return end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local mp = UserInputService:GetMouseLocation()
            local dp = dropList.AbsolutePosition
            local ds = dropList.AbsoluteSize
            local inDrop = mp.X >= dp.X and mp.X <= dp.X + ds.X
                       and mp.Y >= dp.Y and mp.Y <= dp.Y + ds.Y
            local dr = dropRow.AbsolutePosition
            local dw = dropRow.AbsoluteSize
            local inRow = mp.X >= dr.X and mp.X <= dr.X + dw.X
                      and mp.Y >= dr.Y and mp.Y <= dr.Y + dw.Y
            if not inDrop and not inRow then closeDropdown() end
        end))
    end

    -- Theme registration
    registerTheme(self, function(t)
        dropRow.BackgroundColor3 = t.Surface
        dropStroke.Color = t.Border
        selLabel.TextColor3 = t.TextPrimary
        arrow.TextColor3 = t.Accent
        dropList.BackgroundColor3 = VP and VP.BgMid or t.Surface
        for _, c in ipairs(dropScroll:GetChildren()) do
            if c:IsA("TextButton") then
                c.TextColor3 = t.TextPrimary
            end
        end
        if dropBarGrad then
            dropBarGrad.Color = ColorSequence.new(t.Accent, VP and VP.AccentPink or t.Accent)
        end
    end)

    -- Initial render
    rebuildGrid(currentGroup)

    self:_track(container)

    local obj = {
        Instance = container,
        Flag = config.Flag,
        Set = function(_, data)
            if type(data) ~= "table" then return end
            for k, v in pairs(data) do
                selected[k] = v or nil
            end
            rebuildGrid(currentGroup)
            if config.Callback then
                Compat.safeCallback(config.Callback, selected)
            end
        end,
        Get = function() return selected end,
        SelectAll = function(_, groupLabel)
            local grp = groupIndex[groupLabel or currentGroup]
            if not grp then return end
            for _, item in ipairs(grp.Items or {}) do
                selected[item.Name] = true
            end
            rebuildGrid(currentGroup)
        end,
        DeselectAll = function(_)
            selected = {}
            rebuildGrid(currentGroup)
        end,
    }
    if config.Flag and win then
        win._elementsByFlag[config.Flag] = obj
        win._configData[config.Flag] = selected
    end

    return obj
end

-- ============================================================
-- Cleanup hook
-- ============================================================
LucidUI:OnCleanup(function()
    print("[LucidUI] VoidComponents cleaned up")
end)

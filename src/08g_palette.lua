--[[
    Command Palette — search every element across every tab.

    Desktop: Ctrl+K opens the palette anywhere.
    Mobile:  Tap the search icon in the window header.

    Type to filter. Click or press Enter to jump to the element —
    the window switches to its tab, scrolls to it, and flashes a
    brief highlight.

    Cleanup: keyboard listener and any open palette are torn down
    on re-execution.
]]

-- ============================================================
-- Registry
-- Every element created via Section:_track gets registered here.
-- ============================================================
local Registry = {}

local function extractName(frame)
    if not frame then return "" end
    -- First TextLabel with non-empty text is usually the name
    for _, d in ipairs(frame:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text and d.Text ~= "" then
            return d.Text
        end
    end
    -- Fallback: TextButton text
    for _, d in ipairs(frame:GetDescendants()) do
        if d:IsA("TextButton") and d.Text and d.Text ~= "" then
            return d.Text
        end
    end
    return ""
end

local function registerElement(section, frame, win)
    if not frame or not frame.Parent then return end
    local name = extractName(frame)
    if name == "" then return end
    table.insert(Registry, {
        frame   = frame,
        name    = name,
        section = section.Name or "",
        tab     = section.Tab and section.Tab.Name or "",
        tabObj  = section.Tab,
        win     = win or (section.Tab and section.Tab.Window),
    })
end

-- Hook Section._track
local _origTrack = LucidUI.Section._track
function LucidUI.Section:_track(frame)
    local result = _origTrack(self, frame)
    pcall(registerElement, self, result)
    return result
end

-- ============================================================
-- Palette state
-- ============================================================
local Palette = {
    gui       = nil,
    isOpen    = false,
    results   = {},
    selected  = 0,
    resultRow = nil,
}

local MAX_RESULTS = 20

-- ============================================================
-- Search
-- ============================================================
local function matches(entry, query)
    local q = query:lower()
    if q == "" then return true end
    return entry.name:lower():find(q, 1, true) ~= nil
       or entry.section:lower():find(q, 1, true) ~= nil
       or entry.tab:lower():find(q, 1, true) ~= nil
end

local function runSearch(query)
    local out = {}
    for _, entry in ipairs(Registry) do
        if entry.frame and entry.frame.Parent and matches(entry, query) then
            table.insert(out, entry)
            if #out >= MAX_RESULTS then break end
        end
    end
    return out
end

-- ============================================================
-- Jump to element
-- ============================================================
local function highlightFrame(frame)
    local highlight = Instance.new("Frame")
    highlight.BackgroundTransparency = 1
    highlight.BorderSizePixel = 0
    highlight.Size = UDim2.fromScale(1, 1)
    highlight.ZIndex = 200
    highlight.Parent = frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = highlight

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(120, 200, 255)
    stroke.Thickness = 2
    stroke.Transparency = 0
    stroke.Parent = highlight

    task.spawn(function()
        TweenService:Create(stroke, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Transparency = 1 }):Play()
        task.wait(1.5)
        pcall(function() highlight:Destroy() end)
    end)
end

local function jumpTo(entry)
    if not entry.frame or not entry.frame.Parent then return end
    local win = entry.win
    if not win then return end

    -- Switch tab if needed
    if entry.tabObj and win.ActiveTab ~= entry.tabObj then
        win:SelectTab(entry.tabObj)
    end

    -- Wait a frame for tab layout
    task.wait(0.05)

    local page = entry.tabObj and entry.tabObj.Page
    if page then
        -- Compute scroll offset by walking siblings
        local offset = 0
        for _, c in ipairs(page:GetChildren()) do
            if c == entry.frame or c:IsAncestorOf(entry.frame) then break end
            if c:IsA("GuiObject") then
                offset = offset + c.AbsoluteSize.Y + 10
            end
        end
        local target = math.max(0, offset - 20)
        TweenService:Create(page, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            { CanvasPosition = Vector2.new(0, target) }):Play()
    end

    highlightFrame(entry.frame)
end

-- ============================================================
-- Palette UI
-- ============================================================
local function buildPalette(gui)
    local screenW = gui.AbsoluteSize.X
    local screenH = gui.AbsoluteSize.Y
    local isMobile = screenW < 600

    local panelW = isMobile and math.min(screenW - 24, 460) or 500
    local panelH = isMobile and math.min(screenH - 100, 420) or 420

    -- Backdrop
    local backdrop = Create("TextButton", {
        Name = "Backdrop",
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = gui,
    })

    -- Panel
    local panel = Create("Frame", {
        Name = "Panel",
        Size = UDim2.fromOffset(panelW, panelH),
        Position = UDim2.new(0.5, 0, 0, -panelH),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Color3.fromRGB(22, 22, 28),
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 2,
        Parent = gui,
    })
    Corner(14, panel)
    local panelStroke = Stroke(Color3.fromRGB(80, 80, 100), 1, 0.4, panel)

    -- Search bar
    local searchBar = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundTransparency = 1,
        ZIndex = 3,
        Parent = panel,
    })

    local iconHolder = Create("Frame", {
        Size = UDim2.fromOffset(18, 18),
        Position = UDim2.fromOffset(20, 17),
        BackgroundTransparency = 1,
        ZIndex = 4,
        Parent = searchBar,
    })
    if LucidUI.IconBuilders and LucidUI.IconBuilders.search then
        pcall(LucidUI.IconBuilders.search, iconHolder, 18, Color3.fromRGB(150, 150, 170))
    end

    local input = Create("TextBox", {
        Text = "",
        PlaceholderText = "Search elements…",
        PlaceholderColor3 = Color3.fromRGB(130, 130, 150),
        Font = Enum.Font.Gotham,
        TextSize = 15,
        TextColor3 = Color3.fromRGB(240, 240, 250),
        BackgroundTransparency = 1,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(50, 0),
        Size = UDim2.new(1, -90, 1, 0),
        ZIndex = 4,
        Parent = searchBar,
    })

    local closeBtn = Create("TextButton", {
        Text = "×",
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        TextColor3 = Color3.fromRGB(150, 150, 170),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Size = UDim2.fromOffset(40, 52),
        Position = UDim2.new(1, -40, 0, 0),
        ZIndex = 4,
        Parent = searchBar,
    })
    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(150, 150, 170) }):Play()
    end)

    -- Divider
    Create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.fromOffset(0, 52),
        BackgroundColor3 = Color3.fromRGB(60, 60, 75),
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = panel,
    })

    -- Results list
    local results = Create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -52),
        Position = UDim2.fromOffset(0, 52),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120),
        ScrollBarImageTransparency = 0.4,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
        Parent = panel,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = results,
    })
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
        Parent = results,
    })

    return {
        backdrop = backdrop,
        panel = panel,
        panelStroke = panelStroke,
        input = input,
        results = results,
        closeBtn = closeBtn,
    }
end

local function clearResults(ui)
    for _, c in ipairs(ui.results:GetChildren()) do
        if c:IsA("GuiObject") and not c:IsA("UIListLayout") then
            c:Destroy()
        end
    end
end

local function renderResults(ui, list)
    clearResults(ui)
    Palette.results = list

    if #list == 0 then
        Create("TextLabel", {
            Text = "No matching elements",
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Color3.fromRGB(130, 130, 150),
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 40),
            LayoutOrder = 1,
            ZIndex = 4,
            Parent = ui.results,
        })
        return
    end

    for i, entry in ipairs(list) do
        local row = Create("TextButton", {
            Text = "",
            AutoButtonColor = false,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 40),
            LayoutOrder = i,
            ZIndex = 4,
            Parent = ui.results,
        })
        Corner(8, row)

        local nameLabel = Create("TextLabel", {
            Text = entry.name,
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextColor3 = Color3.fromRGB(240, 240, 250),
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -140, 1, 0),
            ZIndex = 5,
            Parent = row,
        })

        local pathLabel = Create("TextLabel", {
            Text = entry.tab .. " › " .. entry.section,
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextColor3 = Color3.fromRGB(130, 130, 150),
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.new(1, -130, 0, 0),
            Size = UDim2.fromOffset(120, 40),
            ZIndex = 5,
            Parent = row,
        })

        row.MouseEnter:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.12),
                { BackgroundTransparency = 0.85, BackgroundColor3 = Color3.fromRGB(120, 180, 255) }):Play()
        end)
        row.MouseLeave:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.12),
                { BackgroundTransparency = 1 }):Play()
        end)

        row.MouseButton1Click:Connect(function()
            LucidUI:ClosePalette()
            task.spawn(jumpTo, entry)
        end)
    end
end

-- ============================================================
-- Palette gui creation
-- ============================================================
local function ensurePaletteGui()
    if Palette.gui and Palette.gui.Parent then return Palette.gui end

    local gui = Create("ScreenGui", {
        Name = "LucidUI_Palette",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 800,
        Enabled = false,
        Parent = PlayerGui,
    })
    Palette.gui = gui

    local ui = buildPalette(gui)
    Palette.ui = ui

    -- Search handler
    ui.input:GetPropertyChangedSignal("Text"):Connect(function()
        renderResults(ui, runSearch(ui.input.Text))
    end)

    -- Close handlers
    BindTap(ui.closeBtn, function() LucidUI:ClosePalette() end)
    BindTap(ui.backdrop, function() LucidUI:ClosePalette() end)

    -- Keyboard navigation
    ui.input.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local list = Palette.results
            if #list > 0 then
                LucidUI:ClosePalette()
                task.spawn(jumpTo, list[1])
            end
        end
    end)

    return gui
end

-- ============================================================
-- Open / close
-- ============================================================
function LucidUI:OpenPalette()
    if Palette.isOpen then return end
    Palette.isOpen = true

    local gui = ensurePaletteGui()
    gui.Enabled = true

    local ui = Palette.ui
    ui.panel.Position = UDim2.new(0.5, 0, 0, -ui.panel.AbsoluteSize.Y)
    ui.backdrop.BackgroundTransparency = 1

    TweenService:Create(ui.backdrop, TweenInfo.new(0.2), { BackgroundTransparency = 0.55 }):Play()
    TweenService:Create(ui.panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0, 60) }):Play()

    ui.input.Text = ""
    renderResults(ui, runSearch(""))

    task.defer(function()
        if ui.input and ui.input.Parent then
            pcall(function() ui.input:CaptureFocus() end)
        end
    end)
end

function LucidUI:ClosePalette()
    if not Palette.isOpen then return end
    Palette.isOpen = false

    local ui = Palette.ui
    if not ui then return end

    TweenService:Create(ui.backdrop, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
    TweenService:Create(ui.panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.new(0.5, 0, 0, -ui.panel.AbsoluteSize.Y) }):Play()

    if ui.input and ui.input.Parent then
        pcall(function() ui.input:ReleaseFocus() end)
    end

    task.delay(0.25, function()
        if Palette.gui then Palette.gui.Enabled = false end
    end)
end

function LucidUI:TogglePalette()
    if Palette.isOpen then self:ClosePalette() else self:OpenPalette() end
end

-- ============================================================
-- Desktop keyboard shortcut: Ctrl+K and Ctrl+P
-- ============================================================
local keyConn = UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    if input.KeyCode == Enum.KeyCode.K
       and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        LucidUI:TogglePalette()
    elseif input.KeyCode == Enum.KeyCode.P
       and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        LucidUI:TogglePalette()
    elseif input.KeyCode == Enum.KeyCode.Escape and Palette.isOpen then
        LucidUI:ClosePalette()
    end
end)

-- ============================================================
-- Header search icon
-- ============================================================
local _origCreateWindow = LucidUI.CreateWindow
function LucidUI:CreateWindow(config)
    local W = _origCreateWindow(self, config)

    -- Place the icon to the left of the gear
    local searchBtn = Create("TextButton", {
        Name = "PaletteButton",
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(36, 36),
        Position = UDim2.new(1, -80, 0.5, -18),
        ZIndex = 3,
        Parent = W.Header,
    })

    local iconHolder = Create("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Parent = searchBtn,
    })

    local iconStroke
    if LucidUI.IconBuilders and LucidUI.IconBuilders.search then
        local ok, _, strokes = pcall(LucidUI.IconBuilders.search, iconHolder, 16, W.Theme.TextSecondary)
        if ok and strokes then iconStroke = strokes end
    end

    BindTap(searchBtn, function() self:OpenPalette() end)

    searchBtn.MouseEnter:Connect(function()
        pcall(function()
            if iconStroke then
                for _, s in ipairs(iconStroke) do
                    TweenService:Create(s, TweenInfo.new(0.15), { Color = W.Theme.Accent }):Play()
                end
            end
        end)
    end)
    searchBtn.MouseLeave:Connect(function()
        pcall(function()
            if iconStroke then
                for _, s in ipairs(iconStroke) do
                    TweenService:Create(s, TweenInfo.new(0.15), { Color = W.Theme.TextSecondary }):Play()
                end
            end
        end)
    end)

    -- Recolor on theme change
    W:_registerTheme(function(t)
        if iconStroke then
            for _, s in ipairs(iconStroke) do
                s.Color = t.TextSecondary
            end
        end
    end)

    return W
end

-- ============================================================
-- Cleanup
-- ============================================================
LucidUI:OnCleanup(function()
    if keyConn then pcall(function() keyConn:Disconnect() end) end
    if Palette.gui and Palette.gui.Parent then
        pcall(function() Palette.gui:Destroy() end)
    end
    Palette.gui = nil
    Palette.ui = nil
    Palette.isOpen = false
    Registry = {}
    print("[LucidUI] Palette cleaned up")
end)

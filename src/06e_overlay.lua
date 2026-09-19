-- ============================================================
-- Module: 06e_overlay.lua
-- ============================================================
--[[
    Overlay — a draggable on-screen HUD for real-time info.

    Unlike the Window, the Overlay is designed to sit in a corner
    and update constantly (FPS, player count, target status, etc.)
    without hogging the center of the screen.

    Features:
      • Drag anywhere (mouse / touch)
      • Auto-sizes to content
      • Optional title bar with collapse toggle
      • Optional accent bar
      • Rows: text, image, imagebutton, progressbar, divider
      • Theme-aware (auto-retints on theme change)
      • Position persists across theme changes
      • Snap-to-edge optional
      • Hidden when GUI disabled
      • Cleaned up on re-execute

    Standalone — no window binding required. Pass an optional
    `Window = W` for theme syncing if you want it to follow
    your hub's theme changes.

    NO tracking. NO network. NO clipboard.
]]

LucidUI.Overlay = {}
LucidUI.Overlay.__index = LucidUI.Overlay

-- ============================================================
-- Helpers
-- ============================================================
local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function palette(theme)
    local VP = LucidUI.VoidPalette
    return {
        bg       = (VP and VP.BgMid)     or theme.Background or Color3.fromRGB(20, 20, 26),
        bgDeep   = (VP and VP.BgDeep)    or theme.Background or Color3.fromRGB(10, 10, 14),
        surface  = (VP and VP.BgLight)   or theme.Surface    or Color3.fromRGB(30, 28, 45),
        border   = (VP and VP.BorderDim) or theme.Border     or Color3.fromRGB(50, 50, 70),
        accent   = theme.Accent          or Color3.fromRGB(130, 80, 255),
        accent2  = (VP and VP.AccentPink) or theme.Accent,
        textHigh = theme.TextPrimary     or Color3.fromRGB(240, 240, 245),
        textMid  = theme.TextSecondary   or Color3.fromRGB(180, 180, 200),
        textDim  = theme.TextMuted       or Color3.fromRGB(130, 130, 150),
    }
end

-- ============================================================
-- Row builders
-- ============================================================
local ROW_BUILDERS = {}

-- Text row: { Type = "text", Text = "...", Id = "fps", Color = optional, Align = "left"|"right"|"center" }
ROW_BUILDERS.text = function(container, cfg, P, obj)
    local lbl = Create("TextLabel", {
        Text = cfg.Text or "",
        Font = cfg.Bold and Enum.Font.GothamBold or Enum.Font.GothamMedium,
        TextSize = cfg.TextSize or 12,
        TextColor3 = cfg.Color or P.textHigh,
        BackgroundTransparency = 1,
        TextXAlignment = cfg.Align == "right" and Enum.TextXAlignment.Right
                        or cfg.Align == "center" and Enum.TextXAlignment.Center
                        or Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Size = UDim2.new(1, 0, 0, 18),
        ZIndex = 4,
        Parent = container,
    })

    if cfg.Id then
        obj._rows[cfg.Id] = {
            kind = "text",
            instance = lbl,
            setText = function(_, v) lbl.Text = tostring(v) end,
            setColor = function(_, c) lbl.TextColor3 = c end,
            getText = function() return lbl.Text end,
        }
    end

    return function(t)
        if not cfg.Color then lbl.TextColor3 = t.TextPrimary end
    end
end

-- Image row: { Type = "image", Icon = "rbxassetid://...", Height = 40, Id = "logo" }
ROW_BUILDERS.image = function(container, cfg, P, obj)
    local h = cfg.Height or 40
    local img = Create("ImageLabel", {
        Size = UDim2.new(1, 0, 0, h),
        BackgroundTransparency = 1,
        Image = cfg.Icon or "",
        ScaleType = cfg.ScaleType or Enum.ScaleType.Fit,
        ImageColor3 = cfg.Tint or Color3.fromRGB(255, 255, 255),
        ZIndex = 4,
        Parent = container,
    })

    if cfg.Id then
        obj._rows[cfg.Id] = {
            kind = "image",
            instance = img,
            setImage = function(_, id) img.Image = id end,
        }
    end

    return function(t) end
end

-- Image button row: { Type = "imagebutton", Icon = "...", Height = 40, OnClick = fn, Label = "optional" }
ROW_BUILDERS.imagebutton = function(container, cfg, P, obj)
    local h = (cfg.Height or 40) + (cfg.Label and 16 or 0)

    local btn = Create("TextButton", {
        Name = "OverlayImageButton",
        Text = "",
        BackgroundColor3 = P.surface,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, cfg.Height or 40),
        ZIndex = 4,
        Parent = container,
    })
    Corner(8, btn)

    local stroke = Stroke(P.border, 1, 0.35, btn)

    local img = Create("ImageLabel", {
        Size = UDim2.new(0.7, 0, 0.8, 0),
        Position = UDim2.new(0.15, 0, 0.1, 0),
        BackgroundTransparency = 1,
        Image = cfg.Icon or "",
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 5,
        Parent = btn,
    })

    if cfg.Label then
        Create("TextLabel", {
            Text = cfg.Label,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = P.textDim,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Center,
            Position = UDim2.new(0, 0, 1, 2),
            Size = UDim2.new(1, 0, 0, 14),
            ZIndex = 5,
            Parent = container,
        })
    end

    btn.MouseEnter:Connect(function()
        Tween(btn, 0.12, { BackgroundColor3 = P.accent, BackgroundTransparency = 0.3 }):Play()
        Tween(stroke, 0.12, { Transparency = 0 }):Play()
    end)
    btn.MouseLeave:Connect(function()
        Tween(btn, 0.12, { BackgroundColor3 = P.surface, BackgroundTransparency = 0.15 }):Play()
        Tween(stroke, 0.12, { Transparency = 0.35 }):Play()
    end)

    BindTap(btn, function()
        PlayUISound("click")
        if cfg.OnClick then Compat.safeCallback(cfg.OnClick) end
        if LucidUI.VoidStyle and LucidUI.VoidStyle.ShinePass then
            LucidUI.VoidStyle.ShinePass(btn, { duration = 0.35 })
        end
    end)

    if cfg.Id then
        obj._rows[cfg.Id] = {
            kind = "imagebutton",
            instance = btn,
            setImage = function(_, id) img.Image = id end,
        }
    end

    return function(t)
        btn.BackgroundColor3 = (LucidUI.VoidPalette and LucidUI.VoidPalette.BgLight) or t.Surface
        stroke.Color = (LucidUI.VoidPalette and LucidUI.VoidPalette.BorderDim) or t.Border
        if not cfg.Label then return end
        -- Label retint handled below
    end
end

-- Progress bar row: { Type = "progress", Id = "hp", Value = 0..1, Height = 8, ShowLabel = true, Label = "HP" }
ROW_BUILDERS.progress = function(container, cfg, P, obj)
    local showLabel = cfg.ShowLabel ~= false
    local totalH = (showLabel and 20 or 0) + (cfg.Height or 8)
    local wrapper = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, totalH),
        ZIndex = 4,
        Parent = container,
    })

    local lbl, valueLbl
    if showLabel then
        lbl = Create("TextLabel", {
            Text = cfg.Label or "",
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            TextColor3 = P.textMid,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, -60, 0, 16),
            ZIndex = 5,
            Parent = wrapper,
        })
        valueLbl = Create("TextLabel", {
            Text = "",
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = P.accent,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Right,
            Size = UDim2.new(1, 0, 0, 16),
            ZIndex = 5,
            Parent = wrapper,
        })
    end

    local track = Create("Frame", {
        Size = UDim2.new(1, 0, 0, cfg.Height or 8),
        Position = UDim2.new(0, 0, 0, showLabel and 20 or 0),
        BackgroundColor3 = (LucidUI.VoidPalette and LucidUI.VoidPalette.BgDeep) or P.bgDeep,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = wrapper,
    })
    Corner((cfg.Height or 8) / 2, track)

    local fill = Create("Frame", {
        Size = UDim2.new(math.clamp(cfg.Value or 0, 0, 1), 0, 1, 0),
        BackgroundColor3 = cfg.Color or P.accent,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = track,
    })
    Corner((cfg.Height or 8) / 2, fill)

    local grad = Create("UIGradient", {
        Color = ColorSequence.new(P.accent, P.accent2),
        Rotation = 0,
        Parent = fill,
    })

    if cfg.Id then
        obj._rows[cfg.Id] = {
            kind = "progress",
            instance = wrapper,
            setValue = function(_, v)
                v = math.clamp(v or 0, 0, 1)
                Tween(fill, 0.25, { Size = UDim2.new(v, 0, 1, 0) }):Play()
                if valueLbl then
                    valueLbl.Text = tostring(math.floor(v * 100)) .. "%"
                end
            end,
            setLabel = function(_, text)
                if lbl then lbl.Text = tostring(text) end
            end,
            setColor = function(_, c)
                fill.BackgroundColor3 = c
            end,
        }
    end

    return function(t)
        if not cfg.Color then
            fill.BackgroundColor3 = t.Accent
        end
        track.BackgroundColor3 = (LucidUI.VoidPalette and LucidUI.VoidPalette.BgDeep) or t.Background
        if lbl then lbl.TextColor3 = t.TextSecondary end
        if valueLbl then valueLbl.TextColor3 = t.Accent end
        grad.Color = ColorSequence.new(
            t.Accent,
            (LucidUI.VoidPalette and LucidUI.VoidPalette.AccentPink) or t.Accent
        )
    end
end

-- Divider row: { Type = "divider" }
ROW_BUILDERS.divider = function(container, cfg, P, obj)
    local line = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = P.border,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = container,
    })
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = line,
    })

    return function(t)
        line.BackgroundColor3 = (LucidUI.VoidPalette and LucidUI.VoidPalette.BorderDim) or t.Border
    end
end

-- Spacer row: { Type = "spacer", Height = 8 }
ROW_BUILDERS.spacer = function(container, cfg, P, obj)
    Create("Frame", {
        Size = UDim2.new(1, 0, 0, cfg.Height or 8),
        BackgroundTransparency = 1,
        ZIndex = 4,
        Parent = container,
    })
    return function(t) end
end

-- ============================================================
-- Public: CreateOverlay
-- ============================================================
--[[
    cfg = {
        Title       = "HUD",
        TitleIcon   = "rbxassetid://...",
        Collapsible = true,
        Position    = UDim2.new(0, 16, 0, 120),
        Width       = 180,
        Padding     = 10,
        Rows        = { ...see above... },
        SnapToEdge  = false,
        Draggable   = true,
        AccentBar   = true,
        Window      = nil,  -- optional; syncs theme changes
        Visible     = true,
    }
]]

function LucidUI:CreateOverlay(cfg)
    cfg = cfg or {}

    local theme = (cfg.Window and cfg.Window.Theme)
              or LucidUI._lastTheme
              or LucidUI.Themes.Default
    local P = palette(theme)

    -- Root GUI (own ScreenGui so it survives window hide)
    local gui = Create("ScreenGui", {
        Name = "LucidUI_Overlay_" .. tostring(math.floor(tick() * 1000) % 100000),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = cfg.DisplayOrder or 300,
        Enabled = cfg.Visible ~= false,
        Parent = PlayerGui,
    })

    local obj = setmetatable({}, LucidUI.Overlay)
    obj.Gui     = gui
    obj.Theme   = theme
    obj._rows   = {}
    obj._conns  = {}
    obj._cfg    = cfg
    obj._themeFns = {}

    -- Container frame
    local container = Create("Frame", {
        Name = "Overlay",
        Size = UDim2.fromOffset(cfg.Width or 180, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = cfg.Position or UDim2.new(0, 16, 0, 120),
        BackgroundColor3 = P.bg,
        BackgroundTransparency = cfg.BackgroundTransparency or 0.15,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = gui,
    })
    Corner(cfg.CornerRadius or 12, container)

    local containerStroke = Stroke(P.border, 1, 0.35, container)

    -- Subtle background gradient
    local bgGrad = Create("UIGradient", {
        Color = ColorSequence.new(P.bg, P.bgDeep),
        Rotation = 90,
        Parent = container,
    })

    -- Accent bar (VoidStyle's signature)
    local accentBar, accentGrad
    if cfg.AccentBar ~= false and LucidUI.VoidStyle then
        accentBar, accentGrad = LucidUI.VoidStyle.AccentBar(container, { height = 0.35, y = 0.325 })
    end

    -- Content list
    local list = Create("Frame", {
        Name = "List",
        Size = UDim2.new(1, -(cfg.Padding or 10) * 2, 0, 0),
        Position = UDim2.fromOffset(cfg.Padding or 10, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
        Parent = container,
    })

    local layout = Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = list,
    })

    -- Top / bottom padding
    Create("UIPadding", {
        PaddingTop    = UDim.new(0, cfg.Padding or 10),
        PaddingBottom = UDim.new(0, cfg.Padding or 10),
        Parent = list,
    })

    obj.Container = container
    obj.Content   = list
    obj.Layout    = layout

    -- ── Title bar (optional) ──────────────────────────────
    local titleBar, titleLbl, collapseBtn, titleIcon
    if cfg.Title and cfg.Title ~= "" then
        titleBar = Create("TextButton", {
            Text = "",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 24),
            LayoutOrder = -1000,
            ZIndex = 4,
            Parent = list,
        })

        -- Icon if provided
        local iconOffset = 0
        if cfg.TitleIcon then
            titleIcon = Create("ImageLabel", {
                Size = UDim2.fromOffset(16, 16),
                Position = UDim2.fromOffset(0, 4),
                BackgroundTransparency = 1,
                Image = cfg.TitleIcon,
                ScaleType = Enum.ScaleType.Fit,
                ZIndex = 5,
                Parent = titleBar,
            })
            iconOffset = 22
        end

        titleLbl = Create("TextLabel", {
            Text = cfg.Title,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = P.textHigh,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(iconOffset, 0),
            Size = UDim2.new(1, -(iconOffset + (cfg.Collapsible and 20 or 0)), 1, 0),
            ZIndex = 5,
            Parent = titleBar,
        })

        if cfg.Collapsible then
            collapseBtn = Create("TextButton", {
                Text = "▾",
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                TextColor3 = P.textDim,
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Size = UDim2.fromOffset(20, 20),
                Position = UDim2.new(1, -20, 0, 2),
                ZIndex = 5,
                Parent = titleBar,
            })
        end
    end

    -- ── Build rows ────────────────────────────────────────
    local order = 1
    for _, rowCfg in ipairs(cfg.Rows or {}) do
        local builder = ROW_BUILDERS[rowCfg.Type or "text"]
        if builder then
            -- Create a row wrapper frame
            local rowWrap = Create("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = order,
                ZIndex = 3,
                Parent = list,
            })
            order = order + 1

            local themeFn = builder(rowWrap, rowCfg, P, obj)
            if themeFn then
                table.insert(obj._themeFns, themeFn)
            end
        end
    end

    -- ── Drag handling ─────────────────────────────────────
    if cfg.Draggable ~= false then
        local dragging, dragStart, startPos, dragInput
        local dragTarget = titleBar or container

        dragTarget.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
            dragging  = true
            dragStart = input.Position
            startPos  = container.Position
            dragInput = input
        end)

        table.insert(obj._conns, UserInputService.InputChanged:Connect(function(input)
            if not dragging or input ~= dragInput then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
                and input.UserInputType ~= Enum.UserInputType.Touch then return end

            local delta = input.Position - dragStart
            container.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end))

        table.insert(obj._conns, UserInputService.InputEnded:Connect(function(input)
            if input ~= dragInput then return end
            dragging = false
            dragInput = nil

            if cfg.SnapToEdge then
                local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
                          or Vector2.new(1920, 1080)
                local margin = cfg.SnapMargin or 12
                local curX = container.AbsolutePosition.X
                local curY = container.AbsolutePosition.Y
                local w    = container.AbsoluteSize.X
                local h    = container.AbsoluteSize.Y

                local distLeft  = curX
                local distRight = vp.X - (curX + w)
                local targetX
                if distLeft < distRight then
                    targetX = margin
                else
                    targetX = vp.X - w - margin
                end
                local targetY = clamp(curY, margin, math.max(vp.Y - h - margin, margin))

                Tween(container, 0.25, {
                    Position = UDim2.fromOffset(targetX, targetY),
                }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out):Play()
            end
        end))
    end

    -- ── Collapse toggle ───────────────────────────────────
    local collapsed = false
    local normalSize
    if collapseBtn then
        collapseBtn.MouseButton1Click:Connect(function()
            collapsed = not collapsed
            if collapsed then
                normalSize = container.Size
                Tween(container, 0.22, {
                    Size = UDim2.fromOffset(cfg.Width or 180, 24 + (cfg.Padding or 10) * 2),
                }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out):Play()
                Tween(list, 0.22, { BackgroundTransparency = 0 }):Play()
                for _, row in ipairs(list:GetChildren()) do
                    if row:IsA("GuiObject") and row ~= titleBar then
                        row.Visible = false
                    end
                end
                collapseBtn.Text = "▸"
            else
                Tween(container, 0.22, {
                    Size = normalSize or UDim2.fromOffset(cfg.Width or 180, 0),
                }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out):Play()
                for _, row in ipairs(list:GetChildren()) do
                    if row:IsA("GuiObject") and row ~= titleBar then
                        row.Visible = true
                    end
                end
                collapseBtn.Text = "▾"
            end
            PlayUISound("click")
        end)
    end

    -- ── Theme application ─────────────────────────────────
    local function applyTheme(t)
        obj.Theme = t
        local TP = palette(t)
        P = TP

        container.BackgroundColor3 = TP.bg
        containerStroke.Color      = TP.border
        bgGrad.Color               = ColorSequence.new(TP.bg, TP.bgDeep)

        if titleLbl then titleLbl.TextColor3 = TP.textHigh end
        if collapseBtn then collapseBtn.TextColor3 = TP.textDim end

        if accentGrad then
            accentGrad.Color = ColorSequence.new(TP.accent, TP.accent2)
        end

        for _, fn in ipairs(obj._themeFns) do
            pcall(fn, t)
        end
    end
    obj._applyTheme = applyTheme

    if cfg.Window then
        cfg.Window:_registerTheme(applyTheme)
    end

    -- ── Public methods ────────────────────────────────────
    function obj:Set(id, value)
        local row = self._rows[id]
        if not row then return end
        if row.kind == "text" and row.setText then
            row.setText(nil, value)
        elseif row.kind == "image" and row.setImage then
            row.setImage(nil, value)
        elseif row.kind == "imagebutton" and row.setImage then
            row.setImage(nil, value)
        elseif row.kind == "progress" and row.setValue then
            row.setValue(nil, value)
        end
    end

    function obj:SetText(id, text)
        local row = self._rows[id]
        if row and row.setText then row.setText(nil, text) end
    end

    function obj:SetImage(id, image)
        local row = self._rows[id]
        if row and row.setImage then row.setImage(nil, image) end
    end

    function obj:SetColor(id, color)
        local row = self._rows[id]
        if row and row.setColor then row.setColor(nil, color) end
    end

    function obj:SetLabel(id, text)
        local row = self._rows[id]
        if row and row.setLabel then row.setLabel(nil, text) end
    end

    function obj:SetProgress(id, value)
        local row = self._rows[id]
        if row and row.setValue then row.setValue(nil, value) end
    end

    function obj:Show()   self.Gui.Enabled = true  end
    function obj:Hide()   self.Gui.Enabled = false end

    function obj:SetVisible(v)
        if v then self:Show() else self:Hide() end
    end

    function obj:SetTitle(text)
        if titleLbl then titleLbl.Text = tostring(text) end
    end

    function obj:SetPosition(udim2)
        self.Container.Position = udim2
    end

    function obj:Destroy()
        for _, c in ipairs(self._conns or {}) do
            if typeof(c) == "RBXScriptConnection" then
                pcall(function() c:Disconnect() end)
            end
        end
        self._conns = {}
        if self.Gui then
            pcall(function() self.Gui:Destroy() end)
            self.Gui = nil
        end
    end

    -- Register for global cleanup
    LucidUI._overlays = LucidUI._overlays or {}
    table.insert(LucidUI._overlays, obj)

    -- Initial theme application
    applyTheme(theme)

    return obj
end

-- ============================================================
-- Quick helper: Update overlay rows from a table
-- ============================================================
--[[
    overlay:BatchSet({
        fps     = 60,
        players = 12,
        status  = "Ready",
    })
]]
function LucidUI.Overlay:BatchSet(data)
    if type(data) ~= "table" then return end
    for id, value in pairs(data) do
        self:Set(id, value)
    end
end

-- ============================================================
-- Cleanup
-- ============================================================
LucidUI:OnCleanup(function()
    if LucidUI._overlays then
        for _, ov in ipairs(LucidUI._overlays) do
            pcall(function() ov:Destroy() end)
        end
        LucidUI._overlays = {}
    end

    -- Fallback sweep for any stragglers
    pcall(function()
        if PlayerGui then
            for _, gui in ipairs(PlayerGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Name:match("^LucidUI_Overlay_") then
                    pcall(function() gui:Destroy() end)
                end
            end
        end
    end)

    print("[LucidUI] Overlay cleaned up")
end)

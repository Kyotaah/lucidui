-- ============================================================
-- Module: 06b_watermark.lua
-- ============================================================
--[[
    Watermark — a small floating glass pill in a screen corner.

    Shows the hub name plus a live FPS counter. Draggable, theme-aware,
    saves its config. Independent of the main window, so it stays
    visible even when the window is hidden or minimized to pill.

    [IMPROVEMENT] Fixed the fpsLabel.TextColor3:match crash bug.
    Added GetWatermark, SetPosition. FPS color now uses a smooth
    red→yellow→green gradient.

    [FIX] The highlight (top sheen) layer now re-tints with the
    theme. Previously it was hardcoded to Color3.fromRGB(255,255,255)
    which made it invisible against Light / Catppuccin Latte
    backgrounds. Now it uses theme.TextPrimary.
]]

LucidUI.Watermark = {}
LucidUI.Watermark.__index = LucidUI.Watermark

local WM_POSITIONS = {
    ["top-left"]     = { x = UDim.new(0, 12),  y = UDim.new(0, 12),  ax = 0, ay = 0 },
    ["top-right"]    = { x = UDim.new(1, -12), y = UDim.new(0, 12),  ax = 1, ay = 0 },
    ["bottom-left"]  = { x = UDim.new(0, 12),  y = UDim.new(1, -12), ax = 0, ay = 1 },
    ["bottom-right"] = { x = UDim.new(1, -12), y = UDim.new(1, -12), ax = 1, ay = 1 },
}

local function mkCorner(radius, parent)
    return Create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function mkStroke(color, thickness, transparency, parent)
    return Create("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0.5,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

-- [IMPROVEMENT] Smooth FPS color gradient.
local function fpsColor(fps)
    if fps >= 60 then
        return Color3.fromRGB(120, 210, 140)
    elseif fps >= 30 then
        local t = (fps - 30) / 30 -- 0 at 30fps, 1 at 60fps
        return Color3.new(1, 0.5 + 0.4 * t, 0.3 * t)
    else
        return Color3.fromRGB(255, 95, 87)
    end
end

function LucidUI.Window:SetWatermark(config)
    config = config or {}

    if self._watermark then
        pcall(function() self._watermark:Destroy() end)
        self._watermark = nil
    end

    local theme = self.Theme
    local W = setmetatable({}, LucidUI.Watermark)
    W.Window = self

    W._text      = config.Text or self.Name
    W._showFPS   = config.ShowFPS ~= false
    W._showDot   = config.ShowDot ~= false
    W._position  = config.Position or "top-left"
    W._draggable = config.Draggable ~= false
    W._color     = config.Color
    W._visible   = true

    W.Gui = Create("ScreenGui", {
        Name = "LucidUI_Watermark_" .. self.Name,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 150,
        Enabled = true,
        Parent = PlayerGui,
    })
    self._watermarkGui = W.Gui

    local preset = WM_POSITIONS[W._position] or WM_POSITIONS["top-left"]

    local pill = Create("Frame", {
        Name = "Watermark",
        Size = UDim2.fromOffset(160, 28),
        Position = UDim2.new(preset.x.Scale, preset.x.Offset, preset.y.Scale, preset.y.Offset),
        AnchorPoint = Vector2.new(preset.ax, preset.ay),
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = W.Gui,
    })
    mkCorner(14, pill)
    local pillStroke = mkStroke(theme.Border, 1, 0.55, pill)
    W.Pill = pill
    W.Stroke = pillStroke

    local highlight = Create("Frame", {
        Size = UDim2.fromScale(1, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.88,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = pill,
    })
    mkCorner(14, highlight)
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Rotation = 90,
        Parent = highlight,
    })
    W.Highlight = highlight

    local dot
    if W._showDot then
        dot = Create("Frame", {
            Size = UDim2.fromOffset(7, 7),
            Position = UDim2.new(0, 12, 0.5, -3.5),
            BackgroundColor3 = W._color or theme.Accent,
            BorderSizePixel = 0,
            ZIndex = 5,
            Parent = pill,
        })
        mkCorner(999, dot)
        W.Dot = dot
    end

    local textX = W._showDot and 26 or 14

    local nameLabel = Create("TextLabel", {
        Text = W._text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(textX, 0),
        Size = UDim2.new(1, -(textX + 60), 1, 0),
        ZIndex = 4,
        Parent = pill,
    })
    W.NameLabel = nameLabel

    local fpsLabel
    if W._showFPS then
        fpsLabel = Create("TextLabel", {
            Text = "60",
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = theme.TextMuted,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Right,
            Position = UDim2.new(1, -10, 0, 0),
            AnchorPoint = Vector2.new(1, 0),
            Size = UDim2.fromOffset(48, 28),
            ZIndex = 4,
            Parent = pill,
        })
        W.FPSLabel = fpsLabel
    end

    local function resize()
        local namePx = TextService:GetTextSize(
            nameLabel.Text, 12, Enum.Font.GothamBold, Vector2.new(400, 28)
        ).X
        local fpsPx = fpsLabel and TextService:GetTextSize(
            fpsLabel.Text, 11, Enum.Font.GothamBold, Vector2.new(200, 28)
        ).X or 0

        local leftPad  = W._showDot and 26 or 14
        local rightPad = 10
        local gap      = 10

        local total = leftPad + namePx + (fpsPx > 0 and (gap + fpsPx) or 0) + rightPad
        total = math.clamp(total, 100, 320)

        TweenService:Create(pill, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = UDim2.fromOffset(total, 28) }):Play()
    end
    resize()
    W._resize = resize

    -- FPS counter
    if W._showFPS then
        local frameCount = 0
        local lastUpdate = tick()

        W._fpsConn = RunService.RenderStepped:Connect(function()
            if not pill.Parent then return end
            frameCount = frameCount + 1
            local now = tick()
            if now - lastUpdate >= 0.5 then
                local fps = math.floor(frameCount / (now - lastUpdate) + 0.5)
                frameCount = 0
                lastUpdate = now
                fpsLabel.Text = tostring(fps)
                fpsLabel.TextColor3 = fpsColor(fps)
                resize()
            end
        end)
    end

    -- Dot pulse
    if W._showDot then
        task.spawn(function()
            while W.Dot and W.Dot.Parent do
                local t = tick()
                local pulse = 0.5 + 0.5 * math.sin(t * 3)
                W.Dot.BackgroundTransparency = pulse * 0.35
                task.wait(0.03)
            end
        end)
    end

    -- Drag
    if W._draggable then
        local dragging, startPos, startWindowPos, dragInput = false, nil, nil, nil

        W._dragChangeConn = UserInputService.InputChanged:Connect(function(input)
            if not dragging or input ~= dragInput then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            local d = input.Position - startPos
            pill.Position = UDim2.new(
                startWindowPos.X.Scale, startWindowPos.X.Offset + d.X,
                startWindowPos.Y.Scale, startWindowPos.Y.Offset + d.Y
            )
        end)

        W._dragEndConn = UserInputService.InputEnded:Connect(function(input)
            if input ~= dragInput then return end
            dragging  = false
            dragInput = nil

            local vp   = workspace.CurrentCamera.ViewportSize
            local pos  = pill.AbsolutePosition
            local size = pill.AbsoluteSize
            local nx = math.clamp(pos.X, 0, math.max(vp.X - size.X, 0))
            local ny = math.clamp(pos.Y, 0, math.max(vp.Y - size.Y, 0))
            pill.Position = UDim2.fromOffset(nx, ny)
        end)

        pill.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            dragging       = true
            dragInput      = input
            startPos       = input.Position
            startWindowPos = pill.Position
            pill.AnchorPoint = Vector2.new(0, 0)
        end)
    end

    -- Theme registration
    self:_registerTheme(function(t)
        if not pill.Parent then return end
        pill.BackgroundColor3 = t.Background
        pillStroke.Color      = t.Border
        nameLabel.TextColor3  = t.TextPrimary
        if W.Dot then W.Dot.BackgroundColor3 = W._color or t.Accent end
        -- [FIX] Re-tint the sheen layer so it doesn't stay hardcoded
        -- white. On Light / Latte themes, white-on-white made the
        -- highlight completely invisible.
        if W.Highlight and W.Highlight.Parent then
            W.Highlight.BackgroundColor3 = t.TextPrimary
        end
    end)

    -- Public methods
    function W:Set(text)
        W._text = tostring(text)
        nameLabel.Text = W._text
        W._resize()
    end

    function W:SetFPS(on)
        W._showFPS = on and true or false
        if fpsLabel then
            fpsLabel.Visible = W._showFPS
            W._resize()
        end
    end

    function W:SetVisible(on)
        W._visible = on and true or false
        W.Gui.Enabled = W._visible
    end

    function W:SetColor(c)
        W._color = c
        if W.Dot then W.Dot.BackgroundColor3 = c or self.Theme.Accent end
    end

    -- [IMPROVEMENT] Change position preset at runtime.
    function W:SetPosition(presetName)
        local p = WM_POSITIONS[presetName]
        if not p then return false end
        W._position = presetName
        pill.AnchorPoint = Vector2.new(p.ax, p.ay)
        pill.Position = UDim2.new(p.x.Scale, p.x.Offset, p.y.Scale, p.y.Offset)
        return true
    end

    function W:Destroy()
        if W._fpsConn      then pcall(function() W._fpsConn:Disconnect()      end) end
        if W._dragChangeConn then pcall(function() W._dragChangeConn:Disconnect() end) end
        if W._dragEndConn  then pcall(function() W._dragEndConn:Disconnect()  end) end
        W._fpsConn, W._dragChangeConn, W._dragEndConn = nil, nil, nil

        if W.Gui then
            pcall(function() W.Gui:Destroy() end)
            W.Gui = nil
        end
        if self._watermark == W then
            self._watermark = nil
            self._watermarkGui = nil
        end
    end

    W._configSnapshot = function()
        return {
            text     = W._text,
            showFPS  = W._showFPS,
            showDot  = W._showDot,
            position = W._position,
            px = pill.Position.X.Scale, py = pill.Position.Y.Scale,
            pxo = pill.Position.X.Offset, pyo = pill.Position.Y.Offset,
            ax = pill.AnchorPoint.X, ay = pill.AnchorPoint.Y,
        }
    end

    function W:RestoreFrom(saved)
        if type(saved) ~= "table" then return end
        if saved.text then W:Set(saved.text) end
        if saved.showFPS ~= nil then W:SetFPS(saved.showFPS) end
        if saved.showDot ~= nil then
            W._showDot = saved.showDot
            if W.Dot then W.Dot.Visible = saved.showDot end
        end
        if saved.px ~= nil then
            pill.Position = UDim2.new(saved.px, saved.pxo or 0, saved.py, saved.pyo or 0)
            pill.AnchorPoint = Vector2.new(saved.ax or 0, saved.ay or 0)
        end
    end

    self._watermark = W
    return W
end

function LucidUI.Window:ToggleWatermark()
    if self._watermark then
        self._watermark:SetVisible(not self._watermark._visible)
    else
        self:SetWatermark({
            Text = self.Name,
            ShowFPS = true,
        })
    end
end

function LucidUI.Window:RemoveWatermark()
    if self._watermark then
        self._watermark:Destroy()
    end
end

-- [IMPROVEMENT] Fetch the current watermark object.
function LucidUI.Window:GetWatermark()
    return self._watermark
end

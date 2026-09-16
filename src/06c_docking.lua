--[[
    Docking — snap the window to screen edges and corners.

    During a header drag, if the window's bounds come within
    `DockThreshold` pixels of a screen edge, a preview rectangle
    shows where it will land on release. Eight zones: left, right,
    top, bottom, and the four corners.

    Releasing inside a zone tweens the window into place. Starting
    a new drag from a docked window undocks it first (restores the
    original size, keeps the top-left where it is, then continues
    the drag from there).

    Resizing is blocked while docked — you must undock first.

    Config via CreateWindow:
      Docking       = true | false     (default true)
      DockThreshold = 30               (px from edge to trigger)
      DockMargin    = 12               (px gap between window and edge)
      DockSnapTime  = 0.25             (tween duration)
]]

local GuiService = game:GetService("GuiService")

local DOCK_ZONES = {
    ["left"]         = true,
    ["right"]        = true,
    ["top"]          = true,
    ["bottom"]       = true,
    ["top-left"]     = true,
    ["top-right"]    = true,
    ["bottom-left"]  = true,
    ["bottom-right"] = true,
}

function LucidUI.Window:_initDocking(config)
    if self._dockingInitialized then return end
    self._dockingInitialized = true

    config = config or {}

    self._dockEnabled   = config.Docking ~= false
    self._dockThreshold = config.DockThreshold or 30
    self._dockMargin    = config.DockMargin    or 12
    self._dockSnapTime  = config.DockSnapTime  or 0.25

    self._docked          = nil
    self._preDockSnapshot = nil
    self._hoverDock       = nil

    -- Preview rectangle. Sits above everything else in the GUI.
    local preview = Create("Frame", {
        Name = "DockPreview",
        BackgroundColor3 = self.Theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 50,
        Parent = self.Gui,
    })
    Corner(18, preview)
    local previewStroke = Stroke(self.Theme.Accent, 2, 1, preview)

    self._dockPreview = preview
    self._dockPreviewStroke = previewStroke

    -- ── Undock Button (for mobile users) ───────────────────────
    local undockBtn = Create("TextButton", {
        Name = "UndockButton",
        Text = "FLOAT",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = self.Theme.TextPrimary,
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = 0.3,
        AutoButtonColor = false,
        Size = UDim2.fromOffset(52, 24),
        Position = UDim2.new(1, -62, 0.5, -12),
        Visible = false,
        ZIndex = 10,
        Parent = self.Header,
    })
    Corner(6, undockBtn)
    
    -- Bind the button to the Undock function
    BindTap(undockBtn, function()
        self:Undock()
    end)

    self._undockBtn = undockBtn

    self:_registerTheme(function(t)
        preview.BackgroundColor3 = t.Accent
        previewStroke.Color      = t.Accent
        undockBtn.BackgroundColor3 = t.Surface
        undockBtn.TextColor3     = t.TextPrimary
    end)
end

-- ── Zone math ─────────────────────────────────────────────────
function LucidUI.Window:_computeDockZone()
    local scrW = self.Gui.AbsoluteSize.X
    local scrH = self.Gui.AbsoluteSize.Y
    local pos  = self.Main.AbsolutePosition
    local size = self.Main.AbsoluteSize
    local thr  = self._dockThreshold
    local topInset = GuiService.TopbarInset.Height

    local nearLeft   = pos.X <= thr
    local nearRight  = pos.X + size.X >= scrW - thr
    local nearTop    = pos.Y <= thr + topInset
    local nearBottom = pos.Y + size.Y >= scrH - thr

    -- Corners take priority — both axes must be near an edge.
    if nearTop and nearLeft     then return "top-left"     end
    if nearTop and nearRight    then return "top-right"    end
    if nearBottom and nearLeft  then return "bottom-left"  end
    if nearBottom and nearRight then return "bottom-right" end

    if nearLeft   then return "left"   end
    if nearRight  then return "right"  end
    if nearTop    then return "top"    end
    if nearBottom then return "bottom" end

    return nil
end

function LucidUI.Window:_dockRect(zone)
    local scrW = self.Gui.AbsoluteSize.X
    local scrH = self.Gui.AbsoluteSize.Y
    local m  = self._dockMargin
    local topInset = GuiService.TopbarInset.Height
    
    -- Safe area boundaries
    local safeTop = m + topInset
    local safeBottom = scrH - m
    local safeLeft = m
    local safeRight = scrW - m

    local availW = safeRight - safeLeft
    local availH = safeBottom - safeTop
    local halfW  = availW / 2
    local halfH  = availH / 2

    local map = {
        ["left"]         = { x = safeLeft,              y = safeTop,              w = halfW, h = availH },
        ["right"]        = { x = safeRight - halfW,     y = safeTop,              w = halfW, h = availH },
        ["top"]          = { x = safeLeft,              y = safeTop,              w = availW, h = halfH },
        ["bottom"]       = { x = safeLeft,              y = safeBottom - halfH,   w = availW, h = halfH },
        ["top-left"]     = { x = safeLeft,              y = safeTop,              w = halfW, h = halfH },
        ["top-right"]    = { x = safeRight - halfW,     y = safeTop,              w = halfW, h = halfH },
        ["bottom-left"]  = { x = safeLeft,              y = safeBottom - halfH,   w = halfW, h = halfH },
        ["bottom-right"] = { x = safeRight - halfW,     y = safeBottom - halfH,   w = halfW, h = halfH },
    }
    return map[zone]
end

-- ── Drag hooks ────────────────────────────────────────────────
function LucidUI.Window:_onBeforeDragStart()
    if not self._docked then return end

    -- Undock instantly so the drag starts from a canonical size.
    local snap = self._preDockSnapshot
    self._docked = nil
    self._preDockSnapshot = nil

    if snap then
        self.Main.Size = UDim2.fromOffset(snap.width, snap.height)
        -- No ClampPosition here! Let the drag take over smoothly.
    end
    if self._undockBtn then self._undockBtn.Visible = false end
end

function LucidUI.Window:_onDragTick()
    if not self._dockEnabled then return end

    local zone = self:_computeDockZone()
    self._hoverDock = zone

    local preview = self._dockPreview
    if not preview then return end

    if zone then
        local rect = self:_dockRect(zone)
        preview.Position = UDim2.fromOffset(rect.x, rect.y)
        preview.Size     = UDim2.fromOffset(rect.w, rect.h)
        preview.Visible  = true
        TweenService:Create(preview, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = 0.72 }):Play()
        TweenService:Create(self._dockPreviewStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Transparency = 0.15 }):Play()
    else
        TweenService:Create(preview, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = 1 }):Play()
        TweenService:Create(self._dockPreviewStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Transparency = 1 }):Play()

        task.delay(0.16, function()
            if preview and preview.Parent and not self._hoverDock then
                preview.Visible = false
            end
        end)
    end
end

function LucidUI.Window:_onDragEnd()
    local preview = self._dockPreview
    if preview then
        preview.Visible = false
        preview.BackgroundTransparency = 1
    end

    if not self._dockEnabled then return end

    local zone = self._hoverDock
    self._hoverDock = nil

    if zone and DOCK_ZONES[zone] then
        self:DockTo(zone)
    end
end

-- ── Public API ────────────────────────────────────────────────
function LucidUI.Window:DockTo(zone, instant)
    if not DOCK_ZONES[zone] then return false end
    if self.Minimized then return false end

    local rect = self:_dockRect(zone)
    if not rect then return false end

    -- Save pre-dock state once, so we can restore on undock.
    if not self._preDockSnapshot then
        self._preDockSnapshot = {
            width  = self._width,
            height = self._height,
        }
    end

    self._docked = zone
    if self._undockBtn then self._undockBtn.Visible = true end

    local info = instant
        and TweenInfo.new(0)
        or  TweenInfo.new(self._dockSnapTime, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    TweenService:Create(self.Main, info, {
        Size     = UDim2.fromOffset(rect.w, rect.h),
        Position = UDim2.fromOffset(rect.x, rect.y),
    }):Play()

    return true
end

function LucidUI.Window:Undock(instant)
    if not self._docked then return end
    self._docked = nil
    if self._undockBtn then self._undockBtn.Visible = false end

    local snap = self._preDockSnapshot
    self._preDockSnapshot = nil

    if not snap then return end

    local info = instant
        and TweenInfo.new(0)
        or  TweenInfo.new(self._dockSnapTime, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    -- Restore to center of screen at canonical size
    local scrW = self.Gui.AbsoluteSize.X
    local scrH = self.Gui.AbsoluteSize.Y
    local targetX = math.max((scrW - snap.width) / 2, 0)
    local targetY = math.max((scrH - snap.height) / 2, 0)

    TweenService:Create(self.Main, info, {
        Size     = UDim2.fromOffset(snap.width, snap.height),
        Position = UDim2.fromOffset(targetX, targetY),
    }):Play()

    task.delay(self._dockSnapTime + 0.05, function()
        ClampPosition(self.Main)
    end)
end

function LucidUI.Window:SetDocking(enabled)
    self._dockEnabled = enabled and true or false
    if not self._dockEnabled and self._docked then
        self:Undock()
    end
    if not self._dockEnabled and self._dockPreview then
        self._dockPreview.Visible = false
    end
end

function LucidUI.Window:GetDockZone()
    return self._docked
end

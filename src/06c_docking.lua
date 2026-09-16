--[[
    Docking — snap the window to screen edges and corners.

    OPT-IN: Enabled only when the user passes `Docking = true` to
    CreateWindow. Default is OFF for a cleaner mobile experience.

    During a header drag, if the window's bounds come within
    `DockThreshold` pixels of a screen edge, a preview rectangle
    shows where it will land on release. Eight zones: left, right,
    top, bottom, and the four corners.

    Releasing inside a zone tweens the window into place. A "FLOAT"
    button appears in the header so mobile users can undock by
    tapping it (or by starting a new drag).

    [IMPROVEMENT] Uses GuiService.TopbarInset for safe area, self.Gui
    size for accurate bounds, opt-in only, all connections tracked,
    FLOAT button for mobile users.
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

-- ============================================================
-- Init
-- ============================================================
function LucidUI.Window:_initDocking(config)
    if self._dockingInitialized then return end
    self._dockingInitialized = true

    config = config or {}

    self._dockEnabled   = config.Docking == true -- [IMPROVEMENT] opt-in
    self._dockThreshold = config.DockThreshold or 30
    self._dockMargin    = config.DockMargin    or 12
    self._dockSnapTime  = config.DockSnapTime  or 0.25

    self._docked          = nil
    self._preDockSnapshot = nil
    self._hoverDock       = nil

    -- Preview rectangle
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

    -- FLOAT undock button (mobile-friendly)
    local undockBtn = Create("TextButton", {
        Name = "UndockButton",
        Text = "FLOAT",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = self.Theme.TextPrimary,
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = 0.3,
        AutoButtonColor = false,
        Size = UDim2.fromOffset(60, 28),
        Position = UDim2.new(1, -70, 0.5, -14),
        Visible = false,
        ZIndex = 10,
        Parent = self.Header,
    })
    Corner(8, undockBtn)

    BindTap(undockBtn, function()
        self:Undock()
    end)

    undockBtn.MouseEnter:Connect(function()
        Tween(undockBtn, 0.15, {
            BackgroundTransparency = 0.1,
            TextColor3 = self.Theme.Accent,
        }):Play()
    end)
    undockBtn.MouseLeave:Connect(function()
        Tween(undockBtn, 0.15, {
            BackgroundTransparency = 0.3,
            TextColor3 = self.Theme.TextPrimary,
        }):Play()
    end)

    self._undockBtn = undockBtn

    self:_registerTheme(function(t)
        preview.BackgroundColor3     = t.Accent
        previewStroke.Color          = t.Accent
        undockBtn.BackgroundColor3   = t.Surface
        undockBtn.TextColor3         = t.TextPrimary
    end)
end

-- ============================================================
-- Zone math
-- ============================================================
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

    local safeTop    = m + topInset
    local safeBottom = scrH - m
    local safeLeft   = m
    local safeRight  = scrW - m

    local availW = safeRight - safeLeft
    local availH = safeBottom - safeTop
    local halfW  = availW / 2
    local halfH  = availH / 2

    local map = {
        ["left"]         = { x = safeLeft,             y = safeTop,            w = halfW, h = availH },
        ["right"]        = { x = safeRight - halfW,    y = safeTop,            w = halfW, h = availH },
        ["top"]          = { x = safeLeft,             y = safeTop,            w = availW, h = halfH },
        ["bottom"]       = { x = safeLeft,             y = safeBottom - halfH, w = availW, h = halfH },
        ["top-left"]     = { x = safeLeft,             y = safeTop,            w = halfW, h = halfH },
        ["top-right"]    = { x = safeRight - halfW,    y = safeTop,            w = halfW, h = halfH },
        ["bottom-left"]  = { x = safeLeft,             y = safeBottom - halfH, w = halfW, h = halfH },
        ["bottom-right"] = { x = safeRight - halfW,    y = safeBottom - halfH, w = halfW, h = halfH },
    }
    return map[zone]
end

-- ============================================================
-- Drag hooks
-- ============================================================
function LucidUI.Window:_onBeforeDragStart()
    if not self._docked then return end

    local snap = self._preDockSnapshot
    self._docked = nil
    self._preDockSnapshot = nil

    if snap then
        self.Main.Size = UDim2.fromOffset(snap.width, snap.height)
        -- Intentionally no ClampPosition here so the drag feels smooth.
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
        pcall(function()
            TweenService:Create(preview, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { BackgroundTransparency = 0.72 }):Play()
            TweenService:Create(self._dockPreviewStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Transparency = 0.15 }):Play()
        end)
    else
        pcall(function()
            TweenService:Create(preview, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { BackgroundTransparency = 1 }):Play()
            TweenService:Create(self._dockPreviewStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Transparency = 1 }):Play()
        end)

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

-- ============================================================
-- Public API
-- ============================================================
function LucidUI.Window:DockTo(zone, instant)
    if not DOCK_ZONES[zone] then return false end
    if self.Minimized then return false end

    local rect = self:_dockRect(zone)
    if not rect then return false end

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

    pcall(function()
        TweenService:Create(self.Main, info, {
            Size     = UDim2.fromOffset(rect.w, rect.h),
            Position = UDim2.fromOffset(rect.x, rect.y),
        }):Play()
    end)

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

    local scrW = self.Gui.AbsoluteSize.X
    local scrH = self.Gui.AbsoluteSize.Y
    local targetX = math.max((scrW - snap.width) / 2, 0)
    local targetY = math.max((scrH - snap.height) / 2, 0)

    pcall(function()
        TweenService:Create(self.Main, info, {
            Size     = UDim2.fromOffset(snap.width, snap.height),
            Position = UDim2.fromOffset(targetX, targetY),
        }):Play()
    end)

    task.delay(self._dockSnapTime + 0.05, function()
        pcall(function() ClampPosition(self.Main) end)
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

-- [IMPROVEMENT] Convenience boolean check.
function LucidUI.Window:IsDocked()
    return self._docked ~= nil
end

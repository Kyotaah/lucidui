-- ============================================================
-- Module: 08d_errorhandler.lua
-- ============================================================
--[[
    Global Error Boundary — catches user callback errors and surfaces
    them visibly instead of swallowing them silently.

    Overrides Compat.safeCallback (defined in 00_compat.lua) so every
    existing caller in 09_elements.lua automatically gets the enriched
    behavior without any changes.

    Adds:
      LucidUI:SetErrorNotifications(bool)
      LucidUI:SetErrorHandler(fn)
      LucidUI:GetLastError()
      LucidUI:GetErrorLog()
      LucidUI:ClearErrorLog()
      LucidUI:SetVerboseErrors(bool)

    [NEW] Discord webhook integration:
      LucidUI:SetErrorWebhook(bool)   -- default OFF
      LucidUI:SetErrorWebhookCooldown(seconds) -- default 30

    When enabled, any callback error caught by the boundary fires a
    LogError to the configured webhook. Identical error messages are
    deduplicated within the cooldown window to prevent a loop of the
    same failure from flooding Discord.
]]

-- ============================================================
-- Config + state
-- ============================================================
local MAX_LOG_SIZE       = 25
local NOTIFICATION_LIMIT = "first"  -- "first" | "all" | "none"

LucidUI._errorLog        = {}
LucidUI._errorHandler    = nil
LucidUI._errorCount      = 0
LucidUI._notifiedErrors  = {}
LucidUI._errorNotify     = true
LucidUI._verboseErrors   = false

-- [NEW] Webhook integration state
LucidUI._errorWebhook          = false
LucidUI._errorWebhookCooldown  = 30
LucidUI._errorWebhookLastSent  = {}   -- [message] = tick() of last send

-- ============================================================
-- Save the original for fallback
-- ============================================================
local _originalSafeCallback = Compat.safeCallback

-- ============================================================
-- Traceback formatter — pulls the first library line from the stack
-- ============================================================
local function formatTrace(err)
    local trace = debug.traceback(tostring(err), 2)

    -- Walk the stack, find the first line that isn't our own handler
    local best
    for line in trace:gmatch("[^\n]+") do
        if not line:find("errorhandler", 1, true)
           and not line:find("safeCallback", 1, true)
           and not line:find("Compat", 1, true) then
            if line:find("%.lua") or line:find(":") then
                best = line
                break
            end
        end
    end

    return trace, best
end

-- ============================================================
-- [NEW] Dispatch an error to Discord (dedup + throttle)
-- ============================================================
local function dispatchToWebhook(entry)
    -- Nothing to do if the user hasn't opted in or configured a webhook
    if not LucidUI._errorWebhook then return end
    if not LucidUI.GetWebhook or not LucidUI:GetWebhook() then return end

    -- Deduplicate identical messages inside the cooldown window so a
    -- rapidly-failing loop doesn't send one embed per frame.
    local key = entry.message
    local now = tick()
    local last = LucidUI._errorWebhookLastSent[key]
    if last and (now - last) < LucidUI._errorWebhookCooldown then
        return
    end
    LucidUI._errorWebhookLastSent[key] = now

    -- Trim the log occasionally so it doesn't grow unbounded
    local seen = 0
    for _ in pairs(LucidUI._errorWebhookLastSent) do
        seen = seen + 1
        if seen > 200 then break end
    end
    if seen > 200 then
        LucidUI._errorWebhookLastSent = {}
        LucidUI._errorWebhookLastSent[key] = now
    end

    -- Fire the send. Errors inside the webhook module are their own
    -- problem — don't let them bubble back here and recurse.
    pcall(function()
        LucidUI:LogError(entry.message, {
            traceback = entry.trace,
            extra     = entry.line,
        })
    end)
end

-- ============================================================
-- Enriched safeCallback — overrides Compat's default
-- ============================================================
local function enrichedSafeCallback(fn, ...)
    if type(fn) ~= "function" then return end

    local ok, err = xpcall(fn, function(e)
        return tostring(e)
    end, ...)

    if ok then return end

    -- Track error
    local trace, bestLine = formatTrace(err)
    LucidUI._errorCount = LucidUI._errorCount + 1

    local entry = {
        timestamp = os.time(),
        message   = tostring(err),
        trace     = trace,
        line      = bestLine,
    }
    table.insert(LucidUI._errorLog, entry)
    if #LucidUI._errorLog > MAX_LOG_SIZE then
        table.remove(LucidUI._errorLog, 1)
    end

    -- Custom handler hook
    if LucidUI._errorHandler then
        pcall(LucidUI._errorHandler, entry)
    end

    -- Console output
    warn("[LucidUI] Callback error: " .. tostring(err))
    if LucidUI._verboseErrors then
        warn(trace)
    else
        warn("[LucidUI] Enable verbose errors with LucidUI:SetVerboseErrors(true)")
    end

    -- [NEW] Optional Discord dispatch
    dispatchToWebhook(entry)

    -- Notification
    if not LucidUI._errorNotify then return end

    local shouldNotify = false
    if NOTIFICATION_LIMIT == "all" then
        shouldNotify = true
    elseif NOTIFICATION_LIMIT == "first" then
        -- Only notify once per unique error message
        if not LucidUI._notifiedErrors[tostring(err)] then
            LucidUI._notifiedErrors[tostring(err)] = true
            shouldNotify = true
        end
    end

    if shouldNotify then
        local msg = tostring(err)
        if #msg > 100 then msg = msg:sub(1, 97) .. "..." end

        pcall(function()
            LucidUI:Notify({
                Title    = "Script Error",
                Message  = msg,
                Duration = 5,
                Variant  = "error",
            })
        end)
    end
end

-- Install override
Compat.safeCallback = enrichedSafeCallback

-- ============================================================
-- Public API
-- ============================================================
function LucidUI:SetErrorNotifications(enabled)
    self._errorNotify = enabled and true or false
end

function LucidUI:SetVerboseErrors(enabled)
    self._verboseErrors = enabled and true or false
end

function LucidUI:SetErrorHandler(fn)
    if fn ~= nil and type(fn) ~= "function" then
        warn("[LucidUI] SetErrorHandler expects a function or nil")
        return
    end
    self._errorHandler = fn
end

function LucidUI:GetLastError()
    return self._errorLog[#self._errorLog]
end

function LucidUI:GetErrorLog()
    return self._errorLog
end

function LucidUI:ClearErrorLog()
    self._errorLog = {}
    self._errorCount = 0
    self._notifiedErrors = {}
    self._errorWebhookLastSent = {}
end

function LucidUI:GetErrorCount()
    return self._errorCount
end

-- ── [NEW] Webhook integration ──────────────────────────────
function LucidUI:SetErrorWebhook(enabled)
    self._errorWebhook = enabled and true or false
end

function LucidUI:GetErrorWebhook()
    return self._errorWebhook
end

function LucidUI:SetErrorWebhookCooldown(seconds)
    if type(seconds) == "number" and seconds >= 0 then
        self._errorWebhookCooldown = seconds
    end
end

-- ============================================================
-- Settings UI — hooked into BuildSettingsPanel
-- ============================================================
function LucidUI.Window:_buildErrorSettings()
    self:_addSettingSection("Errors")

    -- Row 1: Notification toggle
    local row1 = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 44),
    })
    Corner(10, row1)
    self:_addSettingFrame(row1)

    local label1 = Create("TextLabel", {
        Text = "Show error notifications",
        Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -100, 1, 0),
        Parent = row1,
    })

    local track1 = Create("Frame", {
        Size = UDim2.fromOffset(44, 24),
        Position = UDim2.new(1, -58, 0.5, -12),
        BackgroundColor3 = LucidUI._errorNotify and self.Theme.Accent or self.Theme.ToggleOff,
        BorderSizePixel = 0, Parent = row1,
    })
    Corner(12, track1)

    local knob1 = Create("Frame", {
        Size = UDim2.fromOffset(20, 20),
        Position = LucidUI._errorNotify and UDim2.new(1, -22, 0.5, -10) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0, Parent = track1,
    })
    Corner(10, knob1)

    local click1 = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = row1,
    })

    BindTap(click1, function()
        PlayUISound("click")
        local on = not LucidUI._errorNotify
        LucidUI:SetErrorNotifications(on)
        local t = self.Theme
        Tween(track1, 0.22, {
            BackgroundColor3 = on and t.Accent or t.ToggleOff,
        }, Enum.EasingStyle.Quart):Play()
        Tween(knob1, 0.22, {
            Position = on and UDim2.new(1, -22, 0.5, -10) or UDim2.fromOffset(2, 2),
        }, Enum.EasingStyle.Quart):Play()
    end)

    -- Row 2: Verbose toggle
    local row2 = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 44),
    })
    Corner(10, row2)
    self:_addSettingFrame(row2)

    local label2 = Create("TextLabel", {
        Text = "Verbose tracebacks",
        Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -100, 1, 0),
        Parent = row2,
    })

    local track2 = Create("Frame", {
        Size = UDim2.fromOffset(44, 24),
        Position = UDim2.new(1, -58, 0.5, -12),
        BackgroundColor3 = LucidUI._verboseErrors and self.Theme.Accent or self.Theme.ToggleOff,
        BorderSizePixel = 0, Parent = row2,
    })
    Corner(12, track2)

    local knob2 = Create("Frame", {
        Size = UDim2.fromOffset(20, 20),
        Position = LucidUI._verboseErrors and UDim2.new(1, -22, 0.5, -10) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0, Parent = track2,
    })
    Corner(10, knob2)

    local click2 = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = row2,
    })

    BindTap(click2, function()
        PlayUISound("click")
        local on = not LucidUI._verboseErrors
        LucidUI:SetVerboseErrors(on)
        local t = self.Theme
        Tween(track2, 0.22, {
            BackgroundColor3 = on and t.Accent or t.ToggleOff,
        }, Enum.EasingStyle.Quart):Play()
        Tween(knob2, 0.22, {
            Position = on and UDim2.new(1, -22, 0.5, -10) or UDim2.fromOffset(2, 2),
        }, Enum.EasingStyle.Quart):Play()
    end)

    -- [NEW] Row 3: Discord webhook toggle
    local row3 = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 56),
    })
    Corner(10, row3)
    self:_addSettingFrame(row3)

    local label3 = Create("TextLabel", {
        Text = "Send errors to Discord",
        Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 6),
        Size = UDim2.new(1, -100, 0, 18),
        Parent = row3,
    })

    local subLabel3 = Create("TextLabel", {
        Text = "Requires a webhook URL (below). Deduped 30s.",
        Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = self.Theme.TextMuted, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 26),
        Size = UDim2.new(1, -100, 0, 14),
        Parent = row3,
    })

    local track3 = Create("Frame", {
        Size = UDim2.fromOffset(44, 24),
        Position = UDim2.new(1, -58, 0.5, -12),
        BackgroundColor3 = LucidUI._errorWebhook and self.Theme.Accent or self.Theme.ToggleOff,
        BorderSizePixel = 0, Parent = row3,
    })
    Corner(12, track3)

    local knob3 = Create("Frame", {
        Size = UDim2.fromOffset(20, 20),
        Position = LucidUI._errorWebhook and UDim2.new(1, -22, 0.5, -10) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0, Parent = track3,
    })
    Corner(10, knob3)

    local click3 = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = row3,
    })

    BindTap(click3, function()
        PlayUISound("click")
        local on = not LucidUI._errorWebhook

        -- Refuse to turn on if there's no webhook configured
        if on and not (LucidUI.GetWebhook and LucidUI:GetWebhook()) then
            LucidUI:Notify({
                Title = "No Webhook",
                Message = "Set a webhook URL first.",
                Variant = "warn",
                Duration = 3,
            })
            return
        end

        LucidUI:SetErrorWebhook(on)
        local t = self.Theme
        Tween(track3, 0.22, {
            BackgroundColor3 = on and t.Accent or t.ToggleOff,
        }, Enum.EasingStyle.Quart):Play()
        Tween(knob3, 0.22, {
            Position = on and UDim2.new(1, -22, 0.5, -10) or UDim2.fromOffset(2, 2),
        }, Enum.EasingStyle.Quart):Play()
    end)

    -- Row 4: action buttons
    local actionRow = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
    })
    self:_addSettingFrame(actionRow)
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        Parent = actionRow,
    })

    local function mkBtn(text, color, cb)
        local b = Create("TextButton", {
            Text = text, Font = Enum.Font.GothamBold, TextSize = 12,
            TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundColor3 = color,
            BackgroundTransparency = 0.2, AutoButtonColor = false,
            Size = UDim2.new(0.5, -3, 1, 0), Parent = actionRow,
        })
        Corner(8, b)
        BindTap(b, cb, { MoveThreshold = 8 })
        return b
    end

    mkBtn("Test Error", self.Theme.Accent, function()
        Compat.safeCallback(function()
            error("Test error from LucidUI error boundary")
        end)
    end)

    mkBtn("Clear Log", Color3.fromRGB(220, 60, 60), function()
        LucidUI:ClearErrorLog()
        LucidUI:Notify({
            Title = "Cleared",
            Message = "Error log emptied.",
            Variant = "info",
            Duration = 2,
        })
    end)

    self:_registerTheme(function(t)
        row1.BackgroundColor3 = t.Surface
        row2.BackgroundColor3 = t.Surface
        row3.BackgroundColor3 = t.Surface
        label1.TextColor3 = t.TextPrimary
        label2.TextColor3 = t.TextPrimary
        label3.TextColor3 = t.TextPrimary
        subLabel3.TextColor3 = t.TextMuted
        track1.BackgroundColor3 = LucidUI._errorNotify   and t.Accent or t.ToggleOff
        track2.BackgroundColor3 = LucidUI._verboseErrors and t.Accent or t.ToggleOff
        track3.BackgroundColor3 = LucidUI._errorWebhook  and t.Accent or t.ToggleOff
    end)
end

-- ============================================================
-- Hook into BuildSettingsPanel without touching 07_settings_b.lua
-- ============================================================
local _origBuildSettings = LucidUI.Window.BuildSettingsPanel
LucidUI.Window.BuildSettingsPanel = function(self, ...)
    _origBuildSettings(self, ...)
    if not self._errorSettingsBuilt and self._settingsBuilt then
        self._errorSettingsBuilt = true
        pcall(function() self:_buildErrorSettings() end)
    end
end

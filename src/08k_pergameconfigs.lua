-- ============================================================
-- Module: 08h_pergame_configs.lua
-- ============================================================
--[[
    Per-Game Configs — separate config folder per Roblox game,
    so your hub's settings don't collide between games.

    Without this module:
        LucidUI/Configs/aimbot.json    <- same file for every game

    With this module:
        LucidUI/Configs/{PlaceId}/aimbot.json   <- one per game

    Features:
      • Per-game save / load / list / delete
      • Autoload: remembers which config to load on join
      • Retry-with-backoff: if a flag isn't registered yet (because
        the game hasn't loaded or your tabs are still building),
        it waits and tries again instead of failing silently
      • Opt-in per window via CreateWindow({ PerGameConfigs = true })
      • Non-destructive: if disabled, falls back to the global system

    NO tracking. NO network. NO clipboard.
]]

-- ============================================================
-- Config helpers
-- ============================================================
LucidUI.GameConfigs = {}
local GC = LucidUI.GameConfigs

local function hasFS()
    return type(makefolder) == "function"
       and type(isfolder)   == "function"
       and type(writefile)  == "function"
       and type(readfile)   == "function"
end

local function isfolderSafe(path)
    if type(isfolder) ~= "function" then return false end
    local ok, res = pcall(isfolder, path)
    return ok and res == true
end

local function isfileSafe(path)
    if type(isfile) ~= "function" then return false end
    local ok, res = pcall(isfile, path)
    return ok and res == true
end

-- Ensure a folder exists (creates nested folders one by one)
local function ensureFolder(path)
    if not hasFS() then return false end
    local parts = {}
    for segment in path:gmatch("[^/]+") do
        table.insert(parts, segment)
    end

    local built = ""
    for i, seg in ipairs(parts) do
        built = (i == 1) and seg or (built .. "/" .. seg)
        if not isfolderSafe(built) then
            local ok = pcall(makefolder, built)
            if not ok then return false end
        end
    end
    return true
end

-- ============================================================
-- Path layout
-- ============================================================
local ROOT          = "LucidUI"
local PLACE_ROOT    -- computed lazily (needs game.PlaceId)
local CONFIG_DIR    -- ROOT/{PlaceId}/Configs
local AUTOLOAD_FILE -- ROOT/{PlaceId}/autoload.json

local function ensurePaths()
    if PLACE_ROOT then return end
    local placeId = tostring(game.PlaceId)
    PLACE_ROOT    = ROOT .. "/" .. placeId
    CONFIG_DIR    = PLACE_ROOT .. "/Configs"
    AUTOLOAD_FILE = PLACE_ROOT .. "/autoload.json"

    ensureFolder(ROOT)
    ensureFolder(PLACE_ROOT)
    ensureFolder(CONFIG_DIR)
end

local function configPath(name)
    ensurePaths()
    -- Sanitize file name
    local safe = tostring(name):gsub("[^%w_%-%s%.]", "_")
    return CONFIG_DIR .. "/" .. safe .. ".json"
end

-- ============================================================
-- List / read / write
-- ============================================================
function GC.List()
    ensurePaths()
    if type(listfiles) ~= "function" then return {} end
    if not isfolderSafe(CONFIG_DIR) then return {} end

    local ok, files = pcall(listfiles, CONFIG_DIR)
    if not ok or type(files) ~= "table" then return {} end

    local out = {}
    for _, path in ipairs(files) do
        local name = path:match("([^/\\]+)%.json$")
        if name then table.insert(out, name) end
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

function GC.Read(name)
    ensurePaths()
    if type(readfile) ~= "function" then return nil end
    local path = configPath(name)
    if not isfileSafe(path) then return nil end

    local ok, raw = pcall(readfile, path)
    if not ok or not raw then return nil end

    local decodeOK, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(raw)
    end)
    if not decodeOK or type(data) ~= "table" then return nil end
    return data
end

function GC.Write(name, data)
    ensurePaths()
    if type(writefile) ~= "function" then return false end

    local encodeOK, raw = pcall(function()
        return game:GetService("HttpService"):JSONEncode(data)
    end)
    if not encodeOK or not raw then return false end

    local path = configPath(name)
    local ok = pcall(writefile, path, raw)
    return ok
end

function GC.Delete(name)
    ensurePaths()
    if type(delfile) ~= "function" then return false end
    local path = configPath(name)
    if not isfileSafe(path) then return false end
    return pcall(delfile, path)
end

-- ============================================================
-- Autoload
-- ============================================================
local function saveAutoload(slotName)
    ensurePaths()
    if type(writefile) ~= "function" then return false end
    local payload = game:GetService("HttpService"):JSONEncode({
        slot = slotName or "",
        savedAt = os.time(),
    })
    return pcall(writefile, AUTOLOAD_FILE, payload)
end

local function readAutoload()
    ensurePaths()
    if type(readfile) ~= "function" then return nil end
    if not isfileSafe(AUTOLOAD_FILE) then return nil end

    local ok, raw = pcall(readfile, AUTOLOAD_FILE)
    if not ok or not raw then return nil end

    local decodeOK, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(raw)
    end)
    if not decodeOK or type(data) ~= "table" then return nil end
    if type(data.slot) ~= "string" or data.slot == "" then return nil end
    return data.slot
end

function GC.SetAutoload(slotName)
    return saveAutoload(slotName)
end

function GC.GetAutoload()
    return readAutoload()
end

function GC.ClearAutoload()
    return saveAutoload(nil)
end

-- ============================================================
-- Save / Load window config to per-game slot
-- ============================================================
--[[
    These mirror the shape of Window:SaveConfig / LoadConfig but
    write into the per-game folder instead of the global one.
]]

function GC.SaveWindow(window, name)
    if not window or not name then return false end
    if not hasFS() then return false end

    local data = {
        version     = 1,
        placeId     = game.PlaceId,
        savedAt     = os.time(),
        theme       = window._customThemeActive and "Custom" or window.ThemeName,
        windowSize  = { window._width, window._height },
        accent      = window._accentOverride and {
            R = window._accentOverride.R,
            G = window._accentOverride.G,
            B = window._accentOverride.B,
        } or nil,
        customTheme = window._customTheme and Compat.serializeColors(window._customTheme) or nil,
        bgUrl       = window._backgroundUrl,
        bgTrans     = window._bgTransparency,
        pillKeybind = window.PillKeybind and window.PillKeybind.Name or nil,
        lowGraphics = window._lowGraphics,
        elements    = window._configData or {},
    }
    return GC.Write(name, data)
end

function GC.LoadWindow(window, name, opts)
    opts = opts or {}
    if not window or not name then return false, "bad args" end
    if not hasFS() then return false, "no filesystem" end

    local data = GC.Read(name)
    if not data then return false, "not found" end

    -- Apply theme
    if data.theme then
        if data.theme == "Custom" and data.customTheme then
            local restored = Compat.deserializeColors(data.customTheme)
            if restored then
                local d = LucidUI.Themes.Default
                window._customTheme = {
                    Background   = restored.Background   or d.Background,
                    Surface      = restored.Surface      or d.Surface,
                    SurfaceHover = restored.SurfaceHover or d.SurfaceHover,
                    Accent       = restored.Accent       or d.Accent,
                    Border       = restored.Border       or d.Border,
                    TextPrimary  = restored.TextPrimary  or d.TextPrimary,
                }
                window:ApplyCustomTheme()
            end
        elseif LucidUI.Themes[data.theme] then
            window:SetTheme(data.theme)
        end
    end

    if data.accent then
        window:SetAccent(Color3.new(data.accent.R, data.accent.G, data.accent.B))
    end

    if data.windowSize then
        window._width  = math.clamp(data.windowSize[1], window._minWidth,  window._maxWidth)
        window._height = math.clamp(data.windowSize[2], window._minHeight, window._maxHeight)
        window._fullSize = UDim2.fromOffset(window._width, window._height)
        if not window.Minimized and window.Main then
            window.Main.Size = window._fullSize
        end
    end

    if data.bgTrans then window._bgTransparency = data.bgTrans end
    if data.bgUrl then window:SetBackgroundImage(data.bgUrl) end
    if data.pillKeybind then
        local key = Enum.KeyCode[data.pillKeybind]
        if key then window.PillKeybind = key end
    end

    -- Apply element values
    local applied, missing, errors = 0, {}, {}
    local elements = data.elements or {}

    for flag, value in pairs(elements) do
        local el = window._elementsByFlag and window._elementsByFlag[flag]
        if el and el.Set then
            local ok, err = pcall(function() el:Set(value) end)
            if ok then
                applied = applied + 1
            else
                table.insert(errors, { flag = flag, err = tostring(err) })
            end
        else
            table.insert(missing, flag)
        end
    end

    if opts.silent ~= true then
        local msg
        if #missing == 0 and #errors == 0 then
            msg = applied .. " element(s) loaded"
            LucidUI:Notify({
                Title = "Config Loaded",
                Message = name .. " — " .. msg,
                Variant = "success",
                Duration = 3,
            })
        else
            msg = applied .. " applied, " .. #missing .. " missing, " .. #errors .. " failed"
            LucidUI:Notify({
                Title = "Config Loaded (partial)",
                Message = name .. " — " .. msg,
                Variant = "warn",
                Duration = 5,
            })
        end
    end

    return true, {
        applied = applied,
        missing = missing,
        errors  = errors,
    }
end

-- ============================================================
-- Auto-load with retry
-- ============================================================
--[[
    Called after window creation. Waits for UI to settle, then
    loads the autoload slot. If any flags are missing, retries
    with increasing delay up to maxRetries.
]]

local function attemptAutoload(window, slot, attempt, maxRetries, onDone)
    attempt = attempt or 1
    maxRetries = maxRetries or 8

    local ok, result = GC.LoadWindow(window, slot, { silent = true })
    if not ok then
        if onDone then onDone(false) end
        return
    end

    local missing = result.missing or {}
    if #missing == 0 or attempt >= maxRetries then
        -- Done (either fully applied or out of retries)
        if #missing == 0 then
            LucidUI:Notify({
                Title = "Auto-Loaded",
                Message = slot .. " (" .. result.applied .. " element(s))",
                Variant = "success",
                Duration = 4,
            })
        else
            LucidUI:Notify({
                Title = "Auto-Load (partial)",
                Message = slot .. " — " .. #missing .. " flag(s) skipped",
                Variant = "warn",
                Duration = 5,
            })
        end
        if onDone then onDone(true, result) end
        return
    end

    -- Retry with backoff
    local wait = 0.5 + attempt * 0.4
    task.delay(wait, function()
        if not window.Gui or not window.Gui.Parent then return end
        attemptAutoload(window, slot, attempt + 1, maxRetries, onDone)
    end)
end

function GC.AutoLoadWindow(window, slotName, onDone)
    if not window or not slotName then return false end
    if not hasFS() then return false end

    -- Defer a bit so the window is fully constructed
    task.delay(1.5, function()
        if not window.Gui or not window.Gui.Parent then return end
        attemptAutoload(window, slotName, 1, 8, onDone)
    end)
    return true
end

-- ============================================================
-- Hook CreateWindow — auto-load if enabled
-- ============================================================
local _origCreateWindow = LucidUI.CreateWindow
function LucidUI:CreateWindow(config)
    config = config or {}
    local W = _origCreateWindow(self, config)

    if config.PerGameConfigs then
        W._perGameConfigs = true
        ensurePaths()

        -- Auto-load the saved slot if one exists
        local slot = readAutoload()
        if slot then
            local ok, list = pcall(GC.List)
            if ok and list then
                for _, s in ipairs(list) do
                    if s == slot then
                        GC.AutoLoadWindow(W, slot, function(success, result)
                            if not success and config.Debug then
                                print("[LucidUI] Auto-load failed for slot: " .. slot)
                            end
                        end)
                        break
                    end
                end
            end
        end

        -- Also override SaveConfig/LoadConfig to use per-game paths
        local _origSave = W.SaveConfig
        local _origLoad = W.LoadConfig

        function W:SaveConfig(name)
            if self._perGameConfigs then
                local ok = GC.SaveWindow(self, name)
                if ok then
                    LucidUI:Notify({
                        Title = "Saved (per-game)",
                        Message = name,
                        Variant = "success",
                        Duration = 3,
                    })
                else
                    LucidUI:Notify({
                        Title = "Save Failed",
                        Message = "Could not write to disk",
                        Variant = "error",
                        Duration = 3,
                    })
                end
                return ok
            end
            return _origSave and _origSave(self, name)
        end

        function W:LoadConfig(name)
            if self._perGameConfigs then
                local ok = GC.LoadWindow(self, name)
                return ok
            end
            return _origLoad and _origLoad(self, name)
        end
    end

    return W
end

-- ============================================================
-- Optional: settings UI section
-- ============================================================
--[[
    If you want a settings UI for the autoload slot, call:

        LucidUI.GameConfigs.BuildSettingsSection(window)

    Which appends a section to the window's settings panel with:
      • Slot dropdown
      • Save / Load / Delete buttons
      • Autoload toggle
]]

function GC.BuildSettingsSection(window)
    if not window or not window._spContent then return end

    local function addSection(title)
        local label = Create("TextLabel", {
            Text = title:upper(),
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = window.Theme.TextMuted,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, 18),
            LayoutOrder = window._settingsOrder,
            Parent = window._spContent,
        })
        window._settingsOrder = window._settingsOrder + 1
        window:_registerTheme(function(t) label.TextColor3 = t.TextMuted end)
        return label
    end

    local function addFrame(frame)
        frame.LayoutOrder = window._settingsOrder
        window._settingsOrder = window._settingsOrder + 1
        frame.Parent = window._spContent
        return frame
    end

    addSection("Per-Game Configs")

    -- Slot dropdown
    local slotRow = Create("Frame", {
        BackgroundColor3 = window.Theme.Surface,
        BackgroundTransparency = window.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 40),
        ClipsDescendants = true,
    })
    Corner(10, slotRow)
    addFrame(slotRow)

    local slots = GC.List()
    if #slots == 0 then slots = { "(empty)" } end

    local currentSlot = slots[1]

    local headerBtn = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 40), Parent = slotRow,
    })
    Create("TextLabel", {
        Text = "Active Slot", Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = window.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -100, 1, 0),
        Parent = headerBtn,
    })
    local slotLbl = Create("TextLabel", {
        Text = currentSlot, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = window.Theme.Accent, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Size = UDim2.new(1, -34, 1, 0), Parent = headerBtn,
    })
    local arrowLbl = Create("TextLabel", {
        Text = "v", Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = window.Theme.TextMuted, BackgroundTransparency = 1,
        Position = UDim2.new(1, -24, 0, 0),
        Size = UDim2.fromOffset(20, 40), Parent = headerBtn,
    })

    local slotList = Create("Frame", {
        Size = UDim2.new(1, -20, 0, 0),
        Position = UDim2.fromOffset(10, 40),
        BackgroundTransparency = 1, ClipsDescendants = true, Parent = slotRow,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = slotList,
    })

    local expanded = false
    local slotButtons = {}

    local function rebuildSlots()
        for _, b in ipairs(slotButtons) do b:Destroy() end
        slotButtons = {}
        local list = GC.List()
        if #list == 0 then list = { "(empty)" } end
        for i, name in ipairs(list) do
            local opt = Create("TextButton", {
                Text = name, Font = Enum.Font.GothamMedium, TextSize = 13,
                TextColor3 = window.Theme.TextPrimary,
                BackgroundColor3 = window.Theme.Background,
                BackgroundTransparency = 0.5, AutoButtonColor = false,
                Size = UDim2.new(1, 0, 0, 32), LayoutOrder = i, Parent = slotList,
            })
            Corner(8, opt)
            local nm = name
            BindTap(opt, function()
                currentSlot = nm
                slotLbl.Text = nm
                expanded = false
                Tween(slotList, 0.22, { Size = UDim2.new(1, -20, 0, 0) }):Play()
                Tween(slotRow, 0.22, { Size = UDim2.new(1, 0, 0, 40) }):Play()
                Tween(arrowLbl, 0.2, { Rotation = 0 }):Play()
            end)
            table.insert(slotButtons, opt)
        end
    end

    BindTap(headerBtn, function()
        expanded = not expanded
        if expanded then rebuildSlots() end
        local h = expanded and (#slotButtons * 36 + 8) or 0
        Tween(slotList, 0.22, { Size = UDim2.new(1, -20, 0, h) }):Play()
        Tween(slotRow, 0.22, { Size = UDim2.new(1, 0, 0, expanded and (40 + h + 8) or 40) }):Play()
        Tween(arrowLbl, 0.2, { Rotation = expanded and 180 or 0 }):Play()
    end)

    -- Action row
    local actionRow = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
    })
    addFrame(actionRow)
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        Parent = actionRow,
    })

    local function mkBtn(text, color, cb)
        local b = Create("TextButton", {
            Text = text, Font = Enum.Font.GothamBold, TextSize = 12,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundColor3 = color,
            BackgroundTransparency = 0.2, AutoButtonColor = false,
            Size = UDim2.new(0.5, -3, 1, 0),
            Parent = actionRow,
        })
        Corner(8, b)
        BindTap(b, cb, { MoveThreshold = 8 })
        return b
    end

    mkBtn("Save", window.Theme.Accent, function()
        if currentSlot == "(empty)" then
            LucidUI:Notify({
                Title = "No Slot",
                Message = "Create a slot first",
                Variant = "warn",
                Duration = 3,
            })
            return
        end
        window:SaveConfig(currentSlot)
    end)

    mkBtn("Load", window.Theme.Surface, function()
        if currentSlot == "(empty)" then return end
        window:LoadConfig(currentSlot)
    end)

    -- New slot input
    local newRow = Create("Frame", {
        BackgroundColor3 = window.Theme.Surface,
        BackgroundTransparency = window.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 40),
    })
    Corner(10, newRow)
    addFrame(newRow)

    local inputBox = Create("TextBox", {
        Text = "",
        PlaceholderText = "new slot name...",
        PlaceholderColor3 = window.Theme.TextMuted,
        Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = window.Theme.TextPrimary,
        BackgroundColor3 = window.Theme.Background,
        BackgroundTransparency = 0.3, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -120, 0, 26),
        Position = UDim2.new(0, 14, 0.5, -13),
        Parent = newRow,
    })
    Corner(8, inputBox)
    Create("UIPadding", {
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = inputBox,
    })

    local createBtn = Create("TextButton", {
        Text = "Create",
        Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = window.Theme.Accent,
        BackgroundTransparency = 0.2, AutoButtonColor = false,
        Size = UDim2.fromOffset(90, 26),
        Position = UDim2.new(1, -104, 0.5, -13),
        Parent = newRow,
    })
    Corner(8, createBtn)
    BindTap(createBtn, function()
        local name = inputBox.Text
        if name == "" then return end
        GC.Write(name, { elements = {} }) -- create empty
        currentSlot = name
        slotLbl.Text = name
        inputBox.Text = ""
        rebuildSlots()
        LucidUI:Notify({
            Title = "Created",
            Message = name,
            Variant = "success",
            Duration = 3,
        })
    end, { MoveThreshold = 8 })

    -- Autoload row
    local autoRow = Create("Frame", {
        BackgroundColor3 = window.Theme.Surface,
        BackgroundTransparency = window.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 44),
    })
    Corner(10, autoRow)
    addFrame(autoRow)

    local autoLbl = Create("TextLabel", {
        Text = "Auto-load this slot on join",
        Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = window.Theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -80, 1, 0),
        Parent = autoRow,
    })

    local savedAuto = GC.GetAutoload()
    local isOn = (savedAuto == currentSlot)

    local track = Create("Frame", {
        Size = UDim2.fromOffset(44, 24),
        Position = UDim2.new(1, -58, 0.5, -12),
        BackgroundColor3 = isOn and window.Theme.Accent or window.Theme.ToggleOff,
        BorderSizePixel = 0, Parent = autoRow,
    })
    Corner(12, track)

    local knob = Create("Frame", {
        Size = UDim2.fromOffset(20, 20),
        Position = isOn and UDim2.new(1, -22, 0.5, -10) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0, Parent = track,
    })
    Corner(10, knob)

    local autoClick = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = autoRow,
    })

    BindTap(autoClick, function()
        isOn = not isOn
        if isOn then
            GC.SetAutoload(currentSlot)
        else
            GC.ClearAutoload()
        end
        local t = window.Theme
        Tween(track, 0.22, {
            BackgroundColor3 = isOn and t.Accent or t.ToggleOff,
        }, Enum.EasingStyle.Quart):Play()
        Tween(knob, 0.22, {
            Position = isOn and UDim2.new(1, -22, 0.5, -10) or UDim2.fromOffset(2, 2),
        }, Enum.EasingStyle.Quart):Play()
    end)

    window:_registerTheme(function(t)
        slotRow.BackgroundColor3 = t.Surface
        slotLbl.TextColor3 = t.Accent
        arrowLbl.TextColor3 = t.TextMuted
        newRow.BackgroundColor3 = t.Surface
        inputBox.BackgroundColor3 = t.Background
        inputBox.TextColor3 = t.TextPrimary
        createBtn.BackgroundColor3 = t.Accent
        autoRow.BackgroundColor3 = t.Surface
        autoLbl.TextColor3 = t.TextPrimary
        track.BackgroundColor3 = isOn and t.Accent or t.ToggleOff
    end)
end

-- ============================================================
-- Cleanup
-- ============================================================
LucidUI:OnCleanup(function()
    print("[LucidUI] PerGameConfigs cleaned up")
end)

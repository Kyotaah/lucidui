--[[
    Theme & Config Share Codes — export as a compact base64 string,
    import someone else's and apply it instantly.

    Theme format:
      LUCID-THEME:<base64 of JSON>
      JSON payload: { v = 1, bg, sf, sh, ac, bd, tx }

    Config format:
      LUCID-CONFIG:<base64 of JSON>
      JSON payload: { v = 1, theme, accent, elements = {...} }

    [IMPROVEMENT] Added Config Share Codes (not just themes). pcall
    wrapped clipboard ops. Added top-level Export/ImportConfig APIs.
]]

-- ============================================================
-- Pure-Lua base64
-- ============================================================
local B64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_MAP = {}
for i = 1, #B64_ALPHABET do
    B64_MAP[B64_ALPHABET:sub(i, i)] = i - 1
end

local function b64Encode(str)
    local out = {}
    local len = #str
    local i = 1
    while i <= len do
        local b1 = str:byte(i)
        local b2 = str:byte(i + 1)
        local b3 = str:byte(i + 2)

        local c1 = math.floor(b1 / 4)
        local c2 = (b1 % 4) * 16 + (b2 and math.floor(b2 / 16) or 0)
        local c3 = b2 and ((b2 % 16) * 4 + (b3 and math.floor(b3 / 64) or 0)) or nil
        local c4 = b3 and (b3 % 64) or nil

        out[#out + 1] = B64_ALPHABET:sub(c1 + 1, c1 + 1)
        out[#out + 1] = B64_ALPHABET:sub(c2 + 1, c2 + 1)
        out[#out + 1] = c3 and B64_ALPHABET:sub(c3 + 1, c3 + 1) or "="
        out[#out + 1] = c4 and B64_ALPHABET:sub(c4 + 1, c4 + 1) or "="

        i = i + 3
    end
    return table.concat(out)
end

local function b64Decode(str)
    str = str:gsub("[^%w%+/=]", "")

    local out = {}
    local len = #str
    local i = 1
    while i <= len do
        local c1 = B64_MAP[str:sub(i, i)]
        local c2 = B64_MAP[str:sub(i + 1, i + 1)]
        local c3 = B64_MAP[str:sub(i + 2, i + 2)]
        local c4 = B64_MAP[str:sub(i + 3, i + 3)]

        if not c1 or not c2 then break end

        local b1 = c1 * 4 + math.floor(c2 / 16)
        local b2 = c3 and ((c2 % 16) * 16 + math.floor(c3 / 4)) or nil
        local b3 = c4 and ((c3 % 4) * 64 + c4) or nil

        out[#out + 1] = string.char(b1)
        if b2 then out[#out + 1] = string.char(b2) end
        if b3 then out[#out + 1] = string.char(b3) end

        i = i + 4
    end
    return table.concat(out)
end

-- ============================================================
-- Prefixes + serialization helpers
-- ============================================================
local THEME_PREFIX  = "LUCID-THEME:"
local CONFIG_PREFIX = "LUCID-CONFIG:"

local function colorToTable(c)
    if typeof(c) ~= "Color3" then return nil end
    return {
        R = tonumber(string.format("%.4f", c.R)),
        G = tonumber(string.format("%.4f", c.G)),
        B = tonumber(string.format("%.4f", c.B)),
    }
end

local function tableToColor(t)
    if type(t) ~= "table" then return nil end
    if type(t.R) ~= "number" or type(t.G) ~= "number" or type(t.B) ~= "number" then
        return nil
    end
    return Color3.new(
        math.clamp(t.R, 0, 1),
        math.clamp(t.G, 0, 1),
        math.clamp(t.B, 0, 1)
    )
end

-- ============================================================
-- Clipboard helper
-- ============================================================
local function copyToClipboard(text)
    if type(setclipboard) == "function" then
        local ok = pcall(setclipboard, text)
        if ok then return true end
    end
    if syn and syn.setclipboard then
        local ok = pcall(syn.setclipboard, text)
        if ok then return true end
    end
    return false
end

-- ============================================================
-- Theme export / import
-- ============================================================
function LucidUI.Window:ExportThemeCode()
    self:_ensureCustomTheme()
    local ct = self._customTheme
    if not ct then return nil, "no custom theme" end

    local payload = {
        v  = 1,
        bg = colorToTable(ct.Background),
        sf = colorToTable(ct.Surface),
        sh = colorToTable(ct.SurfaceHover),
        ac = colorToTable(ct.Accent),
        bd = colorToTable(ct.Border),
        tx = colorToTable(ct.TextPrimary),
    }

    local json = Compat.encode(payload)
    if not json then return nil, "json encode failed" end

    return THEME_PREFIX .. b64Encode(json)
end

function LucidUI.Window:ImportThemeCode(code)
    if type(code) ~= "string" then return false, "not a string" end
    code = code:gsub("%s+", "")
    if code == "" then return false, "empty code" end

    if code:sub(1, #THEME_PREFIX) == THEME_PREFIX then
        code = code:sub(#THEME_PREFIX + 1)
    end

    local json = b64Decode(code)
    if not json or json == "" then return false, "invalid base64" end

    local data = Compat.decode(json)
    if type(data) ~= "table" then return false, "invalid json" end
    if data.v ~= 1 then return false, "unsupported version" end

    local bg = tableToColor(data.bg)
    local sf = tableToColor(data.sf)
    local sh = tableToColor(data.sh)
    local ac = tableToColor(data.ac)
    local bd = tableToColor(data.bd)
    local tx = tableToColor(data.tx)

    if not bg or not ac or not tx then
        return false, "missing required colors"
    end

    self._customTheme = {
        Background   = bg,
        Surface      = sf or bg,
        SurfaceHover = sh or sf or bg,
        Accent       = ac,
        Border       = bd or Color3.fromRGB(255, 255, 255),
        TextPrimary  = tx,
    }

    self:ApplyCustomTheme()
    if self._refreshSwatches then pcall(self._refreshSwatches) end

    LucidUI:Notify({
        Title = "Theme Imported",
        Message = "Applied as Custom.",
        Variant = "success",
    })
    return true
end

-- ============================================================
-- [IMPROVEMENT] Config export / import
-- ============================================================
function LucidUI.Window:ExportConfigCode()
    local payload = {
        v = 1,
        theme = self._customThemeActive and "Custom" or self.ThemeName,
        accent = self._accentOverride and {
            R = self._accentOverride.R,
            G = self._accentOverride.G,
            B = self._accentOverride.B,
        } or nil,
        windowSize = { self._width, self._height },
        elements = self._configData,
    }
    local json = Compat.encode(payload)
    if not json then return nil, "json encode failed" end
    return CONFIG_PREFIX .. b64Encode(json)
end

function LucidUI.Window:ImportConfigCode(code)
    if type(code) ~= "string" then return false, "not a string" end
    code = code:gsub("%s+", "")
    if code == "" then return false, "empty code" end

    if code:sub(1, #CONFIG_PREFIX) == CONFIG_PREFIX then
        code = code:sub(#CONFIG_PREFIX + 1)
    end

    local json = b64Decode(code)
    if not json or json == "" then return false, "invalid base64" end

    local data = Compat.decode(json)
    if type(data) ~= "table" then return false, "invalid json" end
    if data.v ~= 1 then return false, "unsupported version" end

    if data.theme and LucidUI.Themes[data.theme] then
        self:SetTheme(data.theme)
    end
    if data.accent then
        self:SetAccent(Color3.new(data.accent.R, data.accent.G, data.accent.B))
    end
    if data.windowSize then
        self._width  = math.clamp(data.windowSize[1], self._minWidth,  self._maxWidth)
        self._height = math.clamp(data.windowSize[2], self._minHeight, self._maxHeight)
        self._fullSize = UDim2.fromOffset(self._width, self._height)
        if not self.Minimized then self.Main.Size = self._fullSize end
    end

    local applied = 0
    if data.elements then
        for flag, value in pairs(data.elements) do
            local el = self._elementsByFlag[flag]
            if el and el.Set then
                pcall(function() el:Set(value) end)
                applied = applied + 1
            end
        end
    end

    LucidUI:Notify({
        Title = "Config Imported",
        Message = applied .. " element(s) applied.",
        Variant = "success",
    })
    return true
end

-- ============================================================
-- Settings section: Share Code
-- ============================================================
function LucidUI.Window:_buildThemeCodeSettings()
    self:_addSettingSection("Share Codes")

    -- ── Export row ─────────────────────────────────────────────
    local exportRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 40),
    })
    Corner(10, exportRow)
    self:_addSettingFrame(exportRow)

    Create("TextLabel", {
        Text = "Export Theme",
        Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -110, 1, 0),
        Parent = exportRow,
    })

    local exportBtn = Create("TextButton", {
        Text = "Copy Code",
        Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = self.Theme.Accent,
        BackgroundTransparency = 0.2, AutoButtonColor = false,
        Size = UDim2.fromOffset(90, 26),
        Position = UDim2.new(1, -104, 0.5, -13),
        Parent = exportRow,
    })
    Corner(8, exportBtn)

    BindTap(exportBtn, function()
        local code = self:ExportThemeCode()
        if not code then
            LucidUI:Notify({
                Title = "Export Failed",
                Message = "Could not encode theme.",
                Variant = "error",
            })
            return
        end
        if copyToClipboard(code) then
            LucidUI:Notify({
                Title = "Theme Code Copied",
                Message = "Paste it anywhere to share.",
                Duration = 4,
                Variant = "success",
            })
        else
            LucidUI:Notify({
                Title = "No Clipboard",
                Message = "Executor doesn't support setclipboard.",
                Variant = "error",
                Duration = 4,
            })
        end
    end, { MoveThreshold = 8 })

    -- ── Export config row ──────────────────────────────────────
    local exportCfgRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 40),
    })
    Corner(10, exportCfgRow)
    self:_addSettingFrame(exportCfgRow)

    Create("TextLabel", {
        Text = "Export Config",
        Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -110, 1, 0),
        Parent = exportCfgRow,
    })

    local exportCfgBtn = Create("TextButton", {
        Text = "Copy Code",
        Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = self.Theme.Accent,
        BackgroundTransparency = 0.2, AutoButtonColor = false,
        Size = UDim2.fromOffset(90, 26),
        Position = UDim2.new(1, -104, 0.5, -13),
        Parent = exportCfgRow,
    })
    Corner(8, exportCfgBtn)

    BindTap(exportCfgBtn, function()
        local code = self:ExportConfigCode()
        if not code then
            LucidUI:Notify({
                Title = "Export Failed",
                Message = "Could not encode config.",
                Variant = "error",
            })
            return
        end
        if copyToClipboard(code) then
            LucidUI:Notify({
                Title = "Config Code Copied",
                Message = "Share it to import the full setup.",
                Duration = 4,
                Variant = "success",
            })
        else
            LucidUI:Notify({
                Title = "No Clipboard",
                Message = "Executor doesn't support setclipboard.",
                Variant = "error",
                Duration = 4,
            })
        end
    end, { MoveThreshold = 8 })

    -- ── Import row ─────────────────────────────────────────────
    local importRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 40),
    })
    Corner(10, importRow)
    self:_addSettingFrame(importRow)

    local codeBox = Create("TextBox", {
        Text = "", PlaceholderText = "paste a code...",
        PlaceholderColor3 = self.Theme.TextMuted, Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = self.Theme.TextPrimary, BackgroundColor3 = self.Theme.Background,
        BackgroundTransparency = 0.3, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -160, 0, 26),
        Position = UDim2.new(0, 14, 0.5, -13),
        Parent = importRow,
    })
    Corner(8, codeBox)
    Create("UIPadding", {
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = codeBox,
    })

    local pasteBtn = Create("TextButton", {
        Text = "Paste",
        Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = self.Theme.TextPrimary,
        BackgroundColor3 = self.Theme.Background,
        BackgroundTransparency = 0.3, AutoButtonColor = false,
        Size = UDim2.fromOffset(56, 26),
        Position = UDim2.new(1, -118, 0.5, -13),
        Parent = importRow,
    })
    Corner(8, pasteBtn)

    local applyBtn = Create("TextButton", {
        Text = "Apply",
        Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = self.Theme.Accent,
        BackgroundTransparency = 0.2, AutoButtonColor = false,
        Size = UDim2.fromOffset(56, 26),
        Position = UDim2.new(1, -58, 0.5, -13),
        Parent = importRow,
    })
    Corner(8, applyBtn)

    BindTap(pasteBtn, function()
        if type(getclipboard) == "function" then
            local ok, text = pcall(getclipboard)
            if ok and text and text ~= "" then
                codeBox.Text = text
                PlayUISound("click")
            else
                LucidUI:Notify({
                    Title = "Empty",
                    Message = "Clipboard has nothing.",
                    Duration = 2,
                    Variant = "warn",
                })
            end
        else
            LucidUI:Notify({
                Title = "No Clipboard",
                Message = "Can't read the clipboard on this executor.",
                Variant = "error",
            })
        end
    end, { MoveThreshold = 8 })

    BindTap(applyBtn, function()
        local code = codeBox.Text
        if code == "" then
            LucidUI:Notify({
                Title = "Empty",
                Message = "Paste a code first.",
                Variant = "error",
                Duration = 3,
            })
            return
        end

        -- Auto-detect theme vs config by prefix
        local isConfig = code:sub(1, #CONFIG_PREFIX) == CONFIG_PREFIX
        local ok, err

        if isConfig then
            ok, err = self:ImportConfigCode(code)
        else
            ok, err = self:ImportThemeCode(code)
        end

        if not ok then
            LucidUI:Notify({
                Title = "Import Failed",
                Message = tostring(err or "unknown error"),
                Variant = "error",
                Duration = 4,
            })
        else
            codeBox.Text = ""
        end
    end, { MoveThreshold = 8 })

    -- ── Preview swatches ───────────────────────────────────────
    local previewRow = Create("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24),
    })
    self:_addSettingFrame(previewRow)

    local previewSwatches = {}
    local previewKeys = { "Background", "Surface", "Accent", "Border", "TextPrimary" }
    for i, key in ipairs(previewKeys) do
        local s = Create("Frame", {
            Size = UDim2.fromOffset(22, 22),
            Position = UDim2.fromOffset((i - 1) * 28, 1),
            BackgroundColor3 = self.Theme[key] or Color3.new(0.5, 0.5, 0.5),
            BorderSizePixel = 0, Parent = previewRow,
        })
        Corner(4, s)
        Stroke(self.Theme.Border, 1, 0.6, s)
        previewSwatches[key] = s
    end

    local hint = Create("TextLabel", {
        Text = "Shows the active theme's key colors",
        Font = Enum.Font.Gotham, TextSize = 10,
        TextColor3 = self.Theme.TextMuted, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(#previewKeys * 28 + 4, 0),
        Size = UDim2.new(1, -(#previewKeys * 28 + 8), 0, 24),
        Parent = previewRow,
    })

    -- ── Theme registration ─────────────────────────────────────
    self:_registerTheme(function(t)
        exportRow.BackgroundColor3 = t.Surface
        exportBtn.BackgroundColor3 = t.Accent
        exportCfgRow.BackgroundColor3 = t.Surface
        exportCfgBtn.BackgroundColor3 = t.Accent

        importRow.BackgroundColor3 = t.Surface
        codeBox.BackgroundColor3 = t.Background
        codeBox.TextColor3 = t.TextPrimary
        codeBox.PlaceholderColor3 = t.TextMuted
        pasteBtn.BackgroundColor3 = t.Background
        pasteBtn.TextColor3 = t.TextPrimary
        applyBtn.BackgroundColor3 = t.Accent

        for _, c in ipairs(exportRow:GetChildren()) do
            if c:IsA("TextLabel") then c.TextColor3 = t.TextPrimary end
        end
        for _, c in ipairs(exportCfgRow:GetChildren()) do
            if c:IsA("TextLabel") then c.TextColor3 = t.TextPrimary end
        end

        hint.TextColor3 = t.TextMuted

        for key, swatch in pairs(previewSwatches) do
            swatch.BackgroundColor3 = t[key] or Color3.new(0.5, 0.5, 0.5)
            for _, child in ipairs(swatch:GetChildren()) do
                if child:IsA("UIStroke") then child.Color = t.Border end
            end
        end
    end)
end

-- ============================================================
-- Hook into BuildSettingsPanel without touching 07_settings_b.lua
-- ============================================================
local _origBuildSettings = LucidUI.Window.BuildSettingsPanel
LucidUI.Window.BuildSettingsPanel = function(self, ...)
    _origBuildSettings(self, ...)
    if not self._themeCodeBuilt and self._settingsBuilt then
        self._themeCodeBuilt = true
        self:_buildThemeCodeSettings()
    end
end

-- ============================================================
-- [IMPROVEMENT] Top-level APIs
-- ============================================================
function LucidUI.ExportConfig(window)
    if not window or not window.ExportConfigCode then
        warn("[LucidUI] ExportConfig: invalid window")
        return nil
    end
    return window:ExportConfigCode()
end

function LucidUI.ImportConfig(window, code)
    if not window or not window.ImportConfigCode then
        warn("[LucidUI] ImportConfig: invalid window")
        return false
    end
    return window:ImportConfigCode(code)
end

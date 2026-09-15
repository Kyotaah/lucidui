--[[
    Settings B — background image, keybinds, configs, about,
    BuildSettingsPanel.

    Accent detection:
      AutoDetectAccent samples the image on a center-weighted grid,
      filters out transparent / near-black / near-white / desaturated
      pixels, buckets hues into 36 bins, smooths the histogram with a
      triangular kernel, picks the peak, and averages the actual pixels
      in the winning bin ± 1. Then it boosts saturation, clamps
      brightness, and runs a WCAG contrast pass against the current
      theme background — nudging the value channel up or down until
      the accent reaches a 3:1 ratio.

    Click handling:
      Every click goes through BindTap (from 01b_polish.lua). The
      image-transparency slider keeps InputBegan/InputChanged because
      drag IS its interaction model.

    Keybind capture:
      The pill-toggle keybind row uses a stateful listener. While
      capturing, LucidUI._keyListening is true so the window's global
      keybind handler ignores keystrokes.
]]

-- ============================================================
-- Contrast helpers (mirrors 07_settings_a.lua — the library keeps
-- these local to each file rather than threading them through the
-- module boundary)
-- ============================================================
local function relLuminance(c)
    local function lin(x)
        if x <= 0.03928 then return x / 12.92 end
        return ((x + 0.055) / 1.055) ^ 2.4
    end
    return 0.2126 * lin(c.R) + 0.7152 * lin(c.G) + 0.0722 * lin(c.B)
end

local function contrastRatio(c1, c2)
    local l1, l2 = relLuminance(c1), relLuminance(c2)
    if l1 < l2 then l1, l2 = l2, l1 end
    return (l1 + 0.05) / (l2 + 0.05)
end

function LucidUI.Window:_buildBackgroundSettings()
    self:_addSettingSection("Background Image")

    if self._bgTransparency == nil then self._bgTransparency = 0.10 end

    local urlRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 40),
    })
    Corner(10, urlRow)
    self:_addSettingFrame(urlRow)

    Create("TextLabel", {
        Text = "Image URL", Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -180, 1, 0), Parent = urlRow,
    })

    local urlBox = Create("TextBox", {
        Text = "", PlaceholderText = "asset id or https://...",
        PlaceholderColor3 = self.Theme.TextMuted, Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = self.Theme.TextPrimary, BackgroundColor3 = self.Theme.Background,
        BackgroundTransparency = 0.3, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.fromOffset(140, 26), Position = UDim2.new(1, -154, 0.5, -13), Parent = urlRow,
    })
    Corner(8, urlBox)
    Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = urlBox })

    local actionRow = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36) })
    self:_addSettingFrame(actionRow)
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = actionRow,
    })

    local function mkBtn(text, color, cb)
        local b = Create("TextButton", {
            Text = text, Font = Enum.Font.GothamBold, TextSize = 11,
            TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundColor3 = color,
            BackgroundTransparency = 0.2, AutoButtonColor = false,
            Size = UDim2.new(0.33, -4, 1, 0), Parent = actionRow,
        })
        Corner(8, b)
        BindTap(b, cb, { MoveThreshold = 8 })
        return b
    end

    mkBtn("Apply", self.Theme.Accent, function()
        local url = urlBox.Text
        if url == "" then return end
        self:SetBackgroundImage(url)
    end)

    mkBtn("Auto Accent", self.Theme.Surface, function()
        local url = urlBox.Text
        if url == "" then
            LucidUI:Notify({ Title = "No URL", Message = "Paste a URL first", Accent = Color3.fromRGB(255,80,80) })
            return
        end
        LucidUI:Notify({ Title = "Analyzing...", Message = "Sampling image pixels", Duration = 3 })
        task.spawn(function()
            local accent = self:AutoDetectAccent(url)
            if accent then
                self:SetAccent(accent)
                LucidUI:Notify({ Title = "Accent Detected",
                    Message = string.format("RGB(%d,%d,%d)",
                        math.floor(accent.R*255), math.floor(accent.G*255), math.floor(accent.B*255)) })
            else
                LucidUI:Notify({ Title = "Detection Failed", Message = "Check F9 for details", Accent = Color3.fromRGB(255,80,80) })
            end
        end)
    end)

    mkBtn("Clear", Color3.fromRGB(220, 60, 60), function()
        self:SetBackgroundImage(nil)
        urlBox.Text = ""
    end)

    local transRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 54),
    })
    Corner(10, transRow)
    self:_addSettingFrame(transRow)

    Create("TextLabel", {
        Text = "Image Transparency", Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 18), Parent = transRow,
    })

    local transValue = Create("TextLabel", {
        Text = string.format("%.2f", self._bgTransparency),
        Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = self.Theme.Accent, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 18), Parent = transRow,
    })

    local transTrack = Create("Frame", {
        Size = UDim2.new(1, -28, 0, 4), Position = UDim2.new(0, 14, 1, -16),
        BackgroundColor3 = self.Theme.SliderTrack, BorderSizePixel = 0, Parent = transRow,
    })
    Corner(2, transTrack)

    local transFill = Create("Frame", {
        Size = UDim2.new(self._bgTransparency, 0, 1, 0),
        BackgroundColor3 = self.Theme.Accent, BorderSizePixel = 0, Parent = transTrack,
    })
    Corner(2, transFill)

    local transHandle = Create("Frame", {
        Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(self._bgTransparency, 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, Parent = transTrack,
    })
    Corner(9, transHandle)

    local transDrag = Create("TextButton", {
        Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = transTrack,
    })

    local active = false
    local function setTrans(input)
        local rel = math.clamp((input.Position.X - transTrack.AbsolutePosition.X) / transTrack.AbsoluteSize.X, 0, 1)
        self._bgTransparency = rel
        transFill.Size = UDim2.new(rel, 0, 1, 0)
        transHandle.Position = UDim2.new(rel, 0, 0.5, 0)
        transValue.Text = string.format("%.2f", rel)
        if self._bgImage and self._bgImage.Visible then
            self._bgImage.ImageTransparency = rel
        end
    end
    transDrag.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            active = true
            setTrans(input)
        end
    end)
    table.insert(self._conns, UserInputService.InputChanged:Connect(function(input)
        if not active then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then setTrans(input) end
    end))
    table.insert(self._conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then active = false end
    end))

    local note = Create("TextLabel", {
        Text = "Accepts asset IDs (12345678), rbxassetid:// URLs, or https:// image links.\nDirect image links work best from i.imgur.com or similar hosts.",
        Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = self.Theme.TextMuted, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    })
    self:_addSettingFrame(note)

    self:_registerTheme(function(t)
        urlRow.BackgroundColor3 = t.Surface
        urlBox.BackgroundColor3 = t.Background
        urlBox.TextColor3 = t.TextPrimary
        transRow.BackgroundColor3 = t.Surface
        transValue.TextColor3 = t.Accent
        transTrack.BackgroundColor3 = t.SliderTrack
        transFill.BackgroundColor3 = t.Accent
        note.TextColor3 = t.TextMuted
    end)
end

function LucidUI.Window:SetBackgroundImage(url)
    if not self._bgImage then return end
    if not url or url == "" then
        Tween(self._bgImage, 0.2, { ImageTransparency = 1 }):Play()
        task.delay(0.25, function()
            if self._bgImage then self._bgImage.Visible = false end
            if self.Main then self.Main.BackgroundTransparency = self.Theme.BackgroundTrans end
        end)
        self._backgroundUrl = nil
        return
    end
    self._backgroundUrl = url
    if url:match("^https?://") then
        local ok = self:_downloadAndLoadImage(url)
        if not ok then
            LucidUI:Notify({ Title = "Download Failed", Message = "Check F9 for details", Accent = Color3.fromRGB(255,80,80) })
        end
        return
    end
    local imageId = url
    if not url:match("^rbxasset") then
        local num = url:match("(%d+)")
        if not num then
            LucidUI:Notify({ Title = "Invalid URL", Message = "Use asset ID or https link", Accent = Color3.fromRGB(255,80,80) })
            return
        end
        imageId = "rbxassetid://" .. num
    end
    self._bgImage.Image = imageId
    self._bgImage.Visible = true
    self._bgImage.ImageTransparency = 1
    Tween(self._bgImage, 0.4, { ImageTransparency = self._bgTransparency or 0.10 }):Play()
    Tween(self.Main, 0.4, { BackgroundTransparency = 0.65 }):Play()
end

function LucidUI.Window:_downloadAndLoadImage(url)
    print("[LucidUI] Downloading:", url)
    if not Compat.hasCustomAsset() then
        print("[LucidUI] FAIL: getcustomasset not available")
        return false
    end
    if not Compat.hasFS() then
        print("[LucidUI] FAIL: writefile not available")
        return false
    end
    local ext = url:match("%.(%w+)%?") or url:match("%.(%w+)$") or "png"
    ext = ext:lower()
    if ext ~= "png" and ext ~= "jpg" and ext ~= "jpeg" then ext = "png" end
    Compat.ensureFolders()
    local filename = "LucidUI/bg_" .. tostring(os.time()) .. "." .. ext
    local ok, data = pcall(function() return game:HttpGet(url, true) end)
    if not ok or not data or #data == 0 then
        print("[LucidUI] FAIL: HTTP download returned empty")
        return false
    end
    print("[LucidUI] Downloaded", #data, "bytes")
    if not Compat.write(filename, data) then
        print("[LucidUI] FAIL: writefile")
        return false
    end
    local assetOk, asset = pcall(getcustomasset, filename)
    if not assetOk or not asset then
        print("[LucidUI] FAIL: getcustomasset")
        return false
    end
    print("[LucidUI] Success")
    self._bgImage.Image = asset
    self._bgImage.Visible = true
    self._bgImage.ImageTransparency = 1
    Tween(self._bgImage, 0.4, { ImageTransparency = self._bgTransparency or 0.10 }):Play()
    Tween(self.Main, 0.4, { BackgroundTransparency = 0.65 }):Play()
    return true
end

-- ============================================================
-- Improved auto-accent: center-weighted hue analysis with
-- saturation-squared scoring and WCAG contrast enforcement.
--
-- Pipeline:
--   1. Resolve URL → EditableImage
--   2. Sample on a 60×60 grid
--   3. Per-pixel filter: alpha, brightness bounds, saturation floor
--   4. Score = saturation² × centerWeight
--   5. Hue histogram (36 bins) with triangular kernel over ±2
--   6. Peak bin → average actual pixels from peak ± 1 bins
--   7. HSV boost: saturation × 1.4, value clamped to [0.65, 0.92]
--   8. Contrast pass: nudge value until accent hits 3:1 against theme.Background
-- ============================================================
function LucidUI.Window:AutoDetectAccent(url, opts)
    opts = opts or {}

    local gridN       = opts.Grid          or 60
    local minSat      = opts.MinSat        or 0.18
    local minVal      = opts.MinVal        or 0.10
    local maxVal      = opts.MaxVal        or 0.95
    local minAlpha    = opts.MinAlpha      or 0.30
    local satBoost    = opts.SatBoost      or 1.4
    local valFloor    = opts.ValueFloor    or 0.65
    local valCeil     = opts.ValueCeil     or 0.92
    local targetRatio = opts.ContrastRatio or 3.0

    -- 1. Resolve to asset id
    local imageId = url
    if url:match("^https?://") then
        print("[LucidUI] AutoAccent: downloading image first")
        local ok = self:_downloadAndLoadImage(url)
        if not ok then
            print("[LucidUI] AutoAccent: download failed")
            return nil
        end
        imageId = self._bgImage.Image
    elseif not imageId:match("^rbxasset") then
        local num = imageId:match("(%d+)")
        if num then imageId = "rbxassetid://" .. num end
    end

    local AssetService = game:GetService("AssetService")
    if not AssetService or not AssetService.CreateEditableImageAsync then
        print("[LucidUI] AutoAccent: CreateEditableImageAsync unavailable")
        return nil
    end

    local ok, img = pcall(function()
        return AssetService:CreateEditableImageAsync(imageId)
    end)
    if not ok or not img then
        print("[LucidUI] AutoAccent: CreateEditableImageAsync threw")
        return nil
    end

    -- 2. Wait for size
    local size
    for _ = 1, 60 do
        local ok2, s = pcall(function() return img.Size end)
        if ok2 and s and s.X > 2 and s.Y > 2 then
            size = s
            break
        end
        task.wait(0.05)
    end
    if not size then
        print("[LucidUI] AutoAccent: image never loaded")
        return nil
    end
    print("[LucidUI] AutoAccent: image", size.X .. "x" .. size.Y)

    -- 3. Sample
    local cx, cy = size.X / 2, size.Y / 2
    local maxDist = math.sqrt(cx * cx + cy * cy)
    local stepX = math.max(1, math.floor(size.X / gridN))
    local stepY = math.max(1, math.floor(size.Y / gridN))

    local samples = {}
    for y = 0, size.Y - 1, stepY do
        for x = 0, size.X - 1, stepX do
            local ok3, pixels = pcall(function()
                return img:ReadPixels(Vector2.new(x, y), Vector2.new(1, 1))
            end)
            if ok3 and pixels and #pixels >= 3 then
                local r, g, b = pixels[1], pixels[2], pixels[3]
                local a = (#pixels >= 4) and pixels[4] or 1

                if a >= minAlpha then
                    local c = Color3.new(r, g, b)
                    local h, s, v = Color3.toHSV(c)

                    if v > minVal and v < maxVal and s > minSat then
                        -- Center weight: 1.0 at center, 0.35 at edges.
                        local dx, dy = x - cx, y - cy
                        local dist = math.sqrt(dx * dx + dy * dy)
                        local centerWeight = 1.0 - (dist / maxDist) * 0.65

                        table.insert(samples, {
                            r = r, g = g, b = b,
                            h = h, s = s, v = v,
                            weight = (s * s) * centerWeight,
                        })
                    end
                end
            end
        end
    end

    if #samples == 0 then
        print("[LucidUI] AutoAccent: no valid saturated pixels")
        return nil
    end
    print("[LucidUI] AutoAccent: samples =", #samples)

    -- 4. Hue histogram with triangular kernel
    local BINS = 36
    local bins = {}
    for i = 1, BINS do bins[i] = { weight = 0, rSum = 0, gSum = 0, bSum = 0 } end

    for _, s in ipairs(samples) do
        local bin = math.floor(s.h * BINS) + 1
        if bin < 1 then bin = 1 end
        if bin > BINS then bin = BINS end
        bins[bin].weight = bins[bin].weight + s.weight
        bins[bin].rSum   = bins[bin].rSum + s.r * s.weight
        bins[bin].gSum   = bins[bin].gSum + s.g * s.weight
        bins[bin].bSum   = bins[bin].bSum + s.b * s.weight
    end

    -- Triangular smoothing over ±2 bins, wrapping around the hue wheel
    local smoothed = {}
    for i = 1, BINS do
        local w0 = bins[i].weight
        local wl1 = bins[((i - 2) % BINS) + 1].weight
        local wr1 = bins[(i % BINS) + 1].weight
        local wl2 = bins[((i - 3) % BINS) + 1].weight
        local wr2 = bins[((i + 1) % BINS) + 1].weight
        smoothed[i] = w0 + (wl1 + wr1) * 0.6 + (wl2 + wr2) * 0.25
    end

    local bestBin, bestScore = 1, -1
    for i = 1, BINS do
        if smoothed[i] > bestScore then
            bestScore = smoothed[i]
            bestBin = i
        end
    end

    -- 5. Representative color: average the raw samples in peak ± 1 bins
    local lo = ((bestBin - 2) % BINS) + 1
    local mi = bestBin
    local hi = (bestBin % BINS) + 1
    local accR, accG, accB, accW = 0, 0, 0, 0
    for _, s in ipairs(samples) do
        local bin = math.floor(s.h * BINS) + 1
        if bin < 1 then bin = 1 end
        if bin > BINS then bin = BINS end
        if bin == lo or bin == mi or bin == hi then
            accR = accR + s.r * s.weight
            accG = accG + s.g * s.weight
            accB = accB + s.b * s.weight
            accW = accW + s.weight
        end
    end
    if accW == 0 then
        print("[LucidUI] AutoAccent: peak neighbourhood empty")
        return nil
    end
    local avg = Color3.new(accR / accW, accG / accW, accB / accW)

    -- 6. HSV boost
    local h, s, v = Color3.toHSV(avg)
    s = math.min(s * satBoost, 1)
    v = math.clamp(v, valFloor, valCeil)
    local result = Color3.fromHSV(h, s, v)

    -- 7. Contrast pass against the current theme background
    local bg = (self.Theme and self.Theme.Background) or Color3.fromRGB(28, 28, 30)
    local ratio = contrastRatio(result, bg)
    print(string.format("[LucidUI] AutoAccent: pre-contrast ratio %.2f", ratio))

    local guard = 0
    while ratio < targetRatio and guard < 12 do
        guard = guard + 1
        local hh, ss, vv = Color3.toHSV(result)
        local bgLum = relLuminance(bg)

        -- Decide direction: darken against light backgrounds,
        -- lighten against dark ones.
        if bgLum > 0.45 then
            vv = vv - 0.06
        else
            vv = vv + 0.06
        end
        vv = math.clamp(vv, 0.15, 0.98)
        result = Color3.fromHSV(hh, ss, vv)
        ratio = contrastRatio(result, bg)

        -- If we've hit the value bounds and still failing, kill
        -- saturation and switch to pure white or black.
        if vv <= 0.15 or vv >= 0.98 then
            if bgLum > 0.45 then
                result = Color3.fromRGB(20, 20, 24)
            else
                result = Color3.fromRGB(240, 240, 245)
            end
            break
        end
    end

    local finalH, finalS, finalV = Color3.toHSV(result)
    print(string.format(
        "[LucidUI] AutoAccent: rgb(%d,%d,%d) hsv(%.2f,%.2f,%.2f) contrast %.2f",
        math.floor(result.R * 255), math.floor(result.G * 255), math.floor(result.B * 255),
        finalH, finalS, finalV, ratio
    ))

    return result
end

-- ============================================================
-- Keybinds — global hotkeys that work on desktop
-- ============================================================
function LucidUI.Window:_buildKeybindSettings()
    self:_addSettingSection("Keybinds")

    local row = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 44),
    })
    Corner(10, row)
    self:_addSettingFrame(row)

    Create("TextLabel", {
        Text = "Minimize to Pill",
        Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -120, 1, 0),
        Parent = row,
    })

    local keyBox = Create("TextButton", {
        Text = self.PillKeybind and self.PillKeybind.Name or "Home",
        Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = self.Theme.TextPrimary,
        BackgroundColor3 = self.Theme.Background,
        BackgroundTransparency = 0.3,
        AutoButtonColor = false,
        Size = UDim2.fromOffset(90, 26),
        Position = UDim2.new(1, -104, 0.5, -13),
        Parent = row,
    })
    Corner(8, keyBox)

    local listenConn = nil

    local function stopListening()
        if listenConn then listenConn:Disconnect() listenConn = nil end
        keyBox.Text = self.PillKeybind and self.PillKeybind.Name or "Home"
        keyBox.BackgroundColor3 = self.Theme.Background
        LucidUI._keyListening = false
        self._cancelKeybindListen = nil
    end

    self._cancelKeybindListen = stopListening

    local function startListening()
        if LucidUI._keyListening then return end
        LucidUI._keyListening = true
        keyBox.Text = "..."
        keyBox.BackgroundColor3 = self.Theme.Accent
        PlayUISound("click")

        listenConn = UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if input.KeyCode == Enum.KeyCode.Escape then
                stopListening()
                return
            end
            self.PillKeybind = input.KeyCode
            self._configData["pill_keybind"] = input.KeyCode.Name
            stopListening()
            LucidUI:Notify({
                Title = "Keybind Set",
                Message = "Pill toggle: " .. input.KeyCode.Name,
            })
        end)
    end

    BindTap(keyBox, startListening)

    table.insert(self._conns, UserInputService.InputBegan:Connect(function(input, processed)
        if not LucidUI._keyListening then return end
        if listenConn == nil then return end
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            if not processed then stopListening() end
        end
    end))

    self:_registerTheme(function(t)
        row.BackgroundColor3 = t.Surface
        if not LucidUI._keyListening then
            keyBox.BackgroundColor3 = t.Background
            keyBox.TextColor3 = t.TextPrimary
        end
    end)
end

-- ============================================================
-- Config slots
-- ============================================================
function LucidUI.Window:_buildConfigSettings()
    self:_addSettingSection("Configs")

    local row = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 40),
        ClipsDescendants = true,
    })
    Corner(10, row)
    self:_addSettingFrame(row)

    local headerBtn = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 40), Parent = row,
    })
    Create("TextLabel", {
        Text = "Active Config", Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -100, 1, 0), Parent = headerBtn,
    })
    local slotLabel = Create("TextLabel", {
        Text = self._currentConfig, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = self.Theme.Accent, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Size = UDim2.new(1, -34, 1, 0), Parent = headerBtn,
    })
    local arrowLbl = Create("TextLabel", {
        Text = "v", Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = self.Theme.TextMuted, BackgroundTransparency = 1,
        Position = UDim2.new(1, -24, 0, 0), Size = UDim2.fromOffset(20, 40), Parent = headerBtn,
    })

    local list = Create("Frame", {
        Size = UDim2.new(1, -20, 0, 0), Position = UDim2.fromOffset(10, 40),
        BackgroundTransparency = 1, ClipsDescendants = true, Parent = row,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list,
    })

    local expanded = false
    local slotButtons = {}

    local function rebuildSlots()
        for _, b in ipairs(slotButtons) do b:Destroy() end
        slotButtons = {}
        local slots = Compat.listConfigs()
        for i, name in ipairs(slots) do
            local isDefault = (name == "default")
            local label = isDefault and (name .. "  (locked)") or name
            local opt = Create("TextButton", {
                Text = label, Font = Enum.Font.GothamMedium, TextSize = 13,
                TextColor3 = self.Theme.TextPrimary, BackgroundColor3 = self.Theme.Background,
                BackgroundTransparency = 0.5, AutoButtonColor = false,
                Size = UDim2.new(1, 0, 0, 32), LayoutOrder = i, Parent = list,
            })
            Corner(8, opt)
            local configName = name
            BindTap(opt, function()
                self._currentConfig = configName
                slotLabel.Text = configName
                expanded = false
                Tween(list, 0.22, { Size = UDim2.new(1, -20, 0, 0) }):Play()
                Tween(row, 0.22, { Size = UDim2.new(1, 0, 0, 40) }):Play()
                Tween(arrowLbl, 0.2, { Rotation = 0 }):Play()
                self:LoadConfig(configName)
            end)
            table.insert(slotButtons, opt)
        end
    end

    BindTap(headerBtn, function()
        expanded = not expanded
        local h = 0
        if expanded then rebuildSlots(); h = #slotButtons * 36 + 8 end
        Tween(list, 0.22, { Size = UDim2.new(1, -20, 0, expanded and h or 0) }, Enum.EasingStyle.Quart):Play()
        Tween(row, 0.22, { Size = UDim2.new(1, 0, 0, expanded and (40 + h + 8) or 40) }, Enum.EasingStyle.Quart):Play()
        Tween(arrowLbl, 0.2, { Rotation = expanded and 180 or 0 }):Play()
    end)

    self._themeSlotsRefresh = rebuildSlots

    local newRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 40),
    })
    Corner(10, newRow)
    self:_addSettingFrame(newRow)
    local inputBox = Create("TextBox", {
        Text = "", PlaceholderText = "new config name...",
        PlaceholderColor3 = self.Theme.TextMuted, Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = self.Theme.TextPrimary, BackgroundColor3 = self.Theme.Background,
        BackgroundTransparency = 0.3, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -110, 0, 26), Position = UDim2.new(0, 14, 0.5, -13), Parent = newRow,
    })
    Corner(8, inputBox)
    Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = inputBox })
    local saveNewBtn = Create("TextButton", {
        Text = "Save As New", Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundColor3 = self.Theme.Accent,
        BackgroundTransparency = 0.2, AutoButtonColor = false,
        Size = UDim2.fromOffset(90, 26), Position = UDim2.new(1, -104, 0.5, -13), Parent = newRow,
    })
    Corner(8, saveNewBtn)
    BindTap(saveNewBtn, function()
        local name = inputBox.Text
        if name == "" or name == "default" then
            LucidUI:Notify({ Title = "Invalid Name", Message = "Pick another name", Accent = Color3.fromRGB(255,80,80) })
            return
        end
        self:SaveConfig(name)
        inputBox.Text = ""
        rebuildSlots()
    end, { MoveThreshold = 8 })

    local actionRow = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36) })
    self:_addSettingFrame(actionRow)
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = actionRow,
    })

    local function mkBtn(label, color, cb)
        local b = Create("TextButton", {
            Text = label, Font = Enum.Font.GothamBold, TextSize = 12,
            TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundColor3 = color,
            BackgroundTransparency = 0.2, AutoButtonColor = false,
            Size = UDim2.new(0.33, -4, 1, 0), Parent = actionRow,
        })
        Corner(8, b)
        BindTap(b, cb, { MoveThreshold = 8 })
        return b
    end

    mkBtn("Save", self.Theme.Accent, function()
        self:SaveConfig(self._currentConfig)
        rebuildSlots()
    end)
    mkBtn("Load", self.Theme.Surface, function()
        self:LoadConfig(self._currentConfig)
    end)
    mkBtn("Delete", Color3.fromRGB(220, 60, 60), function()
        if self._currentConfig == "default" then
            LucidUI:Notify({ Title = "Cannot Delete", Message = "Default is locked", Accent = Color3.fromRGB(255,80,80) })
            return
        end
        Compat.delete("LucidUI/Configs/" .. self._currentConfig .. ".json")
        self._currentConfig = "default"
        slotLabel.Text = "default"
        rebuildSlots()
    end)

    self:_registerTheme(function(t)
        row.BackgroundColor3 = t.Surface
        slotLabel.TextColor3 = t.Accent
        arrowLbl.TextColor3 = t.TextMuted
        newRow.BackgroundColor3 = t.Surface
        inputBox.BackgroundColor3 = t.Background
        inputBox.TextColor3 = t.TextPrimary
        saveNewBtn.BackgroundColor3 = t.Accent
        for _, b in ipairs(slotButtons) do
            b.BackgroundColor3 = t.Background
            b.TextColor3 = t.TextPrimary
        end
    end)
end

function LucidUI.Window:_buildAboutSettings()
    self:_addSettingSection("About")
    local row = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    Corner(10, row)
    self:_addSettingFrame(row)
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = row,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row,
    })
    local lbl = Create("TextLabel", {
        Text = "LucidUI v" .. LucidUI._version .. "\nA modern, glass-morphism UI for Roblox.",
        Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = row,
    })
    self:_registerTheme(function(t)
        row.BackgroundColor3 = t.Surface
        lbl.TextColor3 = t.TextPrimary
    end)
end

function LucidUI.Window:BuildSettingsPanel()
    if self._settingsBuilt then return end
    self._settingsBuilt = true
    self:_buildThemeSettings()
    self:_buildCustomThemeSettings()
    self:_buildSavedThemesSettings()
    self:_buildBackgroundSettings()
    self:_buildKeybindSettings()
    self:_buildConfigSettings()
    self:_buildAboutSettings()
end

function LucidUI.Window:SaveConfig(profileName)
    profileName = profileName or "default"
    local data = {
        theme = self._customThemeActive and "Custom" or self.ThemeName,
        accent = self._accentOverride and {
            R = self._accentOverride.R, G = self._accentOverride.G, B = self._accentOverride.B
        } or nil,
        windowSize = { self._width, self._height },
        customTheme = self._customTheme and Compat.serializeColors(self._customTheme) or nil,
        backgroundUrl = self._backgroundUrl,
        bgTransparency = self._bgTransparency,
        pillKeybind = self.PillKeybind and self.PillKeybind.Name or nil,
        elements = self._configData,
    }
    local encoded = Compat.encode(data)
    if not encoded then return end
    Compat.ensureFolders()
    local ok = Compat.write("LucidUI/Configs/" .. profileName .. ".json", encoded)
    if ok then
        LucidUI:Notify({ Title = "Config Saved", Message = profileName })
    else
        LucidUI:Notify({ Title = "Save Failed", Message = "No file system", Accent = Color3.fromRGB(255,80,80) })
    end
end

function LucidUI.Window:LoadConfig(profileName)
    profileName = profileName or "default"
    local contents = Compat.read("LucidUI/Configs/" .. profileName .. ".json")
    if not contents then
        LucidUI:Notify({ Title = "Load Failed", Message = "Not found: " .. profileName, Accent = Color3.fromRGB(255,80,80) })
        return
    end
    local data = Compat.decode(contents)
    if not data then return end
    if data.theme then
        if data.theme == "Custom" and data.customTheme then
            local restored = Compat.deserializeColors(data.customTheme)
            if restored then
                local d = LucidUI.Themes.Default
                self._customTheme = {
                    Background   = restored.Background   or d.Background,
                    Surface      = restored.Surface      or d.Surface,
                    SurfaceHover = restored.SurfaceHover or d.SurfaceHover,
                    Accent       = restored.Accent       or d.Accent,
                    Border       = restored.Border       or d.Border,
                    TextPrimary  = restored.TextPrimary  or d.TextPrimary,
                }
                self:ApplyCustomTheme()
            end
        elseif LucidUI.Themes[data.theme] then
            self:SetTheme(data.theme)
        end
    end
    if data.accent then
        self:SetAccent(Color3.new(data.accent.R, data.accent.G, data.accent.B))
    end
    if data.windowSize then
        self._width  = math.clamp(data.windowSize[1], self._minWidth,  self._maxWidth)
        self._height = math.clamp(data.windowSize[2], self._minHeight, self._maxHeight)
        self._fullSize = UDim2.fromOffset(self._width, self._height)
        self._collapsedSize = UDim2.fromOffset(self._width, 44)
        if not self.Minimized then self.Main.Size = self._fullSize end
    end
    if data.bgTransparency then self._bgTransparency = data.bgTransparency end
    if data.backgroundUrl then self:SetBackgroundImage(data.backgroundUrl) end
    if data.pillKeybind then
        local key = Enum.KeyCode[data.pillKeybind]
        if key then self.PillKeybind = key end
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
    LucidUI:Notify({ Title = "Config Loaded", Message = profileName .. " (" .. applied .. ")" })
end

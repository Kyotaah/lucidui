-- ============================================================
-- Module: 08m_favorites.lua
-- ============================================================
--[[
    Favorites — a star button in the window header that opens a
    quick-access panel of toggleable features.

    [NEW] Long-press a favorite row to open an inline rebind popup.

    [FIX] The star button reference is now stored on the window as
    W._favoriteStarBtn so SetMinimized can hide it during pill mode.
]]

local UserInputService = game:GetService("UserInputService")

local FAVORITES = {}
local ORDER     = {}

LucidUI._favorites     = FAVORITES
LucidUI._favoriteConns = LucidUI._favoriteConns or {}

local SAVE_PATH = "LucidUI/Favorites.json"

local function loadSaved()
    if not Compat or not Compat.read then return { states = {}, keys = {} } end
    local raw = Compat.read(SAVE_PATH)
    if not raw then return { states = {}, keys = {} } end
    local data = Compat.decode(raw)
    if type(data) ~= "table" then return { states = {}, keys = {} } end
    return {
        states = data.states or {},
        keys   = data.keys   or {},
    }
end

local function persist()
    if not Compat or not Compat.write then return end
    local states, keys = {}, {}
    for id, fav in pairs(FAVORITES) do
        states[id] = fav.State and true or false
        if fav.Hotkey then keys[id] = fav.Hotkey.Name end
    end
    local encoded = Compat.encode({ v = 1, states = states, keys = keys })
    if encoded then
        Compat.write(SAVE_PATH, encoded)
    end
end

local saved = loadSaved()

local Favorite = {}
Favorite.__index = Favorite

function Favorite:Get()        return self.State end
function Favorite:GetName()    return self.Name end
function Favorite:GetHotkey()  return self.Hotkey end

function Favorite:Set(newState, silent)
    newState = newState and true or false
    if newState == self.State then return end
    self.State = newState
    persist()
    if self._onChanged then
        self._onChanged(self, newState, silent == true)
    end
end

function Favorite:Toggle(silent)
    self:Set(not self.State, silent)
end

function Favorite:SetHotkey(kc)
    self.Hotkey = kc
    persist()
    for _, win in ipairs(LucidUI._windows or {}) do
        if win._favoritePanelRefresh then
            pcall(win._favoritePanelRefresh)
        end
    end
end

function Favorite:Destroy()
    FAVORITES[self.Id] = nil
    for i, id in ipairs(ORDER) do
        if id == self.Id then table.remove(ORDER, i) break end
    end
    persist()
    for _, win in ipairs(LucidUI._windows or {}) do
        if win._favoritePanelRefresh then
            pcall(win._favoritePanelRefresh)
        end
    end
end

function LucidUI:RegisterFavorite(opts)
    opts = opts or {}
    local id = opts.Id
    if type(id) ~= "string" or id == "" then
        warn("[LucidUI] RegisterFavorite: opts.Id is required")
        return nil
    end
    if FAVORITES[id] then return FAVORITES[id] end

    local fav = setmetatable({}, Favorite)
    fav.Id       = id
    fav.Name     = opts.Name or id
    fav.Category = opts.Category or "General"
    fav.OnChange = opts.OnChange

    local savedName = saved.keys[id]
    if type(savedName) == "string" and savedName ~= "" then
        local ok, kc = pcall(function() return Enum.KeyCode[savedName] end)
        if ok and kc then fav.Hotkey = kc end
    end
    if not fav.Hotkey then
        fav.Hotkey = opts.Hotkey
    end

    if saved.states[id] ~= nil then
        fav.State = saved.states[id] and true or false
    else
        fav.State = opts.Default and true or false
    end

    fav._onChanged = function(self, newState, silent)
        if self.OnChange then
            pcall(self.OnChange, newState)
        end
        for _, win in ipairs(LucidUI._windows or {}) do
            if win._favoritePanelRefresh then
                pcall(win._favoritePanelRefresh)
            end
        end
    end

    FAVORITES[id] = fav
    table.insert(ORDER, id)

    for _, win in ipairs(LucidUI._windows or {}) do
        if win._favoritePanelRefresh then
            pcall(win._favoritePanelRefresh)
        end
    end

    return fav
end

function LucidUI:GetFavorite(id)  return FAVORITES[id] end
function LucidUI:GetFavoriteState(id)
    local f = FAVORITES[id]
    return f and f.State or false
end

function LucidUI:GetAllFavorites()
    local out = {}
    for _, id in ipairs(ORDER) do
        local fav = FAVORITES[id]
        if fav then table.insert(out, fav) end
    end
    return out
end

function LucidUI:ClearAllFavorites()
    for _, fav in pairs(FAVORITES) do
        fav.State = false
        if fav.OnChange then pcall(fav.OnChange, false) end
    end
    persist()
    for _, win in ipairs(LucidUI._windows or {}) do
        if win._favoritePanelRefresh then
            pcall(win._favoritePanelRefresh)
        end
    end
end

table.insert(LucidUI._favoriteConns,
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if not LucidUI._hotkeysEnabled then return end

        for _, id in ipairs(ORDER) do
            local fav = FAVORITES[id]
            if fav and fav.Hotkey and fav.Hotkey == input.KeyCode then
                fav:Toggle()
            end
        end
    end))

local _origCreateWindow = LucidUI.CreateWindow
function LucidUI:CreateWindow(config)
    local W = _origCreateWindow(self, config)
    if not W or not W.Header then return W end

    local starBtn = Create("TextButton", {
        Name = "FavoritesStar",
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(36, 36),
        Position = UDim2.new(1, -160, 0.5, -18),
        ZIndex = 3,
        Parent = W.Header,
    })

    -- [FIX] Expose reference so SetMinimized can hide/show it
    W._favoriteStarBtn = starBtn

    local starGlow = Create("Frame", {
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = W.Theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = starBtn,
    })
    Corner(999, starGlow)

    local starGlyph = Create("TextLabel", {
        Text = "★",
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        TextColor3 = W.Theme.TextMuted,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 4,
        Parent = starBtn,
    })

    if LucidUI._AttachTooltip then
        LucidUI._AttachTooltip(starBtn, "Favorites — quick access toggles", { Position = "bottom" })
    end

    local panel = Create("Frame", {
        Name = "FavoritesPanel",
        Size = UDim2.fromOffset(250, 80),
        Position = UDim2.new(1, -12, 0, 50),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = W.Theme.Background,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 30,
        Parent = W.Main,
    })
    Corner(12, panel)
    local panelStroke = Stroke(W.Theme.Border, 1, 0.35, panel)

    local panelHeader = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        ZIndex = 31,
        Parent = panel,
    })

    Create("TextLabel", {
        Text = "Quick Access",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = W.Theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -120, 1, 0),
        ZIndex = 32,
        Parent = panelHeader,
    })

    Create("TextLabel", {
        Text = "hold to rebind",
        Font = Enum.Font.Gotham,
        TextSize = 9,
        TextColor3 = W.Theme.TextMuted,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(1, -76, 0, 0),
        Size = UDim2.fromOffset(64, 32),
        ZIndex = 32,
        Parent = panelHeader,
    })

    Create("Frame", {
        Size = UDim2.new(1, -16, 0, 1),
        Position = UDim2.new(0, 8, 1, -1),
        BackgroundColor3 = W.Theme.Border,
        BackgroundTransparency = (W.Theme.BorderTrans or 0.75) + 0.05,
        BorderSizePixel = 0,
        ZIndex = 32,
        Parent = panelHeader,
    })

    local list = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.fromOffset(0, 36),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 31,
        Parent = panel,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = list,
    })
    Create("UIPadding", {
        PaddingLeft   = UDim.new(0, 6),
        PaddingRight  = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 8),
        Parent = list,
    })

    local rebindPopup = Create("Frame", {
        Name = "RebindPopup",
        Size = UDim2.fromOffset(220, 130),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = W.Theme.Background,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 60,
        Parent = W.Gui,
    })
    Corner(14, rebindPopup)
    local rebindStroke = Stroke(W.Theme.Accent, 1.5, 0.4, rebindPopup)

    Create("TextLabel", {
        Text = "Rebind Hotkey",
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = W.Theme.TextPrimary,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 24),
        Position = UDim2.fromOffset(0, 12),
        ZIndex = 61,
        Parent = rebindPopup,
    })

    local rebindName = Create("TextLabel", {
        Text = "",
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = W.Theme.TextMuted,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 16),
        Position = UDim2.fromOffset(10, 34),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 61,
        Parent = rebindPopup,
    })

    local rebindKeyBox = Create("TextButton", {
        Text = "",
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = W.Theme.TextPrimary,
        BackgroundColor3 = W.Theme.Surface,
        BackgroundTransparency = 0.3,
        AutoButtonColor = false,
        Size = UDim2.fromOffset(140, 34),
        Position = UDim2.new(0.5, -70, 0, 56),
        ZIndex = 62,
        Parent = rebindPopup,
    })
    Corner(8, rebindKeyBox)

    Create("TextLabel", {
        Text = "Escape to cancel · Del to unbind",
        Font = Enum.Font.Gotham,
        TextSize = 9,
        TextColor3 = W.Theme.TextMuted,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 14),
        Position = UDim2.new(0, 10, 1, -20),
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 61,
        Parent = rebindPopup,
    })

    local rebindTarget = nil
    local rebindListening = false
    local rebindConn = nil

    local function closeRebind()
        rebindListening = false
        rebindTarget = nil
        if rebindConn then
            pcall(function() rebindConn:Disconnect() end)
            rebindConn = nil
        end
        Tween(rebindPopup, 0.15, { BackgroundTransparency = 1 }):Play()
        Tween(rebindStroke, 0.15, { Transparency = 1 }):Play()
        task.delay(0.16, function() rebindPopup.Visible = false end)
    end

    local function openRebind(fav)
        rebindTarget = fav
        rebindName.Text = fav.Name
        rebindKeyBox.Text = fav.Hotkey and fav.Hotkey.Name or "None"
        rebindKeyBox.BackgroundColor3 = W.Theme.Surface
        rebindKeyBox.TextColor3 = W.Theme.TextPrimary
        rebindListening = false

        local scrW = W.Gui.AbsoluteSize.X
        local scrH = W.Gui.AbsoluteSize.Y
        local panelPos = panel.AbsolutePosition
        local panelSize = panel.AbsoluteSize

        local px = panelPos.X + panelSize.X / 2
        local py = panelPos.Y - 80
        px = math.clamp(px, 130, scrW - 130)
        py = math.clamp(py, 90, scrH - 90)

        rebindPopup.Position = UDim2.fromOffset(px, py)
        rebindPopup.Visible = true
        rebindPopup.BackgroundTransparency = 1
        rebindStroke.Transparency = 1
        Tween(rebindPopup, 0.2, { BackgroundTransparency = 0.05 }):Play()
        Tween(rebindStroke, 0.2, { Transparency = 0.4 }):Play()
    end

    local function startListening()
        if not rebindTarget or rebindListening then return end
        rebindListening = true
        rebindKeyBox.Text = "press key…"
        rebindKeyBox.BackgroundColor3 = W.Theme.Accent
        rebindKeyBox.TextColor3 = Color3.fromRGB(255, 255, 255)

        if rebindConn then
            pcall(function() rebindConn:Disconnect() end)
        end

        rebindConn = UserInputService.InputBegan:Connect(function(input, processed)
            if not rebindListening then return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

            if input.KeyCode == Enum.KeyCode.Escape then
                closeRebind()
                return
            end

            if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
                if rebindTarget then rebindTarget:SetHotkey(nil) end
                closeRebind()
                return
            end

            if rebindTarget then
                rebindTarget:SetHotkey(input.KeyCode)
            end
            closeRebind()
        end)
    end

    BindTap(rebindKeyBox, startListening, { MoveThreshold = 8 })

    rebindKeyBox.MouseEnter:Connect(function()
        if not rebindListening then
            Tween(rebindKeyBox, 0.12, { BackgroundTransparency = 0.1 }):Play()
        end
    end)
    rebindKeyBox.MouseLeave:Connect(function()
        if not rebindListening then
            Tween(rebindKeyBox, 0.12, { BackgroundTransparency = 0.3 }):Play()
        end
    end)

    table.insert(W._conns, UserInputService.InputBegan:Connect(function(input)
        if not rebindPopup.Visible then return end
        if rebindListening then return end

        if input.KeyCode == Enum.KeyCode.Escape then
            closeRebind()
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            local pos = Vector2.new(input.Position.X, input.Position.Y)
            local ap = rebindPopup.AbsolutePosition
            local sz = rebindPopup.AbsoluteSize
            local inside = pos.X >= ap.X and pos.X <= ap.X + sz.X
                       and pos.Y >= ap.Y and pos.Y <= ap.Y + sz.Y
            if not inside then closeRebind() end
        end
    end))

    local panelOpen = false

    local function refreshStarVisual()
        local activeCount = 0
        for _, fav in pairs(FAVORITES) do
            if fav.State then activeCount = activeCount + 1 end
        end

        if panelOpen then
            starGlyph.TextColor3 = W.Theme.Accent
            starGlow.BackgroundTransparency = 0.7
        elseif activeCount > 0 then
            starGlyph.TextColor3 = W.Theme.Accent
            starGlow.BackgroundTransparency = 0.85
        else
            starGlyph.TextColor3 = W.Theme.TextMuted
            starGlow.BackgroundTransparency = 1
        end
    end

    local function closePanel()
        if not panelOpen then return end
        panelOpen = false
        Tween(panel, 0.15, { BackgroundTransparency = 1 }):Play()
        Tween(panelStroke, 0.15, { Transparency = 1 }):Play()
        task.delay(0.16, function()
            if not panelOpen then panel.Visible = false end
        end)
        closeRebind()
        refreshStarVisual()
    end

    local function openPanel()
        if panelOpen then return end
        panelOpen = true
        W._favoritePanelRefresh()
        panel.Visible = true
        panel.BackgroundTransparency = 1
        panelStroke.Transparency = 1
        Tween(panel, 0.18, { BackgroundTransparency = 0.1 }):Play()
        Tween(panelStroke, 0.18, { Transparency = 0.35 }):Play()
        refreshStarVisual()
    end

    local function rebuildPanel()
        for _, c in ipairs(list:GetChildren()) do
            if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
                c:Destroy()
            end
        end

        local favorites = LucidUI:GetAllFavorites()

        if #favorites == 0 then
            Create("TextLabel", {
                Text = "No favorites yet.\nLucidUI:RegisterFavorite({...})",
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextColor3 = W.Theme.TextMuted,
                BackgroundTransparency = 1,
                TextWrapped = true,
                Size = UDim2.new(1, 0, 0, 44),
                LayoutOrder = 1,
                ZIndex = 32,
                Parent = list,
            })
            panel.Size = UDim2.fromOffset(250, 36 + 48)
            return
        end

        local order = 0
        local function nextOrder() order = order + 1 return order end

        for _, fav in ipairs(favorites) do
            local row = Create("Frame", {
                BackgroundColor3 = W.Theme.Surface,
                BackgroundTransparency = 0.35,
                Size = UDim2.new(1, 0, 0, 34),
                LayoutOrder = nextOrder(),
                ZIndex = 32,
                Parent = list,
            })
            Corner(8, row)

            local label = Create("TextLabel", {
                Text = fav.Name,
                Font = Enum.Font.GothamMedium,
                TextSize = 12,
                TextColor3 = fav.State and W.Theme.TextPrimary or W.Theme.TextSecondary,
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Position = UDim2.fromOffset(10, 0),
                Size = UDim2.new(1, -110, 1, 0),
                ZIndex = 33,
                Parent = row,
            })

            local chip = Create("TextButton", {
                Text = fav.Hotkey and fav.Hotkey.Name or "–",
                Font = Enum.Font.GothamBold,
                TextSize = 9,
                TextColor3 = fav.Hotkey and W.Theme.TextPrimary or W.Theme.TextMuted,
                BackgroundColor3 = W.Theme.Background,
                BackgroundTransparency = 0.5,
                AutoButtonColor = false,
                TextXAlignment = Enum.TextXAlignment.Center,
                Position = UDim2.new(1, -76, 0.5, -7),
                Size = UDim2.fromOffset(28, 14),
                ZIndex = 34,
                Parent = row,
            })
            Corner(4, chip)

            chip.MouseEnter:Connect(function()
                Tween(chip, 0.12, { BackgroundTransparency = 0.2 }):Play()
            end)
            chip.MouseLeave:Connect(function()
                Tween(chip, 0.12, { BackgroundTransparency = 0.5 }):Play()
            end)

            local track = Create("Frame", {
                Size = UDim2.fromOffset(34, 18),
                Position = UDim2.new(1, -42, 0.5, -9),
                BackgroundColor3 = fav.State and W.Theme.Accent or W.Theme.ToggleOff,
                BorderSizePixel = 0,
                ZIndex = 33,
                Parent = row,
            })
            Corner(9, track)

            local knob = Create("Frame", {
                Size = UDim2.fromOffset(14, 14),
                Position = fav.State and UDim2.new(1, -16, 0.5, -7) or UDim2.fromOffset(2, 2),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                ZIndex = 34,
                Parent = track,
            })
            Corner(7, knob)

            local function applyStateVisual(newState)
                Tween(track, 0.18, {
                    BackgroundColor3 = newState and W.Theme.Accent or W.Theme.ToggleOff,
                }, Enum.EasingStyle.Quart):Play()
                Tween(knob, 0.18, {
                    Position = newState and UDim2.new(1, -16, 0.5, -7)
                                     or UDim2.fromOffset(2, 2),
                }, Enum.EasingStyle.Quart):Play()
                label.TextColor3 = newState and W.Theme.TextPrimary or W.Theme.TextSecondary
            end

            local clickArea = Create("TextButton", {
                Text = "",
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(0, 0),
                Size = UDim2.new(1, -60, 1, 0),
                ZIndex = 33,
                Parent = row,
            })

            BindTap(clickArea, function()
                fav:Toggle()
                applyStateVisual(fav.State)
                refreshStarVisual()
                PlayUISound("click")
            end, { MoveThreshold = 6 })

            clickArea.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                    and input.UserInputType ~= Enum.UserInputType.Touch then return end

                local moved = false
                local startPos = input.Position

                local moveConn, endConn
                moveConn = UserInputService.InputChanged:Connect(function(changed)
                    if changed ~= input then return end
                    if (changed.Position - startPos).Magnitude > 8 then
                        moved = true
                    end
                end)
                endConn = UserInputService.InputEnded:Connect(function(ended)
                    if ended ~= input then return end
                    if moveConn then moveConn:Disconnect() end
                    if endConn then endConn:Disconnect() end
                end)

                task.delay(0.45, function()
                    if moved then return end
                    if rebindPopup.Visible then return end
                    openRebind(fav)
                end)
            end)

            BindTap(chip, function()
                openRebind(fav)
            end, { MoveThreshold = 6 })

            clickArea.MouseEnter:Connect(function()
                Tween(row, 0.12, { BackgroundTransparency = 0.15 }):Play()
            end)
            clickArea.MouseLeave:Connect(function()
                Tween(row, 0.12, { BackgroundTransparency = 0.35 }):Play()
            end)
        end

        local rowH = 34
        local gap = 2
        local contentH = #favorites * (rowH + gap) + 36 + 8
        panel.Size = UDim2.fromOffset(250, contentH)
    end

    W._favoritePanelRefresh = function()
        pcall(rebuildPanel)
        refreshStarVisual()
    end

    BindTap(starBtn, function()
        if panelOpen then closePanel() else openPanel() end
    end, { MoveThreshold = 8 })

    starBtn.MouseEnter:Connect(function()
        if not panelOpen then
            Tween(starGlyph, 0.12, { TextColor3 = W.Theme.Accent }):Play()
        end
    end)
    starBtn.MouseLeave:Connect(function()
        refreshStarVisual()
    end)

    local function isInside(gui, pos)
        if not gui or not gui.Parent then return false end
        local ap = gui.AbsolutePosition
        local sz = gui.AbsoluteSize
        return pos.X >= ap.X and pos.X <= ap.X + sz.X
           and pos.Y >= ap.Y and pos.Y <= ap.Y + sz.Y
    end

    table.insert(W._conns, UserInputService.InputBegan:Connect(function(input)
        if not panelOpen then return end
        if rebindPopup.Visible then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end

        local pos = Vector2.new(input.Position.X, input.Position.Y)

        if isInside(panel, pos) then return end
        if isInside(starBtn, pos) then return end
        if isInside(rebindPopup, pos) then return end

        closePanel()
    end))

    table.insert(W._conns, UserInputService.InputBegan:Connect(function(input)
        if not panelOpen then return end
        if rebindPopup.Visible then return end
        if input.KeyCode == Enum.KeyCode.Escape then
            closePanel()
        end
    end))

    W:_registerTheme(function(t)
        starGlow.BackgroundColor3 = t.Accent
        panel.BackgroundColor3   = t.Background
        panelStroke.Color        = t.Border
        rebindPopup.BackgroundColor3 = t.Background
        rebindStroke.Color       = t.Accent
        refreshStarVisual()
        if panelOpen then
            W._favoritePanelRefresh()
        end
    end)

    rebuildPanel()
    refreshStarVisual()

    return W
end

LucidUI:OnCleanup(function()
    for _, conn in ipairs(LucidUI._favoriteConns or {}) do
        pcall(function() conn:Disconnect() end)
    end
    LucidUI._favoriteConns = {}
    print("[LucidUI] Favorites cleaned up")
end)

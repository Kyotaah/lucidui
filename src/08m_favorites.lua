-- ============================================================
-- Module: 08m_favorites.lua
-- ============================================================
--[[
    Favorites — a star button in the window header that opens a
    quick-access panel of toggleable features.

    Each favorite tracks its own boolean state, persists to disk,
    and optionally has a keyboard shortcut. Toggling from the panel
    or the keyboard keeps them in sync and fires OnChange.

    USAGE
        LucidUI:RegisterFavorite({
            Id       = "aim",
            Name     = "Aim Assist",
            Category = "Combat",
            Default  = false,
            Hotkey   = Enum.KeyCode.R,    -- optional
            OnChange = function(state)
                AimEnabled = state
            end,
        })

    Star button sits in the header, just left of the settings gear.
    Click it to open/close the panel. Escape closes it too.

    API
        LucidUI:RegisterFavorite(opts)  -> favorite object or nil
        LucidUI:GetFavorite(id)         -> favorite object or nil
        LucidUI:GetAllFavorites()       -> { fav, ... }
        LucidUI:ClearAllFavorites()     -> set every favorite off

    Favorite object:
        .Id  .Name  .Category  .State  .Hotkey
        :Get()  :Set(v)  :Toggle()
        :GetHotkey()  :SetHotkey(kc)
        :Destroy()
]]

local UserInputService = game:GetService("UserInputService")

-- ============================================================
-- Registry
-- ============================================================
local FAVORITES = {}
local ORDER     = {}

LucidUI._favorites     = FAVORITES
LucidUI._favoriteConns = LucidUI._favoriteConns or {}

-- ============================================================
-- Persistence
-- ============================================================
local SAVE_PATH = "LucidUI/Favorites.json"

local function loadSaved()
    if not Compat or not Compat.read then return {} end
    local raw = Compat.read(SAVE_PATH)
    if not raw then return {} end
    local data = Compat.decode(raw)
    if type(data) ~= "table" then return {} end
    return data.states or {}
end

local function persistStates()
    if not Compat or not Compat.write then return end
    local states = {}
    for id, fav in pairs(FAVORITES) do
        states[id] = fav.State and true or false
    end
    local encoded = Compat.encode({ v = 1, states = states })
    if encoded then
        Compat.write(SAVE_PATH, encoded)
    end
end

local savedStates = loadSaved()

-- ============================================================
-- Favorite object
-- ============================================================
local Favorite = {}
Favorite.__index = Favorite

function Favorite:Get()             return self.State end
function Favorite:GetName()         return self.Name end
function Favorite:GetHotkey()       return self.Hotkey end

function Favorite:Set(newState, silent)
    newState = newState and true or false
    if newState == self.State then return end
    self.State = newState
    persistStates()
    if self._onChanged then
        self._onChanged(self, newState, silent == true)
    end
end

function Favorite:Toggle(silent)
    self:Set(not self.State, silent)
end

function Favorite:SetHotkey(kc)
    self.Hotkey = kc
    if self._onChanged then self._onChanged(self, self.State, true) end
end

function Favorite:Destroy()
    FAVORITES[self.Id] = nil
    for i, id in ipairs(ORDER) do
        if id == self.Id then table.remove(ORDER, i) break end
    end
    for _, win in ipairs(LucidUI._windows or {}) do
        if win._favoritePanelRefresh then
            pcall(win._favoritePanelRefresh)
        end
    end
end

-- ============================================================
-- Public registration
-- ============================================================
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
    fav.Hotkey   = opts.Hotkey
    fav.OnChange = opts.OnChange

    if savedStates[id] ~= nil then
        fav.State = savedStates[id] and true or false
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

    -- If a window already exists, refresh its panel
    for _, win in ipairs(LucidUI._windows or {}) do
        if win._favoritePanelRefresh then
            pcall(win._favoritePanelRefresh)
        end
    end

    return fav
end

function LucidUI:GetFavorite(id)       return FAVORITES[id] end
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
        if fav.OnChange then
            pcall(fav.OnChange, false)
        end
    end
    persistStates()
    for _, win in ipairs(LucidUI._windows or {}) do
        if win._favoritePanelRefresh then
            pcall(win._favoritePanelRefresh)
        end
    end
end

-- ============================================================
-- Global hotkey dispatch for favorites
-- ============================================================
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

-- ============================================================
-- Header star + dropdown panel
-- ============================================================
local _origCreateWindow = LucidUI.CreateWindow
function LucidUI:CreateWindow(config)
    local W = _origCreateWindow(self, config)
    if not W or not W.Header then return W end

    -- ── Star button (left of the settings gear) ────────
    local starBtn = Create("TextButton", {
        Name = "FavoritesStar",
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(36, 36),
        Position = UDim2.new(1, -160, 0.5, -18),
        ZIndex = 3,
        Parent = W.Header,
    })

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

    -- ── Dropdown panel ────────────────────────────────
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
        Size = UDim2.new(1, -40, 1, 0),
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

    -- ── Panel open/close ──────────────────────────────
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

    -- ── Panel rebuild ─────────────────────────────────
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

            -- Hotkey chip (only if bound)
            if fav.Hotkey then
                local chip = Create("TextLabel", {
                    Text = fav.Hotkey.Name,
                    Font = Enum.Font.GothamBold,
                    TextSize = 9,
                    TextColor3 = W.Theme.TextMuted,
                    BackgroundColor3 = W.Theme.Background,
                    BackgroundTransparency = 0.5,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    Position = UDim2.new(1, -76, 0.5, -7),
                    Size = UDim2.fromOffset(24, 14),
                    ZIndex = 33,
                    Parent = row,
                })
                Corner(4, chip)
            end

            -- Toggle switch
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

            local clickArea = Create("TextButton", {
                Text = "",
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                ZIndex = 35,
                Parent = row,
            })

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

            BindTap(clickArea, function()
                fav:Toggle()
                applyStateVisual(fav.State)
                refreshStarVisual()
                PlayUISound("click")
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

    -- ── Star click toggles panel ──────────────────────
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

    -- ── Outside click → close ─────────────────────────
    local function isInside(gui, pos)
        if not gui or not gui.Parent then return false end
        local ap = gui.AbsolutePosition
        local sz = gui.AbsoluteSize
        return pos.X >= ap.X and pos.X <= ap.X + sz.X
           and pos.Y >= ap.Y and pos.Y <= ap.Y + sz.Y
    end

    table.insert(W._conns, UserInputService.InputBegan:Connect(function(input)
        if not panelOpen then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end

        local pos = Vector2.new(input.Position.X, input.Position.Y)

        if isInside(panel, pos) then return end
        if isInside(starBtn, pos) then return end

        closePanel()
    end))

    -- ── Escape closes panel ───────────────────────────
    table.insert(W._conns, UserInputService.InputBegan:Connect(function(input)
        if not panelOpen then return end
        if input.KeyCode == Enum.KeyCode.Escape then
            closePanel()
        end
    end))

    -- ── Theme integration ────────────────────────────
    W:_registerTheme(function(t)
        starGlow.BackgroundColor3 = t.Accent
        panel.BackgroundColor3   = t.Background
        panelStroke.Color        = t.Border
        refreshStarVisual()
        if panelOpen then
            W._favoritePanelRefresh()
        end
    end)

    -- ── Initial state ─────────────────────────────────
    rebuildPanel()
    refreshStarVisual()

    return W
end

-- ============================================================
-- Cleanup
-- ============================================================
LucidUI:OnCleanup(function()
    for _, conn in ipairs(LucidUI._favoriteConns or {}) do
        pcall(function() conn:Disconnect() end)
    end
    LucidUI._favoriteConns = {}
    print("[LucidUI] Favorites cleaned up")
end)

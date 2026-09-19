-- ============================================================
-- Module: 08i_credit.lua
-- ============================================================
--[[
    Credit — two opt-in tools for hub authors:

      LucidUI:MainCredit(opts)   Registers an auto-built "Main" tab
                                 that becomes the first visible tab
                                 on every new window. Perfect for
                                 Discord links, donation buttons,
                                 and script-sharing pages.

      LucidUI:ShowCredit(opts)   Shows a one-time popup with your
                                 branding, anti-scam warning, and
                                 a call-to-action button. You decide
                                 when to call it — nothing fires
                                 automatically.

    Design notes:
      • Both are OFF by default. Nothing renders unless you call
        MainCredit() or ShowCredit().
      • No clipboard writes ever.
      • No auto-firing — ShowCredit only shows when you call it.
      • No HTTP. No external URLs beyond what you provide.
      • Opt-in per window via CreateWindow({ ShowCreditTab = false }).

    Usage:
        local LucidUI = loadstring(...)()
        LucidUI:MainCredit({
            Discord     = "discord.gg/yourinvite",
            Links = {
                { Name = "ScriptBlox", URL = "https://scriptblox.com/u/you" },
            },
        })

        -- Later, if you want a popup once at startup:
        task.delay(3, function()
            LucidUI:ShowCredit({
                Title    = "My Hub",
                Subtitle = "100% free — always",
                OnClose  = function() print("Dismissed") end,
            })
        end)
]]

-- ============================================================
-- Config storage
-- ============================================================
LucidUI._mainCreditOpts    = nil
LucidUI._creditTabConsumed = false

-- ============================================================
-- MainCredit — register opt-in Main tab
-- ============================================================
--[[
    opts = {
        TabName  = "Main",
        TabIcon  = "home",
        Discord  = "discord.gg/...",
        PayPal   = "paypal.me/...",
        Solana   = "wallet address",
        Links    = {
            { Name = "ScriptBlox", URL = "https://..." },
            { Name = "YouTube",    URL = "https://..." },
        },
        Warning  = "Custom anti-scam text (optional)",
        Free     = true,      -- show "100% free" banner (default true)
    }
]]

function LucidUI:MainCredit(opts)
    if type(opts) ~= "table" then opts = {} end
    self._mainCreditOpts    = opts
    self._creditTabConsumed = false
end

-- ============================================================
-- Build the Main tab content
-- ============================================================
local function buildMainTab(tab, opts)
    local theme = tab.Window.Theme

    -- ── Anti-scam banner ──────────────────────────────────
    if opts.Free ~= false then
        tab:CreateSection("Notice")

        local banner = tab:CreateBanner({
            Variant = "warn",
            Title   = "100% FREE & KEYLESS — ALWAYS",
            Text    = opts.Warning or
                "Asked for a key? You got scammed. Every feature here is "
                .. "free and open. No offerwalls, no Linkvertise, no keys.",
        })
    end

    -- ── Community section ─────────────────────────────────
    if opts.Discord and opts.Discord ~= "" then
        tab:CreateSection("Community")

        tab:CreateParagraph({
            Text = "Join the Discord for updates, new scripts, and support.",
        })

        -- Copy-to-clipboard is NOT automatic — only fires if the user
        -- explicitly clicks the button.
        tab:CreateButton({
            Name = "Copy Discord Invite  (" .. opts.Discord .. ")",
            Callback = function()
                local url = opts.Discord
                if not url:match("^https?://") then
                    url = "https://" .. url
                end
                local ok = false
                if type(setclipboard) == "function" then
                    ok = pcall(setclipboard, url)
                end
                if ok then
                    LucidUI:Notify({
                        Title = "Copied",
                        Message = "Discord invite copied to clipboard",
                        Variant = "success",
                        Duration = 3,
                    })
                else
                    LucidUI:Notify({
                        Title = "Clipboard Unavailable",
                        Message = "Your executor doesn't support setclipboard.",
                        Variant = "warn",
                        Duration = 4,
                    })
                end
            end,
        })
    end

    -- ── Support section ──────────────────────────────────
    if opts.PayPal or opts.Solana then
        tab:CreateSection("Support")

        tab:CreateParagraph({
            Text = "This script is free and always will be. If you want to say thanks, "
                .. "a coffee goes a long way.",
        })

        if opts.PayPal then
            tab:CreateButton({
                Name = "Copy PayPal Link  (" .. opts.PayPal .. ")",
                Callback = function()
                    local url = opts.PayPal
                    if not url:match("^https?://") then
                        url = "https://" .. url
                    end
                    local ok = false
                    if type(setclipboard) == "function" then
                        ok = pcall(setclipboard, url)
                    end
                    if ok then
                        LucidUI:Notify({
                            Title = "Thanks!",
                            Message = "PayPal link copied",
                            Variant = "success",
                            Duration = 3,
                        })
                    end
                end,
            })
        end

        if opts.Solana then
            tab:CreateButton({
                Name = "Copy Solana Address  (" .. opts.Solana:sub(1, 10) .. "...)",
                Callback = function()
                    local ok = false
                    if type(setclipboard) == "function" then
                        ok = pcall(setclipboard, opts.Solana)
                    end
                    if ok then
                        LucidUI:Notify({
                            Title = "Thanks!",
                            Message = "Solana address copied",
                            Variant = "success",
                            Duration = 3,
                        })
                    end
                end,
            })
        end
    end

    -- ── Links section ─────────────────────────────────────
    if opts.Links and #opts.Links > 0 then
        tab:CreateSection("Links")

        tab:CreateParagraph({
            Text = "Find all my scripts and updates on these platforms.",
        })

        for _, link in ipairs(opts.Links) do
            local name = link.Name or "Link"
            local url  = link.URL  or ""
            tab:CreateButton({
                Name = "Copy " .. name .. " Link",
                Callback = function()
                    local ok = false
                    if type(setclipboard) == "function" then
                        ok = pcall(setclipboard, url)
                    end
                    if ok then
                        LucidUI:Notify({
                            Title = name .. " Copied",
                            Message = "Link copied to clipboard",
                            Variant = "success",
                            Duration = 3,
                        })
                    end
                end,
            })
        end
    end

    -- ── Info footer ───────────────────────────────────────
    tab:CreateSection("Info")

    tab:CreateParagraph({
        Text = "LucidUI v" .. (LucidUI._version or "?")
            .. " — a modern, glass-morphism interface for Roblox.",
        Muted = true,
        TextSize = 11,
    })
end

-- ============================================================
-- Hook CreateWindow — build the Main tab as the first tab
-- ============================================================
local _origCreateWindow = LucidUI.CreateWindow
function LucidUI:CreateWindow(config)
    local W = _origCreateWindow(self, config)

    -- Only build once per window, and only if MainCredit() was called
    if self._mainCreditOpts and not self._creditTabConsumed then
        -- Per-window opt-out
        if config.ShowCreditTab ~= false then
            local opts = self._mainCreditOpts
            local icon = opts.TabIcon
            if icon == nil then icon = "home" end

            local ok, tab = pcall(function()
                return W:CreateTab({
                    Name = opts.TabName or "Main",
                    Icon = icon,
                })
            end)

            if ok and tab then
                pcall(buildMainTab, tab, opts)
            end
        end

        -- Only consume once so multiple windows don't all get it
        -- (unless the user re-calls MainCredit between them).
        self._creditTabConsumed = true
    end

    return W
end

-- ============================================================
-- ShowCredit — one-shot popup
-- ============================================================
--[[
    opts = {
        Title         = "My Hub",
        Subtitle      = "Made by You",
        Body          = "Optional custom message",
        WarningText   = "Asked for a key? You got scammed.",
        FreeBadge     = true,
        Discord       = "discord.gg/...",
        ButtonLabel   = "Copy Discord",
        ButtonAction  = function() end,   -- overrides Discord copy
        CloseLabel    = "Got it",
        OnClose       = function() end,
        Dismissible   = true,             -- allow click-outside to close
        Duration      = nil,              -- auto-close after N seconds (nil = manual)
    }
]]

function LucidUI:ShowCredit(opts)
    opts = opts or {}
    if self._creditShown and not opts.Force then
        return false -- only one per session unless Force = true
    end
    self._creditShown = true

    local theme = LucidUI._lastTheme or LucidUI.Themes.Default

    -- Root GUI
    local gui = Create("ScreenGui", {
        Name = "LucidUI_CreditPopup",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = opts.DisplayOrder or 9999,
        Parent = PlayerGui,
    })

    -- Backdrop
    local backdrop = Create("TextButton", {
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = gui,
    })

    -- Card
    local card = Create("Frame", {
        Size = UDim2.fromOffset(opts.Width or 420, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(0.5, 0, 0.5, -100),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = gui,
    })
    Corner(18, card)

    local cardStroke = Stroke(theme.Accent, 1.5, 1, card)

    local cardScale = Instance.new("UIScale")
    cardScale.Scale = 0.85
    cardScale.Parent = card

    -- Content list
    local content = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 4,
        Parent = card,
    })

    Create("UIPadding", {
        PaddingTop    = UDim.new(0, 22),
        PaddingBottom = UDim.new(0, 18),
        PaddingLeft   = UDim.new(0, 22),
        PaddingRight  = UDim.new(0, 22),
        Parent = content,
    })

    Create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = content,
    })

    -- ── Free badge ────────────────────────────────────────
    if opts.FreeBadge ~= false then
        local badgeRow = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = theme.Accent,
            BackgroundTransparency = 0.82,
            BorderSizePixel = 0,
            LayoutOrder = 1,
            ZIndex = 5,
            Parent = content,
        })
        Corner(8, badgeRow)
        Stroke(theme.Accent, 1, 0.5, badgeRow)

        Create("TextLabel", {
            Text = "✓  100% FREE & KEYLESS",
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = theme.Accent,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Center,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 6,
            Parent = badgeRow,
        })
    end

    -- ── Title ─────────────────────────────────────────────
    local titleLbl = Create("TextLabel", {
        Text = opts.Title or "LucidUI",
        Font = Enum.Font.GothamBlack,
        TextSize = 22,
        TextColor3 = theme.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Center,
        Size = UDim2.new(1, 0, 0, 30),
        LayoutOrder = 2,
        ZIndex = 5,
        Parent = content,
    })

    -- ── Subtitle ──────────────────────────────────────────
    if opts.Subtitle then
        Create("TextLabel", {
            Text = opts.Subtitle,
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextColor3 = theme.TextSecondary,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Center,
            Size = UDim2.new(1, 0, 0, 18),
            LayoutOrder = 3,
            ZIndex = 5,
            Parent = content,
        })
    end

    -- ── Anti-scam warning ─────────────────────────────────
    if opts.WarningText ~= false then
        Create("TextLabel", {
            Text = opts.WarningText or "Asked for a key? You got scammed.",
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = Color3.fromRGB(255, 130, 130),
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextWrapped = true,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 4,
            ZIndex = 5,
            Parent = content,
        })
    end

    -- ── Body ──────────────────────────────────────────────
    if opts.Body then
        Create("TextLabel", {
            Text = opts.Body,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = theme.TextMuted,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextWrapped = true,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 5,
            ZIndex = 5,
            Parent = content,
        })
    end

    -- ── Primary action button ─────────────────────────────
    if opts.Discord or opts.ButtonAction then
        local actionBtn = Create("TextButton", {
            Text = opts.ButtonLabel or "Copy Discord Invite",
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundColor3 = theme.Accent,
            BackgroundTransparency = 0.15,
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, 38),
            LayoutOrder = 6,
            ZIndex = 5,
            Parent = content,
        })
        Corner(8, actionBtn)

        actionBtn.MouseEnter:Connect(function()
            Tween(actionBtn, 0.15, { BackgroundTransparency = 0 }):Play()
        end)
        actionBtn.MouseLeave:Connect(function()
            Tween(actionBtn, 0.15, { BackgroundTransparency = 0.15 }):Play()
        end)

        BindTap(actionBtn, function()
            if opts.ButtonAction then
                Compat.safeCallback(opts.ButtonAction)
            elseif opts.Discord then
                local url = opts.Discord
                if not url:match("^https?://") then url = "https://" .. url end
                local ok = false
                if type(setclipboard) == "function" then
                    ok = pcall(setclipboard, url)
                end
                if ok then
                    actionBtn.Text = "✓ Copied!"
                    task.delay(2, function()
                        if actionBtn.Parent then
                            actionBtn.Text = opts.ButtonLabel or "Copy Discord Invite"
                        end
                    end)
                end
            end
        end)
    end

    -- ── Close button ──────────────────────────────────────
    local closeBtn = Create("TextButton", {
        Text = opts.CloseLabel or "Got it",
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = theme.TextPrimary,
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.3,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 34),
        LayoutOrder = 7,
        ZIndex = 5,
        Parent = content,
    })
    Corner(8, closeBtn)

    -- ── Close logic ───────────────────────────────────────
    local closing = false
    local function closePopup()
        if closing then return end
        closing = true

        pcall(function()
            Tween(card, 0.22, { BackgroundTransparency = 1 }):Play()
            Tween(cardStroke, 0.22, { Transparency = 1 }):Play()
            Tween(cardScale, 0.22, { Scale = 0.85 }):Play()
            Tween(backdrop, 0.22, { BackgroundTransparency = 1 }):Play()

            for _, child in ipairs(content:GetDescendants()) do
                if child:IsA("TextLabel") or child:IsA("TextButton") then
                    Tween(child, 0.18, { TextTransparency = 1 }):Play()
                end
            end
        end)

        task.delay(0.25, function()
            if gui.Parent then gui:Destroy() end
            if opts.OnClose then Compat.safeCallback(opts.OnClose) end
        end)
    end

    BindTap(closeBtn, closePopup)
    if opts.Dismissible ~= false then
        BindTap(backdrop, closePopup)
    end

    -- ── Entrance animation ────────────────────────────────
    Tween(backdrop, 0.35, { BackgroundTransparency = 0.55 }):Play()
    Tween(card, 0.40, { BackgroundTransparency = theme.BackgroundTrans or 0.1 }):Play()
    Tween(cardStroke, 0.40, { Transparency = 0.4 }):Play()
    Tween(cardScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()

    -- ── Auto-close timer ──────────────────────────────────
    if opts.Duration and opts.Duration > 0 then
        task.delay(opts.Duration, closePopup)
    end

    return {
        Gui = gui,
        Card = card,
        Close = closePopup,
    }
end

-- ============================================================
-- Reset helper — lets a hub author re-show the credit later
-- ============================================================
function LucidUI:ResetCreditShown()
    self._creditShown = false
end

-- ============================================================
-- Cleanup
-- ============================================================
LucidUI:OnCleanup(function()
    pcall(function()
        if PlayerGui then
            for _, gui in ipairs(PlayerGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Name == "LucidUI_CreditPopup" then
                    pcall(function() gui:Destroy() end)
                end
            end
        end
    end)
    print("[LucidUI] Credit cleaned up")
end)

-- ============================================================
-- Module: 10t_toastaction.lua
-- ============================================================
--[[
    Toast Action Buttons — adds an optional action button to any
    notification via a new `Action` field on the config.

    Usage:
        LucidUI:Notify({
            Title = "Config Saved",
            Message = "default",
            Variant = "success",
            Action = {
                Label = "Undo",
                Callback = function() W:LoadConfig("__prev") end,
            },
            ActionTimeout = 5,
            ActionExpired = function() print("User didn't undo") end,
        })

    Hooks the internal _renderNotification so it works for both
    direct calls and queued notifications.
]]

do

if not LucidUI or not LucidUI._renderNotification then return end

-- ------------------------------------------------------------
-- Find the bottom spacer in a rendered notification card
-- ------------------------------------------------------------
local function findSpacer(card)
    for _, c in ipairs(card:GetChildren()) do
        if c:IsA("Frame")
           and c.BackgroundTransparency == 1
           and c.Size.X.Scale == 1
           and c.Size.Y.Scale == 0
           and c.Size.Y.Offset == 14 then
            return c
        end
    end
    return nil
end

-- ------------------------------------------------------------
-- Attach the action button
-- ------------------------------------------------------------
local function attachAction(card, config)
    if type(config.Action) ~= "table" then return end
    if type(config.Action.Label) ~= "string" then return end

    local theme = config.Theme or LucidUI._lastTheme or LucidUI.Themes.Default
    local VARIANT_COLORS = {
        info    = Color3.fromRGB(90, 180, 255),
        success = Color3.fromRGB(90, 210, 130),
        warn    = Color3.fromRGB(255, 189, 46),
        error   = Color3.fromRGB(255, 95, 87),
    }
    local variant = config.Variant or "default"
    local accent = config.Accent or VARIANT_COLORS[variant] or theme.Accent

    -- Reserve vertical space so the button doesn't overlap the message
    local spacer = findSpacer(card)
    if spacer then
        spacer.Size = UDim2.new(1, 0, 0, 44)
    end

    local btn = Create("TextButton", {
        Text = config.Action.Label,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = accent,
        BackgroundColor3 = accent,
        BackgroundTransparency = 0.85,
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -12, 1, -12),
        Size = UDim2.fromOffset(0, 22),
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 10,
        Parent = card,
    })
    Corner(6, btn)
    Create("UIPadding", {
        PaddingLeft  = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        Parent = btn,
    })

    btn.MouseEnter:Connect(function()
        Tween(btn, 0.12, { BackgroundTransparency = 0.6 }):Play()
    end)
    btn.MouseLeave:Connect(function()
        Tween(btn, 0.12, { BackgroundTransparency = 0.85 }):Play()
    end)

    local fired = false
    local function fire()
        if fired then return end
        fired = true
        if type(config.Action.Callback) == "function" then
            Compat.safeCallback(config.Action.Callback)
        end
    end

    BindTap(btn, fire)

    if type(config.ActionTimeout) == "number" and config.ActionTimeout > 0 then
        task.delay(config.ActionTimeout, function()
            if fired then return end
            fired = true
            if type(config.ActionExpired) == "function" then
                Compat.safeCallback(config.ActionExpired)
            end
        end)
    end
end

-- ------------------------------------------------------------
-- Hook _renderNotification
-- ------------------------------------------------------------
local _origRender = LucidUI._renderNotification
function LucidUI:_renderNotification(config)
    local card = _origRender(self, config)
    if card and card.Parent then
        pcall(attachAction, card, config or {})
    end
    return card
end

LucidUI:OnCleanup(function()
    print("[LucidUI] ToastAction cleaned up")
end)

end

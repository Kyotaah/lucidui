-- ============================================================
-- Module: 10t_toastactions.lua
-- ============================================================
--[[
    Toast Action Buttons — extends Notify to support an action
    button on the right side of any toast.

    Usage:
      LucidUI:Notify({
          Title    = "Config Saved",
          Message  = "default",
          Variant  = "success",
          Action   = {
              Label    = "Undo",
              Callback = function() ... end,
              Timeout  = 5,      -- seconds before the action expires
              Expired  = function() ... end,  -- optional
          },
      })

    The action button:
      • Sits on the right side of the toast
      • Fades out after Timeout seconds
      • Clicking fires Callback and dismisses the toast
      • If the toast auto-dismisses first, Expired fires instead

    Implementation: wraps LucidUI._renderNotification so the
    internal toast renderer doesn't need to be patched.
]]

do

if not LucidUI or not LucidUI.Window then return end

local function attachAction(card, config, accent)
    if not card or not card.Parent then return end
    if type(config.Action) ~= "table" then return end

    local action = config.Action
    local label  = action.Label or "Action"
    local timeout = action.Timeout or 5

    -- Shrink the toast's message area to make room for the button
    -- We can't easily resize existing labels without knowing their
    -- references, so we just overlay a button that covers the
    -- right side and let the labels truncate naturally.

    local btn = Create("TextButton", {
        Text = label,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = accent,
        BackgroundColor3 = accent,
        BackgroundTransparency = 0.85,
        AutoButtonColor = false,
        Size = UDim2.fromOffset(64, 26),
        Position = UDim2.new(1, -74, 0.5, -13),
        ZIndex = 100,
        Parent = card,
    })
    Corner(6, btn)

    local fired = false

    local function doCallback()
        if fired then return end
        fired = true
        if type(action.Callback) == "function" then
            pcall(action.Callback)
        end
        pcall(function() card:Destroy() end)
    end

    BindTap(btn, doCallback, { Sound = false })

    btn.MouseEnter:Connect(function()
        Tween(btn, 0.12, { BackgroundTransparency = 0.65 }):Play()
    end)
    btn.MouseLeave:Connect(function()
        Tween(btn, 0.12, { BackgroundTransparency = 0.85 }):Play()
    end)

    -- Auto-expire
    task.delay(timeout, function()
        if fired then return end
        if not btn.Parent then return end
        fired = true
        Tween(btn, 0.20, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
        task.delay(0.22, function() pcall(function() btn:Destroy() end) end)
        if type(action.Expired) == "function" then
            pcall(action.Expired)
        end
    end)
end

local _origRender = LucidUI._renderNotification
function LucidUI:_renderNotification(config)
    local card = _origRender(self, config)
    if card and config and config.Action then
        local theme = config.Theme or LucidUI._lastTheme or LucidUI.Themes.Default
        local variantData = ({
            info    = Color3.fromRGB(90, 180, 255),
            success = Color3.fromRGB(90, 210, 130),
            warn    = Color3.fromRGB(255, 189, 46),
            error   = Color3.fromRGB(255, 95, 87),
        })[config.Variant or "default"]
        local accent = config.Accent or variantData or theme.Accent
        task.defer(function()
            pcall(attachAction, card, config, accent)
        end)
    end
    return card
end

LucidUI:OnCleanup(function()
    print("[LucidUI] ToastActions cleaned up")
end)

end

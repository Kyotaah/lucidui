--[[
    Discord Webhook Logger — sends execution events to a Discord channel.

    Usage:
        LucidUI:SetWebhook("https://discord.com/api/webhooks/...")
        LucidUI:Log("My hub was executed")

    On setup, fires a "loaded" message with basic info:
      • Player name + UserId
      • Executor name
      • Game name + PlaceId
      • Library version

    Also exposes:
        LucidUI:SetWebhookEnabled(bool)
        LucidUI:SetWebhookName(name)      -- shown as the bot's name
        LucidUI:SetWebhookAvatar(url)     -- shown as the bot's avatar
        LucidUI:Log(message, extraFields) -- send a custom message
        LucidUI:GetWebhook()              -- read the current URL
        LucidUI:TestWebhook()             -- send a test ping

    Cleanup: no persistent connections created (uses HTTP requests only).
    Safe to re-execute — the last-set webhook URL is preserved if you
    call SetWebhook again with no argument.
]]

-- ============================================================
-- State
-- ============================================================
local Webhook = {
    url      = nil,
    enabled  = true,
    name     = "LucidUI",
    avatar   = nil,
    loaded   = false,
}
LucidUI._webhook = Webhook

-- ============================================================
-- HTTP helpers
-- ============================================================
local function httpPost(url, payload)
    local body = Compat.encode(payload)
    if not body then return false, "encode failed" end

    -- Try executors in order of availability
    local request = (syn and syn.request)
                 or (http and http.request)
                 or (fluxus and fluxus.request)
                 or (krnl and krnl.request)
                 or (request)
                 or (http_request)

    if request then
        local ok, response = pcall(request, {
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body,
        })
        if ok then return true, response end
        return false, response
    end

    -- Fallback: roblox's HttpService can't POST to Discord, but some
    -- games proxy it. Try it anyway as a last resort.
    return false, "no executor HTTP support"
end

local function getExecutorName()
    if type(identifyexecutor) == "function" then
        local ok, name = pcall(identifyexecutor)
        if ok and name then return name end
    end
    if syn then return "Synapse X" end
    if KRNL_LOADED then return "Krnl" end
    if getgenv and getgenv().IS_SCRIPTWARE then return "Script-Ware" end
    if is_sirhurt_closure then return "SirHurt" end
    return "Unknown"
end

-- ============================================================
-- Payload builder
-- ============================================================
local function buildEmbed(title, description, color, fields)
    local embed = {
        title       = title,
        description = description,
        color       = color or 0x0A84FF,
        footer      = { text = "LucidUI v" .. (LucidUI._version or "?") },
        timestamp   = DateTime and DateTime.now():ToIsoDate() or nil,
        fields      = fields or {},
    }
    return embed
end

local function sendEmbed(embed)
    if not Webhook.url or not Webhook.enabled then return false end

    local payload = {
        username = Webhook.name,
        embeds   = { embed },
    }
    if Webhook.avatar then
        payload.avatar_url = Webhook.avatar
    end

    local ok, result = httpPost(Webhook.url, payload)
    if not ok then
        warn("[LucidUI] Webhook send failed:", tostring(result))
    end
    return ok
end

-- ============================================================
-- Public API
-- ============================================================
function LucidUI:SetWebhook(url)
    if url ~= nil then
        if type(url) ~= "string" or not url:find("discord") then
            warn("[LucidUI] SetWebhook expects a Discord webhook URL")
            return false
        end
        Webhook.url = url
    end

    -- Fire the "loaded" event the first time a URL is set
    if not Webhook.loaded then
        Webhook.loaded = true
        task.spawn(function()
            task.wait(1) -- let the UI settle
            local lp = LocalPlayer
            local game = game

            local fields = {
                { name = "Player",   value = lp.Name .. " (`" .. tostring(lp.UserId) .. "`)", inline = true },
                { name = "Executor", value = getExecutorName(),                                 inline = true },
                { name = "Place",    value = game.PlaceId .. " (JobId: `" .. tostring(game.JobId):sub(1, 8) .. "...`)", inline = false },
            }

            sendEmbed(buildEmbed(
                "LucidUI Loaded",
                "A user ran the hub",
                0x0A84FF,
                fields
            ))
        end)
    end
    return true
end

function LucidUI:GetWebhook()
    return Webhook.url
end

function LucidUI:SetWebhookEnabled(enabled)
    Webhook.enabled = enabled and true or false
end

function LucidUI:SetWebhookName(name)
    if type(name) == "string" then Webhook.name = name end
end

function LucidUI:SetWebhookAvatar(url)
    Webhook.avatar = url
end

function LucidUI:Log(message, extraFields)
    if not Webhook.url or not Webhook.enabled then return false end
    if type(message) ~= "string" then return false end

    local lp = LocalPlayer
    local fields = {
        { name = "Player", value = lp.Name, inline = true },
    }
    if type(extraFields) == "table" then
        for _, f in ipairs(extraFields) do
            table.insert(fields, f)
        end
    end

    return sendEmbed(buildEmbed(
        "LucidUI Log",
        message,
        0x5AD582,
        fields
    ))
end

function LucidUI:TestWebhook()
    if not Webhook.url then
        warn("[LucidUI] No webhook URL set")
        return false
    end
    return sendEmbed(buildEmbed(
        "Test Ping",
        "If you see this, the webhook is working.",
        0xFFBD2E
    ))
end

-- ============================================================
-- Settings UI
-- ============================================================
function LucidUI.Window:_buildWebhookSettings()
    self:_addSettingSection("Discord Webhook")

    -- URL input row
    local urlRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 40),
    })
    Corner(10, urlRow)
    self:_addSettingFrame(urlRow)

    Create("TextLabel", {
        Text = "Webhook URL", Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -180, 1, 0),
        Parent = urlRow,
    })

    local urlBox = Create("TextBox", {
        Text = Webhook.url or "",
        PlaceholderText = "https://discord.com/api/...",
        PlaceholderColor3 = self.Theme.TextMuted, Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = self.Theme.TextPrimary, BackgroundColor3 = self.Theme.Background,
        BackgroundTransparency = 0.3, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.fromOffset(140, 26), Position = UDim2.new(1, -154, 0.5, -13),
        Parent = urlRow,
    })
    Corner(8, urlBox)
    Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = urlBox })

    urlBox.FocusLost:Connect(function()
        if urlBox.Text ~= "" then
            LucidUI:SetWebhook(urlBox.Text)
            LucidUI:Notify({
                Title = "Webhook Set",
                Message = "URL saved for this session",
                Variant = "success",
                Duration = 2,
            })
        end
    end)

    -- Action buttons row
    local actionRow = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36) })
    self:_addSettingFrame(actionRow)
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = actionRow,
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

    mkBtn("Send Test Ping", self.Theme.Accent, function()
        if not Webhook.url then
            LucidUI:Notify({ Title = "No URL", Message = "Enter a webhook URL first", Variant = "error" })
            return
        end
        LucidUI:TestWebhook()
        LucidUI:Notify({ Title = "Sent", Message = "Check Discord", Variant = "info" })
    end)

    mkBtn("Clear URL", Color3.fromRGB(220, 60, 60), function()
        Webhook.url = nil
        urlBox.Text = ""
        LucidUI:Notify({ Title = "Cleared", Message = "Webhook URL removed", Variant = "info" })
    end)

    -- Status indicator
    local statusRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 44),
    })
    Corner(10, statusRow)
    self:_addSettingFrame(statusRow)

    local statusLabel = Create("TextLabel", {
        Text = "Webhook " .. (Webhook.url and "active" or "not configured"),
        Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = Webhook.url and Color3.fromRGB(90, 210, 130) or self.Theme.TextMuted,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0),
        Parent = statusRow,
    })

    self:_registerTheme(function(t)
        urlRow.BackgroundColor3 = t.Surface
        urlBox.BackgroundColor3 = t.Background
        urlBox.TextColor3 = t.TextPrimary
        statusRow.BackgroundColor3 = t.Surface
        if not Webhook.url then
            statusLabel.TextColor3 = t.TextMuted
        end
    end)
end

-- ============================================================
-- Hook BuildSettingsPanel
-- ============================================================
local _origBuildSettings = LucidUI.Window.BuildSettingsPanel
LucidUI.Window.BuildSettingsPanel = function(self, ...)
    _origBuildSettings(self, ...)
    if not self._webhookSettingsBuilt and self._settingsBuilt then
        self._webhookSettingsBuilt = true
        pcall(function() self:_buildWebhookSettings() end)
    end
end

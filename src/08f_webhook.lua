-- ============================================================
-- Module: 08f_webhook.lua
-- ============================================================
--[[
    Discord Webhook Logger — sends execution events to a Discord
    channel with full bot-style embed + component support.

    ADVANCED FEATURES
      • Rate-limit-aware queue (never trips 429)
      • Automatic batching — up to 10 embeds per HTTP request
      • Retry with exponential backoff, honors Retry-After headers
      • Field sanitization against Discord's hard limits
      • Local ring buffer of the last 50 embeds
      • Structured helpers: LogError, LogEvent, LogExecution
      • Rich embeds: author, thumbnail, image, custom footer, color
      • Link buttons (Discord's only webhook-compatible button style)
      • Auto row-wrapping — pass 12 buttons, get 3 rows
      • Global default components — attached to every outgoing message
      • Per-message overrides
      • Button presets (Discord, YouTube, Website, GitHub, custom)
      • Full manual API: SendCustomMessage(opts)

    USAGE
      -- Simple
      LucidUI:SetWebhook("https://discord.com/api/webhooks/...")
      LucidUI:Log("Player joined")

      -- With branding
      LucidUI:SetWebhookBranding({
          author    = { name = "My Hub", icon_url = "https://..." },
          thumbnail = "https://...",
          color     = 0x9B59B6,
      })

      -- Global buttons shown on every message
      LucidUI:SetWebhookComponents({
          { LucidUI.WebhookPresets.Discord("discord.gg/mine") },
          {
              LucidUI.WebhookPresets.YouTube("https://youtube.com/@me"),
              LucidUI.WebhookPresets.Website("https://mysite.com"),
          },
      })

      -- Rich custom message
      LucidUI:SendCustomMessage({
          title       = "New Update v2.1",
          description = "Featuring...",
          color       = 0x2ECC71,
          thumbnail   = "https://...",
          image       = "https://...",
          fields      = {
              { name = "Changes", value = "• Faster ESP\n• Fixed aimbot", inline = false },
          },
          buttons = {
              { label = "Download", url = "https://...", emoji = "⬇️" },
          },
      })
]]

-- ============================================================
-- Constants
-- ============================================================
local LIMITS = {
    EMBED_TITLE       = 256,
    EMBED_DESCRIPTION = 4096,
    EMBED_FIELD_NAME  = 256,
    EMBED_FIELD_VALUE = 1024,
    EMBED_FIELDS_MAX  = 25,
    EMBED_FOOTER      = 2048,
    EMBED_AUTHOR_NAME = 256,
    EMBED_TOTAL       = 6000,
    EMBEDS_PER_MSG    = 10,
    BUTTON_LABEL      = 80,
    BUTTONS_PER_ROW   = 5,
    BUTTON_ROWS_MAX   = 5,
    BUTTONS_MAX       = 25,
}

local MIN_GAP      = 0.4
local BASE_BACKOFF = 1.0
local MAX_BACKOFF  = 30.0
local MAX_ATTEMPTS = 3
local HISTORY_SIZE = 50

-- Discord component type codes
local COMPONENT_ACTION_ROW = 1
local COMPONENT_BUTTON     = 2
local BUTTON_STYLE_LINK    = 5

-- ============================================================
-- State
-- ============================================================
local Webhook = {
    url            = nil,
    enabled        = true,
    name           = "LucidUI",
    avatar         = nil,
    loaded         = false,
    autoLog        = true,
    consoleEcho    = false,
    branding       = {},   -- { author, thumbnail, image, footer, color }
    components     = nil,  -- global action rows
}
LucidUI._webhook = Webhook

local Queue = {
    items               = {},
    pumping             = false,
    nextSendAt          = 0,
    consecutiveFailures = 0,
    stats = {
        sent       = 0,
        dropped    = 0,
        failed     = 0,
        lastStatus = nil,
        lastError  = nil,
    },
}

local History = {}

-- ============================================================
-- Sanitization — Discord hard limits
-- ============================================================
local function truncate(s, max)
    if s == nil then return nil end
    if type(s) ~= "string" then s = tostring(s) end
    if #s <= max then return s end
    return s:sub(1, max - 1) .. "…"
end

local function isValidUrl(url)
    return type(url) == "string"
       and (url:sub(1, 7) == "http://" or url:sub(1, 8) == "https://")
end

-- Normalize a user-provided emoji into Discord's emoji object shape.
-- Accepts: string ("🔥") | table ({ name = "fire" }) | table ({ id = "123" })
local function normalizeEmoji(e)
    if e == nil then return nil end
    if type(e) == "string" then
        if e == "" then return nil end
        return { name = e }
    end
    if type(e) == "table" then
        if e.id and e.name then return { id = tostring(e.id), name = tostring(e.name) } end
        if e.id then return { id = tostring(e.id), name = nil } end
        if e.name then return { name = tostring(e.name) } end
    end
    return nil
end

-- Sanitize a single button definition into a Discord-style payload.
-- Returns nil if the button is invalid (missing url, etc.)
local function sanitizeButton(btn)
    if type(btn) ~= "table" then return nil end

    local url = btn.url or btn.link or btn.href
    if not isValidUrl(url) then
        return nil -- link-style requires a URL
    end

    local label = btn.label or btn.text or btn.name
    if label ~= nil then
        label = truncate(tostring(label), LIMITS.BUTTON_LABEL)
        if label == "" then label = nil end
    end

    -- Discord requires either a label or an emoji for link buttons
    local emoji = normalizeEmoji(btn.emoji)
    if not label and not emoji then
        return nil
    end

    local out = {
        type  = COMPONENT_BUTTON,
        style = BUTTON_STYLE_LINK,
        url   = url,
    }
    if label then out.label = label end
    if emoji then out.emoji = emoji end
    return out
end

-- Turn a flat list of buttons into Discord action rows, auto-splitting
-- at 5 per row and capping at 5 rows total.
local function buildActionRows(buttons)
    if type(buttons) ~= "table" or #buttons == 0 then return nil end

    local cleaned = {}
    for _, b in ipairs(buttons) do
        local sb = sanitizeButton(b)
        if sb then table.insert(cleaned, sb) end
        if #cleaned >= LIMITS.BUTTONS_MAX then break end
    end
    if #cleaned == 0 then return nil end

    local rows, current = {}, {}
    for _, b in ipairs(cleaned) do
        table.insert(current, b)
        if #current >= LIMITS.BUTTONS_PER_ROW then
            table.insert(rows, { type = COMPONENT_ACTION_ROW, components = current })
            current = {}
            if #rows >= LIMITS.BUTTON_ROWS_MAX then break end
        end
    end
    if #current > 0 and #rows < LIMITS.BUTTON_ROWS_MAX then
        table.insert(rows, { type = COMPONENT_ACTION_ROW, components = current })
    end

    return #rows > 0 and rows or nil
end

-- Accepts either a list of buttons OR a list of rows (lists of buttons).
-- Detects which and normalizes to full action-row format.
local function normalizeComponents(input)
    if type(input) ~= "table" or #input == 0 then return nil end

    -- Heuristic: if the first element is itself a list of buttons, treat
    -- the whole thing as pre-built rows.
    local first = input[1]
    if type(first) == "table" and first[1] and type(first[1]) == "table" then
        -- Already rows. Sanitize each.
        local rows = {}
        for _, row in ipairs(input) do
            if #rows >= LIMITS.BUTTON_ROWS_MAX then break end
            local sanitized = {}
            for _, b in ipairs(row) do
                local sb = sanitizeButton(b)
                if sb then table.insert(sanitized, sb) end
                if #sanitized >= LIMITS.BUTTONS_PER_ROW then break end
            end
            if #sanitized > 0 then
                table.insert(rows, { type = COMPONENT_ACTION_ROW, components = sanitized })
            end
        end
        return #rows > 0 and rows or nil
    end

    -- Flat list of buttons
    return buildActionRows(input)
end

local function sanitizeEmbed(embed)
    if type(embed) ~= "table" then return embed end

    if embed.title then
        embed.title = truncate(embed.title, LIMITS.EMBED_TITLE)
    end
    if embed.description then
        embed.description = truncate(embed.description, LIMITS.EMBED_DESCRIPTION)
    end
    if embed.footer and embed.footer.text then
        embed.footer.text = truncate(embed.footer.text, LIMITS.EMBED_FOOTER)
    end
    if embed.author and embed.author.name then
        embed.author.name = truncate(embed.author.name, LIMITS.EMBED_AUTHOR_NAME)
    end

    if type(embed.fields) == "table" then
        for i = #embed.fields, 1, -1 do
            if i > LIMITS.EMBED_FIELDS_MAX then
                table.remove(embed.fields, i)
            else
                local f = embed.fields[i]
                if type(f) == "table" then
                    if f.name then
                        f.name = truncate(f.name, LIMITS.EMBED_FIELD_NAME)
                    end
                    if f.value then
                        f.value = truncate(f.value, LIMITS.EMBED_FIELD_VALUE)
                    end
                    if f.inline ~= nil then
                        f.inline = f.inline and true or false
                    end
                end
            end
        end
    end

    local total = 0
    total = total + #(embed.title or "")
    total = total + #(embed.description or "")
    total = total + #((embed.footer and embed.footer.text) or "")
    if type(embed.fields) == "table" then
        for _, f in ipairs(embed.fields) do
            if type(f) == "table" then
                total = total + #(f.name or "")
                total = total + #(f.value or "")
            end
        end
    end
    if total > LIMITS.EMBED_TOTAL and embed.description then
        local overflow = total - LIMITS.EMBED_TOTAL
        local newLen = math.max(64, #embed.description - overflow - 1)
        embed.description = embed.description:sub(1, newLen) .. "…"
    end

    return embed
end

-- ============================================================
-- HTTP helpers
-- ============================================================
local function encodeJSON(t)
    if Compat and Compat.encode then return Compat.encode(t) end
    local ok, r = pcall(function()
        return game:GetService("HttpService"):JSONEncode(t)
    end)
    return ok and r or nil
end

local function getRequestFn()
    return (syn and syn.request)
        or (http and http.request)
        or (fluxus and fluxus.request)
        or (krnl and krnl.request)
        or (request)
        or (http_request)
end

local function normalizeResponse(raw)
    if type(raw) == "string" then
        return { status = 200, body = raw, headers = {} }
    end
    if type(raw) == "table" then
        local status = raw.StatusCode or raw.Status or raw.status or 200
        local body   = raw.Body or raw.body or ""
        local hdrs   = raw.Headers or raw.headers or {}
        return { status = tonumber(status) or 0, body = body, headers = hdrs }
    end
    return { status = 0, body = "", headers = {} }
end

local function getHeader(headers, key)
    if type(headers) ~= "table" then return nil end
    local want = key:lower()
    for k, v in pairs(headers) do
        if tostring(k):lower() == want then return v end
    end
    return nil
end

-- Send a single Discord message. `embeds` is an array of embed tables,
-- `components` is an optional array of action rows.
local function sendMessage(embeds, components)
    if not Webhook.url or not Webhook.enabled then
        return { ok = false, status = 0, reason = "disabled" }
    end
    if type(embeds) ~= "table" or #embeds == 0 then
        return { ok = false, status = 0, reason = "empty" }
    end

    local reqFn = getRequestFn()
    if not reqFn then
        return { ok = false, status = 0, reason = "no-http" }
    end

    local payload = {
        username = Webhook.name,
        embeds   = embeds,
    }
    if Webhook.avatar then
        payload.avatar_url = Webhook.avatar
    end
    if type(components) == "table" and #components > 0 then
        payload.components = components
    end

    local body = encodeJSON(payload)
    if not body then
        return { ok = false, status = 0, reason = "encode-failed" }
    end

    local ok, raw = pcall(reqFn, {
        Url = Webhook.url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = body,
    })

    if not ok then
        return { ok = false, status = 0, reason = tostring(raw) }
    end

    local resp = normalizeResponse(raw)

    if resp.status >= 200 and resp.status < 300 then
        return { ok = true, status = resp.status }
    end

    if resp.status == 429 then
        local retry = tonumber(getHeader(resp.headers, "retry-after")) or 2
        return { ok = false, status = 429, retryAfter = retry, reason = "rate-limited" }
    end

    if resp.status >= 500 then
        return { ok = false, status = resp.status, reason = "server-error" }
    end

    return { ok = false, status = resp.status, reason = "client-error", permanent = true }
end

-- ============================================================
-- Embed builder
-- ============================================================
local function buildEmbed(title, description, color, fields)
    local b = Webhook.branding or {}
    local embed = {
        title       = title,
        description = description,
        color       = color or b.color or 0x0A84FF,
        timestamp   = DateTime and DateTime.now():ToIsoDate() or nil,
    }
    if fields and #fields > 0 then
        embed.fields = fields
    end

    -- Footer: custom wins, else default
    if b.footer then
        if type(b.footer) == "table" then
            embed.footer = b.footer
        else
            embed.footer = { text = tostring(b.footer) }
        end
    else
        embed.footer = { text = "LucidUI v" .. (LucidUI._version or "?") }
    end

    -- Author block
    if b.author then
        embed.author = b.author
    end

    -- Thumbnail (small, top-right corner)
    if b.thumbnail then
        local t = (type(b.thumbnail) == "table") and b.thumbnail or { url = b.thumbnail }
        if isValidUrl(t.url) then embed.thumbnail = t end
    end

    -- Image (large, bottom)
    if b.image then
        local i = (type(b.image) == "table") and b.image or { url = b.image }
        if isValidUrl(i.url) then embed.image = i end
    end

    return sanitizeEmbed(embed)
end

-- Full manual embed builder used by SendCustomMessage
local function buildRichEmbed(opts)
    opts = opts or {}
    local b = Webhook.branding or {}

    local embed = {
        title       = opts.title       and truncate(opts.title,       LIMITS.EMBED_TITLE) or nil,
        description = opts.description and truncate(opts.description, LIMITS.EMBED_DESCRIPTION) or nil,
        color       = opts.color or b.color or 0x0A84FF,
        timestamp   = opts.timestamp or (DateTime and DateTime.now():ToIsoDate() or nil),
    }

    if opts.fields and #opts.fields > 0 then
        embed.fields = opts.fields
    end

    -- Footer (per-message wins over branding wins over default)
    local footerSrc = opts.footer or b.footer
    if footerSrc then
        if type(footerSrc) == "table" then
            embed.footer = footerSrc
        else
            embed.footer = { text = tostring(footerSrc) }
        end
    elseif opts.noFooter ~= true then
        embed.footer = { text = "LucidUI v" .. (LucidUI._version or "?") }
    end

    -- Author
    local authorSrc = opts.author or b.author
    if authorSrc and type(authorSrc) == "table" then
        embed.author = authorSrc
    end

    -- Thumbnail
    local thumbSrc = opts.thumbnail or b.thumbnail
    if thumbSrc then
        local t = (type(thumbSrc) == "table") and thumbSrc or { url = thumbSrc }
        if isValidUrl(t.url) then embed.thumbnail = t end
    end

    -- Image
    local imgSrc = opts.image or b.image
    if imgSrc then
        local i = (type(imgSrc) == "table") and imgSrc or { url = imgSrc }
        if isValidUrl(i.url) then embed.image = i end
    end

    return sanitizeEmbed(embed)
end

-- ============================================================
-- Queue
-- ============================================================
local function pushHistory(embed)
    table.insert(History, embed)
    if #History > HISTORY_SIZE then
        table.remove(History, 1)
    end
end

-- Enqueue a message unit: { embed = t, components = t|nil }
-- Messages with components are never batched together with others
-- (components are per-message, not per-embed).
local function enqueue(embed, components)
    if not Webhook.url or not Webhook.enabled then
        Queue.stats.dropped = Queue.stats.dropped + 1
        return false
    end

    -- Fall back to global components when none specified
    local comps = components or Webhook.components

    table.insert(Queue.items, {
        embed      = embed,
        components = comps,
        attempts   = 0,
        enqueuedAt = tick(),
    })

    if not Queue.pumping then
        task.spawn(function()
            Queue.pumping = true
            while #Queue.items > 0 do
                local now = tick()
                if Queue.nextSendAt > now then
                    task.wait(Queue.nextSendAt - now)
                end
                if not Webhook.url or not Webhook.enabled then break end

                -- Peek the head of the queue to decide batching mode
                local head = Queue.items[1]
                if not head then break end

                local batch, batchItems
                if head.components then
                    -- Single message with components — send alone
                    batch      = { head.embed }
                    batchItems = { table.remove(Queue.items, 1) }
                else
                    -- Batch up to 10 component-less embeds
                    batch, batchItems = {}, {}
                    for _ = 1, LIMITS.EMBEDS_PER_MSG do
                        local item = Queue.items[1]
                        if not item or item.components then break end
                        table.remove(Queue.items, 1)
                        table.insert(batch, item.embed)
                        table.insert(batchItems, item)
                    end
                end

                if #batch == 0 then break end

                local result = sendMessage(batch, head.components)
                Queue.stats.lastStatus = result.status

                if result.ok then
                    Queue.consecutiveFailures = 0
                    Queue.nextSendAt = tick() + MIN_GAP
                    Queue.stats.sent = Queue.stats.sent + #batch

                    if Webhook.consoleEcho then
                        print(string.format(
                            "[LucidUI Webhook] Sent %d embed(s) — status %d",
                            #batch, result.status
                        ))
                    end

                elseif result.permanent then
                    Queue.stats.failed = Queue.stats.failed + #batch
                    Queue.stats.lastError = result.reason
                    Queue.nextSendAt = tick() + MIN_GAP

                    if Webhook.consoleEcho then
                        warn(string.format(
                            "[LucidUI Webhook] Dropped %d — %s (%d)",
                            #batch, result.reason, result.status
                        ))
                    end

                else
                    Queue.consecutiveFailures = Queue.consecutiveFailures + 1
                    Queue.stats.lastError = result.reason

                    local requeued = 0
                    for i = #batch, 1, -1 do
                        local item = batchItems[i]
                        item.attempts = item.attempts + 1
                        if item.attempts < MAX_ATTEMPTS then
                            table.insert(Queue.items, 1, item)
                            requeued = requeued + 1
                        else
                            Queue.stats.dropped = Queue.stats.dropped + 1
                        end
                    end

                    if requeued > 0 then
                        local backoff
                        if result.retryAfter then
                            backoff = result.retryAfter
                        else
                            backoff = math.min(
                                MAX_BACKOFF,
                                BASE_BACKOFF * (2 ^ Queue.consecutiveFailures)
                            )
                        end
                        Queue.nextSendAt = tick() + backoff
                        if Webhook.consoleEcho then
                            warn(string.format(
                                "[LucidUI Webhook] Retrying %d in %.1fs — %s",
                                requeued, backoff, tostring(result.reason)
                            ))
                        end
                    else
                        Queue.nextSendAt = tick() + MIN_GAP
                    end
                end
            end
            Queue.pumping = false
        end)
    end

    return true
end

-- ============================================================
-- Button presets
-- ============================================================
LucidUI.WebhookPresets = {}

function LucidUI.WebhookPresets.Discord(url)
    if type(url) == "string" and not url:match("^https?://") then
        url = "https://" .. url
    end
    return { label = "Discord", url = url, emoji = "💬" }
end

function LucidUI.WebhookPresets.YouTube(url)
    return { label = "YouTube", url = url, emoji = "▶️" }
end

function LucidUI.WebhookPresets.Website(url)
    return { label = "Website", url = url, emoji = "🌐" }
end

function LucidUI.WebhookPresets.GitHub(url)
    return { label = "GitHub", url = url, emoji = "💻" }
end

function LucidUI.WebhookPresets.Download(url)
    return { label = "Download", url = url, emoji = "⬇️" }
end

function LucidUI.WebhookPresets.ScriptBlox(url)
    return { label = "ScriptBlox", url = url }
end

function LucidUI.WebhookPresets.PayPal(url)
    return { label = "Donate", url = url, emoji = "❤️" }
end

-- Generic escape hatch
function LucidUI.WebhookPresets.Custom(label, url, emoji)
    return { label = label, url = url, emoji = emoji }
end

-- ============================================================
-- Public API
-- ============================================================
function LucidUI:SetWebhook(url, opts)
    opts = opts or {}

    if url ~= nil then
        if type(url) ~= "string" or not url:find("discord") then
            warn("[LucidUI] SetWebhook expects a Discord webhook URL")
            return false
        end
        Webhook.url = url
    end

    if opts.AutoLog ~= nil then
        Webhook.autoLog = opts.AutoLog and true or false
    end

    if not Webhook.loaded then
        Webhook.loaded = true
        if Webhook.autoLog then
            task.spawn(function()
                task.wait(1)
                self:LogExecution()
            end)
        end
    end
    return true
end

function LucidUI:GetWebhook()                    return Webhook.url end
function LucidUI:SetWebhookEnabled(v)            Webhook.enabled = v and true or false end
function LucidUI:SetWebhookName(n)
    if type(n) == "string" then Webhook.name = n end
end
function LucidUI:SetWebhookAvatar(u)             Webhook.avatar = u end
function LucidUI:SetWebhookAutoLog(v)            Webhook.autoLog = v and true or false end
function LucidUI:SetWebhookConsoleEcho(v)        Webhook.consoleEcho = v and true or false end

-- ── Branding ────────────────────────────────────────────────
--[[
    Set a default look for every outgoing embed. All fields optional.

        LucidUI:SetWebhookBranding({
            author    = { name = "My Hub", icon_url = "https://..." },
            thumbnail = "https://...",         -- small top-right image
            image     = "https://...",         -- large bottom image
            footer    = "Made by Me",          -- string or { text, icon_url }
            color     = 0x9B59B6,              -- default embed color
        })
]]
function LucidUI:SetWebhookBranding(branding)
    Webhook.branding = type(branding) == "table" and branding or {}
end

function LucidUI:ClearWebhookBranding()
    Webhook.branding = {}
end

-- ── Global components ──────────────────────────────────────
--[[
    Set buttons that appear on EVERY outgoing message. Pass either:
      • a flat list of buttons (auto-wrapped into rows of 5), or
      • a list of rows (each row = list of buttons)

        LucidUI:SetWebhookComponents({
            LucidUI.WebhookPresets.Discord("discord.gg/mine"),
            LucidUI.WebhookPresets.YouTube("https://youtube.com/@me"),
        })

    Pass nil to clear.
]]
function LucidUI:SetWebhookComponents(rows)
    Webhook.components = normalizeComponents(rows)
end

function LucidUI:ClearWebhookComponents()
    Webhook.components = nil
end

-- ── Direct message send ────────────────────────────────────
--[[
    Build and send a fully custom embed + buttons.

    opts = {
        title       = "…",
        description = "…",
        color       = 0xRRGGBB,
        fields      = { { name = "…", value = "…", inline = true }, ... },
        author      = { name = "…", icon_url = "…", url = "…" },
        footer      = "text" or { text = "…", icon_url = "…" },
        thumbnail   = "url" or { url = "…" },
        image       = "url" or { url = "…" },
        buttons     = { { label, url, emoji }, ... },
        noFooter    = true,  -- skip the default LucidUI footer
    }
]]
function LucidUI:SendCustomMessage(opts)
    if not Webhook.url or not Webhook.enabled then return false end
    opts = opts or {}

    local embed = buildRichEmbed(opts)
    pushHistory(embed)

    local components
    if type(opts.buttons) == "table" and #opts.buttons > 0 then
        components = normalizeComponents(opts.buttons)
    end
    -- If no per-message buttons, enqueue(nil) falls back to global

    return enqueue(embed, components)
end

-- ── Plain log ───────────────────────────────────────────────
function LucidUI:Log(message, extraFields, opts)
    if not Webhook.url or not Webhook.enabled then return false end
    if type(message) ~= "string" then return false end

    local lp = LocalPlayer
    local fields = {
        { name = "Player", value = lp and lp.Name or "?", inline = true },
    }
    if type(extraFields) == "table" then
        for _, f in ipairs(extraFields) do
            table.insert(fields, f)
        end
    end

    local embed = buildEmbed("LucidUI Log", message, 0x5AD582, fields)
    pushHistory(embed)

    local components
    if opts and type(opts.buttons) == "table" then
        components = normalizeComponents(opts.buttons)
    end
    return enqueue(embed, components)
end

-- ── Structured error ────────────────────────────────────────
function LucidUI:LogError(err, context)
    if not Webhook.url or not Webhook.enabled then return false end

    local lp  = LocalPlayer
    local msg = tostring(err or "Unknown error")
    if #msg > 900 then msg = msg:sub(1, 897) .. "..." end

    local fields = {
        { name = "Player", value = lp and lp.Name or "?", inline = true },
        { name = "Place",  value = tostring(game.PlaceId), inline = true },
    }

    if type(context) == "table" then
        if context.traceback then
            table.insert(fields, {
                name   = "Traceback",
                value  = "```\n" .. tostring(context.traceback):sub(1, 900) .. "\n```",
                inline = false,
            })
        end
        if context.flag then
            table.insert(fields, { name = "Flag", value = tostring(context.flag), inline = true })
        end
        if context.extra then
            table.insert(fields, { name = "Extra", value = tostring(context.extra), inline = false })
        end
    end

    local embed = buildEmbed("Script Error", msg, 0xE64340, fields)
    pushHistory(embed)
    return enqueue(embed)
end

-- ── Named event ─────────────────────────────────────────────
function LucidUI:LogEvent(name, fields)
    if not Webhook.url or not Webhook.enabled then return false end
    if type(name) ~= "string" then return false end

    local lp = LocalPlayer
    local allFields = {
        { name = "Player", value = lp and lp.Name or "?", inline = true },
    }
    if type(fields) == "table" then
        for _, f in ipairs(fields) do
            table.insert(allFields, f)
        end
    end

    local embed = buildEmbed("Event · " .. name, nil, 0x3B82F6, allFields)
    pushHistory(embed)
    return enqueue(embed)
end

-- ── Execution ping ──────────────────────────────────────────
function LucidUI:LogExecution(extraFields)
    if not Webhook.url or not Webhook.enabled then return false end

    local lp = LocalPlayer
    local fields = {
        { name = "Player",   value = lp and (lp.Name .. " (`" .. tostring(lp.UserId) .. "`)") or "?", inline = true },
        { name = "Executor", value = Compat.getExecutorName(), inline = true },
        { name = "Place",    value = tostring(game.PlaceId) .. " (JobId: `"
            .. tostring(game.JobId):sub(1, 8) .. "...`)", inline = false },
    }
    if type(extraFields) == "table" then
        for _, f in ipairs(extraFields) do
            table.insert(fields, f)
        end
    end

    local embed = buildEmbed("LucidUI Loaded", "A user ran the hub", 0x0A84FF, fields)
    pushHistory(embed)
    return enqueue(embed)
end

-- ── Test ping ───────────────────────────────────────────────
function LucidUI:TestWebhook()
    if not Webhook.url then
        warn("[LucidUI] No webhook URL set")
        return false
    end
    local embed = buildEmbed("Test Ping", "If you see this, the webhook is working.", 0xFFBD2E)
    pushHistory(embed)
    return enqueue(embed)
end

-- ── Diagnostics ─────────────────────────────────────────────
function LucidUI:GetWebhookQueueSize()   return #Queue.items end
function LucidUI:GetWebhookStats()
    return {
        sent       = Queue.stats.sent,
        dropped    = Queue.stats.dropped,
        failed     = Queue.stats.failed,
        lastStatus = Queue.stats.lastStatus,
        lastError  = Queue.stats.lastError,
        pending    = #Queue.items,
        pumping    = Queue.pumping,
    }
end
function LucidUI:GetWebhookHistory()
    local out = {}
    for i, e in ipairs(History) do out[i] = e end
    return out
end
function LucidUI:ClearWebhookHistory()  History = {} end
function LucidUI:FlushWebhook()
    Queue.nextSendAt = 0
    Queue.consecutiveFailures = 0
end

-- ============================================================
-- Settings UI
-- ============================================================
function LucidUI.Window:_buildWebhookSettings()
    self:_addSettingSection("Discord Webhook")

    -- URL row
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
                Title = "Webhook Set", Message = "URL saved",
                Variant = "success", Duration = 2,
            })
        end
    end)

    -- Status card
    local statusRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 68),
    })
    Corner(10, statusRow)
    self:_addSettingFrame(statusRow)

    local statusLbl = Create("TextLabel", {
        Text = "Status", Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = self.Theme.TextPrimary, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 16),
        Parent = statusRow,
    })

    local statusValue = Create("TextLabel", {
        Text = "", Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = self.Theme.TextMuted, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 26), Size = UDim2.new(1, -28, 0, 32),
        TextWrapped = true, Parent = statusRow,
    })

    local function refreshStatus()
        local s = LucidUI:GetWebhookStats()
        local lines = {
            "Configured: " .. (Webhook.url and "yes" or "no"),
            "Pending: " .. tostring(s.pending) ..
                "   Sent: " .. tostring(s.sent) ..
                "   Dropped: " .. tostring(s.dropped),
        }
        if s.lastStatus then
            table.insert(lines, "Last: " .. tostring(s.lastStatus) ..
                (s.lastError and ("  (" .. tostring(s.lastError) .. ")") or ""))
        end
        statusValue.Text = table.concat(lines, "\n")
        statusValue.TextColor3 = Webhook.url and self.Theme.TextSecondary or self.Theme.TextMuted
    end
    refreshStatus()

    -- Quick-button presets row (Applies to next messages via SetWebhookComponents)
    local presetRow = Create("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTrans,
        Size = UDim2.new(1, 0, 0, 36),
    })
    Corner(10, presetRow)
    self:_addSettingFrame(presetRow)

    Create("TextLabel", {
        Text = "Attach preset buttons to all messages",
        Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = self.Theme.TextMuted, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0),
        Parent = presetRow,
    })

    local linkRow = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34) })
    self:_addSettingFrame(linkRow)
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        Parent = linkRow,
    })

    local function mkLinkBtn(text, cb)
        local b = Create("TextButton", {
            Text = text, Font = Enum.Font.GothamBold, TextSize = 12,
            TextColor3 = self.Theme.TextPrimary, BackgroundColor3 = self.Theme.Background,
            BackgroundTransparency = 0.3, AutoButtonColor = false,
            Size = UDim2.new(0.5, -3, 1, 0), Parent = linkRow,
        })
        Corner(8, b)
        BindTap(b, cb, { MoveThreshold = 8 })
        return b
    end

    mkLinkBtn("Set Discord Button", function()
        LucidUI:Notify({
            Title = "Enter Invite",
            Message = "Use the console: LucidUI:SetWebhookComponents({LucidUI.WebhookPresets.Discord('invite')})",
            Variant = "info",
            Duration = 6,
        })
    end)

    mkLinkBtn("Clear Buttons", function()
        LucidUI:ClearWebhookComponents()
        LucidUI:Notify({
            Title = "Cleared", Message = "Buttons removed from default",
            Variant = "info", Duration = 2,
        })
    end)

    -- Action buttons
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
        refreshStatus()
    end)

    mkBtn("Flush Queue", self.Theme.Surface, function()
        LucidUI:FlushWebhook()
        LucidUI:Notify({ Title = "Flushed", Message = "Queue sent immediately", Variant = "info" })
        refreshStatus()
    end)

    local clearRow = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32) })
    self:_addSettingFrame(clearRow)
    local clearBtn = Create("TextButton", {
        Text = "Clear URL", Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = Color3.fromRGB(180, 60, 60),
        BackgroundTransparency = 0.2, AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1), Parent = clearRow,
    })
    Corner(8, clearBtn)
    BindTap(clearBtn, function()
        Webhook.url = nil
        urlBox.Text = ""
        refreshStatus()
        LucidUI:Notify({ Title = "Cleared", Message = "Webhook URL removed", Variant = "info" })
    end, { MoveThreshold = 8 })

    task.spawn(function()
        while statusRow.Parent do
            refreshStatus()
            task.wait(0.75)
        end
    end)

    self:_registerTheme(function(t)
        urlRow.BackgroundColor3     = t.Surface
        urlBox.BackgroundColor3     = t.Background
        urlBox.TextColor3           = t.TextPrimary
        statusRow.BackgroundColor3  = t.Surface
        statusLbl.TextColor3        = t.TextPrimary
        statusValue.TextColor3      = Webhook.url and t.TextSecondary or t.TextMuted
        presetRow.BackgroundColor3  = t.Surface
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

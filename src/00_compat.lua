--[[
    Compat — executor-agnostic wrappers for file I/O, HTTP, and serialization.
    Every file-system operation in LucidUI goes through this layer so that
    executors without writefile / readfile / listfiles fail gracefully
    instead of erroring out.
]]

local Compat = {}

-- ============================================================
-- Capability checks
-- ============================================================
function Compat.hasFS()
    return type(isfolder)   == "function"
       and type(makefolder) == "function"
       and type(writefile)  == "function"
       and type(readfile)   == "function"
end

function Compat.hasCustomAsset()
    return type(getcustomasset) == "function"
end

function Compat.hasListfiles()
    return type(listfiles) == "function"
end

-- ============================================================
-- [IMPROVEMENT] Executor Name Detection
-- ============================================================
function Compat.getExecutorName()
    if syn and syn.protect_gui then return "Synapse X" end
    if KRNL_LOADED then return "Krnl" end
    if getgenv and getgenv().IS_SCRIPTWARE then return "Script-Ware" end
    if is_sirhurt_closure then return "SirHurt" end
    if type(getexecutorname) == "function" then return getexecutorname() end
    if type(identifyexecutor) == "function" then return identifyexecutor() end
    return "Unknown Executor"
end

-- ============================================================
-- [IMPROVEMENT] Safe Callback Wrapper
-- ============================================================
function Compat.safeCallback(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[LucidUI] Callback error: " .. tostring(err))
    end
end

-- ============================================================
-- File system
-- ============================================================
function Compat.write(path, content)
    if not Compat.hasFS() then return false end
    return (pcall(writefile, path, content))
end

function Compat.read(path)
    if not Compat.hasFS() then return nil end
    local ok, content = pcall(readfile, path)
    if ok then return content end
    return nil
end

function Compat.makeFolder(path)
    if not Compat.hasFS() then return false end
    return (pcall(function()
        if not isfolder(path) then makefolder(path) end
    end))
end

function Compat.delete(path)
    if type(delfile) ~= "function" then return false end
    return (pcall(delfile, path))
end

-- ============================================================
-- Folder layout
-- ============================================================
function Compat.ensureFolders()
    Compat.makeFolder("LucidUI")
    Compat.makeFolder("LucidUI/Configs")
    Compat.makeFolder("LucidUI/Themes")
end

-- ============================================================
-- Listing helpers
-- ============================================================
local function safeList(folder)
    if not Compat.hasListfiles() then return {} end
    local ok, files = pcall(listfiles, folder)
    if not ok or type(files) ~= "table" then return {} end
    return files
end

local function namesFromPaths(paths)
    local out, seen = {}, {}
    for _, path in ipairs(paths) do
        local name = path:match("([^/\\]+)%.json$")
        if name and not seen[name] then
            table.insert(out, name)
            seen[name] = true
        end
    end
    return out
end

function Compat.listConfigs()
    Compat.ensureFolders()
    local files = safeList("LucidUI/Configs")
    local out = { "default" }
    local seen = { default = true }

    for _, name in ipairs(namesFromPaths(files)) do
        if not seen[name] then
            table.insert(out, name)
            seen[name] = true
        end
    end

    table.sort(out, function(a, b)
        if a == "default" then return true end
        if b == "default" then return false end
        return a:lower() < b:lower()
    end)
    return out
end

function Compat.listThemes()
    Compat.ensureFolders()
    local files = safeList("LucidUI/Themes")
    local out = namesFromPaths(files)
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

-- ============================================================
-- JSON helpers
-- ============================================================
function Compat.encode(t)
    local ok, result = pcall(function()
        return game:GetService("HttpService"):JSONEncode(t)
    end)
    if ok then return result end
    return nil
end

function Compat.decode(s)
    local ok, result = pcall(function()
        return game:GetService("HttpService"):JSONDecode(s)
    end)
    if ok then return result end
    return nil
end

-- ============================================================
-- Color serialization
-- Roblox's JSON encoder turns Color3 into a shape that decodes
-- as a plain Lua table without .R/.G/.B. We wrap colors in a
-- marker table so round-tripping is lossless.
-- ============================================================
function Compat.serializeColors(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do
        if typeof(v) == "Color3" then
            out[k] = { __c3 = true, R = v.R, G = v.G, B = v.B }
        else
            out[k] = v
        end
    end
    return out
end

function Compat.deserializeColors(t)
    if type(t) ~= "table" then return nil end
    local out = {}
    for k, v in pairs(t) do
        if type(v) == "table" and v.R and v.G and v.B then
            -- Handles both the marker format and the legacy format
            out[k] = Color3.new(v.R, v.G, v.B)
        else
            out[k] = v
        end
    end
    return out
end

return Compat

local Window = LucidUI:CreateWindow({
    Name          = "CurrentVector",
    Theme         = "Default",
    Width         = 640,
    Height        = 480,
    IntroTitle    = "CurrentVector",
    IntroSubtitle = "Dances V1",
    IntroTagline  = "Emote library · LucidUI edition",
    IntroStages = {
        {
            text = "Loading modules...",
            pct  = 0.10,
            task = function() task.wait(0.45) end,
        },
        {
            text = "Reading cache...",
            pct  = 0.20,
            task = function()
                if #missingAnims == 0 then
                    task.wait(0.35)
                else
                    task.wait(0.20)
                end
            end,
        },
        {
            text = #missingAnims == 0
                and "All animations cached"
                or  string.format("Downloading %d animation%s...", #missingAnims, #missingAnims == 1 and "" or "s"),
            pct = 0.88,
            task = function(report)
                if #missingAnims == 0 then
                    task.wait(0.55)
                    return
                end
                for i, name in ipairs(missingAnims) do
                    local path = "CurrentVector/Animations/" .. name .. ".rbxm"
                    if not isfile(path) then
                        downloadAnim(name, true)  -- silent, no notifications during intro
                    end
                    report(i / #missingAnims)
                end
                task.wait(0.20)
            end,
        },
        {
            text = "Preparing interface...",
            pct  = 0.95,
            task = function() task.wait(0.50) end,
        },
        {
            text = "Ready",
            pct  = 1.00,
            task = function() task.wait(0.45) end,
        },
    },
})

local _, addon = ...

-- DATA STRUCTURE
--
-- EMOTE ENTRY FORMAT
-- Each entry contains:
--     {"Button label", "default command", "targeted command"}
--
-- The targeted command is optional. It is used only when a target exists and
-- that target is not your own character. Otherwise, the default command is used.
--
-- Example:
--     {"Observe",
--      "/e watches quietly.",
--      "/e watches {target} quietly."}
--
-- Tokens supported in either command:
--     {target}  Target's name without the realm.
--     {player}  Your character's name without the realm.
--
-- Blizzard also supports %t in many chat commands as the current target's name,
-- but the {target} tokens above are expanded by this addon before the command
-- is sent and are therefore easier to use consistently in custom emotes.

addon.DefaultSections = {
    -- Category 1
    {
        name = "Favorites",
        emotes = {
            {"Wave", "/wave"},
            {"Cheer", "/cheer"},
            {"Clap", "/clap"},
            {"Cackle", "/cackle"},
            {"Lean", "/lean"},
            {"Look", "/look"},
            {"Pat", "/pat"},
            {"Point", "/point"},
            {"Salute", "/salute"}
        }
    },

    -- Category 2
    {
        name = "Thoughts",
        emotes = {
            {"Blank", "/blank"},
            {"Gaze", "/gaze"},
            {"Ponder", "/e pauses to ponder.", "/e regards {target} thoughtfully, pausing to ponder."},
            {"Quiet and thoughtful", "/e grows quiet and thoughtful.", "/e grows quiet and thoughtful as she considers {target}."},
            {"Watches quietly", "/e watches quietly.", "/e watches {target} quietly."},
            {"Peer", "/peer"},
            {"Considers that", "/e considers that for a moment.", "/e considers {target}'s words for a moment."},
            {"Tilts her head", "/e tilts her head slightly.", "/e tilts her head slightly at {target}."}
        }
    },

    -- Category 3
    {
        name = "Reactions",
        emotes = {
            {"Blink", "/blink"},
            {"Nod", "/nod"},
            {"Shrug", "/shrug"},
            {"Sigh", "/sigh"},
            {"Smirk", "/smirk"},
            {"Inhale", "/e takes a slow, deep breath, closing her eyes for a moment."},
            {"Exhale", "/e exhales slowly and opens her eyes.", "/e exhales slowly, opening her eyes to look at {target}."},
            {"Growl", "/e makes a soft growling noise in her throat.", "/e makes a soft growling noise in her throat at {target}."}
        }
    },

    -- Category 4
    {
        name = "Conversation",
        emotes = {
            {"Says...", "/e says, \"", "/e says to {target}, \""},
            {"Asks...", "/e asks, \"", "/e asks {target}, \""},
            {"Faint smile", "/e lets a faint smile flirt with the corner of her mouth.", "/e lets a faint smile flirt with the corner of her mouth as she regards {target}."},
            {"Quiet chuckle", "/e lets out a quiet chuckle.", "/e lets out a quiet chuckle at {target}."},
            {"Smile", "/smile"},
            {"Laugh", "/lol"},
            {"Thanks", "/ty"},
            {"Welcome", "/welcome"}
        }
    },

    -- Category 5
    {
        name = "Gestures",
        emotes = {
            {"Raise Hand", "/raise"},
            {"Point", "/point"},
            {"Beckon", "/beckon"},
            {"Wave", "/wave"},
            {"Cheer", "/cheer"},
            {"Kiss", "/kiss"},
            {"Salute", "/salute"}
        }
    },

    -- Category 6
    {
        name = "Postures",
        emotes = {
            {"Sit", "/sit"},
            {"Stand", "/stand"},
            {"Stretch", "/e laces her fingers together and stretches skyward, exhaling slowly before letting her arms fall back to her sides."},
            {"Lean", "/lean"},
            {"Bow", "/bow"},
            {"Read", "/read"}
        }
    },

    -- Category 7
    {
        name = "",
        emotes = {
        }
    },

    -- Category 8
    {
        name = "",
        emotes = {
        }
    },

    -- Category 9
    {
        name = "",
        emotes = {
        }
    },

    -- Category 10
    {
        name = "",
        emotes = {
        }
    }
}

addon.BuiltInFonts = {
    {name = "Friz Quadrata", path = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"},
    {name = "Arial Narrow", path = "Fonts\\ARIALN.TTF"},
    {name = "Morpheus", path = "Fonts\\MORPHEUS.TTF"},
    {name = "Skurri", path = "Fonts\\skurri.ttf"}
}

function addon.GetAvailableFonts()
    local fonts = {}
    local includedFonts = {}

    for _, font in ipairs(addon.BuiltInFonts) do
        fonts[#fonts + 1] = font
        includedFonts[font.name] = true
    end

    local sharedMedia = LibStub and LibStub("LibSharedMedia-3.0", true)

    if sharedMedia then
        local sharedFonts = {}

        for _, fontName in ipairs(sharedMedia:List("font")) do
            local fontPath = sharedMedia:Fetch("font", fontName, true)

            if not includedFonts[fontName]
                and type(fontPath) == "string"
                and fontPath ~= "" then
                sharedFonts[#sharedFonts + 1] = {
                    name = fontName,
                    path = fontPath
                }
                includedFonts[fontName] = true
            end
        end

        table.sort(sharedFonts, function(first, second)
            return string.lower(first.name) < string.lower(second.name)
        end)

        for _, font in ipairs(sharedFonts) do
            fonts[#fonts + 1] = font
        end
    end

    return fonts
end

function addon.GetFontPath(fontName)
    for _, font in ipairs(addon.BuiltInFonts) do
        if font.name == fontName then
            return font.path
        end
    end

    local sharedMedia = LibStub and LibStub("LibSharedMedia-3.0", true)
    local fontPath = sharedMedia and sharedMedia:Fetch("font", fontName, true)

    if type(fontPath) == "string" and fontPath ~= "" then
        return fontPath
    end

    return STANDARD_TEXT_FONT or addon.BuiltInFonts[1].path
end

addon.DefaultSettings = {
    locked = false,
    hideSettingsGear = false,
    showAtLogin = true,
    rememberMinimized = true,
    minimized = false,
    selectedCategory = 1,
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 100,
    width = 250,
    height = 250,
    sidebarWidth = 112,
    categoryFont = "Friz Quadrata",
    emoteFont = "Friz Quadrata",
    categoryFontSize = 12,
    emoteFontSize = 12,
    categoryTextColor = {r = 0.8, g = 0.8, b = 0.8},
    emoteTextColor = {r = 1.0, g = 1.0, b = 1.0},
    categoryHighlightColor = {r = 0.3, g = 0.25, b = 0.12},
    categoryHighlightEffect = "background",
    categoryHighlightThickness = 2,
    backgroundColor = {r = 0.12, g = 0.12, b = 0.12},
    borderColor = {r = 0.2, g = 0.2, b = 0.2},
    borderStyle = "thin",
    backgroundOpacity = 1.0,
    windowOpacity = 1.0,
    fadeEnabled = false,
    fadeDelay = 5,
    inactiveOpacity = 0.35,
    emoteDataVersion = 5
}

addon.EmoteAliases = {
    lol = "LAUGH",
    ty = "THANK"
}

addon.MAX_CATEGORIES = #addon.DefaultSections
addon.MAX_EMOTES = 10
addon.MIN_SIDEBAR_WIDTH = 60
addon.MAX_SIDEBAR_WIDTH = 220

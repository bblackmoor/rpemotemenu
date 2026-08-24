local _, addon = ...

addon.Database = {}

local Database = addon.Database
local defaultSections = addon.DefaultSections
local defaults = addon.DefaultSettings
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local MAX_EMOTES = addon.MAX_EMOTES

local function CopyDefaultCategories()
    local categories = {}

    for categoryIndex, sourceCategory in ipairs(defaultSections) do
        local category = {
            name = sourceCategory.name,
            emotes = {}
        }

        for emoteIndex = 1, MAX_EMOTES do
            local source = sourceCategory.emotes[emoteIndex]
            category.emotes[emoteIndex] = {
                label = source and source[1] or "",
                defaultCommand = source and source[2] or "",
                targetedCommand = source and source[3] or ""
            }
        end

        categories[categoryIndex] = category
    end

    return categories
end

-- SAVED SETTINGS
local function NormalizeCategories(categories)
    categories = type(categories) == "table" and categories or {}

    for categoryIndex = 1, MAX_CATEGORIES do
        local category = categories[categoryIndex]

        if type(category) ~= "table" then
            category = {name = "", emotes = {}}
            categories[categoryIndex] = category
        end

        category.name = category.name or ""
        category.emotes = type(category.emotes) == "table" and category.emotes or {}

        for emoteIndex = 1, MAX_EMOTES do
            local emote = category.emotes[emoteIndex]

            if type(emote) ~= "table" then
                emote = {}
                category.emotes[emoteIndex] = emote
            end

            emote.label = emote.label or ""
            emote.defaultCommand = emote.defaultCommand or ""
            emote.targetedCommand = emote.targetedCommand or ""
        end
    end

    return categories
end

local function CopyCategories(sourceCategories)
    local copy = {}

    for categoryIndex = 1, MAX_CATEGORIES do
        local sourceCategory = sourceCategories[categoryIndex] or {}
        local category = {
            name = sourceCategory.name or "",
            emotes = {}
        }

        for emoteIndex = 1, MAX_EMOTES do
            local sourceEmote =
                sourceCategory.emotes and sourceCategory.emotes[emoteIndex] or {}

            category.emotes[emoteIndex] = {
                label = sourceEmote.label or "",
                defaultCommand = sourceEmote.defaultCommand or "",
                targetedCommand = sourceEmote.targetedCommand or ""
            }
        end

        copy[categoryIndex] = category
    end

    return copy
end

local legacyDefaultCategoryNames = {
    THOUGHTS = "Thoughts",
    REACTIONS = "Reactions",
    CONVERSATION = "Conversation",
    GESTURES = "Gestures",
    POSTURES = "Postures"
}

local function MigrateLegacyCategoryNameCase(categories)
    if type(categories) ~= "table" then
        return
    end

    for categoryIndex = 1, MAX_CATEGORIES do
        local category = categories[categoryIndex]

        if category and legacyDefaultCategoryNames[category.name] then
            category.name = legacyDefaultCategoryNames[category.name]
        end
    end
end

function Database.InitializeDatabase()
    RPEmoteMenuDB = RPEmoteMenuDB or {}

    for key, value in pairs(defaults) do
        if key ~= "emoteDataVersion" and RPEmoteMenuDB[key] == nil then
            RPEmoteMenuDB[key] = value
        end
    end

    -- The database has two separate emote tables:
    --
    -- defaultCategories:
    --     A stored copy of the values supplied with this addon version.
    --
    -- categories:
    --     The editable current values. Both the options fields and the main
    --     addon window read from this table.
    --
    -- This migration fills BOTH tables with the current supplied values once.
    -- Later user changes affect only categories and are preserved, including
    -- deliberately blank fields.
    if RPEmoteMenuDB.emoteDataVersion ~= defaults.emoteDataVersion then
        local suppliedValues = CopyDefaultCategories()

        -- Refresh the reset source when the supplied defaults change, but
        -- preserve any existing user-edited categories.
        RPEmoteMenuDB.defaultCategories = CopyCategories(suppliedValues)

        if RPEmoteMenuDB.categories then
            MigrateLegacyCategoryNameCase(RPEmoteMenuDB.categories)
        end

        RPEmoteMenuDB.categories = NormalizeCategories(
            RPEmoteMenuDB.categories or CopyCategories(suppliedValues)
        )
        RPEmoteMenuDB.emoteDataVersion = defaults.emoteDataVersion
    else
        RPEmoteMenuDB.defaultCategories = NormalizeCategories(
            RPEmoteMenuDB.defaultCategories or CopyDefaultCategories()
        )

        RPEmoteMenuDB.categories = NormalizeCategories(
            RPEmoteMenuDB.categories
                or CopyCategories(RPEmoteMenuDB.defaultCategories)
        )
    end
end

function Database.ResetCategoryToDefaults(categoryIndex)
    -- Rebuild only this category from the defaults supplied in this Lua file.
    local suppliedDefaults = CopyDefaultCategories()
    local defaultCategory = suppliedDefaults[categoryIndex]

    RPEmoteMenuDB.defaultCategories[categoryIndex] = CopyCategories(suppliedDefaults)[categoryIndex]
    RPEmoteMenuDB.categories[categoryIndex] = {
        name = defaultCategory.name,
        emotes = {}
    }

    for emoteIndex = 1, MAX_EMOTES do
        local sourceEmote = defaultCategory.emotes[emoteIndex]
        RPEmoteMenuDB.categories[categoryIndex].emotes[emoteIndex] = {
            label = sourceEmote.label,
            defaultCommand = sourceEmote.defaultCommand,
            targetedCommand = sourceEmote.targetedCommand
        }
    end

    if addon.Settings.RefreshEditors then
        addon.Settings.RefreshEditors(categoryIndex)
    end

    addon.MainWindow.UpdateMenu()
end

function Database.ResetAllCategoriesToDefaults()
    local suppliedDefaults = CopyDefaultCategories()

    RPEmoteMenuDB.defaultCategories = CopyCategories(suppliedDefaults)
    RPEmoteMenuDB.categories = CopyCategories(suppliedDefaults)

    if addon.Settings.RefreshEditors then
        addon.Settings.RefreshEditors()
    end

    addon.MainWindow.SetSelectedCategory(1)
    addon.MainWindow.UpdateMenu()
end

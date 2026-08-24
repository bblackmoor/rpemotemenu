local _, addon = ...

addon.Database = {}

local Database = addon.Database
local defaultSections = addon.DefaultSections
local defaults = addon.DefaultSettings
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local MAX_EMOTES = addon.MAX_EMOTES
local SCHEMA_VERSION = 2
local DEFAULT_PROFILE_NAME = "Default"

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

local function CategoriesMatch(first, second)
    for categoryIndex = 1, MAX_CATEGORIES do
        local firstCategory = first[categoryIndex]
        local secondCategory = second[categoryIndex]

        if firstCategory.name ~= secondCategory.name then
            return false
        end

        for emoteIndex = 1, MAX_EMOTES do
            local firstEmote = firstCategory.emotes[emoteIndex]
            local secondEmote = secondCategory.emotes[emoteIndex]

            if firstEmote.label ~= secondEmote.label
                or firstEmote.defaultCommand ~= secondEmote.defaultCommand
                or firstEmote.targetedCommand ~= secondEmote.targetedCommand then
                return false
            end
        end
    end

    return true
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

function Database.GetSettings()
    return RPEmoteMenuDB
end

function Database.GetCharacterKey()
    local name, realm = UnitName("player")

    if not name or name == "" then
        return nil
    end

    if (not realm or realm == "") and GetRealmName then
        realm = GetRealmName()
    end

    if realm and realm ~= "" then
        return name .. "-" .. realm
    end

    return name
end

function Database.GetActiveProfileName()
    local characterKey = Database.GetCharacterKey()
    local profileName = characterKey and RPEmoteMenuDB.activeProfiles[characterKey]

    if type(profileName) ~= "string" then
        profileName = DEFAULT_PROFILE_NAME

        if characterKey then
            RPEmoteMenuDB.activeProfiles[characterKey] = profileName
        end
    end

    if type(RPEmoteMenuDB.profiles[profileName]) ~= "table" then
        profileName = DEFAULT_PROFILE_NAME

        if characterKey then
            RPEmoteMenuDB.activeProfiles[characterKey] = profileName
        end
    end

    return profileName
end

function Database.GetActiveProfile()
    return RPEmoteMenuDB.profiles[Database.GetActiveProfileName()]
end

function Database.GetCategories()
    return Database.GetActiveProfile().categories
end

function Database.GetCategory(categoryIndex)
    return Database.GetCategories()[categoryIndex]
end

local function PreserveCustomizedProfile(categories, characterKey)
    local baseName = characterKey or "Migrated"
    local profileName = baseName
    local suffix = 2

    while RPEmoteMenuDB.profiles[profileName] do
        profileName = baseName .. " (" .. suffix .. ")"
        suffix = suffix + 1
    end

    RPEmoteMenuDB.profiles[profileName] = {categories = categories}

    for savedCharacterKey, activeProfileName in pairs(RPEmoteMenuDB.activeProfiles) do
        if activeProfileName == DEFAULT_PROFILE_NAME then
            RPEmoteMenuDB.activeProfiles[savedCharacterKey] = profileName
        end
    end

    if characterKey and not RPEmoteMenuDB.activeProfiles[characterKey] then
        RPEmoteMenuDB.activeProfiles[characterKey] = profileName
    end

    return profileName
end

function Database.InitializeDatabase()
    RPEmoteMenuDB = RPEmoteMenuDB or {}

    for key, value in pairs(defaults) do
        if key ~= "emoteDataVersion" and RPEmoteMenuDB[key] == nil then
            RPEmoteMenuDB[key] = value
        end
    end

    -- The database stores supplied defaults separately from editable profiles:
    --
    -- defaultCategories:
    --     A stored copy of the values supplied with this addon version.
    --
    -- profiles[profileName].categories:
    --     The editable categories belonging to each named profile.
    --
    -- activeProfiles[characterName-realmName]:
    --     The profile currently associated with each character.
    --
    -- Default starts with the exact addon-supplied categories. Existing custom
    -- categories are preserved in a separate active profile during migration.
    local suppliedValues = CopyDefaultCategories()
    local defaultsChanged = RPEmoteMenuDB.emoteDataVersion ~= defaults.emoteDataVersion

    if defaultsChanged then
        RPEmoteMenuDB.defaultCategories = CopyCategories(suppliedValues)
        RPEmoteMenuDB.emoteDataVersion = defaults.emoteDataVersion
    else
        RPEmoteMenuDB.defaultCategories = NormalizeCategories(
            RPEmoteMenuDB.defaultCategories or CopyCategories(suppliedValues)
        )
    end

    if type(RPEmoteMenuDB.profiles) ~= "table" then
        RPEmoteMenuDB.profiles = {}
    end

    if type(RPEmoteMenuDB.activeProfiles) ~= "table" then
        RPEmoteMenuDB.activeProfiles = {}
    end

    local defaultProfile = RPEmoteMenuDB.profiles[DEFAULT_PROFILE_NAME]
    if type(defaultProfile) ~= "table" then
        defaultProfile = {}
        RPEmoteMenuDB.profiles[DEFAULT_PROFILE_NAME] = defaultProfile
    end

    if type(RPEmoteMenuDB.schemaVersion) ~= "number"
        or RPEmoteMenuDB.schemaVersion < SCHEMA_VERSION then
        local previousCategories = type(RPEmoteMenuDB.categories) == "table"
            and RPEmoteMenuDB.categories
            or defaultProfile.categories

        if type(previousCategories) == "table" then
            previousCategories = NormalizeCategories(previousCategories)

            if defaultsChanged then
                MigrateLegacyCategoryNameCase(previousCategories)
            end

            if not CategoriesMatch(previousCategories, suppliedValues) then
                PreserveCustomizedProfile(
                    previousCategories,
                    Database.GetCharacterKey()
                )
            end
        end

        defaultProfile.categories = CopyCategories(suppliedValues)
        RPEmoteMenuDB.categories = nil
        RPEmoteMenuDB.schemaVersion = SCHEMA_VERSION
    end

    defaultProfile.categories = NormalizeCategories(
        defaultProfile.categories or CopyCategories(RPEmoteMenuDB.defaultCategories)
    )

    for _, profile in pairs(RPEmoteMenuDB.profiles) do
        if type(profile) == "table" then
            if defaultsChanged then
                MigrateLegacyCategoryNameCase(profile.categories)
            end

            profile.categories = NormalizeCategories(
                profile.categories or CopyCategories(RPEmoteMenuDB.defaultCategories)
            )
        end
    end

    local characterKey = Database.GetCharacterKey()
    if characterKey then
        local profileName = RPEmoteMenuDB.activeProfiles[characterKey]

        if type(profileName) ~= "string"
            or type(RPEmoteMenuDB.profiles[profileName]) ~= "table" then
            RPEmoteMenuDB.activeProfiles[characterKey] = DEFAULT_PROFILE_NAME
        end
    end
end

function Database.ResetCategoryToDefaults(categoryIndex)
    -- Rebuild only this category from the defaults supplied in this Lua file.
    local suppliedDefaults = CopyDefaultCategories()
    local defaultCategory = suppliedDefaults[categoryIndex]

    local categories = Database.GetCategories()

    RPEmoteMenuDB.defaultCategories[categoryIndex] = CopyCategories(suppliedDefaults)[categoryIndex]
    categories[categoryIndex] = {
        name = defaultCategory.name,
        emotes = {}
    }

    for emoteIndex = 1, MAX_EMOTES do
        local sourceEmote = defaultCategory.emotes[emoteIndex]
        categories[categoryIndex].emotes[emoteIndex] = {
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
    Database.GetActiveProfile().categories = CopyCategories(suppliedDefaults)

    if addon.Settings.RefreshEditors then
        addon.Settings.RefreshEditors()
    end

    addon.MainWindow.SetSelectedCategory(1)
    addon.MainWindow.UpdateMenu()
end

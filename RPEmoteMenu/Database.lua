local _, addon = ...

addon.Database = {}

local Database = addon.Database
local defaultSections = addon.DefaultSections
local defaults = addon.DefaultSettings
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local MAX_EMOTES = addon.MAX_EMOTES
local SCHEMA_VERSION = 3
local DEFAULT_PROFILE_NAME = "Default"
local VALID_ANCHOR_POINTS = {
    TOPLEFT = true,
    TOP = true,
    TOPRIGHT = true,
    LEFT = true,
    CENTER = true,
    RIGHT = true,
    BOTTOMLEFT = true,
    BOTTOM = true,
    BOTTOMRIGHT = true
}

local function NormalizeString(value)
    return type(value) == "string" and value or ""
end

local function CopyDefaultCategories()
    local categories = {}

    for categoryIndex, sourceCategory in ipairs(defaultSections) do
        local category = {
            name = NormalizeString(sourceCategory.name),
            emotes = {}
        }

        for emoteIndex = 1, MAX_EMOTES do
            local source = sourceCategory.emotes[emoteIndex]
            category.emotes[emoteIndex] = {
                label = NormalizeString(source and source[1]),
                defaultCommand = NormalizeString(source and source[2]),
                targetedCommand = NormalizeString(source and source[3])
            }
        end

        categories[categoryIndex] = category
    end

    return categories
end

local function NormalizeCategories(categories)
    categories = type(categories) == "table" and categories or {}

    for categoryIndex = 1, MAX_CATEGORIES do
        local category = categories[categoryIndex]

        if type(category) ~= "table" then
            category = {}
            categories[categoryIndex] = category
        end

        category.name = NormalizeString(category.name)
        category.emotes = type(category.emotes) == "table" and category.emotes or {}

        for emoteIndex = 1, MAX_EMOTES do
            local emote = category.emotes[emoteIndex]

            if type(emote) ~= "table" then
                emote = {}
                category.emotes[emoteIndex] = emote
            end

            emote.label = NormalizeString(emote.label)
            emote.defaultCommand = NormalizeString(emote.defaultCommand)
            emote.targetedCommand = NormalizeString(emote.targetedCommand)
        end
    end

    return categories
end

local function IsValidSavedValue(value, defaultValue)
    if type(value) ~= type(defaultValue) then
        return false
    end

    if type(value) == "number" then
        return value == value and value ~= math.huge and value ~= -math.huge
    end

    return true
end

function Database.GetSettings()
    return RPEmoteMenuDB
end

function Database.GetCharacterKey()
    local name, realm = UnitName("player")

    if type(name) ~= "string" or name == "" then
        return nil
    end

    if (type(realm) ~= "string" or realm == "") and GetRealmName then
        realm = GetRealmName()
    end

    if type(realm) == "string" and realm ~= "" then
        return name .. "-" .. realm
    end

    return name
end

function Database.GetActiveProfileName()
    local characterKey = Database.GetCharacterKey()
    local profileName = characterKey and RPEmoteMenuDB.activeProfiles[characterKey]

    if type(profileName) ~= "string"
        or type(RPEmoteMenuDB.profiles[profileName]) ~= "table" then
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

function Database.IsDefaultProfile()
    return Database.GetActiveProfileName() == DEFAULT_PROFILE_NAME
end

function Database.CanEditActiveProfile()
    return not Database.IsDefaultProfile()
end

function Database.GetCategories()
    return Database.GetActiveProfile().categories
end

function Database.GetCategory(categoryIndex)
    return Database.GetCategories()[categoryIndex]
end

function Database.InitializeDatabase()
    RPEmoteMenuDB = type(RPEmoteMenuDB) == "table" and RPEmoteMenuDB or {}

    for key, defaultValue in pairs(defaults) do
        if key ~= "emoteDataVersion"
            and not IsValidSavedValue(RPEmoteMenuDB[key], defaultValue) then
            RPEmoteMenuDB[key] = defaultValue
        end
    end

    if not VALID_ANCHOR_POINTS[RPEmoteMenuDB.point] then
        RPEmoteMenuDB.point = defaults.point
    end

    if not VALID_ANCHOR_POINTS[RPEmoteMenuDB.relativePoint] then
        RPEmoteMenuDB.relativePoint = defaults.relativePoint
    end

    -- Legacy pre-profile categories are intentionally discarded. Existing valid
    -- named profiles remain available, and Default is rebuilt every login so it
    -- always reflects the categories currently supplied by the addon.
    RPEmoteMenuDB.categories = nil
    RPEmoteMenuDB.profiles = type(RPEmoteMenuDB.profiles) == "table"
        and RPEmoteMenuDB.profiles
        or {}
    RPEmoteMenuDB.activeProfiles = type(RPEmoteMenuDB.activeProfiles) == "table"
        and RPEmoteMenuDB.activeProfiles
        or {}

    local invalidProfiles = {}
    for profileName, profile in pairs(RPEmoteMenuDB.profiles) do
        if type(profileName) ~= "string"
            or profileName == ""
            or type(profile) ~= "table" then
            invalidProfiles[#invalidProfiles + 1] = profileName
        elseif profileName ~= DEFAULT_PROFILE_NAME then
            profile.categories = type(profile.categories) == "table"
                and NormalizeCategories(profile.categories)
                or CopyDefaultCategories()
        end
    end

    for _, profileName in ipairs(invalidProfiles) do
        RPEmoteMenuDB.profiles[profileName] = nil
    end

    RPEmoteMenuDB.defaultCategories = CopyDefaultCategories()
    RPEmoteMenuDB.profiles[DEFAULT_PROFILE_NAME] = {
        categories = CopyDefaultCategories()
    }
    RPEmoteMenuDB.emoteDataVersion = defaults.emoteDataVersion
    RPEmoteMenuDB.schemaVersion = SCHEMA_VERSION

    local invalidCharacterKeys = {}
    for characterKey, profileName in pairs(RPEmoteMenuDB.activeProfiles) do
        if type(characterKey) ~= "string" or characterKey == "" then
            invalidCharacterKeys[#invalidCharacterKeys + 1] = characterKey
        elseif type(profileName) ~= "string"
            or type(RPEmoteMenuDB.profiles[profileName]) ~= "table" then
            RPEmoteMenuDB.activeProfiles[characterKey] = DEFAULT_PROFILE_NAME
        end
    end

    for _, characterKey in ipairs(invalidCharacterKeys) do
        RPEmoteMenuDB.activeProfiles[characterKey] = nil
    end

    local characterKey = Database.GetCharacterKey()
    if characterKey and not RPEmoteMenuDB.activeProfiles[characterKey] then
        RPEmoteMenuDB.activeProfiles[characterKey] = DEFAULT_PROFILE_NAME
    end
end

function Database.ResetCategoryToDefaults(categoryIndex)
    if not Database.CanEditActiveProfile() then
        return false
    end

    local suppliedDefaults = CopyDefaultCategories()
    Database.GetCategories()[categoryIndex] = suppliedDefaults[categoryIndex]

    if addon.Settings.RefreshEditors then
        addon.Settings.RefreshEditors(categoryIndex)
    end

    addon.MainWindow.UpdateMenu()
    return true
end

function Database.ResetAllCategoriesToDefaults()
    if not Database.CanEditActiveProfile() then
        return false
    end

    Database.GetActiveProfile().categories = CopyDefaultCategories()

    if addon.Settings.RefreshEditors then
        addon.Settings.RefreshEditors()
    end

    addon.MainWindow.SetSelectedCategory(1)
    addon.MainWindow.UpdateMenu()
    return true
end

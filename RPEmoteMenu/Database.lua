local _, addon = ...

addon.Database = {}

local Database = addon.Database
local defaultSections = addon.DefaultSections
local defaults = addon.DefaultSettings
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local MAX_EMOTES = addon.MAX_EMOTES
local SCHEMA_VERSION = 3
local DEFAULT_PROFILE_NAME = "Default"
local MAX_PROFILE_NAME_LENGTH = 64
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

local function CopyCategories(sourceCategories)
    local categories = {}

    for categoryIndex = 1, MAX_CATEGORIES do
        local sourceCategory = sourceCategories[categoryIndex]
        local category = {
            name = NormalizeString(sourceCategory and sourceCategory.name),
            emotes = {}
        }

        for emoteIndex = 1, MAX_EMOTES do
            local source = sourceCategory
                and sourceCategory.emotes
                and sourceCategory.emotes[emoteIndex]

            category.emotes[emoteIndex] = {
                label = NormalizeString(source and source.label),
                defaultCommand = NormalizeString(source and source.defaultCommand),
                targetedCommand = NormalizeString(source and source.targetedCommand)
            }
        end

        categories[categoryIndex] = category
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

local function FindProfileByName(profileName)
    local requestedName = string.lower(profileName)

    for existingName in pairs(RPEmoteMenuDB.profiles) do
        if string.lower(existingName) == requestedName then
            return existingName
        end
    end

    return nil
end

local function ValidateNewProfileName(profileName, existingProfileName)
    if type(profileName) ~= "string" then
        return nil, "Enter a profile name."
    end

    profileName = strtrim(profileName)

    if profileName == "" then
        return nil, "Enter a profile name."
    end

    if #profileName > MAX_PROFILE_NAME_LENGTH then
        return nil, "Profile names cannot exceed 64 characters."
    end

    if string.lower(profileName) == string.lower(DEFAULT_PROFILE_NAME) then
        return nil, "Default is reserved and cannot be changed."
    end

    local matchingProfile = FindProfileByName(profileName)
    if matchingProfile and matchingProfile ~= existingProfileName then
        return nil, "A profile with that name already exists."
    end

    if matchingProfile == existingProfileName and profileName == existingProfileName then
        return nil, "Enter a different profile name."
    end

    return profileName
end

function Database.ValidateNewProfileName(profileName)
    return ValidateNewProfileName(profileName)
end

local function RefreshProfileViews()
    if addon.MainWindow and addon.MainWindow.SetSelectedCategory then
        addon.MainWindow.SetSelectedCategory(1)
    end

    if addon.MainWindow and addon.MainWindow.UpdateMenu then
        addon.MainWindow.UpdateMenu()
    end

    if addon.Settings and addon.Settings.RefreshEditors then
        addon.Settings.RefreshEditors()
    end

    if addon.Settings and addon.Settings.RefreshProfiles then
        addon.Settings.RefreshProfiles()
    end
end

function Database.GetProfileNames()
    local names = {}

    for profileName in pairs(RPEmoteMenuDB.profiles) do
        names[#names + 1] = profileName
    end

    table.sort(names, function(first, second)
        if first == DEFAULT_PROFILE_NAME then
            return true
        end

        if second == DEFAULT_PROFILE_NAME then
            return false
        end

        local firstLower = string.lower(first)
        local secondLower = string.lower(second)

        if firstLower == secondLower then
            return first < second
        end

        return firstLower < secondLower
    end)

    return names
end

function Database.SetActiveProfile(profileName)
    if type(profileName) ~= "string"
        or type(RPEmoteMenuDB.profiles[profileName]) ~= "table" then
        return false, "That profile does not exist."
    end

    local characterKey = Database.GetCharacterKey()
    if not characterKey then
        return false, "Your character is not available yet."
    end

    RPEmoteMenuDB.activeProfiles[characterKey] = profileName
    RefreshProfileViews()
    return true
end

function Database.CreateProfile(profileName, sourceCategories)
    local validName, errorMessage = ValidateNewProfileName(profileName)
    if not validName then
        return false, errorMessage
    end

    local characterKey = Database.GetCharacterKey()
    if not characterKey then
        return false, "Your character is not available yet."
    end

    RPEmoteMenuDB.profiles[validName] = {
        categories = type(sourceCategories) == "table"
            and CopyCategories(sourceCategories)
            or CopyDefaultCategories()
    }
    RPEmoteMenuDB.activeProfiles[characterKey] = validName

    RefreshProfileViews()
    return true, validName
end

function Database.CopyProfile(sourceProfileName, newProfileName)
    local source = RPEmoteMenuDB.profiles[sourceProfileName]
    if type(source) ~= "table" then
        return false, "The source profile does not exist."
    end

    local validName, errorMessage = ValidateNewProfileName(newProfileName)
    if not validName then
        return false, errorMessage
    end

    local characterKey = Database.GetCharacterKey()
    if not characterKey then
        return false, "Your character is not available yet."
    end

    RPEmoteMenuDB.profiles[validName] = {
        categories = CopyCategories(source.categories)
    }
    RPEmoteMenuDB.activeProfiles[characterKey] = validName

    RefreshProfileViews()
    return true, validName
end

function Database.RenameProfile(oldProfileName, newProfileName)
    if oldProfileName == DEFAULT_PROFILE_NAME then
        return false, "The Default profile cannot be renamed."
    end

    local profile = RPEmoteMenuDB.profiles[oldProfileName]
    if type(profile) ~= "table" then
        return false, "That profile does not exist."
    end

    local validName, errorMessage = ValidateNewProfileName(newProfileName, oldProfileName)
    if not validName then
        return false, errorMessage
    end

    RPEmoteMenuDB.profiles[validName] = profile
    RPEmoteMenuDB.profiles[oldProfileName] = nil

    for characterKey, activeProfileName in pairs(RPEmoteMenuDB.activeProfiles) do
        if activeProfileName == oldProfileName then
            RPEmoteMenuDB.activeProfiles[characterKey] = validName
        end
    end

    RefreshProfileViews()
    return true, validName
end

function Database.DeleteProfile(profileName)
    if profileName == DEFAULT_PROFILE_NAME then
        return false, "The Default profile cannot be deleted."
    end

    if type(RPEmoteMenuDB.profiles[profileName]) ~= "table" then
        return false, "That profile does not exist."
    end

    RPEmoteMenuDB.profiles[profileName] = nil

    for characterKey, activeProfileName in pairs(RPEmoteMenuDB.activeProfiles) do
        if activeProfileName == profileName then
            RPEmoteMenuDB.activeProfiles[characterKey] = DEFAULT_PROFILE_NAME
        end
    end

    RefreshProfileViews()
    return true
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

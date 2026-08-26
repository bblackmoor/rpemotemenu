local _, addon = ...

addon.Database = {}

local Database = addon.Database
local defaultSections = addon.DefaultSections
local defaults = addon.DefaultSettings
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local MAX_EMOTES = addon.MAX_EMOTES
local SCHEMA_VERSION = 6
local DEFAULT_PROFILE_NAME = "Default"
local MAX_PROFILE_NAME_LENGTH = 64

local VALID_CATEGORY_HIGHLIGHT_EFFECTS = {
    background = true,
    outline = true,
    underline = true,
    shadow = true,
    separator = true
}
local VALID_BORDER_STYLES = {none = true, thin = true, blizzard = true}
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
local COLOR_SETTING_KEYS = {
    "categoryTextColor",
    "selectedCategoryTextColor",
    "emoteTextColor",
    "categoryHighlightColor",
    "categoryBackgroundColor",
    "emoteBackgroundColor",
    "borderColor"
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
    sourceCategories = type(sourceCategories) == "table" and sourceCategories or {}

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


local function ClampNumber(value, minimum, maximum, defaultValue)
    value = tonumber(value)

    if not value or value ~= value or value == math.huge or value == -math.huge then
        value = defaultValue
    end

    return math.max(minimum, math.min(maximum, value))
end


local function NormalizeColor(value, defaultValue)
    value = type(value) == "table" and value or {}

    return {
        r = ClampNumber(value.r, 0, 1, defaultValue.r),
        g = ClampNumber(value.g, 0, 1, defaultValue.g),
        b = ClampNumber(value.b, 0, 1, defaultValue.b)
    }
end


local function NormalizeSettings(source)
    source = type(source) == "table" and source or {}
    local result = {}

    for key, defaultValue in pairs(defaults) do
        if key ~= "emoteDataVersion" and type(defaultValue) ~= "table" then
            result[key] = IsValidSavedValue(source[key], defaultValue)
                and source[key]
                or defaultValue
        end
    end

    result.height = math.floor(ClampNumber(source.height, 150, 600, defaults.height))
    result.x = math.floor(ClampNumber(source.x, -100000, 100000, defaults.x))
    result.y = math.floor(ClampNumber(source.y, -100000, 100000, defaults.y))

    if not VALID_ANCHOR_POINTS[result.point] then
        result.point = defaults.point
    end
    if not VALID_ANCHOR_POINTS[result.relativePoint] then
        result.relativePoint = defaults.relativePoint
    end
    if result.selectedCategory % 1 ~= 0
        or result.selectedCategory < 1
        or result.selectedCategory > MAX_CATEGORIES then
        result.selectedCategory = defaults.selectedCategory
    end

    result.sidebarWidth = math.floor(ClampNumber(
        source.sidebarWidth,
        addon.MIN_SIDEBAR_WIDTH,
        addon.MAX_SIDEBAR_WIDTH,
        defaults.sidebarWidth
    ))
    result.emoteColumnWidth = math.floor(ClampNumber(
        source.emoteColumnWidth,
        addon.MIN_EMOTE_COLUMN_WIDTH,
        addon.MAX_EMOTE_COLUMN_WIDTH,
        defaults.emoteColumnWidth
    ))
    result.width = result.sidebarWidth
        + result.emoteColumnWidth
        + addon.COLUMN_CHROME_WIDTH

    if strtrim(result.categoryFont) == "" then
        result.categoryFont = defaults.categoryFont
    end
    if strtrim(result.emoteFont) == "" then
        result.emoteFont = defaults.emoteFont
    end

    result.categoryFontSize = math.floor(ClampNumber(
        source.categoryFontSize, 8, 24, defaults.categoryFontSize
    ))
    result.emoteFontSize = math.floor(ClampNumber(
        source.emoteFontSize, 8, 24, defaults.emoteFontSize
    ))
    result.categoryHighlightThickness = math.floor(ClampNumber(
        source.categoryHighlightThickness,
        1,
        6,
        defaults.categoryHighlightThickness
    ))

    for _, key in ipairs(COLOR_SETTING_KEYS) do
        result[key] = NormalizeColor(source[key], defaults[key])
    end

    if not VALID_CATEGORY_HIGHLIGHT_EFFECTS[result.categoryHighlightEffect] then
        result.categoryHighlightEffect = defaults.categoryHighlightEffect
    end
    if not VALID_BORDER_STYLES[result.borderStyle] then
        result.borderStyle = defaults.borderStyle
    end

    result.backgroundOpacity = ClampNumber(
        source.backgroundOpacity, 0, 1, defaults.backgroundOpacity
    )
    result.windowOpacity = ClampNumber(
        source.windowOpacity, 0.1, 1, defaults.windowOpacity
    )
    result.fadeDelay = math.floor(ClampNumber(
        source.fadeDelay, 0, 60, defaults.fadeDelay
    ))
    result.inactiveOpacity = math.min(
        ClampNumber(source.inactiveOpacity, 0.1, 1, defaults.inactiveOpacity),
        result.windowOpacity
    )

    return result
end


local function CopySettings(source)
    return NormalizeSettings(source)
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


function Database.GetProfile(profileName)
    return RPEmoteMenuDB.profiles[profileName]
end


function Database.GetProfiles()
    return RPEmoteMenuDB.profiles
end


function Database.GetSettings()
    return Database.GetActiveProfile().settings
end


function Database.CopySettings(source)
    return CopySettings(source)
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


function Database.ValidateNewProfileName(profileName, existingProfileName)
    return ValidateNewProfileName(profileName, existingProfileName)
end


local function RefreshProfileViews()
    if addon.MainWindow and addon.MainWindow.ApplyProfileSettings then
        addon.MainWindow.ApplyProfileSettings()
    elseif addon.MainWindow and addon.MainWindow.UpdateMenu then
        addon.MainWindow.UpdateMenu()
    end

    if addon.Settings and addon.Settings.RefreshSettingsPanels then
        addon.Settings.RefreshSettingsPanels()
    else
        if addon.Settings and addon.Settings.RefreshEditors then
            addon.Settings.RefreshEditors()
        end
        if addon.Settings and addon.Settings.RefreshProfiles then
            addon.Settings.RefreshProfiles()
        end
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
        return firstLower == secondLower and first < second or firstLower < secondLower
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


function Database.CreateProfile(profileName, sourceCategories, sourceSettings)
    local validName, errorMessage = ValidateNewProfileName(profileName)
    if not validName then
        return false, errorMessage
    end

    local characterKey = Database.GetCharacterKey()
    if not characterKey then
        return false, "Your character is not available yet."
    end

    local settingsSource = type(sourceSettings) == "table"
        and sourceSettings
        or Database.GetSettings()

    RPEmoteMenuDB.profiles[validName] = {
        categories = type(sourceCategories) == "table"
            and CopyCategories(sourceCategories)
            or CopyDefaultCategories(),
        settings = CopySettings(settingsSource)
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

    return Database.CreateProfile(newProfileName, source.categories, source.settings)
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


local function ImportedProfileName(sourceName)
    local baseName = strtrim(sourceName or "")
    if baseName == "" then
        baseName = "Imported Profile"
    end

    if string.lower(baseName) ~= string.lower(DEFAULT_PROFILE_NAME)
        and not FindProfileByName(baseName) then
        return baseName
    end

    local number = 1
    while true do
        local suffix = number == 1
            and " (Imported)"
            or " (Imported " .. number .. ")"
        local shortenedBase = strtrim(baseName:sub(1, MAX_PROFILE_NAME_LENGTH - #suffix))
        local candidate = shortenedBase .. suffix

        if not FindProfileByName(candidate) then
            return candidate
        end

        number = number + 1
    end
end


function Database.AddImportedProfiles(importedProfiles)
    local createdNames = {}

    for _, imported in ipairs(importedProfiles or {}) do
        local profileName = ImportedProfileName(imported.name)
        RPEmoteMenuDB.profiles[profileName] = {
            categories = CopyCategories(imported.categories),
            settings = CopySettings(imported.settings)
        }
        createdNames[#createdNames + 1] = profileName
    end

    RefreshProfileViews()
    return createdNames
end


function Database.InitializeDatabase()
    RPEmoteMenuDB = type(RPEmoteMenuDB) == "table" and RPEmoteMenuDB or {}

    RPEmoteMenuDB.profiles = type(RPEmoteMenuDB.profiles) == "table"
        and RPEmoteMenuDB.profiles
        or {}
    RPEmoteMenuDB.activeProfiles = type(RPEmoteMenuDB.activeProfiles) == "table"
        and RPEmoteMenuDB.activeProfiles
        or {}

    local existingDefault = RPEmoteMenuDB.profiles[DEFAULT_PROFILE_NAME]
    local defaultSettings = existingDefault and existingDefault.settings
        and NormalizeSettings(existingDefault.settings)
        or CopySettings(defaults)

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
            profile.settings = type(profile.settings) == "table"
                and NormalizeSettings(profile.settings)
                or CopySettings(defaults)
        end
    end

    for _, profileName in ipairs(invalidProfiles) do
        RPEmoteMenuDB.profiles[profileName] = nil
    end

    RPEmoteMenuDB.defaultCategories = CopyDefaultCategories()
    RPEmoteMenuDB.profiles[DEFAULT_PROFILE_NAME] = {
        categories = CopyDefaultCategories(),
        settings = defaultSettings
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

    Database.GetCategories()[categoryIndex] = CopyDefaultCategories()[categoryIndex]

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

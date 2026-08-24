local _, addon = ...

local Serialization = {}
addon.Serialization = Serialization

local Database = addon.Database
local JSON = addon.JSON
local FORMAT_NAME = "RPEmoteMenu"
local FORMAT_VERSION = 1
local MAX_DOCUMENT_BYTES = 512 * 1024
local MAX_PROFILE_NAME_LENGTH = 64
local MAX_CATEGORY_NAME_LENGTH = 128
local MAX_LABEL_LENGTH = 128
local MAX_COMMAND_LENGTH = 4096

local ENVELOPE_FIELDS = {
    format = true,
    version = true,
    type = true,
    name = true,
    emotes = true,
    categories = true
}

local CATEGORY_FIELDS = {name = true, emotes = true}
local EMOTE_FIELDS = {label = true, defaultCommand = true, targetedCommand = true}

local function ValidateObject(value, allowedFields, description)
    if type(value) ~= "table" or JSON.IsArray(value) or value == JSON.Null then
        return nil, description .. " must be an object."
    end

    for key in pairs(value) do
        if not allowedFields[key] then
            return nil, description .. " contains an unsupported field: " .. tostring(key) .. "."
        end
    end

    return true
end

local function ValidateString(value, maximumLength, description)
    if type(value) ~= "string" then
        return nil, description .. " must be a string."
    end

    if #value > maximumLength then
        return nil, description .. " exceeds " .. maximumLength .. " characters."
    end

    return value
end

local function BlankEmote()
    return {label = "", defaultCommand = "", targetedCommand = ""}
end

local function ValidateEmote(value, index)
    local description = "Emote " .. index
    local valid, errorMessage = ValidateObject(value, EMOTE_FIELDS, description)
    if not valid then
        return nil, errorMessage
    end

    local label
    label, errorMessage = ValidateString(value.label, MAX_LABEL_LENGTH, description .. " label")
    if not label then
        return nil, errorMessage
    end

    local defaultCommand
    defaultCommand, errorMessage = ValidateString(
        value.defaultCommand,
        MAX_COMMAND_LENGTH,
        description .. " default command"
    )
    if not defaultCommand then
        return nil, errorMessage
    end

    local targetedCommand = value.targetedCommand
    if targetedCommand == nil then
        targetedCommand = ""
    else
        targetedCommand, errorMessage = ValidateString(
            targetedCommand,
            MAX_COMMAND_LENGTH,
            description .. " targeted command"
        )
        if not targetedCommand then
            return nil, errorMessage
        end
    end

    return {
        label = label,
        defaultCommand = defaultCommand,
        targetedCommand = targetedCommand
    }
end

local function ValidateCategory(value, description, envelope)
    local valid, errorMessage = ValidateObject(
        value,
        envelope and ENVELOPE_FIELDS or CATEGORY_FIELDS,
        description
    )
    if not valid then
        return nil, errorMessage
    end

    local name
    name, errorMessage = ValidateString(value.name, MAX_CATEGORY_NAME_LENGTH, description .. " name")
    if not name then
        return nil, errorMessage
    end

    if not JSON.IsArray(value.emotes) then
        return nil, description .. " emotes must be an array."
    end

    if #value.emotes > addon.MAX_EMOTES then
        return nil, description .. " cannot contain more than " .. addon.MAX_EMOTES .. " emotes."
    end

    local category = {name = name, emotes = {}}

    for index = 1, addon.MAX_EMOTES do
        if index <= #value.emotes then
            local emote
            emote, errorMessage = ValidateEmote(value.emotes[index], index)
            if not emote then
                return nil, errorMessage
            end

            category.emotes[index] = emote
        else
            category.emotes[index] = BlankEmote()
        end
    end

    return category
end

local function ExportCategoryData(category)
    local emotes = JSON.Array()
    local lastPopulated = 0

    for index = 1, addon.MAX_EMOTES do
        local emote = category.emotes[index]
        if emote.label ~= ""
            or emote.defaultCommand ~= ""
            or emote.targetedCommand ~= "" then
            lastPopulated = index
        end
    end

    for index = 1, lastPopulated do
        local source = category.emotes[index]
        local emote = {
            label = source.label,
            defaultCommand = source.defaultCommand
        }

        if source.targetedCommand ~= "" then
            emote.targetedCommand = source.targetedCommand
        end

        emotes[index] = emote
    end

    return {name = category.name, emotes = emotes}
end

local function IsValidCategoryIndex(categoryIndex)
    return type(categoryIndex) == "number"
        and categoryIndex % 1 == 0
        and categoryIndex >= 1
        and categoryIndex <= addon.MAX_CATEGORIES
end

function Serialization.ExportCategory(categoryIndex)
    if not IsValidCategoryIndex(categoryIndex) then
        return nil, "Choose a valid category to export."
    end

    local result = ExportCategoryData(Database.GetCategory(categoryIndex))
    result.format = FORMAT_NAME
    result.version = FORMAT_VERSION
    result.type = "category"

    return JSON.Encode(result, true)
end

function Serialization.ExportProfile()
    local categories = JSON.Array()

    for index = 1, addon.MAX_CATEGORIES do
        categories[index] = ExportCategoryData(Database.GetCategory(index))
    end

    return JSON.Encode({
        format = FORMAT_NAME,
        version = FORMAT_VERSION,
        type = "profile",
        name = Database.GetActiveProfileName(),
        categories = categories
    }, true)
end

function Serialization.Decode(text, expectedType)
    if type(text) ~= "string" or text == "" then
        return nil, "Paste exported RP Emote Menu data."
    end

    if #text > MAX_DOCUMENT_BYTES then
        return nil, "The imported data exceeds the maximum supported size."
    end

    local value, errorMessage = JSON.Decode(text)
    if not value then
        return nil, "Invalid JSON: " .. errorMessage
    end

    local valid
    valid, errorMessage = ValidateObject(value, ENVELOPE_FIELDS, "Import data")
    if not valid then
        return nil, errorMessage
    end

    if value.format ~= FORMAT_NAME then
        return nil, "This data was not exported by RP Emote Menu."
    end

    if value.version ~= FORMAT_VERSION then
        return nil, "This import format version is not supported."
    end

    if value.type ~= "category" and value.type ~= "profile" then
        return nil, "The import data has an unsupported type."
    end

    if expectedType and value.type ~= expectedType then
        return nil, "This is " .. value.type .. " data, not " .. expectedType .. " data."
    end

    if value.type == "category" then
        if value.categories ~= nil then
            return nil, "Category data cannot contain profile categories."
        end

        local category
        category, errorMessage = ValidateCategory(value, "Category", true)
        if not category then
            return nil, errorMessage
        end

        return {type = "category", name = category.name, category = category}
    end

    if value.emotes ~= nil then
        return nil, "Profile data cannot contain category-level emotes."
    end

    local profileName
    profileName, errorMessage = ValidateString(value.name, MAX_PROFILE_NAME_LENGTH, "Profile name")
    if not profileName then
        return nil, errorMessage
    end

    if profileName == "" then
        return nil, "Profile name cannot be empty."
    end

    if not JSON.IsArray(value.categories) then
        return nil, "Profile categories must be an array."
    end

    if #value.categories == 0 or #value.categories > addon.MAX_CATEGORIES then
        return nil, "Profiles must contain between 1 and " .. addon.MAX_CATEGORIES .. " categories."
    end

    local categories = {}

    for index = 1, addon.MAX_CATEGORIES do
        if index <= #value.categories then
            local category
            category, errorMessage = ValidateCategory(value.categories[index], "Category " .. index)
            if not category then
                return nil, errorMessage
            end

            categories[index] = category
        else
            local emotes = {}
            for emoteIndex = 1, addon.MAX_EMOTES do
                emotes[emoteIndex] = BlankEmote()
            end

            categories[index] = {name = "", emotes = emotes}
        end
    end

    return {type = "profile", name = profileName, categories = categories}
end

function Serialization.ImportCategory(categoryIndex, text)
    if not Database.CanEditActiveProfile() then
        return false, "The Default profile cannot receive imports."
    end

    if not IsValidCategoryIndex(categoryIndex) then
        return false, "Choose a valid category to import."
    end

    local imported, errorMessage = Serialization.Decode(text, "category")
    if not imported then
        return false, errorMessage
    end

    Database.GetCategories()[categoryIndex] = imported.category

    if addon.Settings and addon.Settings.RefreshEditors then
        addon.Settings.RefreshEditors(categoryIndex)
    end

    if addon.MainWindow and addon.MainWindow.UpdateMenu then
        addon.MainWindow.UpdateMenu()
    end

    return true, imported.name
end

function Serialization.ImportProfile(text)
    if not Database.CanEditActiveProfile() then
        return false, "The Default profile cannot receive imports."
    end

    local imported, errorMessage = Serialization.Decode(text, "profile")
    if not imported then
        return false, errorMessage
    end

    Database.GetActiveProfile().categories = imported.categories

    if addon.Settings and addon.Settings.RefreshEditors then
        addon.Settings.RefreshEditors()
    end

    if addon.MainWindow and addon.MainWindow.SetSelectedCategory then
        addon.MainWindow.SetSelectedCategory(1)
    end

    if addon.MainWindow and addon.MainWindow.UpdateMenu then
        addon.MainWindow.UpdateMenu()
    end

    return true, imported.name
end

local Event = require("ui/event")
local FileManager = require("apps/filemanager/filemanager")
local ReaderUI = require("apps/reader/readerui")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local background_color = require("ui/background_color")
local background_image_menu = require("ui/background_image")
local font_color = require("ui/font_color")
local font_face_menu = require("ui/font_face")
local dict_font_face_menu = require("ui/dict_font_face")
local transparency_menu = require("ui/transparency")

local function ui_menu()
    return {
        text = "User interface",
        sub_item_table = {
            background_color.menu(),
            background_image_menu(),
            font_color.menu(),
            font_face_menu(),
            dict_font_face_menu(),
            transparency_menu(),
        }
    }
end

-- Helpers that call events
local function recomputeAllColors()
    UIManager:broadcastEvent(Event:new("RecomputeAllColors"))
end

local function refreshFileManager()
    if FileManager.instance then
        FileManager.instance.file_chooser:updateItems(1, true)
    end
end

-- Hook into night mode state changes and refresh page
local original_UIManager_ToggleNightMode = UIManager.ToggleNightMode
function UIManager:ToggleNightMode()
    original_UIManager_ToggleNightMode(self)

    recomputeAllColors()

    if background_color.needsFileManagerRefresh(true) or font_color.needsFileManagerRefresh(true) then
        refreshFileManager()
    end
end

local original_UIManager_SetNightMode = UIManager.SetNightMode
function UIManager:SetNightMode(night_mode)
    original_UIManager_SetNightMode(self)

    if Screen.night_mode ~= night_mode then
        recomputeAllColors()

        if background_color.needsFileManagerRefresh(true) or font_color.needsFileManagerRefresh(true) then
            refreshFileManager()
        end
    end
end

local original_FileManager_onApplyTheme = FileManager.onApplyTheme
function FileManager:onApplyTheme()
    if original_FileManager_onApplyTheme then
        original_FileManager_onApplyTheme(self)
    end

    recomputeAllColors()

    if background_color.needsFileManagerRefresh(false) or font_color.needsFileManagerRefresh(false) then
        refreshFileManager()
    end
end

local original_ReaderUI_onApplyTheme = ReaderUI.onApplyTheme
function ReaderUI:onApplyTheme()
    if original_ReaderUI_onApplyTheme then
        original_ReaderUI_onApplyTheme(self)
    end

    recomputeAllColors()
end

return ui_menu

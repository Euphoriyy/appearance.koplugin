local Event = require("ui/event")
local FileManager = require("apps/filemanager/filemanager")
local ReaderUI = require("apps/reader/readerui")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local background_color = require("ui/background_color")
local background_image_menu = require("ui/background_image")
local common = require("lib/common")
local font_color = require("ui/font_color")
local font_face_menu = require("ui/font_face")
local dict_font_face_menu = require("ui/dict_font_face")
local misc_menu = require("ui/misc")
local nf_icons = require("lib/nf_icons")
local transparency_menu = require("ui/transparency")
local _ = require("gettext")

local function ui_menu()
    return {
        text_func = function() return nf_icons.label(nf_icons.MENU, _("User interface")) end,
        sub_item_table = {
            background_color.menu(),
            common.add_separator(font_color.menu()),
            common.add_separator(background_image_menu()),
            font_face_menu(),
            common.add_separator(dict_font_face_menu()),
            transparency_menu(),
            misc_menu(),
        }
    }
end

-- Helpers that call events
local function recomputeAllColors()
    UIManager:broadcastEvent(Event:new("RecomputeAllColors"))
end

-- Hook into night mode state changes and refresh page
local original_UIManager_ToggleNightMode = UIManager.ToggleNightMode
function UIManager:ToggleNightMode()
    original_UIManager_ToggleNightMode(self)

    recomputeAllColors()

    if background_color.needsFileManagerRefresh(true) or font_color.needsFileManagerRefresh(true) then
        common.refreshFileManager()
    end
end

local original_UIManager_SetNightMode = UIManager.SetNightMode
function UIManager:SetNightMode(night_mode)
    original_UIManager_SetNightMode(self)

    if Screen.night_mode ~= night_mode then
        recomputeAllColors()

        if background_color.needsFileManagerRefresh(true) or font_color.needsFileManagerRefresh(true) then
            common.refreshFileManager()
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
        common.refreshFileManager()
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

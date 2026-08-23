local Event = require("ui/event")
local ReaderRolling = require("apps/reader/modules/readerrolling")
local ReaderTypeset = require("apps/reader/modules/readertypeset")
local ReaderUI = require("apps/reader/readerui")
local Screen = require("device").screen
local Setting = require("lib/setting")
local UIManager = require("ui/uimanager")
local background_color_menu = require("book/background_color").menu
local common = require("lib/common")
local font_color_menu = require("book/font_color").menu
local highlight_colors_menu = require("book/highlight_colors")
local link_color_menu = require("book/link_color").menu
local progress_bar_colors_menu = require("book/progress_bar_colors")
local progress_bar_roundness_menu = require("book/progress_bar_roundness")

local function book_menu()
    return {
        text = "Book",
        sub_item_table = {
            background_color_menu(),
            font_color_menu(),
            link_color_menu(),
            highlight_colors_menu(),
            progress_bar_colors_menu(),
            progress_bar_roundness_menu(),
        }
    }
end

-- Setting for the Book background color
local FixedBackgroundColor = Setting("book_background_color_fixed", true)

-- Helpers that call events
local function recomputeAllColors()
    UIManager:broadcastEvent(Event:new("RecomputeAllColors"))
end

local function refreshCSS()
    if ReaderUI.instance and ReaderUI.instance.rolling then
        UIManager:broadcastEvent(Event:new("ApplyStyleSheet"))
    end
end

local function redrawPage()
    if ReaderUI.instance and ReaderUI.instance.paging then
        UIManager:broadcastEvent(Event:new("RedrawCurrentPage"))
    end
end

-- Hook into night mode state changes and refresh page
local original_UIManager_ToggleNightMode = UIManager.ToggleNightMode
function UIManager:ToggleNightMode()
    original_UIManager_ToggleNightMode(self)

    if common.has_document_open() then
        recomputeAllColors()

        refreshCSS()
        if FixedBackgroundColor.get() then
            redrawPage()
        end
    end
end

local original_UIManager_SetNightMode = UIManager.SetNightMode
function UIManager:SetNightMode(night_mode)
    original_UIManager_SetNightMode(self)

    if Screen.night_mode ~= night_mode then
        recomputeAllColors()

        refreshCSS()
        if FixedBackgroundColor.get() then
            redrawPage()
        end
    end
end

-- Only refresh page on applying a book theme in the reader
local original_ReaderUI_onApplyTheme = ReaderUI.onApplyTheme
function ReaderUI:onApplyTheme()
    if original_ReaderUI_onApplyTheme then
        original_ReaderUI_onApplyTheme(self)
    end

    refreshCSS()
    if FixedBackgroundColor.get() then
        redrawPage()
    end
end

-- Refresh CSS after initialization when color inversion is enabled (invert images)
-- Prevents inverted colors from being shown on opening documents
local original_ReaderRolling_init = ReaderRolling.init
function ReaderRolling:init()
    original_ReaderRolling_init(self)

    self.ui:registerPostInitCallback(function()
        UIManager:nextTick(function()
            if Screen.night_mode and common.isColorInversionActive() then
                refreshCSS()
            end
        end)
    end)
end

-- Refresh CSS when toggling color inversion in reflowable documents (invert images)
local original_ReaderTypeset_onToggleNightmodeImages = ReaderTypeset.onToggleNightmodeImages
function ReaderTypeset:onToggleNightmodeImages(toggle)
    original_ReaderTypeset_onToggleNightmodeImages(self, toggle)

    if Screen.night_mode then
        refreshCSS()
    end
end

return book_menu

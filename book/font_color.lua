local Blitbuffer = require("ffi/blitbuffer")
local ColorWheelWidget = require("widgets/colorwheelwidget")
local Event = require("ui/event")
local FileManager = require("apps/filemanager/filemanager")
local ReaderStyleTweak = require("apps/reader/modules/readerstyletweak")
local ReaderUI = require("apps/reader/readerui")
local Screen = require("device").screen
local Setting = require("lib/setting")
local UIManager = require("ui/uimanager")
local common = require("lib/common")
local util = require("util")

local HexFontColor = Setting("book_font_color_hex", "#000000")
local InvertFontColor = Setting("book_font_color_inverted", true)
local AltNightFontColor = Setting("book_font_color_alt_night", false)
local NightHexFontColor = Setting("book_font_color_night_hex", "#FFFFFF")

-- Cache
local fg_cached = {
    alt_night_color = AltNightFontColor.get(),
    invert_in_night_mode = InvertFontColor.get(),
    hex = HexFontColor.get(),
    night_hex = NightHexFontColor.get(),
    last_hex = nil,
    fgcolor = nil,
}

-- Recompute and cache the final fgcolor based on current settings
-- Applies night mode inversion if enabled, and updates fg_cached.fgcolor only if it has changed
local function recomputeFGColor()
    local hex = (Screen.night_mode and fg_cached.alt_night_color) and fg_cached.night_hex or fg_cached.hex
    if Screen.night_mode then
        if fg_cached.alt_night_color or not fg_cached.invert_in_night_mode then
            hex = common.invertColor(hex)
        end
    end
    if hex ~= fg_cached.last_hex then
        fg_cached.fgcolor = Blitbuffer.colorFromString(hex)
        fg_cached.last_hex = hex
    end
end

-- Compute and cache the initial fgcolor based on current settings
recomputeFGColor()

local function getFontColor()
    if Screen.night_mode and fg_cached.alt_night_color then
        return NightHexFontColor.get()
    else
        return HexFontColor.get()
    end
end

local function setFontColor(hex)
    if Screen.night_mode and fg_cached.alt_night_color then
        NightHexFontColor.set(hex)
        fg_cached.night_hex = hex
    else
        HexFontColor.set(hex)
        fg_cached.hex = hex
    end

    recomputeFGColor()
end

local function refresh()
    -- Reapply page CSS
    if common.has_document_open() then
        UIManager:broadcastEvent(Event:new("ApplyStyleSheet"))
    end
end

-- Menus
local _ = require("gettext")
local T = require("ffi/util").template

local function set_color_menu()
    InputDialog = require("ui/widget/inputdialog")
    return {
        text = _("Enter color code"),
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            local input_dialog
            input_dialog = InputDialog:new({
                title = "Enter custom color code",
                input = getFontColor(),
                input_hint = "#000000",
                buttons = {
                    {
                        {
                            text = "Cancel",
                            callback = function()
                                UIManager:close(input_dialog)
                            end,
                        },
                        {
                            text = "Save",
                            callback = function()
                                local text = input_dialog:getInputText()

                                if text ~= "" then
                                    if not text:match("^#%x%x%x%x%x%x$") then
                                        return
                                    end

                                    setFontColor(string.upper(text))
                                    refresh()

                                    touchmenu_instance:updateItems()
                                    UIManager:close(input_dialog)
                                end
                            end,
                        },
                    },
                },
            })
            UIManager:show(input_dialog)
            input_dialog:onShowKeyboard()
        end,
    }
end

local function pick_color_menu()
    return {
        text = _("Pick color visually"),
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            local h, s, v = common.hexToHSV(getFontColor())
            local wheel
            local should_invert_wheel = AltNightFontColor.get() or not InvertFontColor.get()
            wheel = ColorWheelWidget:new({
                title_text = "Pick font color",
                hue = h,
                saturation = s,
                value = v,
                invert_in_night_mode = should_invert_wheel,
                callback = function(hex)
                    setFontColor(hex)
                    refresh()

                    if touchmenu_instance then
                        touchmenu_instance:updateItems()
                    end
                    UIManager:setDirty(nil, "ui")
                end,
                cancel_callback = function()
                    UIManager:setDirty(nil, "ui")
                end,
            })
            UIManager:show(wheel)
        end,
        separator = true,
    }
end

local function font_color_menu()
    return {
        text_func = function()
            return T(_("Font color: %1"), getFontColor())
        end,
        sub_item_table = {
            {
                text_func = function()
                    return T(_("Current color: %1"), getFontColor())
                end,
            },
            set_color_menu(),
            pick_color_menu(),
            {
                text = _("Alternative night mode color"),
                checked_func = AltNightFontColor.get,
                callback = function()
                    AltNightFontColor.toggle()
                    fg_cached.alt_night_color = AltNightFontColor.get()

                    if Screen.night_mode then
                        recomputeFGColor()

                        if common.has_document_open() then
                            UIManager:broadcastEvent(Event:new("ApplyStyleSheet"))
                        end
                    end
                end,
            },
            {
                text = _("Invert color in night mode"),
                enabled_func = function() return not AltNightFontColor.get() end,
                checked_func = InvertFontColor.get,
                callback = function()
                    InvertFontColor.toggle()
                    fg_cached.invert_in_night_mode = InvertFontColor.get()
                    recomputeFGColor()

                    if Screen.night_mode then
                        if common.has_document_open() then
                            UIManager:broadcastEvent(Event:new("ApplyStyleSheet"))
                        end
                    end
                end,
            },
        },
    }
end

-- Add font color to reader style tweak CSS if enabled
local original_ReaderStyleTweak_getCssText = ReaderStyleTweak.getCssText
function ReaderStyleTweak:getCssText()
    local original_css = original_ReaderStyleTweak_getCssText(self)

    local fg_hex = (Screen.night_mode and fg_cached.alt_night_color) and fg_cached.night_hex or fg_cached.hex
    if Screen.night_mode then
        if fg_cached.alt_night_color or not fg_cached.invert_in_night_mode then
            fg_hex = common.invertColor(fg_hex)
        end
    end

    local fg_css = [[
            body {
                color: ]] .. fg_hex .. [[ !important;
            }
        ]]
    return util.trim(fg_css .. original_css)
end

-- Hook into night mode state changes and update cache
local original_UIManager_ToggleNightMode = UIManager.ToggleNightMode
function UIManager:ToggleNightMode()
    original_UIManager_ToggleNightMode(self)

    recomputeFGColor()

    if fg_cached.alt_night_color or not fg_cached.invert_in_night_mode then
        if common.has_document_open() then
            UIManager:broadcastEvent(Event:new("ApplyStyleSheet"))
        end
    end
end

local original_UIManager_SetNightMode = UIManager.SetNightMode
function UIManager:SetNightMode(night_mode)
    original_UIManager_SetNightMode(self)

    if Screen.night_mode ~= night_mode then
        recomputeFGColor()

        if fg_cached.alt_night_color or not fg_cached.invert_in_night_mode then
            if common.has_document_open() then
                UIManager:broadcastEvent(Event:new("ApplyStyleSheet"))
            end
        end
    end
end

-- Event handlers for when a theme is applied
local original_FileManager_onApplyTheme = FileManager.onApplyTheme
function FileManager:onApplyTheme()
    if original_FileManager_onApplyTheme then
        original_FileManager_onApplyTheme(self)
    end

    fg_cached.hex = HexFontColor.get()
    fg_cached.night_hex = NightHexFontColor.get()
    fg_cached.alt_night_color = AltNightFontColor.get()
    recomputeFGColor()
    refresh()
end

local original_ReaderUI_onApplyTheme = ReaderUI.onApplyTheme
function ReaderUI:onApplyTheme()
    if original_ReaderUI_onApplyTheme then
        original_ReaderUI_onApplyTheme(self)
    end

    fg_cached.hex = HexFontColor.get()
    fg_cached.night_hex = NightHexFontColor.get()
    fg_cached.alt_night_color = AltNightFontColor.get()
    recomputeFGColor()
    refresh()
end

return font_color_menu

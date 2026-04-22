local ColorWheelWidget = require("widgets/colorwheelwidget")
local Event = require("ui/event")
local FileManager = require("apps/filemanager/filemanager")
local InputDialog = require("ui/widget/inputdialog")
local ReaderStyleTweak = require("apps/reader/modules/readerstyletweak")
local ReaderUI = require("apps/reader/readerui")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local common = require("lib/common")
local util = require("util")

local HexLinkColor = Setting("book_link_color_hex", nil)
local InvertLinkColor = Setting("book_link_color_inverted", true)
local AltNightLinkColor = Setting("book_link_color_alt_night", false)
local NightHexLinkColor = Setting("book_link_color_night_hex", nil)

-- Cache
local link_cached = {
    alt_night_color = AltNightLinkColor.get(),
    invert_in_night_mode = InvertLinkColor.get(),
    hex = HexLinkColor.get(),
    night_hex = NightHexLinkColor.get(),
    last_hex = nil,
    computed_hex = nil,
}

-- Recompute and cache the final link color based on current settings
-- Applies night mode inversion if enabled
local function recomputeLinkColor()
    local hex = (Screen.night_mode and link_cached.alt_night_color) and link_cached.night_hex or link_cached.hex
    if not hex then return end -- Hex can be nil if using the default link colors

    if Screen.night_mode then
        if link_cached.alt_night_color or not link_cached.invert_in_night_mode then
            hex = common.invertColor(hex)
        end
    end
    if hex ~= link_cached.last_hex then
        link_cached.computed_hex = hex
        link_cached.last_hex = hex
    end
end

-- Compute and cache the initial link color based on current settings
recomputeLinkColor()

local function getLinkColor()
    if Screen.night_mode and link_cached.alt_night_color then
        return NightHexLinkColor.get()
    else
        return HexLinkColor.get()
    end
end

local function setLinkColor(hex)
    if Screen.night_mode and link_cached.alt_night_color then
        NightHexLinkColor.set(hex)
        link_cached.night_hex = hex
    else
        HexLinkColor.set(hex)
        link_cached.hex = hex
    end

    recomputeLinkColor()
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
    return {
        text = _("Enter color code"),
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            local input_dialog
            input_dialog = InputDialog:new({
                title = "Enter custom color code",
                input = getLinkColor() or "#0066FF",
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

                                    setLinkColor(string.upper(text))
                                    refresh()

                                    if touchmenu_instance then
                                        touchmenu_instance:updateItems()
                                    end
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
            local h, s, v = common.hexToHSV(getLinkColor() or "#0066FF")
            local wheel
            local should_invert_wheel = AltNightLinkColor.get() or not InvertLinkColor.get()
            wheel = ColorWheelWidget:new({
                title_text = "Pick link color",
                hue = h,
                saturation = s,
                value = v,
                invert_in_night_mode = should_invert_wheel,
                callback = function(hex)
                    setLinkColor(hex)
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
    }
end

local function link_color_menu()
    return {
        text_func = function()
            return T(_("Link color: %1"), getLinkColor() or "default")
        end,
        sub_item_table = {
            {
                text_func = function()
                    return T(_("Current color: %1"), getLinkColor() or "default")
                end,
            },
            set_color_menu(),
            pick_color_menu(),
            {
                text = _("Reset color"),
                callback = function()
                    setLinkColor(nil)
                    refresh()
                end,
                separator = true,
            },
            {
                text = _("Alternative night mode color"),
                checked_func = AltNightLinkColor.get,
                callback = function()
                    AltNightLinkColor.toggle()
                    link_cached.alt_night_color = AltNightLinkColor.get()

                    if Screen.night_mode then
                        recomputeLinkColor()

                        refresh()
                    end
                end,
            },
            {
                text = _("Invert color in night mode"),
                enabled_func = function() return not AltNightLinkColor.get() end,
                checked_func = InvertLinkColor.get,
                callback = function()
                    InvertLinkColor.toggle()
                    link_cached.invert_in_night_mode = InvertLinkColor.get()
                    recomputeLinkColor()

                    if Screen.night_mode then
                        refresh()
                    end
                end,
            },
        },
    }
end

-- Add link color to reader style tweak CSS if enabled
local original_ReaderStyleTweak_getCssText = ReaderStyleTweak.getCssText
function ReaderStyleTweak:getCssText()
    local original_css = original_ReaderStyleTweak_getCssText(self) or ""

    if link_cached.computed_hex then
        local link_css = [[
            a {
                color: ]] .. link_cached.computed_hex .. [[ !important;
            }
        ]]
        return util.trim(link_css .. original_css)
    end
    return original_css
end

-- Hook into night mode state changes and update cache
local original_UIManager_ToggleNightMode = UIManager.ToggleNightMode
function UIManager:ToggleNightMode()
    original_UIManager_ToggleNightMode(self)

    recomputeLinkColor()

    if link_cached.alt_night_color or not link_cached.invert_in_night_mode then
        refresh()
    end
end

local original_UIManager_SetNightMode = UIManager.SetNightMode
function UIManager:SetNightMode(night_mode)
    original_UIManager_SetNightMode(self)

    if Screen.night_mode ~= night_mode then
        recomputeLinkColor()

        if link_cached.alt_night_color or not link_cached.invert_in_night_mode then
            refresh()
        end
    end
end

-- Event handlers for when a theme is applied
local original_FileManager_onApplyTheme = FileManager.onApplyTheme
function FileManager:onApplyTheme()
    if original_FileManager_onApplyTheme then
        original_FileManager_onApplyTheme(self)
    end

    link_cached.hex = HexLinkColor.get()
    link_cached.night_hex = NightHexLinkColor.get()
    link_cached.alt_night_color = AltNightLinkColor.get()
    recomputeLinkColor()
    refresh()
end

local original_ReaderUI_onApplyTheme = ReaderUI.onApplyTheme
function ReaderUI:onApplyTheme()
    if original_ReaderUI_onApplyTheme then
        original_ReaderUI_onApplyTheme(self)
    end

    link_cached.hex = HexLinkColor.get()
    link_cached.night_hex = NightHexLinkColor.get()
    link_cached.alt_night_color = AltNightLinkColor.get()
    recomputeLinkColor()
    refresh()
end

return link_color_menu

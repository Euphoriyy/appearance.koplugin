local Blitbuffer = require("ffi/blitbuffer")
local ButtonDialog = require("ui/widget/buttondialog")
local ColorWheelWidget = require("widgets/colorwheelwidget")
local InputDialog = require("ui/widget/inputdialog")
local MultiConfirmBox = require("ui/widget/multiconfirmbox")
local ReaderHighlight = require("apps/reader/modules/readerhighlight")
local ReaderUI = require("apps/reader/readerui")
local Screen = require("device").screen
local Setting = require("lib/setting")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local common = require("lib/common")

local DEFAULT_HIGHLIGHT_COLOR_NAMES = {
    _("Red"),
    _("Orange"),
    _("Yellow"),
    _("Green"),
    _("Olive"),
    _("Cyan"),
    _("Blue"),
    _("Purple"),
    _("Gray"),
}

-- Sourced from ffi/blitbuffer
local DEFAULT_HIGHLIGHT_COLOR_HEXES = {
    "#FF3300",
    "#FF8800",
    "#FFFF33",
    "#00AA66",
    "#88FF77",
    "#00FFEE",
    "#0066FF",
    "#EE00FF",
}

-- Settings
local HighlightColorNames = Setting("highlight_color_names", DEFAULT_HIGHLIGHT_COLOR_NAMES)
local HighlightColorHexes = Setting("highlight_color_hexes", DEFAULT_HIGHLIGHT_COLOR_HEXES)

local highlight_color_keys = {
    "red",
    "orange",
    "yellow",
    "green",
    "olive",
    "cyan",
    "blue",
    "purple",
    "gray",
}

local function getHighlightColorIndex(color)
    for i, key in ipairs(highlight_color_keys) do
        if key == color then
            return i
        end
    end
end

local function getHighlightColorHex(color, i)
    i = getHighlightColorIndex(color) or i
    return HighlightColorHexes.get()[i]
end

local function setHighlightColorHex(color, hex, i)
    i = getHighlightColorIndex(color) or i
    local hexes = HighlightColorHexes.get()
    hexes[i] = hex
    HighlightColorHexes.set(hexes)

    Blitbuffer.HIGHLIGHT_COLORS[color] = hex

    if common.has_document_open() then
        ReaderUI.instance.view:resetHighlightBoxesCache()
    end
end

function ReaderHighlight:getHighlightColorString(color, i)
    i = getHighlightColorIndex(color) or i
    return HighlightColorNames.get()[i]
end

local function setHighlightColorString(color, color_string, i)
    i = getHighlightColorIndex(color) or i
    local names = HighlightColorNames.get()
    names[i] = color_string
    HighlightColorNames.set(names)
end

function ReaderHighlight:getHighlightColor(color, i)
    local hex = getHighlightColorHex(color, i)
    if hex then
        if Screen.night_mode then
            hex = common.invertColor(hex)
        end
        return Blitbuffer.colorFromString(hex)
    end
    return Blitbuffer.gray(G_reader_settings:readSetting("highlight_lighten_factor") or 0.2)
end

-- Updates the highlight color k-v pair tables (responsible for shown color names and values)
local function update_highlight_color_pairs(self)
    self.highlight_colors = {}
    local color_names = HighlightColorNames.get()
    for i, color in ipairs(highlight_color_keys) do
        self.highlight_colors[i] = { color_names[i], color }
        Blitbuffer.HIGHLIGHT_COLORS[color] = getHighlightColorHex(color, i)
    end
end

-- Update highlight color pairs on reader highlight init
local original_ReaderHighlight_init = ReaderHighlight.init
function ReaderHighlight:init()
    update_highlight_color_pairs(self)

    original_ReaderHighlight_init(self)
end

-- Update highlight color pairs on editing highlight color
local original_ReaderHighlight_editHighlightColor = ReaderHighlight.editHighlightColor
function ReaderHighlight:editHighlightColor(index)
    update_highlight_color_pairs(self)

    original_ReaderHighlight_editHighlightColor(self, index)
end

-- Menus
local function set_color_menu(touchmenu_instance, original_hex, callback)
    original_hex = original_hex or "#333333"

    local input_dialog
    input_dialog = InputDialog:new({
        title = _("Enter highlight color code"),
        input = original_hex,
        input_hint = "#FFFFFF",
        buttons = {
            {
                {
                    text = "Cancel",
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = "Next",
                    callback = function()
                        local text = input_dialog:getInputText()

                        if text ~= "" then
                            if not text:match("^#%x%x%x%x%x%x$") then
                                return
                            end

                            callback(text)

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
    return input_dialog
end

local function pick_color_menu(touchmenu_instance, original_hex, callback)
    original_hex = original_hex or "#333333"

    local h, s, v = common.hexToHSV(original_hex)
    local wheel
    wheel = ColorWheelWidget:new({
        title_text = _("Pick highlight color"),
        hue = h,
        saturation = s,
        value = v,
        invert_in_night_mode = true,
        callback = function(hex)
            callback(hex)

            if touchmenu_instance then
                touchmenu_instance:updateItems()
            end
            UIManager:setDirty(nil, "ui")
        end,
        cancel_callback = function()
            UIManager:setDirty(nil, "ui")
        end,
    })
    return wheel
end

-- Menu to select method for choosing color
local function color_menu(touchmenu_instance, original_hex, callback)
    local dialog = MultiConfirmBox:new({
        text = _("Choose the highlight color by:"),
        choice1_text = _("Hex code"),
        choice1_callback = function()
            local input_dialog = set_color_menu(touchmenu_instance, original_hex, callback)
            UIManager:show(input_dialog)
            input_dialog:onShowKeyboard()
        end,
        choice2_text = _("Color picker"),
        choice2_callback = function()
            UIManager:show(pick_color_menu(touchmenu_instance, original_hex, callback))
        end,
    })
    return dialog
end

local edit_menu

local function highlightColorDialog(touchmenu_instance)
    local dialog
    local buttons = {}
    for i, color in ipairs(highlight_color_keys) do
        local color_name = ReaderHighlight.getHighlightColorString(nil, color, i)
        buttons[i] = { {
            text = color_name,
            menu_style = true,
            background = ReaderHighlight.getHighlightColor(nil, color, i),
            callback = function()
                local original_hex = getHighlightColorHex(color)
                UIManager:show(color_menu(touchmenu_instance, original_hex, function(hex)
                    setHighlightColorHex(color, hex)
                    UIManager:close(dialog)
                    UIManager:show(highlightColorDialog(touchmenu_instance))
                end))
            end,
            hold_callback = function()
                UIManager:show(edit_menu(touchmenu_instance, color, { dialog = dialog }))
            end
        } }
    end
    dialog = ButtonDialog:new {
        buttons = buttons,
        width_factor = 0.4,
        colorful = true,
        dithered = true,
    }
    return dialog
end

edit_menu = function(touchmenu_instance, color, updialog_ref)
    local button_bg_colors = {
        Blitbuffer.colorFromString("#BA8E23"),
        Blitbuffer.colorFromString("#2D728F"),
        Blitbuffer.colorFromString("#FF5964"),
    }

    for i, bg_color in ipairs(button_bg_colors) do
        if Screen.night_mode then
            button_bg_colors[i] = bg_color:invert()
        end
    end

    local dialog

    local edit_buttons = {
        { {
            text = _("§white ✒ Rename§r "),
            menu_style = true,
            original_background = button_bg_colors[1],
            background = common.EXCLUSION_COLOR,
            callback = function()
                local input_dialog
                input_dialog = InputDialog:new({
                    title = "Enter the theme's new name:",
                    input = ReaderHighlight.getHighlightColorString(nil, color),
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
                                        setHighlightColorString(color, text)

                                        UIManager:close(input_dialog)
                                        UIManager:close(dialog)

                                        UIManager:close(updialog_ref.dialog)
                                        UIManager:show(highlightColorDialog(touchmenu_instance))
                                    end
                                end,
                            }
                        }
                    }
                })
                UIManager:show(input_dialog)
                input_dialog:onShowKeyboard()
            end,
        } },
        { {
            text = _("§white ● Edit highlight color§r "),
            menu_style = true,
            original_background = button_bg_colors[2],
            background = common.EXCLUSION_COLOR,
            callback = function()
                UIManager:show(color_menu(touchmenu_instance, getHighlightColorHex(color), function(hex)
                    setHighlightColorHex(color, hex)

                    UIManager:close(dialog)

                    UIManager:close(updialog_ref.dialog)
                    UIManager:show(highlightColorDialog(touchmenu_instance))
                end))

                UIManager:close(dialog)
            end,
        } },
        { {
            text = _("§white ✖ Reset§r "),
            menu_style = true,
            original_background = button_bg_colors[3],
            background = common.EXCLUSION_COLOR,
            callback = function()
                setHighlightColorString(color, DEFAULT_HIGHLIGHT_COLOR_NAMES[getHighlightColorIndex(color)])
                setHighlightColorHex(color, DEFAULT_HIGHLIGHT_COLOR_HEXES[getHighlightColorIndex(color)])

                UIManager:close(dialog)

                UIManager:close(updialog_ref.dialog)
                UIManager:show(highlightColorDialog(touchmenu_instance))
            end,
        } },
    }

    dialog = ButtonDialog:new {
        buttons = edit_buttons,
        width_factor = 0.6,
        colorful = true,
        dithered = true,
    }
    return dialog
end

-- Appearance menu
local function highlight_colors_menu()
    return {
        text = _("Highlight colors"),
        callback = function(touchmenu_instance)
            UIManager:show(highlightColorDialog(touchmenu_instance))
        end
    }
end

return highlight_colors_menu

local Blitbuffer = require("ffi/blitbuffer")
local ButtonDialog = require("ui/widget/buttondialog")
local ColorWheelWidget = require("widgets/colorwheelwidget")
local InputDialog = require("ui/widget/inputdialog")
local MultiConfirmBox = require("ui/widget/multiconfirmbox")
local ReaderHighlight = require("apps/reader/modules/readerhighlight")
local ReaderUI = require("apps/reader/readerui")
local ReaderView = require("apps/reader/modules/readerview")
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

-- Settings
local HighlightColorNames = Setting("highlight_color_names", DEFAULT_HIGHLIGHT_COLOR_NAMES)
local HighlightColorHexes = Setting("highlight_color_hexes", {
    Blitbuffer.HIGHLIGHT_COLORS["red"],
    Blitbuffer.HIGHLIGHT_COLORS["orange"],
    Blitbuffer.HIGHLIGHT_COLORS["yellow"],
    Blitbuffer.HIGHLIGHT_COLORS["green"],
    Blitbuffer.HIGHLIGHT_COLORS["olive"],
    Blitbuffer.HIGHLIGHT_COLORS["cyan"],
    Blitbuffer.HIGHLIGHT_COLORS["blue"],
    Blitbuffer.HIGHLIGHT_COLORS["purple"],
})

-- Highlight color keys
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

local function getHighlightColorRGB(color)
    local hex = getHighlightColorHex(color)
    if hex then
        return Blitbuffer.colorFromString(hex)
    else
        return Blitbuffer.gray(G_reader_settings:readSetting("highlight_lighten_factor") or 0.2):getColorRGB32()
    end
end

local function setHighlightColorHex(color, hex, i)
    i = getHighlightColorIndex(color) or i
    local hexes = HighlightColorHexes.get()
    hexes[i] = hex
    HighlightColorHexes.set(hexes)

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

-- Patch method responsible for showing highlight color names (removed in nightly)
local original_ReaderHighlight_showHighlightColorDialog = ReaderHighlight.showHighlightColorDialog
if original_ReaderHighlight_showHighlightColorDialog then
    function ReaderHighlight:showHighlightColorDialog(caller_callback, curr_color)
        local highlight_color_pairs = {}
        local color_names = HighlightColorNames.get()
        for i, color in ipairs(highlight_color_keys) do
            highlight_color_pairs[i] = { color_names[i], color }
        end
        self.highlight_colors = highlight_color_pairs
        original_ReaderHighlight_showHighlightColorDialog(self, caller_callback, curr_color)
    end
end

-- Draw page highlights with custom colors
function ReaderView:drawPageSavedHighlight(bb, x, y)
    local do_cache = not self.page_scroll and self.document.configurable.text_wrap == 0
    local colorful
    local pages = self:getCurrentPageList()
    for _, page in ipairs(pages) do
        if self.highlight.page_boxes[page] ~= nil then -- cached
            for _, box in ipairs(self.highlight.page_boxes[page]) do
                local rect = self:pageToScreenTransform(page, box.rect)
                if rect then
                    table.insert(self.highlight.visible_boxes, box)
                    self:drawHighlightRect(bb, x, y, rect, box.drawer, box.color, box.draw_mark)
                    if box.colorful then
                        colorful = true
                    end
                end
            end
        else -- not cached
            if do_cache then
                self.highlight.page_boxes[page] = {}
            end
            local items, idx_offset = self.ui.highlight:getPageSavedHighlights(page)
            for index, item in ipairs(items) do
                local boxes = self.document:getPageBoxesFromPositions(page, item.pos0, item.pos1)
                if boxes then
                    local drawer = item.drawer
                    local color = item.color and getHighlightColorRGB(item.color)
                    if not colorful and color and not Blitbuffer.isColor8(color) then
                        colorful = true
                    end
                    local draw_note_mark = item.note and true or nil
                    for _, box in ipairs(boxes) do
                        local rect = self:pageToScreenTransform(page, box)
                        if rect then
                            local hl_box = {
                                index     = item.parent or (index + idx_offset), -- index in annotations
                                rect      = box,
                                drawer    = drawer,
                                color     = color,
                                draw_mark = draw_note_mark,
                                colorful  = colorful,
                            }
                            if do_cache then
                                table.insert(self.highlight.page_boxes[page], hl_box)
                            end
                            table.insert(self.highlight.visible_boxes, hl_box)
                            self:drawHighlightRect(bb, x, y, rect, drawer, color, draw_note_mark)
                            draw_note_mark = draw_note_mark and false -- side mark in the first line only
                        else
                            -- some boxes are not displayed in the currently visible part of the page,
                            -- the page boxes cannot be cached
                            do_cache = false
                            self.highlight.page_boxes[page] = nil
                        end
                    end
                end
            end
        end
    end
    return colorful
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
        Blitbuffer.colorFromName("blue"),
        Blitbuffer.colorFromName("red"),
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
                setHighlightColorHex(color, Blitbuffer.HIGHLIGHT_COLORS[color])

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

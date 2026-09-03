local Blitbuffer = require("ffi/blitbuffer")
local ColorWheelWidget = require("widgets/colorwheelwidget")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Document = require("document/document")
local Event = require("ui/event")
local FileManager = require("apps/filemanager/filemanager")
local FootnoteWidget = require("ui/widget/footnotewidget")
local InputDialog = require("ui/widget/inputdialog")
local KoptInterface = require("document/koptinterface")
local ReaderStyleTweak = require("apps/reader/modules/readerstyletweak")
local ReaderUI = require("apps/reader/readerui")
local Screen = Device.screen
local Setting = require("lib/setting")
local UIManager = require("ui/uimanager")
local common = require("lib/common")
local util = require("util")

-- Settings
local HexBackgroundColor = Setting("book_background_color_hex", "#FFFFFF")
local InvertBackgroundColor = Setting("book_background_color_inverted", true)
local AltNightBackgroundColor = Setting("book_background_color_alt_night", false)
local NightHexBackgroundColor = Setting("book_background_color_night_hex", "#000000")
local FixedBackgroundColor = Setting("book_background_color_fixed", true)

--------------------------------------------
-- Lazy Loading
--------------------------------------------

local font_color

local function get_book_fgcolor()
    font_color = font_color or require("book/font_color")
    return font_color.fgcolor()
end

local function get_book_fghex()
    font_color = font_color or require("book/font_color")
    return font_color.hex()
end

local function get_book_fixed_fgcolor()
    font_color = font_color or require("book/font_color")
    return font_color.set_fixed_color()
end

-- Cache
local bg_cached = {
    alt_night_color = AltNightBackgroundColor.get(),
    invert_in_night_mode = InvertBackgroundColor.get(),
    set_fixed_color = FixedBackgroundColor.get(),
    hex = HexBackgroundColor.get(),
    night_hex = NightHexBackgroundColor.get(),
    last_hex = nil,
    bgcolor = nil,
}

-- Calculate the current hex value based on night mode and current settings
local function calculateHex(is_doc_css)
    local hex = (Screen.night_mode and bg_cached.alt_night_color) and bg_cached.night_hex or bg_cached.hex
    if Screen.night_mode then
        if bg_cached.alt_night_color or not bg_cached.invert_in_night_mode then
            hex = common.invertColor(hex)
        end
        -- Invert hex again if the reflowable document is inverting it
        if is_doc_css and common.isColorInversionActive() and not common.isGrayscale(hex) then
            hex = common.invertColor(hex)
        end
    end
    return hex
end

-- Recompute and cache the final bgcolor based on current settings
-- Applies night mode inversion if enabled, and updates bg_cached.bgcolor only if it has changed
local function recomputeBGColor()
    local hex = calculateHex()
    if hex ~= bg_cached.last_hex then
        bg_cached.bgcolor = Blitbuffer.colorFromString(hex)
        bg_cached.last_hex = hex
    end
end

-- Compute and cache the initial bgcolor based on current settings
recomputeBGColor()

local function getBackgroundColor()
    if Screen.night_mode and bg_cached.alt_night_color then
        return NightHexBackgroundColor.get()
    else
        return HexBackgroundColor.get()
    end
end

local function setBackgroundColor(hex)
    hex = string.upper(hex)

    if Screen.night_mode and bg_cached.alt_night_color then
        NightHexBackgroundColor.set(hex)
        bg_cached.night_hex = hex
    else
        HexBackgroundColor.set(hex)
        bg_cached.hex = hex
    end

    recomputeBGColor()
end

local function refresh()
    if common.has_document_open() then
        if ReaderUI.instance.rolling then
            UIManager:broadcastEvent(Event:new("ApplyStyleSheet"))
        elseif ReaderUI.instance.paging and bg_cached.set_fixed_color then
            UIManager:broadcastEvent(Event:new("RedrawCurrentPage"))
        end
    end
end

-- Menus
local _ = require("gettext")
local T = require("ffi/util").template

local function set_color_callback()
    return function(touchmenu_instance)
        local input_dialog
        input_dialog = InputDialog:new({
            title = "Enter custom color code",
            input = getBackgroundColor(),
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
                        text = "Save",
                        callback = function()
                            local text = input_dialog:getInputText()

                            if text ~= "" then
                                if not text:match("^#%x%x%x%x%x%x$") then
                                    return
                                end

                                setBackgroundColor(text)
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
    end
end

local function pick_color_callback()
    return function(touchmenu_instance)
        local h, s, v = common.hexToHSV(getBackgroundColor())
        local wheel
        local should_invert_wheel = AltNightBackgroundColor.get() or not InvertBackgroundColor.get()
        wheel = ColorWheelWidget:new({
            title_text = "Pick background color",
            hue = h,
            saturation = s,
            value = v,
            invert_in_night_mode = should_invert_wheel,
            callback = function(hex)
                setBackgroundColor(hex)
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
    end
end

local function background_color_menu()
    return {
        text_func = function()
            return T(_("Background color: %1"), getBackgroundColor())
        end,
        sub_item_table = {
            {
                text_func = function()
                    return T(_("Background color: %1 (hold to pick)"), getBackgroundColor())
                end,
                keep_menu_open = true,
                callback = set_color_callback(),
                hold_callback = pick_color_callback(),
            },
            {
                text = _("Alternative night mode color"),
                checked_func = AltNightBackgroundColor.get,
                callback = function()
                    AltNightBackgroundColor.toggle()
                    bg_cached.alt_night_color = AltNightBackgroundColor.get()

                    if Screen.night_mode then
                        recomputeBGColor()

                        refresh()
                    end
                end,
            },
            {
                text = _("Invert color in night mode"),
                enabled_func = function() return not AltNightBackgroundColor.get() end,
                checked_func = InvertBackgroundColor.get,
                callback = function()
                    InvertBackgroundColor.toggle()
                    bg_cached.invert_in_night_mode = InvertBackgroundColor.get()
                    recomputeBGColor()

                    if Screen.night_mode then
                        refresh()
                    end
                end,
                separator = true,
            },
            {
                text = _("Apply to reader pages (pdf, djvu, cbz...)"),
                checked_func = FixedBackgroundColor.get,
                callback = function()
                    FixedBackgroundColor.toggle()
                    bg_cached.set_fixed_color = FixedBackgroundColor.get()
                end,
            },
        }
    }
end

-- Add background color to reader style tweak CSS if enabled
local original_ReaderStyleTweak_getCssText = ReaderStyleTweak.getCssText
function ReaderStyleTweak:getCssText()
    local original_css = original_ReaderStyleTweak_getCssText(self) or ""

    local bg_css = [[
        body {
            background-color: ]] .. calculateHex(true) .. [[ !important;
        }
    ]]
    return util.trim(bg_css .. original_css)
end

-- Add background color to footnote popup CSS
local original_FootnoteWidget_init = FootnoteWidget.init
function FootnoteWidget:init()
    original_FootnoteWidget_init(self)

    local htmlwidget = self.htmlwidget
    local original_css = htmlwidget.css

    local bg_css = [[
        body {
            background-color: ]] .. calculateHex() .. [[ !important;
        }
    ]]
    htmlwidget.css = util.trim(bg_css .. original_css)
    htmlwidget.htmlbox_widget:setContent(htmlwidget.html_body, htmlwidget.css, htmlwidget.default_font_size,
        htmlwidget.is_xhtml, nil, htmlwidget.html_resource_directory)

    -- Use book background color for container
    self.container.original_background = bg_cached.bgcolor
    self.container.background = common.EXCLUSION_COLOR
end

-- Helper: check if dual pages are enabled (comicreader.koplugin)
local function has_dual_pages()
    local ui = ReaderUI.instance
    return ui.paging.isDualPageEnabled and ui.paging:isDualPageEnabled()
end

-- Helper: wraps Blitbuffer:multiplyRectRGB with a setting check
local function multiplyRectRGB(bb, x, y, w, h, c)
    if not bg_cached.set_fixed_color then return end

    bb:multiplyRectRGB(x, y, w, h, c)
end

-- Helper: recolor light pixels as an alternative to RGB multiplication
local function recolorLightPixels(bb, x, y, w, h, c, override_setting)
    if not bg_cached.set_fixed_color and not override_setting then return end

    local thres = 200
    local bb_w = bb:getWidth()
    local bb_h = bb:getHeight()
    local x0 = math.max(x, 0)
    local y0 = math.max(y, 0)
    local x1 = math.min(x + w - 1, bb_w - 1)
    local y1 = math.min(y + h - 1, bb_h - 1)
    for py = y0, y1 do
        for px = x0, x1 do
            local pixel = bb:getPixel(px, py)
            if pixel:getR() > thres and pixel:getG() > thres and pixel:getB() > thres then
                bb:setPixel(px, py, c)
            end
        end
    end
end

-- Helper: recolor dark pixels (i.e. text)
local function recolorDarkPixels(bb, x, y, w, h, c)
    if not get_book_fixed_fgcolor() then return end

    local thres = 50
    local bb_w = bb:getWidth()
    local bb_h = bb:getHeight()
    local x0 = math.max(x, 0)
    local y0 = math.max(y, 0)
    local x1 = math.min(x + w - 1, bb_w - 1)
    local y1 = math.min(y + h - 1, bb_h - 1)
    for py = y0, y1 do
        for px = x0, x1 do
            local pixel = bb:getPixel(px, py)
            if pixel:getR() <= thres and pixel:getG() <= thres and pixel:getB() <= thres then
                bb:setPixel(px, py, c)
            end
        end
    end
end

-- Helper: decides when to fully skip color replacement
local function shouldSkipColorReplacement()
    -- If both settings are disabled, skip
    if not bg_cached.set_fixed_color and not get_book_fixed_fgcolor() then
        return true
    end

    -- Check if background color is at default for the current mode
    local is_default_bg = (Screen.night_mode and bg_cached.last_hex == "#000000") or
        (not Screen.night_mode and bg_cached.last_hex == "#FFFFFF")

    -- Check if font color is at default for the current mode
    local is_default_fg = (Screen.night_mode and get_book_fghex() == "#FFFFFF") or
        (not Screen.night_mode and get_book_fghex() == "#000000")

    -- Skip if both colors are at defaults
    return is_default_bg and is_default_fg
end

-- Add background color to PDFs by using RGB multiplication (or replacement)
local original_Document_drawPage = Document.drawPage
function Document:drawPage(target, x, y, rect, ...)
    original_Document_drawPage(self, target, x, y, rect, ...)

    if shouldSkipColorReplacement() then
        return
    end

    -- Manually replace white background in software-inverted night mode where multiplication would fail
    -- (Note that this doesn't work with the C blitter on Android due to the way it inverts during night mode)
    -- Or to have an idempotent effect when dual pages are enabled
    -- Otherwise, the right side of the screen becomes more saturated due to repeated multiplication
    local sw_invert = Screen.night_mode and not Device:canHWInvert()
    local is_cbb_enabled = G_reader_settings:nilOrFalse("dev_no_c_blitter")
    if not (Device:isAndroid() and is_cbb_enabled) and (sw_invert or has_dual_pages()) then
        recolorLightPixels(target, x, y, rect.w, rect.h, bg_cached.bgcolor)
        recolorDarkPixels(target, x, y, rect.w, rect.h, get_book_fgcolor())
    else
        multiplyRectRGB(target, x, y, rect.w, rect.h, bg_cached.bgcolor)
        recolorDarkPixels(target, x, y, rect.w, rect.h, get_book_fgcolor())
    end
end

-- Do the same for when "Invert Document" is enabled in night mode
-- Use the day mode bgcolor instead of the one for night mode
local original_Document_drawPageInverted = Document.drawPageInverted
function Document:drawPageInverted(target, x, y, rect, pageno, ...)
    if shouldSkipColorReplacement() then
        original_Document_drawPageInverted(self, target, x, y, rect, pageno, ...)
        return
    end

    local bgcolor = Blitbuffer.colorFromString(bg_cached.hex)
    local fgcolor = Blitbuffer.colorFromString(get_book_fghex())

    -- Multiply against background before inversion when hardware inversion is used
    if Device:canHWInvert() then
        local tile = self:renderPage(pageno, rect, ...)
        target:blitFrom(tile.bb,
            x, y,
            rect.x - tile.excerpt.x,
            rect.y - tile.excerpt.y,
            rect.w, rect.h)
        multiplyRectRGB(target, x, y, rect.w, rect.h, bgcolor)
        recolorDarkPixels(target, x, y, rect.w, rect.h, fgcolor)
        target:invertRect(x, y, rect.w, rect.h)
    else
        original_Document_drawPageInverted(self, target, x, y, rect, pageno, ...)

        local is_cbb_enabled = G_reader_settings:nilOrFalse("dev_no_c_blitter")
        -- Manually recolor in Android (when using the C blitter) instead of using RGB multiplication
        if Device:isAndroid() and is_cbb_enabled then
            recolorLightPixels(target, x, y, rect.w, rect.h, bgcolor)
            recolorDarkPixels(target, x, y, rect.w, rect.h, fgcolor)
        else
            multiplyRectRGB(target, x, y, rect.w, rect.h, bgcolor:invert())
            if get_book_fixed_fgcolor() then
                recolorLightPixels(target, x, y, rect.w, rect.h, fgcolor:invert(), true)
            end
        end
    end
end

-- Finally, add background color to context pages
local original_KoptInterface_drawContextPage = KoptInterface.drawContextPage
function KoptInterface:drawContextPage(doc, target, x, y, rect, pageno, zoom, rotation, nightmode_invert)
    if shouldSkipColorReplacement() then
        original_KoptInterface_drawContextPage(self, doc, target, x, y, rect, pageno, zoom, rotation, nightmode_invert)
        return
    end

    local is_cbb_enabled = G_reader_settings:nilOrFalse("dev_no_c_blitter")
    local bgcolor = nightmode_invert and Blitbuffer.colorFromString(bg_cached.hex) or bg_cached.bgcolor
    local fgcolor = nightmode_invert and Blitbuffer.colorFromString(get_book_fghex()) or get_book_fgcolor()

    if nightmode_invert then
        -- Document:drawPageInverted path
        if Device:canHWInvert() then
            local tile = self:renderPage(doc, pageno, rect, zoom, rotation, 1.0, 1.0)
            target:blitFrom(tile.bb,
                x, y,
                rect.x - tile.excerpt.x,
                rect.y - tile.excerpt.y,
                rect.w, rect.h)
            multiplyRectRGB(target, x, y, rect.w, rect.h, bgcolor)
            recolorDarkPixels(target, x, y, rect.w, rect.h, fgcolor)
            target:invertRect(x, y, rect.w, rect.h)
        else
            original_KoptInterface_drawContextPage(self, doc, target, x, y, rect, pageno, zoom, rotation,
                nightmode_invert)
            if Device:isAndroid() and is_cbb_enabled then
                recolorLightPixels(target, x, y, rect.w, rect.h, bgcolor)
                recolorDarkPixels(target, x, y, rect.w, rect.h, fgcolor)
            else
                multiplyRectRGB(target, x, y, rect.w, rect.h, bgcolor:invert())
                recolorDarkPixels(target, x, y, rect.w, rect.h, fgcolor:invert())
            end
        end
    else
        -- Document:drawPage path
        original_KoptInterface_drawContextPage(self, doc, target, x, y, rect, pageno, zoom, rotation, nightmode_invert)
        local sw_invert = Screen.night_mode and not Device:canHWInvert()
        if not (Device:isAndroid() and is_cbb_enabled) and (sw_invert or has_dual_pages()) then
            recolorLightPixels(target, x, y, rect.w, rect.h, bgcolor)
            recolorDarkPixels(target, x, y, rect.w, rect.h, fgcolor)
        else
            multiplyRectRGB(target, x, y, rect.w, rect.h, bgcolor)
            recolorDarkPixels(target, x, y, rect.w, rect.h, fgcolor)
        end
    end
end

-- Recompute colors upon event call
local original_FileManager_onRecomputeAllColors = FileManager.onRecomputeAllColors
function FileManager:onRecomputeAllColors()
    if original_FileManager_onRecomputeAllColors then
        original_FileManager_onRecomputeAllColors(self)
    end

    recomputeBGColor()
end

local original_ReaderUI_onRecomputeAllColors = ReaderUI.onRecomputeAllColors
function ReaderUI:onRecomputeAllColors()
    if original_ReaderUI_onRecomputeAllColors then
        original_ReaderUI_onRecomputeAllColors(self)
    end

    recomputeBGColor()
end

-- Event handlers for when a theme is applied
local original_FileManager_onApplyTheme = FileManager.onApplyTheme
function FileManager:onApplyTheme()
    if original_FileManager_onApplyTheme then
        original_FileManager_onApplyTheme(self)
    end

    bg_cached.hex = HexBackgroundColor.get()
    bg_cached.night_hex = NightHexBackgroundColor.get()
    bg_cached.alt_night_color = AltNightBackgroundColor.get()
    recomputeBGColor()
end

local original_ReaderUI_onApplyTheme = ReaderUI.onApplyTheme
function ReaderUI:onApplyTheme()
    if original_ReaderUI_onApplyTheme then
        original_ReaderUI_onApplyTheme(self)
    end

    bg_cached.hex = HexBackgroundColor.get()
    bg_cached.night_hex = NightHexBackgroundColor.get()
    bg_cached.alt_night_color = AltNightBackgroundColor.get()
    recomputeBGColor()
end

-- Register toggling/setting application of background color to fixed document pages as dispatcher actions
local function ToggleBookBackgroundColorFixed()
    FixedBackgroundColor.toggle()
    bg_cached.set_fixed_color = FixedBackgroundColor.get()
    refresh()
end

local function SetBookBackgroundColorFixed(apply_on)
    FixedBackgroundColor.set(apply_on)
    bg_cached.set_fixed_color = apply_on
    refresh()
end

FileManager.onToggleBookBackgroundColorFixed = ToggleBookBackgroundColorFixed
ReaderUI.onToggleBookBackgroundColorFixed = ToggleBookBackgroundColorFixed

FileManager.onSetBookBackgroundColorFixed = SetBookBackgroundColorFixed
ReaderUI.onSetBookBackgroundColorFixed = SetBookBackgroundColorFixed

Dispatcher:registerAction("toggle_book_background_color_fixed", {
    category = "none",
    event = "ToggleBookBackgroundColorFixed",
    title = _("Toggle background color application for reader pages (pdf, djvu, cbz...)"),
    general = true,
})

Dispatcher:registerAction("set_book_background_color_fixed", {
    category = "string",
    event = "SetBookBackgroundColorFixed",
    title = _("Set background color application for reader pages (pdf, djvu, cbz...)"),
    args = { true, false },
    toggle = { _("on"), _("off") },
    general = true,
})

return { menu = background_color_menu, bgcolor = function() return bg_cached.bgcolor end }

local Blitbuffer = require("ffi/blitbuffer")
local ColorWheelWidget = require("widgets/colorwheelwidget")
local Device = require("device")
local Document = require("document/document")
local Event = require("ui/event")
local FileManager = require("apps/filemanager/filemanager")
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
local FixedBackgroundColor = Setting("book_background_color_reader_fixed", true) -- Whether the background color of fixed pages should be changed (default: true)

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

-- Recompute and cache the final colors based on current settings
-- Applies night mode inversion if enabled, and updates bg_cached.bgcolor only if it has changed
local function recomputeColors()
    local hex = (Screen.night_mode and bg_cached.alt_night_color) and bg_cached.night_hex or bg_cached.hex
    if Screen.night_mode then
        if bg_cached.alt_night_color or not bg_cached.invert_in_night_mode then
            hex = common.invertColor(hex)
        end
    end
    if hex ~= bg_cached.last_hex then
        bg_cached.bgcolor = Blitbuffer.colorFromString(hex)
        bg_cached.last_hex = hex
    end

    bg_cached.fgcolor = Blitbuffer.ColorRGB32(
        bg_cached.bgcolor:getR() * 0.6,
        bg_cached.bgcolor:getG() * 0.6,
        bg_cached.bgcolor:getB() * 0.6
    )
end

-- Compute and cache the initial bgcolor/fgcolor based on current settings
recomputeColors()

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

    recomputeColors()
end

local function refresh()
    -- Reapply page CSS
    if common.has_document_open() and ReaderUI.instance.rolling then
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
        end,
        separator = true,
    }
end

local function background_color_menu()
    return {
        text_func = function()
            return T(_("Background color: %1"), getBackgroundColor())
        end,
        sub_item_table = {
            {
                text_func = function()
                    return T(_("Current color: %1"), getBackgroundColor())
                end,
            },
            set_color_menu(),
            pick_color_menu(),
            {
                text = _("Alternative night mode color"),
                checked_func = AltNightBackgroundColor.get,
                callback = function()
                    AltNightBackgroundColor.toggle()
                    bg_cached.alt_night_color = AltNightBackgroundColor.get()

                    if Screen.night_mode then
                        recomputeColors()

                        if common.has_document_open() then
                            UIManager:broadcastEvent(Event:new("ApplyStyleSheet"))
                        end
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
                    recomputeColors()

                    if Screen.night_mode then
                        if common.has_document_open() then
                            UIManager:broadcastEvent(Event:new("ApplyStyleSheet"))
                        end
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
    local original_css = original_ReaderStyleTweak_getCssText(self)

    local bg_hex = (Screen.night_mode and bg_cached.alt_night_color) and bg_cached.night_hex or bg_cached.hex
    if Screen.night_mode then
        if bg_cached.alt_night_color or not bg_cached.invert_in_night_mode then
            bg_hex = common.invertColor(bg_hex)
        end
    end

    local bg_css = [[
        body {
            background-color: ]] .. bg_hex .. [[ !important;
        }
    ]]
    return util.trim(bg_css .. original_css)
end

-- Helper: check if dual pages are enabled (comicreader.koplugin)
local function has_dual_pages()
    local ui = ReaderUI.instance
    return ui.paging.isDualPageEnabled and ui.paging:isDualPageEnabled()
end

-- Helper: recolor light pixels as an alternative to RGB multiplication
local function recolorLightPixels(bb, x, y, w, h, c)
    local bb_w = bb:getWidth()
    local bb_h = bb:getHeight()
    local x0 = math.max(x, 0)
    local y0 = math.max(y, 0)
    local x1 = math.min(x + w - 1, bb_w - 1)
    local y1 = math.min(y + h - 1, bb_h - 1)
    for py = y0, y1 do
        for px = x0, x1 do
            local pixel = bb:getPixel(px, py)
            if pixel:getR() > 200 and pixel:getG() > 200 and pixel:getB() > 200 then
                bb:setPixel(px, py, c)
            end
        end
    end
end

-- Add background color to PDFs by using RGB multiplication (or replacement)
local original_Document_drawPage = Document.drawPage
function Document:drawPage(target, x, y, rect, pageno, zoom, rotation, gamma)
    original_Document_drawPage(self, target, x, y, rect, pageno, zoom, rotation, gamma)

    if not bg_cached.set_fixed_color then
        return
    end

    -- Manually replace white background in software-inverted night mode where multiplication would fail
    -- (Note that this doesn't work on Android due to the way it inverts during night mode)
    -- Or to have an idempotent effect when dual pages are enabled
    -- Otherwise, the right side of the screen becomes more saturated due to repeated multiplication
    local sw_invert = Screen.night_mode and not Device:canHWInvert()
    if not Device:isAndroid() and (sw_invert or has_dual_pages()) then
        recolorLightPixels(target, x, y, rect.w, rect.h, bg_cached.bgcolor)
    else
        target:multiplyRectRGB(x, y, rect.w, rect.h, bg_cached.bgcolor)
    end
end

-- Do the same for when "Invert Document" is enabled in night mode
-- Use the day mode bgcolor instead of the one for night mode
local original_Document_drawPageInverted = Document.drawPageInverted
function Document:drawPageInverted(target, x, y, rect, pageno, zoom, rotation, gamma)
    if not bg_cached.set_fixed_color then
        original_Document_drawPageInverted(self, target, x, y, rect, pageno, zoom, rotation, gamma)
        return
    end

    local bgcolor = Blitbuffer.colorFromString(bg_cached.hex)

    -- Multiply against background before inversion when hardware inversion is used
    if Device:canHWInvert() then
        local tile = self:renderPage(pageno, rect, zoom, rotation, gamma)
        target:blitFrom(tile.bb,
            x, y,
            rect.x - tile.excerpt.x,
            rect.y - tile.excerpt.y,
            rect.w, rect.h)
        target:multiplyRectRGB(x, y, rect.w, rect.h, bgcolor)
        target:invertRect(x, y, rect.w, rect.h)
    else
        original_Document_drawPageInverted(self, target, x, y, rect, pageno, zoom, rotation, gamma)
        -- Manually recolor in Android instead of using RGB multiplication
        if Device:isAndroid() then
            recolorLightPixels(target, x, y, rect.w, rect.h, bgcolor)
        else
            target:multiplyRectRGB(x, y, rect.w, rect.h, bgcolor:invert())
        end
    end
end

-- Finally, add background color to context pages
local original_KoptInterface_drawContextPage = KoptInterface.drawContextPage
function KoptInterface:drawContextPage(doc, target, x, y, rect, pageno, zoom, rotation, nightmode_invert)
    if not bg_cached.set_fixed_color then
        original_KoptInterface_drawContextPage(self, doc, target, x, y, rect, pageno, zoom, rotation, nightmode_invert)
        return
    end

    local bgcolor = nightmode_invert and Blitbuffer.colorFromString(bg_cached.hex) or bg_cached.bgcolor

    if nightmode_invert then
        -- Document:drawPageInverted path
        if Device:canHWInvert() then
            local tile = self:renderPage(doc, pageno, rect, zoom, rotation, 1.0)
            target:blitFrom(tile.bb,
                x, y,
                rect.x - tile.excerpt.x,
                rect.y - tile.excerpt.y,
                rect.w, rect.h)
            target:multiplyRectRGB(x, y, rect.w, rect.h, bgcolor)
            target:invertRect(x, y, rect.w, rect.h)
        else
            original_KoptInterface_drawContextPage(self, doc, target, x, y, rect, pageno, zoom, rotation,
                nightmode_invert)
            if Device:isAndroid() then
                recolorLightPixels(target, x, y, rect.w, rect.h, bgcolor)
            else
                target:multiplyRectRGB(x, y, rect.w, rect.h, bgcolor:invert())
            end
        end
    else
        -- Document:drawPage path
        original_KoptInterface_drawContextPage(self, doc, target, x, y, rect, pageno, zoom, rotation, nightmode_invert)
        local sw_invert = Screen.night_mode and not Device:canHWInvert()
        if not Device:isAndroid() and (sw_invert or has_dual_pages()) then
            recolorLightPixels(target, x, y, rect.w, rect.h, bg_cached.bgcolor)
        else
            target:multiplyRectRGB(x, y, rect.w, rect.h, bgcolor)
        end
    end
end

-- Hook into night mode state changes and update cache
local original_UIManager_ToggleNightMode = UIManager.ToggleNightMode
function UIManager:ToggleNightMode()
    original_UIManager_ToggleNightMode(self)

    recomputeColors()

    if bg_cached.alt_night_color or not bg_cached.invert_in_night_mode then
        if common.has_document_open() then
            UIManager:broadcastEvent(Event:new("ApplyStyleSheet"))
        end
    end
end

local original_UIManager_SetNightMode = UIManager.SetNightMode
function UIManager:SetNightMode(night_mode)
    original_UIManager_SetNightMode(self)

    if Screen.night_mode ~= night_mode then
        recomputeColors()

        if bg_cached.alt_night_color or not bg_cached.invert_in_night_mode then
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

    bg_cached.hex = HexBackgroundColor.get()
    bg_cached.night_hex = NightHexBackgroundColor.get()
    bg_cached.alt_night_color = AltNightBackgroundColor.get()
    recomputeColors()
    refresh()
end

local original_ReaderUI_onApplyTheme = ReaderUI.onApplyTheme
function ReaderUI:onApplyTheme()
    if original_ReaderUI_onApplyTheme then
        original_ReaderUI_onApplyTheme(self)
    end

    bg_cached.hex = HexBackgroundColor.get()
    bg_cached.night_hex = NightHexBackgroundColor.get()
    bg_cached.alt_night_color = AltNightBackgroundColor.get()
    recomputeColors()
    refresh()
end

return background_color_menu

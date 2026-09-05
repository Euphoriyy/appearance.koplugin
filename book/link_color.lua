local Blitbuffer = require("ffi/blitbuffer")
local ColorWheelWidget = require("widgets/colorwheelwidget")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local FileManager = require("apps/filemanager/filemanager")
local FootnoteWidget = require("ui/widget/footnotewidget")
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
local FixedLinkColor = Setting("book_link_color_fixed", true)

-- Cache
local link_cached = {
    alt_night_color = AltNightLinkColor.get(),
    invert_in_night_mode = InvertLinkColor.get(),
    set_fixed_color = FixedLinkColor.get(),
    hex = HexLinkColor.get(),
    night_hex = NightHexLinkColor.get(),
    computed_hex = nil,
    linkcolor = nil,
}

-- Recompute and cache the final link color based on current settings
-- Applies night mode inversion if enabled
local function recomputeLinkColor(is_doc_css)
    local hex = (Screen.night_mode and link_cached.alt_night_color) and link_cached.night_hex or link_cached.hex
    if not hex then -- Hex can be nil if using the default link colors
        link_cached.computed_hex = nil
        return
    end

    if Screen.night_mode then
        if link_cached.alt_night_color or not link_cached.invert_in_night_mode then
            hex = common.invertColor(hex)
        end
        -- Invert hex again if the reflowable document is inverting it
        if is_doc_css and common.isColorInversionActive() and not common.isGrayscale(hex) then
            hex = common.invertColor(hex)
        end
    end

    link_cached.computed_hex = hex
    link_cached.linkcolor = Blitbuffer.colorFromString(hex)
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

local function set_color_callback()
    return function(touchmenu_instance)
        local input_dialog
        input_dialog = InputDialog:new({
            title = "Enter custom color code",
            input = getLinkColor() or "#0000EE",
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
    end
end

local function pick_color_callback()
    return function(touchmenu_instance)
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
    end
end

local function link_color_menu()
    return {
        text_func = function()
            return T(_("Link color: %1"), getLinkColor() or "default")
        end,
        sub_item_table = {
            {
                text_func = function()
                    return T(_("Link color: %1 (hold to pick)"), getLinkColor() or "default")
                end,
                keep_menu_open = true,
                callback = set_color_callback(),
                hold_callback = pick_color_callback(),
            },
            {
                text = _("Reset color"),
                enabled_func = function() return getLinkColor() ~= nil end,
                keep_menu_open = true,
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
                separator = true,
            },
            {
                text = _("Apply to reader pages (pdf, djvu, cbz...)"),
                checked_func = FixedLinkColor.get,
                callback = function()
                    FixedLinkColor.toggle()
                    link_cached.set_fixed_color = FixedLinkColor.get()
                    refresh()
                end,
            },
        },
    }
end

-- Add link color to reader style tweak CSS if enabled
local original_ReaderStyleTweak_getCssText = ReaderStyleTweak.getCssText
function ReaderStyleTweak:getCssText()
    local original_css = original_ReaderStyleTweak_getCssText(self) or ""

    recomputeLinkColor(true)

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

-- Add font color to footnote popup CSS
local original_FootnoteWidget_init = FootnoteWidget.init
function FootnoteWidget:init()
    original_FootnoteWidget_init(self)

    local htmlwidget = self.htmlwidget
    local original_css = htmlwidget.css

    recomputeLinkColor()

    if link_cached.computed_hex then
        local link_css = [[
            a {
                color: ]] .. link_cached.computed_hex .. [[ !important;
            }
        ]]
        htmlwidget.css = util.trim(link_css .. original_css)
        htmlwidget.htmlbox_widget:setContent(htmlwidget.html_body, htmlwidget.css, htmlwidget.default_font_size,
            htmlwidget.is_xhtml, nil, htmlwidget.html_resource_directory)
    end
end

-- Recompute colors upon event call
local original_FileManager_onRecomputeAllColors = FileManager.onRecomputeAllColors
function FileManager:onRecomputeAllColors()
    if original_FileManager_onRecomputeAllColors then
        original_FileManager_onRecomputeAllColors(self)
    end

    recomputeLinkColor()
end

local original_ReaderUI_onRecomputeAllColors = ReaderUI.onRecomputeAllColors
function ReaderUI:onRecomputeAllColors()
    if original_ReaderUI_onRecomputeAllColors then
        original_ReaderUI_onRecomputeAllColors(self)
    end

    recomputeLinkColor()
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
end

-- Register toggling/setting application of link color to fixed document pages as dispatcher actions
local function ToggleBookLinkColorFixed()
    FixedLinkColor.toggle()
    link_cached.set_fixed_color = FixedLinkColor.get()
    refresh()
end

local function SetBookLinkColorFixed(apply_on)
    FixedLinkColor.set(apply_on)
    link_cached.set_fixed_color = apply_on
    refresh()
end

FileManager.onToggleBookLinkColorFixed = ToggleBookLinkColorFixed
ReaderUI.onToggleBookLinkColorFixed = ToggleBookLinkColorFixed

FileManager.onSetBookLinkColorFixed = SetBookLinkColorFixed
ReaderUI.onSetBookLinkColorFixed = SetBookLinkColorFixed

Dispatcher:registerAction("toggle_book_link_color_fixed", {
    category = "none",
    event = "ToggleBookLinkColorFixed",
    title = _("Toggle link color application for reader pages (pdf, djvu, cbz...)"),
    general = true,
})

Dispatcher:registerAction("set_book_link_color_fixed", {
    category = "string",
    event = "SetBookLinkColorFixed",
    title = _("Set link color application for reader pages (pdf, djvu, cbz...)"),
    args = { true, false },
    toggle = { _("on"), _("off") },
    general = true,
})

return {
    menu = link_color_menu,
    linkcolor = function() return link_cached.linkcolor end,
    hex = function() return link_cached.hex end,
    is_default = function() return link_cached.computed_hex == nil end,
    set_fixed_color = function() return link_cached.set_fixed_color end
}

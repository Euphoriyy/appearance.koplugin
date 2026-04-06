local Blitbuffer = require("ffi/blitbuffer")
local ColorWheelWidget = require("widgets/colorwheelwidget")
local DictQuickLookup = require("ui/widget/dictquicklookup")
local Event = require("ui/event")
local FileManager = require("apps/filemanager/filemanager")
local ReaderStyleTweak = require("apps/reader/modules/readerstyletweak")
local ReaderUI = require("apps/reader/readerui")
local RenderText = require("ui/rendertext")
local Screen = require("device").screen
local Setting = require("lib/setting")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local ToggleSwitch = require("ui/widget/toggleswitch")
local UIManager = require("ui/uimanager")
local bit = require("bit")
local common = require("lib/common")
local logger = require("logger")
local util = require("util")

-- Settings
local HexFontColor = Setting("ui_font_color_hex", "#000000")               -- RGB hex for UI font color (default: #000000)
local InvertFontColor = Setting("ui_font_color_inverted", true)            -- Whether the UI font color should be inverted in night mode (default: true)
local AltNightFontColor = Setting("ui_font_color_alt_night", false)        -- Whether the UI font color should be changed to an alternative color in night mode (default: false)
local NightHexFontColor = Setting("ui_font_color_night_hex", "#FFFFFF")    -- RGB hex for the alternative UI font color in night mode (default: #FFFFFF)
local TextBoxFontColor = Setting("ui_font_color_textbox", true)            -- Whether the font color of TextBoxWidgets should be changed (default: true)
local DictionaryFontColor = Setting("ui_font_color_dict", true)            -- Whether the font color of the dictionary should be changed (default: true)
local PageFontColor = Setting("ui_font_color_reader_page", false)          -- Whether the font color of the page should be changed (default: false)
local ReaderOnlyFontColor = Setting("ui_font_color_reader_only", false)    -- Whether the font color should be changed in the reader only (default: false)
local MarkupColors = Setting("ui_font_color_markup", true)                 -- Whether the markup colors should be enabled (default: true)
local InvertMarkupColors = Setting("ui_font_color_inverted_markup", false) -- Whether the markup colors should be inverted in night mode (default: false)

-- Cache
local fg_cached = {
    alt_night_color = AltNightFontColor.get(),
    invert_in_night_mode = InvertFontColor.get(),
    set_textbox_color = TextBoxFontColor.get(),
    set_dictionary_color = DictionaryFontColor.get(),
    set_page_color = PageFontColor.get(),
    reader_only = ReaderOnlyFontColor.get(),
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

local function refreshFileManager()
    if FileManager.instance then
        FileManager.instance.file_chooser:updateItems(1, true)
    end
end

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
    -- If TextBoxWidget colors are enabled, then update the file list
    if fg_cached.set_textbox_color then
        refreshFileManager()
    end

    -- Reapply page CSS
    if fg_cached.set_page_color and common.has_document_open() then
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

                        if fg_cached.set_textbox_color then
                            refreshFileManager()
                        end

                        if fg_cached.set_page_color and common.has_document_open() then
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
                        if fg_cached.set_textbox_color then
                            refreshFileManager()
                        end

                        if fg_cached.set_page_color and common.has_document_open() then
                            UIManager:broadcastEvent(Event:new("ApplyStyleSheet"))
                        end
                    end
                end,
                separator = true,
            },
            {
                text = _("Apply to text boxes (CoverBrowser)"),
                checked_func = TextBoxFontColor.get,
                callback = function()
                    TextBoxFontColor.toggle()
                    fg_cached.set_textbox_color = TextBoxFontColor.get()

                    -- Update the file list
                    refreshFileManager()
                end,
            },
            {
                text = _("Apply to dictionary text"),
                checked_func = DictionaryFontColor.get,
                callback = function()
                    DictionaryFontColor.toggle()
                    fg_cached.set_dictionary_color = DictionaryFontColor.get()
                end,
            },
            {
                text = _("Apply to reader pages (epub, html, fb2, txt...)"),
                checked_func = PageFontColor.get,
                callback = function()
                    PageFontColor.toggle()
                    fg_cached.set_page_color = PageFontColor.get()

                    if common.has_document_open() then
                        UIManager:broadcastEvent(Event:new("ApplyStyleSheet"))
                    end
                end,
            },
            {
                text = _("Apply in reader only"),
                checked_func = ReaderOnlyFontColor.get,
                callback = function()
                    ReaderOnlyFontColor.toggle()
                    fg_cached.reader_only = ReaderOnlyFontColor.get()

                    if fg_cached.set_textbox_color then
                        refreshFileManager()
                    end

                    if common.has_document_open() and fg_cached.set_page_color then
                        UIManager:broadcastEvent(Event:new("ApplyStyleSheet"))
                    end
                end,
                separator = true,
            },
            {
                text = _("Enable markup colors"),
                checked_func = MarkupColors.get,
                callback = function()
                    MarkupColors.toggle()
                end,
            },
            {
                text = _("Invert markup colors in night mode"),
                checked_func = InvertMarkupColors.get,
                callback = function()
                    InvertMarkupColors.toggle()
                end,
            },
        },
    }
end

-- Hook into night mode state changes and update cache
local original_UIManager_ToggleNightMode = UIManager.ToggleNightMode
function UIManager:ToggleNightMode()
    original_UIManager_ToggleNightMode(self)

    recomputeFGColor()

    if fg_cached.alt_night_color or not fg_cached.invert_in_night_mode then
        -- Refresh files if CoverBrowser is affected and night mode inversion is not enabled
        if fg_cached.set_textbox_color then
            refreshFileManager()
        end

        if fg_cached.set_page_color and common.has_document_open() then
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
            if fg_cached.set_textbox_color then
                refreshFileManager()
            end

            if fg_cached.set_page_color and common.has_document_open() then
                UIManager:broadcastEvent(Event:new("ApplyStyleSheet"))
            end
        end
    end
end

local band = bit.band
local bor = bit.bor
local lshift = bit.lshift

local function utf8Chars(input_text)
    local function read_next_glyph(input, pos)
        if string.len(input) < pos then return nil end
        local value = string.byte(input, pos)
        if band(value, 0x80) == 0 then
            --- @todo check valid ranges
            return pos + 1, value, string.sub(input, pos, pos)
        elseif band(value, 0xC0) == 0x80 -- invalid, continuation
            or band(value, 0xF8) == 0xF8 -- 5-or-more byte sequence, illegal due to RFC3629
        then
            return pos + 1, 0xFFFD, "\xFF\xFD"
        else
            local glyph, bytes_left
            if band(value, 0xE0) == 0xC0 then
                glyph = band(value, 0x1F)
                bytes_left = 1
            elseif band(value, 0xF0) == 0xE0 then
                glyph = band(value, 0x0F)
                bytes_left = 2
            elseif band(value, 0xF8) == 0xF0 then
                glyph = band(value, 0x07)
                bytes_left = 3
            else
                return pos + 1, 0xFFFD, "\xFF\xFD"
            end
            if string.len(input) < (pos + bytes_left) then
                return pos + 1, 0xFFFD, "\xFF\xFD"
            end
            for i = pos + 1, pos + bytes_left do
                value = string.byte(input, i)
                if band(value, 0xC0) == 0x80 then
                    glyph = bor(lshift(glyph, 6), band(value, 0x3F))
                else
                    -- invalid UTF8 continuation - don't be greedy, just skip
                    -- the initial char of the sequence.
                    return pos + 1, 0xFFFD, "\xFF\xFD"
                end
            end
            --- @todo check for valid ranges here!
            return pos + bytes_left + 1, glyph, string.sub(input, pos, pos + bytes_left)
        end
    end
    return read_next_glyph, input_text, 1
end

-- Hook into fallback text rendering for when xtext is disabled and add support for RGB fgcolors
function RenderText:renderUtf8Text(dest_bb, x, baseline, face, text, kerning, bold, fgcolor, width, char_pads)
    if not text then
        logger.warn("renderUtf8Text called without text")
        return 0
    end

    if not fgcolor then
        fgcolor = Blitbuffer.COLOR_BLACK
    end

    local pen_x = 0
    local prevcharcode = 0
    local text_width = dest_bb:getWidth() - x
    if width and width < text_width then
        text_width = width
    end
    local char_idx = 0
    for _, charcode, uchar in utf8Chars(text) do
        if pen_x < text_width then
            local glyph = self:getGlyph(face, charcode, bold)
            if kerning and (prevcharcode ~= 0) then
                pen_x = pen_x + face.ftsize:getKerning(prevcharcode, charcode)
            end
            dest_bb:colorblitFromRGB32(
                glyph.bb,
                x + pen_x + glyph.l,
                baseline - glyph.t,
                0, 0,
                glyph.bb:getWidth(), glyph.bb:getHeight(),
                fgcolor)
            pen_x = pen_x + glyph.ax
            prevcharcode = charcode
        end -- if pen_x < text_width
        if char_pads then
            char_idx = char_idx + 1
            pen_x = pen_x + (char_pads[char_idx] or 0)
        end
    end

    return pen_x
end

-- Color parsing helpers
local COLOR_MAP = {
    black    = Blitbuffer.COLOR_BLACK,
    white    = Blitbuffer.COLOR_WHITE,
    gray     = Blitbuffer.COLOR_GRAY,
    darkgray = Blitbuffer.COLOR_DARK_GRAY,
    red      = Blitbuffer.colorFromName("red"),
    orange   = Blitbuffer.colorFromName("orange"),
    yellow   = Blitbuffer.colorFromName("yellow"),
    green    = Blitbuffer.colorFromName("green"),
    olive    = Blitbuffer.colorFromName("olive"),
    cyan     = Blitbuffer.colorFromName("cyan"),
    blue     = Blitbuffer.colorFromName("blue"),
    purple   = Blitbuffer.colorFromName("purple"),
    pink     = Blitbuffer.colorFromName("#FF8DA1"),
}

local function parseColor(color_str, default_color)
    color_str = color_str:lower():gsub("%s", "")
    local named = COLOR_MAP[color_str]
    if named then return named end
    local hex = color_str:match("^#(%x+)$")
    if hex then
        if #hex == 3 then
            hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
        end
        local n = tonumber(hex, 16)
        if n then
            return Blitbuffer.ColorRGB32(
                bit.rshift(bit.band(n, 0xFF0000), 16),
                bit.rshift(bit.band(n, 0x00FF00), 8),
                bit.band(n, 0x0000FF)
            )
        end
    end
    return default_color
end

local SEP = "\xC2\xA7" -- § as explicit raw bytes

local function parseColorSegments(input, default_color)
    local segments = {}
    local pos = 1
    local current_color = nil

    while pos <= #input do
        local ms, color_str, me_open = input:match("()" .. SEP .. "([#%w][#%w]+) ()", pos)
        local rs, me_close = input:match("()" .. SEP .. "r()[ %d%u]", pos)
        if not rs then rs, me_close = input:match("()" .. SEP .. "r()$", pos) end

        local next_event, event_type
        if ms and (not rs or ms < rs) then
            next_event, event_type = ms, "open"
        elseif rs then
            next_event, event_type = rs, "close"
        end

        if not next_event then
            local plain = input:sub(pos)
            if #plain > 0 then
                table.insert(segments, { text = plain, color = current_color })
            end
            break
        end

        local plain = input:sub(pos, next_event - 1)
        if #plain > 0 then
            table.insert(segments, { text = plain, color = current_color })
        end

        if event_type == "open" then
            current_color = parseColor(color_str, default_color)
            pos = me_open
        else
            current_color = nil
            pos = me_close
        end
    end
    return segments
end

local function hasColorMarkers(text)
    return type(text) == "string" and text:find(SEP .. "[#%w]") ~= nil
end

local function stripColorMarkers(text)
    text = text:gsub(SEP .. "[#%w][#%w]+ ", "") -- Opening tags (2+ chars)
    text = text:gsub(SEP .. "r([ %d%u])", "%1") -- Followed by space, digit, or uppercase
    text = text:gsub(SEP .. "r$", "")           -- At end of string
    return text
end

-- Replace setText method so that it resets and recomputes the colored text on changes
function TextWidget:setText(text)
    if text == self.text then
        return
    end

    self._text_unstripped = nil
    self._color_segments = nil
    self._cluster_colors = nil
    self._updated = nil

    self.text = text
    self:free()
end

-- Hook into TextWidget updateSize to preprocess color markers before xtext sees the text
local original_TextWidget_updateSize = TextWidget.updateSize
function TextWidget:updateSize()
    if hasColorMarkers(self.text) then
        if MarkupColors.get() then
            if not self._color_segments then
                self._color_segments = parseColorSegments(self.text, self.fgcolor)

                -- Cache cluster_colors
                self._cluster_colors = {}
                local char_index = 1
                for _, seg in ipairs(self._color_segments) do
                    for _ in seg.text:gmatch(".[\128-\191]*") do
                        self._cluster_colors[char_index] = seg.color
                        char_index = char_index + 1
                    end
                end
            end
            if not self._text_unstripped then
                self._text_unstripped = self.text
                self.text = stripColorMarkers(self.text)
                self._updated = nil -- Force recompute with stripped text
            end
        else
            if not self._text_unstripped then
                self._text_unstripped = self.text
                self.text = stripColorMarkers(self.text)
                self._updated = nil -- Force recompute with stripped text
            end
        end
    end
    original_TextWidget_updateSize(self)
end

-- Special color which indicates that the color should either stay black or be set to the original fgcolor
local EXCLUSION_COLOR = Blitbuffer.colorFromString("#DAAAAD")
local EXCLUSION_COLOR_RGB32 = EXCLUSION_COLOR:getColorRGB32()

local function is_excluded(color)
    return color and color:getColorRGB32() == EXCLUSION_COLOR_RGB32
end

-- Hook into TextWidget painting
local original_TextWidget_paintTo = TextWidget.paintTo
function TextWidget:paintTo(bb, x, y)
    local original_fgcolor = self.fgcolor

    if is_excluded(original_fgcolor) then
        self.fgcolor = self.original_fgcolor or Blitbuffer.COLOR_BLACK
    elseif original_fgcolor == Blitbuffer.COLOR_DARK_GRAY then
        -- If the original color was dark gray, then place a lighter color
        self.fgcolor = common.lightenColor(fg_cached.fgcolor, 0.5)

        -- Set font color to dark gray when more contrast is needed
        if common.contrast(self.fgcolor, fg_cached.fgcolor) < 10 then
            self.fgcolor = Blitbuffer.COLOR_DARK_GRAY
        end
    else
        self.fgcolor = fg_cached.fgcolor
    end

    -- Use original B/W TextWidget painting method if color is not enabled,
    -- or if reader only is enabled and not in reader
    if not Screen:isColorEnabled() or (fg_cached.reader_only and not common.has_document_open()) then
        original_TextWidget_paintTo(self, bb, x, y)
        self.fgcolor = original_fgcolor
    else
        self:updateSize()
        if self._is_empty then
            return
        end

        local has_markers = MarkupColors.get() and self._color_segments ~= nil

        if not self.use_xtext then
            if has_markers then
                local cursor_x = x
                for _, seg in ipairs(self._color_segments) do
                    local fgcolor = seg.color or self.fgcolor
                    if Screen.night_mode and not InvertMarkupColors.get() and seg.color and fgcolor then
                        fgcolor = fgcolor:invert()
                    end
                    local seg_w = RenderText:sizeUtf8Text(cursor_x, bb:getWidth(), self.face, seg.text, true, self.bold)
                        .x
                    RenderText:renderUtf8Text(bb, cursor_x, y + self._baseline_h, self.face, seg.text,
                        true, self.bold, fgcolor, seg_w)
                    cursor_x = cursor_x + seg_w
                end
            else
                RenderText:renderUtf8Text(bb, x, y + self._baseline_h, self.face, self._text_to_draw,
                    true, self.bold, self.fgcolor, self._length)
            end
            return
        end

        -- Draw shaped glyphs with the help of xtext
        if not self._xshaping then
            self._xshaping = self._xtext:shapeLine(self._shape_start, self._shape_end,
                self._shape_idx_to_substitute_with_ellipsis)
        end

        -- Don't draw outside of BlitBuffer or max_width
        local text_width = bb:getWidth() - x
        if self.max_width and self.max_width < text_width then
            text_width = self.max_width
        end

        local pen_x = 0
        local baseline = self.forced_baseline or self._baseline_h
        local run_offset = 0
        local prev_text_index = 0
        for i, xglyph in ipairs(self._xshaping) do
            if pen_x >= text_width then
                break
            end

            if xglyph.text_index < prev_text_index then
                run_offset = run_offset + prev_text_index
            end
            prev_text_index = xglyph.text_index

            local face = self.face.getFallbackFont(xglyph.font_num) -- callback (not a method)
            local glyph = RenderText:getGlyphByIndex(face, xglyph.glyph, self.bold)

            -- Markup color for glyph (can be nil if falling back to fgcolor)
            local glyph_color = has_markers and
                (self._cluster_colors and self._cluster_colors[run_offset + xglyph.text_index])
            if Screen.night_mode and not InvertMarkupColors.get() and glyph_color then
                glyph_color = glyph_color:invert()
            end

            bb:colorblitFromRGB32(
                glyph.bb,
                x + pen_x + glyph.l + xglyph.x_offset,
                y + baseline - glyph.t - xglyph.y_offset,
                0, 0,
                glyph.bb:getWidth(), glyph.bb:getHeight(),
                glyph_color or self.fgcolor)
            pen_x = pen_x + xglyph.x_advance -- use Harfbuzz advance
        end
    end

    self.fgcolor = original_fgcolor
end

-- Hook into TextBoxWidget text rendering
local original_TextBoxWidget_renderText = TextBoxWidget._renderText
function TextBoxWidget:_renderText(start_row_idx, end_row_idx)
    local original_fgcolor = self.fgcolor

    if fg_cached.set_textbox_color and not (fg_cached.reader_only and not common.has_document_open()) then
        self.fgcolor = fg_cached.fgcolor
    end

    original_TextBoxWidget_renderText(self, start_row_idx, end_row_idx)

    self.fgcolor = original_fgcolor
end

-- Add font color CSS to HTML dictionary
local original_DictQuickLookup_getHtmlDictionaryCss = DictQuickLookup.getHtmlDictionaryCss
function DictQuickLookup:getHtmlDictionaryCss()
    local original_css = original_DictQuickLookup_getHtmlDictionaryCss(self)

    if fg_cached.set_dictionary_color and not (fg_cached.reader_only and not common.has_document_open()) then
        local fg_hex = (Screen.night_mode and fg_cached.alt_night_color) and fg_cached.night_hex or fg_cached.hex
        if Screen.night_mode then
            if fg_cached.alt_night_color or not fg_cached.invert_in_night_mode then
                fg_hex = common.invertColor(fg_hex)
            end
        end
        local custom_css = [[
            body {
                color: ]] .. fg_hex .. [[;
            }
        ]]

        return original_css .. custom_css
    else
        return original_css
    end
end

-- Add font color to reader style tweak CSS if enabled
local original_ReaderStyleTweak_getCssText = ReaderStyleTweak.getCssText
function ReaderStyleTweak:getCssText()
    local original_css = original_ReaderStyleTweak_getCssText(self)

    if fg_cached.set_page_color then
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
    else
        return original_css
    end
end

-- Hook into ToggleSwitch updates and fix the font color
-- Run late after the background color patch
UIManager:scheduleIn(1, function()
    local original_ToggleSwitch_update = ToggleSwitch.update

    function ToggleSwitch:update()
        original_ToggleSwitch_update(self)

        local pos = self.position
        for i = 1, #self.toggle_content do
            local row = self.toggle_content[i]
            for j = 1, #row do
                local cell = row[j]
                if pos == (i - 1) * self.n_pos + j then
                    cell[1][1].original_fgcolor = cell[1][1].fgcolor
                    cell[1][1].fgcolor = EXCLUSION_COLOR
                end
            end
        end
    end
end)

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

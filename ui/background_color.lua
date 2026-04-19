local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local ButtonProgressWidget = require("ui/widget/buttonprogresswidget")
local ButtonTable = require("ui/widget/buttontable")
local Cache = require("cache")
local ColorWheelWidget = require("widgets/colorwheelwidget")
local Device = require("device")
local DictQuickLookup = require("ui/widget/dictquicklookup")
local Event = require("ui/event")
local FileManager = require("apps/filemanager/filemanager")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HtmlBoxWidget = require("ui/widget/htmlboxwidget")
local IconWidget = require("ui/widget/iconwidget")
local ImageWidget = require("ui/widget/imagewidget")
local InputDialog = require("ui/widget/inputdialog")
local InputText = require("ui/widget/inputtext")
local LineWidget = require("ui/widget/linewidget")
local ProgressWidget = require("ui/widget/progresswidget")
local ReaderFooter = require("apps/reader/modules/readerfooter")
local ReaderUI = require("apps/reader/readerui")
local ReaderView = require("apps/reader/modules/readerview")
local RenderImage = require("ui/renderimage")
local Screen = Device.screen
local ScreenSaverWidget = require("ui/widget/screensaverwidget")
local Setting = require("lib/setting")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local ToggleSwitch = require("ui/widget/toggleswitch")
local UIManager = require("ui/uimanager")
local UnderlineContainer = require("ui/widget/container/underlinecontainer")
local VirtualKeyboard = require("ui/widget/virtualkeyboard")
local common = require("lib/common")
local logger = require("logger")
local userpatch = require("userpatch")
local util = require("util")

-- Settings
local HexBackgroundColor = Setting("ui_background_color_hex", "#FFFFFF")            -- RGB hex for UI background color (default: #FFFFFF)
local InvertBackgroundColor = Setting("ui_background_color_inverted", true)         -- Whether the UI background color should be inverted in night mode (default: true)
local AltNightBackgroundColor = Setting("ui_background_color_alt_night", false)     -- Whether the UI background color should be changed to an alternative color in night mode (default: false)
local NightHexBackgroundColor = Setting("ui_background_color_night_hex", "#000000") -- RGB hex for the alternative UI background color in night mode (default: #000000)
local InvertIcons = Setting("ui_background_color_invert_icons", true)               -- Whether icons should be inverted when an alternative night mode color is set
local TextBoxBackgroundColor = Setting("ui_background_color_textbox", true)         -- Whether the background color of TextBoxWidgets should be changed (default: true)
local BookBackgroundColor = Setting("ui_background_color_book", true)               -- Whether the book's background color should be used for the reader UI
local FooterBackgroundColor = Setting("ui_background_color_reader_footer", false)   -- Whether the background color of the ReaderFooter should be changed (default: false)
local SidesBackgroundColor = Setting("ui_background_color_reader_sides", true)      -- Whether the background color of the reader sides should be changed (default: true)
local GapBackgroundColor = Setting("ui_background_color_reader_gap", true)          -- Whether the background color of the page gap should be changed (default: true)
local OutlineColor = Setting("ui_background_color_lines", true)                     -- Whether the UI outline should be set to the chosen foreground color (default: true)
local BorderColor = Setting("ui_background_color_border", true)                     -- Whether the UI borders should be set to the chosen foreground color (default: true)

------------------------------------------------------------
-- ImageWidget specific code
------------------------------------------------------------

-- DPI_SCALE can't change without a restart, so let's compute it now
local function get_dpi_scale()
    local size_scale = math.min(Screen:getWidth(), Screen:getHeight()) * (1 / 600)
    local dpi_scale = Screen:scaleByDPI(1)
    return math.max(0, (math.log((size_scale + dpi_scale) / 2) / 0.69) ^ 2)
end
local DPI_SCALE = get_dpi_scale()

local ImageCache = Cache:new {
    -- 8 MiB of image cache, with 128 slots
    -- Overwhelmingly used for our icons, which are tiny in size, and not very numerous (< 100),
    -- but also by ImageViewer (on files, which we never do), and ScreenSaver (again, on image files, but not covers),
    -- hence the leeway.
    size = 8 * 1024 * 1024,
    avg_itemsize = 64 * 1024,
    -- Rely on our FFI finalizer to free the BBs on GC
    enable_eviction_cb = false,
}

--------------------------------------------
-- Lazy Loading
--------------------------------------------

local font_color

local function get_font_fgcolor()
    font_color = font_color or require("ui/font_color")
    return font_color.fgcolor()
end

local book_bgcolor

local function get_book_bgcolor()
    book_bgcolor = book_bgcolor or require("book/background_color")
    return book_bgcolor.bgcolor()
end

--------------------------------------------
-- Background Color
--------------------------------------------

-- Cache
local bg_cached = {
    alt_night_color = AltNightBackgroundColor.get(),
    invert_in_night_mode = InvertBackgroundColor.get(),
    invert_icons_in_night_mode = InvertIcons.get(),
    set_textbox_color = TextBoxBackgroundColor.get(),
    use_book_bgcolor = BookBackgroundColor.get(),
    set_footer_color = FooterBackgroundColor.get(),
    set_sides_color = SidesBackgroundColor.get(),
    set_gap_color = GapBackgroundColor.get(),
    set_outline_color = OutlineColor.get(),
    set_border_color = BorderColor.get(),
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

local function refreshFileManager()
    if FileManager.instance then
        FileManager.instance.file_chooser:updateItems(1, true)
    end
end

local function reloadIcons()
    ImageCache:clear()
    UIManager:broadcastEvent(Event:new("ChangeBackgroundColor"))
end

-- Handles RefreshFooterBackground event
-- Refresh the reader footer
function ReaderFooter:onRefreshFooterBackground()
    self:refreshFooter(true)
end

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
    -- If TextBoxWidget colors are enabled, then update the file list
    if bg_cached.set_textbox_color then
        refreshFileManager()
    end

    reloadIcons()
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

                        reloadIcons()

                        if bg_cached.set_textbox_color then
                            refreshFileManager()
                        end
                    end
                end,
            },
            {
                text = _("Invert icons in night mode"),
                enabled_func = function() return AltNightBackgroundColor.get() end,
                checked_func = InvertIcons.get,
                callback = function()
                    InvertIcons.toggle()
                    bg_cached.invert_icons_in_night_mode = InvertIcons.get()

                    if Screen.night_mode then
                        reloadIcons()
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
                        reloadIcons()

                        if bg_cached.set_textbox_color then
                            refreshFileManager()
                        end
                    end
                end,
                separator = true,
            },
            {
                text = _("Advanced settings"),
                sub_item_table = {
                    {
                        text = _("Use book's background color for reader UI"),
                        checked_func = BookBackgroundColor.get,
                        callback = function()
                            BookBackgroundColor.toggle()

                            bg_cached.use_book_bgcolor = BookBackgroundColor.get()
                        end,
                    },
                    {
                        text = _("Apply to the reader footer"),
                        checked_func = FooterBackgroundColor.get,
                        callback = function()
                            FooterBackgroundColor.toggle()
                            bg_cached.set_footer_color = FooterBackgroundColor.get()

                            if common.has_document_open() then
                                UIManager:broadcastEvent(Event:new("RefreshFooterBackground"))
                            end
                        end,
                    },
                    {
                        text = _("Apply to the reader sides"),
                        checked_func = SidesBackgroundColor.get,
                        callback = function()
                            SidesBackgroundColor.toggle()
                            bg_cached.set_sides_color = SidesBackgroundColor.get()
                        end,
                    },
                    {
                        text = _("Apply to the page gaps"),
                        checked_func = GapBackgroundColor.get,
                        callback = function()
                            GapBackgroundColor.toggle()
                            bg_cached.set_gap_color = GapBackgroundColor.get()
                        end,
                        separator = true,
                    },
                    {
                        text = _("Apply to text boxes (CoverBrowser)"),
                        checked_func = TextBoxBackgroundColor.get,
                        callback = function()
                            TextBoxBackgroundColor.toggle()
                            bg_cached.set_textbox_color = TextBoxBackgroundColor.get()

                            -- Update the file list
                            refreshFileManager()
                        end,
                    },
                    {
                        text = _("Apply foreground color to UI outlines"),
                        checked_func = OutlineColor.get,
                        callback = function()
                            OutlineColor.toggle()
                            bg_cached.set_outline_color = OutlineColor.get()
                        end,
                    },
                    {
                        text = _("Apply foreground color to UI borders"),
                        checked_func = BorderColor.get,
                        callback = function()
                            BorderColor.toggle()
                            bg_cached.set_border_color = BorderColor.get()
                        end,
                    },
                },
            },
        },
    }
end

-- Hook into FrameContainer painting (responsible for 80% of background)
local original_FrameContainer_paintTo = FrameContainer.paintTo
function FrameContainer:paintTo(bb, x, y)
    local original_background = self.background
    local original_color = self.color

    -- Change background color if it isn't transparent (nil)
    if original_background and not common.is_excluded(original_background) and original_background == Blitbuffer.COLOR_WHITE then
        self.background = bg_cached.bgcolor
        self.color = bg_cached.bgcolor:invert()
    elseif common.is_excluded(original_background) then
        self.background = self.original_background or Blitbuffer.COLOR_WHITE
    end

    original_FrameContainer_paintTo(self, bb, x, y)

    -- After default painting, repaint border
    if bg_cached.set_border_color then
        local fgcolor = get_font_fgcolor() or bg_cached.bgcolor:invert()

        local my_size = self:getSize()
        local container_width = self.width or my_size.w
        local container_height = self.height or my_size.h

        if self.bordersize > 0 then
            local anti_alias = G_reader_settings:nilOrTrue("anti_alias_ui")
            bb:paintBorderRGB32(x + self.margin, y + self.margin,
                container_width - self.margin * 2,
                container_height - self.margin * 2,
                self.bordersize, fgcolor, self.radius, anti_alias)
        end
    end

    self.background = original_background
    self.color = original_color
end

-- Exclude footer background color changes if option is not set
local original_ReaderFooter_updateFooterContainer = ReaderFooter.updateFooterContainer
function ReaderFooter:updateFooterContainer()
    original_ReaderFooter_updateFooterContainer(self)

    if not bg_cached.set_footer_color then
        self.footer_content.background = common.EXCLUSION_COLOR
    end
end

-- Exclude ScreenSaverWidget from background color changes
local original_ScreenSaverWidget_init = ScreenSaverWidget.init
function ScreenSaverWidget:init()
    original_ScreenSaverWidget_init(self)

    if self.background then
        self[1].original_background = self.background
        self[1].background = common.EXCLUSION_COLOR
    end
end

local function should_invert_icons()
    if bg_cached.alt_night_color then
        return bg_cached.invert_icons_in_night_mode
    end
    return bg_cached.invert_in_night_mode
end

-- Replace ImageWidget loading method
-- Responsible for icons matching the background
function ImageWidget:_loadfile()
    local DocumentRegistry = require("document/documentregistry")
    if DocumentRegistry:isImageFile(self.file) then
        -- In our use cases for files (icons), we either provide width and height,
        -- or just scale_for_dpi, and scale_factor should stay nil.
        -- Other combinations will result in double scaling, and unexpected results.
        -- We should anyway only give self.width and self.height to renderImageFile(),
        -- and use them in cache hash, when self.scale_factor is nil, when we are sure
        -- we don't need to keep aspect ratio.
        local width, height
        if self.scale_factor == nil and self.stretch_limit_percentage == nil then
            width = self.width
            height = self.height
        end
        local hash = "image|" ..
            self.file .. "|" .. tostring(width) .. "|" .. tostring(height) .. "|" .. (self.alpha and "alpha" or "flat")
        -- Do the scaling for DPI here, so it can be cached and not re-done
        -- each time in _render() (but not if scale_factor, to avoid double scaling)
        local scale_for_dpi_here = false
        if self.scale_for_dpi and DPI_SCALE ~= 1 and not self.scale_factor then
            scale_for_dpi_here = true          -- we'll do it before caching
            hash = hash .. "|d"
            self.already_scaled_for_dpi = true -- so we don't do it again in _render()
        end
        local cached = ImageCache:check(hash)
        if cached then
            -- hit cache
            self._bb = cached.bb
            self._bb_disposable = false -- don't touch or free a cached _bb
            self._is_straight_alpha = cached.is_straight_alpha
        else
            if util.getFileNameSuffix(self.file) == "svg" then
                local zoom
                if scale_for_dpi_here then
                    zoom = DPI_SCALE
                elseif self.scale_factor == 0 then
                    -- renderSVGImageFile() keeps aspect ratio by default
                    width = self.width
                    height = self.height
                end
                -- If NanoSVG is used by renderSVGImageFile, we'll get self._is_straight_alpha=true,
                -- and paintTo() must use alphablitFrom() instead of pmulalphablitFrom() (which is
                -- fine for everything MuPDF renders out)
                self._bb, self._is_straight_alpha = RenderImage:renderSVGImageFile(self.file, width, height, zoom)

                -- Ensure we always return a BB, even on failure
                if not self._bb then
                    logger.warn("ImageWidget: Failed to render SVG image file:", self.file)
                    self._bb = RenderImage:renderCheckerboard(width, height, Screen.bb:getType())
                    self._is_straight_alpha = false
                end
            else
                self._bb = RenderImage:renderImageFile(self.file, false, width, height)

                if not self._bb then
                    logger.warn("ImageWidget: Failed to render image file:", self.file)
                    self._bb = RenderImage:renderCheckerboard(width, height, Screen.bb:getType())
                    self._is_straight_alpha = false
                end

                if scale_for_dpi_here then
                    local bb_w, bb_h = self._bb:getWidth(), self._bb:getHeight()
                    self._bb = RenderImage:scaleBlitBuffer(self._bb, math.floor(bb_w * DPI_SCALE),
                        math.floor(bb_h * DPI_SCALE))
                end
            end

            -- Now, if that was *also* one of our icons, we haven't explicitly requested to keep the alpha channel intact,
            -- and it actually has an alpha channel, compose it against a background-colored BB now, and cache *that*.
            -- This helps us avoid repeating alpha-blending steps down the line,
            -- and also ensures icon highlights/unhighlights behave sensibly.
            if self.is_icon then
                if not self.alpha then
                    local bbtype = self._bb:getType()
                    if bbtype == Blitbuffer.TYPE_BB8A or bbtype == Blitbuffer.TYPE_BBRGB32 then
                        -- Invert so that icons stay the same
                        if Screen.night_mode and not should_invert_icons() then
                            self._bb:invert()
                        end

                        local icon_bb = Blitbuffer.new(self._bb.w, self._bb.h, Screen.bb:getType())

                        -- Fill icon's background with custom background color
                        if bg_cached.bgcolor then
                            icon_bb:paintRectRGB32(0, 0, icon_bb.w, icon_bb.h, bg_cached.bgcolor)
                        end

                        -- And now simply compose the icon on top of that, with dithering if necessary
                        -- Remembering that NanoSVG feeds us straight alpha, unlike MµPDF
                        if self._is_straight_alpha then
                            if Screen.sw_dithering then
                                icon_bb:ditheralphablitFrom(self._bb, 0, 0, 0, 0, icon_bb.w, icon_bb.h)
                            else
                                icon_bb:alphablitFrom(self._bb, 0, 0, 0, 0, icon_bb.w, icon_bb.h)
                            end
                        else
                            if Screen.sw_dithering then
                                icon_bb:ditherpmulalphablitFrom(self._bb, 0, 0, 0, 0, icon_bb.w, icon_bb.h)
                            else
                                icon_bb:pmulalphablitFrom(self._bb, 0, 0, 0, 0, icon_bb.w, icon_bb.h)
                            end
                        end

                        -- Reinvert back to original
                        if Screen.night_mode and not should_invert_icons() then
                            self._bb:invert()
                        end

                        -- Save the original alpha-channel icon for alpha masks and the flattened one
                        self._unflattened = self._bb
                        self._bb = icon_bb

                        -- There's no longer an alpha channel ;)
                        self._is_straight_alpha = nil
                    end
                elseif Screen.night_mode and not should_invert_icons() then
                    -- Invert icons with alpha so they stay the same
                    self._bb:invert()
                end
            end

            if not self.file_do_cache then
                self._bb_disposable = true  -- we made it, we can modify and free it
            else
                self._bb_disposable = false -- don't touch or free a cached _bb
                -- cache this image
                logger.dbg("cache", hash)
                cached = {
                    bb = self._bb,
                    is_straight_alpha = self._is_straight_alpha,
                }
                ImageCache:insert(hash, cached, tonumber(cached.bb.stride) * cached.bb.h)
            end
        end
    else
        error("Image file type not supported.")
    end
end

-- Replace ImageWidget painting to fix RGB dimming
function ImageWidget:paintTo(bb, x, y)
    if self.hide then return end
    -- self:_render is called in getSize method
    local size = self:getSize()
    if not self.dimen then
        self.dimen = Geom:new {
            x = x, y = y,
            w = size.w,
            h = size.h
        }
    else
        self.dimen.x = x
        self.dimen.y = y
    end
    logger.dbg("blitFrom", x, y, self._offset_x, self._offset_y, size.w, size.h)
    local do_alpha = false
    if self.alpha == true then
        -- Only actually try to alpha-blend if the image really has an alpha channel...
        local bbtype = self._bb:getType()
        if bbtype == Blitbuffer.TYPE_BB8A or bbtype == Blitbuffer.TYPE_BBRGB32 then
            do_alpha = true
        end
    end
    if do_alpha then
        --- @note: MuPDF feeds us premultiplied alpha (and we don't care w/ GifLib, as alpha is all or nothing),
        ---        while NanoSVG feeds us straight alpha.
        ---        SVG icons are currently flattened at caching time, so we'll only go through the straight alpha
        ---        codepath for non-icons SVGs.
        if self._is_straight_alpha then
            --- @note: Our icons are already dithered properly, either at encoding time, or at caching time.
            if Screen.sw_dithering and not self.is_icon then
                bb:ditheralphablitFrom(self._bb, x, y, self._offset_x, self._offset_y, size.w, size.h)
            else
                bb:alphablitFrom(self._bb, x, y, self._offset_x, self._offset_y, size.w, size.h)
            end
        else
            if Screen.sw_dithering and not self.is_icon then
                bb:ditherpmulalphablitFrom(self._bb, x, y, self._offset_x, self._offset_y, size.w, size.h)
            else
                bb:pmulalphablitFrom(self._bb, x, y, self._offset_x, self._offset_y, size.w, size.h)
            end
        end
    else
        if Screen.sw_dithering and not self.is_icon then
            bb:ditherblitFrom(self._bb, x, y, self._offset_x, self._offset_y, size.w, size.h)
        else
            bb:blitFrom(self._bb, x, y, self._offset_x, self._offset_y, size.w, size.h)
        end
    end
    if self.invert then
        bb:invertRect(x, y, size.w, size.h)
    end
    --- @note: This is mainly geared at black icons/text on a *white* background,
    ---        otherwise the background color itself will shift.
    ---        i.e., this actually *lightens* the rectangle, but since it's aimed at black,
    ---        it makes it gray, dimmer; hence the name.
    ---        TL;DR: If we one day want that to work for icons on a non-white background,
    ---        a better solution would probably be to take the icon pixmap as an alpha-mask,
    ---        (which simply involves blending it onto a white background, then inverting the result),
    ---        and colorBlit it a dim gray onto the target bb.
    ---        This would require the *original* transparent icon, not the flattened one in the cache.
    ---        c.f., https://github.com/koreader/koreader/pull/6937#issuecomment-748372429 for a PoC
    if self.dim and self._unflattened then
        -- bb:lightenRect(x, y, size.w, size.h)
        -- First, convert that black-on-transparent icon into an alpha mask (i.e., flat white on black)
        local icon_bb = Blitbuffer.new(self._unflattened.w, self._unflattened.h, Blitbuffer.TYPE_BB8)
        icon_bb:fill(Blitbuffer.Color8(0xFF)) -- We need *actual* white ^^
        icon_bb:alphablitFrom(self._unflattened, 0, 0, 0, 0, icon_bb.w, icon_bb.h)
        icon_bb:invertRect(0, 0, icon_bb.w, icon_bb.h)
        -- Then, use it as an alpha mask with a fg color set at the middle point of the eInk palette
        -- (much like black after the default dim)
        local fgcolor = Blitbuffer.COLOR_DARK_GRAY
        if Screen.night_mode and not should_invert_icons() then
            fgcolor = fgcolor:invert()
        end
        bb:colorblitFromRGB32(icon_bb, x, y, self._offset_x, self._offset_y, size.w, size.h, fgcolor)
        icon_bb:free()
    end
    -- In night mode, invert all rendered images, so the original is
    -- displayed when the whole screen is inverted by night mode.
    -- Except for our *black & white* icons: we do *NOT* want to invert them again:
    -- they should match the UI's text/background.
    --- @note: As for *color* icons, we really *ought* to invert them here,
    ---        but we currently don't, as we don't really trickle down
    ---        a way to discriminate them from the B&W ones.
    ---        Currently, this is *only* the KOReader icon in Help, AFAIK.
    if Screen.night_mode and self.original_in_nightmode and not self.is_icon then
        bb:invertRect(x, y, size.w, size.h)
    end
end

-- Handles ChangeBackgroundColor event
-- Reload icon images on background color changes
function IconWidget:onChangeBackgroundColor()
    self:free()
    self:init()
end

-- Reload icon images on night mode state changes
function IconWidget:onToggleNightMode()
    if bg_cached.alt_night_color or not bg_cached.invert_in_night_mode then
        self:free()
        self:init()
    end
end

function IconWidget:onSetNightMode(night_mode)
    if Screen.night_mode ~= night_mode and (bg_cached.alt_night_color or not bg_cached.invert_in_night_mode) then
        self:free()
        self:init()
    end
end

-- Hook into night mode state changes and update cache
local original_UIManager_ToggleNightMode = UIManager.ToggleNightMode
function UIManager:ToggleNightMode()
    original_UIManager_ToggleNightMode(self)

    recomputeColors()

    if bg_cached.alt_night_color or not bg_cached.invert_in_night_mode then
        -- Refresh files if CoverBrowser is affected and night mode inversion is not enabled
        if bg_cached.set_textbox_color then
            refreshFileManager()
        end

        ImageCache:clear()
    end
end

local original_UIManager_SetNightMode = UIManager.SetNightMode
function UIManager:SetNightMode(night_mode)
    original_UIManager_SetNightMode(self)

    if Screen.night_mode ~= night_mode then
        recomputeColors()

        if bg_cached.alt_night_color or not bg_cached.invert_in_night_mode then
            if bg_cached.set_textbox_color then
                refreshFileManager()
            end

            ImageCache:clear()
        end
    end
end

-- Replace UnderlineContainer painting
function UnderlineContainer:paintTo(bb, x, y)
    local container_size = self:getSize()
    if not self.dimen then
        self.dimen = Geom:new {
            x = x, y = y,
            w = container_size.w,
            h = container_size.h
        }
    else
        self.dimen.x = x
        self.dimen.y = y
    end

    local line_width = self.line_width or self.dimen.w
    local line_x = x
    if BD.mirroredUILayout() then
        line_x = line_x + self.dimen.w - line_width
    end

    local content_size = self[1]:getSize()
    local p_y = y
    if self.vertical_align == "center" then
        p_y = math.floor((container_size.h - content_size.h) / 2) + y
    elseif self.vertical_align == "bottom" then
        p_y = (container_size.h - content_size.h) + y
    end
    self[1]:paintTo(bb, x, p_y)

    -- Only paint underline if its color is NOT white
    if self.color ~= Blitbuffer.COLOR_WHITE then
        bb:paintRect(line_x, y + container_size.h - self.linesize,
            line_width, self.linesize, self.color)
    end
end

-- Hook into TextBoxWidget text rendering
local original_TextBoxWidget_renderText = TextBoxWidget._renderText
function TextBoxWidget:_renderText(start_row_idx, end_row_idx)
    local original_bgcolor = self.bgcolor

    if bg_cached.set_textbox_color and not self.alpha then
        self.bgcolor = bg_cached.bgcolor
    end

    original_TextBoxWidget_renderText(self, start_row_idx, end_row_idx)

    self.bgcolor = original_bgcolor
end

-- Add background color and color painting to LineWidget painting method
-- Responsible for separators between icons and document option tabs
function LineWidget:paintTo(bb, x, y)
    local original_background = self.background

    local fgcolor = bg_cached.set_outline_color and get_font_fgcolor()
        or bg_cached.bgcolor:invert()

    if original_background == Blitbuffer.COLOR_WHITE and not common.is_excluded(original_background) then
        self.background = bg_cached.bgcolor
    elseif common.is_excluded(original_background) then
        self.background = self.original_background
    else
        self.background = fgcolor
    end

    if self.style == "none" then return end
    if self.style == "dashed" then
        for i = 0, self.dimen.w - 20, 20 do
            bb:paintRectRGB32(x + i, y,
                16, self.dimen.h, self.background)
        end
    else
        if self.empty_segments then
            bb:paintRectRGB32(x, y,
                self.empty_segments[1].s,
                self.dimen.h,
                self.background)
            bb:paintRectRGB32(x + self.empty_segments[1].e, y,
                self.dimen.w - x - self.empty_segments[1].e,
                self.dimen.h,
                self.background)
        else
            bb:paintRectRGB32(x, y, self.dimen.w, self.dimen.h, self.background)
        end
    end

    self.background = original_background
end

-- Adjust InputText frame color to match background
local original_InputText_initTextBox = InputText.initTextBox
function InputText:initTextBox(text, char_added)
    original_InputText_initTextBox(self, text, char_added)

    self.focused_color = bg_cached.bgcolor:invert()
    self.unfocused_color = Blitbuffer.ColorRGB32(
        self.focused_color:getR() * 0.5,
        self.focused_color:getG() * 0.5,
        self.focused_color:getB() * 0.5
    )

    self._frame_textwidget.color = self.focused and self.focused_color or self.unfocused_color
end

function InputText:unfocus()
    self.focused = false
    self.text_widget:unfocus()
    self._frame_textwidget.color = self.unfocused_color
end

function InputText:focus()
    self.focused = true
    self.text_widget:focus()
    self._frame_textwidget.color = self.focused_color
end

-- Hook into HTMLBoxWidget rendering (DictQuickLookup) to add "flashui" refreshes to prevent ghosting
local original_HtmlBoxWidget_render = HtmlBoxWidget._render
function HtmlBoxWidget:_render()
    original_HtmlBoxWidget_render(self)

    -- Check for non-B/W background color
    local bg_hex = (Screen.night_mode and bg_cached.alt_night_color) and bg_cached.night_hex or bg_cached.hex
    if bg_hex ~= "#FFFFFF" and bg_hex ~= "#000000" then
        UIManager:setDirty(self.dialog or "all", function()
            return "flashui", self.dimen
        end)
    end
end

-- Add background color CSS to HTML dictionary
local original_DictQuickLookup_getHtmlDictionaryCss = DictQuickLookup.getHtmlDictionaryCss
function DictQuickLookup:getHtmlDictionaryCss()
    local original_css = original_DictQuickLookup_getHtmlDictionaryCss(self)

    local bg_hex = (Screen.night_mode and bg_cached.alt_night_color) and bg_cached.night_hex or bg_cached.hex
    if Screen.night_mode then
        if bg_cached.alt_night_color or not bg_cached.invert_in_night_mode then
            bg_hex = common.invertColor(bg_hex)
        end
    end
    local custom_css = [[
        body {
            background-color: ]] .. bg_hex .. [[;
        }
    ]]

    return original_css .. custom_css
end

-- Replace ToggleSwitch update method to use the appropriate colors
function ToggleSwitch:update()
    self.fgcolor = bg_cached.bgcolor:invert()

    self[1].original_background = bg_cached.bgcolor
    self[1].background = common.EXCLUSION_COLOR

    local pos = self.position
    for i = 1, #self.toggle_content do
        local row = self.toggle_content[i]
        for j = 1, #row do
            local cell = row[j]
            if pos == (i - 1) * self.n_pos + j then
                cell.color = self.fgcolor
                cell.original_background = self.fgcolor
                cell.background = common.EXCLUSION_COLOR
                cell[1][1].fgcolor = bg_cached.bgcolor
            else
                cell.color = self.bgcolor
                cell.background = self.bgcolor
                cell[1][1].fgcolor = Blitbuffer.COLOR_BLACK
                cell.bordersize = 0
            end
        end
    end
end

-- Change button inversion color for visual feedback
function Button:_doFeedbackHighlight()
    if self.text then
        if self[1].radius == nil or self.background then
            self[1].radius = Size.radius.button
            self[1].background = bg_cached.bgcolor:invert()
            self.label_widget.fgcolor = self.label_widget.fgcolor:invert()
        else
            self[1].invert = true
        end

        UIManager:widgetRepaint(self[1], self[1].dimen.x, self[1].dimen.y)
    else
        self[1].invert = true
        UIManager:widgetInvert(self[1], self[1].dimen.x, self[1].dimen.y)
    end
    UIManager:setDirty(nil, "fast", self[1].dimen)
end

-- Restore virtual keyboard key border with appropriate color
local MIN_KEY_BORDER_CONTRAST = 5

local original_VirtualKeyboard_addKeys = VirtualKeyboard.addKeys
function VirtualKeyboard:addKeys()
    original_VirtualKeyboard_addKeys(self)

    local border_color = bg_cached.fgcolor

    -- Set border color to dark gray when more contrast is needed
    if common.contrast(border_color, bg_cached.bgcolor) < MIN_KEY_BORDER_CONTRAST then
        border_color = Blitbuffer.COLOR_DARK_GRAY
    end

    local keyboard_frame = self[1][1]

    -- Key border
    if G_reader_settings:nilOrTrue("keyboard_key_border") then
        keyboard_frame.original_background = border_color
        keyboard_frame.background = common.EXCLUSION_COLOR
    end
end

-- Declare original methods before patching the plugin to prevent nested patching
local original_CalendarWeek_update, original_CalendarDayView_generateSpan, original_BookDailyItem_init

-- Restore background colors to reading statistics calendar (plugin)
userpatch.registerPatchPluginFunc("statistics", function()
    local CalendarView = require("calendarview")
    if not CalendarView then return end

    local CalendarWeek = userpatch.getUpValue(CalendarView._populateItems, "CalendarWeek")
    if CalendarWeek then
        if not original_CalendarWeek_update then
            original_CalendarWeek_update = CalendarWeek.update
        end

        function CalendarWeek:update()
            original_CalendarWeek_update(self)

            local overlaps = self[1][1]
            local span_index = 2

            for col, day_books in ipairs(self.days_books) do
                for _, book in ipairs(day_books) do
                    if book and book.start_day == col then
                        local span_w = overlaps[span_index][1]
                        span_index = span_index + 1

                        if Screen.night_mode and
                            (bg_cached.alt_night_color or not bg_cached.invert_in_night_mode) then
                            span_w.background = span_w.background:invert()
                        end
                    end
                end
            end
        end
    end

    local CalendarDayView = userpatch.getUpValue(CalendarView._populateItems, "CalendarDayView")
    if not CalendarDayView then return end

    if not original_CalendarDayView_generateSpan then
        original_CalendarDayView_generateSpan = CalendarDayView.generateSpan
    end

    function CalendarDayView:generateSpan(start, finish, bgcolor, fgcolor, title)
        local span = original_CalendarDayView_generateSpan(self, start, finish, bgcolor, fgcolor, title)
        if span then
            if Screen.night_mode and
                (bg_cached.alt_night_color or not bg_cached.invert_in_night_mode) then
                span.background = span.background:invert()
            end
        end
        return span
    end

    local BookDailyItem = userpatch.getUpValue(CalendarDayView._populateBooks, "BookDailyItem")
    if not BookDailyItem then return end

    if not original_BookDailyItem_init then
        original_BookDailyItem_init = BookDailyItem.init
    end

    function BookDailyItem:init()
        original_BookDailyItem_init(self)

        local container = self[1]
        local left_container = container and container[1]
        local horizontal_group = left_container and left_container[1]
        local overlap_group = horizontal_group and horizontal_group[3]
        local span = overlap_group and overlap_group[1]

        if span then
            if Screen.night_mode and
                (bg_cached.alt_night_color or not bg_cached.invert_in_night_mode) then
                span.background = span.background:invert()
            end
        end
    end
end)

-- Propagate properties from the button table entries to each button (or its FrameContainer)
local original_ButtonTable_init = ButtonTable.init
function ButtonTable:init()
    original_ButtonTable_init(self)

    for i = 1, #self.buttons_layout do
        for j = 1, #self.buttons_layout[i] do
            local btn_entry = self.buttons[i][j]
            if btn_entry and btn_entry.original_background then
                self.buttons_layout[i][j][1].original_background = btn_entry.original_background
            end
            -- Buttons in a button table should NOT be transparent
            self.buttons_layout[i][j].exclude_from_transparency = true
        end
    end
end

-- Add background, fill, and border colors to ProgressWidget init method
local original_ProgressWidget_init = ProgressWidget.init
function ProgressWidget:init()
    original_ProgressWidget_init(self)

    self.bgcolor = bg_cached.bgcolor
    self.fillcolor = bg_cached.bgcolor:invert()
    self.bordercolor = bg_cached.fgcolor
end

-- Change the highlighted color of the button progress widget
local original_ButtonProgressWidget_update = ButtonProgressWidget.update
function ButtonProgressWidget:update()
    original_ButtonProgressWidget_update(self)

    for i, button in ipairs(self.buttonprogress_content) do
        local highlighted = i <= self.position
        if highlighted then
            -- The button and its frame background will be inverted,
            -- so invert the color we want so it gets inverted back
            if button[1] and button[1].frame then
                button[1].frame.background = bg_cached.bgcolor
            end
        end
    end
end

-- Change the background color for the reader sides & page gaps
-- Page view mode
function ReaderView:drawPageSurround(bb, x, y)
    local bgcolor = bg_cached.use_book_bgcolor and get_book_bgcolor()
        or bg_cached.bgcolor
    local outer_page_color = bg_cached.set_sides_color and bgcolor or self.outer_page_color

    if self.dimen.h > self.visible_area.h then
        bb:paintRectRGB32(x, y, self.dimen.w, self.state.offset.y, outer_page_color)
        local bottom_margin = y + self.visible_area.h + self.state.offset.y
        bb:paintRectRGB32(x, bottom_margin, self.dimen.w, self.state.offset.y +
            self.footer:getHeight(), outer_page_color)
    end
    if self.dimen.w > self.visible_area.w then
        bb:paintRectRGB32(x, y, self.state.offset.x, self.dimen.h, outer_page_color)
        bb:paintRectRGB32(x + self.dimen.w - self.state.offset.x - 1, y,
            self.state.offset.x + 1, self.dimen.h, outer_page_color)
    end
end

-- Continuous view mode
function ReaderView:drawPageBackground(bb, x, y)
    local bgcolor = bg_cached.use_book_bgcolor and get_book_bgcolor()
        or bg_cached.bgcolor
    local page_bgcolor = bg_cached.set_sides_color and bgcolor or self.page_bgcolor

    bb:paintRectRGB32(x, y, self.dimen.w, self.dimen.h, page_bgcolor)
end

-- Continuous view mode - page gaps
function ReaderView:drawPageGap(bb, x, y)
    local bgcolor = bg_cached.use_book_bgcolor and get_book_bgcolor()
        or bg_cached.bgcolor
    local page_gap_color = bg_cached.set_gap_color and bgcolor or self.page_gap.color

    bb:paintRectRGB32(x, y, self.dimen.w, self.page_gap.height, page_gap_color)
end

userpatch.registerPatchPluginFunc("simpleui", function()
    -- Fix foreground color of progress bar being set to the background color
    local currently_reading = require("desktop_modules/module_currently")
    local Config = require("sui_config")
    if not (currently_reading and Config) then return end

    local original_buildProgressBarWithPct, buildProgressBarWithPct_idx = userpatch.getUpValue(currently_reading.build,
        "buildProgressBarWithPct")

    local function buildProgressBarWithPct(w, pct, bar_h, scale, lbl_scale, face_inline)
        local horizontal_group  = original_buildProgressBarWithPct(w, pct, bar_h, scale, lbl_scale, face_inline)
        local bar               = horizontal_group[1]

        local _BASE_PCT_W       = Screen:scaleBySize(32)
        local _BASE_BAR_PCT_GAP = Screen:scaleBySize(6)
        local PCT_W             = math.max(16, math.floor(_BASE_PCT_W * scale * lbl_scale))
        local GAP               = math.max(2, math.floor(_BASE_BAR_PCT_GAP * scale))
        local bar_w             = math.max(10, w - GAP - PCT_W)
        local fw                = math.max(0, math.floor(bar_w * math.min(pct, 1.0)))

        -- If bar is not fully filled
        if fw > 0 then
            -- Explicitly set background and foreground colors of the progress bar
            bar[1].original_background = bg_cached.fgcolor
            bar[1].background = common.EXCLUSION_COLOR
            bar[2].original_background = get_font_fgcolor()
            bar[2].background = common.EXCLUSION_COLOR
        end
        return horizontal_group
    end

    userpatch.replaceUpValue(currently_reading.build, buildProgressBarWithPct_idx, buildProgressBarWithPct)

    local SH = require("desktop_modules/module_books_shared")

    local original_SH_progressBar = SH.progressBar

    function SH.progressBar(w, pct, bh)
        local fw = math.max(0, math.floor(w * math.min(pct or 0, 1.0)))
        local bar = original_SH_progressBar(w, pct, bh)
        if fw <= 0 then
            bar.original_background = get_font_fgcolor()
            bar.background = common.EXCLUSION_COLOR
            return bar
        end
        bar[1].original_background = bg_cached.fgcolor
        bar[1].background = common.EXCLUSION_COLOR
        bar[2].original_background = get_font_fgcolor()
        bar[2].background = common.EXCLUSION_COLOR
        return bar
    end

    local reading_goals = require("desktop_modules/module_reading_goals")
    local buildGoalRow = userpatch.getUpValue(reading_goals.build, "buildGoalRow")
    local _, buildProgressBar_idx = userpatch.getUpValue(buildGoalRow, "buildProgressBar")

    userpatch.replaceUpValue(buildGoalRow, buildProgressBar_idx, SH.progressBar)
end)

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

return {
    menu = background_color_menu,
    bgcolor = function() return bg_cached.bgcolor end,
    reloadIcons = reloadIcons,
}

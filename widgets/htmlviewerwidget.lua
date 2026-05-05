--[[--
A general-purpose viewer widget that renders either plain text or an HTML body
inside a scrollable, titled dialog with configurable buttons.

Supports the same call-site API as KOReader's built-in TextViewer, with an
additional `is_html` flag (and optional `css` override) to switch the inner
scroll widget from ScrollTextWidget to ScrollHtmlWidget.

Example (plain text, default Close button):

    local HtmlViewerWidget = require("ui/widget/htmlviewer")
    local viewer = HtmlViewerWidget:new{
        title = _("Release notes"),
        text  = release_notes_string,
    }
    UIManager:show(viewer)

Example (HTML body, custom buttons, no default Close button):

    local HtmlViewerWidget = require("ui/widget/htmlviewer")
    local viewer
    viewer = HtmlViewerWidget:new{
        title   = _("Update available!"),
        text    = html_body_string,
        is_html = true,
        buttons_table = {
            {
                {
                    text = _("Close"),
                    callback = function() UIManager:close(viewer) end,
                },
                {
                    text = _("Update and restart"),
                    callback = function()
                        UIManager:close(viewer)
                        Updater.install(url, old_ver, new_ver)
                    end,
                },
            },
        },
        add_default_buttons = false,
    }
    UIManager:show(viewer)

--]]

local Blitbuffer       = require("ffi/blitbuffer")
local ButtonTable      = require("ui/widget/buttontable")
local CenterContainer  = require("ui/widget/container/centercontainer")
local Device           = require("device")
local Font             = require("ui/font")
local FrameContainer   = require("ui/widget/container/framecontainer")
local Geom             = require("ui/geometry")
local GestureRange     = require("ui/gesturerange")
local InputContainer   = require("ui/widget/container/inputcontainer")
local Math             = require("optmath")
local MovableContainer = require("ui/widget/container/movablecontainer")
local ScrollHtmlWidget = require("ui/widget/scrollhtmlwidget")
local ScrollTextWidget = require("ui/widget/scrolltextwidget")
local Size             = require("ui/size")
local TitleBar         = require("ui/widget/titlebar")
local UIManager        = require("ui/uimanager")
local VerticalGroup    = require("ui/widget/verticalgroup")
local VerticalSpan     = require("ui/widget/verticalspan")
local WidgetContainer  = require("ui/widget/container/widgetcontainer")
local _                = require("gettext")
local Screen           = Device.screen

--------------------------------------------
-- Lazy Loading
--------------------------------------------

local ui_bgcolor

local function get_ui_bg_hex()
    ui_bgcolor = ui_bgcolor or require("ui/background_color")
    return ui_bgcolor.bg_hex()
end

local font_color

local function get_ui_fg_hex()
    font_color = font_color or require("ui/font_color")
    return font_color.fg_hex()
end

local link_color

local function get_book_link_hex()
    link_color = link_color or require("book/link_color")
    return link_color.link_hex()
end

-- ---------------------------------------------------------------------------

local HtmlViewerWidget = InputContainer:extend {
    -- Required
    title                     = nil, -- string shown in the title bar
    text                      = nil, -- plain-text string or HTML body string

    -- HTML mode
    is_html                   = false, -- set true when `text` contains HTML markup
    css                       = nil,   -- optional extra CSS appended after the built-in defaults

    -- Layout
    width                     = nil, -- defaults to screen width minus some margin
    height                    = nil, -- when nil the widget auto-sizes to ~70 % of screen height

    -- Font (plain-text mode only; HTML mode uses its own CSS font-size)
    text_font_face            = "cfont",
    text_font_size            = 20, -- will be overridden by the "dict_font_size" setting if present
    justified                 = true,
    lang                      = nil,

    -- Buttons
    -- `buttons_table` mirrors the format expected by ButtonTable: a list of
    -- rows, each row being a list of button spec tables.
    buttons_table             = nil,
    add_default_buttons       = true, -- when true, a "Close" button row is appended

    -- Callbacks
    html_link_tapped_callback = nil, -- called when a link is tapped
    close_callback            = nil, -- called after the widget is closed
}

-- ---------------------------------------------------------------------------
-- Private helpers
-- ---------------------------------------------------------------------------

--- Build the base CSS used for HTML rendering, consistent with DictQuickLookup.
function HtmlViewerWidget:_buildCss()
    local css_justify = G_reader_settings:nilOrTrue("dict_justify")
        and "text-align: justify;" or ""
    local base = [[
        @page {
            margin: 0;
            font-family: 'Noto Sans';
        }
        body {
            margin: 0;
            line-height: 1.3;
            background-color: ]] .. get_ui_bg_hex() .. [[;
            color: ]] .. get_ui_fg_hex() .. [[;
            ]] .. css_justify .. [[
        }
        blockquote, dd {
            margin: 0 1em;
        }
        ol, ul, menu {
            margin: 0; padding: 0 1.7em;
        }
    ]]

    local link_hex = get_book_link_hex()
    if link_hex then
        base = base .. [[
            a {
                color: ]] .. link_hex .. [[;
            }
        ]]
    end

    if self.css then
        return base .. self.css
    end
    return base
end

--- Return the scroll widget and its inner content widget as a pair.
function HtmlViewerWidget:_getScrollAndContentWidgets()
    if self.is_html then
        return self._shw, self._shw and self._shw.htmlbox_widget
    else
        return self._stw, self._stw and self._stw.text_widget
    end
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function HtmlViewerWidget:init()
    -- ---- resolved settings ------------------------------------------------
    local font_size     = G_reader_settings:readSetting("dict_font_size")
        or self.text_font_size
    local content_face  = Font:getFace(self.text_font_face, font_size)

    -- ---- geometry ---------------------------------------------------------
    local frame_border  = Size.border.window
    local pad_h         = Size.padding.large -- horizontal content padding
    local pad_v         = Size.padding.large -- vertical span height

    self.width          = self.width
        or (Screen:getWidth() - Screen:scaleBySize(80))
    local inner_width   = self.width - 2 * frame_border
    local content_width = inner_width - 2 * pad_h

    -- ---- title bar --------------------------------------------------------
    self._title_bar     = TitleBar:new {
        width            = inner_width,
        title            = self.title or "",
        with_bottom_line = true,
        bottom_v_padding = 0,
        close_callback   = function() self:onClose() end,
        show_parent      = self,
    }

    -- ---- vertical spans ---------------------------------------------------
    local top_span      = VerticalSpan:new { width = pad_v }
    local bottom_span   = VerticalSpan:new { width = pad_v }

    -- ---- buttons ----------------------------------------------------------
    -- Start from a copy so we never mutate the caller's table.
    local buttons       = {}
    if self.buttons_table then
        for _, row in ipairs(self.buttons_table) do
            table.insert(buttons, row)
        end
    end
    if self.add_default_buttons then
        table.insert(buttons, {
            {
                text = _("Close"),
                callback = function() self:onClose() end,
            },
        })
    end

    -- ButtonTable requires at least one row; add a no-op placeholder when
    -- the caller explicitly passed an empty table with add_default_buttons=false.
    if #buttons == 0 then
        table.insert(buttons, {
            {
                text = _("Close"),
                callback = function() self:onClose() end,
            },
        })
    end

    local btn_padding   = Size.padding.default
    local btn_width     = inner_width - 2 * btn_padding
    self._button_table  = ButtonTable:new {
        width       = btn_width,
        buttons     = buttons,
        zero_sep    = true,
        show_parent = self,
    }

    -- ---- height calculation -----------------------------------------------
    local margin_top    = Size.margin.default
    local margin_bottom = Size.margin.default
    local avail_height  = Screen:getHeight() - margin_top - margin_bottom

    local fixed_height  = frame_border * 2
        + self._title_bar:getHeight()
        + top_span:getSize().h
        + bottom_span:getSize().h
        + self._button_table:getSize().h

    -- Measure how many whole text lines fit in 70 % of available height,
    -- then snap to that so no partial line is ever shown.
    local probe         = ScrollTextWidget:new {
        text                 = "z",
        face                 = content_face,
        width                = content_width,
        height               = 100,
        for_measurement_only = true,
    }
    local line_h        = probe:getLineHeight()
    probe:free(true)

    local target_h      = self.height or math.floor(avail_height * 0.70)
    local nb_lines      = Math.round(target_h / line_h)
    local content_h     = nb_lines * line_h
    -- Do not exceed what fits on screen.
    local max_content_h = avail_height - fixed_height
    if content_h > max_content_h then
        content_h = math.floor(max_content_h / line_h) * line_h
    end

    -- ---- scroll widget ----------------------------------------------------
    if self.is_html then
        self._shw = ScrollHtmlWidget:new {
            html_body                 = self.text,
            css                       = self:_buildCss(),
            default_font_size         = Screen:scaleBySize(font_size),
            width                     = content_width,
            height                    = content_h,
            dialog                    = self,
            highlight_text_selection  = true,
            html_link_tapped_callback = self.html_link_tapped_callback,
        }
        self._scroll_widget = self._shw
    else
        self._stw = ScrollTextWidget:new {
            text                     = self.text,
            face                     = content_face,
            width                    = content_width,
            height                   = content_h,
            dialog                   = self,
            justified                = self.justified,
            lang                     = self.lang,
            auto_para_direction      = true,
            highlight_text_selection = true,
        }
        self._scroll_widget = self._stw
    end

    -- Wrap the scroll widget with horizontal padding.
    local content_container = FrameContainer:new {
        padding       = 0,
        padding_left  = pad_h,
        padding_right = pad_h,
        margin        = 0,
        bordersize    = 0,
        self._scroll_widget,
    }

    -- ---- assemble frame ---------------------------------------------------
    self._frame = FrameContainer:new {
        radius     = Size.radius.window,
        bordersize = frame_border,
        padding    = 0,
        margin     = 0,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new {
            align = "left",
            self._title_bar,
            top_span,
            CenterContainer:new {
                dimen = Geom:new {
                    w = inner_width,
                    h = content_container:getSize().h,
                },
                content_container,
            },
            bottom_span,
            CenterContainer:new {
                dimen = Geom:new {
                    w = inner_width,
                    h = self._button_table:getSize().h,
                },
                self._button_table,
            },
        },
    }

    -- MovableContainer lets the user drag the dialog around.
    self._movable = MovableContainer:new {
        -- We handle swipe ourselves; don't let MovableContainer eat it.
        ignore_events = { "swipe" },
        self._frame,
    }

    -- Region for centering.
    self._region = Geom:new {
        x = 0,
        y = margin_top,
        w = Screen:getWidth(),
        h = avail_height,
    }

    self[1] = WidgetContainer:new {
        align = "center",
        dimen = self._region,
        self._movable,
    }

    -- ---- touch gestures ---------------------------------------------------
    if Device:isTouchDevice() then
        local range = Geom:new {
            x = 0, y = 0,
            w = Screen:getWidth(),
            h = Screen:getHeight(),
        }
        self.ges_events = {
            TapClose = {
                GestureRange:new { ges = "tap", range = range },
            },
            Swipe = {
                GestureRange:new { ges = "swipe", range = range },
            },
            -- Forward pan/touch so MovableContainer can do its job.
            ForwardingTouch = {
                GestureRange:new { ges = "touch", range = range },
            },
            ForwardingPan = {
                GestureRange:new { ges = "pan", range = range },
            },
            ForwardingPanRelease = {
                GestureRange:new { ges = "pan_release", range = range },
            },
        }
    end

    -- ---- key events -------------------------------------------------------
    if Device:hasKeys() then
        local Input = Device.input
        self.key_events = {
            Close = { { Input.group.Back } },
        }
    end
end

-- ---------------------------------------------------------------------------
-- Event handlers
-- ---------------------------------------------------------------------------

function HtmlViewerWidget:onShow()
    UIManager:setDirty(self, function()
        return "flashui", self._frame.dimen
    end)
    return true
end

function HtmlViewerWidget:onCloseWidget()
    -- Full-screen flash to erase any artefacts.
    UIManager:setDirty(nil, function()
        return "flashui", nil
    end)
end

--- Tap outside the dialog → close; tap inside the definition area → scroll.
function HtmlViewerWidget:onTapClose(_, ges)
    if ges.pos:notIntersectWith(self._frame.dimen) then
        self:onClose()
        return true
    end
    -- Taps inside the frame are handled by child widgets.
    return false
end

--- Swipe inside definition scrolls; swipe outside moves the dialog.
function HtmlViewerWidget:onSwipe(_, ges)
    local scroll_area = self._scroll_widget
    if scroll_area and ges.pos:intersectWith(scroll_area.dimen) then
        local direction = ges.direction
        if direction == "north" or direction == "south" then
            -- Let the scroll widget handle vertical swipes naturally via
            -- its own pan/swipe recognition; here we just block propagation.
            return true
        end
    end
    return self._movable:onMovableSwipe(_, ges)
end

--- Forward touch/pan/pan_release to MovableContainer.
function HtmlViewerWidget:onForwardingTouch(arg, ges)
    if not ges.pos:intersectWith(self._scroll_widget and self._scroll_widget.dimen) then
        return self._movable:onMovableTouch(arg, ges)
    else
        self._movable._touch_pre_pan_was_inside = false
    end
end

function HtmlViewerWidget:onForwardingPan(arg, ges)
    if self._movable._touch_pre_pan_was_inside or self._movable._moving then
        return self._movable:onMovablePan(arg, ges)
    end
end

function HtmlViewerWidget:onForwardingPanRelease(arg, ges)
    -- Mouse-wheel scroll support.
    if ges.from_mousewheel and ges.relative and ges.relative.y then
        local sw = self._scroll_widget
        if sw then
            if ges.relative.y < 0 then
                sw:onScrollDown()
            else
                sw:onScrollUp()
            end
        end
        return true
    end
    return self._movable:onMovablePanRelease(arg, ges)
end

--- Physical back key.
function HtmlViewerWidget:onClose_Key() -- mapped from key_events.Close
    self:onClose()
    return true
end

function HtmlViewerWidget:onClose()
    UIManager:close(self)
    if self.close_callback then
        self.close_callback()
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Public helpers
-- ---------------------------------------------------------------------------

--- Replace the displayed content without rebuilding the whole widget.
-- Useful for streaming / updating the text after opening.
-- @param new_text  string   new plain-text or HTML body
function HtmlViewerWidget:updateText(new_text)
    self.text = new_text
    local sw, cw = self:_getScrollAndContentWidgets()
    if not sw then return end

    if self.is_html then
        -- Re-feed the htmlbox widget with new markup.
        sw.htmlbox_widget:setContent(
            new_text,
            self:_buildCss(),
            Screen:scaleBySize(
                G_reader_settings:readSetting("dict_font_size") or self.text_font_size
            )
        )
        sw:resetScroll()
    else
        -- Update the underlying TextBoxWidget.
        cw.text             = new_text
        cw.charlist         = nil -- force re-init for non-xtext path
        cw.virtual_line_num = 1
        cw:init()
        sw:resetScroll()
    end

    UIManager:setDirty(self, function()
        return "partial", self._frame.dimen
    end)
end

-- ---------------------------------------------------------------------------

return HtmlViewerWidget

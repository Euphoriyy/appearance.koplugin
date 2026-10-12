local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local CircleWidget = require("widgets/circlewidget")
local Device = require("device")
local FocusManager = require("ui/widget/focusmanager")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local MovableContainer = require("ui/widget/container/movablecontainer")
local Screen = Device.screen
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Font = require("ui/font")
local common = require("lib/common")
local nf_icons = require("lib/nf_icons")

--------------------------------------------
-- Lazy Loading
--------------------------------------------

local font_color

local function get_font_fgcolor()
    font_color = font_color or require("ui/font_color")
    return font_color.fgcolor()
end

------------------------------------------------------------

local ColorWheelWidget = FocusManager:extend {
    title_text           = "Pick a color",
    width                = nil,
    width_factor         = 0.6,

    -- HSV values
    hue                  = 0, -- 0..360
    saturation           = 1,
    value                = 1,

    -- Whether to invert colors in night mode for accurate preview (default: true)
    invert_in_night_mode = true,

    -- Render the wheel at this fraction of full size, then scale up.
    -- Lower values are faster but produce more visible color banding.
    --
    -- | draw_scale | pixels rendered | speedup vs 1.0 |
    -- |------------|-----------------|----------------|
    -- | 1.0        | 100%            | 1x             |
    -- | 0.5        | 25%             | 4x             |
    -- | 0.25       | 6.25%           | 16x            |
    -- | 0.125      | 1.56%           | 64x            |
    draw_scale           = 0.5,

    cancel_text          = "Cancel",
    ok_text              = "Apply",

    callback             = nil,
    cancel_callback      = nil,
    close_callback       = nil,
}

------------------------------------------------------------
-- HSV → RGB
------------------------------------------------------------
local function hsvToRgb(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b
    if h < 60 then
        r, g, b = c, x, 0
    elseif h < 120 then
        r, g, b = x, c, 0
    elseif h < 180 then
        r, g, b = 0, c, x
    elseif h < 240 then
        r, g, b = 0, x, c
    elseif h < 300 then
        r, g, b = x, 0, c
    else
        r, g, b = c, 0, x
    end
    return
        math.floor((r + m) * 255 + 0.5),
        math.floor((g + m) * 255 + 0.5),
        math.floor((b + m) * 255 + 0.5)
end

------------------------------------------------------------
-- Per-radius lookup cache: hue + saturation for every pixel.
-- Built once per unique draw_radius, survives widget rebuilds.
-- Pixels outside the circle are marked with sat = -1.
--
-- Cap the cache at MAX_CACHE_ENTRIES entries (LRU eviction).
-- Without a bound the table grows forever if draw_scale or widget
-- size varies across the process lifetime.
------------------------------------------------------------
local _wheel_cache      = {}
local _wheel_cache_keys = {} -- insertion-order list for LRU eviction
local MAX_CACHE_ENTRIES = 8

local function getWheelCache(draw_radius)
    if _wheel_cache[draw_radius] then
        return _wheel_cache[draw_radius]
    end

    -- Evict oldest entry when the cache is full
    if #_wheel_cache_keys >= MAX_CACHE_ENTRIES then
        local oldest = table.remove(_wheel_cache_keys, 1)
        _wheel_cache[oldest] = nil
    end

    local r2    = draw_radius * draw_radius
    local hue_t = {}
    local sat_t = {}
    local idx   = 0

    for py = -draw_radius, draw_radius do
        for px = -draw_radius, draw_radius do
            idx = idx + 1
            local dist2 = px * px + py * py
            if dist2 <= r2 then
                hue_t[idx] = (math.deg(math.atan2(py, px)) + 360) % 360
                sat_t[idx] = math.sqrt(dist2) / draw_radius
            else
                sat_t[idx] = -1
            end
        end
    end

    local cache = { hue = hue_t, sat = sat_t }
    _wheel_cache[draw_radius] = cache
    table.insert(_wheel_cache_keys, draw_radius)
    return cache
end

------------------------------------------------------------
-- ColorWheel: draws the wheel into an off-screen buffer
-- and blits it to the screen. Redraws only when value changes;
-- hue/saturation changes only move the indicator dot.
------------------------------------------------------------
local ColorWheel = WidgetContainer:extend {
    radius               = 0,
    hue                  = 0,
    saturation           = 1,
    value                = 1,
    invert_in_night_mode = true,
    draw_scale           = 0.5,
    _needs_redraw        = true,
    _last_val            = nil,
    _cached_buf          = nil,
}

function ColorWheel:init()
    self.radius      = math.floor(self.dimen.w / 2)
    self.dimen       = Geom:new { x = 0, y = 0, w = self.dimen.w, h = self.dimen.h }
    self.night_mode  = self.invert_in_night_mode and Screen.night_mode
    self.draw_radius = math.max(1, math.floor(self.radius * self.draw_scale))

    -- Selection indicator: white disc with a dark dot, scaled to the wheel.
    -- Odd diameters so the circle centers exactly on the selected pixel.
    local outer_r    = math.max(2, math.floor(self.radius / 32 + 0.5))
    local inner_r    = math.max(1, math.floor(outer_r * 0.707 + 0.5))
    self._sel_outer  = CircleWidget:new {
        width      = outer_r * 2 + 1,
        height     = outer_r * 2 + 1,
        background = Blitbuffer.COLOR_WHITE,
    }
    self._sel_inner  = CircleWidget:new {
        width      = inner_r * 2 + 1,
        height     = inner_r * 2 + 1,
        background = get_font_fgcolor() or Blitbuffer.COLOR_BLACK,
    }

    -- Pre-warm the cache so the first paint doesn't stutter
    getWheelCache(self.draw_radius)
    self._needs_redraw = true
end

function ColorWheel:free()
    if self._cached_buf then
        self._cached_buf:free()
        self._cached_buf = nil
    end
end

function ColorWheel:_renderToBuffer(x, y)
    local dr      = self.draw_radius
    local side    = dr * 2 + 1
    local buf     = Blitbuffer.new(side, side, Blitbuffer.TYPE_BBRGB32)
    local bgcolor = Screen.bb:getPixel(x - 1, y - 1)
    buf:paintRectRGB32(0, 0, side, side, bgcolor)

    local cache       = getWheelCache(dr)
    local hue_t       = cache.hue
    local sat_t       = cache.sat
    local v           = self.value
    local nm          = self.night_mode
    local idx         = 0

    local bordercolor = get_font_fgcolor() or Blitbuffer.COLOR_BLACK
    for py = -dr, dr do
        for px = -dr, dr do
            idx = idx + 1
            local s = sat_t[idx]
            if s >= 0 then
                -- Draw border
                if sat_t[idx] >= 1 - Size.border.window / dr then
                    buf:setPixel(dr + px, dr + py, bordercolor)
                else -- Draw colors
                    local r, g, b = hsvToRgb(hue_t[idx], s, v)
                    if nm then r, g, b = 255 - r, 255 - g, 255 - b end
                    buf:setPixel(dr + px, dr + py,
                        Blitbuffer.ColorRGB32(r, g, b, 0xFF))
                end
            end
        end
    end

    -- Free any previous buffer before replacing it
    if self._cached_buf then
        self._cached_buf:free()
    end
    self._cached_buf   = buf
    self._last_val     = v
    self._needs_redraw = false
end

function ColorWheel:paintTo(bb, x, y)
    self.dimen.x = x
    self.dimen.y = y

    if self._needs_redraw or self._last_val ~= self.value then
        self:_renderToBuffer(x, y)
    end

    local disp_side = self.radius * 2

    if self.draw_scale < 1.0 then
        -- Scale the small buffer up to display size, then free it
        local scaled = self._cached_buf:scale(disp_side, disp_side)
        bb:blitFrom(scaled, x, y, 0, 0, disp_side, disp_side)
        scaled:free()
    else
        bb:blitFrom(self._cached_buf, x, y, 0, 0, disp_side, disp_side)
    end

    -- Selection indicator at full display resolution (always crisp)
    local cx    = x + self.radius
    local cy    = y + self.radius
    local sel_x = cx + math.floor(math.cos(math.rad(self.hue)) * self.saturation * self.radius + 0.5)
    local sel_y = cy + math.floor(math.sin(math.rad(self.hue)) * self.saturation * self.radius + 0.5)

    local outer = math.floor(self._sel_outer.width / 2)
    local inner = math.floor(self._sel_inner.width / 2)
    self._sel_outer:paintTo(bb, sel_x - outer, sel_y - outer)
    self._sel_inner:paintTo(bb, sel_x - inner, sel_y - inner)
end

function ColorWheel:updateColor(ges_pos)
    if not self.dimen then return false end

    local cx    = self.dimen.x + self.radius
    local cy    = self.dimen.y + self.radius
    local dx    = ges_pos.x - cx
    local dy    = ges_pos.y - cy
    local dist2 = dx * dx + dy * dy

    if dist2 > self.radius * self.radius then return false end

    self.hue        = (math.deg(math.atan2(dy, dx)) + 360) % 360
    self.saturation = math.min(1, math.sqrt(dist2) / self.radius)

    if self.update_callback then
        self.update_callback()
    end
    return true
end

------------------------------------------------------------
-- Live color preview — reads hue/sat/val at paint time,
-- no widget rebuild needed during drag.
------------------------------------------------------------
local function makeLivePreview(parent, preview_size)
    local LivePreview = WidgetContainer:extend {
        dimen = Geom:new { w = preview_size, h = preview_size },
    }
    function LivePreview:paintTo(bb, x, y)
        local r, g, b = hsvToRgb(parent.hue, parent.saturation, parent.value)
        local nm = parent.invert_in_night_mode
            and G_reader_settings:isTrue("night_mode")
        if nm then r, g, b = 255 - r, 255 - g, 255 - b end
        bb:paintRectRGB32(x, y, self.dimen.w, self.dimen.h,
            Blitbuffer.ColorRGB32(r, g, b, 0xFF))
    end

    return LivePreview:new {}
end

------------------------------------------------------------
-- Brightness slider: gradient from black to the current colour.
-- Reads hue/sat at paint time; writes parent.value on touch.
------------------------------------------------------------
local function makeBrightnessSlider(parent, width, height)
    local Slider = WidgetContainer:extend {
        dimen = Geom:new { w = width, h = height },
        gradient_hue = nil,
        gradient_saturation = nil,
    }

    function Slider:paintTo(bb, x, y)
        self.dimen.x, self.dimen.y = x, y
        local bar_h  = math.floor(height / 2)
        local bar_y  = y + math.floor((height - bar_h) / 2)
        local radius = math.floor(bar_h / 2)
        local nm     = parent.invert_in_night_mode and Screen.night_mode
        local fg     = get_font_fgcolor() or Blitbuffer.COLOR_BLACK

        -- Keep the gradient fixed while the slider is being dragged.
        local hue = self.gradient_hue or parent.hue
        local saturation = self.gradient_saturation or parent.saturation

        for i = 0, width - 1 do
            local inset = 0
            local d = (i < radius) and (radius - i - 0.5)
                or (i > width - 1 - radius) and (i - (width - 1 - radius) - 0.5)
                or nil
            if d then
                inset = math.floor(radius - math.sqrt(math.max(0, radius * radius - d * d)) + 0.5)
            end

            local r, g, b = hsvToRgb(hue, saturation, i / (width - 1))
            if nm then r, g, b = 255 - r, 255 - g, 255 - b end
            bb:paintRectRGB32(x + i, bar_y + inset, 1, bar_h - 2 * inset,
                Blitbuffer.ColorRGB32(r, g, b, 0xFF))
        end
        bb:paintBorder(x, bar_y, width, bar_h, Size.border.thin, fg, radius)

        -- The knob always follows the live brightness value.
        local kw = Screen:scaleBySize(10)
        local kx = x + math.floor(parent.value * (width - 1)) - math.floor(kw / 2)
        local kr = math.floor(kw / 2)
        bb:paintRoundedRect(kx, y, kw, height, Blitbuffer.COLOR_WHITE, kr)
        bb:paintBorder(kx, y, kw, height, Size.border.thick, fg, kr)
    end

    function Slider:hit(pos)
        local m = Size.padding.large
        return pos.x >= self.dimen.x - m and pos.x <= self.dimen.x + width + m
            and pos.y >= self.dimen.y - m and pos.y <= self.dimen.y + height + m
    end

    function Slider:setFromPos(pos)
        local v = (pos.x - self.dimen.x) / (width - 1)
        parent.value = math.max(0, math.min(1, v))
    end

    function Slider:beginDrag()
        self.gradient_hue = parent.hue
        self.gradient_saturation = parent.saturation
    end

    function Slider:endDrag()
        self.gradient_hue = nil
        self.gradient_saturation = nil
    end

    return Slider:new {}
end

------------------------------------------------------------
-- Live hex label — reads hue/sat/val at paint time.
------------------------------------------------------------
local function makeLiveHexLabel(parent, face)
    -- Fixed size so layout/centering is correct before the first paint
    local sample      = TextWidget:new { text = "#FFFFFF", face = face }
    local sample_size = sample:getSize()
    sample:free()

    local LiveHex = WidgetContainer:extend {
        dimen = Geom:new {
            w = sample_size.w + Screen:scaleBySize(16),
            h = sample_size.h,
        },
        _last_text = "",
        _tw = nil,
    }
    function LiveHex:paintTo(bb, x, y)
        local r, g, b = hsvToRgb(parent.hue, parent.saturation, parent.value)
        local txt = string.format("#%02X%02X%02X", r, g, b)
        -- Rebuild TextWidget only when the hex value actually changes
        if txt ~= self._last_text or not self._tw then
            if self._tw then self._tw:free() end
            self._tw = TextWidget:new { text = txt, face = face }
            self._last_text = txt
        end
        -- Center the text inside the fixed-width box
        local tw_size = self._tw:getSize()
        self._tw:paintTo(bb, x + math.floor((self.dimen.w - tw_size.w) / 2), y)
    end

    function LiveHex:free()
        if self._tw then
            self._tw:free()
            self._tw = nil
        end
    end

    return LiveHex:new {}
end

------------------------------------------------------------
-- Live brightness label — reads value at paint time.
------------------------------------------------------------
local function makeLiveValueLabel(parent, face)
    -- Fixed size from the widest text so centering is stable
    local sample      = TextWidget:new { text = "Brightness: 100%", face = face }
    local sample_size = sample:getSize()
    sample:free()

    local LiveValue = WidgetContainer:extend {
        dimen = Geom:new { w = sample_size.w, h = sample_size.h },
        _last_text = "",
        _tw = nil,
    }
    function LiveValue:paintTo(bb, x, y)
        self.dimen.x, self.dimen.y = x, y
        local txt = string.format("Brightness: %d%%", math.floor(parent.value * 100 + 0.5))
        if txt ~= self._last_text or not self._tw then
            if self._tw then self._tw:free() end
            self._tw = TextWidget:new { text = txt, face = face }
            self._last_text = txt
        end
        local tw_size = self._tw:getSize()
        self._tw:paintTo(bb, x + math.floor((self.dimen.w - tw_size.w) / 2), y)
    end

    function LiveValue:free()
        if self._tw then
            self._tw:free()
            self._tw = nil
        end
    end

    return LiveValue:new {}
end

------------------------------------------------------------
-- Main dialog
------------------------------------------------------------
function ColorWheelWidget:init()
    self.screen_width     = Screen:getWidth()
    self.screen_height    = Screen:getHeight()
    self.medium_font_face = Font:getFace("ffont")
    self.hex_font_face    = Font:getFace("infofont", 20)

    if not self.width then
        self.width = math.floor(
            math.min(self.screen_width, self.screen_height) * self.width_factor
        )
    end

    self.inner_width = self.width - 2 * Size.padding.large

    if Device:isTouchDevice() then
        self.ges_events = {
            TapColorWheel = {
                GestureRange:new {
                    ges   = "tap",
                    range = Geom:new { x = 0, y = 0,
                        w = self.screen_width, h = self.screen_height }
                }
            },
            PanColorWheel = {
                GestureRange:new {
                    ges   = "pan",
                    range = Geom:new { x = 0, y = 0,
                        w = self.screen_width, h = self.screen_height }
                }
            },
            PanReleaseColorWheel = {
                GestureRange:new {
                    ges   = "pan_release",
                    range = Geom:new { x = 0, y = 0,
                        w = self.screen_width, h = self.screen_height }
                }
            },
            HoldPanColorWheel = {
                GestureRange:new {
                    ges   = "hold_pan",
                    range = Geom:new { x = 0, y = 0,
                        w = self.screen_width, h = self.screen_height }
                }
            },
            HoldReleaseColorWheel = {
                GestureRange:new {
                    ges   = "hold_release",
                    range = Geom:new { x = 0, y = 0,
                        w = self.screen_width, h = self.screen_height }
                }
            },
            SwipeColorWheel = {
                GestureRange:new {
                    ges   = "swipe",
                    range = Geom:new { x = 0, y = 0,
                        w = self.screen_width, h = self.screen_height }
                }
            },
            MultiSwipeColorWheel = {
                GestureRange:new {
                    ges   = "multiswipe",
                    range = Geom:new { x = 0, y = 0,
                        w = self.screen_width, h = self.screen_height }
                }
            },
        }
    end

    self:update()
end

-- Free all owned FFI/widget resources before rebuilding the widget tree.
function ColorWheelWidget:_freeChildren()
    if self.color_wheel then
        self.color_wheel:free()
        self.color_wheel = nil
    end
    if self._live_hex then
        self._live_hex:free()
        self._live_hex = nil
    end
    if self._live_value then
        self._live_value:free()
        self._live_value = nil
    end
end

function ColorWheelWidget:onCloseWidget()
    self:_freeChildren()
end

function ColorWheelWidget:setHex(hex)
    local hue, saturation, value = common.hexToHSV(hex)
    if not hue then return false end
    self.hue, self.saturation, self.value = hue, saturation, value
    -- The wheel keeps its own hue/saturation for the selection dot,
    -- so a typed color needs a rebuild to move it.
    self:update()
    return true
end

function ColorWheelWidget:showHexInput()
    local InputDialog = require("ui/widget/inputdialog")
    local r, g, b = hsvToRgb(self.hue, self.saturation, self.value)
    local dialog
    dialog = InputDialog:new {
        title = "Enter color code",
        input = string.format("#%02X%02X%02X", r, g, b),
        input_hint = "#FFFFFF",
        buttons = { {
            {
                text = "Cancel",
                id = "close",
                callback = function() UIManager:close(dialog) end,
            },
            {
                text = "Set",
                is_enter_default = true,
                callback = function()
                    local text = dialog:getInputText()
                    if text ~= "" and text:match("^#%x%x%x%x%x%x$") then
                        self:setHex(text)
                    end
                    UIManager:close(dialog)
                end,
            },
        } },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function ColorWheelWidget:update()
    -- Free previous ColorWheel (and its _cached_buf) and LiveHex
    -- before creating new ones, so no orphaned FFI buffers are left behind.
    self:_freeChildren()

    local wheel_size   = self.width - 2 * Size.padding.large
    local preview_size = math.floor(wheel_size / 6)

    self.color_wheel   = ColorWheel:new {
        dimen                = Geom:new { w = wheel_size, h = wheel_size },
        hue                  = self.hue,
        saturation           = self.saturation,
        value                = 1, -- wheel always shows full brightness
        invert_in_night_mode = self.invert_in_night_mode,
        draw_scale           = self.draw_scale,
    }

    -- Live widgets read parent's hue/sat/val at paint time; no rebuild on drag
    self._live_preview = makeLivePreview(self, preview_size)
    self._live_hex     = makeLiveHexLabel(self, self.hex_font_face)
    self._hex_frame    = FrameContainer:new {
        bordersize = Size.border.button,
        radius     = Size.radius.button,
        margin     = 0,
        padding    = Size.padding.button,
        self._live_hex,
    }

    local title_bar    = TitleBar:new {
        width            = self.width,
        title            = nf_icons.label(nf_icons.EYEDROPPER, self.title_text),
        with_bottom_line = true,
        close_button     = true,
        close_callback   = function() self:onClose() end,
        show_parent      = self,
    }


    local value_label   = makeLiveValueLabel(self, self.medium_font_face)
    self._live_value    = value_label

    self._slider        = makeBrightnessSlider(self, wheel_size, Screen:scaleBySize(36))

    self._preview_frame = FrameContainer:new {
        bordersize = Size.border.thick,
        radius     = Size.radius.button,
        margin     = 0,
        padding    = 0,
        self._live_preview,
    }

    local preview_group = HorizontalGroup:new {
        align = "center",
        self._preview_frame,
        HorizontalSpan:new { width = Size.padding.large },
        self._hex_frame,
    }

    local cancel_button = Button:new {
        text        = self.cancel_text,
        width       = math.floor(self.width / 2) - Size.padding.large * 2,
        radius      = Size.radius.button,
        show_parent = self,
        callback    = function() self:onCancel() end,
    }

    local ok_button     = Button:new {
        text        = self.ok_text,
        width       = math.floor(self.width / 2) - Size.padding.large * 2,
        radius      = Size.radius.button,
        show_parent = self,
        callback    = function() self:onApply() end,
    }

    local button_row    = HorizontalGroup:new {
        align = "center",
        cancel_button,
        HorizontalSpan:new { width = Size.padding.large },
        ok_button,
    }

    local vgroup        = VerticalGroup:new {
        align = "center",
        title_bar,
        VerticalSpan:new { width = Size.padding.large },
        CenterContainer:new {
            dimen = Geom:new {
                w = self.width,
                h = value_label:getSize().h + self._slider.dimen.h + Size.padding.default,
            },
            VerticalGroup:new {
                align = "center",
                value_label,
                self._slider,
            },
        },
        VerticalSpan:new { width = Size.padding.large },
        CenterContainer:new {
            dimen = Geom:new {
                w = self.width,
                h = wheel_size + Size.padding.large * 2,
            },
            self.color_wheel,
        },
        VerticalSpan:new { width = Size.padding.large },
        CenterContainer:new {
            dimen = Geom:new {
                w = self.width,
                h = preview_size + Size.padding.default,
            },
            preview_group,
        },
        VerticalSpan:new { width = Size.padding.large * 2 },
        CenterContainer:new {
            dimen = Geom:new {
                w = self.width,
                h = Size.item.height_default,
            },
            button_row,
        },
        VerticalSpan:new { width = Size.padding.default },
    }

    self.frame          = FrameContainer:new {
        radius     = Size.radius.window,
        bordersize = Size.border.window,
        background = Blitbuffer.COLOR_WHITE,
        vgroup,
    }

    self.movable        = MovableContainer:new { self.frame }

    self[1]             = CenterContainer:new {
        dimen = Geom:new {
            x = 0, y = 0,
            w = self.screen_width, h = self.screen_height,
        },
        self.movable,
    }

    UIManager:setDirty(self, "ui")
end

------------------------------------------------------------
-- Gesture handlers
------------------------------------------------------------

-- Tap: update hue/sat.
-- Close on tap outside the dialog.
function ColorWheelWidget:onTapColorWheel(arg, ges_ev)
    self._pan_target = nil
    if not self.color_wheel.dimen or not self.frame.dimen then return true end

    if self._hex_frame and self._hex_frame.dimen
        and ges_ev.pos:intersectWith(self._hex_frame.dimen) then
        self:showHexInput()
        return true
    end
    if self._slider and self._slider:hit(ges_ev.pos) then
        self._slider:setFromPos(ges_ev.pos)
        UIManager:setDirty(self, "ui")
        return true
    end

    if ges_ev.pos:intersectWith(self.color_wheel.dimen) then
        if self.color_wheel:updateColor(ges_ev.pos) then
            self.hue        = self.color_wheel.hue
            self.saturation = self.color_wheel.saturation
            UIManager:setDirty(self, "ui")
        end
        return true
    elseif not ges_ev.pos:intersectWith(self.frame.dimen) then
        self:onClose()
        return true
    end
    return false
end

-- Screen regions that change while the brightness slider is dragged.
-- Deliberately excludes the wheel.
function ColorWheelWidget:_sliderDirtyRegions()
    local regions = {}
    if self._live_value and self._live_value.dimen and self._live_value.dimen.x
        and self._slider and self._slider.dimen then
        table.insert(regions, self._live_value.dimen:copy():combine(self._slider.dimen))
    end
    if self._preview_frame and self._preview_frame.dimen
        and self._hex_frame and self._hex_frame.dimen then
        table.insert(regions, self._preview_frame.dimen:copy():combine(self._hex_frame.dimen))
    end
    return regions
end

-- Screen rect covering the wheel's selection dot at the current hue/saturation.
-- Used to refresh only the dot's old and new positions while panning.
function ColorWheelWidget:_indicatorRect()
    local w = self.color_wheel
    if not (w and w.dimen and w.dimen.x and w._sel_outer) then return nil end
    local cx = w.dimen.x + w.radius
    local cy = w.dimen.y + w.radius
    local sx = cx + math.floor(math.cos(math.rad(self.hue)) * self.saturation * w.radius + 0.5)
    local sy = cy + math.floor(math.sin(math.rad(self.hue)) * self.saturation * w.radius + 0.5)
    local r  = math.floor(w._sel_outer.width / 2) + 2 -- small margin for the border
    return Geom:new { x = sx - r, y = sy - r, w = r * 2 + 1, h = r * 2 + 1 }
end

-- Screen rect covering the preview swatch and the hex label.
function ColorWheelWidget:_previewRegion()
    if self._preview_frame and self._preview_frame.dimen
        and self._hex_frame and self._hex_frame.dimen then
        return self._preview_frame.dimen:copy():combine(self._hex_frame.dimen)
    end
end

function ColorWheelWidget:_previewSwatchRegion()
    if self._preview_frame and self._preview_frame.dimen then
        return self._preview_frame.dimen:copy()
    end
end

-- Pan: sync values + fast-dirty + periodic ui-dirty.
function ColorWheelWidget:onPanColorWheel(arg, ges_ev)
    if not self.color_wheel or not self.color_wheel.dimen then return false end

    -- Lock onto whichever control the drag started on
    if not self._pan_target then
        if self._slider and self._slider:hit(ges_ev.pos) then
            self._pan_target = "slider"
        elseif ges_ev.pos:intersectWith(self.color_wheel.dimen) then
            self._pan_target = "wheel"
            self._ind_rect   = self:_indicatorRect() -- where the dot is before this drag moves it
        else
            return false
        end
    end

    if self._pan_target == "slider" then
        self._slider:setFromPos(ges_ev.pos)
    elseif not self.color_wheel:updateColor(ges_ev.pos) then
        return true
    else
        self.hue        = self.color_wheel.hue
        self.saturation = self.color_wheel.saturation
    end

    if self._pan_target == "slider" then
        -- Keep the gradient fixed, while updating the knob and swatch.
        if not self._slider_drag_started then
            self._slider:beginDrag()
            self._slider_drag_started = true
        end

        local slider = self._slider.dimen
        local preview = self:_previewSwatchRegion()

        UIManager:setDirty(self, "fast", slider)

        if preview then
            UIManager:setDirty(self, "fast", preview)
        end
    else
        -- Update the indicator and preview swatch during wheel dragging.
        local old = self._ind_rect
        local new = self:_indicatorRect()
        self._ind_rect = new

        if old then UIManager:setDirty(self, "fast", old) end
        if new then UIManager:setDirty(self, "fast", new) end

        local preview = self:_previewSwatchRegion()
        if preview then UIManager:setDirty(self, "fast", preview) end

        if not (old or new or preview) then
            UIManager:setDirty(self, "fast")
        end
    end

    return true
end

function ColorWheelWidget:onPanReleaseColorWheel(arg, ges_ev)
    if not self._pan_target then return false end
    local was_slider = self._pan_target == "slider"
    self._pan_target = nil
    self._ind_rect   = nil

    -- Everything is drawn live from hue/sat/value, so a clean refresh is
    -- enough. No rebuild needed.
    if was_slider then
        local regions = self:_sliderDirtyRegions()
        if #regions > 0 then
            for _, r in ipairs(regions) do
                UIManager:setDirty(self, "ui", r)
            end
        else
            UIManager:setDirty(self, "ui")
        end
    else
        -- Finish wheel drag: clear indicator ghosts and update
        -- the preview and brightness gradient after the pan ends.
        UIManager:setDirty(self, "partial", self.color_wheel.dimen)

        local preview = self:_previewRegion()
        if preview then
            UIManager:setDirty(self, "ui", preview)
        end

        local slider_regions = self:_sliderDirtyRegions()
        for _, r in ipairs(slider_regions) do
            UIManager:setDirty(self, "ui", r)
        end
    end
    return true
end

-- A fast flick ends as a swipe instead of a pan release. The value is already
-- set by the pan events, so just finish the drag the same way.
function ColorWheelWidget:onSwipeColorWheel(arg, ges_ev)
    return self:onPanReleaseColorWheel(arg, ges_ev)
end

ColorWheelWidget.onMultiSwipeColorWheel  = ColorWheelWidget.onSwipeColorWheel
ColorWheelWidget.onHoldPanColorWheel     = ColorWheelWidget.onPanColorWheel
ColorWheelWidget.onHoldReleaseColorWheel = ColorWheelWidget.onPanReleaseColorWheel

function ColorWheelWidget:onApply()
    UIManager:close(self)
    if self.callback then
        local r, g, b = hsvToRgb(self.hue, self.saturation, self.value)
        self.callback(string.format("#%02X%02X%02X", r, g, b))
    end
    if self.close_callback then self.close_callback() end
    return true
end

function ColorWheelWidget:onClose()
    UIManager:close(self)
    if self.close_callback then self.close_callback() end
    return true
end

function ColorWheelWidget:onCancel()
    UIManager:close(self)
    if self.cancel_callback then self.cancel_callback() end
    if self.close_callback then self.close_callback() end
    return true
end

function ColorWheelWidget:onShow()
    UIManager:setDirty(self, "ui", nil, true)
    return true
end

return ColorWheelWidget

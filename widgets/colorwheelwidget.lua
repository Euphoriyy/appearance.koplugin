local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local FocusManager = require("ui/widget/focusmanager")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local MovableContainer = require("ui/widget/container/movablecontainer")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Font = require("ui/font")
local Screen = Device.screen
local common = require("lib/common")

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
------------------------------------------------------------
local _wheel_cache = {}

local function getWheelCache(draw_radius)
    if _wheel_cache[draw_radius] then
        return _wheel_cache[draw_radius]
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
    -- Pre-warm the cache so the first paint doesn't stutter
    getWheelCache(self.draw_radius)
    self._needs_redraw = true
end

function ColorWheel:_renderToBuffer(x, y)
    local dr      = self.draw_radius
    local side    = dr * 2 + 1
    local buf     = Blitbuffer.new(side, side, Blitbuffer.TYPE_BBRGB32)
    local bgcolor = Screen.bb:getPixel(x - 1, y - 1)
    common.fillRGB(buf, Blitbuffer.TYPE_BBRGB32, bgcolor)

    local cache = getWheelCache(dr)
    local hue_t = cache.hue
    local sat_t = cache.sat
    local v     = self.value
    local nm    = self.night_mode
    local idx   = 0

    for py = -dr, dr do
        for px = -dr, dr do
            idx = idx + 1
            local s = sat_t[idx]
            if s >= 0 then
                local r, g, b = hsvToRgb(hue_t[idx], s, v)
                if nm then r, g, b = 255 - r, 255 - g, 255 - b end
                buf:setPixel(dr + 1 + px, dr + 1 + py,
                    Blitbuffer.ColorRGB32(r, g, b, 0xFF))
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

    for py = -4, 4 do
        for px = -4, 4 do
            local d = px * px + py * py
            if d <= 16 then
                bb:setPixelClamped(sel_x + px, sel_y + py, Blitbuffer.COLOR_WHITE)
            end
            if d <= 9 then
                bb:setPixelClamped(sel_x + px, sel_y + py, Blitbuffer.COLOR_BLACK)
            end
        end
    end
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
-- Live hex label — reads hue/sat/val at paint time.
------------------------------------------------------------
local function makeLiveHexLabel(parent, face)
    local LiveHex = WidgetContainer:extend {
        dimen = Geom:new { w = 0, h = 0 },
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
            local sz = self._tw:getSize()
            self.dimen.w = sz.w
            self.dimen.h = sz.h
        end
        self._tw:paintTo(bb, x, y)
    end

    return LiveHex:new {}
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

    self.inner_width  = self.width - 2 * Size.padding.large
    self.button_width = math.floor(self.inner_width / 4)

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
        }
    end

    self:update()
end

function ColorWheelWidget:update()
    local wheel_size    = self.width - 2 * Size.padding.large
    local preview_size  = math.floor(wheel_size / 4)

    self.color_wheel    = ColorWheel:new {
        dimen                = Geom:new { w = wheel_size, h = wheel_size },
        hue                  = self.hue,
        saturation           = self.saturation,
        value                = self.value,
        invert_in_night_mode = self.invert_in_night_mode,
        draw_scale           = self.draw_scale,
        -- update_callback is NOT set here — pan bypasses update() entirely
    }

    -- Live widgets read parent's hue/sat/val at paint time; no rebuild on drag
    self._live_preview  = makeLivePreview(self, preview_size)
    self._live_hex      = makeLiveHexLabel(self, self.hex_font_face)

    local title_bar     = TitleBar:new {
        width            = self.width,
        title            = self.title_text,
        with_bottom_line = true,
        close_button     = true,
        close_callback   = function() self:onCancel() end,
        show_parent      = self,
    }

    local value_minus   = Button:new {
        text        = "−",
        enabled     = self.value > 0,
        width       = self.button_width,
        show_parent = self,
        callback    = function()
            self.value = math.max(0, self.value - 0.1)
            -- Brightness change requires wheel re-render: use full update()
            self.color_wheel._needs_redraw = true
            self:update()
        end,
    }

    local value_plus    = Button:new {
        text        = "＋",
        enabled     = self.value < 1,
        width       = self.button_width,
        show_parent = self,
        callback    = function()
            self.value = math.min(1, self.value + 0.1)
            self.color_wheel._needs_redraw = true
            self:update()
        end,
    }

    local value_label   = TextWidget:new {
        text = string.format("Brightness: %d%%", math.floor(self.value * 100)),
        face = self.medium_font_face,
    }

    local value_group   = HorizontalGroup:new {
        align = "center",
        value_minus,
        HorizontalSpan:new { width = Size.padding.large },
        value_label,
        HorizontalSpan:new { width = Size.padding.large },
        value_plus,
    }

    local preview_group = HorizontalGroup:new {
        align = "center",
        FrameContainer:new {
            bordersize = Size.border.thick,
            margin     = 0,
            padding    = 0,
            self._live_preview,
        },
        HorizontalSpan:new { width = Size.padding.large },
        self._live_hex,
    }

    local cancel_button = Button:new {
        text        = self.cancel_text,
        width       = math.floor(self.width / 2) - Size.padding.large * 2,
        show_parent = self,
        callback    = function() self:onCancel() end,
    }

    local ok_button     = Button:new {
        text        = self.ok_text,
        width       = math.floor(self.width / 2) - Size.padding.large * 2,
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
                h = value_label:getSize().h + Size.padding.default,
            },
            value_group,
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
    if not self.color_wheel.dimen or not self.frame.dimen then return true end

    if ges_ev.pos:intersectWith(self.color_wheel.dimen) then
        if self.color_wheel:updateColor(ges_ev.pos) then
            self.hue        = self.color_wheel.hue
            self.saturation = self.color_wheel.saturation
            UIManager:setDirty(self, "ui")
        end
        return true
    elseif not ges_ev.pos:intersectWith(self.frame.dimen) then
        self:onCancel()
        return true
    end
    return false
end

-- Pan: sync values + fast-dirty + periodic ui-dirty only the wheel region.
function ColorWheelWidget:onPanColorWheel(arg, ges_ev)
    if not self.color_wheel or not self.color_wheel.dimen then return false end

    if ges_ev.pos:intersectWith(self.color_wheel.dimen) then
        if self.color_wheel:updateColor(ges_ev.pos) then
            self.hue        = self.color_wheel.hue
            self.saturation = self.color_wheel.saturation

            self._pan_tick  = (self._pan_tick or 0) + 1
            local mode      = (self._pan_tick % 8 == 0) and "ui" or "fast"

            UIManager:setDirty(self, mode)
        end
        return true
    end
    return false
end

-- Pan release: one clean "ui" refresh to fix A2 ghosting,
-- plus a full update() so the hex label and preview sync up.
function ColorWheelWidget:onPanReleaseColorWheel(arg, ges_ev)
    if not self.color_wheel or not self.color_wheel.dimen then return false end

    if ges_ev.pos:intersectWith(self.color_wheel.dimen) then
        self:update() -- rebuilds widget tree with final hue/sat; does "ui" dirty
        return true
    end
    return false
end

function ColorWheelWidget:onApply()
    UIManager:close(self)
    if self.callback then
        local r, g, b = hsvToRgb(self.hue, self.saturation, self.value)
        self.callback(string.format("#%02X%02X%02X", r, g, b))
    end
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
    UIManager:setDirty(self, "ui")
    return true
end

return ColorWheelWidget

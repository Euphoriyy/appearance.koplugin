local Blitbuffer = require("ffi/blitbuffer")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

--------------------------------------------
-- Lazy Loading
--------------------------------------------

local font_color

local function get_font_fgcolor()
    font_color = font_color or require("ui/font_color")
    return font_color.fgcolor()
end

--------------------------------------------

local AlphaTextBoxWidget = WidgetContainer:extend {
    text = nil,
    face = nil,
    bold = nil,
    width = 200,
    height = nil,
    alignment = "left",
    justified = false,
    line_height = 0.3,
    fgcolor = Blitbuffer.COLOR_BLACK,
    bgcolor = Blitbuffer.COLOR_WHITE,
    bg_alpha = 0,
}

function AlphaTextBoxWidget:init()
    self._textbox = TextBoxWidget:new {
        text = self.text,
        face = self.face,
        bold = self.bold,
        width = self.width,
        height = self.height,
        alignment = self.alignment,
        justified = self.justified,
        line_height = self.line_height,
        fgcolor = Blitbuffer.COLOR_BLACK,
        bgcolor = Blitbuffer.COLOR_WHITE,
        alpha = true,
    }
    self.dimen = self._textbox:getSize()
end

function AlphaTextBoxWidget:getSize()
    return self.dimen
end

function AlphaTextBoxWidget:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    local w = self.dimen.w
    local h = self.dimen.h

    if self.bg_alpha > 0 then
        local bg = self.bgcolor or Blitbuffer.COLOR_WHITE
        if self.bg_alpha >= 255 then
            bb:paintRect(x, y, w, h, bg)
        else
            local c = Blitbuffer.Color8A(bg:getColor8().a, self.bg_alpha)
            bb:paintRect(x, y, w, h, c, bb.setPixelBlend)
        end
    end

    -- Render black text on black background
    local tmp_bb = Blitbuffer.new(w, h, Blitbuffer.TYPE_BB8)
    tmp_bb:fill(Blitbuffer.COLOR_WHITE)
    self._textbox:paintTo(tmp_bb, 0, 0)
    tmp_bb:invertRect(0, 0, w, h)
    bb:colorblitFromRGB32(tmp_bb, x, y, 0, 0, w, h, get_font_fgcolor() or self.fgcolor)

    tmp_bb:free()
end

function AlphaTextBoxWidget:onCloseWidget()
    self:free()
end

function AlphaTextBoxWidget:free()
    if self._textbox then
        self._textbox:free()
        self._textbox = nil
    end
end

function AlphaTextBoxWidget:onToggleNightMode()
    UIManager:setDirty(self)
end

function AlphaTextBoxWidget:onSetNightMode()
    UIManager:setDirty(self)
end

function AlphaTextBoxWidget:onApplyTheme()
    UIManager:setDirty(self)
end

return AlphaTextBoxWidget

--[[--
Widget that shows a message and cancel/choice1/choice2/choice3 buttons

Example:

    UIManager:show(TripleConfirmBox:new{
        text = _("Apply the theme to:"),
        choice1_text = _("UI"),
        choice1_callback = function()
            -- apply theme to ui
        end,
        choice2_text = _("Book"),
        choice2_callback = function()
            -- apply theme to book
        end,
        choice3_text = _("Both"),
        choice3_callback = function()
            -- apply theme to both
        end,
    })
]]

local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconWidget = require("ui/widget/iconwidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local MovableContainer = require("ui/widget/container/movablecontainer")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")
local Screen = require("device").screen

local TripleConfirmBox = InputContainer:extend {
    modal = true,
    text = _("no text"),
    face = Font:getFace("infofont"),
    icon = "notice-question",
    choice1_text = _("Choice 1"),
    choice1_text_func = nil,
    choice2_text = _("Choice 2"),
    choice2_text_func = nil,
    choice3_text = _("Choice 3"),
    choice3_text_func = nil,
    cancel_text = _("Cancel"),
    choice1_callback = function() end,
    choice2_callback = function() end,
    choice3_callback = function() end,
    cancel_callback = function() end,
    choice1_enabled = true,
    choice2_enabled = true,
    choice3_enabled = true,
    margin = Size.margin.default,
    padding = Size.padding.default,
    dismissable = true, -- set to false if any button callback is required
}

function TripleConfirmBox:init()
    if self.dismissable then
        if Device:isTouchDevice() then
            self.ges_events.TapClose = {
                GestureRange:new {
                    ges = "tap",
                    range = Geom:new {
                        x = 0, y = 0,
                        w = Screen:getWidth(),
                        h = Screen:getHeight(),
                    }
                }
            }
        end
        if Device:hasKeys() then
            self.key_events.Close = { { Device.input.group.Back } }
        end
    end
    local content = HorizontalGroup:new {
        align = "center",
        IconWidget:new {
            icon = self.icon,
            alpha = true,
        },
        HorizontalSpan:new { width = Size.span.horizontal_default },
        TextBoxWidget:new {
            text = self.text,
            face = self.face,
            width = math.floor(math.min(Screen:getWidth(), Screen:getHeight()) * 2 / 3),
        }
    }

    local button_table = ButtonTable:new {
        width = content:getSize().w,
        buttons = {
            {
                {
                    text = self.cancel_text,
                    callback = function()
                        self.cancel_callback()
                        UIManager:close(self)
                    end,
                },
                {
                    text = self.choice1_text,
                    text_func = self.choice1_text_func,
                    enabled = self.choice1_enabled,
                    callback = function()
                        self.choice1_callback()
                        UIManager:close(self)
                    end,
                },
                {
                    text = self.choice2_text,
                    text_func = self.choice2_text_func,
                    enabled = self.choice2_enabled,
                    callback = function()
                        self.choice2_callback()
                        UIManager:close(self)
                    end,
                },
                {
                    text = self.choice3_text,
                    text_func = self.choice3_text_func,
                    enabled = self.choice3_enabled,
                    callback = function()
                        self.choice3_callback()
                        UIManager:close(self)
                    end,
                },
            },
        },
        zero_sep = true,
        show_parent = self,
    }

    self[1] = CenterContainer:new {
        dimen = Screen:getSize(),
        MovableContainer:new {
            FrameContainer:new {
                background = Blitbuffer.COLOR_WHITE,
                radius = Size.radius.window,
                padding = self.padding,
                padding_bottom = 0, -- no padding below buttontable
                VerticalGroup:new {
                    align = "left",
                    content,
                    -- Add same vertical space after than before content
                    VerticalSpan:new { width = self.margin + self.padding },
                    button_table,
                }
            }
        }
    }
end

function TripleConfirmBox:onShow()
    UIManager:setDirty(self, function()
        return "ui", self[1][1].dimen -- i.e., MovableContainer
    end)
end

function TripleConfirmBox:onCloseWidget()
    UIManager:setDirty(nil, function()
        return "ui", self[1][1].dimen
    end)
end

function TripleConfirmBox:onClose()
    UIManager:close(self)
    return true
end

function TripleConfirmBox:onTapClose(arg, ges)
    if ges.pos:notIntersectWith(self[1][1].dimen) then
        self:onClose()
        return true
    end
    return false
end

return TripleConfirmBox

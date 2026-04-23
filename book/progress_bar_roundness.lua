local Event = require("ui/event")
local ReaderFooter = require("apps/reader/modules/readerfooter")
local Screen = require("device").screen
local Setting = require("lib/setting")
local SpinWidget = require("ui/widget/spinwidget")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local T = require("ffi/util").template

-- Settings
local ProgressBarRadius = Setting("book_progress_bar_radius", 2)            -- The radius of the progress bar. (default: 2
local ProgressBarRoundFill = Setting("book_progress_bar_round_fill", false) -- Whether the inner fill bar should be rounded. (default: false)

local function progress_bar_roundness_menu()
    return {
        text = _("Progress bar roundness"),
        keep_menu_open = true,
        sub_item_table = {
            {
                text_func = function() return T(_("Radius: %1"), ProgressBarRadius.get()) end,
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    local spin = SpinWidget:new {
                        title_text = _("Progress bar radius"),
                        value = ProgressBarRadius.get(),
                        default_value = 2,
                        value_min = 0,
                        value_max = 10,
                        value_step = 1,
                        value_hold_step = 3,
                        callback = function(widget)
                            ProgressBarRadius.set(widget.value)
                            UIManager:broadcastEvent(Event:new("ChangeFooterRoundness"))
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                        end,
                    }
                    UIManager:show(spin)
                end
            },
            {
                text = _("Round fill bar"),
                checked_func = ProgressBarRoundFill.get,
                callback = function()
                    ProgressBarRoundFill.toggle()
                    UIManager:broadcastEvent(Event:new("ChangeFooterRoundness"))
                end
            }
        },
    }
end

local original_ReaderFooter_init = ReaderFooter.init
function ReaderFooter:init()
    original_ReaderFooter_init(self)
    self.progress_bar.radius = Screen:scaleBySize(ProgressBarRadius.get())
end

-- Handles ChangeFooterRoundness event
function ReaderFooter:onChangeFooterRoundness()
    self.progress_bar.radius = Screen:scaleBySize(ProgressBarRadius.get())
    self:refreshFooter(true)
end

return progress_bar_roundness_menu

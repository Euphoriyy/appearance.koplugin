local Setting             = require("lib/setting")

-- Settings
local SquareWindowCorners = Setting("ui_misc_square_window_corners", false) -- Whether window corners should be square (default: false)
local SquareOtherCorners  = Setting("ui_misc_square_other_corners", false)  -- Whether other corners should be square (default: false)

-- Menu
local _                   = require("gettext")

local function misc_menu()
    return {
        text = _("Miscellaneous"),
        sub_item_table = {
            {
                text = _("Square window corners"),
                checked_func = SquareWindowCorners.get,
                callback = function()
                    SquareWindowCorners.toggle()
                end,
            },
            {
                text = _("Square other corners"),
                checked_func = SquareOtherCorners.get,
                callback = function()
                    SquareOtherCorners.toggle()
                end,
            }
        },
    }
end

return misc_menu

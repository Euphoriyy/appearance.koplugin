local Setting             = require("lib/setting")
local nf_icons            = require("lib/nf_icons")

-- Settings
local MenuIcons           = Setting("ui_misc_icons", true)
local SquareWindowCorners = Setting("ui_misc_square_window_corners", false) -- Whether window corners should be square (default: false)
local SquareOtherCorners  = Setting("ui_misc_square_other_corners", false)  -- Whether other corners should be square (default: false)

-- Menu
local _ = require("gettext")

local function misc_menu()
    return {
        text_func = function() return nf_icons.label(nf_icons.MAGIC, _("Miscellaneous")) end,
        sub_item_table = {
            {
                text = _("Show Appearance menu icons"),
                checked_func = MenuIcons.get,
                callback = function()
                    MenuIcons.toggle()
                end,
            },
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
            },
        },
    }
end

return misc_menu

local Setting             = require("lib/setting")
local nf_icons            = require("lib/nf_icons")

-- Settings
local MenuIcons           = Setting("ui_misc_icons", true)

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
        },
    }
end

return misc_menu

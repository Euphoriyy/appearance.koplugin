local background_color_menu = require("ui/background_color").menu
local background_image_menu = require("ui/background_image")
local font_color_menu = require("ui/font_color").menu

local function ui_menu()
    return {
        text = "User interface",
        sub_item_table = {
            background_color_menu(),
            background_image_menu(),
            font_color_menu(),
        }
    }
end

return ui_menu

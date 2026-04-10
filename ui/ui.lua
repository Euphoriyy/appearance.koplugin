local background_color_menu = require("ui/background_color").menu
local background_image_menu = require("ui/background_image")
local font_color_menu = require("ui/font_color").menu
local transparency_menu = require("ui/transparency")
local font_face_menu = require("ui/font_face")

local function ui_menu()
    return {
        text = "User interface",
        sub_item_table = {
            background_color_menu(),
            background_image_menu(),
            font_color_menu(),
            font_face_menu(),
            transparency_menu(),
        }
    }
end

return ui_menu

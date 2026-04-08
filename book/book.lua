local background_color_menu = require("book/background_color").menu
local font_color_menu = require("book/font_color").menu
local progress_bar_colors_menu = require("book/progress_bar_colors")

local function book_menu()
    return {
        text = "Book",
        sub_item_table = {
            background_color_menu(),
            font_color_menu(),
            progress_bar_colors_menu(),
        }
    }
end

return book_menu

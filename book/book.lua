local background_color_menu = require("book/background_color").menu
local font_color_menu = require("book/font_color").menu

local function book_menu()
    return {
        text = "Book",
        sub_item_table = {
            background_color_menu(),
            font_color_menu(),
        }
    }
end

return book_menu

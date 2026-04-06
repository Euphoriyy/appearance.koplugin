local background_color_menu = require("book/background_color")
local font_color_menu = require("book/font_color")

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

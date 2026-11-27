local font_face_menu = require("ui/font_face")
local dict_font_face_menu = require("ui/dict_font_face")
local virtual_kb_font_face = require("ui/virtual_kb_font_face")
local nf_icons = require("lib/nf_icons")
local text_editor_font_face_menu = require("ui/text_editor_font_face")
local _ = require("gettext")

local function fonts_menu()
    return {
        text_func = function() return nf_icons.label(nf_icons.FONT, _("Fonts")) end,
        sub_item_table = {
            font_face_menu(),
            dict_font_face_menu(),
            virtual_kb_font_face(),
            text_editor_font_face_menu(),
        }
    }
end

return fonts_menu

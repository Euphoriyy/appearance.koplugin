-- Nerd font symbol icons that are included by default in KOReader
-- Source for glyph codepoints:
-- https://github.com/AndyHazz/bookshelf.koplugin/blob/master/lib/bookshelf_nerdfont_names.lua

-- Misc setting for showing icons
local MenuIcons  = Setting("ui_misc_icons", true)

local icons = {
    BOOK = "\u{E7B9}",
    BOOK_OPEN = "\u{E28B}",
    BORDER_COLOR = "\u{E7C8}",
    CURSOR_DEFAULT = "\u{E8B3}",
    EYEDROPPER = "\u{E909}",
    FONT = "\u{F031}",
    FORMAT_COLOR = "\u{E965}",
    FORMAT_LINE_WEIGHT = "\u{ECC8}",
    GREASE_PENCIL = "\u{ED47}",
    INFO = "\u{F449}",
    LINK = "\u{EA36}",
    LINK_EXTERNAL = "\u{F465}",
    LINK_VARIANT_1 = "\u{EA38}",
    MAGIC = "\u{F0D0}",
    MENU = "\u{EA5B}",
    OPACITY = "\u{ECCB}",
    PALETTE = "\u{EAD7}",
    PICTURE = "\u{F03E}",
    PLUS = "\u{F44D}",
    REFRESH = "\u{EB4F}",
    ROUNDED_CORNER = "\u{ED06}",
    UPDATE = "\u{EDAE}",
}

function icons.label(glyph, text)
    if MenuIcons.get() == false then return text end
    if type(glyph) ~= "string" or glyph == "" then return text end
    return glyph .. "  " .. text
end

return icons
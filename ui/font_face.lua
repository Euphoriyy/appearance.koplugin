-- Based on patch:
-- https://github.com/sebdelsol/KOReader.patches/blob/main/2--ui-font.lua by @sebdelsol

local Font = require("ui/font")
local FontList = require("fontlist")
local Setting = require("lib/setting")
local UIManager = require("ui/uimanager")
local cre = require("document/credocument"):engineInit()

local UIFontName = Setting("ui_font_name", "Noto Sans")
local UIFontEnabled = Setting("ui_font_enabled", true)

local font_list
local fonts
local to_be_replaced
local font_type = { regular = "NotoSans-Regular.ttf", bold = "NotoSans-Bold.ttf" }

local function get_bold_path(path_regular)
    local path_bold, n_repl = path_regular:gsub("%-Regular%.", "-Bold.", 1)
    return n_repl > 0 and path_bold
end

local function set_font(name)
    if not UIFontEnabled.get() then return end
    local current_name = UIFontName.get()
    if name ~= current_name then
        name = name or current_name
        if not fonts[name] then return end
        for font, typ in pairs(to_be_replaced) do
            Font.fontmap[font] = fonts[name][typ]
        end
        UIFontName.set(name)
        return true
    end
end

local function init(font_name)
    font_list = {}
    fonts = {}
    to_be_replaced = {}

    local path_exists = {}
    for _, font in ipairs(FontList.fontlist) do
        path_exists[font] = true
    end

    -- Get fonts from CRE font list
    for _, name in ipairs(cre.getFontFaces()) do
        local path_regular = cre.getFontFaceFilenameAndFaceIndex(name)
        local path_bold = get_bold_path(path_regular)

        local regular_exists = path_exists[path_regular]
        local bold_exists = path_exists[path_bold]

        -- Add both regular and bold versions if they exist, otherwise default to whatever is left
        if regular_exists and bold_exists then
            table.insert(font_list, name)
            fonts[name] = { regular = path_regular, bold = path_bold }
        elseif regular_exists then
            table.insert(font_list, name)
            fonts[name] = { regular = path_regular, bold = path_regular }
        elseif bold_exists then
            table.insert(font_list, name)
            fonts[name] = { regular = path_bold, bold = path_bold }
        end
    end

    local type_font = {}
    for typ, font in pairs(font_type) do
        type_font[font] = typ
    end
    for name, font in pairs(Font.fontmap) do
        to_be_replaced[name] = type_font[font]
    end

    return set_font(font_name)
end

init()

-- Menu
local _ = require("gettext")
local T = require("ffi/util").template

local function font_face_menu()
    return {
        text_func = function()
            return T(_("Font: %1"), UIFontEnabled.get() and UIFontName.get() or "default")
        end,
        sub_item_table_func = function()
            local items = {}
            table.insert(items, {
                text = "Enable font replacement",
                checked_func = UIFontEnabled.get,
                callback = function()
                    UIFontEnabled.toggle()
                    init()
                    UIManager:askForRestart(_("Restart to fully apply the UI font change."))
                end,
                separator = true,
            })
            for i, name in ipairs(font_list) do
                table.insert(items, {
                    text = name,
                    enabled_func = function() return name ~= UIFontName.get() end,
                    font_func = function(size) return Font:getFace(fonts[name].regular, size) end,
                    callback = function()
                        if init(name) then
                            UIManager:askForRestart(_("Restart to fully apply the UI font change."))
                        end
                    end,
                })
            end
            return items
        end
    }
end

return font_face_menu

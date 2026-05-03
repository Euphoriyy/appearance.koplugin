-- Based on patch:
-- https://github.com/sebdelsol/KOReader.patches/blob/main/2--ui-font.lua by @sebdelsol

local Device = require("device")
local Font = require("ui/font")
local FontList = require("fontlist")
local Setting = require("lib/setting")
local UIManager = require("ui/uimanager")
local cre = require("document/credocument"):engineInit()

local UIFontName = Setting("ui_font_name", "Noto Sans", true)
local UIFontEnabled = Setting("ui_font_enabled", true, true)
local SystemFonts = Setting("system_fonts", false, true)

local font_list
local fonts
local to_be_replaced
local font_type = { regular = "NotoSans-Regular.ttf", bold = "NotoSans-Bold.ttf" }

local function get_bold_path(path_regular)
    if not path_regular then return nil end
    -- Try "Font-Regular.ext" -> "Font-Bold.ext"
    local path_bold, n_repl = path_regular:gsub("%-Regular%.", "-Bold.", 1)
    if n_repl > 0 then return path_bold end
    -- Try "Font.ext" -> "Font-Bold.ext"
    path_bold, n_repl = path_regular:gsub("(%.)([^.]+)$", "-Bold.%2", 1)
    return n_repl > 0 and path_bold
end

local function apply_font(name)
    name = name or UIFontName.get()
    if not UIFontEnabled.get() or not fonts[name] then return end
    for font, typ in pairs(to_be_replaced) do
        Font.fontmap[font] = fonts[name][typ]
    end
end

local function set_font(name)
    if not fonts[name] then return end
    local changed = name ~= UIFontName.get()
    UIFontName.set(name)
    apply_font(name)
    return changed
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
        if path_regular then
            local path_bold = get_bold_path(path_regular)

            local regular_exists = path_exists[path_regular]
            local bold_exists = path_exists[path_bold]

            table.insert(font_list, name)
            -- Add both regular and bold versions if they exist, otherwise default to whatever is left
            if regular_exists and bold_exists then
                fonts[name] = { regular = path_regular, bold = path_bold }
            elseif regular_exists then
                fonts[name] = { regular = path_regular, bold = path_regular }
            elseif bold_exists then
                fonts[name] = { regular = path_bold, bold = path_bold }
            end
        end
    end

    local type_font = {}
    for typ, font in pairs(font_type) do
        type_font[font] = typ
    end
    for name, font in pairs(Font.fontmap) do
        to_be_replaced[name] = type_font[font]
    end

    apply_font(font_name)
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
            local items = {
                {
                    text = "Enable font replacement",
                    checked_func = UIFontEnabled.get,
                    callback = function()
                        UIFontEnabled.toggle()
                        apply_font()
                        UIManager:askForRestart(_("Restart to fully apply the UI font change."))
                    end,
                    separator = true,
                },
            }
            -- Add option for toggling system fonts on supported platforms
            if Device:isAndroid() or Device:isDesktop() or Device:isEmulator() or Device:isPocketBook() then
                items[1].separator = nil
                table.insert(items, {
                    text = "Enable system fonts",
                    checked_func = SystemFonts.get,
                    callback = function()
                        SystemFonts.toggle()
                        UIManager:askForRestart()
                    end,
                    separator = true,
                })
            end
            for i, name in ipairs(font_list) do
                table.insert(items, {
                    text = T(name .. " %1", fonts[name].regular == fonts[name].bold and "(no bold)" or ""),
                    enabled_func = function() return name ~= UIFontName.get() end,
                    font_func = function(size) return Font:getFace(fonts[name].regular, size) end,
                    callback = function()
                        if set_font(name) then
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

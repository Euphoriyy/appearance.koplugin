local Device = require("device")
local Font = require("ui/font")
local FontList = require("fontlist")
local Setting = require("lib/setting")
local UIManager = require("ui/uimanager")
local VirtualKeyboard = require("ui/widget/virtualkeyboard")
local cre = require("document/credocument"):engineInit()
local nf_icons = require("lib/nf_icons")

local VirtualKBFontName = Setting("virtual_kb_font_name", "Noto Sans", false)
local VirtualKBFontEnabled = Setting("virtual_kb_font_enabled", false, false)
local SystemFonts = Setting("system_fonts", false, true)

local font_list
local fonts
local initializing_kb

local function get_bold_path(path_regular)
    if not path_regular then return nil end
    -- Try "Font-Regular.ext" -> "Font-Bold.ext"
    local path_bold, n_repl = path_regular:gsub("%-Regular%.", "-Bold.", 1)
    if n_repl > 0 then return path_bold end
    -- Try "Font.ext" -> "Font-Bold.ext"
    path_bold, n_repl = path_regular:gsub("(%.)([^.]+)$", "-Bold.%2", 1)
    return n_repl > 0 and path_bold
end

local original_VirtualKeyboard_init = VirtualKeyboard.init

function VirtualKeyboard:init()
    initializing_kb = true

    original_VirtualKeyboard_init(self)

    initializing_kb = false
end

local original_getFace = Font.getFace
function Font:getFace(font, size, ...)
    if VirtualKBFontEnabled.get() and initializing_kb and font == "infont" then
        local selected_font = fonts[VirtualKBFontName.get()]
        if selected_font then
            font = selected_font.regular
        end
    end

    return original_getFace(self, font, size, ...)
end

local function set_font(name)
    if not fonts[name] then return end
    local changed = name ~= VirtualKBFontName.get()
    VirtualKBFontName.set(name)
    return changed
end

local function init()
    font_list = {}
    fonts = {}

    local path_exists = {}
    for _, font in ipairs(FontList.fontlist) do
        path_exists[font] = true
    end

    -- Get fonts from CRE font list
    for _, name in ipairs(cre.getFontFaces()) do
        local path_regular = cre.getFontFaceFilenameAndFaceIndex(name)
        if path_regular and path_exists[path_regular] then
            local path_bold = get_bold_path(path_regular)
            local bold_exists = path_exists[path_bold]

            table.insert(font_list, name)
            -- Add both regular and bold versions if they exist, otherwise default to regular
            if bold_exists then
                fonts[name] = { regular = path_regular, bold = path_bold }
            else
                fonts[name] = { regular = path_regular, bold = path_regular }
            end
        end
    end
end

init()

-- Menu
local _ = require("gettext")
local T = require("ffi/util").template

local function virtual_kb_font_face_menu()
    return {
        text_func = function()
            return T(nf_icons.label(nf_icons.KEYBOARD, _("Virtual keyboard font: %1")),
                VirtualKBFontEnabled.get() and VirtualKBFontName.get() or "default")
        end,
        sub_item_table_func = function()
            local items = {
                {
                    text = "Enable virtual keyboard font replacement",
                    checked_func = VirtualKBFontEnabled.get,
                    callback = function()
                        VirtualKBFontEnabled.toggle()
                    end,
                },
            }
            -- Add option for toggling system fonts on supported platforms
            if Device:isAndroid() or Device:isDesktop() or Device:isEmulator() or Device:isPocketBook() then
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
                    font_func = function(size)
                        return Font:getFace(fonts[name].regular, size)
                    end,
                    checked_func = function()
                        return name == VirtualKBFontName.get()
                    end,
                    radio = true,
                    callback = function()
                        set_font(name)
                    end,
                })
            end
            return items
        end
    }
end

return virtual_kb_font_face_menu

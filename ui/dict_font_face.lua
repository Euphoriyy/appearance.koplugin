-- Based on patch:
-- https://github.com/gennaro-tedesco/KOReader.patches/blob/master/patches/2-custom-ui-fonts.lua
-- by @gennaro-tedesco

local Device = require("device")
local DictQuickLookup = require("ui/widget/dictquicklookup")
local Font = require("ui/font")
local FontList = require("fontlist")
local Setting = require("lib/setting")
local UIManager = require("ui/uimanager")
local cre = require("document/credocument"):engineInit()

local DictFontName = Setting("dict_font_name", "Noto Sans", true)
local DictFontEnabled = Setting("dict_font_enabled", true, true)
local SystemFonts = Setting("system_fonts", false, true)

local font_list
local fonts

local function get_bold_path(path_regular)
    if not path_regular then return nil end
    -- Try "Font-Regular.ext" -> "Font-Bold.ext"
    local path_bold, n_repl = path_regular:gsub("%-Regular%.", "-Bold.", 1)
    if n_repl > 0 then return path_bold end
    -- Try "Font.ext" -> "Font-Bold.ext"
    path_bold, n_repl = path_regular:gsub("(%.)([^.]+)$", "-Bold.%2", 1)
    return n_repl > 0 and path_bold
end

local function set_font(name)
    if not fonts[name] then return end
    local changed = name ~= DictFontName.get()
    DictFontName.set(name)
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
end

init()

-- Menu
local _ = require("gettext")
local T = require("ffi/util").template

local function dict_font_face_menu()
    return {
        text_func = function()
            return T(_("Dictionary font: %1"), DictFontEnabled.get() and DictFontName.get() or "default")
        end,
        sub_item_table_func = function()
            local items = {
                {
                    text = "Enable font replacement",
                    checked_func = DictFontEnabled.get,
                    callback = function()
                        DictFontEnabled.toggle()
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
                    enabled_func = function() return name ~= DictFontName.get() end,
                    font_func = function(size) return Font:getFace(fonts[name].regular, size) end,
                    callback = function()
                        set_font(name)
                    end,
                })
            end
            return items
        end
    }
end

-- Change font of dictionary title
local original_DictQuickLookup_instantiateScrollWidget = DictQuickLookup._instantiateScrollWidget

function DictQuickLookup:_instantiateScrollWidget()
    original_DictQuickLookup_instantiateScrollWidget(self)

    local selected_font = DictFontEnabled.get() and DictFontName.get()
    if not selected_font then
        return
    end

    local font_filename = cre.getFontFaceFilenameAndFaceIndex(selected_font)
    if not font_filename then
        return
    end

    if self.dict_title then
        local font_size = Font.sizemap.x_smallinfofont
        self.dict_title.title_face = Font:getFace(font_filename, font_size)
        self.dict_title:clear()
        self.dict_title:init()
        UIManager:setDirty(self.dict_title.show_parent, "ui", self.dict_title.dimen)
    end

    if self.lookup_word_text and self.lookup_word_text.face then
        self.lookup_word_text.face = Font:getFace(font_filename, self.lookup_word_text.face.orig_size)
        self.lookup_word_text._face_adjusted = false
        self.lookup_word_text:free()
    end
end

-- Change font of dictionary body
local original_DictQuickLookup_getHtmlDictionaryCss = DictQuickLookup.getHtmlDictionaryCss

function DictQuickLookup:getHtmlDictionaryCss()
    local original_css = original_DictQuickLookup_getHtmlDictionaryCss(self) or ""

    local selected_font = DictFontEnabled.get() and DictFontName.get()
    if selected_font then
        local font_filename, font_faceindex = cre.getFontFaceFilenameAndFaceIndex(selected_font)
        if font_filename then
            local face_css = "@font-face { font-family: 'DictCustomFont'; src: url('" .. font_filename .. "') }\n"
            local seen = { [font_filename] = true }
            local variants = {
                { bold = false, italic = true,  style = "; font-style: italic" },
                { bold = true,  italic = false, style = "; font-weight: bold" },
                { bold = true,  italic = true,  style = "; font-weight: bold; font-style: italic" },
            }
            for _, v in ipairs(variants) do
                local path = cre.getFontFaceFilenameAndFaceIndex(selected_font, v.bold, v.italic)
                if path and not seen[path] then
                    seen[path] = true
                    face_css = face_css
                        .. "@font-face { font-family: 'DictCustomFont'; src: url('"
                        .. path
                        .. "')"
                        .. v.style
                        .. " }\n"
                end
            end
            local custom_css = face_css .. [[
                @page { font-family: 'DictCustomFont' !important; }
                body { font-family: 'DictCustomFont' !important; }
            ]]

            return original_css .. custom_css
        end
    end

    return original_css
end

return dict_font_face_menu

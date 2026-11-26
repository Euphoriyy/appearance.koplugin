-- Run with: luajit tests/duplicate_themes.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local function theme(label, night)
    return { key = "duplicate", label = label, bg = "#FFFFFF", fg = "#000000", night = night }
end

local day = { theme("Day first", false), theme("Day second", false) }
local night = { theme("Night first", true), theme("Night second", true) }
local values = { ui_themes_day = day, ui_themes_night = night }
local settings = { flushSettings = function() end }
local manager = {
    show = function(self, widget) self.last = widget end,
    close = function() end,
    setDirty = function() end,
}
local widget = {
    new = function(_, value)
        value.getScrolledOffset = function() return 0 end
        value.setScrolledOffset = function() end
        value.getInputText = function() return "Renamed" end
        value.onShowKeyboard = function() end
        return value
    end,
}
local stubs = {
    ["ffi/blitbuffer"] = { colorFromString = function() return {} end },
    ["ui/widget/buttondialog"] = widget,
    ["widgets/colorwheelwidget"] = widget,
    ["ui/widget/confirmbox"] = widget,
    ["ui/widget/infomessage"] = widget,
    ["ui/widget/inputdialog"] = widget,
    ["ui/widget/multiconfirmbox"] = widget,
    ["widgets/tripleconfirmbox"] = widget,
    ["dispatcher"] = { registerAction = function() end },
    ["ui/event"] = {},
    ["apps/filemanager/filemanager"] = {},
    ["apps/reader/readerui"] = {},
    ["device"] = { screen = { night_mode = false } },
    ["lib/settings"] = settings,
    ["ui/uimanager"] = manager,
    ["lib/common"] = { EXCLUSION_COLOR = 0 },
    ["lib/nf_icons"] = { label = function(_, text) return text end },
    ["lib/theme_list"] = {
        DEFAULT_DAY_THEME = day[1], DEFAULT_NIGHT_THEME = night[1],
        DEFAULT_DAY_THEMES = day, DEFAULT_NIGHT_THEMES = night,
    },
    ["gettext"] = function(text) return text end,
    ["ffi/util"] = { template = function(text) return text end },
    ["lib/setting"] = function(name, default)
        if values[name] == nil then values[name] = default end
        return {
            default = default,
            get = function() return values[name] end,
            set = function(value) values[name] = value end,
        }
    end,
}
for name, value in pairs(stubs) do package.loaded[name] = value end

local themes_menu = require("themes")
local function open_theme(index)
    local items = themes_menu().sub_item_table_func()
    for _, item in ipairs(items) do
        if item.text_func and item.text_func() == "Choose a theme" then
            item.callback({})
            manager.last.buttons[index][1].hold_callback()
            return
        end
    end
    error("Choose a theme menu not found")
end

local function edit_button(label)
    for _, row in ipairs(manager.last.buttons) do
        if row[1].text:find(label, 1, true) then return row[1] end
    end
    error(label .. " button not found")
end

for _, case in ipairs({ { day, 2 }, { night, 3 } }) do
    local list, index = case[1], case[2]
    local first, second = list[1], list[2]

    open_theme(index)
    edit_button("Rename").callback()
    manager.last.buttons[1][2].callback()
    assert(list[1] == first and list[2] == second and second.label == "Renamed",
        "renaming a duplicate must preserve the first theme")

    open_theme(index)
    edit_button("Delete").callback()
    assert(#list == 1 and list[1] == first,
        "deleting a duplicate must remove the selected theme")
end

print("Duplicate theme edit and deletion tests passed")

local Settings = require("lib/settings")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local common = require("lib/common")
local book_menu = require("book/book")
local themes_menu = require("themes")
local ui_menu = require("ui/ui")

local Appearance = WidgetContainer:extend({
    name = "appearance",
    title = _("Appearance"),
    is_doc_only = false,
})

function Appearance:init()
    self.ui.menu:registerToMainMenu(self)
end

function Appearance:onFlushSettings()
    Settings:flushSettings()
end

local submenus = {
    themes_menu(),
    ui_menu(),
    book_menu(),
}

function Appearance:addToMainMenu(menu_items)
    local filemanager_menu_order = require("ui/elements/filemanager_menu_order")
    if not common.contains(filemanager_menu_order.setting, "appearance") then
        table.insert(filemanager_menu_order.setting, 6, "appearance")
    end

    local reader_menu_order = require("ui/elements/reader_menu_order")
    if not common.contains(reader_menu_order.setting, "appearance") then
        table.insert(reader_menu_order.setting, 6, "appearance")
    end

    menu_items.appearance = {
        sorting_hint = "setting",
        text = self.title,
        sub_item_table = {},
    }

    -- Insert submenus
    for _, submenu in pairs(submenus) do
        for _, value in ipairs({ submenu }) do
            table.insert(menu_items.appearance.sub_item_table, value)
        end
    end
end

return Appearance

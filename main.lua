local FileManagerMenu = require("apps/filemanager/filemanagermenu")
local ReaderMenu = require("apps/reader/modules/readermenu")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local common = require("lib/common")
local book_menu = require("book/book")
local themes_menu = require("themes")
local ui_menu = require("ui/ui")

local Appearance = WidgetContainer:extend({
    name = "Appearance",
    is_doc_only = true,
})

local submenus = {
    themes_menu(),
    ui_menu(),
    book_menu(),
}

local function patch_menu(menu, order, menu_entries)
    -- Ensure the appearance entry exists in order.setting
    if not common.contains(order.setting, "appearance") then
        table.insert(order.setting, 6, "appearance")
    end

    -- Ensure the appearance menu exists
    if not menu.menu_items.appearance then
        menu.menu_items.appearance = {
            text = _("Appearance"),
            sub_item_table = {},
        }
    end

    -- Insert sub items
    for _, value in ipairs(menu_entries) do
        table.insert(menu.menu_items.appearance.sub_item_table, value)
    end
end

local original_FileManagerMenu_setUpdateItemTable = FileManagerMenu.setUpdateItemTable
function FileManagerMenu:setUpdateItemTable()
    local order = require("ui/elements/filemanager_menu_order")
    for _, submenu in pairs(submenus) do
        patch_menu(self, order, { submenu })
    end
    original_FileManagerMenu_setUpdateItemTable(self)
end

local original_ReaderMenu_setUpdateItemTable = ReaderMenu.setUpdateItemTable
function ReaderMenu:setUpdateItemTable()
    local order = require("ui/elements/reader_menu_order")
    for _, submenu in pairs(submenus) do
        patch_menu(self, order, { submenu })
    end
    original_ReaderMenu_setUpdateItemTable(self)
end

return Appearance

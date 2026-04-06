local FileManagerMenu = require("apps/filemanager/filemanagermenu")
local ReaderMenu = require("apps/reader/modules/readermenu")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local common = require("lib/common")

local Appearance = WidgetContainer:extend({
    name = "Appearance",
    is_doc_only = true,
})

local submenus = {
    background_color = require("background_color")(),
    background_image = require("background_image")(),
    font_color = require("font_color")(),
    themes = require("themes")(),
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
    for _, value in pairs(menu_entries) do
        table.insert(menu.menu_items.appearance.sub_item_table, value)
    end

    -- Sort sub items
    table.sort(menu.menu_items.appearance.sub_item_table, function(a, b)
        local a_text = type(a.text_func) == "function" and a.text_func() or a.text or ""
        local b_text = type(b.text_func) == "function" and b.text_func() or b.text or ""
        return a_text < b_text
    end)
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

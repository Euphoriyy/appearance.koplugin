local Notification = require("ui/widget/notification")
local Setting = require("lib/setting")
local Settings = require("lib/settings")
local Updater = require("lib/updater")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local common = require("lib/common")
local about_menu = require("about")
local book_menu = require("book/book")
local themes_menu = require("themes")
local ui_menu = require("ui/ui")

local Appearance = WidgetContainer:extend({
    name = "appearance",
    title = _("Appearance"),
    is_doc_only = false,
    AutomaticUpdateChecks = Setting("automatic_update_checks", false)
})

function Appearance:init()
    self.ui.menu:registerToMainMenu(self)
    self:checkForUpdatesInBackground()
end

function Appearance:onResume()
    self:checkForUpdatesInBackground()
end

function Appearance:onFlushSettings()
    Settings:flushSettings()
end

function Appearance:deletePluginSettings()
    Settings.settings:purge()
end

function Appearance:checkForUpdatesInBackground()
    if not self.AutomaticUpdateChecks.get() then return end
    Updater.checkBackground(function(ver)
        Notification:notify(_("Appearance update available: v") .. ver,
            Notification.SOURCE_ALWAYS_SHOW)
    end)
end

local submenus = {
    themes_menu(),
    ui_menu(),
    book_menu(),
    about_menu(),
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

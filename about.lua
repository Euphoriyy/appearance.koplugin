local Device = require("device")
local Setting = require("lib/setting")
local Updater = require("lib/updater")
local _ = require("gettext")
local T = require("ffi/util").template

local AutomaticUpdateChecks = Setting("automatic_update_checks", false)

local function about_menu()
    return {
        text = _("About"),
        sub_item_table = {
            {
                text = _("Made with §pink ❤§r by Euphoriyy"),
                callback = function()
                    Device:openLink("https://github.com/Euphoriyy/appearance.koplugin")
                end
            },
            {
                text_func = function()
                    local available_update = Updater.getAvailableUpdate()
                    return T(_("Version: %1%2"), Updater.getInstalledVersion(),
                        available_update and string.format(" (v%s is available)", available_update) or "")
                end,
                keep_menu_open = true,
                callback = function() end,
                separator = true,
            },
            {
                text = _("Check for updates"),
                callback = function()
                    Updater.check()
                end,
            },
            {
                text = _("Automatically check for updates"),
                checked_func = AutomaticUpdateChecks.get,
                callback = function()
                    AutomaticUpdateChecks.toggle()
                end,
            },
        }
    }
end

return about_menu

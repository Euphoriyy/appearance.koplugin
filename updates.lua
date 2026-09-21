local Setting = require("lib/setting")
local Updater = require("lib/updater")
local common = require("lib/common")
local nf_icons = require("lib/nf_icons")
local _ = require("gettext")
local T = require("ffi/util").template

local AutomaticUpdateChecks = Setting("automatic_update_checks", false)

local function updates_menu()
    return {
        text_func = function() return nf_icons.label(nf_icons.UPDATE, _("Updates")) end,
        sub_item_table = {
            {
                text_func = function()
                    local available_update = Updater.getAvailableUpdate()
                    return T(_("Version: %1%2 %3"), Updater.getInstalledVersion(),
                        available_update and T(" (v%1 is available)", available_update) or "", nf_icons.LINK_EXTERNAL)
                end,
                keep_menu_open = true,
                callback = function()
                    common.handleLink(T("https://github.com/Euphoriyy/appearance.koplugin/releases/tag/v%1",
                        Updater.getInstalledVersion()))
                end,
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

return updates_menu

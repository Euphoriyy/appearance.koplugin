local Device            = require("device")
local Event             = require("ui/event")
local Setting           = require("lib/setting")
local ThemeWatcher      = require("lib/themewatcher")
local UIManager         = require("ui/uimanager")
local common            = require("lib/common")
local nf_icons          = require("lib/nf_icons")

-- Settings
local MenuIcons         = Setting("ui_misc_icons", true)
local DetectSystemTheme = Setting("ui_misc_detect_sys_theme", false)

-- Menu
local _                 = require("gettext")

local function start_themewatcher()
    ThemeWatcher:start(function(is_dark)
        UIManager:broadcastEvent(Event:new("SetNightMode", is_dark))
    end)
end

local function misc_menu()
    return {
        text_func = function() return nf_icons.label(nf_icons.MAGIC, _("Miscellaneous")) end,
        sub_item_table = {
            {
                text = _("Show Appearance menu icons"),
                checked_func = MenuIcons.get,
                callback = function()
                    MenuIcons.toggle()
                end,
            },
            {
                text = _("Detect system theme"),
                enabled_func = function() return Device.isDesktop() and jit.os == "Linux" end,
                checked_func = DetectSystemTheme.get,
                callback = function()
                    DetectSystemTheme.toggle()
                    if DetectSystemTheme.get() then
                        start_themewatcher()
                    else
                        ThemeWatcher:stop()
                    end
                end,
            },
        },
    }
end

-- Start checking for the system theme if on Desktop (Linux)
if Device:isDesktop() and jit.os == "Linux" then
    if DetectSystemTheme.get() then
        -- Startup check
        UIManager:nextTick(function()
            local is_dark = common.isSystemDark()
            if is_dark ~= nil then
                UIManager:broadcastEvent(Event:new("SetNightMode", is_dark))
            end
        end)

        start_themewatcher()
    end

    local original_UIManager_quit = UIManager.quit
    function UIManager:quit()
        ThemeWatcher:stop()
        original_UIManager_quit(self)
    end
end

return misc_menu

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

local function apply_night_mode(is_dark)
    if is_dark == nil then return end
    UIManager:broadcastEvent(Event:new("SetNightMode", is_dark))
end

local function start_themewatcher()
    ThemeWatcher:start(function(is_dark)
        apply_night_mode(is_dark)
    end)
end

local function misc_menu()
    local menu = {
        text_func = function() return nf_icons.label(nf_icons.MAGIC, _("Miscellaneous")) end,
        sub_item_table = {
            {
                text = _("Show Appearance menu icons"),
                checked_func = MenuIcons.get,
                callback = function()
                    MenuIcons.toggle()
                end,
            },
        },
    }

    if Device.isDesktop() and jit.os == "Linux" then
        table.insert(menu.sub_item_table, {
            text = _("Detect system theme"),
            checked_func = DetectSystemTheme.get,
            callback = function()
                DetectSystemTheme.toggle()
                if DetectSystemTheme.get() then
                    start_themewatcher()
                else
                    ThemeWatcher:stop()
                end
            end,
        })
    end

    return menu
end

-- Start checking for the system theme if on Desktop (Linux)
if Device:isDesktop() and jit.os == "Linux" then
    if DetectSystemTheme.get() then
        -- Startup check
        UIManager:nextTick(function()
            local is_dark = common.isSystemDark()
            apply_night_mode(is_dark)
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

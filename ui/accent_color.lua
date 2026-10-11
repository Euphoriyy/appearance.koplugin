local Blitbuffer = require("ffi/blitbuffer")
local ColorWheelWidget = require("widgets/colorwheelwidget")
local FileManager = require("apps/filemanager/filemanager")
local ReaderUI = require("apps/reader/readerui")
local Screen = require("device").screen
local Setting = require("lib/setting")
local UIManager = require("ui/uimanager")
local common = require("lib/common")
local nf_icons = require("lib/nf_icons")

-- Settings
local HexAccentColor = Setting("ui_accent_color_hex", nil)            -- RGB hex for UI accent color (default: #000000)
local InvertAccentColor = Setting("ui_accent_color_inverted", true)         -- Whether the UI accent color should be inverted in night mode (default: true)
local AltNightAccentColor = Setting("ui_accent_color_alt_night", false)     -- Whether the UI accent color should be changed to an alternative color in night mode (default: false)
local NightHexAccentColor = Setting("ui_accent_color_night_hex", nil) -- RGB hex for the alternative UI accent color in night mode (default: #FFFFFF)

-- Cache
local cached = {
    alt_night_color = AltNightAccentColor.get(),
    invert_in_night_mode = InvertAccentColor.get(),
    hex = HexAccentColor.get(),
    night_hex = NightHexAccentColor.get(),
    last_hex = nil,
    accent_color = nil,
}

-- Calculate the current hex value based on night mode and current settings
local function calculateHex()
    local hex = cached.hex
    if Screen.night_mode and cached.alt_night_color then
        hex = cached.night_hex
    end
    if not hex then return nil end
    if Screen.night_mode then
        if cached.alt_night_color or not cached.invert_in_night_mode then
            hex = common.invertColor(hex)
        end
    end
    return hex
end

-- Recompute and cache the final accent_color based on current settings
-- Applies night mode inversion if enabled, and updates cached.accent_color only if it has changed
local function recomputeAccentColor()
    local hex = calculateHex()
    if not hex then
        cached.accent_color = nil
        cached.last_hex = nil
        return
    end
    if hex ~= cached.last_hex then
        cached.accent_color = Blitbuffer.colorFromString(hex)
        cached.last_hex = hex
    end
end

-- Compute and cache the initial accent_color based on current settings
recomputeAccentColor()

local function getAccentColor()
    if Screen.night_mode and cached.alt_night_color then
        return NightHexAccentColor.get()
    else
        return HexAccentColor.get()
    end
end

local function setAccentColor(hex)
    if Screen.night_mode and cached.alt_night_color then
        NightHexAccentColor.set(hex)
        cached.night_hex = hex
    else
        HexAccentColor.set(hex)
        cached.hex = hex
    end

    recomputeAccentColor()
end

-- Menus
local _ = require("gettext")
local T = require("ffi/util").template

local function pick_color_callback()
    return function(touchmenu_instance)
        local h, s, v = common.hexToHSV(getAccentColor() or "#AAAAAA")
        local wheel
        local should_invert_wheel = AltNightAccentColor.get() or not InvertAccentColor.get()
        wheel = ColorWheelWidget:new({
            title_text = "Pick accent color",
            hue = h,
            saturation = s,
            value = v,
            invert_in_night_mode = should_invert_wheel,
            callback = function(hex)
                setAccentColor(hex)

                if touchmenu_instance then
                    touchmenu_instance:updateItems()
                end
                UIManager:setDirty(nil, "ui")
            end,
            cancel_callback = function()
                UIManager:setDirty(nil, "ui")
            end,
        })
        UIManager:show(wheel)
    end
end

local function accent_color_menu()
    return {
        text_func = function()
            return T(nf_icons.label(nf_icons.CREATION, _("Accent color: %1")), getAccentColor() or "default")
        end,
        sub_item_table = {
            {
                text_func = function()
                    return T(_("Accent color: %1"), getAccentColor() or "default")
                end,
                keep_menu_open = true,
                callback = pick_color_callback(),
            },
            {
                text = _("Reset color"),
                enabled_func = function() return getAccentColor() ~= nil end,
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    setAccentColor(nil)
                    if touchmenu_instance then
                        touchmenu_instance:updateItems()
                    end
                end,
                separator = true,
            },
            {
                text = _("Alternative night mode color"),
                checked_func = AltNightAccentColor.get,
                callback = function()
                    AltNightAccentColor.toggle()
                    cached.alt_night_color = AltNightAccentColor.get()

                    if Screen.night_mode then
                        recomputeAccentColor()
                    end
                end,
            },
            {
                text = _("Invert color in night mode"),
                enabled_func = function() return not AltNightAccentColor.get() end,
                checked_func = InvertAccentColor.get,
                callback = function()
                    InvertAccentColor.toggle()
                    cached.invert_in_night_mode = InvertAccentColor.get()
                    recomputeAccentColor()
                end,
                separator = true,
            },
        },
    }
end

-- Recompute colors upon event call
local original_FileManager_onRecomputeAllColors = FileManager.onRecomputeAllColors
function FileManager:onRecomputeAllColors()
    if original_FileManager_onRecomputeAllColors then
        original_FileManager_onRecomputeAllColors(self)
    end

    recomputeAccentColor()
end

local original_ReaderUI_onRecomputeAllColors = ReaderUI.onRecomputeAllColors
function ReaderUI:onRecomputeAllColors()
    if original_ReaderUI_onRecomputeAllColors then
        original_ReaderUI_onRecomputeAllColors(self)
    end

    recomputeAccentColor()
end

-- Event handlers for when a theme is applied
local original_FileManager_onApplyTheme = FileManager.onApplyTheme
function FileManager:onApplyTheme()
    if original_FileManager_onApplyTheme then
        original_FileManager_onApplyTheme(self)
    end

    cached.hex = HexAccentColor.get()
    cached.night_hex = NightHexAccentColor.get()
    cached.alt_night_color = AltNightAccentColor.get()
end

local original_ReaderUI_onApplyTheme = ReaderUI.onApplyTheme
function ReaderUI:onApplyTheme()
    if original_ReaderUI_onApplyTheme then
        original_ReaderUI_onApplyTheme(self)
    end

    cached.hex = HexAccentColor.get()
    cached.night_hex = NightHexAccentColor.get()
    cached.alt_night_color = AltNightAccentColor.get()
end

return {
    menu = accent_color_menu,
    accent_color = function() return cached.accent_color end,
    accent_hex = function() return calculateHex() end,
}

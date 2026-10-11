local Screen                = require("device").screen
local Setting               = require("lib/setting")
local Size                  = require("ui/size")
local SpinWidget            = require("ui/widget/spinwidget")
local UIManager             = require("ui/uimanager")
local nf_icons              = require("lib/nf_icons")

local DEFAULT_SIZES         = {
    default = 1,
    thin = 0.5,
    button = 1.5,
    window = 1.5,
    thick = 2,
    inputtext = 2,
    separator = 1,
}

-- Settings
local SquareWindowCorners   = Setting("ui_borders_square_window_corners", false) -- Whether window corners should be square (default: false)
local SquareOtherCorners    = Setting("ui_borders_square_other_corners", false)  -- Whether other corners should be square (default: false)
local WindowBorderThickness = Setting("ui_borders_thickness_window", DEFAULT_SIZES.window)
local ThinBorderThickness   = Setting("ui_borders_thickness_thin", DEFAULT_SIZES.thin)
local ThickBorderThickness  = Setting("ui_borders_thickness_thick", DEFAULT_SIZES.thick)
local SeparatorThickness    = Setting("ui_borders_thickness_separator", DEFAULT_SIZES.separator)

-- Menu
local _                     = require("gettext")
local T                     = require("ffi/util").template

local function borders_menu()
    return {
        text_func = function() return nf_icons.label(nf_icons.BORDER_STYLE, _("Borders")) end,
        sub_item_table = {
            {
                text = _("Square window corners"),
                checked_func = SquareWindowCorners.get,
                callback = function()
                    SquareWindowCorners.toggle()
                end,
            },
            {
                text = _("Square other corners"),
                checked_func = SquareOtherCorners.get,
                callback = function()
                    SquareOtherCorners.toggle()
                end,
                separator = true,
            },
            {
                text_func = function()
                    return T(_("Window border thickness: %1"), WindowBorderThickness.get())
                end,
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    local spin = SpinWidget:new {
                        title_text = _("Window border thickness"),
                        value = WindowBorderThickness.get(),
                        default_value = DEFAULT_SIZES.window,
                        value_min = 0,
                        value_max = 5,
                        value_step = 0.1,
                        value_hold_step = 0.5,
                        precision = "%.1f",
                        callback = function(widget)
                            WindowBorderThickness.set(widget.value)
                            Size.border.window = Screen:scaleBySize(widget.value)
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                        end,
                    }
                    UIManager:show(spin)
                end,
            },
            {
                text_func = function()
                    return T(_("Thin border thickness: %1"), ThinBorderThickness.get())
                end,
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    local spin = SpinWidget:new {
                        title_text = _("Thin border thickness"),
                        value = ThinBorderThickness.get(),
                        default_value = DEFAULT_SIZES.thin,
                        value_min = 0,
                        value_max = 3,
                        value_step = 0.1,
                        value_hold_step = 0.5,
                        precision = "%.1f",
                        callback = function(widget)
                            ThinBorderThickness.set(widget.value)
                            Size.border.thin = Screen:scaleBySize(widget.value)
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                        end,
                    }
                    UIManager:show(spin)
                end,
            },
            {
                text_func = function()
                    return T(_("Thick border thickness: %1"), ThickBorderThickness.get())
                end,
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    local spin = SpinWidget:new {
                        title_text = _("Thick border thickness"),
                        value = ThickBorderThickness.get(),
                        default_value = DEFAULT_SIZES.thick,
                        value_min = 0,
                        value_max = 5,
                        value_step = 0.1,
                        value_hold_step = 0.5,
                        precision = "%.1f",
                        callback = function(widget)
                            ThickBorderThickness.set(widget.value)
                            Size.border.thick = Screen:scaleBySize(widget.value)
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                        end,
                    }
                    UIManager:show(spin)
                end,
            },
            {
                text_func = function()
                    return T(_("Separator thickness: %1"), SeparatorThickness.get())
                end,
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    local spin = SpinWidget:new {
                        title_text = _("Separator thickness"),
                        value = SeparatorThickness.get(),
                        default_value = DEFAULT_SIZES.separator,
                        value_min = 0,
                        value_max = 5,
                        value_step = 0.1,
                        value_hold_step = 0.5,
                        precision = "%.1f",
                        callback = function(widget)
                            SeparatorThickness.set(widget.value)
                            Size.line.medium = Screen:scaleBySize(widget.value)
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            UIManager:askForRestart()
                        end,
                    }
                    UIManager:show(spin)
                end,
            },
        },
    }
end

Size.border.window = Screen:scaleBySize(WindowBorderThickness.get())
Size.border.thin = Screen:scaleBySize(ThinBorderThickness.get())
Size.border.thick = Screen:scaleBySize(ThickBorderThickness.get())
Size.line.medium = Screen:scaleBySize(SeparatorThickness.get())

return borders_menu

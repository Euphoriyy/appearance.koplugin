local Blitbuffer = require("ffi/blitbuffer")
local ButtonDialog = require("ui/widget/buttondialog")
local ColorWheelWidget = require("widgets/colorwheelwidget")
local ConfirmBox = require("ui/widget/confirmbox")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local MultiConfirmBox = require("ui/widget/multiconfirmbox")
local Screen = require("device").screen
local Setting = require("lib/setting")
local UIManager = require("ui/uimanager")
local common = require("lib/common")
local theme_list = require("lib/theme_list")

-- Significant variables for the UI background and font color patches
local HexBackgroundColor = Setting("ui_background_color_hex", "#FFFFFF")            -- RGB hex for UI background color (default: #FFFFFF)
local InvertBackgroundColor = Setting("ui_background_color_inverted", true)         -- Whether the UI background color should be inverted in night mode (default: true)
local AltNightBackgroundColor = Setting("ui_background_color_alt_night", false)     -- Whether the UI background color should be changed to an alternative color in night mode (default: false)
local NightHexBackgroundColor = Setting("ui_background_color_night_hex", "#000000") -- RGB hex for the alternative UI background color in night mode (default: #000000)
local HexFontColor = Setting("ui_font_color_hex", "#000000")                        -- RGB hex for UI font color (default: #000000)
local AltNightFontColor = Setting("ui_font_color_alt_night", false)                 -- Whether the UI font color should be changed to an alternative color in night mode (default: false)
local NightHexFontColor = Setting("ui_font_color_night_hex", "#FFFFFF")             -- RGB hex for the alternative UI font color in night mode (default: #FFFFFF)

-- Theme variables
local DayThemes = Setting("ui_themes_day", theme_list.DEFAULT_DAY_THEMES)
local NightThemes = Setting("ui_themes_night", theme_list.DEFAULT_NIGHT_THEMES)
local CurrentDayTheme = Setting("ui_themes_current_day", theme_list.DEFAULT_DAY_THEME)
local CurrentNightTheme = Setting("ui_themes_current_night", theme_list.DEFAULT_NIGHT_THEME)

-- Cache of current theme lists
local cached = {
    dayThemes = DayThemes.get(),
    nightThemes = NightThemes.get(),
}

-- Set background color variables
local function setBackgroundColor(hex, night)
    if not night then
        HexBackgroundColor.set(hex)
    else
        AltNightBackgroundColor.set(true)
        NightHexBackgroundColor.set(hex)
    end
end

-- Set font color variables
local function setForegroundColor(hex, night)
    if not night then
        HexFontColor.set(hex)
    else
        AltNightFontColor.set(true)
        NightHexFontColor.set(hex)
    end
end

-- Special color which indicates that the color should either stay white or be set to the original bgcolor
-- Used for ReaderFooter option and ScreenSaverWidget
local EXCLUSION_COLOR = Blitbuffer.colorFromString("#DAAAAD")

-- Menus
local _ = require("gettext")
local T = require("ffi/util").template

ColorType = { BACKGROUND = "background", FOREGROUND = "foreground", }

local function set_color_menu(touchmenu_instance, type, original_hex, callback)
    original_hex = original_hex or
        (type == ColorType.BACKGROUND and theme_list.DEFAULT_DAY_THEME.bg or theme_list.DEFAULT_DAY_THEME.fg)

    local input_dialog
    input_dialog = InputDialog:new({
        title = T(_("Enter %1 color code"), type),
        input = original_hex,
        input_hint = "#FFFFFF",
        buttons = {
            {
                {
                    text = "Cancel",
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = "Next",
                    callback = function()
                        local text = input_dialog:getInputText()

                        if text ~= "" then
                            if not text:match("^#%x%x%x%x%x%x$") then
                                return
                            end

                            callback(text)

                            touchmenu_instance:updateItems()
                            UIManager:close(input_dialog)
                        end
                    end,
                },
            },
        },
    })
    return input_dialog
end

local function pick_color_menu(touchmenu_instance, type, original_hex, callback)
    original_hex = original_hex or
        (type == ColorType.BACKGROUND and theme_list.DEFAULT_DAY_THEME.bg or theme_list.DEFAULT_DAY_THEME.fg)

    local h, s, v = common.hexToHSV(original_hex)
    local wheel
    local should_invert_wheel = AltNightBackgroundColor.get() or not InvertBackgroundColor.get()
    wheel = ColorWheelWidget:new({
        title_text = T(_("Pick %1 color"), type),
        hue = h,
        saturation = s,
        value = v,
        invert_in_night_mode = should_invert_wheel,
        callback = function(hex)
            callback(hex)

            if touchmenu_instance then
                touchmenu_instance:updateItems()
            end
            UIManager:setDirty(nil, "ui")
        end,
        cancel_callback = function()
            UIManager:setDirty(nil, "ui")
        end,
    })
    return wheel
end

-- Menu to select method for choosing color
local function color_menu(touchmenu_instance, type, original_hex, callback)
    local dialog = MultiConfirmBox:new({
        text = T(_("Choose the %1 color by:"), type),
        choice1_text = _("Hex code"),
        choice1_callback = function()
            local input_dialog = set_color_menu(touchmenu_instance, type, original_hex, callback)
            UIManager:show(input_dialog)
            input_dialog:onShowKeyboard()
        end,
        choice2_text = _("Color picker"),
        choice2_callback = function()
            UIManager:show(pick_color_menu(touchmenu_instance, type, original_hex, callback))
        end,
    })
    return dialog
end

-- Add theme to the appropriate list
local function add_theme(name, bg_hex, fg_hex, night)
    local key = string.lower(name:gsub(" ", "_"))
    local theme = { key = key, label = name, bg = bg_hex, fg = fg_hex, night = night }

    if not night then
        table.insert(cached.dayThemes, theme)
        DayThemes.set(cached.dayThemes)
    else
        table.insert(cached.nightThemes, theme)
        NightThemes.set(cached.nightThemes)
    end
    G_reader_settings:flush()

    return theme
end

-- Replace theme with new version
local function replace_theme(theme, val)
    if not theme.night then
        for i, v in ipairs(cached.dayThemes) do
            if v.key == theme.key then
                cached.dayThemes[i] = val
                break
            end
        end
        DayThemes.set(cached.dayThemes)
    else
        for i, v in ipairs(cached.nightThemes) do
            if v.key == theme.key then
                cached.nightThemes[i] = val
                break
            end
        end
        NightThemes.set(cached.nightThemes)
    end
    G_reader_settings:flush()
end

-- Remove theme from the appropriate list
local function remove_theme(theme)
    if not theme.night then
        for i, v in ipairs(cached.dayThemes) do
            if v.key == theme.key then
                table.remove(cached.dayThemes, i)
                break
            end
        end
        DayThemes.set(cached.dayThemes)
    else
        for i, v in ipairs(cached.nightThemes) do
            if v.key == theme.key then
                table.remove(cached.nightThemes, i)
                break
            end
        end
        NightThemes.set(cached.nightThemes)
    end
    G_reader_settings:flush()
end

-- Declare edit_menu stub
local edit_menu

-- Fetch theme preview buttons for the theme list dialog
local function getThemeButtons(touchmenu_instance, dialog_ref)
    local buttons = {}
    local themes = {}
    for _, v in ipairs(cached.dayThemes) do table.insert(themes, v) end
    for _, v in ipairs(cached.nightThemes) do table.insert(themes, v) end

    for i, theme in ipairs(themes) do
        local bgcolor = Blitbuffer.colorFromString(theme.bg)
        buttons[i] = { {
            text = T(_("§%1 §%2 %3 §r "), theme.night and "blue ⏾" or "orange ☀️",
                string.lower(theme.fg), theme.label),
            menu_style = true,
            original_background = Screen.night_mode and bgcolor:invert() or bgcolor,
            background = EXCLUSION_COLOR,
            callback = function()
                UIManager:show(MultiConfirmBox:new({
                    text = _("Apply the theme to:"),
                    choice1_text = _("§orange ☀️ Day mode§r "),
                    choice1_callback = function()
                        CurrentDayTheme.set(theme)

                        setBackgroundColor(theme.bg, false)
                        setForegroundColor(theme.fg, false)
                        UIManager:broadcastEvent(Event:new("ApplyTheme"))
                    end,
                    choice2_text = _("§blue ⏾ Night mode§r "),
                    choice2_callback = function()
                        CurrentNightTheme.set(theme)

                        setBackgroundColor(theme.bg, true)
                        setForegroundColor(theme.fg, true)
                        UIManager:broadcastEvent(Event:new("ApplyTheme"))
                    end,
                }))

                UIManager:close(dialog_ref.dialog)
            end,
            hold_callback = function()
                UIManager:show(edit_menu(touchmenu_instance, theme, dialog_ref))
            end
        } }
    end
    return buttons
end

-- Message to show when there are no themes in either list
local function showNoThemesMessage()
    UIManager:show(InfoMessage:new({ text = "No themes! Either add a new theme or reset all themes.", timeout = 5, }))
end

-- Menu for editing theme
-- Shown when holding down on a theme in the theme list
edit_menu = function(touchmenu_instance, theme, updialog_ref)
    local function refreshThemeButtons()
        local scrolled_offset = 0
        if updialog_ref.dialog then
            scrolled_offset = updialog_ref.dialog:getScrolledOffset()
            UIManager:close(updialog_ref.dialog)
        end
        local new_ref = {}
        local buttons = getThemeButtons(touchmenu_instance, new_ref)
        if #buttons == 0 then
            showNoThemesMessage()
            return
        end

        local new_updialog = ButtonDialog:new {
            buttons = buttons,
            width_factor = 0.6,
            colorful = true,
            dithered = true,
            rows_per_page = 10,
        }
        new_updialog:setScrolledOffset(scrolled_offset)
        new_ref.dialog = new_updialog
        updialog_ref.dialog = new_updialog -- Update the ref so future calls are correct
        UIManager:show(new_updialog)
    end

    local button_bg_colors = {
        Blitbuffer.colorFromString("#BA8E23"),
        Blitbuffer.colorFromName("blue"),
        Blitbuffer.colorFromName("green"),
        Blitbuffer.colorFromName("red"),
    }

    for i, color in ipairs(button_bg_colors) do
        if Screen.night_mode then
            button_bg_colors[i] = color:invert()
        end
    end

    local dialog

    local edit_buttons = {
        { {
            text = _("§white ✒ Rename§r "),
            menu_style = true,
            original_background = button_bg_colors[1],
            background = EXCLUSION_COLOR,
            callback = function()
                local input_dialog
                input_dialog = InputDialog:new({
                    title = "Enter the theme's new name:",
                    input = theme.label,
                    buttons = {
                        {
                            {
                                text = "Cancel",
                                callback = function()
                                    UIManager:close(input_dialog)
                                end,
                            },
                            {
                                text = "Save",
                                callback = function()
                                    local text = input_dialog:getInputText()

                                    if text ~= "" then
                                        theme.label = text
                                        replace_theme(theme, theme)
                                        refreshThemeButtons()

                                        UIManager:close(input_dialog)
                                        UIManager:close(dialog)
                                    end
                                end,
                            }
                        }
                    }
                })
                UIManager:show(input_dialog)
                input_dialog:onShowKeyboard()
            end,
        } },
        { {
            text = T(_("§white ● Edit background color§r ")),
            menu_style = true,
            original_background = button_bg_colors[2],
            background = EXCLUSION_COLOR,
            callback = function()
                UIManager:show(color_menu(touchmenu_instance, ColorType.BACKGROUND, theme.bg, function(bg_hex)
                    theme.bg = bg_hex
                    replace_theme(theme, theme)

                    UIManager:close(dialog)
                    refreshThemeButtons()
                end))

                UIManager:close(dialog)
            end,
        } },
        { {
            text = T(_("§white ＴEdit foreground color§r ")),
            menu_style = true,
            original_background = button_bg_colors[3],
            background = EXCLUSION_COLOR,
            callback = function()
                UIManager:show(color_menu(touchmenu_instance, ColorType.FOREGROUND, theme.fg, function(fg_hex)
                    theme.fg = fg_hex
                    replace_theme(theme, theme)

                    UIManager:close(dialog)
                    refreshThemeButtons()
                end))
            end,
        } },
        { {
            text = _("§white ✖ Delete§r "),
            menu_style = true,
            original_background = button_bg_colors[4],
            background = EXCLUSION_COLOR,
            callback = function()
                remove_theme(theme)

                UIManager:close(dialog)
                refreshThemeButtons()
            end,
        } },
    }

    dialog = ButtonDialog:new {
        buttons = edit_buttons,
        width_factor = 0.6,
        colorful = true,
        dithered = true,
    }
    return dialog
end

-- Popup to ask whether the theme should be (re)applied now
-- Used after creation of a new theme or selection of the current theme
local function ask_to_apply(theme, reapply)
    UIManager:show(ConfirmBox:new({
        text = T(_("%1 this theme now?"), reapply and "Reapply" or "Apply"),
        ok_text = _("Yes"),
        ok_callback = function()
            if not theme.night then
                CurrentDayTheme.set(theme)
            else
                CurrentNightTheme.set(theme)
            end

            setBackgroundColor(theme.bg, theme.night)
            setForegroundColor(theme.fg, theme.night)
            UIManager:broadcastEvent(Event:new("ApplyTheme"))
        end,
    }))
end

-- Popup that asks which mode the theme should be created for
local function select_mode(name, bg_hex, fg_hex)
    UIManager:show(MultiConfirmBox:new({
        text = _("The theme is for:"),
        choice1_text = _("§orange ☀️ Day mode§r "),
        choice1_callback = function()
            local theme = add_theme(name, bg_hex, fg_hex, false)
            ask_to_apply(theme)
        end,
        choice2_text = _("§blue ⏾ Night mode§r "),
        choice2_callback = function()
            local theme = add_theme(name, bg_hex, fg_hex, true)
            ask_to_apply(theme)
        end,
    }))
end

-- Main themes menu
local function themes_menu()
    return {
        text = _("Themes"),
        sub_item_table_func = function()
            InputDialog = require("ui/widget/inputdialog")

            local items = {
                {
                    text_func = function()
                        return T(_("Current day theme: %1"), CurrentDayTheme.get().label)
                    end,
                    callback = function()
                        ask_to_apply(CurrentDayTheme.get(), true)
                    end,
                },
                {
                    text_func = function()
                        return T(_("Current night theme: %1"), CurrentNightTheme.get().label)
                    end,
                    callback = function()
                        ask_to_apply(CurrentNightTheme.get(), true)
                    end,
                    separator = true,
                },
                {
                    text = _("Choose a theme"),
                    callback = function(touchmenu_instance)
                        local dialog_ref = {}
                        local buttons = getThemeButtons(touchmenu_instance, dialog_ref)
                        if #buttons == 0 then
                            showNoThemesMessage()
                            return
                        end

                        local dialog = ButtonDialog:new {
                            buttons = buttons,
                            width_factor = 0.6,
                            colorful = true,
                            dithered = true,
                            rows_per_page = 10,
                        }
                        dialog_ref.dialog = dialog
                        UIManager:show(dialog)
                    end,
                },
                {
                    text = _("Add a theme"),
                    callback = function(touchmenu_instance)
                        local input_dialog
                        input_dialog = InputDialog:new({
                            title = "Enter a name for the theme",
                            buttons = {
                                {
                                    {
                                        text = "Cancel",
                                        callback = function()
                                            UIManager:close(input_dialog)
                                        end,
                                    },
                                    {
                                        text = "Next",
                                        callback = function()
                                            local text = input_dialog:getInputText()

                                            if text ~= "" then
                                                UIManager:show(color_menu(touchmenu_instance, ColorType.BACKGROUND,
                                                    nil,
                                                    function(bg_hex)
                                                        UIManager:show(color_menu(touchmenu_instance,
                                                            ColorType.FOREGROUND,
                                                            nil,
                                                            function(fg_hex)
                                                                select_mode(text, bg_hex, fg_hex)
                                                            end))
                                                    end))

                                                UIManager:close(input_dialog)
                                            end
                                        end,
                                    },
                                },
                            }
                        })
                        UIManager:show(input_dialog)
                        input_dialog:onShowKeyboard()
                    end,
                },
                {
                    text = _("Reset themes"),
                    sub_item_table = {
                        {
                            text = _("Reset to current themes"),
                            callback = function()
                                local current_day_theme = CurrentDayTheme.get()
                                local current_night_theme = CurrentNightTheme.get()
                                setBackgroundColor(current_day_theme.bg, false)
                                setBackgroundColor(current_night_theme.bg, true)
                                setForegroundColor(current_day_theme.fg, false)
                                setForegroundColor(current_night_theme.fg, true)
                                UIManager:broadcastEvent(Event:new("ApplyTheme"))
                            end,
                        },
                        {
                            text = _("Reset to default themes"),
                            callback = function()
                                CurrentDayTheme.set(theme_list.DEFAULT_DAY_THEME)
                                CurrentNightTheme.set(theme_list.DEFAULT_NIGHT_THEME)

                                setBackgroundColor(theme_list.DEFAULT_DAY_THEME.bg, false)
                                setBackgroundColor(theme_list.DEFAULT_NIGHT_THEME.bg, true)
                                setForegroundColor(theme_list.DEFAULT_DAY_THEME.fg, false)
                                setForegroundColor(theme_list.DEFAULT_NIGHT_THEME.fg, true)
                                UIManager:broadcastEvent(Event:new("ApplyTheme"))
                            end,
                        },
                        {
                            text = _("Reset all themes"),
                            callback = function()
                                DayThemes.set(theme_list.DEFAULT_DAY_THEMES)
                                cached.dayThemes = DayThemes.get()
                                NightThemes.set(theme_list.DEFAULT_NIGHT_THEMES)
                                cached.nightThemes = NightThemes.get()
                            end,
                        },
                    },
                },
            }
            return items
        end,
    }
end

return themes_menu

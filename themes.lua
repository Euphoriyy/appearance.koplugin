local Blitbuffer = require("ffi/blitbuffer")
local ButtonDialog = require("ui/widget/buttondialog")
local ColorWheelWidget = require("widgets/colorwheelwidget")
local ConfirmBox = require("ui/widget/confirmbox")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local FileManager = require("apps/filemanager/filemanager")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local MultiConfirmBox = require("ui/widget/multiconfirmbox")
local ReaderUI = require("apps/reader/readerui")
local Screen = require("device").screen
local Setting = require("lib/setting")
local Settings = require("lib/settings")
local TripleConfirmBox = require("widgets/tripleconfirmbox")
local UIManager = require("ui/uimanager")
local common = require("lib/common")
local theme_list = require("lib/theme_list")

-- Significant variables for the UI background and font color
local UIHexBackgroundColor = Setting("ui_background_color_hex", "#FFFFFF")
local UIInvertBackgroundColor = Setting("ui_background_color_inverted", true)
local UIAltNightBackgroundColor = Setting("ui_background_color_alt_night", false)
local UINightHexBackgroundColor = Setting("ui_background_color_night_hex", "#000000")
local UIHexFontColor = Setting("ui_font_color_hex", "#000000")
local UIAltNightFontColor = Setting("ui_font_color_alt_night", false)
local UINightHexFontColor = Setting("ui_font_color_night_hex", "#FFFFFF")

-- Significant variables for the Book background, font, and link color
local BookHexBackgroundColor = Setting("book_background_color_hex", "#FFFFFF")
local BookAltNightBackgroundColor = Setting("book_background_color_alt_night", false)
local BookNightHexBackgroundColor = Setting("book_background_color_night_hex", "#000000")
local BookHexFontColor = Setting("book_font_color_hex", "#000000")
local BookAltNightFontColor = Setting("book_font_color_alt_night", false)
local BookNightHexFontColor = Setting("book_font_color_night_hex", "#FFFFFF")
local BookHexLinkColor = Setting("book_link_color_hex", nil)
local BookAltNightLinkColor = Setting("book_link_color_alt_night", false)
local BookNightHexLinkColor = Setting("book_link_color_night_hex", nil)

-- Theme variables
local DayThemes = Setting("ui_themes_day", theme_list.DEFAULT_DAY_THEMES)
local NightThemes = Setting("ui_themes_night", theme_list.DEFAULT_NIGHT_THEMES)
local CurrentUIDayTheme = Setting("ui_themes_current_day", theme_list.DEFAULT_DAY_THEME)
local CurrentUINightTheme = Setting("ui_themes_current_night", theme_list.DEFAULT_NIGHT_THEME)
local CurrentBookDayTheme = Setting("book_themes_current_day", theme_list.DEFAULT_DAY_THEME)
local CurrentBookNightTheme = Setting("book_themes_current_night", theme_list.DEFAULT_NIGHT_THEME)

-- Cache of current theme lists
local cached = {
    dayThemes = DayThemes.get(),
    nightThemes = NightThemes.get(),
}

-- Set background color variables
local function setBackgroundColor(hex, book, night)
    if not book then
        if not night then
            UIHexBackgroundColor.set(hex)
        else
            UIAltNightBackgroundColor.set(true)
            UINightHexBackgroundColor.set(hex)
        end
    else
        if not night then
            BookHexBackgroundColor.set(hex)
        else
            BookAltNightBackgroundColor.set(true)
            BookNightHexBackgroundColor.set(hex)
        end
    end
end

-- Set font color variables
local function setForegroundColor(hex, book, night)
    if not book then
        if not night then
            UIHexFontColor.set(hex)
        else
            UIAltNightFontColor.set(true)
            UINightHexFontColor.set(hex)
        end
    else
        if not night then
            BookHexFontColor.set(hex)
        else
            BookAltNightFontColor.set(true)
            BookNightHexFontColor.set(hex)
        end
    end
end

local function setLinkColor(hex, book, night)
    if not book then return end
    if not night then
        BookHexLinkColor.set(hex)
    else
        BookAltNightLinkColor.set(true)
        BookNightHexLinkColor.set(hex)
    end
end

-- Menus
local _ = require("gettext")
local T = require("ffi/util").template

local ColorType = { BACKGROUND = "background", FOREGROUND = "foreground", LINK = "link", }

local function set_color_menu(touchmenu_instance, type, original_hex, callback)
    if not original_hex then
        if type == ColorType.BACKGROUND then
            original_hex = theme_list.DEFAULT_DAY_THEME.bg
        elseif type == ColorType.FOREGROUND then
            original_hex = theme_list.DEFAULT_DAY_THEME.fg
        elseif type == ColorType.LINK then
            original_hex = "#0066FF"
        end
    end

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

                            if touchmenu_instance then
                                touchmenu_instance:updateItems()
                            end
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
    if not original_hex then
        if type == ColorType.BACKGROUND then
            original_hex = theme_list.DEFAULT_DAY_THEME.bg
        elseif type == ColorType.FOREGROUND then
            original_hex = theme_list.DEFAULT_DAY_THEME.fg
        elseif type == ColorType.LINK then
            original_hex = "#0066FF"
        end
    end

    local h, s, v = common.hexToHSV(original_hex)
    local wheel
    local should_invert_wheel = UIAltNightBackgroundColor.get() or not UIInvertBackgroundColor.get()
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
local function color_menu(touchmenu_instance, type, original_hex, callback, skippable)
    local VariableConfirmBox = skippable and TripleConfirmBox or MultiConfirmBox

    local dialog = VariableConfirmBox:new({
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
        choice3_text = _("Skip"),
        choice3_callback = function()
            callback(nil)
        end,
        choice3_enabled = skippable,
    })
    return dialog
end

-- Add theme to the appropriate list
local function add_theme(name, bg_hex, fg_hex, link_hex, night)
    local key = string.lower(name:gsub(" ", "_"))
    local theme = { key = key, label = name, bg = bg_hex, fg = fg_hex, link = link_hex, night = night }

    if not night then
        table.insert(cached.dayThemes, theme)
        DayThemes.set(cached.dayThemes)
    else
        table.insert(cached.nightThemes, theme)
        NightThemes.set(cached.nightThemes)
    end
    Settings:flushSettings()

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
    Settings:flushSettings()
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
    Settings:flushSettings()
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
            -- Could also use ↗ symbol ¯\_('' )_/¯
            text = T(_("§%1 §%2 %3 §%4 ⤴ §r"), theme.night and "blue ⏾" or "orange ☀️",
                string.lower(theme.fg), theme.label, theme.link or "blue"),
            menu_style = true,
            original_background = Screen.night_mode and bgcolor:invert() or bgcolor,
            background = common.EXCLUSION_COLOR,
            callback = function()
                UIManager:show(TripleConfirmBox:new({
                    text = _("Apply the theme to:"),
                    choice1_text = _("UI"),
                    choice1_callback = function()
                        UIManager:show(MultiConfirmBox:new({
                            text = _("Apply the theme to:"),
                            choice1_text = _("§orange ☀️ Day mode§r "),
                            choice1_callback = function()
                                CurrentUIDayTheme.set(theme)

                                setBackgroundColor(theme.bg, false, false)
                                setForegroundColor(theme.fg, false, false)
                                UIManager:broadcastEvent(Event:new("ApplyTheme"))
                            end,
                            choice2_text = _("§blue ⏾ Night mode§r "),
                            choice2_callback = function()
                                CurrentUINightTheme.set(theme)

                                setBackgroundColor(theme.bg, false, true)
                                setForegroundColor(theme.fg, false, true)
                                UIManager:broadcastEvent(Event:new("ApplyTheme"))
                            end,
                        }))
                    end,
                    choice2_text = _("Book"),
                    choice2_callback = function()
                        UIManager:show(MultiConfirmBox:new({
                            text = _("Apply the theme to:"),
                            choice1_text = _("§orange ☀️ Day mode§r "),
                            choice1_callback = function()
                                CurrentBookDayTheme.set(theme)

                                setBackgroundColor(theme.bg, true, false)
                                setForegroundColor(theme.fg, true, false)
                                setLinkColor(theme.link, true, false)
                                UIManager:broadcastEvent(Event:new("ApplyTheme"))
                            end,
                            choice2_text = _("§blue ⏾ Night mode§r "),
                            choice2_callback = function()
                                CurrentBookNightTheme.set(theme)

                                setBackgroundColor(theme.bg, true, true)
                                setForegroundColor(theme.fg, true, true)
                                setLinkColor(theme.link, true, true)
                                UIManager:broadcastEvent(Event:new("ApplyTheme"))
                            end,
                        }))
                    end,
                    choice3_text = _("Both"),
                    choice3_callback = function()
                        UIManager:show(MultiConfirmBox:new({
                            text = _("Apply the theme to:"),
                            choice1_text = _("§orange ☀️ Day mode§r "),
                            choice1_callback = function()
                                CurrentUIDayTheme.set(theme)
                                CurrentBookDayTheme.set(theme)

                                setBackgroundColor(theme.bg, false, false)
                                setForegroundColor(theme.fg, false, false)
                                setBackgroundColor(theme.bg, true, false)
                                setForegroundColor(theme.fg, true, false)
                                setLinkColor(theme.link, true, false)
                                UIManager:broadcastEvent(Event:new("ApplyTheme"))
                            end,
                            choice2_text = _("§blue ⏾ Night mode§r "),
                            choice2_callback = function()
                                CurrentUINightTheme.set(theme)
                                CurrentBookNightTheme.set(theme)

                                setBackgroundColor(theme.bg, false, true)
                                setForegroundColor(theme.fg, false, true)
                                setBackgroundColor(theme.bg, true, true)
                                setForegroundColor(theme.fg, true, true)
                                setLinkColor(theme.link, true, true)
                                UIManager:broadcastEvent(Event:new("ApplyTheme"))
                            end,
                        }))
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
        Blitbuffer.colorFromString("#2D728F"),
        Blitbuffer.colorFromString("#60AB9A"),
        Blitbuffer.colorFromString("#9B5DE5"),
        Blitbuffer.colorFromString("#700548"),
        Blitbuffer.colorFromString("#FF5964"),
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
            background = common.EXCLUSION_COLOR,
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
            background = common.EXCLUSION_COLOR,
            callback = function()
                UIManager:show(color_menu(touchmenu_instance, ColorType.BACKGROUND, theme.bg, function(bg_hex)
                    theme.bg = bg_hex
                    replace_theme(theme, theme)

                    UIManager:close(dialog)
                    refreshThemeButtons()
                end))
            end,
        } },
        { {
            text = T(_("§white ＴEdit foreground color§r ")),
            menu_style = true,
            original_background = button_bg_colors[3],
            background = common.EXCLUSION_COLOR,
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
            text = T(_("§white ⤴ Edit link color§r ")),
            menu_style = true,
            original_background = button_bg_colors[4],
            background = common.EXCLUSION_COLOR,
            callback = function()
                UIManager:show(color_menu(touchmenu_instance, ColorType.LINK, theme.link, function(link_hex)
                    theme.link = link_hex
                    replace_theme(theme, theme)

                    UIManager:close(dialog)
                    refreshThemeButtons()
                end))
            end,
        } },
        { {
            text = _("§white ✖ Delete§r "),
            menu_style = true,
            original_background = button_bg_colors[6],
            background = common.EXCLUSION_COLOR,
            callback = function()
                remove_theme(theme)

                UIManager:close(dialog)
                refreshThemeButtons()
            end,
        } },
    }

    if theme.link then
        table.insert(edit_buttons, 5, { {
            text = T(_("§white ⟳ Reset link color§r ")),
            menu_style = true,
            original_background = button_bg_colors[5],
            background = common.EXCLUSION_COLOR,
            callback = function()
                theme.link = nil
                replace_theme(theme, theme)

                UIManager:close(dialog)
                refreshThemeButtons()
            end,
        } })
    end

    dialog = ButtonDialog:new {
        buttons = edit_buttons,
        width_factor = 0.5,
        colorful = true,
        dithered = true,
    }
    return dialog
end

-- Popup to ask whether the theme should be (re)applied now
-- Used after creation of a new theme or selection of the current theme
local function ask_to_apply(theme, reapply, book)
    local function apply_theme(both_ui_and_book)
        if both_ui_and_book then
            if not theme.night then
                CurrentUIDayTheme.set(theme)
                CurrentBookDayTheme.set(theme)
            else
                CurrentUINightTheme.set(theme)
                CurrentBookNightTheme.set(theme)
            end

            setBackgroundColor(theme.bg, false, theme.night)
            setForegroundColor(theme.fg, false, theme.night)
            setBackgroundColor(theme.bg, true, theme.night)
            setForegroundColor(theme.fg, true, theme.night)
            setLinkColor(theme.link, true, theme.night)
            UIManager:broadcastEvent(Event:new("ApplyTheme"))
        else
            if not theme.night then
                if not book then
                    CurrentUIDayTheme.set(theme)
                else
                    CurrentBookDayTheme.set(theme)
                end
            else
                if not book then
                    CurrentUINightTheme.set(theme)
                else
                    CurrentBookNightTheme.set(theme)
                end
            end

            setBackgroundColor(theme.bg, book, theme.night)
            setForegroundColor(theme.fg, book, theme.night)
            setLinkColor(theme.link, book, theme.night)
            UIManager:broadcastEvent(Event:new("ApplyTheme"))
        end
    end

    UIManager:show(ConfirmBox:new({
        text = T(_("%1 this theme now?"), reapply and "Reapply" or "Apply"),
        ok_text = _("Yes"),
        ok_callback = function()
            if book == nil then
                UIManager:show(TripleConfirmBox:new({
                    text = _("Apply the theme to:"),
                    choice1_text = _("UI"),
                    choice1_callback = function()
                        book = false
                        apply_theme(false)
                    end,
                    choice2_text = _("Book"),
                    choice2_callback = function()
                        book = true
                        apply_theme(false)
                    end,
                    choice3_text = _("Both"),
                    choice3_callback = function()
                        apply_theme(true)
                    end,
                }))
            else
                apply_theme(false)
            end
        end,
    }))
end

-- Popup that asks which mode the theme should be created for
local function select_mode(name, bg_hex, fg_hex, link_hex)
    UIManager:show(MultiConfirmBox:new({
        text = _("The theme is for:"),
        choice1_text = _("§orange ☀️ Day mode§r "),
        choice1_callback = function()
            local theme = add_theme(name, bg_hex, fg_hex, link_hex, false)
            ask_to_apply(theme)
        end,
        choice2_text = _("§blue ⏾ Night mode§r "),
        choice2_callback = function()
            local theme = add_theme(name, bg_hex, fg_hex, link_hex, true)
            ask_to_apply(theme)
        end,
    }))
end

-- Main themes menu
local function themes_menu()
    return {
        text = _("Themes"),
        sub_item_table_func = function()
            local items = {
                {
                    text_func = function()
                        return T(_("Current day theme for UI: %1"), CurrentUIDayTheme.get().label)
                    end,
                    callback = function()
                        ask_to_apply(CurrentUIDayTheme.get(), true, false)
                    end,
                },
                {
                    text_func = function()
                        return T(_("Current night theme for UI: %1"), CurrentUINightTheme.get().label)
                    end,
                    callback = function()
                        ask_to_apply(CurrentUINightTheme.get(), true, false)
                    end,
                    separator = true,
                },
                {
                    text_func = function()
                        return T(_("Current day theme for Book: %1"), CurrentBookDayTheme.get().label)
                    end,
                    callback = function()
                        ask_to_apply(CurrentBookDayTheme.get(), true, true)
                    end,
                },
                {
                    text_func = function()
                        return T(_("Current night theme for Book: %1"), CurrentBookNightTheme.get().label)
                    end,
                    callback = function()
                        ask_to_apply(CurrentBookNightTheme.get(), true, true)
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
                                                UIManager:show(color_menu(touchmenu_instance,
                                                    ColorType.BACKGROUND, nil,
                                                    function(bg_hex)
                                                        UIManager:show(color_menu(touchmenu_instance,
                                                            ColorType.FOREGROUND, nil,
                                                            function(fg_hex)
                                                                UIManager:show(color_menu(touchmenu_instance,
                                                                    ColorType.LINK, nil,
                                                                    function(link_hex)
                                                                        select_mode(text, bg_hex, fg_hex, link_hex)
                                                                    end, true))
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
                                local current_ui_day_theme = CurrentUIDayTheme.get()
                                local current_ui_night_theme = CurrentUINightTheme.get()
                                local current_book_day_theme = CurrentBookDayTheme.get()
                                local current_book_night_theme = CurrentBookNightTheme.get()

                                setBackgroundColor(current_ui_day_theme.bg, false, false)
                                setBackgroundColor(current_ui_night_theme.bg, false, true)
                                setForegroundColor(current_ui_day_theme.fg, false, false)
                                setForegroundColor(current_ui_night_theme.fg, false, true)

                                setBackgroundColor(current_book_day_theme.bg, true, false)
                                setBackgroundColor(current_book_night_theme.bg, true, true)
                                setForegroundColor(current_book_day_theme.fg, true, false)
                                setForegroundColor(current_book_night_theme.fg, true, true)
                                setLinkColor(current_book_day_theme.link, true, false)
                                setLinkColor(current_book_night_theme.link, true, true)

                                UIManager:broadcastEvent(Event:new("ApplyTheme"))
                            end,
                        },
                        {
                            text = _("Reset to default themes"),
                            callback = function()
                                CurrentUIDayTheme.set(theme_list.DEFAULT_DAY_THEME)
                                CurrentUINightTheme.set(theme_list.DEFAULT_NIGHT_THEME)
                                CurrentBookDayTheme.set(theme_list.DEFAULT_DAY_THEME)
                                CurrentBookNightTheme.set(theme_list.DEFAULT_NIGHT_THEME)

                                setBackgroundColor(theme_list.DEFAULT_DAY_THEME.bg, false, false)
                                setBackgroundColor(theme_list.DEFAULT_NIGHT_THEME.bg, false, true)
                                setForegroundColor(theme_list.DEFAULT_DAY_THEME.fg, false, false)
                                setForegroundColor(theme_list.DEFAULT_NIGHT_THEME.fg, false, true)

                                setBackgroundColor(theme_list.DEFAULT_DAY_THEME.bg, true, false)
                                setBackgroundColor(theme_list.DEFAULT_NIGHT_THEME.bg, true, true)
                                setForegroundColor(theme_list.DEFAULT_DAY_THEME.fg, true, false)
                                setForegroundColor(theme_list.DEFAULT_NIGHT_THEME.fg, true, true)
                                setLinkColor(theme_list.DEFAULT_DAY_THEME.link, true, false)
                                setLinkColor(theme_list.DEFAULT_NIGHT_THEME.link, true, true)

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

-- Register theme selection dispatcher actions
local function getThemeActions(night)
    local action_nums, action_texts = {}, {}

    local themes = night and cached.nightThemes or cached.dayThemes

    for i, theme in ipairs(themes) do
        table.insert(action_nums, i)
        table.insert(action_texts, theme.label)
    end
    return action_nums, action_texts
end

local ApplicationMode = {
    DAY_UI = 1,
    DAY_BOOK = 2,
    NIGHT_UI = 3,
    NIGHT_BOOK = 4,
}

local theme_setters = {
    [ApplicationMode.DAY_UI] = CurrentUIDayTheme,
    [ApplicationMode.DAY_BOOK] = CurrentBookDayTheme,
    [ApplicationMode.NIGHT_UI] = CurrentUINightTheme,
    [ApplicationMode.NIGHT_BOOK] = CurrentBookNightTheme,
}

local function SelectTheme(_, args)
    if not args or #args < 2 then return end
    local application_mode, action_num = args[1], args[2]

    local book = application_mode == ApplicationMode.DAY_BOOK
        or application_mode == ApplicationMode.NIGHT_BOOK
    local night = application_mode == ApplicationMode.NIGHT_UI
        or application_mode == ApplicationMode.NIGHT_BOOK

    local themes = night and cached.nightThemes or cached.dayThemes

    local theme = themes[action_num]
    if not theme then return end

    local setter = theme_setters[application_mode]
    if setter then
        setter.set(theme)
    end

    setBackgroundColor(theme.bg, book, night)
    setForegroundColor(theme.fg, book, night)
    setLinkColor(theme.link, book, night)
    UIManager:broadcastEvent(Event:new("ApplyTheme"))
end

FileManager.onSelectTheme = SelectTheme
ReaderUI.onSelectTheme = SelectTheme

Dispatcher:registerAction("ui_themes_select_day_ui", {
    category = "string",
    event = "SelectTheme",
    arg = ApplicationMode.DAY_UI,
    title = _("Select day theme for UI"),
    args_func = function() return getThemeActions(false) end,
    general = true,
})

Dispatcher:registerAction("ui_themes_select_day_book", {
    category = "string",
    event = "SelectTheme",
    arg = ApplicationMode.DAY_BOOK,
    title = _("Select day theme for book"),
    args_func = function() return getThemeActions(false) end,
    general = true,
})

Dispatcher:registerAction("ui_themes_select_night_ui", {
    category = "string",
    event = "SelectTheme",
    arg = ApplicationMode.NIGHT_UI,
    title = _("Select night theme for UI"),
    args_func = function() return getThemeActions(true) end,
    general = true,
})

Dispatcher:registerAction("ui_themes_select_night_book", {
    category = "string",
    event = "SelectTheme",
    arg = ApplicationMode.NIGHT_BOOK,
    title = _("Select night theme for book"),
    args_func = function() return getThemeActions(true) end,
    general = true,
})

return themes_menu

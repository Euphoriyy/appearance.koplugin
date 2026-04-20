local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local ColorWheelWidget = require("widgets/colorwheelwidget")
local Geom = require("ui/geometry")
local InputDialog = require("ui/widget/inputdialog")
local Math = require("optmath")
local ProgressWidget = require("ui/widget/progresswidget")
local ReaderFooter = require("apps/reader/modules/readerfooter")
local ReaderUI = require("apps/reader/readerui")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local common = require("lib/common")
local _ = require("gettext")
local T = require("ffi/util").template

-- Somewhat empirically chosen threshold to switch between the two designs ;o)
local INITIAL_MARKER_HEIGHT_THRESHOLD = Screen:scaleBySize(12)

-- Settings
local Settings = {}
local InvertReadColor = Setting("book_progress_bar_colors_invert_read", false)
local InvertUnreadColor = Setting("book_progress_bar_colors_invert_unread", true)

local function colorAttrib(read)
    return read and "fillcolor" or "bgcolor"
end
local function getStyle(thin)
    return thin and "progress_style_thin_colors" or "progress_style_thick_colors"
end

function Settings:init(footer)
    local function defaultColor(thin)
        ProgressWidget:updateStyle(not thin, nil, false) -- no object needed, since height is nil, do no set colors
        local read, unread = colorAttrib(true), colorAttrib(false)
        return {
            [read] = "#808080",
            [unread] = "#c0c0c0",
        }
    end

    self.footer = footer
    self.default = {
        [getStyle(true)] = defaultColor(true),
        [getStyle(false)] = defaultColor(false),
    }
end

function Settings:getDefault(thin, color_attrib)
    local default = self.default[getStyle(thin)]
    return default[color_attrib]
end

function Settings:get(thin, color_attrib)
    if not self.footer then return nil end
    local settings = self.footer.settings and self.footer.settings[getStyle(thin)]
    local color = settings and settings[color_attrib]
    return color or self:getDefault(thin, color_attrib)
end

function Settings:set(thin, color_attrib, color)
    if not self.footer then return nil end
    local style = getStyle(thin)
    local settings = self.footer.settings[style] or {}
    settings[color_attrib] = color
    self.footer.settings[style] = settings
end

function Settings:getPersistent(thin, color_attrib)
    local key = getStyle(thin) .. "_" .. color_attrib
    local value = G_reader_settings:readSetting(key)
    if value then
        return value
    end
    return self:getDefault(thin, color_attrib)
end

function Settings:setPersistent(thin, color_attrib, color)
    local key = getStyle(thin) .. "_" .. color_attrib
    G_reader_settings:saveSetting(key, color)
    self:set(thin, color_attrib, color)
end

--------------------------------------------
-- Reader Footer
--------------------------------------------
local original_init = ReaderFooter.init
function ReaderFooter:init()
    Settings:init(self)
    original_init(self)
    self.progress_bar:_setColors(self.settings.progress_style_thin)
end

function ReaderFooter:onToggleNightMode()
    local read, unread = colorAttrib(true), colorAttrib(false)
    local thin = self.settings.progress_style_thin
    local readColor = Settings:getPersistent(thin, read)
    local unreadColor = Settings:getPersistent(thin, unread)

    if not Screen.night_mode then
        if not InvertReadColor.get() then
            readColor = common.invertColor(readColor)
        end
        if not InvertUnreadColor.get() then
            unreadColor = common.invertColor(unreadColor)
        end
    end

    self.progress_bar[read]   = Blitbuffer.colorFromString(readColor)
    self.progress_bar[unread] = Blitbuffer.colorFromString(unreadColor)

    self:refreshFooter(true)
end

function ReaderFooter:onSetNightMode(night_mode)
    local read, unread = colorAttrib(true), colorAttrib(false)
    local thin = self.settings.progress_style_thin
    local readColor = Settings:getPersistent(thin, read)
    local unreadColor = Settings:getPersistent(thin, unread)

    if night_mode then
        if not InvertReadColor.get() then
            readColor = common.invertColor(readColor)
        end
        if not InvertUnreadColor.get() then
            unreadColor = common.invertColor(unreadColor)
        end
    end

    self.progress_bar[read]   = Blitbuffer.colorFromString(readColor)
    self.progress_bar[unread] = Blitbuffer.colorFromString(unreadColor)

    self:refreshFooter(true)
end

local original_loadPreset = ReaderFooter.loadPreset
function ReaderFooter:loadPreset(preset)
    original_loadPreset(self, preset)
    self.progress_bar:_setColors(self.settings.progress_style_thin, true)
end

function ProgressWidget:_setColors(thin, preset)
    local read, unread = colorAttrib(true), colorAttrib(false)

    local readColor    = preset and Settings:get(thin, read) or Settings:getPersistent(thin, read)
    local unreadColor  = preset and Settings:get(thin, unread) or Settings:getPersistent(thin, unread)

    if not readColor:match("^#%x%x%x%x%x%x$") then
        readColor = "#808080"
        Settings:set(thin, read, readColor)
        Settings:setPersistent(thin, read, readColor)
    end

    if not unreadColor:match("^#%x%x%x%x%x%x$") then
        unreadColor = "#c0c0c0"
        Settings:set(thin, read, readColor)
        Settings:setPersistent(thin, unread, unreadColor)
    end

    if Screen.night_mode then
        if not InvertReadColor.get() then
            readColor = common.invertColor(readColor)
        end
        if not InvertUnreadColor.get() then
            unreadColor = common.invertColor(unreadColor)
        end
    end

    self[read]   = Blitbuffer.colorFromString(readColor)
    self[unread] = Blitbuffer.colorFromString(unreadColor)
end

local orig_ProgressWidget_updateStyle = ProgressWidget.updateStyle
function ProgressWidget:updateStyle(thick, height, do_setcolors)
    do_setcolors = do_setcolors or do_setcolors == nil -- default: do_setcolors = trues
    orig_ProgressWidget_updateStyle(self, thick, height)
    if do_setcolors then self:_setColors(not thick) end
end

--------------------------------------------
-- Status Bar Menu
--------------------------------------------
local function getMenuItem(menu, ...) -- path
    local function findItem(sub_items, texts)
        local find = {}
        local texts = type(texts) == "table" and texts or { texts }
        -- stylua: ignore
        for _, text in ipairs(texts) do find[text] = true end
        for _, item in ipairs(sub_items) do
            local text = item.text or (item.text_func and item.text_func())
            if text and find[text] then
                return item
            end
        end
    end

    local sub_items, item
    for _, texts in ipairs({ ... }) do -- walk path
        sub_items = (item or menu).sub_item_table
        if not sub_items then
            return
        end
        item = findItem(sub_items, texts)
        if not item then
            return
        end
    end
    return item
end

function ReaderFooter:_statusBarColorMenu(read)
    local color_attrib = colorAttrib(read)
    return {
        text_func = function()
            local color = Settings:getPersistent(self.settings.progress_style_thin, color_attrib)
            local format = (read and "Read color: %1" or "Unread color: %1") .. " (hold to pick)"
            return T(format, color)
        end,
        keep_menu_open = true,
        enabled_func = function()
            return not self.settings.disable_progress_bar
        end,
        callback = function(touchmenu_instance)
            local invert_enabled = read and InvertReadColor.get() or InvertUnreadColor.get()
            local input_dialog
            input_dialog = InputDialog:new({
                title = "Enter color hex code for " .. (read and "read color" or "unread color"),
                input = Settings:getPersistent(self.settings.progress_style_thin, color_attrib),
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
                            text = "Save",
                            callback = function()
                                local text = input_dialog:getInputText()

                                if text ~= "" then
                                    if not text:match("^#%x%x%x%x%x%x$") then
                                        return
                                    end

                                    -- Process color depending on if the color should be inverted in night mode
                                    local display_text = text
                                    if Screen.night_mode then
                                        if not invert_enabled then
                                            display_text = common.invertColor(text)
                                        end
                                    end
                                    local color = Blitbuffer.colorFromString(display_text)

                                    if not color then
                                        return
                                    end

                                    Settings:set(self.settings.progress_style_thin, color_attrib,
                                        string.upper(text))
                                    Settings:setPersistent(self.settings.progress_style_thin, color_attrib,
                                        string.upper(text))
                                    self.progress_bar[color_attrib] = color
                                    touchmenu_instance:updateItems()
                                    self:refreshFooter(true)
                                    UIManager:close(input_dialog)
                                end
                            end,
                        },
                    },
                },
            })
            UIManager:show(input_dialog)
            input_dialog:onShowKeyboard()
        end,
        hold_callback = function(touchmenu_instance)
            local title_text = read and "Pick read color" or "Pick unread color"
            local current_hex = Settings:getPersistent(self.settings.progress_style_thin, color_attrib)
            local h, s, v = common.hexToHSV(current_hex)
            local invert_enabled = read and InvertReadColor.get() or InvertUnreadColor.get()
            local wheel
            wheel = ColorWheelWidget:new({
                title_text = title_text,
                hue = h,
                saturation = s,
                value = v,
                invert_in_night_mode = not invert_enabled,
                callback = function(new_hex)
                    if new_hex ~= current_hex then
                        -- Process color depending on if the color should be inverted in night mode
                        local display_hex = new_hex
                        if Screen.night_mode then
                            if not invert_enabled then
                                display_hex = common.invertColor(new_hex)
                            end
                        end
                        local color = Blitbuffer.colorFromString(display_hex)

                        if not color then
                            UIManager:setDirty(nil, "ui")
                            return
                        end

                        Settings:set(self.settings.progress_style_thin, color_attrib, new_hex)
                        Settings:setPersistent(self.settings.progress_style_thin, color_attrib, new_hex)
                        self.progress_bar[color_attrib] = color
                        touchmenu_instance:updateItems()
                        self:refreshFooter(true)
                    end
                    UIManager:setDirty(nil, "ui")
                end,
                cancel_callback = function()
                    UIManager:setDirty(nil, "ui")
                end,
            })
            UIManager:show(wheel)
        end
    }
end

function ReaderFooter:_invertColorMenu(read)
    local setting = read and InvertReadColor or InvertUnreadColor

    return {
        text = T(_("Invert %1 color in night mode"), read and "read" or "unread"),
        checked_func = setting.get,
        callback = function()
            setting.toggle()
            self.progress_bar:_setColors(self.settings.progress_style_thin)
            self:refreshFooter(true)
        end,
    }
end

local original_ReaderFooter_addToMainMenu = ReaderFooter.addToMainMenu
function ReaderFooter:addToMainMenu(menu_items)
    original_ReaderFooter_addToMainMenu(self, menu_items)

    local item = getMenuItem(
        menu_items.status_bar,
        _("Progress bar"),
        { _("Thickness and height: thin"), _("Thickness and height: thick") }
    )
    if item then
        item.text_func = function()
            return self.settings.progress_style_thin and _("Thickness, height & colors: thin")
                or _("Thickness, height & colors: thick")
        end
        table.insert(item.sub_item_table, self:_statusBarColorMenu(true))
        table.insert(item.sub_item_table, self:_statusBarColorMenu(false))
        table.insert(item.sub_item_table, self:_invertColorMenu(true))
        table.insert(item.sub_item_table, self:_invertColorMenu(false))
    end
end

--------------------------------------------
-- Colored Progress Bar Painting
--------------------------------------------
function ProgressWidget:paintTo(bb, x, y)
    local my_size = self:getSize()
    if not self.dimen then
        self.dimen = Geom:new({
            x = x,
            y = y,
            w = my_size.w,
            h = my_size.h,
        })
    else
        self.dimen.x = x
        self.dimen.y = y
    end
    if self.dimen.w == 0 or self.dimen.h == 0 then
        return
    end

    local _mirroredUI = BD.mirroredUILayout()
    -- We'll draw every bar element in order, bottom to top.
    local fill_width = my_size.w - 2 * (self.margin_h + self.bordersize)
    local fill_y = y + self.margin_v + self.bordersize
    local fill_height = my_size.h - 2 * (self.margin_v + self.bordersize)

    if self.radius == 0 then
        -- If we don't have rounded borders, we can start with a simple border colored rectangle.
        bb:paintRect(x, y, my_size.w, my_size.h, self.bordercolor)
        -- And a full background bar inside (i.e., on top) of that.
        bb:paintRectRGB32(
            x + self.margin_h + self.bordersize,
            fill_y,
            math.ceil(fill_width),
            math.ceil(fill_height),
            self.bgcolor
        )
    else
        -- Otherwise, we have to start with the background.
        bb:paintRoundedRectRGB32(x, y, my_size.w, my_size.h, self.bgcolor, self.radius)
        -- Then the border around that.
        bb:paintBorderRGB32(math.floor(x), math.floor(y),
            my_size.w, my_size.h,
            self.bordersize, self.bordercolor, self.radius)
    end

    -- Then we can just paint the fill rectangle(s) and tick(s) on top of that.
    -- First the fill bar(s)...
    -- Fill bar for alternate pages (e.g. non-linear flows).
    if self.alt and self.alt[1] ~= nil then
        for i = 1, #self.alt do
            local tick_x = fill_width * ((self.alt[i][1] - 1) / self.last)
            local width = fill_width * (self.alt[i][2] / self.last)
            if _mirroredUI then
                tick_x = fill_width - tick_x - width
            end
            tick_x = math.floor(tick_x)
            width = math.ceil(width)

            bb:paintRectRGB32(
                x + self.margin_h + self.bordersize + tick_x,
                fill_y,
                width,
                math.ceil(fill_height),
                self.altcolor
            )
        end
    end

    -- Main fill bar for the specified percentage.
    if self.percentage >= 0 and self.percentage <= 1 then
        local fill_x = x + self.margin_h + self.bordersize
        if self.fill_from_right or (_mirroredUI and not self.fill_from_right) then
            fill_x = fill_x + (fill_width * (1 - self.percentage))
            fill_x = math.floor(fill_x)
        end

        bb:paintRectRGB32(
            fill_x,
            fill_y,
            math.ceil(fill_width * self.percentage),
            math.ceil(fill_height),
            self.fillcolor
        )

        -- Overlay the initial position marker on top of that
        if self.initial_pos_marker and self.initial_percentage >= 0 then
            if self.height <= INITIAL_MARKER_HEIGHT_THRESHOLD then
                self.initial_pos_icon:paintTo(
                    bb,
                    Math.round(fill_x + math.ceil(fill_width * self.initial_percentage) - self.height / 4),
                    y - Math.round(self.height / 6)
                )
            else
                self.initial_pos_icon:paintTo(
                    bb,
                    Math.round(fill_x + math.ceil(fill_width * self.initial_percentage) - self.height / 2),
                    y
                )
            end
        end
    end

    -- ...then the tick(s).
    if self.ticks and self.last and self.last > 0 then
        for i, tick in ipairs(self.ticks) do
            local tick_x = fill_width * (tick / self.last)
            if _mirroredUI then
                tick_x = fill_width - tick_x
            end
            tick_x = math.floor(tick_x)

            bb:paintRect(
                x + self.margin_h + self.bordersize + tick_x,
                fill_y,
                self.tick_width,
                math.ceil(fill_height),
                self.bordercolor
            )
        end
    end
end

--------------------------------------------
-- Appearance Menu
--------------------------------------------
local function update_footer()
    if common.has_document_open() then
        local footer = ReaderUI.instance.view.footer
        footer.progress_bar:_setColors(footer.settings.progress_style_thin)
        footer:refreshFooter(true)
    end
end

local function color_submenu(thin, read, separator)
    local color_attrib = colorAttrib(read)
    return
    {
        text_func = function()
            local color = Settings:getPersistent(thin, color_attrib)
            local format = (read and "Read color: %1" or "Unread color: %1") .. " (hold to pick)"
            return T(format, color)
        end,
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            local invert_enabled = read and InvertReadColor.get() or InvertUnreadColor.get()
            local input_dialog
            input_dialog = InputDialog:new({
                title = "Enter color hex code for " .. (read and "read color" or "unread color"),
                input = Settings:getPersistent(thin, color_attrib),
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
                            text = "Save",
                            callback = function()
                                local text = input_dialog:getInputText()

                                if text ~= "" then
                                    if not text:match("^#%x%x%x%x%x%x$") then
                                        return
                                    end

                                    -- Process color depending on if the color should be inverted in night mode
                                    local display_text = text
                                    if Screen.night_mode then
                                        if not invert_enabled then
                                            display_text = common.invertColor(text)
                                        end
                                    end
                                    local color = Blitbuffer.colorFromString(display_text)

                                    if not color then
                                        return
                                    end

                                    Settings:set(thin, color_attrib, string.upper(text))
                                    Settings:setPersistent(thin, color_attrib, string.upper(text))
                                    touchmenu_instance:updateItems()
                                    update_footer()
                                    UIManager:close(input_dialog)
                                end
                            end,
                        },
                    },
                },
            })
            UIManager:show(input_dialog)
            input_dialog:onShowKeyboard()
        end,
        hold_callback = function(touchmenu_instance)
            local title_text = read and "Pick read color" or "Pick unread color"
            local current_hex = Settings:getPersistent(thin, color_attrib)
            local h, s, v = common.hexToHSV(current_hex)
            local invert_enabled = read and InvertReadColor.get() or InvertUnreadColor.get()
            local wheel
            wheel = ColorWheelWidget:new({
                title_text = title_text,
                hue = h,
                saturation = s,
                value = v,
                invert_in_night_mode = not invert_enabled,
                callback = function(new_hex)
                    if new_hex ~= current_hex then
                        -- Process color depending on if the color should be inverted in night mode
                        local display_hex = new_hex
                        if Screen.night_mode then
                            if not invert_enabled then
                                display_hex = common.invertColor(new_hex)
                            end
                        end
                        local color = Blitbuffer.colorFromString(display_hex)

                        if not color then
                            UIManager:setDirty(nil, "ui")
                            return
                        end

                        Settings:set(thin, color_attrib, new_hex)
                        Settings:setPersistent(thin, color_attrib, new_hex)
                        touchmenu_instance:updateItems()
                        update_footer()
                    end
                    UIManager:setDirty(nil, "ui")
                end,
                cancel_callback = function()
                    UIManager:setDirty(nil, "ui")
                end,
            })
            UIManager:show(wheel)
        end,
        separator = separator
    }
end

local function invert_color_submenu(read)
    local setting = read and InvertReadColor or InvertUnreadColor

    return {
        text = T(_("Invert %1 color in night mode"), read and "read" or "unread"),
        checked_func = setting.get,
        callback = function()
            setting.toggle()
            update_footer()
        end,
    }
end

local function progress_bar_colors_menu()
    if not common.has_document_open() then
        Settings:init()
    end
    return {
        text = _("Progress bar colors"),
        sub_item_table = {
            {
                text = _("Thick progress bar")
            },
            color_submenu(false, true),
            color_submenu(false, false, true),
            {
                text = _("Thin progress bar")
            },
            color_submenu(true, true),
            color_submenu(true, false, true),
            invert_color_submenu(true),
            invert_color_submenu(false)
        }
    }
end

return progress_bar_colors_menu

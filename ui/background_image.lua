local AlphaTextBoxWidget     = require("widgets/alphatextboxwidget")
local Blitbuffer             = require("ffi/blitbuffer")
local Device                 = require("device")
local Dispatcher             = require("dispatcher")
local DocumentRegistry       = require("document/documentregistry")
local FileManager            = require("apps/filemanager/filemanager")
local FileManagerMenu        = require("apps/filemanager/filemanagermenu")
local Font                   = require("ui/font")
local ImageWidget            = require("ui/widget/imagewidget")
local ReaderMenu             = require("apps/reader/modules/readermenu")
local ReaderUI               = require("apps/reader/readerui")
local ReaderView             = require("apps/reader/modules/readerview")
local Screen                 = Device.screen
local Setting                = require("lib/setting")
local UIManager              = require("ui/uimanager")
local VerticalGroup          = require("ui/widget/verticalgroup")
local lfs                    = require("libs/libkoreader-lfs")
local logger                 = require("logger")
local pic                    = require("ffi/pic")
local userpatch              = require("userpatch")

-- Settings
local BackgroundImage        = Setting("ui_background_image_path", nil)         -- Path for UI background image (default: nil)
local StretchImage           = Setting("ui_background_image_stretch", true)     -- Whether the background image should be stretched to fit the screen (default: true)
local RotateImage            = Setting("ui_background_image_auto_rotate", true) -- Whether the background image should be auto-rotated (default: true)
local InvertImage            = Setting("ui_background_image_invert", false)     -- Whether the background image should be inverted in night mode (default: false)
local ShowInFiles            = Setting("ui_background_image_filemanager", true) -- Whether the background image should be shown in the file manager (default: true)
local ShowInReader           = Setting("ui_background_image_reader", true)      -- Whether the background image should be shown in the reader (default: true)
local ShowInMenu             = Setting("ui_background_image_menu", false)       -- Whether the background image should be shown in the top menu (default: false)
local ShowInHomescreen       = Setting("ui_background_image_homescreen", true)  -- Whether the background image should be shown in the homescreen (SimpleUI) (default: true)
local BackgroundImageHistory = Setting("ui_background_image_history", {})       -- A history of the past background images selected.
local LastBackgroundImage    = Setting("ui_background_image_last", nil)         -- The last background images selected.

-- Helper: get the filename for the current background image
local function background_image_name(path)
    path = path or BackgroundImage.get()
    return path:match("^.+/(.+)$")
end

-- Helper: save the last background image to the current one if one is set
local function save_last_background_image()
    local current_background_image = BackgroundImage.get()
    if current_background_image then
        LastBackgroundImage.set(current_background_image)
    end
end

-- Helper: get the dimensions of an image by loading it as a picture document
local function get_image_dimen(path)
    local ok, doc = pcall(pic.openDocument, path)
    if not ok or not doc then
        logger.info("get_image_dimen error:", tostring(doc))
        return nil, nil
    end
    local w, h = doc.width, doc.height
    doc:close()
    return w, h
end

-- Background Image Widget
local background_image = nil

local function reload_background_image()
    if background_image then
        background_image:free()
        background_image = nil
    end

    local fm_ui = FileManager.instance
    if fm_ui then
        -- Load new background in FileManager
        fm_ui:setupLayout()
        -- Refresh filemanager titlebar if it exists (patch)
        if FileManager.updateTitleBarTitle then
            fm_ui:updateTitleBarTitle()
        end
        UIManager:setDirty(FileManager.instance, "ui")
    end
end

local function get_bg_widget()
    local path = BackgroundImage.get()
    if not path then return nil end
    if not background_image then
        local screen_w, screen_h = Screen:getWidth(), Screen:getHeight()
        local image_w, image_h

        local widget_settings = {
            width = screen_w,
            height = screen_h,
            file_do_cache = false,
            alpha = true,
            scale_factor = not StretchImage.get() and 0 or nil,
            original_in_nightmode = not InvertImage.get(),
        }

        if DocumentRegistry:isImageFile(path) then
            image_w, image_h = get_image_dimen(path)
            widget_settings.file = path
        else
            local ui = require("apps/reader/readerui").instance or require("apps/filemanager/filemanager").instance
            if not ui then
                logger.warn("Screensaver called without UI instance, skipped")
                return
            end

            local cover_image = ui.bookinfo:getCoverImage(ui.document, path)
            if cover_image == nil then
                return nil
            end
            image_w, image_h = cover_image:getWidth(), cover_image:getHeight()
            widget_settings.image = cover_image
        end

        if RotateImage.get() then
            local rotation_mode = Screen:getRotationMode()

            local angle = rotation_mode == 3 and 180 or 0 -- match mode if possible
            if (image_w and image_h) and (image_w < image_h) ~= (screen_w < screen_h) then
                angle = angle + (G_reader_settings:isTrue("imageviewer_rotation_landscape_invert") and -90 or 90)
            end
            widget_settings.rotation_angle = angle
        end

        background_image = ImageWidget:new(widget_settings)
    end
    return background_image
end

-- Menus
local _ = require("gettext")
local T = require("ffi/util").template
local filemanagerutil = require("apps/filemanager/filemanagerutil")

local function background_image_menu()
    return {
        text_func = function()
            return T(_("Background image: %1"), BackgroundImage.get() and background_image_name() or "none")
        end,
        sub_item_table = {
            {
                text_func = function()
                    local status = BackgroundImage.get()
                        and (background_image_name() .. " (hold to unset)")
                        or "none (press to select)"
                    return T(_("Current image: %1"), status)
                end,
                callback = function(touchmenu_instance)
                    local title_header, current_path, file_filter, caller_callback

                    local home_dir = G_reader_settings:readSetting("home_dir") or Device.home_dir
                        or lfs.currentdir()
                    local current_screensaver = G_reader_settings:readSetting("screensaver_document_cover")
                    current_path = BackgroundImage.get() or LastBackgroundImage.get()
                        or current_screensaver
                        or home_dir

                    if current_path == BackgroundImage.get() then
                        title_header = _("Current image or document cover:")
                    elseif current_path == LastBackgroundImage.get() then
                        title_header = _("Last image or document cover:")
                    elseif current_path == current_screensaver then
                        title_header = _("Screensaver directory:")
                    elseif current_path == home_dir then
                        title_header = _("Home or current directory:")
                    end

                    file_filter = function(filename)
                        return DocumentRegistry:hasProvider(filename)
                    end
                    caller_callback = function(path)
                        save_last_background_image()

                        BackgroundImage.set(path)
                        touchmenu_instance:updateItems()
                        reload_background_image()

                        -- Append to history
                        local history = BackgroundImageHistory.get()
                        table.insert(history, path)
                        BackgroundImageHistory.set(history)
                    end
                    filemanagerutil.showChooseDialog(
                        title_header, caller_callback, current_path, nil, file_filter
                    )
                end,
                hold_callback = function(touchmenu_instance)
                    save_last_background_image()

                    BackgroundImage.set(nil)
                    touchmenu_instance:updateItems()
                    reload_background_image()
                end,
            },
            {
                text = _("Stretch to fit screen"),
                checked_func = StretchImage.get,
                callback = function()
                    StretchImage.toggle()
                    reload_background_image()
                end,
            },
            {
                text = _("Rotate for best fit"),
                checked_func = RotateImage.get,
                callback = function()
                    RotateImage.toggle()
                    reload_background_image()
                end,
            },
            {
                text = _("Invert image in night mode"),
                checked_func = InvertImage.get,
                callback = function()
                    InvertImage.toggle()
                    if Screen.night_mode then
                        reload_background_image()
                    end
                end,
                separator = true,
            },
            {
                text = _("Show in file browser"),
                checked_func = ShowInFiles.get,
                callback = function()
                    ShowInFiles.toggle()
                    local fm_ui = FileManager.instance
                    if FileManager.instance then
                        fm_ui:setupLayout()
                        -- Refresh filemanager titlebar if it exists (patch)
                        if FileManager.updateTitleBarTitle then
                            fm_ui:updateTitleBarTitle()
                        end
                        UIManager:setDirty(FileManager.instance, "ui")
                    end
                end,
            },
            {
                text = _("Show in reader"),
                checked_func = ShowInReader.get,
                callback = function()
                    ShowInReader.toggle()
                end,
            },
            {
                text = _("Show in top menu"),
                checked_func = ShowInMenu.get,
                callback = function()
                    ShowInMenu.toggle()
                end,
            },
            {
                text = _("Show in homescreen"),
                enabled_func = function() return G_reader_settings:readSetting("simpleui_enabled") end,
                checked_func = ShowInHomescreen.get,
                callback = function()
                    ShowInHomescreen.toggle()
                end,
            },
        },
    }
end

-- Add background image to FileManager
local original_FM_setupLayout = FileManager.setupLayout
function FileManager:setupLayout()
    original_FM_setupLayout(self)
    local bg_widget = get_bg_widget()
    if not (ShowInFiles.get() and bg_widget and self[1]) then return end

    local fm_ui = self[1][1]
    fm_ui[1].background = nil

    local original_paintTo = fm_ui.paintTo
    function fm_ui:paintTo(bb, x, y)
        bg_widget:paintTo(bb, x, y)
        original_paintTo(self, bb, x, y)
    end
end

-- Add the background image to the reader background, allowing it to show in the sides & page gaps
-- Page view mode
local original_ReaderView_drawPageSurround = ReaderView.drawPageSurround
function ReaderView:drawPageSurround(bb, x, y)
    original_ReaderView_drawPageSurround(self, bb, x, y)

    local bg_widget = get_bg_widget()
    if ShowInReader.get() and bg_widget then
        bg_widget:paintTo(bb, x, y)
    end
end

-- Continuous view mode
local original_ReaderView_drawPageBackground = ReaderView.drawPageBackground
function ReaderView:drawPageBackground(bb, x, y)
    original_ReaderView_drawPageBackground(self, bb, x, y)

    local bg_widget = get_bg_widget()
    if ShowInReader.get() and bg_widget then
        bg_widget:paintTo(bb, x, y)
    end
end

-- Continuous view mode - page gaps
local original_ReaderView_drawPageGap = ReaderView.drawPageGap
function ReaderView:drawPageGap(bb, x, y)
    local bg_widget = get_bg_widget()
    if not (ShowInReader.get() and bg_widget) then
        original_ReaderView_drawPageGap(self, bb, x, y)
    end
end

-- Add background image to top menu if the option is selected
local original_FileManagerMenu_onShowMenu = FileManagerMenu.onShowMenu
function FileManagerMenu:onShowMenu(tab_index, do_not_show)
    local result = original_FileManagerMenu_onShowMenu(self, tab_index, do_not_show)
    local bg_widget = get_bg_widget()
    if not (ShowInMenu.get() and bg_widget and self.menu_container) then return result end

    local menu_container = self.menu_container
    local main_menu = menu_container[1]
    main_menu[1][1].background = nil

    local original_paintTo = main_menu.paintTo
    function main_menu:paintTo(bb, x, y)
        local h = self.item_group:getSize().h + self.bordersize * 2 + self.padding
        local sub_bb = bb:viewport(x, y, Screen:getWidth(), h)
        bg_widget:paintTo(sub_bb, 0, 0)
        original_paintTo(self, sub_bb, 0, 0)
    end

    return result
end

local original_ReaderMenu_onShowMenu = ReaderMenu.onShowMenu
function ReaderMenu:onShowMenu(tab_index, do_not_show)
    local result = original_ReaderMenu_onShowMenu(self, tab_index, do_not_show)
    local bg_widget = get_bg_widget()
    if not (ShowInMenu.get() and bg_widget and self.menu_container) then return result end

    local menu_container = self.menu_container
    local main_menu = menu_container[1]
    main_menu[1][1].background = nil

    local original_paintTo = main_menu.paintTo
    function main_menu:paintTo(bb, x, y)
        local h = self.item_group:getSize().h + self.bordersize * 2 + self.padding
        local sub_bb = bb:viewport(x, y, Screen:getWidth(), h)
        bg_widget:paintTo(sub_bb, 0, 0)
        original_paintTo(self, sub_bb, 0, 0)
    end

    return result
end

local original_HomescreenWidget_initLayout, original_currently_reading_build

userpatch.registerPatchPluginFunc("simpleui", function()
    local Homescreen = require("sui_homescreen")
    if not Homescreen then return end

    local HomescreenWidget = userpatch.getUpValue(Homescreen.show, "HomescreenWidget")
    if not HomescreenWidget then return end

    if not original_HomescreenWidget_initLayout then
        original_HomescreenWidget_initLayout = HomescreenWidget._initLayout
    end

    function HomescreenWidget:_initLayout()
        local bg_widget = get_bg_widget()
        local overlap = original_HomescreenWidget_initLayout(self)
        if not (ShowInHomescreen.get() and bg_widget) then return overlap end

        local outer = overlap[1]
        local content_widget = outer[1]

        -- Move padding from outer widget to content widget
        local side_off = outer.padding_left
        content_widget.padding_left = side_off
        content_widget.padding_right = side_off
        outer.padding_left = 0
        outer.padding_right = 0

        outer.background = nil
        content_widget.background = nil

        local original_paintTo = content_widget.paintTo
        function content_widget:paintTo(bb, x, y)
            bg_widget:paintTo(bb, x, y)
            original_paintTo(self, bb, x, y)
        end

        return overlap
    end

    -- Replace the currently reading title label with one that supports transparency
    local currently_reading = require("desktop_modules/module_currently")
    local SH                = require("desktop_modules/module_books_shared")
    local UI                = require("sui_core")
    local Config            = require("sui_config")
    if not (currently_reading and SH and UI and Config) then return end

    local _getElemOrder = userpatch.getUpValue(currently_reading.build, "_getElemOrder")

    if not original_currently_reading_build then
        original_currently_reading_build = currently_reading.build
    end

    function currently_reading.build(w, ctx)
        local result        = original_currently_reading_build(w, ctx)
        local tappable      = ctx.kb_currently_focused and result[1] or result
        local row           = tappable[1][1]
        local meta_centered = row[2]
        local meta          = meta_centered[1]

        local pfx           = ctx.pfx
        local elem_order    = _getElemOrder(pfx)

        for i, elem in ipairs(elem_order) do
            if elem == "title" then
                local _BASE_COVER_GAP = Screen:scaleBySize(16) -- between cover and text column
                local scale           = Config.getModuleScale("currently", ctx.pfx)
                local thumb_scale     = Config.getThumbScale("currently", ctx.pfx)
                local lbl_scale       = Config.getItemLabelScale("currently", ctx.pfx)
                local D               = SH.getDims(scale, thumb_scale)
                local cover_gap       = math.max(1, math.floor(_BASE_COVER_GAP * scale))
                local tw              = w - UI.PAD - D.COVER_W - cover_gap - UI.PAD
                local _BASE_TITLE_FS  = Screen:scaleBySize(11)
                local title_fs        = math.max(8, math.floor(_BASE_TITLE_FS * scale * lbl_scale))
                local face_title      = Font:getFace("smallinfofont", title_fs)

                local new_label       = AlphaTextBoxWidget:new {
                    text      = meta[i].text,
                    face      = face_title,
                    bold      = true,
                    width     = tw,
                    max_lines = 2,
                }

                -- Free old label and set new one
                meta[i]:free()
                meta[i] = new_label
            end
        end

        return result
    end

    -- Fix quotes having an opaque background
    local quotes = require("desktop_modules/module_quote")
    if not quotes then return end

    local buildFromQuote, buildFromQuote_idx = userpatch.getUpValue(quotes.build, "buildFromQuote")
    local _, buildWidget_idx                 = userpatch.getUpValue(buildFromQuote, "buildWidget")
    local pickQuote                          = userpatch.getUpValue(buildFromQuote, "pickQuote")

    local function new_buildWidget(inner_w, text_str, attr_str, face_quote, face_attr, vspan_gap)
        local vg = VerticalGroup:new { align = "center" }
        local _CLR_TEXT_QUOTE = Blitbuffer.COLOR_BLACK

        vg[#vg + 1] = AlphaTextBoxWidget:new {
            text      = text_str,
            face      = face_quote,
            fgcolor   = _CLR_TEXT_QUOTE,
            width     = inner_w,
            alignment = "center",
        }
        -- vg[#vg + 1] = vspan_gap -- Don't use vertical span gap due to imperfect transparency
        vg[#vg + 1] = AlphaTextBoxWidget:new {
            text      = attr_str,
            face      = face_attr,
            fgcolor   = UI.CLR_TEXT_SUB,
            bold      = true,
            width     = inner_w,
            alignment = "center",
        }
        return vg
    end

    local function new_buildFromQuote(inner_w, face_quote, face_attr, vspan_gap)
        local q = pickQuote()

        if not q then
            return AlphaTextBoxWidget:new {
                text    = _("No quotes found."),
                face    = face_quote,
                fgcolor = UI.CLR_TEXT_SUB,
                bgcolor = nil,
                width   = inner_w,
            }
        end

        local attr = "— " .. (q.a or "?")
        if q.b and q.b ~= "" then attr = attr .. ",  " .. q.b end
        return new_buildWidget(inner_w, "\u{201C}" .. q.q .. "\u{201D}", attr, face_quote, face_attr, vspan_gap)
    end

    userpatch.replaceUpValue(buildFromQuote, buildWidget_idx, new_buildWidget)
    userpatch.replaceUpValue(quotes.build, buildFromQuote_idx, new_buildFromQuote)
end)

-- Hook into night mode state changes and reload background image
local original_UIManager_ToggleNightMode = UIManager.ToggleNightMode
function UIManager:ToggleNightMode()
    original_UIManager_ToggleNightMode(self)
    reload_background_image()
end

local original_UIManager_SetNightMode = UIManager.SetNightMode
function UIManager:SetNightMode()
    original_UIManager_SetNightMode(self)
    reload_background_image()
end

-- Reload background image on dimension changes (window resizing)
local original_FileManager_onSetDimensions = FileManager.onSetDimensions
function FileManager:onSetDimensions(dimen)
    original_FileManager_onSetDimensions(self, dimen)
    reload_background_image()
end

local original_ReaderView_onSetDimensions = ReaderView.onSetDimensions
function ReaderView:onSetDimensions(dimen)
    original_ReaderView_onSetDimensions(self, dimen)
    reload_background_image()
end

-- Register background image toggling & selection as dispatcher actions
local function SetLastBackgroundImage()
    local last_background_image = LastBackgroundImage.get()
    if last_background_image then
        LastBackgroundImage.set(BackgroundImage.get())
        BackgroundImage.set(last_background_image)
        reload_background_image()
    end
end

local function SelectBackgroundImage(action_num)
    save_last_background_image()

    local history = BackgroundImageHistory.get()
    BackgroundImage.set(history[action_num])
    reload_background_image()
end

local function getBackgroundImageActions()
    local action_nums, action_texts = {}, {}
    local history = BackgroundImageHistory.get()
    for i, v in ipairs(history) do
        table.insert(action_nums, i)
        table.insert(action_texts, background_image_name(v))
    end
    return action_nums, action_texts
end

FileManager.onSetLastBackgroundImage = SetLastBackgroundImage
ReaderUI.onSetLastBackgroundImage = SetLastBackgroundImage

FileManager.onSelectBackgroundImage = SelectBackgroundImage
ReaderUI.onSelectBackgroundImage = SelectBackgroundImage

Dispatcher:registerAction("ui_background_image_set_last", {
    category = "none",
    event = "SetLastBackgroundImage",
    title = _("Set last background image"),
    general = true,
})

Dispatcher:registerAction("ui_background_image_select", {
    category = "string",
    event = "SelectBackgroundImage",
    title = _("Select background image"),
    args_func = getBackgroundImageActions,
    general = true,
})

return background_image_menu

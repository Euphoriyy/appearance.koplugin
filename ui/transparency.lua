local Button = require("ui/widget/button")
local Event = require("ui/event")
local ReaderFooter = require("apps/reader/modules/readerfooter")
local Setting = require("lib/setting")
local UIManager = require("ui/uimanager")
local common = require("lib/common")

local TransparentButtons = Setting("ui_transparency_buttons", false) -- Whether buttons should be fully transparent (default: false)
local TransparentFooter = Setting("ui_transparency_footer", true)    -- Whether the ReaderFooter should be fully transparent (default: true)

-- Background color setting
local FooterBackgroundColor = Setting("ui_background_color_reader_footer", false)

-- Cache
local cached = {
    transparent_buttons = TransparentButtons.get(),
    transparent_footer = TransparentFooter.get(),
}

-- Menu
local _ = require("gettext")

local function transparency_menu()
    return {
        text = _("Transparency"),
        sub_item_table = {
            {
                text = _("Make buttons transparent"),
                checked_func = TransparentButtons.get,
                callback = function()
                    TransparentButtons.toggle()
                    cached.transparent_buttons = TransparentButtons.get()

                    UIManager:askForRestart()
                end,
            },
            {
                text = _("Make the reader footer transparent"),
                enabled_func = function() return not FooterBackgroundColor.get() end,
                checked_func = TransparentFooter.get,
                callback = function()
                    TransparentFooter.toggle()
                    cached.transparent_footer = TransparentFooter.get()

                    if common.has_document_open() then
                        UIManager:broadcastEvent(Event:new("RefreshFooterBackground"))
                    end
                end,
            },
        },
    }
end

-- Set buttons to be transparent before painting
local original_Button_paintTo = Button.paintTo
function Button:paintTo(bb, x, y)
    local original_background = self[1].background

    if cached.transparent_buttons and not self.exclude_from_transparency then
        self[1].background = nil
    end

    original_Button_paintTo(self, bb, x, y)

    self[1].background = original_background
end

-- Exclude footer background color changes if option is not set
local original_ReaderFooter_updateFooterContainer = ReaderFooter.updateFooterContainer
function ReaderFooter:updateFooterContainer()
    original_ReaderFooter_updateFooterContainer(self)

    if common.is_excluded(self.footer_content.background) then
        if cached.transparent_footer then
            self.footer_content.background = nil
        end
    end
end

return transparency_menu

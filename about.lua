local DataStorage = require("datastorage")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local common = require("lib/common")
local nf_icons = require("lib/nf_icons")
local _ = require("gettext")
local T = require("ffi/util").template

local PLUGIN_NAME = "appearance.koplugin"
local PLUGIN_TITLE = "Appearance"
local AUTHOR = "Euphoriyy"
local REPO_PATH = AUTHOR .. "/" .. PLUGIN_NAME
local PLUGIN_PATH = DataStorage:getDataDir() .. "/plugins/" .. PLUGIN_NAME
local meta_path = PLUGIN_PATH .. "/_meta.lua"

local meta
do
    local ok, m = pcall(dofile, meta_path)
    if ok then meta = m end
end
local name               = (meta and meta.fullname) or PLUGIN_TITLE
local version            = (meta and meta.version) or "?"
local description        = (meta and meta.description) or ""
local license_text            = "Licensed under GPL v3."

local GITHUB_URL_DISPLAY = "github.com/" .. REPO_PATH
local GITHUB_URL         = "https://" .. GITHUB_URL_DISPLAY

local about_text         = T(_([[
%1 v%2

Made with ❤ by %3

%4

%5

%6]]), name, version, AUTHOR, description, license_text, GITHUB_URL_DISPLAY)

local function about_menu()
    return {
        text_func = function() return nf_icons.label(nf_icons.INFO, _("About")) end,
        keep_menu_open = true,
        callback = function()
            local dialog = InfoMessage:new { text = about_text }
            UIManager:show(dialog)
        end,
        hold_callback = function()
            common.handleLink(GITHUB_URL)
        end,
    }
end

return about_menu

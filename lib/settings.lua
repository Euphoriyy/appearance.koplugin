local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")

local Settings = {
    settings_file = DataStorage:getSettingsDir() .. "/appearance.lua",
    settings = nil,
    updated = false,
}

Settings.settings = LuaSettings:open(Settings.settings_file)

function Settings:flushSettings()
    if self.settings and self.updated then
        self.settings:flush()
        self.updated = false
    end
end

return Settings

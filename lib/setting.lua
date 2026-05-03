local Settings = require("lib/settings")
local logger = require("logger")

function Setting(name, default, external)
    local self = {}

    -- Migration
    if not external and G_reader_settings:has(name) then
        local data = G_reader_settings:readSetting(name)
        Settings.settings:saveSetting(name, data)
        Settings.settings:flush()
        G_reader_settings:delSetting(name)

        logger.info("[SETTINGS MIGRATION] Migrated '" .. name .. "' → settings/appearance.lua...")
    end

    local instance = external and G_reader_settings or Settings.settings

    self.default = default
    self.get = function() return instance:readSetting(name, default) end
    self.set = function(value)
        if instance == Settings.settings then
            Settings.updated = true
        end
        return instance:saveSetting(name, value)
    end
    self.toggle = function()
        if instance == Settings.settings then
            Settings.updated = true
        end
        instance:toggle(name)
    end
    self.delete = function()
        if instance == Settings.settings then
            Settings.updated = true
        end
        instance:delSetting(name)
    end
    return self
end

return Setting

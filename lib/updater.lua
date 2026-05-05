-- Based on plugin:
-- https://github.com/AndyHazz/bookends.koplugin by @AndyHazz

local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Device = require("device")
local HtmlViewerWidget = require("widgets/htmlviewerwidget")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local markdown = require("lib/markdown/markdown")
local _ = require("gettext")
local T = require("ffi/util").template

local PLUGIN_NAME = "appearance.koplugin"
local PLUGIN_TITLE = "Appearance"
local REPO_PATH = "Euphoriyy/" .. PLUGIN_NAME
local PLUGIN_PATH = DataStorage:getDataDir() .. "/plugins/" .. PLUGIN_NAME
local USERAGENT_STRING = "KOReader-" .. PLUGIN_TITLE
local CACHE_DIR = "appearance_cache"

local Updater = {}

-- Background check state (session-only, not persisted)
local _cached_version = nil  -- latest available version string, or nil
local _cached_zip_url = nil  -- download URL for the latest release ZIP
local _last_check_time = nil -- os.time() of last successful or attempted check
local _check_in_flight = false
local CHECK_INTERVAL = 3600  -- 1 hour

function Updater.getInstalledVersion()
    local meta_path = PLUGIN_PATH .. "/_meta.lua"
    local ok_meta, meta = pcall(dofile, meta_path)
    return (ok_meta and meta and meta.version) or "unknown"
end

local function parseVersion(v)
    local parts = {}
    for part in tostring(v):gsub("^v", ""):gmatch("([^.]+)") do
        table.insert(parts, tonumber(part) or 0)
    end
    return parts
end

local function isNewer(v1, v2)
    local a, b = parseVersion(v1), parseVersion(v2)
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x > y then return true end
        if x < y then return false end
    end
    return false
end

--- Try LuaSocket first, fall back to curl for platforms where SSL crashes.
local function httpGetJSON(url, user_agent)
    local json = require("json")
    local ok_require, http, ltn12, socket, socketutil =
        pcall(function()
            return require("socket/http"),
                require("ltn12"),
                require("socket"),
                require("socketutil")
        end)
    if ok_require then
        local body = {}
        local ok_req, code = pcall(function()
            socketutil:set_timeout(socketutil.LARGE_BLOCK_TIMEOUT, socketutil.LARGE_TOTAL_TIMEOUT)
            local c = socket.skip(1, http.request({
                url = url,
                method = "GET",
                headers = {
                    ["User-Agent"] = user_agent,
                    ["Accept"] = "application/vnd.github.v3+json",
                },
                sink = ltn12.sink.table(body),
                redirect = true,
            }))
            socketutil:reset_timeout()
            return c
        end)
        if ok_req and code == 200 then
            local ok, data = pcall(json.decode, table.concat(body))
            if ok then return data end
        end
        pcall(function() socketutil:reset_timeout() end)
    end
    -- Fallback: curl (available on Android, desktop)
    local handle = io.popen(string.format(
        "curl -s -L -H 'User-Agent: %q' -H 'Accept: application/vnd.github.v3+json' %q",
        USERAGENT_STRING,
        url))
    if handle then
        local body = handle:read("*a")
        handle:close()
        if body and body ~= "" then
            local ok, data = pcall(json.decode, body)
            if ok then return data end
        end
    end
    return nil
end

function Updater.offerReleasesPage(message)
    local url = "https://github.com/" .. REPO_PATH .. "/releases"
    if Device:canOpenLink() then
        UIManager:show(ConfirmBox:new {
            text = message .. "\n\n" .. _("Open the releases page in a browser?"),
            ok_text = _("Open"),
            ok_callback = function()
                Device:openLink(url)
            end,
        })
    else
        UIManager:show(InfoMessage:new {
            text = message,
            timeout = 3,
        })
    end
end

--- Return the available update version and zip URL, or nil if none/not checked.
function Updater.getAvailableUpdate()
    return _cached_version, _cached_zip_url
end

--- Fire a silent background update check if the cache is stale (>1h or never checked).
-- Results available via getAvailableUpdate().
-- @param on_update_found function(version): optional callback when a new version is discovered
function Updater.checkBackground(on_update_found)
    if _check_in_flight then return end
    local now = os.time()
    if _last_check_time and (now - _last_check_time) < CHECK_INTERVAL then return end

    local NetworkMgr = require("ui/network/manager")
    if not NetworkMgr:isWifiOn() then return end

    _check_in_flight = true
    _last_check_time = now

    UIManager:scheduleIn(0.1, function()
        local installed_version = Updater.getInstalledVersion()
        local user_agent = USERAGENT_STRING .. "/" .. installed_version

        -- Only fetch the latest release (lightweight)
        local release = httpGetJSON(
            "https://api.github.com/repos/" .. REPO_PATH .. "/releases/latest",
            user_agent)

        _check_in_flight = false

        if not release or not release.tag_name then return end
        if release.draft or release.prerelease then return end

        local ver = release.tag_name:gsub("^v", "")
        if isNewer(ver, installed_version) then
            _cached_version = ver
            _cached_zip_url = nil
            if release.assets then
                for _, asset in ipairs(release.assets) do
                    if asset.name:match("%.zip$") then
                        _cached_zip_url = asset.browser_download_url
                        break
                    end
                end
            end
            if on_update_found then
                on_update_found(ver)
            end
        else
            _cached_version = nil
            _cached_zip_url = nil
        end
    end)
end

local function markdown_to_html(md)
    local html_content = markdown(md)
    local sanitized_html = ''
    for line in html_content:gmatch('[^\r\n]+') do
        if line ~= '' then
            sanitized_html = sanitized_html .. line .. '\n'
        end
    end
    return sanitized_html
end

function Updater.check()
    local installed_version = Updater.getInstalledVersion()

    local NetworkMgr = require("ui/network/manager")
    if not NetworkMgr:isWifiOn() then
        UIManager:show(InfoMessage:new {
            text = _("Wi-Fi is not enabled."),
            timeout = 3,
        })
        return
    end

    UIManager:show(InfoMessage:new {
        text = _("Checking for updates..."),
        timeout = 1,
    })

    UIManager:scheduleIn(0.1, function()
        local user_agent = USERAGENT_STRING .. "/" .. installed_version

        -- Fetch all releases to gather notes between installed and latest
        local releases = httpGetJSON(
            "https://api.github.com/repos/" .. REPO_PATH .. "/releases",
            user_agent)
        if not releases or #releases == 0 then
            Updater.offerReleasesPage(_("Could not check for updates."))
            return
        end

        -- Collect releases newer than installed version
        local new_releases = {}
        local latest_zip_url
        for _, rel in ipairs(releases) do
            if rel.draft or rel.prerelease then goto continue end
            local ver = rel.tag_name:gsub("^v", "")
            if isNewer(ver, installed_version) then
                table.insert(new_releases, rel)
                -- Find ZIP asset from the newest release
                if not latest_zip_url and rel.assets then
                    for _, asset in ipairs(rel.assets) do
                        if asset.name:match("%.zip$") then
                            latest_zip_url = asset.browser_download_url
                            break
                        end
                    end
                end
            end
            ::continue::
        end

        -- Update the background cache too
        _last_check_time = os.time()
        if #new_releases > 0 then
            _cached_version = new_releases[1].tag_name:gsub("^v", "")
            _cached_zip_url = latest_zip_url
        else
            _cached_version = nil
            _cached_zip_url = nil
        end

        if #new_releases == 0 then
            UIManager:show(InfoMessage:new {
                text = T(_("%1 is up to date."), PLUGIN_TITLE) .. "\n\n" ..
                    _("Version: ") .. installed_version,
                timeout = 3,
            })
            return
        end

        -- Build combined release notes (newest first)
        local latest_version = new_releases[1].tag_name:gsub("^v", "")
        local notes = {}
        for _, rel in ipairs(new_releases) do
            local body = markdown_to_html(rel.body or "")
            table.insert(notes, body)
        end

        local viewer
        local buttons = {
            {
                {
                    text = _("Close"),
                    callback = function()
                        UIManager:close(viewer)
                    end,
                },
                {
                    text = _("Update"),
                    callback = function()
                        UIManager:close(viewer)
                        if not latest_zip_url then
                            UIManager:show(InfoMessage:new {
                                text = _("No download available for this release."),
                                timeout = 3,
                            })
                            return
                        end
                        Updater.install(latest_zip_url, installed_version, latest_version)
                    end,
                },
            },
        }

        table.insert(notes, 1, markdown_to_html(T(_("# v%1 ➡ v%2\n"), installed_version, latest_version)))
        local all_notes = table.concat(notes, "\n\n")

        viewer = HtmlViewerWidget:new {
            title = _("Update available!"),
            text = all_notes,
            is_html = true,
            buttons_table = buttons,
            add_default_buttons = false,
            html_link_tapped_callback = function(link)
                Device:openLink(link)
            end,
        }
        UIManager:show(viewer)
    end)
end

function Updater.install(zip_url, old_version, new_version)
    UIManager:show(InfoMessage:new {
        text = _("Downloading update..."),
        timeout = 1,
    })

    UIManager:scheduleIn(0.1, function()
        -- Download ZIP to temp location
        local cache_dir = DataStorage:getSettingsDir() .. "/" .. CACHE_DIR
        if lfs.attributes(cache_dir, "mode") ~= "directory" then
            lfs.mkdir(cache_dir)
        end
        local zip_path = cache_dir .. "/" .. PLUGIN_NAME .. ".zip"

        -- Try LuaSocket first, fall back to curl
        local downloaded = false
        local ok_require, http, ltn12, socket, socketutil =
            pcall(function()
                return require("socket/http"),
                    require("ltn12"),
                    require("socket"),
                    require("socketutil")
            end)
        if ok_require then
            local file = io.open(zip_path, "wb")
            if file then
                local ok_dl, code = pcall(function()
                    socketutil:set_timeout(socketutil.FILE_BLOCK_TIMEOUT, socketutil.FILE_TOTAL_TIMEOUT)
                    local c = socket.skip(1, http.request({
                        url = zip_url,
                        method = "GET",
                        headers = {
                            ["User-Agent"] = USERAGENT_STRING .. "/" .. old_version,
                        },
                        sink = ltn12.sink.file(file),
                        redirect = true,
                    }))
                    socketutil:reset_timeout()
                    return c
                end)
                if not ok_dl then
                    pcall(function() socketutil:reset_timeout() end)
                end
                downloaded = ok_dl and code == 200
            end
        end
        -- Fallback: curl (available on Android, desktop)
        if not downloaded then
            pcall(os.remove, zip_path)
            local ret = os.execute(string.format(
                "curl -s -L -o %q %q", zip_path, zip_url))
            downloaded = ret == 0 or ret == true
        end
        if not downloaded then
            pcall(os.remove, zip_path)
            Updater.offerReleasesPage(_("Download failed."))
            return
        end

        -- Extract to plugin directory (strip root folder from ZIP)
        local ok, err = Device:unpackArchive(zip_path, PLUGIN_PATH, true)
        pcall(os.remove, zip_path)

        if not ok then
            UIManager:show(InfoMessage:new {
                text = _("Installation failed: ") .. tostring(err),
                timeout = 5,
            })
            return
        end

        -- Restart KOReader to load the new version
        UIManager:show(ConfirmBox:new {
            text = _("Appearance updated to v") .. new_version .. ".\n\n" ..
                _("Restart KOReader now?"),
            ok_text = _("Restart"),
            ok_callback = function()
                UIManager:restartKOReader()
            end,
        })
    end)
end

return Updater

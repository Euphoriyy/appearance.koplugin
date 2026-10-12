local UIManager = require("ui/uimanager")
local ffi = require("ffi")
local ffiutil = require("ffi/util")

require("ffi/posix_h")

local POLL_INTERVAL = 1 -- In seconds

local MONITOR_CMD = "exec gdbus monitor --session "
    .. "--dest org.freedesktop.portal.Desktop "
    .. "--object-path /org/freedesktop/portal/desktop 2>/dev/null"

local ThemeWatcher = { pid = nil, fd = nil, buf = "", running = false }

function ThemeWatcher:start(on_change)
    if self.running then return true end
    self.on_change = on_change
    self.buf = ""

    local pid, read_fd = ffiutil.runInSubProcess(function(_, write_fd)
        local p = io.popen(MONITOR_CMD, "r")
        if not p then return end
        for line in p:lines() do
            -- ... SettingChanged ('org.freedesktop.appearance', 'color-scheme', <uint32 1>)
            local v = line:match("color%-scheme.-uint32 (%d)")
            if v then
                ffiutil.writeToFD(write_fd, v .. "\n")
            end
        end
        p:close()
    end, true) -- true = create a pipe

    if not pid then return false end
    self.pid, self.fd, self.running = pid, read_fd, true

    self._tick_fn = function() self:_tick() end
    UIManager:scheduleIn(POLL_INTERVAL, self._tick_fn)
    return true
end

function ThemeWatcher:_tick()
    if not self.running then return end

    local n = ffiutil.getNonBlockingReadSize(self.fd)
    if n and n > 0 then
        local buf = ffi.new("char[?]", n)
        local got = tonumber(ffi.C.read(self.fd, buf, n))
        if got and got > 0 then
            self.buf = self.buf .. ffi.string(buf, got)
            -- Process complete lines, keep any partial remainder
            for line in self.buf:gmatch("([^\n]*)\n") do
                self.on_change(line == "1") -- true = dark
            end
            self.buf = self.buf:match("[^\n]*$")
        end
    end

    -- Child exited (gdbus missing, session bus gone, etc.)
    if ffiutil.isSubProcessDone(self.pid) then
        self:stop()
        return
    end

    UIManager:scheduleIn(POLL_INTERVAL, self._tick_fn)
end

function ThemeWatcher:stop()
    if not self.running then return end
    self.running = false
    UIManager:unschedule(self._tick_fn)
    ffiutil.terminateSubProcess(self.pid)
    ffi.C.close(self.fd)
    self.pid, self.fd = nil, nil
end

return ThemeWatcher

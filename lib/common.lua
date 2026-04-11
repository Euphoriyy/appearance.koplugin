local Blitbuffer = require("ffi/blitbuffer")
local ReaderUI = require("apps/reader/readerui")

local common = {}

-- Special color that indicates the color should either stay white/black or be set to the original bgcolor/fgcolor
-- Used for ReaderFooter and ScreenSaverWidget
common.EXCLUSION_COLOR = Blitbuffer.colorFromString("#DAAAAD")
local EXCLUSION_COLOR_RGB32 = common.EXCLUSION_COLOR:getColorRGB32()

function common.is_excluded(color)
    return color and color:getColorRGB32() == EXCLUSION_COLOR_RGB32
end

-- Helper: invert a hex color string "#RRGGBB" → "#(FF-R)(FF-G)(FF-B)"
function common.invertColor(hex)
    -- Remove the "#" and parse as R, G, B
    local r = tonumber(hex:sub(2, 3), 16)
    local g = tonumber(hex:sub(4, 5), 16)
    local b = tonumber(hex:sub(6, 7), 16)
    if not r or not g or not b then return hex end
    -- Invert
    return string.format("#%02X%02X%02X", 255 - r, 255 - g, 255 - b)
end

-- Helper: convert hex color string "#RRGGBB" → HSV values
function common.hexToHSV(hex)
    -- Remove # if present
    hex = hex:gsub("#", "")

    -- Parse RGB values
    local r, g, b
    if #hex == 6 then
        -- Full form #RRGGBB
        r = tonumber(hex:sub(1, 2), 16) / 255
        g = tonumber(hex:sub(3, 4), 16) / 255
        b = tonumber(hex:sub(5, 6), 16) / 255
    elseif #hex == 3 then
        -- Short form #RGB -> #RRGGBB
        r = tonumber(hex:sub(1, 1), 16) / 15
        g = tonumber(hex:sub(2, 2), 16) / 15
        b = tonumber(hex:sub(3, 3), 16) / 15
    else
        -- Invalid format, return default (red)
        return 0, 1, 1
    end

    -- RGB to HSV conversion
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local delta = max - min

    -- Value (brightness)
    local v = max

    -- Saturation
    local s = 0
    if max > 0 then
        s = delta / max
    end

    -- Hue
    local h = 0
    if delta > 0 then
        if max == r then
            h = 60 * (((g - b) / delta) % 6)
        elseif max == g then
            h = 60 * (((b - r) / delta) + 2)
        else
            h = 60 * (((r - g) / delta) + 4)
        end
    end

    -- Normalize hue to 0-360
    if h < 0 then
        h = h + 360
    end

    return h, s, v
end

-- Helper: compute luminance of a color (0 = black, 1 = white)
function common.luminance(color)
    return 0.299 * color:getR() + 0.587 * color:getG() + 0.114 * color:getB()
end

-- Helper: compute contrast between two colors
function common.contrast(c1, c2)
    return math.abs(common.luminance(c1) - common.luminance(c2))
end

function common.lightenColor(c, amount)
    local r = c:getR()
    local g = c:getG()
    local b = c:getB()

    return Blitbuffer.ColorRGB32(
        math.floor(r + (255 - r) * amount),
        math.floor(g + (255 - g) * amount),
        math.floor(b + (255 - b) * amount)
    )
end

-- Helper: check if we have a document open
function common.has_document_open()
    return ReaderUI.instance ~= nil and ReaderUI.instance.document ~= nil
end

-- Helper: check if a value exists in a table
function common.contains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end

return common

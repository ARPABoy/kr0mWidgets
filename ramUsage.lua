local wibox = require("wibox")
local awful = require("awful")

-- Get $HOME environment variable
local home = os.getenv("HOME")

-- Create RAM icon widget (global for rc.lua)
kr0mRamIcon = wibox.widget.imagebox(home .. "/.config/awesome/kr0mWidgets/media_files/ram.png")

-- Create RAM usage text widget (global for rc.lua)
kr0mRamData = wibox.widget.textbox()

-- DBus listener to receive RAM usage updates
dbus.request_name("session", "com.alfaexploit.ramUsage")
dbus.add_match("session", "interface='com.alfaexploit.ramUsage', member='data'")
dbus.connect_signal("com.alfaexploit.ramUsage", function (...)
    local data = {...}
    local dbustext = data[2]
    kr0mRamData:set_text(dbustext)
end)

-- Function to read /proc/meminfo and calculate RAM usage
local function get_ram_usage()
    local meminfo = {}
    local f = io.open("/proc/meminfo", "r")
    if not f then return "ERR" end

    for line in f:lines() do
        local key, value = line:match("^(%w+):%s+(%d+)")
        if key and value then
            meminfo[key] = tonumber(value) -- Values are in kB
        end
    end
    f:close()

    local mem_total  = (meminfo["MemTotal"] or 0) * 1024
    local mem_free   = (meminfo["MemFree"] or 0) * 1024
    local buffers    = (meminfo["Buffers"] or 0) * 1024
    local cached     = (meminfo["Cached"] or 0) * 1024
    local sreclaim   = (meminfo["SReclaimable"] or 0) * 1024

    -- Used memory = total - free - buffers - cached - sreclaimable
    local used_memory = mem_total - mem_free - buffers - cached - sreclaim

    -- Function to convert bytes to human readable string
    local function human_readable(bytes)
        local units = { "B", "K", "M", "G", "T" }
        local size = bytes
        local level = 1
        while size >= 1024 and level < #units do
            size = size / 1024
            level = level + 1
        end
        return string.format("%.1f%s", size, units[level])
    end

    local human_total = human_readable(mem_total)
    local human_used  = human_readable(used_memory)

    local percentage = 0
    if mem_total > 0 then
        percentage = math.floor((used_memory / mem_total) * 100)
    end

    return string.format("%d%%-%s/%s", percentage, human_used, human_total)
end

-- Timer that runs every 5 seconds and sends RAM usage via DBus
local sleepTimerDbus = timer({ timeout = 5 })
sleepTimerDbus:connect_signal("timeout", function ()
    local usage = get_ram_usage()
    awful.util.spawn_with_shell(
        string.format(
            "dbus-send --session --dest=com.alfaexploit.ramUsage /com/alfaexploit/ramUsage com.alfaexploit.ramUsage.data string:'%s'",
            usage
        )
    )
end)

-- Start timer
sleepTimerDbus:start()

-- Trigger first update immediately
sleepTimerDbus:emit_signal("timeout")


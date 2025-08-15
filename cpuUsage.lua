local wibox = require("wibox")
local awful = require("awful")

-- Get $HOME environment variable
local home = os.getenv("HOME")

-- Create CPU icon widget (global for rc.lua)
kr0mCpuIcon = wibox.widget.imagebox(home .. "/.config/awesome/kr0mWidgets/media_files/cpu.png")

-- Create CPU usage text widget (global for rc.lua)
kr0mCpuData = wibox.widget.textbox()

-- DBus listener to receive CPU usage updates
dbus.request_name("session", "com.alfaexploit.cpuUsage")
dbus.add_match("session", "interface='com.alfaexploit.cpuUsage', member='data'")
dbus.connect_signal("com.alfaexploit.cpuUsage", function (...)
    local data = {...}
    local dbustext = data[2]
    kr0mCpuData:set_text(dbustext)
end)

-- Store previous CPU times to calculate percentage
local prev_used = nil
local prev_total = nil

-- Function to read /proc/stat and calculate CPU usage percentage
local function get_cpu_usage()
    local f = io.open("/proc/stat", "r")
    if not f then return "ERR" end

    local line = f:read("*l")
    f:close()

    -- Extract all numeric values after "cpu"
    local numbers = {}
    for num in line:gmatch("(%d+)") do
        table.insert(numbers, tonumber(num))
    end

    -- Assign variables with default value 0 if missing
    local user    = numbers[1] or 0
    local nice    = numbers[2] or 0
    local system  = numbers[3] or 0
    local idle    = numbers[4] or 0
    local iowait  = numbers[5] or 0
    local irq     = numbers[6] or 0
    local softirq = numbers[7] or 0

    -- Calculate used and total CPU time (ignoring steal, guest, guest_nice)
    local used  = user + nice + system + iowait + irq + softirq
    local total = user + nice + system + idle + iowait + irq + softirq

    -- Calculate CPU usage percentage if previous values exist
    local usage = "NULL"
    if prev_used ~= nil and prev_total ~= nil then
        local diff_used  = used - prev_used
        local diff_total = total - prev_total
        if diff_total > 0 then
            usage = string.format("%d%%", math.floor((diff_used / diff_total) * 100))
        else
            usage = "0%"
        end
    end

    -- Store current values for next calculation
    prev_used = used
    prev_total = total

    return usage
end

-- Timer that runs every 5 seconds and sends CPU usage via DBus
local sleepTimerDbus = timer({ timeout = 5 })
sleepTimerDbus:connect_signal("timeout", function ()
    local usage = get_cpu_usage()
    awful.util.spawn_with_shell(
        string.format(
            "dbus-send --session --dest=com.alfaexploit.cpuUsage /com/alfaexploit/cpuUsage com.alfaexploit.cpuUsage.data string:'%s'",
            usage
        )
    )
end)

-- Start timer
sleepTimerDbus:start()

-- Trigger first update immediately
sleepTimerDbus:emit_signal("timeout")


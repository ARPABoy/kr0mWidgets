local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")

-- Text widget
kr0mCpuTempData = wibox.widget.textbox()

-- Icon widget
kr0mCpuTempIcon = wibox.widget.imagebox()

-- Base path of your images
local icon_base_path = os.getenv("HOME") .. "/.config/awesome/kr0mWidgets/media_files/cpuTemp/"

-- Function to get CPU temperature
local function get_cpu_temp()
    local handle = io.popen("sensors | grep 'Package id 0:' | awk '{print $4}' | tr -d '+°C'")
    local temp = handle:read("*a")
    handle:close()

    temp = tonumber(temp) or 0
    return temp
end

-- Function to choose icon based on temperature
local function get_icon_name(temp)
    if temp < 55 then
        return icon_base_path .. "blue.png"
    elseif temp < 75 then
        return icon_base_path .. "orange.png"
    elseif temp < 90 then
        return icon_base_path .. "red.png"
    else
        return icon_base_path .. "burning.png"
    end
end

-- Function to update the widget
local function update_cpu_temp_widget()
    local temp = get_cpu_temp()
    kr0mCpuTempData:set_text(temp .. "°C")
    kr0mCpuTempIcon:set_image(get_icon_name(temp))
end

-- Timer to update every 5s
local cpu_temp_timer = gears.timer({ timeout = 5 })
cpu_temp_timer:connect_signal("timeout", update_cpu_temp_widget)
cpu_temp_timer:start()

-- Initial call
update_cpu_temp_widget()


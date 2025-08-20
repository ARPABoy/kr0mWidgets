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

-- Icons
local blue_icon    = icon_base_path .. "blue.png"
local orange_icon  = icon_base_path .. "orange.png"
local red_icon     = icon_base_path .. "red.png"
local burning_icon = icon_base_path .. "burning.png"

-- State for blinking
local blink_state = false

-- Timer for blinking
local blink_timer = gears.timer({
    timeout   = 0.5,
    autostart = false,
    call_now  = false,
    single_shot = false,
    callback = function()
        blink_state = not blink_state
        if blink_state then
            kr0mCpuTempIcon:set_image(red_icon)
        else
            kr0mCpuTempIcon:set_image(burning_icon)
        end
    end
})

-- Function to update the widget
local function update_cpu_temp_widget()
    local temp = get_cpu_temp()
    kr0mCpuTempData:set_text(temp .. "°C")

    if temp >= 90 then
        if not blink_timer.started then
            blink_timer:start()
        end
    else
        if blink_timer.started then
            blink_timer:stop()
        end

        if temp < 55 then
            kr0mCpuTempIcon:set_image(blue_icon)
        elseif temp < 75 then
            kr0mCpuTempIcon:set_image(orange_icon)
        elseif temp < 90 then
            kr0mCpuTempIcon:set_image(red_icon)
        end
    end
end

-- Timer to update every 5s
local cpu_temp_timer = gears.timer({ timeout = 5 })
cpu_temp_timer:connect_signal("timeout", update_cpu_temp_widget)
cpu_temp_timer:start()

-- Initial call
update_cpu_temp_widget()


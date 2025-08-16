local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")

-- Text widget
kr0mBatteryData = wibox.widget.textbox()

-- Battery icon widget
kr0mBatteryIcon = wibox.widget.imagebox()

-- Base path of your images
local icon_base_path = os.getenv("HOME") .. "/.config/awesome/kr0mWidgets/media_files/battery/"

-- Blinking state
local blink_state = true

-- Function to get battery info
local function get_battery_info()
    local handle = io.popen("upower -i $(upower -e | grep BAT)")
    local output = handle:read("*a")
    handle:close()

    local percentage = tonumber(output:match("percentage:%s*(%d+)%%") or 0)
    local status = output:match("state:%s*(%a+)") or "Unknown"

    return percentage, status
end

-- Function to get power profile
local function get_power_profile()
    local handle = io.popen("powerprofilesctl get")
    local profile = handle:read("*a")
    handle:close()
    profile = profile:gsub("%s+", "")  -- remove spaces and newlines
    return profile
end

-- Function to determine the icon level based on percentage
local function get_battery_level(percentage)
    if percentage >= 88 then
        return 7
    elseif percentage >= 75 then
        return 6
    elseif percentage >= 63 then
        return 5
    elseif percentage >= 50 then
        return 4
    elseif percentage >= 38 then
        return 3
    elseif percentage >= 25 then
        return 2
    elseif percentage >= 13 then
        return 1
    else
        return 0
    end
end

-- Function to get the icon filename
local function get_icon_name(level, status, profile)
    local charging_suffix = ""
    if status:lower() == "charging" then
        charging_suffix = "-charging"
    end
    local profile_suffix = "-" .. profile
    return icon_base_path .. "battery" .. level .. profile_suffix .. charging_suffix .. ".png"
end

-- Function to update the widget
local function update_battery_widget()
    local percentage, status = get_battery_info()
    local profile = get_power_profile()
    local level = get_battery_level(percentage)

    kr0mBatteryData:set_text(percentage .. "%")

    -- Blink if battery is critical and discharging
    if percentage < 5 and status:lower() == "discharging" then
        if blink_state then
            kr0mBatteryIcon:set_image(get_icon_name(level, status, profile))
        else
            kr0mBatteryIcon:set_image(icon_base_path .. "battery-blink.png")
        end
        blink_state = not blink_state
    else
        kr0mBatteryIcon:set_image(get_icon_name(level, status, profile))
        blink_state = true
    end
end

-- Timer to update every 0.5s for blinking
local battery_timer = gears.timer({ timeout = 0.5 })
battery_timer:connect_signal("timeout", update_battery_widget)
battery_timer:start()

-- Initial call
update_battery_widget()

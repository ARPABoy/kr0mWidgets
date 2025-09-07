local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")

-- Text widget
kr0mCpuTempData = wibox.widget.textbox()

-- Icon widget
kr0mCpuTempIcon = wibox.widget.imagebox()

-- Base path of your images
local icon_base_path = os.getenv("HOME") .. "/.config/awesome/kr0mWidgets/media_files/cpuTemp/"

-- Function to get CPU temperature (principal)
local function get_cpu_temp()
    local handle = io.popen("sensors | grep 'Package id 0:' | awk '{print $4}' | tr -d '+°C'")
    local temp = handle:read("*a")
    handle:close()
    temp = tonumber(temp) or 0
    return temp
end

-- Function to get full sensors info
local function get_all_sensors()
    local handle = io.popen("sensors")
    local out = handle:read("*a") or ""
    handle:close()
    return out
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

-- Sensors Popup
local sensors_popup = awful.popup {
    widget = {
        {
            id     = "text_role",
            widget = wibox.widget.textbox,
            text   = "",
        },
        margins = 8,
        widget  = wibox.container.margin
    },
    border_color = "#666666",
    border_width = 1,
    ontop        = true,
    visible      = false,
    shape        = gears.shape.rounded_rect,
    preferred_positions = { "right", "left", "top", "bottom" },
}

-- Timer sensors popup
local sensors_popup_timer = gears.timer({
    timeout   = 5,
    autostart = false,
    call_now  = true,
    single_shot = false,
    callback = function()
        if sensors_popup.visible then
            sensors_popup.widget:get_children_by_id("text_role")[1].text = get_all_sensors()
        end
    end
})

-- Sensors popup toggle
kr0mCpuTempIcon:buttons(gears.table.join(
    awful.button({}, 1, function()
        if sensors_popup.visible then
            sensors_popup.visible = false
            sensors_popup_timer:stop()
        else
            sensors_popup.widget:get_children_by_id("text_role")[1].text = get_all_sensors()
            sensors_popup:move_next_to(mouse.current_widget_geometry)
            sensors_popup.visible = true
            sensors_popup_timer:start()
        end
    end)
))


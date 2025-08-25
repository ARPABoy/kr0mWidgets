local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")
local naughty = require("naughty")

-- Base path for your icons
local icon_base_path = os.getenv("HOME") .. "/.config/awesome/kr0mWidgets/media_files/calendar/"

-- Calendar icon widget
kr0mCalendarIcon = wibox.widget.imagebox(icon_base_path .. "calendar.png")

-- Function to check if there are events today
local function has_events_today()
    local handle = io.popen("khal list today today")
    local output = handle:read("*a")
    handle:close()
    return output ~= nil and output:match("%S") ~= nil
end

-- Function to update the icon depending on today's events
local function update_calendar_icon()
    if has_events_today() then
        kr0mCalendarIcon:set_image(icon_base_path .. "calendar-dot.png")
    else
        kr0mCalendarIcon:set_image(icon_base_path .. "calendar.png")
    end
end

-- Left click on the icon → show upcoming events for the next 30 days
kr0mCalendarIcon:buttons(
    gears.table.join(
        awful.button({}, 1, function()
            awful.spawn.easy_async_with_shell("khal list today 30d", function(stdout)
                if stdout == "" then
                    naughty.notify({ title = "Calendar", text = "No upcoming events.", timeout = 5 })
                else
                    naughty.notify({ title = "Upcoming Events", text = stdout, timeout = 10 })
                end
            end)
        end)
    )
)

-- Timer to refresh the icon every 30s
local calendar_timer = gears.timer({ timeout = 30 })
calendar_timer:connect_signal("timeout", update_calendar_icon)
calendar_timer:start()

-- Initial update call
update_calendar_icon()


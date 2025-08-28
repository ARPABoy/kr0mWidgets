local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")
local naughty = require("naughty")

-- Base path for your icons
local icon_base_path = os.getenv("HOME") .. "/.config/awesome/kr0mWidgets/media_files/calendarEvents/"

-- Calendar icon widget
kr0mCalendarEventsIcon = wibox.widget.imagebox(icon_base_path .. "calendar-none.png")

-- Generic function to check if there are events in a date range
local function has_events(range)
    local handle = io.popen("khal list " .. range)
    local output = handle:read("*a")
    handle:close()
    return output ~= nil and output:match("%S") ~= nil
end

-- Function to update the icon depending on events
local function update_calendar_icon()
    if has_events("today today") then
        kr0mCalendarEventsIcon:set_image(icon_base_path .. "calendar-today.png")
    elseif has_events("tomorrow tomorrow") then
        kr0mCalendarEventsIcon:set_image(icon_base_path .. "calendar-tomorrow.png")
    elseif has_events("today 7d") then
        kr0mCalendarEventsIcon:set_image(icon_base_path .. "calendar-week.png")
    elseif has_events("today 30d") then
        kr0mCalendarEventsIcon:set_image(icon_base_path .. "calendar-month.png")
    else
        kr0mCalendarEventsIcon:set_image(icon_base_path .. "calendar-none.png")
    end
end

-- Popup to display events
local calendar_popup = awful.popup {
    widget = {
        {
            id = "event_list",
            widget = wibox.widget.textbox,
            text = "Loading events...",
            align = "left",
        },
        margins = 8,
        widget = wibox.container.margin,
    },
    border_color = "#666666",
    border_width = 1,
    ontop = true,
    visible = false,
    placement = awful.placement.top_right,
    shape = gears.shape.rounded_rect,
}

-- Helper to update popup content
local function update_calendar_popup()
    awful.spawn.easy_async_with_shell("khal list today 30d", function(stdout)
        if stdout == "" then
            calendar_popup.widget:get_children_by_id("event_list")[1].text = "No upcoming events."
        else
            calendar_popup.widget:get_children_by_id("event_list")[1].text = stdout
        end
    end)
end

-- Left click on the icon → toggle popup
kr0mCalendarEventsIcon:buttons(
    gears.table.join(
        awful.button({}, 1, function()
            if calendar_popup.visible then
                calendar_popup.visible = false
            else
                update_calendar_popup()
                calendar_popup.visible = true
            end
        end)
    )
)

-- Timer to refresh the icon every 60s
local calendar_timer = gears.timer({ timeout = 60 })
calendar_timer:connect_signal("timeout", update_calendar_icon)
calendar_timer:start()

-- Initial update call
update_calendar_icon()


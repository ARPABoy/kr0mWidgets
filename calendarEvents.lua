local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")

local icon_base_path = os.getenv("HOME") .. "/.config/awesome/kr0mWidgets/media_files/calendarEvents/"

kr0mCalendarEventsIcon = wibox.widget.imagebox(icon_base_path .. "calendar-none.png")

local function has_events(range)
    local handle = io.popen("khal list " .. range .. " 2>/dev/null")
    local output = handle:read("*a")
    handle:close()
    return output ~= nil and output:match("%S") ~= nil and not output:match("No events")
end

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

local calendar_popup = awful.popup {
    widget = {
        {
            id = "event_list",
            layout = wibox.layout.fixed.vertical,
        },
        margins = 8,
        widget = wibox.container.margin,
    },
    border_color = "#666666",
    border_width = 1,
    ontop = true,
    visible = false,
    shape = gears.shape.rounded_rect,
    maximum_width = 400,
    maximum_height = 300,
}

local function update_calendar_popup()
    awful.spawn.easy_async_with_shell("LC_TIME=en_US.UTF-8 khal list today 30d", function(stdout)
        local event_list = calendar_popup.widget:get_children_by_id("event_list")[1]
        event_list:reset()

        if stdout == "" or stdout:match("^%s*$") then
            event_list:add(wibox.widget.textbox("No upcoming events."))
            return
        end

        local current_day = nil
        local day_events = {}
        local first_day = true

        for line in stdout:gmatch("[^\r\n]+") do
            if line:match("^%s*$") then
                goto continue
            end
            
            if not line:match("^%s") and line:match("%d%d/%d%d/%d%d%d%d") then
                if current_day then
                    if not first_day then
                        event_list:add(wibox.widget { widget = wibox.widget.separator, forced_height = 1, color = "#888888", opacity = 0.6 })
                    end
                    
                    local tb_day = wibox.widget.textbox(current_day)
                    tb_day.font = "Sans Bold 11"
                    event_list:add(tb_day)
                    
                    for _, ev in ipairs(day_events) do
                        event_list:add(wibox.widget.textbox("  " .. ev))
                    end
                    
                    first_day = false
                    day_events = {}
                end
                current_day = line
            else
                local cleaned_event = line:match("^%s*(.+)$")
                if cleaned_event and cleaned_event ~= "" then
                    table.insert(day_events, cleaned_event)
                end
            end
            
            ::continue::
        end

        if current_day then
            if not first_day then
                event_list:add(wibox.widget { widget = wibox.widget.separator, forced_height = 1, color = "#888888", opacity = 0.6 })
            end
            
            local tb_day = wibox.widget.textbox(current_day)
            tb_day.font = "Sans Bold 11"
            event_list:add(tb_day)
            
            for _, ev in ipairs(day_events) do
                event_list:add(wibox.widget.textbox("  " .. ev))
            end
        end
    end)
end

kr0mCalendarEventsIcon:buttons(
    gears.table.join(
        awful.button({}, 1, function()
            if calendar_popup.visible then
                calendar_popup.visible = false
            else
                update_calendar_popup()
                awful.placement.top_right(calendar_popup, { margins = { top = 40, right = 10 } })
                calendar_popup.visible = true
            end
        end)
    )
)

local calendar_timer = gears.timer({ timeout = 60 })
calendar_timer:connect_signal("timeout", update_calendar_icon)
calendar_timer:start()
update_calendar_icon()
